`timescale 1ns/1ps
module tb_accepted_fetch_reset;
    parameter bit TRACE_EN=1;
    reg clk=0,rst=1;
    always #5 clk=~clk;
    wire [31:0] imem_addr,imem_rdata,dmem_addr,dmem_wdata,dmem_rdata,fault_pc;
    wire imem_en,dmem_re,dmem_we,halted;
    wire [3:0] dmem_wmask,fault_cause;
    rv32i_core_top #(.TRACE_EN(TRACE_EN)) dut(.clk(clk),.rst(rst),
        .imem_addr(imem_addr),.imem_en(imem_en),.imem_rdata(imem_rdata),
        .dmem_addr(dmem_addr),.dmem_re(dmem_re),.dmem_we(dmem_we),
        .dmem_wmask(dmem_wmask),.dmem_wdata(dmem_wdata),.dmem_rdata(dmem_rdata),
        .halted(halted),.fault_pc(fault_pc),.fault_cause(fault_cause));
    imem_sync imem(.clk(clk),.imem_addr(imem_addr),.imem_en(imem_en),.imem_rdata(imem_rdata));
    dmem_sync dmem(.clk(clk),.dmem_addr(dmem_addr),.dmem_re(dmem_re),.dmem_we(dmem_we),
        .dmem_wmask(dmem_wmask),.dmem_wdata(dmem_wdata),.dmem_rdata(dmem_rdata));
    localparam [31:0] ABORTED=32'h05500293; // ADDI x5,x0,85 (must never execute)
    reg [31:0] saved_regs[1:31],words[0:3];
    integer errors=0,checks=0,j,cycle,completed=0,reads=0,writes=0,traces=0;
    integer slot;
    reg wb_before;
    time accepted_at,reset_at;
    task automatic check(input bit ok,input string msg);
        begin checks=checks+1;
            if(!ok) begin errors=errors+1; $display("FAIL IV01 trace=%0d t=%0t %s",TRACE_EN,$time,msg); end
        end
    endtask
    task automatic cycle_log(input string phase);
        $display("CYCLE %s trace=%0d t=%0t rst=%b req=%b:%h response=%h IFID=%b:%h:f%b EX=%b:%h WB=%b:%h write=%b:x%0d:%h retire=%b halt=%b",
            phase,TRACE_EN,$time,rst,imem_en,imem_addr,imem_rdata,dut.ifid_valid,dut.ifid_pc,dut.ifid_fetch_fault,
            dut.idex_valid,dut.idex_pc,dut.memwb_valid,dut.memwb_pc,dut.wb_rd_we,dut.memwb_rd,dut.memwb_wb_data,dut.retire_valid,halted);
    endtask
    task automatic disabled_trace;
        if(!TRACE_EN) check({dut.retire_valid,dut.retire_pc,dut.retire_instr,dut.retire_rd,dut.retire_rd_we,dut.retire_rd_data,
            dut.retire_mem_valid,dut.retire_mem_write,dut.retire_mem_addr,dut.retire_mem_wmask,dut.retire_mem_wdata,dut.retire_mem_rdata}===0,"disabled trace entirely zero");
    endtask
    task automatic no_effect;
        begin
            check(!dut.wb_rd_we && !dmem_we && !dmem_re && !dut.retire_valid,"no effect from accepted/discarded instruction");
            for(j=1;j<32;j=j+1) check(dut.u_reg_file.register[j]===saved_regs[j],"GPR state unchanged before restart");
            for(j=0;j<4096;j=j+1) check(dmem.mem[j]===32'haabbccdd,"RAM state unchanged before restart");
            disabled_trace();
        end
    endtask
    initial begin
        // Real memories and natural fetch, no forced core state or register initialization.
        for(j=0;j<4096;j=j+1) begin imem.mem[j]=32'hffffffff; dmem.mem[j]=32'haabbccdd; end
        imem.mem[0]=ABORTED;
        for(j=1;j<32;j=j+1) saved_regs[j]=dut.u_reg_file.register[j];
        repeat(2) begin @(posedge clk);
            // Before the first synchronous reset NBA, registered trace is
            // intentionally uninitialized; only acceptance enables are defined.
            check(!imem_en && !dut.fetch_issue && !dut.wb_rd_we && !dmem_we && !dmem_re,"reset suppresses acceptance at edge");
            #1; no_effect();
        end
        @(negedge clk); rst=0;
        @(posedge clk);
        check(!rst && imem_en===1'b1 && dut.fetch_issue===1'b1 && imem_addr===0,"fetch acceptance predicate at rising edge");
        accepted_at=$time; cycle_log("ACCEPT_PRE");
        no_effect();
        #1;
        check(imem_rdata===ABORTED,"accepted synchronous instruction response live");
        check(dut.ifid_valid===1'b1 && dut.ifid_pc===0 && dut.ifid_fetch_fault===0,"accepted IFID metadata aligned and live");
        check(dut.id_valid===1'b1 && dut.decode_legal && dut.decode_rd===5,"accepted ADDI actually decoded in ID");
        check(!dut.idex_valid && imem_addr===4,"fetch advanced but accepted instruction not yet in EX");
        cycle_log("ACCEPTED_LIVE"); no_effect();
        @(negedge clk); rst=1; reset_at=$time;
        check(reset_at>accepted_at && reset_at<accepted_at+10,"reset strictly after acceptance and before next rising edge");
        #1;
        check(dut.ifid_valid===1'b1 && imem_rdata===ABORTED,"live packet remains until synchronous reset edge");
        check(!imem_en && !dut.fetch_issue && !dmem_we && !dut.wb_rd_we,"reset suppresses new acceptance before edge");
        cycle_log("RESET_ASSERTED_AFTER_ACCEPT"); no_effect();
        @(posedge clk); no_effect(); #1;
        check({dut.ifid_valid,dut.idex_valid,dut.exmem_valid,dut.memwb_valid}===4'b0,"reset flushes accepted IFID and all pipeline valids");
        check(imem_rdata===ABORTED,"RAM holds stale response while CPU invalidates it");
        check(imem_addr===0 && !halted && {fault_pc,fault_cause}===0,"reset clears fetch/controller/fault state");
        cycle_log("RESET_EDGE_FLUSHED"); no_effect();
        // Change the external image under reset so stale-response reuse is observable.
        // LUI x10,0x10; ADDI x5,x0,42; SW x5,0(x10); LW x6,0(x10); ECALL.
        words[0]=32'h00010537; words[1]=32'h02a00293;
        words[2]=32'h00552023; words[3]=32'h00052303;
        @(negedge clk);
        for(j=0;j<4;j=j+1) imem.mem[j]=words[j];
        imem.mem[4]=32'h00000073;
        rst=0; #1;
        check(imem_en && dut.fetch_issue && imem_addr===0 && !dut.ifid_valid,"restart fetch begins at PC zero with empty ID");
        check(imem_rdata===ABORTED,"stale response present but not a valid restart instruction");
        begin : restart
            for(cycle=0;cycle<40;cycle=cycle+1) begin
                @(posedge clk); cycle_log("RESTART_PRE");
                disabled_trace();
                wb_before=dut.memwb_valid && !halted; slot=completed;
                if(cycle==0) check(imem_en && imem_addr===0,"fresh restart fetch acceptance at zero");
                if(dmem_we) begin
                    writes=writes+1;
                    check(writes==1 && dmem_addr===32'h10000 && dmem_wmask===4'hf && dmem_wdata===42,"only intended restart store accepted");
                end
                if(dmem_re) begin reads=reads+1; check(reads==1 && dmem_addr===32'h10000,"only intended restart read accepted"); end
                check(!(dmem_we && dmem_re),"exclusive memory requests");
                if(wb_before) begin
                    check(slot<4,"no extra or stale WB completion");
                    if(slot<4) begin
                        check(dut.memwb_pc===slot*4,"ordered restart WB PC");
                        check(dut.wb_rd_we===(slot!=2),"exact restart WB enables");
                        if(slot!=2) begin
                            check(dut.memwb_rd===(slot==0 ? 5'd10 : slot==1 ? 5'd5 : 5'd6),"exact restart WB destination");
                            check(dut.memwb_wb_data===(slot==0 ? 32'h10000 : 32'd42),"exact restart WB value; aborted 85 forbidden");
                        end
                    end
                    completed=completed+1;
                end else check(!dut.wb_rd_we,"no write without valid completion");
                #1;
                if(cycle==0) begin
                    check(imem_rdata===words[0] && dut.ifid_valid && dut.ifid_pc===0 && !dut.ifid_fetch_fault,"new instruction and metadata replace stale response");
                    check(!dut.idex_valid,"stale accepted ADDI never enters EX at restart edge");
                    cycle_log("FRESH_RESTART_LIVE");
                end
                disabled_trace();
                if(TRACE_EN) begin
                    check(dut.retire_valid===wb_before,"registered trace exactly follows intended WB");
                    if(dut.retire_valid) begin
                        traces=traces+1;
                        check(slot<4,"no extra trace instruction");
                        if(slot<4) begin
                            check(dut.retire_pc===slot*4 && dut.retire_instr===words[slot],"retirement exact new image, aborted instruction forbidden");
                            check(dut.retire_rd_we===(slot!=2),"retirement write enable");
                            if(slot!=2) check(dut.retire_rd===(slot==0 ? 5'd10 : slot==1 ? 5'd5 : 5'd6) && dut.retire_rd_data===(slot==0 ? 32'h10000 : 32'd42),"retirement destination/value");
                            check(dut.retire_mem_valid===(slot>=2),"retirement memory validity");
                            if(slot>=2) check(dut.retire_mem_addr===32'h10000 && dut.retire_mem_write===(slot==2),"retirement memory address/direction");
                            if(slot==2) check(dut.retire_mem_wmask===4'hf && dut.retire_mem_wdata===42,"retirement store payload");
                            if(slot==3) check(dut.retire_mem_rdata===42,"retirement raw load word");
                        end
                    end
                end
                check(!(halted && dut.retire_valid),"halt excludes retirement");
                if(halted) disable restart;
            end
        end
        check(halted && fault_cause===4 && fault_pc===16,"restart terminates on new ECALL at PC16");
        check(completed==4 && reads==1 && writes==1 && traces==(TRACE_EN ? 4 : 0),"exact completion/transaction/trace counts");
        repeat(4) begin @(posedge clk); #1; disabled_trace();
            check(halted && !imem_en && !dut.fetch_issue && !dmem_re && !dmem_we && !dut.wb_rd_we && !dut.retire_valid,"no delayed stale effects in HALTED");
            check(fault_cause===4 && fault_pc===16,"stable restarted terminal record");
        end
        for(j=1;j<32;j=j+1)
            if(j==10) check(dut.u_reg_file.register[j]===32'h10000,"restart base register");
            else if(j==5 || j==6) check(dut.u_reg_file.register[j]===42,"restart result registers, no aborted value");
            else check(dut.u_reg_file.register[j]===saved_regs[j],"no unintended other GPR writes");
        for(j=0;j<4096;j=j+1) check(dmem.mem[j]===(j==0 ? 32'd42 : 32'haabbccdd),"entire RAM exactly intended restart state");
        if(errors) $fatal(1,"IV01 FAIL errors=%0d checks=%0d",errors,checks);
        $display("PASS ALL IV01 trace=%0d accepted_at=%0t reset_at=%0t completed=%0d reads=%0d writes=%0d traces=%0d checks=%0d",TRACE_EN,accepted_at,reset_at,completed,reads,writes,traces,checks);
        $finish;
    end
    initial begin #2000; $fatal(1,"IV01 finite watchdog"); end
endmodule
