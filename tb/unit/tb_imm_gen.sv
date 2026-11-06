`timescale 1ns/1ps

module tb_imm_gen;
    // Zero outputs for NONE/invalid codes are characterization checks
    // of the current implementation.
    parameter CHECK_ZERO_DEFAULTS = 1'b1;

    localparam [2:0] K_NONE = 3'b000;
    localparam [2:0] K_I    = 3'b001;
    localparam [2:0] K_S    = 3'b010;
    localparam [2:0] K_B    = 3'b011;
    localparam [2:0] K_U    = 3'b100;
    localparam [2:0] K_J    = 3'b101;

    logic [31:0] instr;
    logic [2:0]  imm_kind;
    wire  [31:0] imm;

    integer checks = 0;
    integer failures = 0;
    integer policy_checks = 0;
    integer policy_failures = 0;
    integer k, n, bit_index;
    reg [31:0] value;

    imm_gen dut (
        .instr(instr),
        .imm_kind(imm_kind),
        .imm(imm)
    );

    // Start with a background pattern, then overwrite only the
    // instruction bits belonging to the selected immediate format.
    function automatic [31:0] encode(
        input [2:0] kind,
        input [31:0] immediate_value,
        input [31:0] background
    );
        reg [31:0] word;
        begin
            word = background;
            case (kind)
                K_I: word[31:20] = immediate_value[11:0];

                K_S: begin
                    word[31:25] = immediate_value[11:5];
                    word[11:7]  = immediate_value[4:0];
                end

                K_B: begin
                    word[31]    = immediate_value[12];
                    word[7]     = immediate_value[11];
                    word[30:25] = immediate_value[10:5];
                    word[11:8]  = immediate_value[4:1];
                end

                K_U: word[31:12] = immediate_value[31:12];

                K_J: begin
                    word[31]    = immediate_value[20];
                    word[19:12] = immediate_value[19:12];
                    word[20]    = immediate_value[11];
                    word[30:21] = immediate_value[10:1];
                end

                default: begin end
            endcase
            encode = word;
        end
    endfunction

    task automatic check_raw(
        input [2:0] kind,
        input [31:0] word,
        input [31:0] expected,
        input policy_check
    );
        begin
            instr = word;
            imm_kind = kind;
            #1; // Allow combinational logic to settle.

            if (policy_check)
                policy_checks = policy_checks + 1;
            else
                checks = checks + 1;

            // Case inequality detects unexpected X/Z output bits.
            if (imm !== expected) begin
                if (policy_check)
                    policy_failures = policy_failures + 1;
                else
                    failures = failures + 1;

                // Bound diagnostics while retaining total counts.
                if ((failures + policy_failures) <= 20)
                    $display(
                    "FAIL policy=%0d kind=%03b instr=%08h expected=%08h actual=%08h",
                    policy_check, kind, word, expected, imm
                    );
            end
        end
    endtask

    task automatic check_value(
        input [2:0] kind,
        input [31:0] immediate_value
    );
        begin
            // Complementary backgrounds toggle every ignored bit.
            check_raw(kind,
                      encode(kind, immediate_value, 32'h00000000),
                      immediate_value, 1'b0);
            check_raw(kind,
                      encode(kind, immediate_value, 32'hffffffff),
                      immediate_value, 1'b0);
        end
    endtask

    initial begin
        instr = 0;
        imm_kind = K_NONE;

        // I and S: zero, positive, negative, signed minimum/maximum.
        for (k = 1; k <= 2; k = k + 1) begin
            check_value(k[2:0], 32'h00000000);
            check_value(k[2:0], 32'h00000001);
            check_value(k[2:0], 32'hffffffff);
            check_value(k[2:0], 32'hfffff800); // -2048
            check_value(k[2:0], 32'h000007ff); // +2047
        end

        // B: representable offsets are even; bit 1 must be retained.
        check_value(K_B, 32'h00000000);
        check_value(K_B, 32'h00000002);
        check_value(K_B, 32'hfffffffe); // -2
        check_value(K_B, 32'hfffff000); // -4096
        check_value(K_B, 32'h00000ffe); // +4094

        // U: signed interpretation of the resulting 32-bit pattern.
        check_value(K_U, 32'h00000000);
        check_value(K_U, 32'h00001000);
        check_value(K_U, 32'hfffff000); // -4096
        check_value(K_U, 32'h80000000); // Signed minimum
        check_value(K_U, 32'h7ffff000); // Signed maximum
        check_value(K_U, 32'h12345000);
        check_value(K_U, 32'hfffff000); // Maximum unsigned U pattern

        // J: even offsets, including bit-1-only and signed boundaries.
        check_value(K_J, 32'h00000000);
        check_value(K_J, 32'h00000002);
        check_value(K_J, 32'hfffffffe); // -2
        check_value(K_J, 32'hfff00000); // -1048576
        check_value(K_J, 32'h000ffffe); // +1048574

        // Exhaust every representable I, S and B immediate.
        for (n = -2048; n <= 2047; n = n + 1) begin
            check_value(K_I, n);
            check_value(K_S, n);
        end
        for (n = -4096; n <= 4094; n = n + 2)
            check_value(K_B, n);

        // J walking-one and walking-zero tests isolate every
        // non-sign payload bit and exercise negative sign extension.
        for (bit_index = 1; bit_index <= 19;
             bit_index = bit_index + 1) begin
            value = 32'h00000001 << bit_index;
            check_value(K_J, value);
            check_value(K_J, 32'hfffffffe ^ value);
        end
        check_value(K_J, 32'h000aaaaa);
        check_value(K_J, 32'hfff55554);

        // U walking-one/zero tests cover all 20 payload positions.
        for (bit_index = 12; bit_index <= 31;
             bit_index = bit_index + 1) begin
            value = 32'h00000001 << bit_index;
            check_value(K_U, value);
            check_value(K_U, 32'hfffff000 ^ value);
        end
        check_value(K_U, 32'haaaaa000);
        check_value(K_U, 32'h55555000);

        // Change imm_kind while holding instr constant.
        check_raw(K_I, 32'hffffffff, 32'hffffffff, 1'b0);
        check_raw(K_S, 32'hffffffff, 32'hffffffff, 1'b0);
        check_raw(K_B, 32'hffffffff, 32'hfffffffe, 1'b0);
        check_raw(K_U, 32'hffffffff, 32'hfffff000, 1'b0);
        check_raw(K_J, 32'hffffffff, 32'hfffffffe, 1'b0);

        if (CHECK_ZERO_DEFAULTS) begin
            // Check defaults after a nonzero result to detect retention.
            for (k = 0; k <= 7; k = k + 1) begin
                if ((k == 0) || (k == 6) || (k == 7)) begin
                    check_raw(K_I, 32'hfff00000,
                              32'hffffffff, 1'b0);
                    check_raw(k[2:0], 32'hffffffff,
                              32'h00000000, 1'b1);
                    check_raw(k[2:0], 32'h00000000,
                              32'h00000000, 1'b1);

                    // Toggle each instruction bit under each default.
                    for (bit_index = 0; bit_index < 32;
                         bit_index = bit_index + 1)
                        check_raw(k[2:0],
                                  32'h00000001 << bit_index,
                                  32'h00000000, 1'b1);
                end
            end
        end

        $display("Architecture checks=%0d failures=%0d",
                 checks, failures);
        $display("Proposed default checks=%0d failures=%0d",
                 policy_checks, policy_failures);

        if ((failures != 0) || (policy_failures != 0))
            $fatal(1, "imm_gen proposal checks failed");

        $display("PASS: all enabled proposal checks");
        $finish;
    end
endmodule
