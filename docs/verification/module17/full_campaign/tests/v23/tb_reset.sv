`timescale 1ns/1ps
module tb_reset;
    parameter bit TRACE_EN=1;
    reg clk=0,rst=1;
    always #5 clk=~clk;
    wire [31:0] imem_addr,imem_rdata,dmem_addr,dmem_wdata,dmem_rdata;
    wire imem_en,dmem_re,dmem_we,halted;
    wire [3:0] dmem_wmask,fault_cause;
    wire [31:0] fault_pc;
    rv32i_core_top #(.TRACE_EN(TRACE_EN)) dut(.clk(clk),.rst(rst),.imem_addr(imem_addr),.imem_en(imem_en),.imem_rdata(imem_rdata),
        .dmem_addr(dmem_addr),.dmem_re(dmem_re),.dmem_we(dmem_we),.dmem_wmask(dmem_wmask),.dmem_wdata(dmem_wdata),.dmem_rdata(dmem_rdata),
        .halted(halted),.fault_pc(fault_pc),.fault_cause(fault_cause));
    imem_sync imem(.clk(clk),.imem_en(imem_en),.imem_addr(imem_addr),.imem_rdata(imem_rdata));
    dmem_sync dmem(.clk(clk),.dmem_addr(dmem_addr),.dmem_re(dmem_re),.dmem_we(dmem_we),.dmem_wmask(dmem_wmask),.dmem_wdata(dmem_wdata),.dmem_rdata(dmem_rdata));
    integer errors=0,mode,j,k,cycles;
    reg reached;
    reg [31:0] saved_regs[1:31],saved_mem[0:4095];
    task automatic check(input bit ok,input string msg);
        if(!ok) begin errors=errors+1; $display("FAIL reset mode=%0d %s",mode,msg); end
    endtask
    task automatic trace_zero;
        check({dut.retire_valid,dut.retire_pc,dut.retire_instr,dut.retire_rd,dut.retire_rd_we,dut.retire_rd_data,
          dut.retire_mem_valid,dut.retire_mem_write,dut.retire_mem_addr,dut.retire_mem_wmask,dut.retire_mem_wdata,dut.retire_mem_rdata}===0,"reset trace all zero");
    endtask
    initial begin
        for(mode=0;mode<5;mode=mode+1) begin
            @(negedge clk); rst=1;
            for(j=0;j<4096;j=j+1) begin imem.mem[j]=32'hffffffff; dmem.mem[j]=32'h89abcdef; end
            // LUI x1,0x10; ADDI x2,x0,85; LW x2,0(x1) or SW x2,0(x1); ECALL.
            imem.mem[0]=32'h000100b7; imem.mem[1]=32'h05500113;
            imem.mem[2]=(mode==1) ? 32'h0000a103 : 32'h0020a023;
            imem.mem[3]=32'h00000073;
            repeat(2) begin @(posedge clk); #1; end
            @(negedge clk); rst=0;
            reached=0;
            begin : seek
                for(cycles=0;cycles<50;cycles=cycles+1) begin
                    // All stimulus changes and snapshots precede the accepting edge.
                    #1;
                    reached=(mode==0 && imem_en && !dut.ifid_valid) ||
                      (mode==1 && dut.exmem_valid && dut.exmem_mem_read) ||
                      (mode==2 && dut.idex_valid && dut.idex_mem_write && dmem_we) ||
                      (mode==3 && dut.stop_fetch && !halted) || (mode==4 && halted);
                    if(reached) disable seek;
                    @(negedge clk);
                end
            end
            check(reached,"requested active reset phase reached");
            $display("RESET_STIM mode=%0d cycles=%0d IF=%b EXload=%b MEMload=%b EXstore=%b we=%b stop=%b halted=%b",mode,cycles,imem_en,dut.idex_mem_read,dut.exmem_mem_read,dut.idex_mem_write,dmem_we,dut.stop_fetch,halted);
            for(j=1;j<32;j=j+1) saved_regs[j]=dut.u_reg_file.register[j];
            for(j=0;j<4096;j=j+1) saved_mem[j]=dmem.mem[j];
            rst=1; #1;
            check(!imem_en && !dmem_re && !dmem_we && !dut.wb_rd_we,"reset suppresses acceptance before edge");
            @(posedge clk); #1;
            check(!dut.ifid_valid && !dut.idex_valid && !dut.exmem_valid && !dut.memwb_valid,"reset clears all packet valids");
            check(!halted && {fault_pc,fault_cause}===0 && imem_addr===0,"reset restarts PC and diagnostic");
            trace_zero();
            for(j=1;j<32;j=j+1) check(dut.u_reg_file.register[j]===saved_regs[j],"reset no GPR writes/clearing");
            for(j=0;j<4096;j=j+1) check(dmem.mem[j]===saved_mem[j],"reset no memory writes/clearing");
            @(negedge clk); imem.mem[0]=32'h00000073; rst=0;
            #1; check(imem_en && imem_addr===0,"restart fetch zero");
            @(posedge clk); #1; check(dut.ifid_valid && dut.ifid_pc===0,"restart decoded PC zero");
            @(posedge clk); #1; check(!halted && fault_cause===4 && fault_pc===0,"bare event enters drain at detecting edge");
            @(posedge clk); #1; check(halted && !dut.retire_valid,"bare event halt at next edge C(d+2)");
            repeat(3) begin @(posedge clk); #1;
                check(halted && !imem_en && !dmem_re && !dmem_we && !dut.wb_rd_we,"halt holds without enables");
                check(fault_cause===4 && fault_pc===0,"halt diagnostic immutable");
            end
            for(j=1;j<32;j=j+1) check(dut.u_reg_file.register[j]===saved_regs[j],"flushed work never writes after reset");
            for(j=0;j<4096;j=j+1) check(dmem.mem[j]===saved_mem[j],"flushed work never stores after reset");
            $display("RESET_CASE_COMPLETED mode=%0d",mode);
        end
        if(errors) $fatal(1,"reset errors=%0d",errors);
        $display("PASS ALL RESET cases=5 trace=%0d",TRACE_EN); $finish;
    end
    initial begin #10000; $fatal(1,"reset watchdog"); end
endmodule
