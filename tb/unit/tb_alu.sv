module tb_alu;
    timeunit 1ns;
    timeprecision 1ps;

    localparam logic [3:0]
        ADD    = 4'h0, SUB  = 4'h1,
        AND_OP = 4'h2, OR_OP = 4'h3, XOR_OP = 4'h4,
        SLL    = 4'h5, SRL  = 4'h6, SRA = 4'h7,
        SLT    = 4'h8, SLTU = 4'h9, PASS_B = 4'ha;

    logic [31:0] a, b, result;
    logic [3:0]  alu_op;

    int unsigned checks = 0;
    int unsigned failures = 0;
    int unsigned hits [0:10];

    // Fixed seed and explicit generator make stimulus reproducible.
    bit [31:0] rng = 32'h1234_5678;
    logic [31:0] ra, rb;

    
    localparam int N = 12;
    logic [31:0] edges [0:N-1];

    initial begin
        edges[0]  = 32'h0000_0000;
        edges[1]  = 32'h0000_0001;
        edges[2]  = 32'h0000_0002;
        edges[3]  = 32'h0000_001f;
        edges[4]  = 32'h0000_0020;
        edges[5]  = 32'h0000_0021;
        edges[6]  = 32'h7fff_fffe;
        edges[7]  = 32'h7fff_ffff;
        edges[8]  = 32'h8000_0000;
        edges[9]  = 32'hffff_ffff;
        edges[10] = 32'haaaa_aaaa;
        edges[11] = 32'h5555_5555;
    end


    alu dut (
        .a(a),
        .b(b),
        .alu_op(alu_op),
        .result(result)
    );

    function automatic bit [31:0] next_word();
        rng = rng ^ (rng << 13);
        rng = rng ^ (rng >> 17);
        rng = rng ^ (rng << 5);
        return rng;
    endfunction

    function automatic logic [31:0] reference_result(
        input logic [3:0]  op,
        input logic [31:0] x,
        input logic [31:0] y
    );
        logic [32:0] wide;
        logic [31:0] r;
        int unsigned sh;

        r = '0;
        sh = int'(y[4:0]);

        case (op)
            ADD: begin
                wide = {1'b0, x} + {1'b0, y};
                r = wide[31:0];
            end

            SUB: begin
                wide = {1'b0, x} + {1'b0, ~y} + 33'd1;
                r = wide[31:0];
            end

            AND_OP: r = x & y;
            OR_OP:  r = x | y;
            XOR_OP: r = x ^ y;

            // Model shifts by selecting individual source bits.
            SLL: begin
                for (int i = 0; i < 32; i++)
                    if (i >= sh)
                        r[i] = x[i-sh];
            end

            SRL, SRA: begin
                for (int i = 0; i < 32; i++) begin
                    if ((i + sh) < 32)
                        r[i] = x[i+sh];
                    else
                        r[i] = (op == SRA) ? x[31] : 1'b0;
                end
            end

            // Flipping the sign bit maps signed order to unsigned order.
            SLT:  r = {31'b0,
                      ((x ^ 32'h8000_0000) <
                       (y ^ 32'h8000_0000))};

            SLTU: r = {31'b0, (x < y)};
            PASS_B: r = y;

            default: $fatal(1, "Reference received invalid op %h", op);
        endcase

        return r;
    endfunction

    task automatic check(
        input logic [3:0]  op,
        input logic [31:0] x,
        input logic [31:0] y,
        input logic [31:0] expected,
        input string label
    );
        a = x;
        b = y;
        alu_op = op;

        // Allow combinational evaluation before sampling.
        #1ns;
        checks++;

        if (op <= PASS_B)
            hits[op]++;

        // Case inequality also rejects unexpected X/Z output bits.
        if (result !== expected) begin
            failures++;
            $display(
                "FAIL %s op=%h a=%08h b=%08h expected=%08h got=%08h",
                label, op, x, y, expected, result
            );
        end
    endtask

    task automatic check_model(
        input logic [3:0] op,
        input logic [31:0] x,
        input logic [31:0] y
    );
        check(op, x, y, reference_result(op, x, y), "model");
    endtask

    initial begin
        for (int op = 0; op < 11; op++)
            hits[op] = 0;

        // Literal expectations anchor important boundary behavior.
        check(ADD, 32'hffff_ffff, 32'h0000_0001,
                   32'h0000_0000, "carry wrap");
        check(ADD, 32'h7fff_ffff, 32'h0000_0001,
                   32'h8000_0000, "signed overflow");
        check(SUB, 32'h0000_0000, 32'h0000_0001,
                   32'hffff_ffff, "borrow wrap");
        check(SUB, 32'h8000_0000, 32'h0000_0001,
                   32'h7fff_ffff, "signed underflow");
        check(SLT, 32'h8000_0000, 32'h7fff_ffff,
                   32'd1, "signed extrema");
        check(SLTU, 32'h8000_0000, 32'h7fff_ffff,
                    32'd0, "unsigned extrema");
        check(SLTU, 32'h0000_0001, 32'hffff_ffff,
                    32'd1, "sign-extended negative immediate operand");
        check(SRL, 32'h8000_0000, 32'd31,
                   32'h0000_0001, "logical right 31");
        check(SRA, 32'h8000_0000, 32'd31,
                   32'hffff_ffff, "arithmetic right 31");
        check(SLL, 32'h0000_0001, 32'd31,
                   32'h8000_0000, "left 31");

        // All operations, equality, both operand orders and sign boundaries.
        for (int op = 0; op < 11; op++)
            for (int i = 0; i < N; i++)
                for (int j = 0; j < N; j++)
                    check_model(op[3:0], edges[i], edges[j]);

        // Every shift amount, with upper shift-operand bits clear and set.
        for (int op = 5; op <= 7; op++)
            for (int i = 0; i < N; i++)
                for (int sh = 0; sh < 32; sh++) begin
                    check_model(op[3:0], edges[i], 32'(sh));
                    check_model(op[3:0], edges[i],
                                32'hffff_ffe0 | 32'(sh));
                end

        // Walking bits expose bit-lane and operand-selection mistakes.
        for (int op = 0; op < 11; op++)
            for (int bitno = 0; bitno < 32; bitno++) begin
                check_model(op[3:0], 32'h1 << bitno,
                            ~(32'h1 << bitno));
                check_model(op[3:0], ~(32'h1 << bitno),
                            32'h1 << bitno);
            end

        // Adjacent calls exercise A-only, B-only and control-only changes.
        check_model(ADD, 32'd1, 32'd2);
        check_model(ADD, 32'd4, 32'd2);
        check_model(ADD, 32'd4, 32'd3);
        check_model(SUB, 32'd4, 32'd3);
        check_model(PASS_B, 32'd4, 32'd3);
        check_model(PASS_B, 32'hffff_ffff, 32'd3);

        for (int sample = 0; sample < 200; sample++) begin
            ra = next_word();
            rb = next_word();
            for (int op = 0; op < 11; op++)
                check_model(op[3:0], ra, rb);
        end

        // Implementation fallback checks, not architectural requirements.
        // Nonzero predecessor makes a retained-result defect observable.
        for (int op = 11; op < 16; op++) begin
            check_model(PASS_B, 32'd0, 32'hdead_beef);
            check(op[3:0], 32'hffff_ffff, 32'hffff_ffff,
                  32'd0, "reserved-control fallback");
        end

        for (int op = 0; op < 11; op++)
            if (hits[op] == 0)
                $fatal(1, "Operation %0d was not exercised", op);

        if (failures != 0)
            $fatal(1, "%0d failures in %0d checks", failures, checks);

        $display("PASS: %0d checks; all 11 operations exercised", checks);
        $finish;
    end
endmodule