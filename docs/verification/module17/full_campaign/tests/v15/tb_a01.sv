`timescale 1ns/1ps
module tb_a01;
    parameter bit TRACE_EN=1;
    reg clk=0,rst=1;
    always #5 clk=~clk;
    reg idex_valid,idex_uses_rs1,idex_uses_rs2,idex_is_store;
    reg exmem_valid,exmem_reg_write,exmem_result_ready,memwb_valid,memwb_reg_write;
    reg [4:0] idex_rs1,idex_rs2,exmem_rd,memwb_rd;
    wire [1:0] fwd_a_sel,fwd_b_sel,fwd_store_sel;
    wire fwd_nonready_error;
    forward_unit fu(.*);
    rv32i_core_top #(.TRACE_EN(TRACE_EN)) dut(.clk(clk),.rst(rst),.imem_rdata(32'h00000013),.dmem_rdata(32'b0));
    rv32i_core_top #(.TRACE_EN(TRACE_EN)) reference_core(.clk(clk),.rst(rst),.imem_rdata(32'h00000013),.dmem_rdata(32'b0));
    integer errors=0,vectors=0;
    task automatic check(input bit ok,input string msg);
        if(!ok) begin errors=errors+1; $display("FAIL A01 %s",msg); end
    endtask
    task automatic vector(input [1:0] a,b,store,input bit error_expected);
        begin #1;
            check({fwd_a_sel,fwd_b_sel,fwd_store_sel,fwd_nonready_error}==={a,b,store,error_expected},"forward select/error vector");
            vectors=vectors+1;
            $display("VECTOR %0d a=%b b=%b store=%b error=%b",vectors,fwd_a_sel,fwd_b_sel,fwd_store_sel,fwd_nonready_error);
        end
    endtask
    task automatic equivalent;
        begin
            check({dut.imem_addr,dut.imem_en,dut.fetch_issue,dut.hold_if,dut.bubble_ex,dut.dmem_re,dut.dmem_we,dut.wb_rd_we,dut.halted,dut.fault_pc,dut.fault_cause,dut.idex_valid,dut.exmem_valid,dut.memwb_valid}===
                  {reference_core.imem_addr,reference_core.imem_en,reference_core.fetch_issue,reference_core.hold_if,reference_core.bubble_ex,reference_core.dmem_re,reference_core.dmem_we,reference_core.wb_rd_we,reference_core.halted,reference_core.fault_pc,reference_core.fault_cause,reference_core.idex_valid,reference_core.exmem_valid,reference_core.memwb_valid},"injection changes scheduling/transactions/fault");
        end
    endtask
    initial begin
        idex_valid=1; idex_uses_rs1=1; idex_uses_rs2=1; idex_is_store=1;
        idex_rs1=7; idex_rs2=7; exmem_valid=1; exmem_rd=7; exmem_reg_write=1;
        exmem_result_ready=0; memwb_valid=1; memwb_rd=7; memwb_reg_write=1;
        vector(3,3,3,1); // Never select stale MEM/WB over youngest nonready producer.
        exmem_result_ready=1; vector(1,1,1,0);
        exmem_valid=0; vector(2,2,2,0);
        exmem_valid=1; exmem_result_ready=0;
        idex_uses_rs1=0; vector(0,3,3,1);
        idex_uses_rs2=0; vector(0,0,0,0);
        idex_uses_rs1=1; vector(3,0,0,1);
        idex_valid=0; vector(0,0,0,0);
        idex_valid=1; exmem_rd=0; memwb_rd=0; idex_rs1=0; vector(0,0,0,0);
        repeat(2) begin @(posedge clk); #1; check(!dut.fwd_nonready_sticky,"reset clears sticky"); end
        @(negedge clk); rst=0;
        repeat(5) begin @(posedge clk); #1; equivalent(); end
        @(negedge clk);
        // Diagnostic-only integration injection, not a naturally executed instruction.
        force dut.u_forward_unit.fwd_nonready_error=1'b1;
        #1; equivalent(); check(!dut.fwd_nonready_sticky,"sticky is sequential");
        @(posedge clk); #1; check(dut.fwd_nonready_sticky,"positive sticky capture"); equivalent();
        @(negedge clk); force dut.u_forward_unit.fwd_nonready_error=1'b0;
        // Explicitly remove the injected error: release of a procedural variable
        // alone need not trigger always_comb when all NOP input controls are static.
        repeat(5) begin @(posedge clk); #1;
            check(!dut.fwd_nonready_error,"injected error explicitly removed");
            check(dut.fwd_nonready_sticky,"sticky retained with error absent"); equivalent();
        end
        @(negedge clk); rst=1; #1; check(dut.fwd_nonready_sticky,"no asynchronous sticky reset");
        @(posedge clk); #1; check(!dut.fwd_nonready_sticky,"active reset clears sticky"); equivalent();
        release dut.u_forward_unit.fwd_nonready_error;
        if(errors) $fatal(1,"A01 errors=%0d",errors);
        $display("PASS ALL A01 vectors=%0d trace=%0d",vectors,TRACE_EN); $finish;
    end
    initial begin #5000; $fatal(1,"A01 watchdog"); end
endmodule
