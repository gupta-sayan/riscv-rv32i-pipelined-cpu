`timescale 1ns/1ps
module tb_d02_a01;
    parameter bit TRACE_EN=1;
    reg clk=0,rst=1;
    always #5 clk=~clk;
    // NOP instruction source and a deterministic synthetic older-load response.
    rv32i_core_top #(.TRACE_EN(TRACE_EN)) dut(.clk(clk),.rst(rst),.imem_rdata(32'h00000013),.dmem_rdata(32'hcafebabe));
    rv32i_core_top #(.TRACE_EN(TRACE_EN)) control_core(.clk(clk),.rst(rst),.imem_rdata(32'h00000013),.dmem_rdata(32'hcafebabe));
    integer errors=0,checks=0,mode,j,writes,events=0;
    reg [31:0] saved_dut[1:31],saved_control[1:31];
    // Force only upstream pipeline packet fields, never forwarding results,
    // readiness, diagnostic wires, sticky storage, scheduler or write enables.
`define PACKET(field,value) \
    force dut.u_pipeline_regs.field=value; \
    force control_core.u_pipeline_regs.field=value;
`define UNPACK(field) \
    release dut.u_pipeline_regs.field; \
    release control_core.u_pipeline_regs.field;
    task automatic check(input bit ok,input string msg);
        begin checks=checks+1;
            if(!ok) begin errors=errors+1; $display("FAIL D02 mode=%0d trace=%0d t=%0t %s",mode,TRACE_EN,$time,msg); end
        end
    endtask
    task automatic evidence(input string phase);
        $display("CYCLE %s mode=%0d trace=%0d t=%0t rst=%b consumer=%b:%0d:%0d use=%b%b producer=%b:rd%0d:load%b:ready%b older=%b:rd%0d:data%h sels=%b/%b error=%b sticky=%b hold=%b bubble=%b mem=%b%b wb=%b:rd%0d:%h event=%b halt=%b",
          phase,mode,TRACE_EN,$time,rst,dut.idex_valid,dut.idex_rs1,dut.idex_rs2,dut.idex_uses_rs1,dut.idex_uses_rs2,
          dut.exmem_valid,dut.exmem_rd,dut.exmem_mem_read,dut.exmem_result_ready,
          dut.memwb_valid,dut.memwb_rd,dut.memwb_wb_data,dut.fwd_a_sel,dut.fwd_b_sel,dut.fwd_nonready_error,dut.fwd_nonready_sticky,
          dut.hold_if,dut.bubble_ex,dut.dmem_re,dut.dmem_we,dut.wb_rd_we,dut.wb_rd,dut.wb_data,dut.enter_drain,dut.halted);
    endtask
    task automatic quiet_and_equivalent;
        begin
            check({dut.imem_addr,dut.imem_en,dut.fetch_issue,dut.hold_if,dut.bubble_ex,dut.kill_if,dut.kill_id,dut.kill_ex,
              dut.stop_fetch,dut.enter_drain,dut.fetch_redirect_valid,dut.idex_valid,dut.exmem_valid,dut.memwb_valid,
              dut.dmem_re,dut.dmem_we,dut.wb_rd_we,dut.halted,dut.fault_pc,dut.fault_cause}===
              {control_core.imem_addr,control_core.imem_en,control_core.fetch_issue,control_core.hold_if,control_core.bubble_ex,
              control_core.kill_if,control_core.kill_id,control_core.kill_ex,control_core.stop_fetch,control_core.enter_drain,
              control_core.fetch_redirect_valid,control_core.idex_valid,control_core.exmem_valid,control_core.memwb_valid,
              control_core.dmem_re,control_core.dmem_we,control_core.wb_rd_we,control_core.halted,control_core.fault_pc,control_core.fault_cause},"schedule/request/write-enable/fault equivalence");
            check(!dut.hold_if && !dut.bubble_ex && !dut.dmem_re && !dut.dmem_we,"no diagnostic stall or memory transaction");
            check(!dut.enter_drain && !dut.ex_evt_valid && !dut.id_evt_valid && !dut.fetch_redirect_valid && !dut.halted && {dut.fault_pc,dut.fault_cause}===0,"no architectural event");
            check(control_core.fwd_nonready_error===0 && control_core.fwd_nonready_sticky===0,"control core never diagnoses");
            if(dut.wb_rd_we) check(dut.wb_rd===control_core.wb_rd && dut.wb_data===control_core.wb_data,"same intended write payload");
            if(TRACE_EN) begin
                check(dut.retire_valid===control_core.retire_valid,"same retirement schedule");
                if(dut.retire_valid) begin
                    check({dut.retire_pc,dut.retire_instr,dut.retire_rd_we,dut.retire_mem_valid}===
                      {control_core.retire_pc,control_core.retire_instr,control_core.retire_rd_we,control_core.retire_mem_valid},"same meaningful retirement packet");
                    if(dut.retire_rd_we) check({dut.retire_rd,dut.retire_rd_data}==={control_core.retire_rd,control_core.retire_rd_data},"same retired write");
                    if(dut.retire_mem_valid) check({dut.retire_mem_write,dut.retire_mem_addr,dut.retire_mem_rdata}===
                      {control_core.retire_mem_write,control_core.retire_mem_addr,control_core.retire_mem_rdata},"same synthetic load history");
                end
            end else begin
                check({dut.retire_valid,dut.retire_pc,dut.retire_instr,dut.retire_rd,dut.retire_rd_we,dut.retire_rd_data,dut.retire_mem_valid,dut.retire_mem_write,dut.retire_mem_addr,dut.retire_mem_wmask,dut.retire_mem_wdata,dut.retire_mem_rdata}===0,"all disabled DUT trace outputs zero");
                check({control_core.retire_valid,control_core.retire_pc,control_core.retire_instr,control_core.retire_rd,control_core.retire_rd_we,control_core.retire_rd_data,control_core.retire_mem_valid,control_core.retire_mem_write,control_core.retire_mem_addr,control_core.retire_mem_wmask,control_core.retire_mem_wdata,control_core.retire_mem_rdata}===0,"all disabled control trace outputs zero");
            end
        end
    endtask
    task automatic write_check(input integer expected);
        begin
            if(expected==0) check(!dut.wb_rd_we && !control_core.wb_rd_we,"no additional register write");
            else begin
                check(dut.wb_rd_we && dut.wb_rd===7 && dut.wb_data===(expected==1 ? 32'd17 : 32'hcafebabe),"exact synthetic producer write");
                check(control_core.wb_rd_we && control_core.wb_rd===7 && control_core.wb_data===dut.wb_data,"control producer write");
                writes=writes+1;
            end
        end
    endtask
    task automatic selects(input bit error_expected);
        begin
            check(dut.fwd_nonready_error===error_expected && dut.u_forward_unit.fwd_nonready_error===error_expected,"actual integrated combinational diagnostic");
            check(dut.exmem_result_ready===!dut.exmem_mem_read,"unforced readiness derived from load packet");
            check(dut.fwd_a_sel===(mode==1 ? 2'b00 : error_expected ? 2'b11 : 2'b01),"rs1 priority, no stale MEM/WB fallback");
            check(dut.fwd_b_sel===(mode==0 ? 2'b00 : error_expected ? 2'b11 : 2'b01),"rs2 priority, no stale MEM/WB fallback");
            check(dut.fwd_store_sel===0,"non-store consumer has no store selection");
        end
    endtask
    initial begin
        for(mode=0;mode<3;mode=mode+1) begin
            @(negedge clk);rst=1;
            repeat(2) begin @(posedge clk);#1;check(dut.fwd_nonready_sticky===0,"epoch synchronous reset");end
            @(negedge clk);rst=0;
            repeat(6) begin @(posedge clk);#1;quiet_and_equivalent();end
            for(j=1;j<32;j=j+1) begin saved_dut[j]=dut.u_reg_file.register[j];saved_control[j]=control_core.u_reg_file.register[j];end
            writes=0;
            // Prepare the older stale x7=17 via the actual MEM/WB capture path.
            @(negedge clk);
            `PACKET(exmem_valid,1'b1)
            `PACKET(exmem_reg_write,1'b1)
            `PACKET(exmem_rd,5'd7)
            `PACKET(exmem_mem_read,1'b0)
            `PACKET(exmem_wb_sel,2'b01)
            `PACKET(exmem_ex_result,32'd17)
            `PACKET(exmem_pc,32'h80)
            @(posedge clk);write_check(0);#1;quiet_and_equivalent();
            check(dut.memwb_valid && dut.memwb_rd===7 && dut.memwb_wb_data===17,"older stale producer naturally captured");
            @(negedge clk);
            `PACKET(exmem_mem_read,1'b1)
            `PACKET(exmem_wb_sel,2'b10)
            `PACKET(exmem_mem_size,2'b10)
            `PACKET(exmem_load_unsigned,1'b0)
            `PACKET(exmem_load_lane,2'b00)
            `PACKET(exmem_ex_result,32'h10000)
            `PACKET(exmem_pc,32'h84)
            `PACKET(idex_valid,1'b1)
            `PACKET(idex_mem_read,1'b0)
            `PACKET(idex_mem_write,1'b0)
            `PACKET(idex_reg_write,1'b0)
            `PACKET(idex_rd,5'd0)
            `PACKET(idex_rs1_value,32'h11112222)
            `PACKET(idex_rs2_value,32'h33334444)
            force control_core.u_pipeline_regs.idex_rs1=5'd8;
            force control_core.u_pipeline_regs.idex_rs2=5'd8;
            force dut.u_pipeline_regs.idex_rs1=5'd7;
            force dut.u_pipeline_regs.idex_rs2=5'd7;
            case(mode)
                0: begin `PACKET(idex_uses_rs1,1'b1) `PACKET(idex_uses_rs2,1'b0) end
                1: begin `PACKET(idex_uses_rs1,1'b0) `PACKET(idex_uses_rs2,1'b1) end
                2: begin `PACKET(idex_uses_rs1,1'b1) `PACKET(idex_uses_rs2,1'b1) end
            endcase
            #1;selects(1);quiet_and_equivalent();check(dut.fwd_nonready_sticky===0,"no asynchronous sticky capture");evidence("NONREADY_ASSERTS");
            `PACKET(exmem_mem_read,1'b0)
            #1;selects(0);check(dut.fwd_nonready_sticky===0,"ready transition does not capture sticky");evidence("READY_CLEARS_COMBINATIONAL");
            `PACKET(exmem_mem_read,1'b1)
            #1;selects(1);check(dut.fwd_nonready_sticky===0,"reassertion still combinational");evidence("NONREADY_REASSERTS");
            @(posedge clk);write_check(1);quiet_and_equivalent();evidence("CAPTURE_PRE");#1;
            check(dut.fwd_nonready_sticky===1,"sticky captures actual forwarding error at edge");
            check(dut.u_reg_file.register[7]===17,"only intended older producer wrote");
            check(dut.memwb_wb_data===32'hcafebabe && dut.memwb_rd===7,"synthetic load traverses actual MEM/WB data path");
            quiet_and_equivalent();evidence("CAPTURE_POST");events=events+1;
            @(negedge clk);
            `PACKET(exmem_valid,1'b0)
            `PACKET(exmem_mem_read,1'b0)
            `PACKET(exmem_reg_write,1'b0)
            `PACKET(idex_valid,1'b0)
            `PACKET(idex_uses_rs1,1'b0)
            `PACKET(idex_uses_rs2,1'b0)
            #1;check(dut.fwd_nonready_error===0,"removing producer/consumer condition clears actual error");
            check(dut.fwd_nonready_sticky===1,"sticky persists after actual condition removed");evidence("CONDITION_REMOVED");
            @(posedge clk);write_check(2);quiet_and_equivalent();#1;
            check(dut.u_reg_file.register[7]===32'hcafebabe,"only intended injected load wrote");
            check(dut.fwd_nonready_sticky && !dut.fwd_nonready_error,"retention edge with error low");quiet_and_equivalent();
            @(negedge clk);
            `UNPACK(exmem_valid) `UNPACK(exmem_reg_write) `UNPACK(exmem_rd) `UNPACK(exmem_mem_read)
            `UNPACK(exmem_wb_sel) `UNPACK(exmem_ex_result) `UNPACK(exmem_pc)
            `UNPACK(exmem_mem_size) `UNPACK(exmem_load_unsigned) `UNPACK(exmem_load_lane)
            `UNPACK(idex_valid) `UNPACK(idex_mem_read) `UNPACK(idex_mem_write) `UNPACK(idex_reg_write) `UNPACK(idex_rd)
            `UNPACK(idex_rs1_value) `UNPACK(idex_rs2_value) `UNPACK(idex_rs1) `UNPACK(idex_rs2)
            `UNPACK(idex_uses_rs1) `UNPACK(idex_uses_rs2)
            repeat(5) begin @(posedge clk);write_check(0);quiet_and_equivalent();#1;
                check(dut.fwd_nonready_sticky && !dut.fwd_nonready_error,"unforced retention with natural NOP packets");quiet_and_equivalent();evidence("UNFORCED_RETAIN");
            end
            for(j=1;j<32;j=j+1) begin
                check(dut.u_reg_file.register[j]===(j==7 ? 32'hcafebabe : saved_dut[j]),"no unintended DUT GPR writes");
                check(control_core.u_reg_file.register[j]===(j==7 ? 32'hcafebabe : saved_control[j]),"no unintended control GPR writes");
            end
            check(writes==2,"exactly two intended packet writes, no diagnostic writes");
            @(negedge clk);rst=1;#1;
            check(dut.fwd_nonready_sticky===1,"reset assertion does not asynchronously clear sticky");evidence("RESET_BEFORE_EDGE");
            @(posedge clk);write_check(0);check(dut.fwd_nonready_sticky===1,"sticky remains set before reset NBA");#1;
            check(dut.fwd_nonready_sticky===0 && dut.fwd_nonready_error===0,"active synchronous reset clears sticky");quiet_and_equivalent();evidence("RESET_AFTER_EDGE");
            $display("PASS D02 mode=%0d trace=%0d intended_writes=%0d",mode,TRACE_EN,writes);
        end
        if(errors) $fatal(1,"D02 FAIL errors=%0d checks=%0d",errors,checks);
        $display("PASS ALL D02 trace=%0d events=%0d checks=%0d",TRACE_EN,events,checks);$finish;
    end
    initial begin #5000;$fatal(1,"D02 finite watchdog");end
endmodule
