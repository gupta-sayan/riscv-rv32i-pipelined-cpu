`timescale 1ns/1ps
module tb_campaign;
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


    integer completed, first_decode, redirect_age, redirects, split_sources, bypass_a, bypass_b;
    integer token_load, cancel_token, wb_seen, accepted_seen;
    reg [31:0] expected_redirect;
    reg pre_completion, expected_target_terminal, capture_expected;
    reg [31:0] captured_pc_expected;
    reg [3:0] captured_cause_expected;
    integer expected_mem_indices[0:2047];
    integer expected_mem_count;
    task automatic sample_completion;
        integer k;
        begin
            pre_completion=dut.memwb_valid && !halted;
            capture_expected=0;
            if(!dut.stop_fetch && dut.idex_valid && dut.ex_evt_valid) begin
                capture_expected=1; captured_pc_expected=dut.ex_evt_pc; captured_cause_expected=dut.ex_evt_cause;
            end else if(!dut.stop_fetch && !dut.fetch_redirect_valid && dut.id_evt_valid) begin
                capture_expected=1; captured_pc_expected=dut.id_evt_pc; captured_cause_expected=dut.id_evt_cause;
            end
            if(dut.ifid_valid && first_decode==0) begin
                check(dut.ifid_pc===0,"first decoded PC zero"); first_decode=1;
            end
            if(pre_completion) begin
                if(wb_seen>=n) check(0,"unexpected internal completion");
                else begin
                    check(dut.memwb_pc===epc[wb_seen],$sformatf("WB PC index %0d",wb_seen));
                    check(dut.wb_rd_we===(erd[wb_seen]>0),"actual WB write enable");
                    if(erd[wb_seen]>0) begin
                        check(dut.memwb_rd===erd[wb_seen][4:0],"actual WB destination");
                        check(dut.memwb_wb_data===edata[wb_seen],$sformatf("actual WB result PC=%h got=%h expected=%h",epc[wb_seen],dut.memwb_wb_data,edata[wb_seen]));
                    end
                end
                wb_seen=wb_seen+1;
            end
            if(dmem_re || dmem_we) begin
                if(accepted_seen>=expected_mem_count) check(0,"extra memory transaction");
                else begin
                    k=expected_mem_indices[accepted_seen];
                    check(dmem_addr===eaddr[k],"accepted transaction byte address");
                    check(dmem_we===(emem[k]==2),"accepted transaction direction");
                    if(dmem_we) begin
                        check(dmem_wmask===emask[k][3:0],"accepted byte strobe");
                        check(dmem_wdata===ewdata[k],"accepted lane payload");
                    end
                end
                accepted_seen=accepted_seen+1;
            end
            if(redirect_age>0) begin
                if(redirect_age<=2) check(!dut.idex_valid,"exact redirect EX bubble");
                if(redirect_age==2 && expected_redirect<32'h4000) begin
                    check(dut.ifid_valid && dut.ifid_pc===expected_redirect,"redirect target in ID at scheduled cycle");
                    expected_target_terminal=dut.id_evt_valid;
                end
                if(redirect_age==3) begin
                    if(expected_redirect<32'h4000 && !expected_target_terminal)
                        check(dut.idex_valid && dut.idex_pc===expected_redirect,"target in EX after exactly two bubbles");
                    if(expected_redirect<32'h4000 && expected_target_terminal)
                        check(!dut.idex_valid,"ID terminal target excluded from EX");
                    redirect_age=0;
                end else redirect_age=redirect_age+1;
            end
            if(dut.fetch_redirect_valid) begin
                redirects=redirects+1; redirect_age=1; expected_redirect=dut.redirect_pc; expected_target_terminal=0;
                if(dut.ifid_fetch_fault) cancel_token=cancel_token+1;
            end
            if(dut.idex_valid && dut.idex_uses_rs1 && dut.idex_uses_rs2 && dut.fwd_a_sel==1 && dut.fwd_b_sel==2)
                split_sources=split_sources+1;
            if(dut.ifid_valid && dut.memwb_valid && dut.memwb_reg_write && dut.memwb_rd!=0) begin
                if(dut.decode_uses_rs1 && dut.decode_rs1==dut.memwb_rd) begin
                    bypass_a=bypass_a+1; check(dut.id_rs1_value===dut.memwb_wb_data,"WB-ID rs1 bypass");
                end
                if(dut.decode_uses_rs2 && dut.decode_rs2==dut.memwb_rd) begin
                    bypass_b=bypass_b+1; check(dut.id_rs2_value===dut.memwb_wb_data,"WB-ID rs2 bypass");
                end
            end
            if(dut.ifid_valid && dut.ifid_fetch_fault && dut.idex_valid && dut.idex_mem_read) begin
                token_load=token_load+1;
                check(dut.idex_rd==dut.decode_rs1 || dut.idex_rd==dut.decode_rs2,"token raw field coincidence");
                check(!dut.decode_uses_rs1 && !dut.decode_uses_rs2 && !dut.hold_if,"token no sources/no false hold");
            end
            check(!(dut.lsu_evt_valid && dut.branch_target_misaligned),"exclusive legal EX fault sources");
        end
    endtask

    // Independent, explicitly authored expected retirement stream; no DUT decode used.
    reg [31:0] epc[0:2047], eins[0:2047], edata[0:2047], eaddr[0:2047], ewdata[0:2047], erdata[0:2047];
    integer erd[0:2047], emem[0:2047], emask[0:2047]; // emem: 0 none, 1 load, 2 store
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
            if(memkind!=0) begin expected_mem_indices[expected_mem_count]=n; expected_mem_count=expected_mem_count+1; end
            n=n+1;
        end
    endtask
    task automatic ins(input integer pc,input reg [31:0] op,input integer rd,input reg [31:0] data);
        expect_ins(pc,op,rd,data,0,0,0,0,0);
    endtask
    task automatic prepare(input string name);
        integer j;
        begin
            @(negedge clk); rst=1; case_name=name; n=0; seen=0; stalls=0; reads=0; writes=0; reg_known=0; first_decode=0; redirect_age=0; redirects=0; split_sources=0; bypass_a=0; bypass_b=0; token_load=0; cancel_token=0; wb_seen=0; accepted_seen=0; expected_mem_count=0;
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
                for(cycle=0;cycle<2000;cycle=cycle+1) begin
                    // Pre-edge observations: requests accepted by the real synchronous RAMs.
                    @(posedge clk);
                    $display("CYCLE case=%s edge=%0d IF=%h ID=%b:%h token=%b EX=%b:%h MEM=%b WB=%b hold=%b redirect=%b:%h evt=%b:%h drain=%b halt=%b",case_name,cycle,imem_addr,dut.ifid_valid,dut.ifid_pc,dut.ifid_fetch_fault,dut.idex_valid,dut.idex_pc,dut.exmem_valid,dut.memwb_valid,dut.hold_if,dut.fetch_redirect_valid,dut.redirect_pc,dut.enter_drain,dut.id_evt_cause,dut.stop_fetch,halted);
                    sample_completion();
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
                    if(capture_expected) check(dut.stop_fetch && !halted && fault_pc===captured_pc_expected && fault_cause===captured_cause_expected,"terminal record captured at detecting edge");
                    if(TRACE_EN) check(retire_valid===pre_completion,"registered retire pulse matches pre-edge WB");
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
                check(0,"2000 cycle timeout");
            end
            check(halted===1'b1,"terminal halt reached");
            check(fault_cause===cause[3:0] && fault_pc===pc,$sformatf("diagnostic got cause=%h pc=%h expected cause=%h pc=%h",fault_cause,fault_pc,cause,pc));
            check(wb_seen==n,"all internal completions observed");
            check(accepted_seen==expected_mem_count,"all expected transactions accepted");
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
            $display("COVER case=%s redirects=%0d split=%0d bypass_a=%0d bypass_b=%0d token_load=%0d cancel_token=%0d",case_name,redirects,split_sources,bypass_a,bypass_b,token_load,cancel_token);
            $write("SIGNATURE %s fault=%h:%h regs=",case_name,fault_cause,fault_pc);
            for(j=1;j<32;j=j+1) if(reg_known[j]) $write("%0d:%08h,",j,dut.u_reg_file.register[j]);
            $write(" memory=");
            for(j=0;j<4096;j=j+1) $write("%08h",u_dmem.mem[j]);
            $display("");
            tests=tests+1;
            if(errors==start_errors) $display("PASS trace=%0d case=%s cycles=%0d retired=%0d stalls=%0d reads=%0d writes=%0d",TRACE_EN,case_name,cycle+1,seen,stalls,reads,writes);
        end
    endtask


    initial begin
        prepare("load_lanes_807fff00");
        u_imem.mem[0]=32'h000100b7;
        u_imem.mem[1]=32'h00008093;
        u_imem.mem[2]=32'h00008103;
        u_imem.mem[3]=32'h00108183;
        u_imem.mem[4]=32'h00208203;
        u_imem.mem[5]=32'h00308283;
        u_imem.mem[6]=32'h0000c103;
        u_imem.mem[7]=32'h0010c183;
        u_imem.mem[8]=32'h0020c203;
        u_imem.mem[9]=32'h0030c283;
        u_imem.mem[10]=32'h00009303;
        u_imem.mem[11]=32'h00209403;
        u_imem.mem[12]=32'h0000d303;
        u_imem.mem[13]=32'h0020d403;
        u_imem.mem[14]=32'h0000a503;
        u_imem.mem[15]=32'h00000073;
        u_dmem.mem[0]=32'h807fff00;
        expect_ins(32'h00000000,32'h000100b7,1,32'h00010000,0,32'h00000000,0,32'h00000000,32'h00000000);
        expect_ins(32'h00000004,32'h00008093,1,32'h00010000,0,32'h00000000,0,32'h00000000,32'h00000000);
        expect_ins(32'h00000008,32'h00008103,2,32'h00000000,1,32'h00010000,0,32'h00000000,32'h807fff00);
        expect_ins(32'h0000000c,32'h00108183,3,32'hffffffff,1,32'h00010001,0,32'h00000000,32'h807fff00);
        expect_ins(32'h00000010,32'h00208203,4,32'h0000007f,1,32'h00010002,0,32'h00000000,32'h807fff00);
        expect_ins(32'h00000014,32'h00308283,5,32'hffffff80,1,32'h00010003,0,32'h00000000,32'h807fff00);
        expect_ins(32'h00000018,32'h0000c103,2,32'h00000000,1,32'h00010000,0,32'h00000000,32'h807fff00);
        expect_ins(32'h0000001c,32'h0010c183,3,32'h000000ff,1,32'h00010001,0,32'h00000000,32'h807fff00);
        expect_ins(32'h00000020,32'h0020c203,4,32'h0000007f,1,32'h00010002,0,32'h00000000,32'h807fff00);
        expect_ins(32'h00000024,32'h0030c283,5,32'h00000080,1,32'h00010003,0,32'h00000000,32'h807fff00);
        expect_ins(32'h00000028,32'h00009303,6,32'hffffff00,1,32'h00010000,0,32'h00000000,32'h807fff00);
        expect_ins(32'h0000002c,32'h00209403,8,32'hffff807f,1,32'h00010002,0,32'h00000000,32'h807fff00);
        expect_ins(32'h00000030,32'h0000d303,6,32'h0000ff00,1,32'h00010000,0,32'h00000000,32'h807fff00);
        expect_ins(32'h00000034,32'h0020d403,8,32'h0000807f,1,32'h00010002,0,32'h00000000,32'h807fff00);
        expect_ins(32'h00000038,32'h0000a503,10,32'h807fff00,1,32'h00010000,0,32'h00000000,32'h807fff00);
        memory[0]=32'h807fff00;
        run_case(4,32'h0000003c,0,13,0);
        prepare("load_lanes_80007fff");
        u_imem.mem[0]=32'h000100b7;
        u_imem.mem[1]=32'h00008093;
        u_imem.mem[2]=32'h00008103;
        u_imem.mem[3]=32'h00108183;
        u_imem.mem[4]=32'h00208203;
        u_imem.mem[5]=32'h00308283;
        u_imem.mem[6]=32'h0000c103;
        u_imem.mem[7]=32'h0010c183;
        u_imem.mem[8]=32'h0020c203;
        u_imem.mem[9]=32'h0030c283;
        u_imem.mem[10]=32'h00009303;
        u_imem.mem[11]=32'h00209403;
        u_imem.mem[12]=32'h0000d303;
        u_imem.mem[13]=32'h0020d403;
        u_imem.mem[14]=32'h0000a503;
        u_imem.mem[15]=32'h00000073;
        u_dmem.mem[0]=32'h80007fff;
        expect_ins(32'h00000000,32'h000100b7,1,32'h00010000,0,32'h00000000,0,32'h00000000,32'h00000000);
        expect_ins(32'h00000004,32'h00008093,1,32'h00010000,0,32'h00000000,0,32'h00000000,32'h00000000);
        expect_ins(32'h00000008,32'h00008103,2,32'hffffffff,1,32'h00010000,0,32'h00000000,32'h80007fff);
        expect_ins(32'h0000000c,32'h00108183,3,32'h0000007f,1,32'h00010001,0,32'h00000000,32'h80007fff);
        expect_ins(32'h00000010,32'h00208203,4,32'h00000000,1,32'h00010002,0,32'h00000000,32'h80007fff);
        expect_ins(32'h00000014,32'h00308283,5,32'hffffff80,1,32'h00010003,0,32'h00000000,32'h80007fff);
        expect_ins(32'h00000018,32'h0000c103,2,32'h000000ff,1,32'h00010000,0,32'h00000000,32'h80007fff);
        expect_ins(32'h0000001c,32'h0010c183,3,32'h0000007f,1,32'h00010001,0,32'h00000000,32'h80007fff);
        expect_ins(32'h00000020,32'h0020c203,4,32'h00000000,1,32'h00010002,0,32'h00000000,32'h80007fff);
        expect_ins(32'h00000024,32'h0030c283,5,32'h00000080,1,32'h00010003,0,32'h00000000,32'h80007fff);
        expect_ins(32'h00000028,32'h00009303,6,32'h00007fff,1,32'h00010000,0,32'h00000000,32'h80007fff);
        expect_ins(32'h0000002c,32'h00209403,8,32'hffff8000,1,32'h00010002,0,32'h00000000,32'h80007fff);
        expect_ins(32'h00000030,32'h0000d303,6,32'h00007fff,1,32'h00010000,0,32'h00000000,32'h80007fff);
        expect_ins(32'h00000034,32'h0020d403,8,32'h00008000,1,32'h00010002,0,32'h00000000,32'h80007fff);
        expect_ins(32'h00000038,32'h0000a503,10,32'h80007fff,1,32'h00010000,0,32'h00000000,32'h80007fff);
        memory[0]=32'h80007fff;
        run_case(4,32'h0000003c,0,13,0);
        prepare("load_lanes_ff80017f");
        u_imem.mem[0]=32'h000100b7;
        u_imem.mem[1]=32'h00008093;
        u_imem.mem[2]=32'h00008103;
        u_imem.mem[3]=32'h00108183;
        u_imem.mem[4]=32'h00208203;
        u_imem.mem[5]=32'h00308283;
        u_imem.mem[6]=32'h0000c103;
        u_imem.mem[7]=32'h0010c183;
        u_imem.mem[8]=32'h0020c203;
        u_imem.mem[9]=32'h0030c283;
        u_imem.mem[10]=32'h00009303;
        u_imem.mem[11]=32'h00209403;
        u_imem.mem[12]=32'h0000d303;
        u_imem.mem[13]=32'h0020d403;
        u_imem.mem[14]=32'h0000a503;
        u_imem.mem[15]=32'h00000073;
        u_dmem.mem[0]=32'hff80017f;
        expect_ins(32'h00000000,32'h000100b7,1,32'h00010000,0,32'h00000000,0,32'h00000000,32'h00000000);
        expect_ins(32'h00000004,32'h00008093,1,32'h00010000,0,32'h00000000,0,32'h00000000,32'h00000000);
        expect_ins(32'h00000008,32'h00008103,2,32'h0000007f,1,32'h00010000,0,32'h00000000,32'hff80017f);
        expect_ins(32'h0000000c,32'h00108183,3,32'h00000001,1,32'h00010001,0,32'h00000000,32'hff80017f);
        expect_ins(32'h00000010,32'h00208203,4,32'hffffff80,1,32'h00010002,0,32'h00000000,32'hff80017f);
        expect_ins(32'h00000014,32'h00308283,5,32'hffffffff,1,32'h00010003,0,32'h00000000,32'hff80017f);
        expect_ins(32'h00000018,32'h0000c103,2,32'h0000007f,1,32'h00010000,0,32'h00000000,32'hff80017f);
        expect_ins(32'h0000001c,32'h0010c183,3,32'h00000001,1,32'h00010001,0,32'h00000000,32'hff80017f);
        expect_ins(32'h00000020,32'h0020c203,4,32'h00000080,1,32'h00010002,0,32'h00000000,32'hff80017f);
        expect_ins(32'h00000024,32'h0030c283,5,32'h000000ff,1,32'h00010003,0,32'h00000000,32'hff80017f);
        expect_ins(32'h00000028,32'h00009303,6,32'h0000017f,1,32'h00010000,0,32'h00000000,32'hff80017f);
        expect_ins(32'h0000002c,32'h00209403,8,32'hffffff80,1,32'h00010002,0,32'h00000000,32'hff80017f);
        expect_ins(32'h00000030,32'h0000d303,6,32'h0000017f,1,32'h00010000,0,32'h00000000,32'hff80017f);
        expect_ins(32'h00000034,32'h0020d403,8,32'h0000ff80,1,32'h00010002,0,32'h00000000,32'hff80017f);
        expect_ins(32'h00000038,32'h0000a503,10,32'hff80017f,1,32'h00010000,0,32'h00000000,32'hff80017f);
        memory[0]=32'hff80017f;
        run_case(4,32'h0000003c,0,13,0);
        prepare("load_lanes_0000ffff");
        u_imem.mem[0]=32'h000100b7;
        u_imem.mem[1]=32'h00008093;
        u_imem.mem[2]=32'h00008103;
        u_imem.mem[3]=32'h00108183;
        u_imem.mem[4]=32'h00208203;
        u_imem.mem[5]=32'h00308283;
        u_imem.mem[6]=32'h0000c103;
        u_imem.mem[7]=32'h0010c183;
        u_imem.mem[8]=32'h0020c203;
        u_imem.mem[9]=32'h0030c283;
        u_imem.mem[10]=32'h00009303;
        u_imem.mem[11]=32'h00209403;
        u_imem.mem[12]=32'h0000d303;
        u_imem.mem[13]=32'h0020d403;
        u_imem.mem[14]=32'h0000a503;
        u_imem.mem[15]=32'h00000073;
        u_dmem.mem[0]=32'h0000ffff;
        expect_ins(32'h00000000,32'h000100b7,1,32'h00010000,0,32'h00000000,0,32'h00000000,32'h00000000);
        expect_ins(32'h00000004,32'h00008093,1,32'h00010000,0,32'h00000000,0,32'h00000000,32'h00000000);
        expect_ins(32'h00000008,32'h00008103,2,32'hffffffff,1,32'h00010000,0,32'h00000000,32'h0000ffff);
        expect_ins(32'h0000000c,32'h00108183,3,32'hffffffff,1,32'h00010001,0,32'h00000000,32'h0000ffff);
        expect_ins(32'h00000010,32'h00208203,4,32'h00000000,1,32'h00010002,0,32'h00000000,32'h0000ffff);
        expect_ins(32'h00000014,32'h00308283,5,32'h00000000,1,32'h00010003,0,32'h00000000,32'h0000ffff);
        expect_ins(32'h00000018,32'h0000c103,2,32'h000000ff,1,32'h00010000,0,32'h00000000,32'h0000ffff);
        expect_ins(32'h0000001c,32'h0010c183,3,32'h000000ff,1,32'h00010001,0,32'h00000000,32'h0000ffff);
        expect_ins(32'h00000020,32'h0020c203,4,32'h00000000,1,32'h00010002,0,32'h00000000,32'h0000ffff);
        expect_ins(32'h00000024,32'h0030c283,5,32'h00000000,1,32'h00010003,0,32'h00000000,32'h0000ffff);
        expect_ins(32'h00000028,32'h00009303,6,32'hffffffff,1,32'h00010000,0,32'h00000000,32'h0000ffff);
        expect_ins(32'h0000002c,32'h00209403,8,32'h00000000,1,32'h00010002,0,32'h00000000,32'h0000ffff);
        expect_ins(32'h00000030,32'h0000d303,6,32'h0000ffff,1,32'h00010000,0,32'h00000000,32'h0000ffff);
        expect_ins(32'h00000034,32'h0020d403,8,32'h00000000,1,32'h00010002,0,32'h00000000,32'h0000ffff);
        expect_ins(32'h00000038,32'h0000a503,10,32'h0000ffff,1,32'h00010000,0,32'h00000000,32'h0000ffff);
        memory[0]=32'h0000ffff;
        run_case(4,32'h0000003c,0,13,0);
        if(errors) $fatal(1,"CAMPAIGN FAIL errors=%0d",errors);
        $display("PASS ALL V10 trace=%0d cases=4",TRACE_EN);
        $finish;
    end
    initial begin #10000000; $fatal(1,"campaign watchdog"); end
endmodule
