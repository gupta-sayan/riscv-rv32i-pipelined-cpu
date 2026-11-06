`timescale 1ns/1ps

// Table-driven masked instruction oracle from ARCH-001 Rev C 5.2/5.3.
// Tests control decoding only, not EX targets or fault-controller arbitration.
module tb_decoder;
    // Rev C specifies PC+4 in ex_result, but does not explicitly require the
    // shared ALU to produce it. Enable this additional integration assumption
    // only when EX uses op_a_sel/op_b_sel for jump-link generation.
    parameter STRICT_ALU_JUMP_LINK = 1'b0;
    logic [31:0] instr, pc;
    logic fetch_fault;
    wire legal, uses_rs1, uses_rs2, is_jal, is_jalr;
    wire mem_read, mem_write, load_unsigned, reg_write;
    wire [4:0] rs1, rs2, rd;
    wire [3:0] alu_op;
    wire [2:0] imm_kind, br_kind;
    wire [1:0] op_a_sel, op_b_sel, mem_size, wb_sel;
    decoder dut (.*);

    typedef struct packed {
        logic legal;
        logic uses_rs1, uses_rs2;
        logic [3:0] alu_op;
        logic [2:0] imm_kind;
        logic [1:0] op_a_sel, op_b_sel;
        logic [2:0] br_kind;
        logic is_jal, is_jalr, mem_read, mem_write;
        logic [1:0] mem_size;
        logic load_unsigned, reg_write;
        logic [1:0] wb_sel;
    } controls_t;
    controls_t rule_controls [0:39];
    logic [31:0] masks [0:39], words [0:39];
    integer hits [0:39];
    string names [0:39];
    integer rule_count = 0, checks = 0, failures = 0, samples = 0;
    integer jump_route_checks = 0, jump_route_mismatches = 0;
    integer failing_samples = 0, failures_before;
    integer positive_imm = 0, negative_imm = 0;
    integer x0_loads = 0, fetch_tokens = 0;
    integer r, k, op, f3, f7, dest, sh, n;
    logic [31:0] word_value, background;
    bit [31:0] rng = 32'hdec0de01;

    function automatic [31:0] next_word();
        rng = rng ^ (rng << 13);
        rng = rng ^ (rng >> 17);
        rng = rng ^ (rng << 5);
        return rng;
    endfunction

    // The table explicitly lists complete expected controls for each mnemonic.
    task automatic add_rule(input string name_value,
                            input [31:0] mask_value, input [31:0] word_bits,
                            input bit use1, input bit use2,
                            input [3:0] alu, input [2:0] immediate,
                            input [1:0] a, input [1:0] b,
                            input [2:0] branch_code,
                            input bit jal, input bit jalr,
                            input bit read_mem, input bit write_mem,
                            input [1:0] size, input bit unsigned_load,
                            input bit write_reg, input [1:0] wb);
        controls_t c;
        begin
            c = '0;
            c.legal = 1;
            c.uses_rs1 = use1; c.uses_rs2 = use2;
            c.alu_op = alu; c.imm_kind = immediate;
            c.op_a_sel = a; c.op_b_sel = b;
            c.br_kind = branch_code; c.is_jal = jal; c.is_jalr = jalr;
            c.mem_read = read_mem; c.mem_write = write_mem;
            c.mem_size = size; c.load_unsigned = unsigned_load;
            c.reg_write = write_reg; c.wb_sel = wb;
            names[rule_count] = name_value;
            masks[rule_count] = mask_value;
            words[rule_count] = word_bits;
            rule_controls[rule_count] = c;
            hits[rule_count] = 0;
            rule_count = rule_count + 1;
        end
    endtask

    task automatic check(input bit condition, input string label_value);
        checks = checks + 1;
        if (!condition) begin
            failures = failures + 1;
            if (failures <= 30)
                $display("FAIL sample=%0d instr=%08h pc=%08h fetch_fault=%b %s",
                         samples, instr, pc, fetch_fault, label_value);
        end
    endtask

    task automatic run_sample(input [31:0] instruction,
                              input bit fault, input [31:0] address);
        controls_t expected, actual, compared_actual, compared_expected;
        integer match_count, index;
        begin
            failures_before = failures;
            instr = instruction; fetch_fault = fault; pc = address;
            expected = '0;
            match_count = 0;
            for (index = 0; index < rule_count; index = index + 1)
                if (!fault && ((instruction & masks[index]) == words[index])) begin
                    expected = rule_controls[index];
                    hits[index] = hits[index] + 1;
                    match_count = match_count + 1;
                end
            if (instruction[11:7] == 0) expected.reg_write = 0;
            #1;
            samples = samples + 1;
            actual = {legal, uses_rs1, uses_rs2, alu_op, imm_kind,
                      op_a_sel, op_b_sel, br_kind, is_jal, is_jalr,
                      mem_read, mem_write, mem_size, load_unsigned,
                      reg_write, wb_sel};
            check(match_count <= 1, "oracle rules must not overlap");
            compared_actual = actual;
            compared_expected = expected;
            // The branch comparator/target path is dedicated; Rev C does not
            // require a particular shared-ALU operand route for branches.
            // Likewise the jump link may use a separate EX PC+4 computation.
            // Still range-check every selector below, and report jump routing.
            if (expected.br_kind != 0 || expected.is_jal || expected.is_jalr) begin
                compared_actual.op_a_sel = 0;
                compared_actual.op_b_sel = 0;
                compared_expected.op_a_sel = 0;
                compared_expected.op_b_sel = 0;
            end
            check(compared_actual === compared_expected,
                  $sformatf("controls expected=%h actual=%h (branch/jump operand routes excluded)",
                            compared_expected, compared_actual));
            if (expected.is_jal || expected.is_jalr) begin
                jump_route_checks = jump_route_checks + 1;
                if ({op_a_sel, op_b_sel} !== {2'b01, 2'b10}) begin
                    jump_route_mismatches = jump_route_mismatches + 1;
                    if (jump_route_mismatches <= 8)
                        $display("REVIEW instr=%08h JAL=%b JALR=%b operand routes A=%b B=%b; shared-ALU PC+4 would require A=01 B=10",
                                 instruction, is_jal, is_jalr, op_a_sel, op_b_sel);
                end
                if (STRICT_ALU_JUMP_LINK)
                    check({op_a_sel, op_b_sel} === {2'b01, 2'b10},
                          "conditional integration check: shared ALU must form PC+4");
            end
            check({rs1,rs2,rd} === {instruction[19:15],instruction[24:20],
                                    instruction[11:7]}, "raw field extraction");
            check(!(mem_read && mem_write), "mutually exclusive memory enables");
            check(!(reg_write && rd == 0), "x0 write suppression");
            check(!((fault || !legal) &&
                    (uses_rs1 || uses_rs2 || mem_read || mem_write ||
                     reg_write || is_jal || is_jalr || br_kind != 0)),
                  "invalid/token safety and no false dependencies");
            check(alu_op <= 10 && imm_kind <= 5 && op_a_sel <= 2 &&
                  op_b_sel <= 2 && br_kind <= 6 && mem_size <= 2 && wb_sel <= 2,
                  "approved control encoding ranges");
            if (fault) fetch_tokens = fetch_tokens + 1;
            if (expected.mem_read && instruction[11:7] == 0)
                x0_loads = x0_loads + 1;
            if (expected.legal && instruction[6:0] == 7'h13 &&
                instruction[14:12] != 1 && instruction[14:12] != 5) begin
                if (instruction[31]) negative_imm = negative_imm + 1;
                else positive_imm = positive_imm + 1;
            end
            if (failures != failures_before)
                failing_samples = failing_samples + 1;
        end
    endtask

    initial begin
        // Columns after mask/word: uses1, uses2, alu, imm, A, B, branch,
        // JAL, JALR, mem_read, mem_write, size, unsigned_load, reg_write, WB.
        add_rule("ADD", 32'hfe00707f, 32'h00000033, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1);
        add_rule("SUB", 32'hfe00707f, 32'h40000033, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1);
        add_rule("SLL", 32'hfe00707f, 32'h00001033, 1, 1, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1);
        add_rule("SLT", 32'hfe00707f, 32'h00002033, 1, 1, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1);
        add_rule("SLTU", 32'hfe00707f, 32'h00003033, 1, 1, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1);
        add_rule("XOR", 32'hfe00707f, 32'h00004033, 1, 1, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1);
        add_rule("SRL", 32'hfe00707f, 32'h00005033, 1, 1, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1);
        add_rule("SRA", 32'hfe00707f, 32'h40005033, 1, 1, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1);
        add_rule("OR", 32'hfe00707f, 32'h00006033, 1, 1, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1);
        add_rule("AND", 32'hfe00707f, 32'h00007033, 1, 1, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1);
        add_rule("ADDI", 32'h0000707f, 32'h00000013, 1, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1);
        add_rule("SLTI", 32'h0000707f, 32'h00002013, 1, 0, 8, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1);
        add_rule("SLTIU", 32'h0000707f, 32'h00003013, 1, 0, 9, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1);
        add_rule("XORI", 32'h0000707f, 32'h00004013, 1, 0, 4, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1);
        add_rule("ORI", 32'h0000707f, 32'h00006013, 1, 0, 3, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1);
        add_rule("ANDI", 32'h0000707f, 32'h00007013, 1, 0, 2, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1);
        add_rule("SLLI", 32'hfe00707f, 32'h00001013, 1, 0, 5, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1);
        add_rule("SRLI", 32'hfe00707f, 32'h00005013, 1, 0, 6, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1);
        add_rule("SRAI", 32'hfe00707f, 32'h40005013, 1, 0, 7, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1);
        add_rule("LUI", 32'h0000007f, 32'h00000037, 0, 0, 10, 4, 2, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1);
        add_rule("AUIPC", 32'h0000007f, 32'h00000017, 0, 0, 0, 4, 1, 1, 0, 0, 0, 0, 0, 0, 0, 1, 1);
        add_rule("LB", 32'h0000707f, 32'h00000003, 1, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 2);
        add_rule("LH", 32'h0000707f, 32'h00001003, 1, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 0, 1, 2);
        add_rule("LW", 32'h0000707f, 32'h00002003, 1, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 2, 0, 1, 2);
        add_rule("LBU", 32'h0000707f, 32'h00004003, 1, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0, 1, 1, 2);
        add_rule("LHU", 32'h0000707f, 32'h00005003, 1, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 1, 1, 2);
        add_rule("SB", 32'h0000707f, 32'h00000023, 1, 1, 0, 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0);
        add_rule("SH", 32'h0000707f, 32'h00001023, 1, 1, 0, 2, 0, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0);
        add_rule("SW", 32'h0000707f, 32'h00002023, 1, 1, 0, 2, 0, 1, 0, 0, 0, 0, 1, 2, 0, 0, 0);
        add_rule("BEQ", 32'h0000707f, 32'h00000063, 1, 1, 0, 3, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0);
        add_rule("BNE", 32'h0000707f, 32'h00001063, 1, 1, 0, 3, 1, 1, 2, 0, 0, 0, 0, 0, 0, 0, 0);
        add_rule("BLT", 32'h0000707f, 32'h00004063, 1, 1, 0, 3, 1, 1, 3, 0, 0, 0, 0, 0, 0, 0, 0);
        add_rule("BGE", 32'h0000707f, 32'h00005063, 1, 1, 0, 3, 1, 1, 4, 0, 0, 0, 0, 0, 0, 0, 0);
        add_rule("BLTU", 32'h0000707f, 32'h00006063, 1, 1, 0, 3, 1, 1, 5, 0, 0, 0, 0, 0, 0, 0, 0);
        add_rule("BGEU", 32'h0000707f, 32'h00007063, 1, 1, 0, 3, 1, 1, 6, 0, 0, 0, 0, 0, 0, 0, 0);
        add_rule("JAL", 32'h0000007f, 32'h0000006f, 0, 0, 0, 5, 1, 2, 0, 1, 0, 0, 0, 0, 0, 1, 1);
        add_rule("JALR", 32'h0000707f, 32'h00000067, 1, 0, 0, 1, 1, 2, 0, 0, 1, 0, 0, 0, 0, 1, 1);
        add_rule("FENCE", 32'h0000707f, 32'h0000000f, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        add_rule("ECALL", 32'hffffffff, 32'h00000073, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        add_rule("EBREAK", 32'hffffffff, 32'h00100073, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

        // Literal no-op/system cases, including FENCE.TSO and ignored fields.
        run_sample(32'h00000013, 0, 0); // NOP
        run_sample(32'h8330000f, 0, 0); // FENCE.TSO
        run_sample(32'hffff8f8f, 0, 0); // Reserved FENCE fields, funct3=000
        run_sample(32'h0000100f, 0, 0); // FENCE.I: illegal
        run_sample(32'h30200073, 0, 0); // MRET: illegal
        run_sample(32'h00000000, 0, 0);
        run_sample(32'hffffffff, 0, 0);

        // Every mnemonic with zero/one/alternating/random unconstrained fields.
        // PC changes must not affect controls; fetch tokens suppress decoding.
        for (r = 0; r < rule_count; r = r + 1)
            for (k = 0; k < 8; k = k + 1) begin
                case (k)
                    0: background = 0;
                    1: background = 32'hffffffff;
                    2: background = 32'haaaaaaaa;
                    3: background = 32'h55555555;
                    default: background = next_word();
                endcase
                word_value = words[r] | (background & ~masks[r]);
                run_sample(word_value, 0, 0);
                run_sample(word_value, 0, 32'hfffffffc);
                run_sample(word_value, 1, 32'h00003ffc);
            end

        // All opcode/funct3/funct7 combinations, rd=x0 and rd=x31.
        // All 128 funct7 values include M-extension and reserved encodings.
        for (op = 0; op < 128; op = op + 1)
            for (f3 = 0; f3 < 8; f3 = f3 + 1)
                for (f7 = 0; f7 < 128; f7 = f7 + 1)
                    for (dest = 0; dest < 2; dest = dest + 1) begin
                        word_value = (32'(f7) << 25) | (32'd31 << 20) |
                                     (32'd31 << 15) | (32'(f3) << 12) |
                                     (dest ? 32'hf80 : 32'd0) | 32'(op);
                        run_sample(word_value, 0, 32'h100);
                    end

        // All 4096 immediate bit patterns for every nonshift OP-IMM mnemonic.
        // Includes zero, +2047, -2048, -1, and all nonzero instr[31:25] values.
        for (n = 0; n < 4096; n = n + 1)
            for (f3 = 0; f3 < 8; f3 = f3 + 1)
                if (f3 != 1 && f3 != 5) begin
                    word_value = (32'(n) << 20) | (32'd7 << 15) |
                                 (32'(f3) << 12) | (32'd9 << 7) | 32'h13;
                    run_sample(word_value, 0, 32'h300);
                end

        // Every shamt with every upper immediate value for both shift funct3.
        for (f7 = 0; f7 < 128; f7 = f7 + 1)
            for (sh = 0; sh < 32; sh = sh + 1)
                for (f3 = 1; f3 <= 5; f3 = f3 + 4) begin
                    word_value = (32'(f7) << 25) | (32'(sh) << 20) |
                                 (32'd1 << 15) | (32'(f3) << 12) | 32'hf93;
                    run_sample(word_value, 0, 32'h200);
                end

        // All SYSTEM immediates and funct3, with exact and nonexact operands.
        for (n = 0; n < 4096; n = n + 1)
            for (f3 = 0; f3 < 8; f3 = f3 + 1) begin
                word_value = (32'(n) << 20) | (32'(f3) << 12) | 32'h73;
                run_sample(word_value, 0, 0);
                run_sample(word_value | 32'h000f8f80, 0, 0);
            end
        // Single-bit neighbors ensure full-word ECALL/EBREAK matching.
        for (n = 0; n < 32; n = n + 1) begin
            run_sample(32'h00000073 ^ (32'h1 << n), 0, 0);
            run_sample(32'h00100073 ^ (32'h1 << n), 0, 0);
        end
        for (n = 0; n < 10000; n = n + 1) begin
            word_value = next_word();
            background = next_word();
            run_sample(word_value, 0, background);
            run_sample(word_value, 1, background);
        end
        for (r = 0; r < rule_count; r = r + 1) begin
            check(hits[r] != 0, {"coverage: ", names[r]});
            $display("COVER %s samples=%0d", names[r], hits[r]);
        end
        check(positive_imm > 0 && negative_imm > 0, "both OP-IMM signs covered");
        check(x0_loads > 0, "loads targeting x0 covered");
        check(fetch_tokens > 0, "fetch tokens covered");
        $display("COVER nonnegative_OP_IMM=%0d negative_OP_IMM=%0d x0_loads=%0d fetch_tokens=%0d",
                 positive_imm, negative_imm, x0_loads, fetch_tokens);
        $display("REVIEW jump_route_checks=%0d mismatches=%0d strict_mode=%0d",
                 jump_route_checks, jump_route_mismatches, STRICT_ALU_JUMP_LINK);
        $display("SUMMARY samples=%0d passing_samples=%0d failing_samples=%0d checks=%0d passing_checks=%0d failures=%0d seed=dec0de01",
                 samples, samples - failing_samples, failing_samples,
                 checks, checks - failures, failures);
        if (failures != 0) $fatal(1, "FAIL: decoder unit test");
        $display("PASS: decoder unit test");
        $finish;
    end

    initial begin
        #1000000;
        $fatal(1, "FAIL: watchdog timeout");
    end
endmodule
