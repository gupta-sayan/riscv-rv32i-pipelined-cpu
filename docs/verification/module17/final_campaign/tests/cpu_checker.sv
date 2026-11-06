`timescale 1ns/1ps
module cpu_checker #(parameter bit TRACE_EN=1, INJECTED=0)(input wire clk,rst,
input wire  idex_valid,
input wire  idex_uses_rs1,
input wire  idex_uses_rs2,
input wire  idex_mem_read,
input wire  idex_mem_write,
input wire  exmem_valid,
input wire  exmem_reg_write,
input wire  exmem_mem_read,
input wire  exmem_result_ready,
input wire  memwb_valid,
input wire  memwb_reg_write,
input wire  fwd_nonready_error,
input wire  fwd_nonready_sticky,
input wire  ifid_valid,
input wire  ifid_fetch_fault,
input wire  decode_uses_rs1,
input wire  decode_uses_rs2,
input wire  id_evt_valid,
input wire  ex_evt_valid,
input wire  lsu_evt_valid,
input wire  branch_target_misaligned,
input wire  hold_if,
input wire  bubble_ex,
input wire  kill_if,
input wire  kill_id,
input wire  kill_ex,
input wire  stop_fetch,
input wire  enter_drain,
input wire  fetch_redirect_valid,
input wire  imem_en,
input wire  fetch_issue,
input wire  dmem_re,
input wire  dmem_we,
input wire  halted,
input wire  retire_valid,
input wire  wb_rd_we,
input wire  drained,
input wire [4:0] idex_rs1,
input wire [4:0] idex_rs2,
input wire [4:0] idex_rd,
input wire [4:0] exmem_rd,
input wire [4:0] memwb_rd,
input wire [4:0] decode_rs1,
input wire [4:0] decode_rs2,
input wire [31:0] ifid_pc,
input wire [31:0] idex_pc,
input wire [31:0] redirect_pc,
input wire [31:0] imem_addr,
input wire [31:0] dmem_addr,
input wire [31:0] fault_pc,
input wire [1:0] fwd_a_sel,
input wire [1:0] fwd_b_sel,
input wire [1:0] fwd_store_sel,
input wire [3:0] fault_cause);

    integer checks=0,samples=0,nonready=0,youngest=0,held_count=0,redirects=0,exfaults=0,idevents=0,resets=0,retained=0;
    integer property_hits[0:23];
    integer age=0,k;
    reg seen_reset=0,old_sticky,old_error,old_wb,was_drain,empty,held,capture,was_redirect;
    reg [33:0] metadata;
    reg [31:0] held_pc,saved_fault_pc;
    reg [3:0] saved_cause;
    function automatic [1:0] selection(input [4:0] source,input bit used);
        reg [1:0] choice;
        begin
            choice=0;
            // Ordered producer list: older first, youngest last overwrites.
            if(idex_valid && used && source!=0) begin
                if(memwb_valid && memwb_reg_write && memwb_rd==source) choice=2;
                if(exmem_valid && exmem_reg_write && exmem_rd==source) choice=exmem_result_ready ? 1 : 3;
            end
            selection=choice;
        end
    endfunction
    task automatic property_check(input integer id,input bit ok,input string name);
        begin
            checks=checks+1;property_hits[id]=property_hits[id]+1;
            $display("PROPERTY_EVAL P%0d hit=%0d",id,property_hits[id]);
            assert(ok) else begin $display("CHECKER_FAIL P%0d %s t=%0t",id,name,$time);$fatal(1,"executable property violation");end
        end
    endtask
    reg [1:0] a,b;
    initial for(k=0;k<24;k=k+1) property_hits[k]=0;
    always @(posedge clk) begin
        samples=samples+1;
        old_sticky=fwd_nonready_sticky;old_error=fwd_nonready_error;
        old_wb=memwb_valid && !halted;
        was_drain=stop_fetch && !halted;empty=!(idex_valid || exmem_valid || memwb_valid);
        held=hold_if && !kill_if;metadata={ifid_valid,ifid_fetch_fault,ifid_pc};held_pc=imem_addr;
        saved_fault_pc=fault_pc;saved_cause=fault_cause;was_redirect=fetch_redirect_valid;
        if(rst) begin
            resets=resets+1;
            property_check(0,!imem_en && !dmem_re && !dmem_we && !wb_rd_we,"RESET_GATING");
            age=0;
        end else if(seen_reset) begin
            a=selection(idex_rs1,idex_uses_rs1);b=selection(idex_rs2,idex_uses_rs2);
            property_check(1,fwd_a_sel===a,"FORWARD_A");
            property_check(2,fwd_b_sel===b,"FORWARD_B");
            property_check(3,fwd_store_sel===(idex_valid && idex_mem_write && idex_uses_rs2 ? b : 2'b00),"FORWARD_STORE");
            property_check(4,fwd_nonready_error===(a==3 || b==3),"DIAGNOSTIC_GENERATION");
            property_check(5,exmem_result_ready===!exmem_mem_read,"READINESS_DERIVATION");
            if(a==3 || b==3) begin
                nonready=nonready+1;
                property_check(6,INJECTED,"NO_NONREADY_IN_LEGAL_PROGRAM");
                property_check(7,(a!=3 || fwd_a_sel==3) && (b!=3 || fwd_b_sel==3),"NO_STALE_FALLBACK");
            end
            if(idex_valid && exmem_valid && exmem_reg_write && exmem_rd!=0 && memwb_valid && memwb_reg_write && memwb_rd==exmem_rd &&
               ((idex_uses_rs1 && idex_rs1==exmem_rd) || (idex_uses_rs2 && idex_rs2==exmem_rd))) youngest=youngest+1;
            capture=ifid_valid && !id_evt_valid && idex_valid && idex_mem_read && idex_rd!=0 &&
              ((decode_uses_rs1 && decode_rs1==idex_rd) || (decode_uses_rs2 && decode_rs2==idex_rd));
            property_check(8,hold_if===capture && bubble_ex===capture,"EXACT_LOAD_USE_PREDICATE");
            property_check(9,!(lsu_evt_valid && branch_target_misaligned),"EX_FAULT_SOURCE_EXCLUSIVITY");
            property_check(10,!(dmem_re && dmem_we) && (!(dmem_re || dmem_we) || (idex_valid && !stop_fetch && !ex_evt_valid && dmem_addr>=32'h10000 && dmem_addr<=32'h13fff)),"VALID_MEMORY_PACKET");
            property_check(11,!wb_rd_we || (memwb_valid && memwb_reg_write && memwb_rd!=0 && !halted),"VALID_WB_PACKET");
            property_check(12,drained===empty,"DRAINED_EQUATION");
            if(fetch_redirect_valid) begin
                redirects=redirects+1;
                property_check(13,!stop_fetch && idex_valid && !ex_evt_valid && kill_if && kill_id && !kill_ex && !enter_drain,"REDIRECT_QUALIFICATION");
            end
            if(idex_valid && ex_evt_valid) begin
                exfaults=exfaults+1;
                property_check(14,enter_drain && kill_if && kill_id && kill_ex && !fetch_redirect_valid,"EX_FAULT_PRIORITY");
            end else if(id_evt_valid && !fetch_redirect_valid && !stop_fetch) begin
                idevents=idevents+1;
                property_check(15,enter_drain && kill_if && kill_id && !kill_ex,"ID_EVENT_PRESERVES_OLDER_EX");
            end
            if(imem_en) property_check(16,fetch_issue && imem_addr[31:14]==0 && imem_addr[1:0]==0 && !stop_fetch,"LEGAL_FETCH");
            if(stop_fetch) property_check(17,!imem_en && !fetch_issue && !dmem_re && !dmem_we && !idex_valid && !fetch_redirect_valid,"NO_NEW_DRAIN_WORK");
            if(age>0) begin
                property_check(18,!idex_valid,"TWO_REDIRECT_EX_BUBBLES");age=age-1;
            end
            if(was_redirect) age=2;
            if(held) held_count=held_count+1;
        end
        #1;
        if(rst) begin
            property_check(19,fwd_nonready_sticky===0 && !ifid_valid && !idex_valid && !exmem_valid && !memwb_valid && !halted && !retire_valid,"SYNCHRONOUS_RESET_STATE");
            seen_reset=1;
        end else if(seen_reset) begin
            property_check(20,fwd_nonready_sticky===(old_sticky || old_error),"STICKY_CAPTURE_RETENTION");
            if(old_sticky && !old_error) retained=retained+1;
            property_check(21,retire_valid===(TRACE_EN ? old_wb : 1'b0),"REGISTERED_RETIRE_TIMING");
            if(held) property_check(22,{ifid_valid,ifid_fetch_fault,ifid_pc}===metadata && imem_addr===held_pc && !idex_valid,"HOLD_AND_EX_BUBBLE");
            if(was_drain) property_check(23,halted===empty && fault_pc===saved_fault_pc && fault_cause===saved_cause,"FIRST_EMPTY_DRAIN_IMMUTABLE_RECORD");
        end
    end
    final begin
        $display("CHECKER_SUMMARY samples=%0d checks=%0d nonready=%0d youngest=%0d holds=%0d redirects=%0d exfaults=%0d idevents=%0d resets=%0d retained=%0d",samples,checks,nonready,youngest,held_count,redirects,exfaults,idevents,resets,retained);
        for(integer p=0;p<24;p=p+1) $display("PROPERTY_HITS P%0d %0d",p,property_hits[p]);
    end
endmodule
