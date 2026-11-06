`timescale 1ns/1ps

// ARCH-001 Rev C sections 2.2, 6 and 8.5; authorized register-file unit test.
// Uses the existing reg_file port names. No internal DUT state is accessed.
module tb_reg_file;
    logic clk = 0;
    logic rst = 0;
    logic rd_we = 0;
    logic [4:0] rs1_addr = 0, rs2_addr = 0, rd_addr = 0;
    logic [31:0] rd_data = 0;
    wire [31:0] rs1_data, rs2_data;

    logic [31:0] model [0:31];
    bit known [0:31];
    integer write_hits [0:31];
    integer checks = 0, failures = 0, skipped = 0, cycles = 0;
    bit [31:0] rng = 32'h65ab_1234;
    logic [31:0] patterns [0:7];
    logic [31:0] random_data, control;
    integer i, j, p, b, round;

    reg_file dut (
        .clk(clk), .rst(rst),
        .rs1_addr(rs1_addr), .rs2_addr(rs2_addr),
        .rs1_data(rs1_data), .rs2_data(rs2_data),
        .rd_we(rd_we), .rd_addr(rd_addr), .rd_data(rd_data)
    );

    // Fixed, simulator-independent xorshift32 sequence.
    function automatic [31:0] next_word();
        begin
            rng = rng ^ (rng << 13);
            rng = rng ^ (rng >> 17);
            rng = rng ^ (rng << 5);
            next_word = rng;
        end
    endfunction

    task automatic check_port(input integer port_number,
                              input [4:0] address,
                              input [31:0] actual,
                              input string phase);
        begin
            if (known[address]) begin
                checks = checks + 1;
                if (actual !== model[address]) begin
                    failures = failures + 1;
                    if (failures <= 30)
                        $display("FAIL t=%0t cycle=%0d phase=%s port=%0d x%0d expected=%08h actual=%08h rst=%b we=%b rd=%0d data=%08h",
                                 $time, cycles, phase, port_number, address,
                                 model[address], actual, rst, rd_we,
                                 rd_addr, rd_data);
                end
            end else
                skipped = skipped + 1;
        end
    endtask

    task automatic check_outputs(input string phase);
        begin
            check_port(1, rs1_addr, rs1_data, phase);
            check_port(2, rs2_addr, rs2_data, phase);
        end
    endtask

    task automatic read_pair(input [4:0] a, input [4:0] b_addr,
                             input string phase);
        begin
            rs1_addr = a;
            rs2_addr = b_addr;
            #1;
            check_outputs(phase);
        end
    endtask

    // No clock edges during scans: both ports must respond asynchronously.
    task automatic scan_all(input string phase);
        integer address;
        begin
            for (address = 0; address < 32; address = address + 1)
                read_pair(address[4:0], 5'd31 - address[4:0], phase);
        end
    endtask

    // Inputs are driven with clk low. Verify the old state before the
    // rising edge, then the committed state after NBA/combinational settling.
    // No claim is made about sampling in the rising-edge active region.
    task automatic transaction(input bit reset_value,
                               input bit enable_value,
                               input [4:0] destination,
                               input [31:0] data_value,
                               input [4:0] read_a,
                               input [4:0] read_b);
        begin
            rst = reset_value;
            rd_we = enable_value;
            rd_addr = destination;
            rd_data = data_value;
            read_pair(read_a, read_b, "before rising edge");
            scan_all("before rising edge: no early write/reset clear");
            read_pair(read_a, read_b, "read/write collision before edge");
            clk = 1;
            cycles = cycles + 1;
            if (!reset_value && enable_value && destination != 0) begin
                model[destination] = data_value;
                known[destination] = 1;
                write_hits[destination] = write_hits[destination] + 1;
            end
            #1;
            check_outputs("after rising edge settled");
            scan_all("after rising edge: full state");
            // A different pending value exposes transparent-high or
            // falling-edge writes that repeating the same data would hide.
            rd_data = ~data_value;
            read_pair(read_a, read_b, "changed write data with clock high");
            scan_all("clock high: no transparent write");
            clk = 0;
            #1;
            check_outputs("after falling edge");
            scan_all("after falling edge: no write");
        end
    endtask

    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            known[i] = 0;
            write_hits[i] = 0;
        end
        known[0] = 1;
        model[0] = 0;
        patterns[0] = 32'h00000000;
        patterns[1] = 32'hffffffff;
        patterns[2] = 32'haaaaaaaa;
        patterns[3] = 32'h55555555;
        patterns[4] = 32'h80000000;
        patterns[5] = 32'h7fffffff;
        patterns[6] = 32'h00000001;
        patterns[7] = 32'hdeadbeef;

        // Startup checks only x0; never assume unwritten state is zero or X.
        read_pair(0, 0, "startup x0");
        transaction(1, 1, 0, 32'hffffffff, 0, 0);
        transaction(1, 1, 1, 32'h12345678, 0, 0);

        // Initialize every writable word through the public write port.
        // Distinct values expose address aliasing before uniform patterns.
        for (i = 1; i < 32; i = i + 1)
            transaction(0, 1, i[4:0], 32'hcafe0000 | i,
                        i[4:0], i[4:0]);

        // All address pairs; inner loop changes only port 2. Follow with
        // a port-1-only sweep while port 2 remains fixed.
        rd_we = 0;
        for (i = 0; i < 32; i = i + 1)
            for (j = 0; j < 32; j = j + 1)
                read_pair(i[4:0], j[4:0], "asynchronous address pairs");
        for (i = 0; i < 32; i = i + 1)
            read_pair(i[4:0], 17, "port 1 independently changing");

        for (p = 0; p < 8; p = p + 1)
            for (i = 1; i < 32; i = i + 1)
                transaction(0, 1, i[4:0], patterns[p],
                            i[4:0], 5'd31 - i[4:0]);

        // Every data bit, both polarities, at every writable address.
        for (b = 0; b < 32; b = b + 1)
            for (i = 1; i < 32; i = i + 1) begin
                transaction(0, 1, i[4:0], 32'h1 << b, 0, i[4:0]);
                transaction(0, 1, i[4:0], ~(32'h1 << b), i[4:0], 0);
            end

        // Disabled writes at every address, with guaranteed different data.
        for (i = 0; i < 32; i = i + 1)
            transaction(0, 0, i[4:0], ~model[i], i[4:0], i[4:0]);
        for (p = 0; p < 8; p = p + 1)
            transaction(0, 1, 0, patterns[p], 0, 0);

        // Reset assertion occurs with clk low. Scans check immediate
        // retention; rising-edge scans check suppression, then deassertion
        // checks retention again. All words are known at this point.
        for (i = 0; i < 32; i = i + 1)
            transaction(1, 1, i[4:0], ~model[i], i[4:0], i[4:0]);
        transaction(1, 0, 7, ~model[7], 7, 7);
        transaction(0, 0, 7, ~model[7], 7, 7);

        // Multiple reproducible random writes to every writable register.
        for (round = 0; round < 8; round = round + 1)
            for (i = 1; i < 32; i = i + 1) begin
                random_data = next_word();
                control = next_word();
                transaction(0, 1, i[4:0], random_data,
                            control[4:0], control[9:5]);
            end

        // Random controls, independent reads, resets and disabled writes.
        for (i = 0; i < 500; i = i + 1) begin
            control = next_word();
            random_data = next_word();
            transaction(control[0] && control[1], control[2],
                        control[7:3], random_data,
                        control[12:8], control[17:13]);
        end

        // Extended retention with changing disabled-write inputs.
        for (i = 0; i < 64; i = i + 1) begin
            random_data = next_word();
            transaction(0, 0, i[4:0], random_data,
                        i[4:0], 5'd31 - i[4:0]);
        end
        scan_all("final state");
        for (i = 1; i < 32; i = i + 1) begin
            checks = checks + 1;
            if (!known[i] || write_hits[i] < 81) begin
                failures = failures + 1;
                $display("FAIL coverage x%0d known=%b writes=%0d",
                         i, known[i], write_hits[i]);
            end
        end
        $display("SUMMARY checks=%0d failures=%0d cycles=%0d unknown-state comparisons skipped=%0d seed=65ab1234",
                 checks, failures, cycles, skipped);
        if (failures != 0)
            $fatal(1, "FAIL: register file unit test");
        $display("PASS: register file unit test");
        $finish;
    end

    initial begin
        #1000000;
        $fatal(1, "FAIL: watchdog timeout");
    end
endmodule
