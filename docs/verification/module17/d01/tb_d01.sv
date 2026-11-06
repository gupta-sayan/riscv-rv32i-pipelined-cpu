`timescale 1ns/1ps
module tb_d01;
    logic clk = 0;
    logic rst = 1;
    integer failures = 0;
    rv32i_core_top dut (
        .clk(clk), .rst(rst),
        .imem_rdata(32'h00000013), .dmem_rdata(32'b0)
    );

    // Exercise the real top-level mux, isolated from pipeline/forwarding control.
    task automatic check(input [1:0] sel, input [31:0] expected);
        begin
            case (sel)
                0: force dut.u_pipeline_regs.idex_op_b_sel = 2'b00;
                1: force dut.u_pipeline_regs.idex_op_b_sel = 2'b01;
                2: force dut.u_pipeline_regs.idex_op_b_sel = 2'b10;
                3: force dut.u_pipeline_regs.idex_op_b_sel = 2'b11;
            endcase
            #1;
            if (dut.alu_operand_b !== expected) begin
                $display("FAIL selector=%b expected=%08h actual=%08h", sel, expected, dut.alu_operand_b);
                failures = failures + 1;
            end else
                $display("PASS selector=%b expected=%08h actual=%08h", sel, expected, dut.alu_operand_b);
        end
    endtask

    initial begin
        force dut.ex_rs2_forwarded = 32'ha5c35a3c;
        force dut.u_pipeline_regs.idex_imm = 32'h81234567;
        check(2'b00, 32'ha5c35a3c);
        check(2'b01, 32'h81234567);
        check(2'b10, 32'h00000004);
        check(2'b11, 32'h00000000);
        // Repeat with different inputs and transition order to detect stale data.
        force dut.ex_rs2_forwarded = 32'hffffffff;
        force dut.u_pipeline_regs.idex_imm = 32'h13579bdf;
        check(2'b01, 32'h13579bdf);
        check(2'b11, 32'h00000000);
        check(2'b00, 32'hffffffff);
        check(2'b10, 32'h00000004);
        release dut.u_pipeline_regs.idex_op_b_sel;
        release dut.ex_rs2_forwarded;
        release dut.u_pipeline_regs.idex_imm;
        if (failures != 0) $fatal(1, "D01 FAIL failures=%0d", failures);
        $display("PASS ALL D01 selectors=4 checks=8");
        $finish;
    end
    initial begin
        #100;
        $fatal(1, "D01 watchdog timeout");
    end
endmodule
