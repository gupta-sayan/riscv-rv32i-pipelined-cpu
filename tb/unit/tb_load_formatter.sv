// MODULE 06 local development verification; ARCH-001 Rev C §§4.2, 5.3, 8.4.
// Class A testbench addition under the explicit Load Formatter task.
// Legal accesses only; EX/LSU owns alignment faults. Reserved-size zero is
// checked separately as an implementation fallback, not an ISA requirement.
module tb_load_formatter;
    timeunit 1ns;
    timeprecision 1ps;

    logic [31:0] dmem_rdata, load_result;
    logic [1:0] load_lane, mem_size;
    logic load_unsigned;
    int checks = 0, failures = 0, legal_checks = 0, fallback_checks = 0;
    int hits [0:4][0:3]; // LB, LBU, LH, LHU, LW by byte offset
    bit [31:0] rng = 32'h06fa_2026;
    logic [31:0] words [0:7];
    logic [31:0] word_value;

    load_formatter dut (
        .dmem_rdata(dmem_rdata), .load_lane(load_lane), .mem_size(mem_size),
        .load_unsigned(load_unsigned), .load_result(load_result)
    );

    function automatic bit [31:0] next_word();
        rng = rng ^ (rng << 13);
        rng = rng ^ (rng >> 17);
        rng = rng ^ (rng << 5);
        return rng;
    endfunction

    // Independent bit-address model: no RTL lane cases or concatenated
    // extension expressions. A selected sign bit fills each upper bit.
    function automatic logic [31:0] reference_load(
        input logic [31:0] word_in,
        input logic [1:0] lane, size,
        input logic unsigned_load
    );
        int width_bits, first_bit;
        logic [31:0] result_value;
        width_bits = 8 * (1 << int'(size));
        first_bit = 8 * int'(lane);
        result_value = 0;
        if (size == 3) return result_value;
        for (int bit_index = 0; bit_index < 32; bit_index++) begin
            if (bit_index < width_bits)
                result_value[bit_index] = word_in[first_bit + bit_index];
            else if (!unsigned_load)
                result_value[bit_index] = word_in[first_bit + width_bits - 1];
        end
        return result_value;
    endfunction

    task automatic check(
        input logic [31:0] word_in,
        input logic [1:0] lane, size,
        input logic unsigned_load,
        input logic [31:0] expected,
        input string label_text
    );
        bit [2:0] operation;
        if ((size == 1 && lane[0]) ||
            (size == 2 && (lane != 0 || unsigned_load)))
            $fatal(1, "Testbench attempted unsupported load combination");
        dmem_rdata = word_in; load_lane = lane;
        mem_size = size; load_unsigned = unsigned_load;
        #1ns;
        checks++;
        if (size == 3) fallback_checks++;
        else begin
            legal_checks++;
            operation = (size == 0) ? {2'b0, unsigned_load} :
                        ((size == 1) ? 3'd2 + {2'b0, unsigned_load} : 3'd4);
            hits[operation][int'(lane)]++;
        end
        if (load_result !== expected) begin
            failures++;
            if (failures <= 20)
                $display("FAIL #%0d %s word=%08h lane=%0d size=%b unsigned=%b expected=%08h got=%08h",
                         checks, label_text, word_in, lane, size,
                         unsigned_load, expected, load_result);
        end
    endtask

    task automatic check_model(
        input logic [31:0] word_in,
        input logic [1:0] lane, size,
        input logic unsigned_load
    );
        check(word_in, lane, size, unsigned_load,
              reference_load(word_in, lane, size, unsigned_load), "model");
    endtask

    task automatic all_loads(input logic [31:0] word_in);
        for (int lane = 0; lane < 4; lane++) begin
            check_model(word_in, 2'(lane), 0, 0);
            check_model(word_in, 2'(lane), 0, 1);
        end
        for (int lane = 0; lane < 4; lane += 2) begin
            check_model(word_in, 2'(lane), 1, 0);
            check_model(word_in, 2'(lane), 1, 1);
        end
        check_model(word_in, 0, 2, 0);
    endtask

    initial begin
        for (int op = 0; op < 5; op++)
            for (int lane = 0; lane < 4; lane++) hits[op][lane] = 0;
        $display("MODULE06 seed=06fa2026 random_words=2000");
        // Literal anchors independently check the reference-model conventions.
        check(32'h1234_5680, 0, 0, 0, 32'hffff_ff80, "LB 80");
        check(32'h8034_5678, 3, 0, 1, 32'h0000_0080, "LBU 80");
        check(32'h1234_8000, 0, 1, 0, 32'hffff_8000, "LH 8000");
        check(32'h8000_1234, 2, 1, 1, 32'h0000_8000, "LHU 8000");
        check(32'ha1b2_c3d4, 0, 2, 0, 32'ha1b2_c3d4, "LW unchanged");

        // Every byte value at every lane, with other lanes deliberately different.
        for (int value = 0; value < 256; value++)
            for (int lane = 0; lane < 4; lane++) begin
                word_value = (32'ha15c_e739 & ~(32'hff << (8 * lane))) |
                             (32'(value) << (8 * lane));
                check_model(word_value, 2'(lane), 0, 0);
                check_model(word_value, 2'(lane), 0, 1);
            end
        // All 65536 halfwords, both legal positions and extension modes.
        for (int value = 0; value < 65536; value++)
            for (int lane = 0; lane < 4; lane += 2) begin
                word_value = (32'h5aa5_c33c & ~(32'hffff << (8 * lane))) |
                             (32'(value) << (8 * lane));
                check_model(word_value, 2'(lane), 1, 0);
                check_model(word_value, 2'(lane), 1, 1);
            end

        words[0] = 0; words[1] = 32'hffff_ffff;
        words[2] = 32'h7fff_ffff; words[3] = 32'h8000_0000;
        words[4] = 32'ha1b2_c3d4; words[5] = 32'h807f_ff00;
        words[6] = 32'h8000_7fff; words[7] = 32'h0102_0408;
        for (int i = 0; i < 8; i++) all_loads(words[i]);
        for (int bit_index = 0; bit_index < 32; bit_index++) begin
            all_loads(32'h1 << bit_index);
            all_loads(~(32'h1 << bit_index));
        end
        for (int sample = 0; sample < 2000; sample++) begin
            word_value = next_word();
            all_loads(word_value);
        end
        // Nonzero predecessor exposes retained outputs on reserved-size entry.
        for (int lane = 0; lane < 4; lane++)
            for (int unsigned_mode = 0; unsigned_mode < 2; unsigned_mode++) begin
                check_model(32'hffff_ffff, 0, 2, 0);
                check(32'ha1b2_c3d4, 2'(lane), 3, 1'(unsigned_mode),
                      0, "reserved-size fallback");
            end
        for (int op = 0; op < 5; op++)
            for (int lane = 0; lane < 4; lane++) begin
                $display("coverage op=%0d lane=%0d vectors=%0d", op, lane, hits[op][lane]);
                if ((op < 2 || (op < 4 && lane % 2 == 0) || lane == 0) &&
                    hits[op][lane] == 0) $fatal(1, "Missing legal coverage bin");
            end
        $display("total=%0d legal=%0d fallback=%0d passing=%0d failing=%0d",
                 checks, legal_checks, fallback_checks, checks - failures, failures);
        if (failures != 0) $fatal(1, "Load Formatter verification failed");
        $display("PASS");
        $finish;
    end
endmodule
