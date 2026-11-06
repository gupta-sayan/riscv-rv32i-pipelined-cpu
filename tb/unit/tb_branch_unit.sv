module tb_branch_unit;
    timeunit 1ns;
    timeprecision 1ps;

    logic [31:0] rs1, rs2, pc, imm, redirect_pc;
    logic [2:0] br_kind;
    logic is_jal, is_jalr, redirect_valid, target_misaligned;
    int checks = 0, failures = 0, fallback_checks = 0;
    int carry_cases = 0;
    int outcomes [1:6][0:1];
    int alignment [0:2][0:3];
    bit [31:0] rng = 32'hb12a_2026;
    logic [31:0] edges [0:7];
    logic [31:0] a, b, p, offset;

    branch_unit dut (.*);

    // Explicit xorshift32 state: no simulator-dependent random sequencing.
    function automatic bit [31:0] next_word();
        rng = rng ^ (rng << 13);
        rng = rng ^ (rng >> 17);
        rng = rng ^ (rng << 5);
        return rng;
    endfunction

    task automatic check(
        input logic [2:0] kind,
        input logic jal, jalr,
        input logic [31:0] x, y, address, displacement
    );
        bit taken, active, bad;
        logic [32:0] sum;
        logic [31:0] target;
        bit signed_less;
        // Signed order modeled by sign-bit bias rather than RTL signed casts.
        signed_less = ((x ^ 32'h8000_0000) < (y ^ 32'h8000_0000));
        case (kind)
            1: taken = (x == y);
            2: taken = (x != y);
            3: taken = signed_less;
            4: taken = !signed_less;
            5: taken = (x < y);
            6: taken = !(x < y);
            default: taken = 0;
        endcase
        active = jal || jalr || taken;
        sum = {1'b0, (jalr ? x : address)} + {1'b0, displacement};
        target = sum[31:0];
        if (jalr) target[0] = 0;
        bad = active && ((target % 32'd4) != 0);
        if (!active) target = 0;

        rs1 = x; rs2 = y; pc = address; imm = displacement;
        br_kind = kind; is_jal = jal; is_jalr = jalr;
        #1ns;
        checks++;
        if (active && sum[32]) carry_cases++;
        // Reserved controls, overlapping controls and inactive target zero are
        // implementation fallback observations, not new ARCH-001 requirements.
        if (kind == 7 || (jal && jalr) || ((jal || jalr) && kind != 0))
            fallback_checks++;
        else begin
            if (kind >= 1 && kind <= 6) outcomes[kind][int'(taken)]++;
            if (active) alignment[jalr ? 2 : (jal ? 1 : 0)][int'(sum[1:0])]++;
        end
        if (redirect_valid !== (active && !bad) ||
            target_misaligned !== bad || redirect_pc !== target) begin
            failures++;
            $display("FAIL #%0d kind=%0d jal=%b jalr=%b rs1=%h rs2=%h pc=%h imm=%h expected=%b/%h/%b got=%b/%h/%b",
                     checks, kind, jal, jalr, x, y, address, displacement,
                     active && !bad, target, bad,
                     redirect_valid, redirect_pc, target_misaligned);
        end
    endtask

    initial begin
        edges[0] = 0; edges[1] = 1; edges[2] = 2;
        edges[3] = 32'h7fff_fffe; edges[4] = 32'h7fff_ffff;
        edges[5] = 32'h8000_0000; edges[6] = 32'h8000_0001;
        edges[7] = 32'hffff_ffff;
        for (int k = 1; k <= 6; k++)
            for (int t = 0; t < 2; t++) outcomes[k][t] = 0;
        for (int k = 0; k < 3; k++)
            for (int lane = 0; lane < 4; lane++) alignment[k][lane] = 0;
        $display("Seed=b12a2026; 2000 random tuples; fixed directed matrix");

        // All comparisons, equality and both operand orders, all target lanes.
        for (int k = 1; k <= 6; k++)
            for (int i = 0; i < 8; i++)
                for (int j = 0; j < 8; j++)
                    for (int lane = 0; lane < 4; lane++) begin
                        check(3'(k), 0, 0, edges[i], edges[j], 32'h100, 32'(lane));
                        check(3'(k), 0, 0, edges[i], edges[j], 32'hffff_fffc, 32'(lane + 4));
                    end
        // PC and base selection, negative offsets, carry wrap and every raw
        // low-bit combination. JALR alignment is checked AFTER bit-0 clearing.
        for (int i = 0; i < 8; i++)
            for (int j = 0; j < 8; j++)
                for (int lane = 0; lane < 4; lane++) begin
                    check(0, 1, 0, ~edges[i], 0, edges[i], edges[j] + 32'(lane));
                    check(0, 0, 1, edges[i], 0, ~edges[i], edges[j] + 32'(lane));
                end

        for (int sample = 0; sample < 2000; sample++) begin
            a = next_word(); b = next_word();
            p = next_word(); offset = next_word();
            for (int k = 0; k <= 7; k++)
                check(3'(k), 0, 0, a, b, p, offset);
            check(0, 1, 0, a, b, p, offset);
            check(0, 0, 1, a, b, p, offset);
        end
        // Precede inactive/reserved controls by active outputs to detect stale
        // combinational values. Exercise current JALR priority as fallback only.
        for (int k = 0; k <= 7; k++) begin
            check(0, 1, 0, 32'h100, 0, 32'h200, 4);
            check(3'(k), 1, 1, 32'h101, 0, 32'h200, 4);
            check(0, 0, 0, 0, 0, 32'h202, 0);
            check(7, 0, 0, 0, 0, 32'h202, 0);
        end
        for (int k = 1; k <= 6; k++) begin
            $display("branch kind=%0d untaken=%0d taken=%0d", k, outcomes[k][0], outcomes[k][1]);
            for (int t = 0; t < 2; t++)
                if (outcomes[k][t] == 0) $fatal(1, "Missing branch outcome");
        end
        for (int k = 0; k < 3; k++)
            for (int lane = 0; lane < 4; lane++) begin
                $display("target class=%0d raw_sum_lane=%0d hits=%0d", k, lane, alignment[k][lane]);
                if (alignment[k][lane] == 0) $fatal(1, "Missing target lane");
            end
        $display("checks=%0d fallback_vectors=%0d failures=%0d", checks, fallback_checks, failures);
        $display("active addition carry cases=%0d", carry_cases);
        if (carry_cases == 0) $fatal(1, "Missing wraparound coverage");
        if (failures != 0) $fatal(1, "Branch unit verification failed");
        $display("PASS");
        $finish;
    end
endmodule
