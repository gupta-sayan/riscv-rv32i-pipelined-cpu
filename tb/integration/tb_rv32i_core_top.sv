`timescale 1ns/1ps
module tb_rv32i_core_top;
    parameter bit TRACE_EN = 1;
    reg clk=0, rst=1;
    always #5 clk=~clk;
    wire [31:0] imem_addr, imem_rdata, dmem_addr, dmem_wdata, dmem_rdata;
    wire imem_en,dmem_re,dmem_we,halted;
    wire [3:0] dmem_wmask,fault_cause,retire_mem_wmask;
    wire [31:0] fault_pc,retire_pc,retire_instr,retire_rd_data;
    wire [31:0] retire_mem_addr,retire_mem_wdata,retire_mem_rdata;
    wire retire_valid,retire_rd_we,retire_mem_valid,retire_mem_write;
    wire [4:0] retire_rd;
    rv32i_core_top #(.TRACE_EN(TRACE_EN)) dut(.*);
    imem_sync u_imem(.clk(clk),.imem_en(imem_en),.imem_addr(imem_addr),.imem_rdata(imem_rdata));
    dmem_sync u_dmem(.clk(clk),.dmem_addr(dmem_addr),.dmem_re(dmem_re),.dmem_we(dmem_we),
        .dmem_wmask(dmem_wmask),.dmem_wdata(dmem_wdata),.dmem_rdata(dmem_rdata));

    // Independent, explicitly authored expected retirement stream; no DUT decode used.
    reg [31:0] epc[0:127], eins[0:127], edata[0:127], eaddr[0:127], ewdata[0:127], erdata[0:127];
    integer erd[0:127], emem[0:127], emask[0:127]; // emem: 0 none, 1 load, 2 store
    reg [31:0] regs[0:31], memory[0:4095];
    reg [31:0] reg_known;
    integer n,seen,errors=0,tests=0,stalls,reads,writes,case_id;
    string case_name;
    function automatic [31:0] it(input integer imm,rs,f3,rd,op);
        it={imm[11:0],rs[4:0],f3[2:0],rd[4:0],op[6:0]};
    endfunction
    function automatic [31:0] rt(input integer f7,b,a,f3,rd);
        rt={f7[6:0],b[4:0],a[4:0],f3[2:0],rd[4:0],7'h33};
    endfunction
    function automatic [31:0] st(input integer imm,b,a,f3);
        st={imm[11:5],b[4:0],a[4:0],f3[2:0],imm[4:0],7'h23};
    endfunction
    function automatic [31:0] br(input integer imm,b,a,f3);
        br={imm[12],imm[10:5],b[4:0],a[4:0],f3[2:0],imm[4:1],imm[11],7'h63};
    endfunction
    function automatic [31:0] jal(input integer imm,rd);
        jal={imm[20],imm[10:1],imm[11],imm[19:12],rd[4:0],7'h6f};
    endfunction
    task automatic check(input bit ok,input string msg);
        if (!ok) begin errors=errors+1; $display("FAIL trace=%0d case=%s: %s",TRACE_EN,case_name,msg); end
    endtask
    task automatic expect_ins(input integer pc,input reg [31:0] ins,input integer rd,input reg [31:0] data,
        input integer memkind,input reg [31:0] addr,input integer mask,input reg [31:0] wd,raw);
        begin
            u_imem.mem[pc/4]=ins;
            epc[n]=pc; eins[n]=ins; erd[n]=rd; edata[n]=data;
            emem[n]=memkind; eaddr[n]=addr; emask[n]=mask; ewdata[n]=wd; erdata[n]=raw;
            if(rd>0) begin regs[rd]=data; reg_known[rd]=1; end
            n=n+1;
        end
    endtask
    task automatic ins(input integer pc,input reg [31:0] op,input integer rd,input reg [31:0] data);
        expect_ins(pc,op,rd,data,0,0,0,0,0);
    endtask
    task automatic prepare(input string name);
        integer j;
        begin
            @(negedge clk); rst=1; case_name=name; n=0; seen=0; stalls=0; reads=0; writes=0; reg_known=0;
            for(j=0;j<4096;j=j+1) begin u_imem.mem[j]=32'hffffffff; u_dmem.mem[j]=0; memory[j]=0; end
            for(j=0;j<32;j=j+1) regs[j]=0;
            repeat(2) begin @(posedge clk); #1;
                check({imem_en,dmem_re,dmem_we,dut.wb_rd_we,halted,retire_valid}===6'b0,"reset enables/state");
                check({fault_pc,fault_cause}===36'b0,"reset diagnostics");
            end
        end
    endtask
    task automatic sample_trace;
        begin
            if(!TRACE_EN) check({retire_valid,retire_pc,retire_instr,retire_rd,retire_rd_we,retire_rd_data,
                retire_mem_valid,retire_mem_write,retire_mem_addr,retire_mem_wmask,retire_mem_wdata,retire_mem_rdata}===0,"disabled trace all zero");
            else if(retire_valid===1'b1) begin
                if(seen>=n) check(0,"unexpected extra retirement");
                else begin
                    check(retire_pc===epc[seen],$sformatf("retire %0d PC got %h expected %h",seen,retire_pc,epc[seen]));
                    check(retire_instr===eins[seen],$sformatf("retire %0d instruction",seen));
                    check(retire_rd_we===(erd[seen]>0),$sformatf("retire %0d write enable",seen));
                    if(erd[seen]>0) begin
                        check(retire_rd===erd[seen][4:0],"retire destination");
                        check(retire_rd_data===edata[seen],$sformatf("retire %0d result got %h expected %h",seen,retire_rd_data,edata[seen]));
                    end
                    check(retire_mem_valid===(emem[seen]!=0),"retire memory validity");
                    if(emem[seen]!=0) begin
                        check(retire_mem_write===(emem[seen]==2),"retire memory direction");
                        check(retire_mem_addr===eaddr[seen],"retire byte address");
                        if(emem[seen]==2) begin
                            check(retire_mem_wmask===emask[seen][3:0],"retire store mask");
                            check(retire_mem_wdata===ewdata[seen],"retire store lane data");
                        end else check(retire_mem_rdata===erdata[seen],"retire raw load word");
                    end
                end
                seen=seen+1;
            end else check(retire_valid===1'b0,"known retire valid");
        end
    endtask
    task automatic run_case(input integer cause,pc,expected_stalls,expected_reads,expected_writes);
        integer cycle,j,start_errors;
        reg was_drain,empty,held;
        reg [31:0] expected_imem,expected_dmem,held_pc;
        reg [32:0] held_metadata;
        reg [31:0] saved_pc;
        reg [3:0] saved_cause;
        begin
            start_errors=errors;
            @(negedge clk); rst=0;
            begin : execution
                for(cycle=0;cycle<160;cycle=cycle+1) begin
                    // Pre-edge observations: requests accepted by the real synchronous RAMs.
                    @(posedge clk);
                    was_drain=dut.stop_fetch && !halted;
                    empty=!(dut.idex_valid || dut.exmem_valid || dut.memwb_valid);
                    expected_imem=imem_en ? u_imem.mem[imem_addr[13:2]] : imem_rdata;
                    expected_dmem=dmem_re ? u_dmem.mem[dmem_addr[13:2]] : dmem_rdata;
                    held=dut.hold_if && !dut.kill_if;
                    held_pc=imem_addr;
                    held_metadata={dut.ifid_valid,dut.ifid_pc};
                    if(dut.hold_if) stalls=stalls+1;
                    if(dmem_re) reads=reads+1;
                    if(dmem_we) writes=writes+1;
                    check(!(dmem_re && dmem_we),"exclusive DMEM requests");
                    if(imem_en) check(imem_addr[31:14]===0 && imem_addr[1:0]===0,"legal fetch address");
                    if(dmem_re || dmem_we) check(dmem_addr>=32'h10000 && dmem_addr<=32'h13fff,"legal data address");
                    if(dut.stop_fetch) check(!imem_en && !dmem_re && !dmem_we && !dut.idex_valid,"no new work during drain/halt");
                    check(!dut.fwd_nonready_error && !dut.fwd_nonready_sticky,"A01 no nonready forwarding");
                    check(!dut.fetch_redirect_valid || (!dut.stop_fetch && dut.idex_valid && !dut.ex_evt_valid),"A03 qualified redirect");
                    saved_pc=fault_pc; saved_cause=fault_cause;
                    if(dut.decode_rs1==0) check(dut.rf_rs1_data===32'b0,"x0 read is zero");
                    if(dut.decode_rs2==0) check(dut.rf_rs2_data===32'b0,"x0 second read is zero");
                    #1; sample_trace();
                    check(imem_rdata===expected_imem,"synchronous IMEM response/hold");
                    check(dmem_rdata===expected_dmem,"synchronous DMEM response/hold");
                    if(held) begin
                        check(imem_addr===held_pc && {dut.ifid_valid,dut.ifid_pc}===held_metadata,"load-use fetch hold");
                        check(!dut.idex_valid,"load-use inserts EX bubble");
                    end
                    if(was_drain) begin
                        check(halted===empty,"halt at first empty drain edge");
                        check({fault_pc,fault_cause}==={saved_pc,saved_cause},"immutable drain diagnostic");
                    end
                    check(!(halted && retire_valid),"halt excludes retirement");
                    if(halted) disable execution;
                end
                check(0,"160 cycle timeout");
            end
            check(halted===1'b1,"terminal halt reached");
            check(fault_cause===cause[3:0] && fault_pc===pc,$sformatf("diagnostic got cause=%h pc=%h expected cause=%h pc=%h",fault_cause,fault_pc,cause,pc));
            check(stalls==expected_stalls,$sformatf("stalls got %0d expected %0d",stalls,expected_stalls));
            check(reads==expected_reads && writes==expected_writes,$sformatf("transactions reads=%0d writes=%0d expected %0d/%0d",reads,writes,expected_reads,expected_writes));
            if(TRACE_EN) check(seen==n,$sformatf("retirement count got %0d expected %0d",seen,n));
            for(j=1;j<32;j=j+1) if(reg_known[j]) check(dut.u_reg_file.register[j]===regs[j],$sformatf("x%0d got %h expected %h",j,dut.u_reg_file.register[j],regs[j]));
            for(j=0;j<4096;j=j+1) check(u_dmem.mem[j]===memory[j],$sformatf("DMEM word %0d",j));
            repeat(4) begin @(posedge clk); #1; sample_trace();
                check(halted && !imem_en && !dmem_re && !dmem_we && !dut.wb_rd_we && !retire_valid,"halt holds with no side effects");
                check(fault_cause===cause[3:0] && fault_pc===pc,"halt diagnostic holds");
                for(j=1;j<32;j=j+1) if(reg_known[j]) check(dut.u_reg_file.register[j]===regs[j],"register stable in halt");
            end
            tests=tests+1;
            if(errors==start_errors) $display("PASS trace=%0d case=%s cycles=%0d retired=%0d stalls=%0d reads=%0d writes=%0d",TRACE_EN,case_name,cycle+1,seen,stalls,reads,writes);
        end
    endtask

    initial begin
        prepare("arithmetic_forwarding_load_store_control");
        ins(0,32'h000100b7,1,32'h10000); // LUI base
        ins(4,it(7,0,0,2,'h13),2,7);
        ins(8,it(5,2,0,2,'h13),2,12); // youngest EX/MEM producer
        ins(12,rt(0,2,2,0,3),3,24);
        ins(16,rt(32,2,3,0,4),4,12);
        expect_ins(20,st(0,3,1,2),0,0,2,'h10000,15,24,0);
        expect_ins(24,it(0,1,2,5,3),5,24,1,'h10000,0,0,24);
        ins(28,rt(0,2,5,0,6),6,36); // immediate load-use
        expect_ins(32,st(1,6,1,0),0,0,2,'h10001,2,'h2400,0);
        expect_ins(36,it(1,1,4,7,3),7,36,1,'h10001,0,0,'h2418);
        expect_ins(40,it(0,1,5,8,3),8,'h2418,1,'h10000,0,0,'h2418);
        ins(44,br(8,7,6,0),0,0); // taken, forwarded comparison
        u_imem.mem[12]=32'hffffffff; // wrong-path illegal loses to redirect
        ins(52,br(8,7,6,1),0,0); // not taken
        ins(56,jal(8,9),9,60);
        u_imem.mem[15]=32'h00100073;
        ins(64,it(81,0,0,10,'h13),10,81); // JALR bit 0 clear
        ins(68,it(0,10,0,11,'h67),11,72);
        u_imem.mem[18]=32'hffffffff;
        ins(80,rt(0,11,9,0,12),12,132);
        ins(84,it(99,0,0,0,'h13),0,0); // x0 suppressed
        expect_ins(88,st(4,12,1,2),0,0,2,'h10004,15,132,0);
        u_imem.mem[23]=32'h00000073; // older store must commit at ID event
        memory[0]='h2418; memory[1]=132;
        run_case(4,92,1,3,3);

        prepare("preloaded_signed_lanes_and_load_x0");
        u_dmem.mem[0]=32'h80ff7f01; memory[0]=32'h80ff7f01;
        ins(0,32'h000100b7,1,32'h10000);
        expect_ins(4,it(3,1,0,2,3),2,32'hffffff80,1,'h10003,0,0,'h80ff7f01);
        expect_ins(8,it(3,1,4,3,3),3,128,1,'h10003,0,0,'h80ff7f01);
        expect_ins(12,it(2,1,1,4,3),4,32'hffff80ff,1,'h10002,0,0,'h80ff7f01);
        expect_ins(16,it(2,1,5,5,3),5,'h80ff,1,'h10002,0,0,'h80ff7f01);
        expect_ins(20,it(0,1,2,0,3),0,0,1,'h10000,0,0,'h80ff7f01);
        expect_ins(24,st(6,2,1,1),0,0,2,'h10006,12,'hff800000,0);
        expect_ins(28,it(6,1,1,6,3),6,32'hffffff80,1,'h10006,0,0,'hff800000);
        u_imem.mem[8]=32'h00000073; memory[1]=32'hff800000;
        run_case(4,32,0,6,1);

        for(case_id=0;case_id<3;case_id=case_id+1) begin
            prepare($sformatf("ID_terminal_%0d",case_id));
            ins(0,it(17,0,0,1,'h13),1,17);
            case(case_id)
                0:u_imem.mem[1]=32'hffffffff;
                1:u_imem.mem[1]=32'h00100073;
                2:u_imem.mem[1]=32'h00000073;
            endcase
            u_imem.mem[2]=it(99,0,0,1,'h13);
            run_case(case_id+2,4,0,0,0);
        end
        for(case_id=0;case_id<4;case_id=case_id+1) begin
            prepare($sformatf("EX_fault_over_ID_%0d",case_id));
            ins(0,it(9,0,0,2,'h13),2,9);
            // Unmapped + misaligned cases establish alignment-before-range priority.
            if(case_id<2) u_imem.mem[1]=it((case_id==0)?1:0,0,2,3,3);
            else u_imem.mem[1]=st((case_id==2)?1:0,2,0,2);
            u_imem.mem[2]=32'h00100073;
            run_case(case_id+5,4,0,0,0);
        end
        prepare("misaligned_jump_over_ID");
        u_imem.mem[0]=jal(2,1); u_imem.mem[1]=32'h00000073;
        run_case(9,0,0,0,0);
        prepare("out_of_range_target_fetch_token");
        ins(0,jal('h4000,1),1,4);
        u_imem.mem[1]=32'hffffffff;
        run_case(1,'h4000,0,0,0);
        prepare("empty_terminal_drain");
        u_imem.mem[0]=32'h00000073;
        run_case(4,0,0,0,0);
        if(errors != 0) $fatal(1,"FAIL TRACE_EN=%0d tests=%0d errors=%0d",TRACE_EN,tests,errors);
        $display("PASS ALL TRACE_EN=%0d tests=%0d",TRACE_EN,tests); $finish;
    end
    initial begin #100000; $fatal(1,"FAIL global simulation timeout"); end
endmodule
