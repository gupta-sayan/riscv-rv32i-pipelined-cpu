// Module 13: architectural packet reference model, dual TRACE_EN regression.
// All inputs are explicit packet values; no hierarchical DUT state is read.
module tb_pipeline_regs;
    timeunit 1ns; timeprecision 1ps;
    logic clk=0;
    logic rst=0;
    logic kill_if=0;
    logic hold_if=0;
    logic kill_id=0;
    logic bubble_ex=0;
    logic kill_ex=0;
    logic fetch_issue=0;
    logic fetch_token_fault=0;
    logic id_valid=0;
    logic ex_valid=0;
    logic mem_valid=0;
    logic [31:0] imem_addr=0;
    logic [31:0] id_pc=0;
    logic [31:0] id_instr=0;
    logic [4:0] id_rs1=0;
    logic [4:0] id_rs2=0;
    logic [4:0] id_rd=0;
    logic [31:0] id_rs1_value=0;
    logic [31:0] id_rs2_value=0;
    logic [31:0] id_imm=0;
    logic [3:0] id_alu_op=0;
    logic [2:0] id_imm_kind=0;
    logic [1:0] id_op_a_sel=0;
    logic [1:0] id_op_b_sel=0;
    logic [2:0] id_br_kind=0;
    logic id_uses_rs1=0;
    logic id_uses_rs2=0;
    logic id_is_jal=0;
    logic id_is_jalr=0;
    logic id_mem_read=0;
    logic id_mem_write=0;
    logic [1:0] id_mem_size=0;
    logic id_load_unsigned=0;
    logic id_reg_write=0;
    logic [1:0] id_wb_sel=0;
    logic [31:0] ex_pc=0;
    logic [31:0] ex_instr=0;
    logic [4:0] ex_rd=0;
    logic ex_reg_write=0;
    logic [1:0] ex_wb_sel=0;
    logic [31:0] ex_result=0;
    logic ex_mem_read=0;
    logic ex_mem_write=0;
    logic [1:0] ex_mem_size=0;
    logic ex_load_unsigned=0;
    logic [1:0] ex_load_lane=0;
    logic [31:0] ex_mem_addr=0;
    logic [31:0] ex_mem_wdata=0;
    logic [3:0] ex_mem_wmask=0;
    logic [31:0] mem_pc=0;
    logic [4:0] mem_rd=0;
    logic mem_reg_write=0;
    logic [31:0] mem_wb_data=0;
    logic mem_read=0;
    logic mem_write=0;
    logic [31:0] mem_instr=0;
    logic [31:0] mem_addr=0;
    logic [31:0] mem_wdata=0;
    logic [3:0] mem_wmask=0;
    logic [31:0] mem_rdata=0;
    wire ifid_valid[0:1];
    logic expected_ifid_valid[0:1];
    logic seen_one_ifid_valid=0, seen_zero_ifid_valid=0;
    wire [31:0] ifid_pc[0:1];
    logic [31:0] expected_ifid_pc[0:1];
    logic [31:0] seen_one_ifid_pc=0, seen_zero_ifid_pc=0;
    wire ifid_fetch_fault[0:1];
    logic expected_ifid_fetch_fault[0:1];
    logic seen_one_ifid_fetch_fault=0, seen_zero_ifid_fetch_fault=0;
    wire idex_valid[0:1];
    logic expected_idex_valid[0:1];
    logic seen_one_idex_valid=0, seen_zero_idex_valid=0;
    wire [31:0] idex_pc[0:1];
    logic [31:0] expected_idex_pc[0:1];
    logic [31:0] seen_one_idex_pc=0, seen_zero_idex_pc=0;
    wire [31:0] idex_instr[0:1];
    logic [31:0] expected_idex_instr[0:1];
    logic [31:0] seen_one_idex_instr=0, seen_zero_idex_instr=0;
    wire [4:0] idex_rs1[0:1];
    logic [4:0] expected_idex_rs1[0:1];
    logic [4:0] seen_one_idex_rs1=0, seen_zero_idex_rs1=0;
    wire [4:0] idex_rs2[0:1];
    logic [4:0] expected_idex_rs2[0:1];
    logic [4:0] seen_one_idex_rs2=0, seen_zero_idex_rs2=0;
    wire [4:0] idex_rd[0:1];
    logic [4:0] expected_idex_rd[0:1];
    logic [4:0] seen_one_idex_rd=0, seen_zero_idex_rd=0;
    wire [31:0] idex_rs1_value[0:1];
    logic [31:0] expected_idex_rs1_value[0:1];
    logic [31:0] seen_one_idex_rs1_value=0, seen_zero_idex_rs1_value=0;
    wire [31:0] idex_rs2_value[0:1];
    logic [31:0] expected_idex_rs2_value[0:1];
    logic [31:0] seen_one_idex_rs2_value=0, seen_zero_idex_rs2_value=0;
    wire [31:0] idex_imm[0:1];
    logic [31:0] expected_idex_imm[0:1];
    logic [31:0] seen_one_idex_imm=0, seen_zero_idex_imm=0;
    wire [3:0] idex_alu_op[0:1];
    logic [3:0] expected_idex_alu_op[0:1];
    logic [3:0] seen_one_idex_alu_op=0, seen_zero_idex_alu_op=0;
    wire [2:0] idex_imm_kind[0:1];
    logic [2:0] expected_idex_imm_kind[0:1];
    logic [2:0] seen_one_idex_imm_kind=0, seen_zero_idex_imm_kind=0;
    wire [1:0] idex_op_a_sel[0:1];
    logic [1:0] expected_idex_op_a_sel[0:1];
    logic [1:0] seen_one_idex_op_a_sel=0, seen_zero_idex_op_a_sel=0;
    wire [1:0] idex_op_b_sel[0:1];
    logic [1:0] expected_idex_op_b_sel[0:1];
    logic [1:0] seen_one_idex_op_b_sel=0, seen_zero_idex_op_b_sel=0;
    wire [2:0] idex_br_kind[0:1];
    logic [2:0] expected_idex_br_kind[0:1];
    logic [2:0] seen_one_idex_br_kind=0, seen_zero_idex_br_kind=0;
    wire idex_uses_rs1[0:1];
    logic expected_idex_uses_rs1[0:1];
    logic seen_one_idex_uses_rs1=0, seen_zero_idex_uses_rs1=0;
    wire idex_uses_rs2[0:1];
    logic expected_idex_uses_rs2[0:1];
    logic seen_one_idex_uses_rs2=0, seen_zero_idex_uses_rs2=0;
    wire idex_is_jal[0:1];
    logic expected_idex_is_jal[0:1];
    logic seen_one_idex_is_jal=0, seen_zero_idex_is_jal=0;
    wire idex_is_jalr[0:1];
    logic expected_idex_is_jalr[0:1];
    logic seen_one_idex_is_jalr=0, seen_zero_idex_is_jalr=0;
    wire idex_mem_read[0:1];
    logic expected_idex_mem_read[0:1];
    logic seen_one_idex_mem_read=0, seen_zero_idex_mem_read=0;
    wire idex_mem_write[0:1];
    logic expected_idex_mem_write[0:1];
    logic seen_one_idex_mem_write=0, seen_zero_idex_mem_write=0;
    wire [1:0] idex_mem_size[0:1];
    logic [1:0] expected_idex_mem_size[0:1];
    logic [1:0] seen_one_idex_mem_size=0, seen_zero_idex_mem_size=0;
    wire idex_load_unsigned[0:1];
    logic expected_idex_load_unsigned[0:1];
    logic seen_one_idex_load_unsigned=0, seen_zero_idex_load_unsigned=0;
    wire idex_reg_write[0:1];
    logic expected_idex_reg_write[0:1];
    logic seen_one_idex_reg_write=0, seen_zero_idex_reg_write=0;
    wire [1:0] idex_wb_sel[0:1];
    logic [1:0] expected_idex_wb_sel[0:1];
    logic [1:0] seen_one_idex_wb_sel=0, seen_zero_idex_wb_sel=0;
    wire exmem_valid[0:1];
    logic expected_exmem_valid[0:1];
    logic seen_one_exmem_valid=0, seen_zero_exmem_valid=0;
    wire [31:0] exmem_pc[0:1];
    logic [31:0] expected_exmem_pc[0:1];
    logic [31:0] seen_one_exmem_pc=0, seen_zero_exmem_pc=0;
    wire [31:0] exmem_instr[0:1];
    logic [31:0] expected_exmem_instr[0:1];
    logic [31:0] seen_one_exmem_instr=0, seen_zero_exmem_instr=0;
    wire [4:0] exmem_rd[0:1];
    logic [4:0] expected_exmem_rd[0:1];
    logic [4:0] seen_one_exmem_rd=0, seen_zero_exmem_rd=0;
    wire exmem_reg_write[0:1];
    logic expected_exmem_reg_write[0:1];
    logic seen_one_exmem_reg_write=0, seen_zero_exmem_reg_write=0;
    wire [1:0] exmem_wb_sel[0:1];
    logic [1:0] expected_exmem_wb_sel[0:1];
    logic [1:0] seen_one_exmem_wb_sel=0, seen_zero_exmem_wb_sel=0;
    wire [31:0] exmem_ex_result[0:1];
    logic [31:0] expected_exmem_ex_result[0:1];
    logic [31:0] seen_one_exmem_ex_result=0, seen_zero_exmem_ex_result=0;
    wire exmem_mem_read[0:1];
    logic expected_exmem_mem_read[0:1];
    logic seen_one_exmem_mem_read=0, seen_zero_exmem_mem_read=0;
    wire exmem_mem_write[0:1];
    logic expected_exmem_mem_write[0:1];
    logic seen_one_exmem_mem_write=0, seen_zero_exmem_mem_write=0;
    wire [1:0] exmem_mem_size[0:1];
    logic [1:0] expected_exmem_mem_size[0:1];
    logic [1:0] seen_one_exmem_mem_size=0, seen_zero_exmem_mem_size=0;
    wire exmem_load_unsigned[0:1];
    logic expected_exmem_load_unsigned[0:1];
    logic seen_one_exmem_load_unsigned=0, seen_zero_exmem_load_unsigned=0;
    wire [1:0] exmem_load_lane[0:1];
    logic [1:0] expected_exmem_load_lane[0:1];
    logic [1:0] seen_one_exmem_load_lane=0, seen_zero_exmem_load_lane=0;
    wire [31:0] exmem_mem_addr[0:1];
    logic [31:0] expected_exmem_mem_addr[0:1];
    logic [31:0] seen_one_exmem_mem_addr=0, seen_zero_exmem_mem_addr=0;
    wire [31:0] exmem_mem_wdata[0:1];
    logic [31:0] expected_exmem_mem_wdata[0:1];
    logic [31:0] seen_one_exmem_mem_wdata=0, seen_zero_exmem_mem_wdata=0;
    wire [3:0] exmem_mem_wmask[0:1];
    logic [3:0] expected_exmem_mem_wmask[0:1];
    logic [3:0] seen_one_exmem_mem_wmask=0, seen_zero_exmem_mem_wmask=0;
    wire memwb_valid[0:1];
    logic expected_memwb_valid[0:1];
    logic seen_one_memwb_valid=0, seen_zero_memwb_valid=0;
    wire [31:0] memwb_pc[0:1];
    logic [31:0] expected_memwb_pc[0:1];
    logic [31:0] seen_one_memwb_pc=0, seen_zero_memwb_pc=0;
    wire [4:0] memwb_rd[0:1];
    logic [4:0] expected_memwb_rd[0:1];
    logic [4:0] seen_one_memwb_rd=0, seen_zero_memwb_rd=0;
    wire memwb_reg_write[0:1];
    logic expected_memwb_reg_write[0:1];
    logic seen_one_memwb_reg_write=0, seen_zero_memwb_reg_write=0;
    wire [31:0] memwb_wb_data[0:1];
    logic [31:0] expected_memwb_wb_data[0:1];
    logic [31:0] seen_one_memwb_wb_data=0, seen_zero_memwb_wb_data=0;
    wire memwb_mem_read[0:1];
    logic expected_memwb_mem_read[0:1];
    logic seen_one_memwb_mem_read=0, seen_zero_memwb_mem_read=0;
    wire memwb_mem_write[0:1];
    logic expected_memwb_mem_write[0:1];
    logic seen_one_memwb_mem_write=0, seen_zero_memwb_mem_write=0;
    wire [31:0] memwb_instr[0:1];
    logic [31:0] expected_memwb_instr[0:1];
    logic [31:0] seen_one_memwb_instr=0, seen_zero_memwb_instr=0;
    wire [31:0] memwb_mem_addr[0:1];
    logic [31:0] expected_memwb_mem_addr[0:1];
    logic [31:0] seen_one_memwb_mem_addr=0, seen_zero_memwb_mem_addr=0;
    wire [31:0] memwb_mem_wdata[0:1];
    logic [31:0] expected_memwb_mem_wdata[0:1];
    logic [31:0] seen_one_memwb_mem_wdata=0, seen_zero_memwb_mem_wdata=0;
    wire [3:0] memwb_mem_wmask[0:1];
    logic [3:0] expected_memwb_mem_wmask[0:1];
    logic [3:0] seen_one_memwb_mem_wmask=0, seen_zero_memwb_mem_wmask=0;
    wire [31:0] memwb_mem_rdata[0:1];
    logic [31:0] expected_memwb_mem_rdata[0:1];
    logic [31:0] seen_one_memwb_mem_rdata=0, seen_zero_memwb_mem_rdata=0;
    for(genvar t=0;t<2;t=t+1) begin : configs
        pipeline_regs #(.TRACE_EN(t==1)) dut (
            .clk(clk),
            .rst(rst),
            .kill_if(kill_if),
            .hold_if(hold_if),
            .kill_id(kill_id),
            .bubble_ex(bubble_ex),
            .kill_ex(kill_ex),
            .fetch_issue(fetch_issue),
            .fetch_token_fault(fetch_token_fault),
            .id_valid(id_valid),
            .ex_valid(ex_valid),
            .mem_valid(mem_valid),
            .imem_addr(imem_addr),
            .id_pc(id_pc),
            .id_instr(id_instr),
            .id_rs1(id_rs1),
            .id_rs2(id_rs2),
            .id_rd(id_rd),
            .id_rs1_value(id_rs1_value),
            .id_rs2_value(id_rs2_value),
            .id_imm(id_imm),
            .id_alu_op(id_alu_op),
            .id_imm_kind(id_imm_kind),
            .id_op_a_sel(id_op_a_sel),
            .id_op_b_sel(id_op_b_sel),
            .id_br_kind(id_br_kind),
            .id_uses_rs1(id_uses_rs1),
            .id_uses_rs2(id_uses_rs2),
            .id_is_jal(id_is_jal),
            .id_is_jalr(id_is_jalr),
            .id_mem_read(id_mem_read),
            .id_mem_write(id_mem_write),
            .id_mem_size(id_mem_size),
            .id_load_unsigned(id_load_unsigned),
            .id_reg_write(id_reg_write),
            .id_wb_sel(id_wb_sel),
            .ex_pc(ex_pc),
            .ex_instr(ex_instr),
            .ex_rd(ex_rd),
            .ex_reg_write(ex_reg_write),
            .ex_wb_sel(ex_wb_sel),
            .ex_result(ex_result),
            .ex_mem_read(ex_mem_read),
            .ex_mem_write(ex_mem_write),
            .ex_mem_size(ex_mem_size),
            .ex_load_unsigned(ex_load_unsigned),
            .ex_load_lane(ex_load_lane),
            .ex_mem_addr(ex_mem_addr),
            .ex_mem_wdata(ex_mem_wdata),
            .ex_mem_wmask(ex_mem_wmask),
            .mem_pc(mem_pc),
            .mem_rd(mem_rd),
            .mem_reg_write(mem_reg_write),
            .mem_wb_data(mem_wb_data),
            .mem_read(mem_read),
            .mem_write(mem_write),
            .mem_instr(mem_instr),
            .mem_addr(mem_addr),
            .mem_wdata(mem_wdata),
            .mem_wmask(mem_wmask),
            .mem_rdata(mem_rdata),
            .ifid_valid(ifid_valid[t]),
            .ifid_pc(ifid_pc[t]),
            .ifid_fetch_fault(ifid_fetch_fault[t]),
            .idex_valid(idex_valid[t]),
            .idex_pc(idex_pc[t]),
            .idex_instr(idex_instr[t]),
            .idex_rs1(idex_rs1[t]),
            .idex_rs2(idex_rs2[t]),
            .idex_rd(idex_rd[t]),
            .idex_rs1_value(idex_rs1_value[t]),
            .idex_rs2_value(idex_rs2_value[t]),
            .idex_imm(idex_imm[t]),
            .idex_alu_op(idex_alu_op[t]),
            .idex_imm_kind(idex_imm_kind[t]),
            .idex_op_a_sel(idex_op_a_sel[t]),
            .idex_op_b_sel(idex_op_b_sel[t]),
            .idex_br_kind(idex_br_kind[t]),
            .idex_uses_rs1(idex_uses_rs1[t]),
            .idex_uses_rs2(idex_uses_rs2[t]),
            .idex_is_jal(idex_is_jal[t]),
            .idex_is_jalr(idex_is_jalr[t]),
            .idex_mem_read(idex_mem_read[t]),
            .idex_mem_write(idex_mem_write[t]),
            .idex_mem_size(idex_mem_size[t]),
            .idex_load_unsigned(idex_load_unsigned[t]),
            .idex_reg_write(idex_reg_write[t]),
            .idex_wb_sel(idex_wb_sel[t]),
            .exmem_valid(exmem_valid[t]),
            .exmem_pc(exmem_pc[t]),
            .exmem_instr(exmem_instr[t]),
            .exmem_rd(exmem_rd[t]),
            .exmem_reg_write(exmem_reg_write[t]),
            .exmem_wb_sel(exmem_wb_sel[t]),
            .exmem_ex_result(exmem_ex_result[t]),
            .exmem_mem_read(exmem_mem_read[t]),
            .exmem_mem_write(exmem_mem_write[t]),
            .exmem_mem_size(exmem_mem_size[t]),
            .exmem_load_unsigned(exmem_load_unsigned[t]),
            .exmem_load_lane(exmem_load_lane[t]),
            .exmem_mem_addr(exmem_mem_addr[t]),
            .exmem_mem_wdata(exmem_mem_wdata[t]),
            .exmem_mem_wmask(exmem_mem_wmask[t]),
            .memwb_valid(memwb_valid[t]),
            .memwb_pc(memwb_pc[t]),
            .memwb_rd(memwb_rd[t]),
            .memwb_reg_write(memwb_reg_write[t]),
            .memwb_wb_data(memwb_wb_data[t]),
            .memwb_mem_read(memwb_mem_read[t]),
            .memwb_mem_write(memwb_mem_write[t]),
            .memwb_instr(memwb_instr[t]),
            .memwb_mem_addr(memwb_mem_addr[t]),
            .memwb_mem_wdata(memwb_mem_wdata[t]),
            .memwb_mem_wmask(memwb_mem_wmask[t]),
            .memwb_mem_rdata(memwb_mem_rdata[t])
        );
    end
    integer vectors=0, checks=0, failures=0, directed=0, randomized=0;
    integer model_checks[0:1], model_failures[0:1];
    integer control_seen[0:2047];
    integer i,t;
    logic initialized=0;
    logic [31:0] rng=32'h13c0ffee;
    logic [10:0] random_flags;
    function automatic [31:0] random_word();
        rng=rng^(rng<<13); rng=rng^(rng>>17); rng=rng^(rng<<5);
        return rng;
    endfunction
    task automatic verify(input bit ok, input string name);
        checks=checks+1;
        if(!ok) begin
            failures=failures+1;
            if(failures<30) $display("FAIL vector=%0d time=%0t %s",vectors,$time,name);
        end
    endtask
    task automatic field_check(input logic [31:0] actual, predicted,
                               input string name, input integer cfg);
        model_checks[cfg]=model_checks[cfg]+1;
        if(actual !== predicted) begin
            model_failures[cfg]=model_failures[cfg]+1;
            if(failures<30) $display("DETAIL trace=%0d field=%s actual=%h expected=%h",cfg,name,actual,predicted);
        end
        verify(actual === predicted,name);
    endtask
    task automatic random_payload();
        imem_addr=32'(random_word());
        id_pc=32'(random_word());
        id_instr=32'(random_word());
        id_rs1=5'(random_word());
        id_rs2=5'(random_word());
        id_rd=5'(random_word());
        id_rs1_value=32'(random_word());
        id_rs2_value=32'(random_word());
        id_imm=32'(random_word());
        id_alu_op=4'(random_word());
        id_imm_kind=3'(random_word());
        id_op_a_sel=2'(random_word());
        id_op_b_sel=2'(random_word());
        id_br_kind=3'(random_word());
        id_uses_rs1=1'(random_word());
        id_uses_rs2=1'(random_word());
        id_is_jal=1'(random_word());
        id_is_jalr=1'(random_word());
        id_mem_read=1'(random_word());
        id_mem_write=1'(random_word());
        id_mem_size=2'(random_word());
        id_load_unsigned=1'(random_word());
        id_reg_write=1'(random_word());
        id_wb_sel=2'(random_word());
        ex_pc=32'(random_word());
        ex_instr=32'(random_word());
        ex_rd=5'(random_word());
        ex_reg_write=1'(random_word());
        ex_wb_sel=2'(random_word());
        ex_result=32'(random_word());
        ex_mem_read=1'(random_word());
        ex_mem_write=1'(random_word());
        ex_mem_size=2'(random_word());
        ex_load_unsigned=1'(random_word());
        ex_load_lane=2'(random_word());
        ex_mem_addr=32'(random_word());
        ex_mem_wdata=32'(random_word());
        ex_mem_wmask=4'(random_word());
        mem_pc=32'(random_word());
        mem_rd=5'(random_word());
        mem_reg_write=1'(random_word());
        mem_wb_data=32'(random_word());
        mem_read=1'(random_word());
        mem_write=1'(random_word());
        mem_instr=32'(random_word());
        mem_addr=32'(random_word());
        mem_wdata=32'(random_word());
        mem_wmask=4'(random_word());
        mem_rdata=32'(random_word());
    endtask
    task automatic predict();
        for(integer c=0;c<2;c=c+1) begin
            // Select architectural slot actions, then capture a whole packet.
            // Clear values are deterministic verification hygiene per task.
            if(rst || kill_if) begin
                expected_ifid_valid[c]=0; expected_ifid_pc[c]=0; expected_ifid_fetch_fault[c]=0;
            end else if(!hold_if) begin
                expected_ifid_valid[c]=fetch_issue;
                expected_ifid_pc[c]=fetch_issue?imem_addr:0;
                expected_ifid_fetch_fault[c]=fetch_issue?fetch_token_fault:0;
            end
            {expected_idex_valid[c],expected_idex_pc[c],expected_idex_instr[c],expected_idex_rs1[c],expected_idex_rs2[c],expected_idex_rd[c],expected_idex_rs1_value[c],expected_idex_rs2_value[c],expected_idex_imm[c],expected_idex_alu_op[c],expected_idex_imm_kind[c],expected_idex_op_a_sel[c],expected_idex_op_b_sel[c],expected_idex_br_kind[c],expected_idex_uses_rs1[c],expected_idex_uses_rs2[c],expected_idex_is_jal[c],expected_idex_is_jalr[c],expected_idex_mem_read[c],expected_idex_mem_write[c],expected_idex_mem_size[c],expected_idex_load_unsigned[c],expected_idex_reg_write[c],expected_idex_wb_sel[c]}=
                (!rst && !kill_id && !bubble_ex && id_valid) ? {id_valid,id_pc,((c==1)?id_instr:32'd0),id_rs1,id_rs2,id_rd,id_rs1_value,id_rs2_value,id_imm,id_alu_op,id_imm_kind,id_op_a_sel,id_op_b_sel,id_br_kind,id_uses_rs1,id_uses_rs2,id_is_jal,id_is_jalr,id_mem_read,id_mem_write,id_mem_size,id_load_unsigned,id_reg_write,id_wb_sel} : '0;
            {expected_exmem_valid[c],expected_exmem_pc[c],expected_exmem_instr[c],expected_exmem_rd[c],expected_exmem_reg_write[c],expected_exmem_wb_sel[c],expected_exmem_ex_result[c],expected_exmem_mem_read[c],expected_exmem_mem_write[c],expected_exmem_mem_size[c],expected_exmem_load_unsigned[c],expected_exmem_load_lane[c],expected_exmem_mem_addr[c],expected_exmem_mem_wdata[c],expected_exmem_mem_wmask[c]}=
                (!rst && !kill_ex && ex_valid) ? {ex_valid,ex_pc,((c==1)?ex_instr:32'd0),ex_rd,ex_reg_write,ex_wb_sel,ex_result,ex_mem_read,((c==1)?ex_mem_write:1'd0),ex_mem_size,ex_load_unsigned,ex_load_lane,((c==1)?ex_mem_addr:32'd0),((c==1)?ex_mem_wdata:32'd0),((c==1)?ex_mem_wmask:4'd0)} : '0;
            {expected_memwb_valid[c],expected_memwb_pc[c],expected_memwb_rd[c],expected_memwb_reg_write[c],expected_memwb_wb_data[c],expected_memwb_mem_read[c],expected_memwb_mem_write[c],expected_memwb_instr[c],expected_memwb_mem_addr[c],expected_memwb_mem_wdata[c],expected_memwb_mem_wmask[c],expected_memwb_mem_rdata[c]}=
                (!rst && mem_valid) ? {mem_valid,mem_pc,mem_rd,mem_reg_write,mem_wb_data,((c==1)?mem_read:1'd0),((c==1)?mem_write:1'd0),((c==1)?mem_instr:32'd0),((c==1)?mem_addr:32'd0),((c==1)?mem_wdata:32'd0),((c==1)?mem_wmask:4'd0),((c==1)?mem_rdata:32'd0)} : '0;
        end
    endtask
    task automatic observe(input string phase);
        for(integer c=0;c<2;c=c+1) begin
            field_check(32'(ifid_valid[c]),32'(expected_ifid_valid[c]),{phase," ifid_valid"},c);
            field_check(32'(ifid_pc[c]),32'(expected_ifid_pc[c]),{phase," ifid_pc"},c);
            field_check(32'(ifid_fetch_fault[c]),32'(expected_ifid_fetch_fault[c]),{phase," ifid_fetch_fault"},c);
            field_check(32'(idex_valid[c]),32'(expected_idex_valid[c]),{phase," idex_valid"},c);
            field_check(32'(idex_pc[c]),32'(expected_idex_pc[c]),{phase," idex_pc"},c);
            field_check(32'(idex_instr[c]),32'(expected_idex_instr[c]),{phase," idex_instr"},c);
            field_check(32'(idex_rs1[c]),32'(expected_idex_rs1[c]),{phase," idex_rs1"},c);
            field_check(32'(idex_rs2[c]),32'(expected_idex_rs2[c]),{phase," idex_rs2"},c);
            field_check(32'(idex_rd[c]),32'(expected_idex_rd[c]),{phase," idex_rd"},c);
            field_check(32'(idex_rs1_value[c]),32'(expected_idex_rs1_value[c]),{phase," idex_rs1_value"},c);
            field_check(32'(idex_rs2_value[c]),32'(expected_idex_rs2_value[c]),{phase," idex_rs2_value"},c);
            field_check(32'(idex_imm[c]),32'(expected_idex_imm[c]),{phase," idex_imm"},c);
            field_check(32'(idex_alu_op[c]),32'(expected_idex_alu_op[c]),{phase," idex_alu_op"},c);
            field_check(32'(idex_imm_kind[c]),32'(expected_idex_imm_kind[c]),{phase," idex_imm_kind"},c);
            field_check(32'(idex_op_a_sel[c]),32'(expected_idex_op_a_sel[c]),{phase," idex_op_a_sel"},c);
            field_check(32'(idex_op_b_sel[c]),32'(expected_idex_op_b_sel[c]),{phase," idex_op_b_sel"},c);
            field_check(32'(idex_br_kind[c]),32'(expected_idex_br_kind[c]),{phase," idex_br_kind"},c);
            field_check(32'(idex_uses_rs1[c]),32'(expected_idex_uses_rs1[c]),{phase," idex_uses_rs1"},c);
            field_check(32'(idex_uses_rs2[c]),32'(expected_idex_uses_rs2[c]),{phase," idex_uses_rs2"},c);
            field_check(32'(idex_is_jal[c]),32'(expected_idex_is_jal[c]),{phase," idex_is_jal"},c);
            field_check(32'(idex_is_jalr[c]),32'(expected_idex_is_jalr[c]),{phase," idex_is_jalr"},c);
            field_check(32'(idex_mem_read[c]),32'(expected_idex_mem_read[c]),{phase," idex_mem_read"},c);
            field_check(32'(idex_mem_write[c]),32'(expected_idex_mem_write[c]),{phase," idex_mem_write"},c);
            field_check(32'(idex_mem_size[c]),32'(expected_idex_mem_size[c]),{phase," idex_mem_size"},c);
            field_check(32'(idex_load_unsigned[c]),32'(expected_idex_load_unsigned[c]),{phase," idex_load_unsigned"},c);
            field_check(32'(idex_reg_write[c]),32'(expected_idex_reg_write[c]),{phase," idex_reg_write"},c);
            field_check(32'(idex_wb_sel[c]),32'(expected_idex_wb_sel[c]),{phase," idex_wb_sel"},c);
            field_check(32'(exmem_valid[c]),32'(expected_exmem_valid[c]),{phase," exmem_valid"},c);
            field_check(32'(exmem_pc[c]),32'(expected_exmem_pc[c]),{phase," exmem_pc"},c);
            field_check(32'(exmem_instr[c]),32'(expected_exmem_instr[c]),{phase," exmem_instr"},c);
            field_check(32'(exmem_rd[c]),32'(expected_exmem_rd[c]),{phase," exmem_rd"},c);
            field_check(32'(exmem_reg_write[c]),32'(expected_exmem_reg_write[c]),{phase," exmem_reg_write"},c);
            field_check(32'(exmem_wb_sel[c]),32'(expected_exmem_wb_sel[c]),{phase," exmem_wb_sel"},c);
            field_check(32'(exmem_ex_result[c]),32'(expected_exmem_ex_result[c]),{phase," exmem_ex_result"},c);
            field_check(32'(exmem_mem_read[c]),32'(expected_exmem_mem_read[c]),{phase," exmem_mem_read"},c);
            field_check(32'(exmem_mem_write[c]),32'(expected_exmem_mem_write[c]),{phase," exmem_mem_write"},c);
            field_check(32'(exmem_mem_size[c]),32'(expected_exmem_mem_size[c]),{phase," exmem_mem_size"},c);
            field_check(32'(exmem_load_unsigned[c]),32'(expected_exmem_load_unsigned[c]),{phase," exmem_load_unsigned"},c);
            field_check(32'(exmem_load_lane[c]),32'(expected_exmem_load_lane[c]),{phase," exmem_load_lane"},c);
            field_check(32'(exmem_mem_addr[c]),32'(expected_exmem_mem_addr[c]),{phase," exmem_mem_addr"},c);
            field_check(32'(exmem_mem_wdata[c]),32'(expected_exmem_mem_wdata[c]),{phase," exmem_mem_wdata"},c);
            field_check(32'(exmem_mem_wmask[c]),32'(expected_exmem_mem_wmask[c]),{phase," exmem_mem_wmask"},c);
            field_check(32'(memwb_valid[c]),32'(expected_memwb_valid[c]),{phase," memwb_valid"},c);
            field_check(32'(memwb_pc[c]),32'(expected_memwb_pc[c]),{phase," memwb_pc"},c);
            field_check(32'(memwb_rd[c]),32'(expected_memwb_rd[c]),{phase," memwb_rd"},c);
            field_check(32'(memwb_reg_write[c]),32'(expected_memwb_reg_write[c]),{phase," memwb_reg_write"},c);
            field_check(32'(memwb_wb_data[c]),32'(expected_memwb_wb_data[c]),{phase," memwb_wb_data"},c);
            field_check(32'(memwb_mem_read[c]),32'(expected_memwb_mem_read[c]),{phase," memwb_mem_read"},c);
            field_check(32'(memwb_mem_write[c]),32'(expected_memwb_mem_write[c]),{phase," memwb_mem_write"},c);
            field_check(32'(memwb_instr[c]),32'(expected_memwb_instr[c]),{phase," memwb_instr"},c);
            field_check(32'(memwb_mem_addr[c]),32'(expected_memwb_mem_addr[c]),{phase," memwb_mem_addr"},c);
            field_check(32'(memwb_mem_wdata[c]),32'(expected_memwb_mem_wdata[c]),{phase," memwb_mem_wdata"},c);
            field_check(32'(memwb_mem_wmask[c]),32'(expected_memwb_mem_wmask[c]),{phase," memwb_mem_wmask"},c);
            field_check(32'(memwb_mem_rdata[c]),32'(expected_memwb_mem_rdata[c]),{phase," memwb_mem_rdata"},c);
        end
        verify(ifid_valid[0] === ifid_valid[1],{phase," TRACE functional equality ifid_valid"});
        verify(ifid_pc[0] === ifid_pc[1],{phase," TRACE functional equality ifid_pc"});
        verify(ifid_fetch_fault[0] === ifid_fetch_fault[1],{phase," TRACE functional equality ifid_fetch_fault"});
        verify(idex_valid[0] === idex_valid[1],{phase," TRACE functional equality idex_valid"});
        verify(idex_pc[0] === idex_pc[1],{phase," TRACE functional equality idex_pc"});
        verify(idex_rs1[0] === idex_rs1[1],{phase," TRACE functional equality idex_rs1"});
        verify(idex_rs2[0] === idex_rs2[1],{phase," TRACE functional equality idex_rs2"});
        verify(idex_rd[0] === idex_rd[1],{phase," TRACE functional equality idex_rd"});
        verify(idex_rs1_value[0] === idex_rs1_value[1],{phase," TRACE functional equality idex_rs1_value"});
        verify(idex_rs2_value[0] === idex_rs2_value[1],{phase," TRACE functional equality idex_rs2_value"});
        verify(idex_imm[0] === idex_imm[1],{phase," TRACE functional equality idex_imm"});
        verify(idex_alu_op[0] === idex_alu_op[1],{phase," TRACE functional equality idex_alu_op"});
        verify(idex_imm_kind[0] === idex_imm_kind[1],{phase," TRACE functional equality idex_imm_kind"});
        verify(idex_op_a_sel[0] === idex_op_a_sel[1],{phase," TRACE functional equality idex_op_a_sel"});
        verify(idex_op_b_sel[0] === idex_op_b_sel[1],{phase," TRACE functional equality idex_op_b_sel"});
        verify(idex_br_kind[0] === idex_br_kind[1],{phase," TRACE functional equality idex_br_kind"});
        verify(idex_uses_rs1[0] === idex_uses_rs1[1],{phase," TRACE functional equality idex_uses_rs1"});
        verify(idex_uses_rs2[0] === idex_uses_rs2[1],{phase," TRACE functional equality idex_uses_rs2"});
        verify(idex_is_jal[0] === idex_is_jal[1],{phase," TRACE functional equality idex_is_jal"});
        verify(idex_is_jalr[0] === idex_is_jalr[1],{phase," TRACE functional equality idex_is_jalr"});
        verify(idex_mem_read[0] === idex_mem_read[1],{phase," TRACE functional equality idex_mem_read"});
        verify(idex_mem_write[0] === idex_mem_write[1],{phase," TRACE functional equality idex_mem_write"});
        verify(idex_mem_size[0] === idex_mem_size[1],{phase," TRACE functional equality idex_mem_size"});
        verify(idex_load_unsigned[0] === idex_load_unsigned[1],{phase," TRACE functional equality idex_load_unsigned"});
        verify(idex_reg_write[0] === idex_reg_write[1],{phase," TRACE functional equality idex_reg_write"});
        verify(idex_wb_sel[0] === idex_wb_sel[1],{phase," TRACE functional equality idex_wb_sel"});
        verify(exmem_valid[0] === exmem_valid[1],{phase," TRACE functional equality exmem_valid"});
        verify(exmem_pc[0] === exmem_pc[1],{phase," TRACE functional equality exmem_pc"});
        verify(exmem_rd[0] === exmem_rd[1],{phase," TRACE functional equality exmem_rd"});
        verify(exmem_reg_write[0] === exmem_reg_write[1],{phase," TRACE functional equality exmem_reg_write"});
        verify(exmem_wb_sel[0] === exmem_wb_sel[1],{phase," TRACE functional equality exmem_wb_sel"});
        verify(exmem_ex_result[0] === exmem_ex_result[1],{phase," TRACE functional equality exmem_ex_result"});
        verify(exmem_mem_read[0] === exmem_mem_read[1],{phase," TRACE functional equality exmem_mem_read"});
        verify(exmem_mem_size[0] === exmem_mem_size[1],{phase," TRACE functional equality exmem_mem_size"});
        verify(exmem_load_unsigned[0] === exmem_load_unsigned[1],{phase," TRACE functional equality exmem_load_unsigned"});
        verify(exmem_load_lane[0] === exmem_load_lane[1],{phase," TRACE functional equality exmem_load_lane"});
        verify(memwb_valid[0] === memwb_valid[1],{phase," TRACE functional equality memwb_valid"});
        verify(memwb_pc[0] === memwb_pc[1],{phase," TRACE functional equality memwb_pc"});
        verify(memwb_rd[0] === memwb_rd[1],{phase," TRACE functional equality memwb_rd"});
        verify(memwb_reg_write[0] === memwb_reg_write[1],{phase," TRACE functional equality memwb_reg_write"});
        verify(memwb_wb_data[0] === memwb_wb_data[1],{phase," TRACE functional equality memwb_wb_data"});
    endtask
    task automatic step(input logic [10:0] flags, input string label_text);
        vectors=vectors+1;
        {rst,kill_if,hold_if,kill_id,bubble_ex,kill_ex,
         fetch_issue,fetch_token_fault,id_valid,ex_valid,mem_valid}=flags;
        control_seen[flags]=control_seen[flags]+1;
        #1;
        if(initialized) observe({label_text," before rising edge"});
        predict();
        clk=1;
        #1; observe({label_text," after rising edge"});
        clk=0;
        #1; observe({label_text," after falling edge"});
        initialized=1;
        seen_one_ifid_valid=seen_one_ifid_valid|expected_ifid_valid[1];
        seen_zero_ifid_valid=seen_zero_ifid_valid|~expected_ifid_valid[1];
        seen_one_ifid_pc=seen_one_ifid_pc|expected_ifid_pc[1];
        seen_zero_ifid_pc=seen_zero_ifid_pc|~expected_ifid_pc[1];
        seen_one_ifid_fetch_fault=seen_one_ifid_fetch_fault|expected_ifid_fetch_fault[1];
        seen_zero_ifid_fetch_fault=seen_zero_ifid_fetch_fault|~expected_ifid_fetch_fault[1];
        seen_one_idex_valid=seen_one_idex_valid|expected_idex_valid[1];
        seen_zero_idex_valid=seen_zero_idex_valid|~expected_idex_valid[1];
        seen_one_idex_pc=seen_one_idex_pc|expected_idex_pc[1];
        seen_zero_idex_pc=seen_zero_idex_pc|~expected_idex_pc[1];
        seen_one_idex_instr=seen_one_idex_instr|expected_idex_instr[1];
        seen_zero_idex_instr=seen_zero_idex_instr|~expected_idex_instr[1];
        seen_one_idex_rs1=seen_one_idex_rs1|expected_idex_rs1[1];
        seen_zero_idex_rs1=seen_zero_idex_rs1|~expected_idex_rs1[1];
        seen_one_idex_rs2=seen_one_idex_rs2|expected_idex_rs2[1];
        seen_zero_idex_rs2=seen_zero_idex_rs2|~expected_idex_rs2[1];
        seen_one_idex_rd=seen_one_idex_rd|expected_idex_rd[1];
        seen_zero_idex_rd=seen_zero_idex_rd|~expected_idex_rd[1];
        seen_one_idex_rs1_value=seen_one_idex_rs1_value|expected_idex_rs1_value[1];
        seen_zero_idex_rs1_value=seen_zero_idex_rs1_value|~expected_idex_rs1_value[1];
        seen_one_idex_rs2_value=seen_one_idex_rs2_value|expected_idex_rs2_value[1];
        seen_zero_idex_rs2_value=seen_zero_idex_rs2_value|~expected_idex_rs2_value[1];
        seen_one_idex_imm=seen_one_idex_imm|expected_idex_imm[1];
        seen_zero_idex_imm=seen_zero_idex_imm|~expected_idex_imm[1];
        seen_one_idex_alu_op=seen_one_idex_alu_op|expected_idex_alu_op[1];
        seen_zero_idex_alu_op=seen_zero_idex_alu_op|~expected_idex_alu_op[1];
        seen_one_idex_imm_kind=seen_one_idex_imm_kind|expected_idex_imm_kind[1];
        seen_zero_idex_imm_kind=seen_zero_idex_imm_kind|~expected_idex_imm_kind[1];
        seen_one_idex_op_a_sel=seen_one_idex_op_a_sel|expected_idex_op_a_sel[1];
        seen_zero_idex_op_a_sel=seen_zero_idex_op_a_sel|~expected_idex_op_a_sel[1];
        seen_one_idex_op_b_sel=seen_one_idex_op_b_sel|expected_idex_op_b_sel[1];
        seen_zero_idex_op_b_sel=seen_zero_idex_op_b_sel|~expected_idex_op_b_sel[1];
        seen_one_idex_br_kind=seen_one_idex_br_kind|expected_idex_br_kind[1];
        seen_zero_idex_br_kind=seen_zero_idex_br_kind|~expected_idex_br_kind[1];
        seen_one_idex_uses_rs1=seen_one_idex_uses_rs1|expected_idex_uses_rs1[1];
        seen_zero_idex_uses_rs1=seen_zero_idex_uses_rs1|~expected_idex_uses_rs1[1];
        seen_one_idex_uses_rs2=seen_one_idex_uses_rs2|expected_idex_uses_rs2[1];
        seen_zero_idex_uses_rs2=seen_zero_idex_uses_rs2|~expected_idex_uses_rs2[1];
        seen_one_idex_is_jal=seen_one_idex_is_jal|expected_idex_is_jal[1];
        seen_zero_idex_is_jal=seen_zero_idex_is_jal|~expected_idex_is_jal[1];
        seen_one_idex_is_jalr=seen_one_idex_is_jalr|expected_idex_is_jalr[1];
        seen_zero_idex_is_jalr=seen_zero_idex_is_jalr|~expected_idex_is_jalr[1];
        seen_one_idex_mem_read=seen_one_idex_mem_read|expected_idex_mem_read[1];
        seen_zero_idex_mem_read=seen_zero_idex_mem_read|~expected_idex_mem_read[1];
        seen_one_idex_mem_write=seen_one_idex_mem_write|expected_idex_mem_write[1];
        seen_zero_idex_mem_write=seen_zero_idex_mem_write|~expected_idex_mem_write[1];
        seen_one_idex_mem_size=seen_one_idex_mem_size|expected_idex_mem_size[1];
        seen_zero_idex_mem_size=seen_zero_idex_mem_size|~expected_idex_mem_size[1];
        seen_one_idex_load_unsigned=seen_one_idex_load_unsigned|expected_idex_load_unsigned[1];
        seen_zero_idex_load_unsigned=seen_zero_idex_load_unsigned|~expected_idex_load_unsigned[1];
        seen_one_idex_reg_write=seen_one_idex_reg_write|expected_idex_reg_write[1];
        seen_zero_idex_reg_write=seen_zero_idex_reg_write|~expected_idex_reg_write[1];
        seen_one_idex_wb_sel=seen_one_idex_wb_sel|expected_idex_wb_sel[1];
        seen_zero_idex_wb_sel=seen_zero_idex_wb_sel|~expected_idex_wb_sel[1];
        seen_one_exmem_valid=seen_one_exmem_valid|expected_exmem_valid[1];
        seen_zero_exmem_valid=seen_zero_exmem_valid|~expected_exmem_valid[1];
        seen_one_exmem_pc=seen_one_exmem_pc|expected_exmem_pc[1];
        seen_zero_exmem_pc=seen_zero_exmem_pc|~expected_exmem_pc[1];
        seen_one_exmem_instr=seen_one_exmem_instr|expected_exmem_instr[1];
        seen_zero_exmem_instr=seen_zero_exmem_instr|~expected_exmem_instr[1];
        seen_one_exmem_rd=seen_one_exmem_rd|expected_exmem_rd[1];
        seen_zero_exmem_rd=seen_zero_exmem_rd|~expected_exmem_rd[1];
        seen_one_exmem_reg_write=seen_one_exmem_reg_write|expected_exmem_reg_write[1];
        seen_zero_exmem_reg_write=seen_zero_exmem_reg_write|~expected_exmem_reg_write[1];
        seen_one_exmem_wb_sel=seen_one_exmem_wb_sel|expected_exmem_wb_sel[1];
        seen_zero_exmem_wb_sel=seen_zero_exmem_wb_sel|~expected_exmem_wb_sel[1];
        seen_one_exmem_ex_result=seen_one_exmem_ex_result|expected_exmem_ex_result[1];
        seen_zero_exmem_ex_result=seen_zero_exmem_ex_result|~expected_exmem_ex_result[1];
        seen_one_exmem_mem_read=seen_one_exmem_mem_read|expected_exmem_mem_read[1];
        seen_zero_exmem_mem_read=seen_zero_exmem_mem_read|~expected_exmem_mem_read[1];
        seen_one_exmem_mem_write=seen_one_exmem_mem_write|expected_exmem_mem_write[1];
        seen_zero_exmem_mem_write=seen_zero_exmem_mem_write|~expected_exmem_mem_write[1];
        seen_one_exmem_mem_size=seen_one_exmem_mem_size|expected_exmem_mem_size[1];
        seen_zero_exmem_mem_size=seen_zero_exmem_mem_size|~expected_exmem_mem_size[1];
        seen_one_exmem_load_unsigned=seen_one_exmem_load_unsigned|expected_exmem_load_unsigned[1];
        seen_zero_exmem_load_unsigned=seen_zero_exmem_load_unsigned|~expected_exmem_load_unsigned[1];
        seen_one_exmem_load_lane=seen_one_exmem_load_lane|expected_exmem_load_lane[1];
        seen_zero_exmem_load_lane=seen_zero_exmem_load_lane|~expected_exmem_load_lane[1];
        seen_one_exmem_mem_addr=seen_one_exmem_mem_addr|expected_exmem_mem_addr[1];
        seen_zero_exmem_mem_addr=seen_zero_exmem_mem_addr|~expected_exmem_mem_addr[1];
        seen_one_exmem_mem_wdata=seen_one_exmem_mem_wdata|expected_exmem_mem_wdata[1];
        seen_zero_exmem_mem_wdata=seen_zero_exmem_mem_wdata|~expected_exmem_mem_wdata[1];
        seen_one_exmem_mem_wmask=seen_one_exmem_mem_wmask|expected_exmem_mem_wmask[1];
        seen_zero_exmem_mem_wmask=seen_zero_exmem_mem_wmask|~expected_exmem_mem_wmask[1];
        seen_one_memwb_valid=seen_one_memwb_valid|expected_memwb_valid[1];
        seen_zero_memwb_valid=seen_zero_memwb_valid|~expected_memwb_valid[1];
        seen_one_memwb_pc=seen_one_memwb_pc|expected_memwb_pc[1];
        seen_zero_memwb_pc=seen_zero_memwb_pc|~expected_memwb_pc[1];
        seen_one_memwb_rd=seen_one_memwb_rd|expected_memwb_rd[1];
        seen_zero_memwb_rd=seen_zero_memwb_rd|~expected_memwb_rd[1];
        seen_one_memwb_reg_write=seen_one_memwb_reg_write|expected_memwb_reg_write[1];
        seen_zero_memwb_reg_write=seen_zero_memwb_reg_write|~expected_memwb_reg_write[1];
        seen_one_memwb_wb_data=seen_one_memwb_wb_data|expected_memwb_wb_data[1];
        seen_zero_memwb_wb_data=seen_zero_memwb_wb_data|~expected_memwb_wb_data[1];
        seen_one_memwb_mem_read=seen_one_memwb_mem_read|expected_memwb_mem_read[1];
        seen_zero_memwb_mem_read=seen_zero_memwb_mem_read|~expected_memwb_mem_read[1];
        seen_one_memwb_mem_write=seen_one_memwb_mem_write|expected_memwb_mem_write[1];
        seen_zero_memwb_mem_write=seen_zero_memwb_mem_write|~expected_memwb_mem_write[1];
        seen_one_memwb_instr=seen_one_memwb_instr|expected_memwb_instr[1];
        seen_zero_memwb_instr=seen_zero_memwb_instr|~expected_memwb_instr[1];
        seen_one_memwb_mem_addr=seen_one_memwb_mem_addr|expected_memwb_mem_addr[1];
        seen_zero_memwb_mem_addr=seen_zero_memwb_mem_addr|~expected_memwb_mem_addr[1];
        seen_one_memwb_mem_wdata=seen_one_memwb_mem_wdata|expected_memwb_mem_wdata[1];
        seen_zero_memwb_mem_wdata=seen_zero_memwb_mem_wdata|~expected_memwb_mem_wdata[1];
        seen_one_memwb_mem_wmask=seen_one_memwb_mem_wmask|expected_memwb_mem_wmask[1];
        seen_zero_memwb_mem_wmask=seen_zero_memwb_mem_wmask|~expected_memwb_mem_wmask[1];
        seen_one_memwb_mem_rdata=seen_one_memwb_mem_rdata|expected_memwb_mem_rdata[1];
        seen_zero_memwb_mem_rdata=seen_zero_memwb_mem_rdata|~expected_memwb_mem_rdata[1];
    endtask
    task automatic scenario(input logic [5:0] ctrl,input logic [4:0] valid_bits,input string name);
        random_payload();
        step({ctrl,valid_bits},name);
        directed=directed+1;
        $display("DIRECTED %s",name);
    endtask
    initial begin
        for(i=0;i<2048;i=i+1) control_seen[i]=0;
        for(t=0;t<2;t=t+1) begin model_checks[t]=0;model_failures[t]=0;end
        scenario(6'b111111,5'b11111,"reset with every kill/hold/bubble");
        // One all-ones packet ensures every transported field bit can assert.
        imem_addr='1;
        id_pc='1;
        id_instr='1;
        id_rs1='1;
        id_rs2='1;
        id_rd='1;
        id_rs1_value='1;
        id_rs2_value='1;
        id_imm='1;
        id_alu_op='1;
        id_imm_kind='1;
        id_op_a_sel='1;
        id_op_b_sel='1;
        id_br_kind='1;
        id_uses_rs1='1;
        id_uses_rs2='1;
        id_is_jal='1;
        id_is_jalr='1;
        id_mem_read='1;
        id_mem_write='1;
        id_mem_size='1;
        id_load_unsigned='1;
        id_reg_write='1;
        id_wb_sel='1;
        ex_pc='1;
        ex_instr='1;
        ex_rd='1;
        ex_reg_write='1;
        ex_wb_sel='1;
        ex_result='1;
        ex_mem_read='1;
        ex_mem_write='1;
        ex_mem_size='1;
        ex_load_unsigned='1;
        ex_load_lane='1;
        ex_mem_addr='1;
        ex_mem_wdata='1;
        ex_mem_wmask='1;
        mem_pc='1;
        mem_rd='1;
        mem_reg_write='1;
        mem_wb_data='1;
        mem_read='1;
        mem_write='1;
        mem_instr='1;
        mem_addr='1;
        mem_wdata='1;
        mem_wmask='1;
        mem_rdata='1;
        step({6'b000000,5'b11111},"all bits set"); directed=directed+1;
        scenario(6'b000000,5'b10111,"back-to-back valid packets");
        scenario(6'b001010,5'b11111,"IF hold with EX bubble, older packets advance");
        scenario(6'b011000,5'b11111,"IF kill overrides hold");
        scenario(6'b000110,5'b11111,"ID kill and bubble, older packets advance");
        scenario(6'b000100,5'b11111,"ID kill with older packets advancing");
        scenario(6'b000001,5'b11111,"EX kill with MEM/WB advancing");
        scenario(6'b010100,5'b10111,"legal redirect kill pattern preserves EX");
        random_payload(); imem_addr=32'h00004000;
        step({6'b000000,5'b11111},"out-of-range fetch fault token"); directed=directed+1;
        scenario(6'b000000,5'b01000,"no issue and invalid stage packets");
        scenario(6'b000000,5'b00000,"consecutive invalid packet 1");
        scenario(6'b000000,5'b00000,"consecutive invalid packet 2");
        scenario(6'b000000,5'b10111,"resume valid packets");
        // Exhaust all 11 control/valid/fault bits, each after a live packet.
        for(i=0;i<2048;i=i+1) begin
            random_payload(); step({6'b000000,5'b11111},"control sweep preload");
            random_payload(); step(11'(i),"exhaustive control sweep");
        end
        for(i=0;i<10000;i=i+1) begin
            random_payload();random_flags=11'(random_word());
            step(random_flags,"random packets and controls");randomized=randomized+1;
        end
        for(i=0;i<2048;i=i+1) verify(control_seen[i]>0,"control coverage");
        verify((&seen_one_ifid_valid)===1'b1,"all bits asserted ifid_valid");
        verify((&seen_zero_ifid_valid)===1'b1,"all bits cleared ifid_valid");
        verify((&seen_one_ifid_pc)===1'b1,"all bits asserted ifid_pc");
        verify((&seen_zero_ifid_pc)===1'b1,"all bits cleared ifid_pc");
        verify((&seen_one_ifid_fetch_fault)===1'b1,"all bits asserted ifid_fetch_fault");
        verify((&seen_zero_ifid_fetch_fault)===1'b1,"all bits cleared ifid_fetch_fault");
        verify((&seen_one_idex_valid)===1'b1,"all bits asserted idex_valid");
        verify((&seen_zero_idex_valid)===1'b1,"all bits cleared idex_valid");
        verify((&seen_one_idex_pc)===1'b1,"all bits asserted idex_pc");
        verify((&seen_zero_idex_pc)===1'b1,"all bits cleared idex_pc");
        verify((&seen_one_idex_instr)===1'b1,"all bits asserted idex_instr");
        verify((&seen_zero_idex_instr)===1'b1,"all bits cleared idex_instr");
        verify((&seen_one_idex_rs1)===1'b1,"all bits asserted idex_rs1");
        verify((&seen_zero_idex_rs1)===1'b1,"all bits cleared idex_rs1");
        verify((&seen_one_idex_rs2)===1'b1,"all bits asserted idex_rs2");
        verify((&seen_zero_idex_rs2)===1'b1,"all bits cleared idex_rs2");
        verify((&seen_one_idex_rd)===1'b1,"all bits asserted idex_rd");
        verify((&seen_zero_idex_rd)===1'b1,"all bits cleared idex_rd");
        verify((&seen_one_idex_rs1_value)===1'b1,"all bits asserted idex_rs1_value");
        verify((&seen_zero_idex_rs1_value)===1'b1,"all bits cleared idex_rs1_value");
        verify((&seen_one_idex_rs2_value)===1'b1,"all bits asserted idex_rs2_value");
        verify((&seen_zero_idex_rs2_value)===1'b1,"all bits cleared idex_rs2_value");
        verify((&seen_one_idex_imm)===1'b1,"all bits asserted idex_imm");
        verify((&seen_zero_idex_imm)===1'b1,"all bits cleared idex_imm");
        verify((&seen_one_idex_alu_op)===1'b1,"all bits asserted idex_alu_op");
        verify((&seen_zero_idex_alu_op)===1'b1,"all bits cleared idex_alu_op");
        verify((&seen_one_idex_imm_kind)===1'b1,"all bits asserted idex_imm_kind");
        verify((&seen_zero_idex_imm_kind)===1'b1,"all bits cleared idex_imm_kind");
        verify((&seen_one_idex_op_a_sel)===1'b1,"all bits asserted idex_op_a_sel");
        verify((&seen_zero_idex_op_a_sel)===1'b1,"all bits cleared idex_op_a_sel");
        verify((&seen_one_idex_op_b_sel)===1'b1,"all bits asserted idex_op_b_sel");
        verify((&seen_zero_idex_op_b_sel)===1'b1,"all bits cleared idex_op_b_sel");
        verify((&seen_one_idex_br_kind)===1'b1,"all bits asserted idex_br_kind");
        verify((&seen_zero_idex_br_kind)===1'b1,"all bits cleared idex_br_kind");
        verify((&seen_one_idex_uses_rs1)===1'b1,"all bits asserted idex_uses_rs1");
        verify((&seen_zero_idex_uses_rs1)===1'b1,"all bits cleared idex_uses_rs1");
        verify((&seen_one_idex_uses_rs2)===1'b1,"all bits asserted idex_uses_rs2");
        verify((&seen_zero_idex_uses_rs2)===1'b1,"all bits cleared idex_uses_rs2");
        verify((&seen_one_idex_is_jal)===1'b1,"all bits asserted idex_is_jal");
        verify((&seen_zero_idex_is_jal)===1'b1,"all bits cleared idex_is_jal");
        verify((&seen_one_idex_is_jalr)===1'b1,"all bits asserted idex_is_jalr");
        verify((&seen_zero_idex_is_jalr)===1'b1,"all bits cleared idex_is_jalr");
        verify((&seen_one_idex_mem_read)===1'b1,"all bits asserted idex_mem_read");
        verify((&seen_zero_idex_mem_read)===1'b1,"all bits cleared idex_mem_read");
        verify((&seen_one_idex_mem_write)===1'b1,"all bits asserted idex_mem_write");
        verify((&seen_zero_idex_mem_write)===1'b1,"all bits cleared idex_mem_write");
        verify((&seen_one_idex_mem_size)===1'b1,"all bits asserted idex_mem_size");
        verify((&seen_zero_idex_mem_size)===1'b1,"all bits cleared idex_mem_size");
        verify((&seen_one_idex_load_unsigned)===1'b1,"all bits asserted idex_load_unsigned");
        verify((&seen_zero_idex_load_unsigned)===1'b1,"all bits cleared idex_load_unsigned");
        verify((&seen_one_idex_reg_write)===1'b1,"all bits asserted idex_reg_write");
        verify((&seen_zero_idex_reg_write)===1'b1,"all bits cleared idex_reg_write");
        verify((&seen_one_idex_wb_sel)===1'b1,"all bits asserted idex_wb_sel");
        verify((&seen_zero_idex_wb_sel)===1'b1,"all bits cleared idex_wb_sel");
        verify((&seen_one_exmem_valid)===1'b1,"all bits asserted exmem_valid");
        verify((&seen_zero_exmem_valid)===1'b1,"all bits cleared exmem_valid");
        verify((&seen_one_exmem_pc)===1'b1,"all bits asserted exmem_pc");
        verify((&seen_zero_exmem_pc)===1'b1,"all bits cleared exmem_pc");
        verify((&seen_one_exmem_instr)===1'b1,"all bits asserted exmem_instr");
        verify((&seen_zero_exmem_instr)===1'b1,"all bits cleared exmem_instr");
        verify((&seen_one_exmem_rd)===1'b1,"all bits asserted exmem_rd");
        verify((&seen_zero_exmem_rd)===1'b1,"all bits cleared exmem_rd");
        verify((&seen_one_exmem_reg_write)===1'b1,"all bits asserted exmem_reg_write");
        verify((&seen_zero_exmem_reg_write)===1'b1,"all bits cleared exmem_reg_write");
        verify((&seen_one_exmem_wb_sel)===1'b1,"all bits asserted exmem_wb_sel");
        verify((&seen_zero_exmem_wb_sel)===1'b1,"all bits cleared exmem_wb_sel");
        verify((&seen_one_exmem_ex_result)===1'b1,"all bits asserted exmem_ex_result");
        verify((&seen_zero_exmem_ex_result)===1'b1,"all bits cleared exmem_ex_result");
        verify((&seen_one_exmem_mem_read)===1'b1,"all bits asserted exmem_mem_read");
        verify((&seen_zero_exmem_mem_read)===1'b1,"all bits cleared exmem_mem_read");
        verify((&seen_one_exmem_mem_write)===1'b1,"all bits asserted exmem_mem_write");
        verify((&seen_zero_exmem_mem_write)===1'b1,"all bits cleared exmem_mem_write");
        verify((&seen_one_exmem_mem_size)===1'b1,"all bits asserted exmem_mem_size");
        verify((&seen_zero_exmem_mem_size)===1'b1,"all bits cleared exmem_mem_size");
        verify((&seen_one_exmem_load_unsigned)===1'b1,"all bits asserted exmem_load_unsigned");
        verify((&seen_zero_exmem_load_unsigned)===1'b1,"all bits cleared exmem_load_unsigned");
        verify((&seen_one_exmem_load_lane)===1'b1,"all bits asserted exmem_load_lane");
        verify((&seen_zero_exmem_load_lane)===1'b1,"all bits cleared exmem_load_lane");
        verify((&seen_one_exmem_mem_addr)===1'b1,"all bits asserted exmem_mem_addr");
        verify((&seen_zero_exmem_mem_addr)===1'b1,"all bits cleared exmem_mem_addr");
        verify((&seen_one_exmem_mem_wdata)===1'b1,"all bits asserted exmem_mem_wdata");
        verify((&seen_zero_exmem_mem_wdata)===1'b1,"all bits cleared exmem_mem_wdata");
        verify((&seen_one_exmem_mem_wmask)===1'b1,"all bits asserted exmem_mem_wmask");
        verify((&seen_zero_exmem_mem_wmask)===1'b1,"all bits cleared exmem_mem_wmask");
        verify((&seen_one_memwb_valid)===1'b1,"all bits asserted memwb_valid");
        verify((&seen_zero_memwb_valid)===1'b1,"all bits cleared memwb_valid");
        verify((&seen_one_memwb_pc)===1'b1,"all bits asserted memwb_pc");
        verify((&seen_zero_memwb_pc)===1'b1,"all bits cleared memwb_pc");
        verify((&seen_one_memwb_rd)===1'b1,"all bits asserted memwb_rd");
        verify((&seen_zero_memwb_rd)===1'b1,"all bits cleared memwb_rd");
        verify((&seen_one_memwb_reg_write)===1'b1,"all bits asserted memwb_reg_write");
        verify((&seen_zero_memwb_reg_write)===1'b1,"all bits cleared memwb_reg_write");
        verify((&seen_one_memwb_wb_data)===1'b1,"all bits asserted memwb_wb_data");
        verify((&seen_zero_memwb_wb_data)===1'b1,"all bits cleared memwb_wb_data");
        verify((&seen_one_memwb_mem_read)===1'b1,"all bits asserted memwb_mem_read");
        verify((&seen_zero_memwb_mem_read)===1'b1,"all bits cleared memwb_mem_read");
        verify((&seen_one_memwb_mem_write)===1'b1,"all bits asserted memwb_mem_write");
        verify((&seen_zero_memwb_mem_write)===1'b1,"all bits cleared memwb_mem_write");
        verify((&seen_one_memwb_instr)===1'b1,"all bits asserted memwb_instr");
        verify((&seen_zero_memwb_instr)===1'b1,"all bits cleared memwb_instr");
        verify((&seen_one_memwb_mem_addr)===1'b1,"all bits asserted memwb_mem_addr");
        verify((&seen_zero_memwb_mem_addr)===1'b1,"all bits cleared memwb_mem_addr");
        verify((&seen_one_memwb_mem_wdata)===1'b1,"all bits asserted memwb_mem_wdata");
        verify((&seen_zero_memwb_mem_wdata)===1'b1,"all bits cleared memwb_mem_wdata");
        verify((&seen_one_memwb_mem_wmask)===1'b1,"all bits asserted memwb_mem_wmask");
        verify((&seen_zero_memwb_mem_wmask)===1'b1,"all bits cleared memwb_mem_wmask");
        verify((&seen_one_memwb_mem_rdata)===1'b1,"all bits asserted memwb_mem_rdata");
        verify((&seen_zero_memwb_mem_rdata)===1'b1,"all bits cleared memwb_mem_rdata");
        for(t=0;t<2;t=t+1)
            $display("CONFIG TRACE_EN=%0d model_checks=%0d failures=%0d",t,model_checks[t],model_failures[t]);
        $display("COVER controls=2048/2048 each output bit set/clear, functional TRACE equality every observation");
        $display("RESULT vectors=%0d checks=%0d passing=%0d failures=%0d directed=%0d sweep=4096 random=%0d seed=13c0ffee",
                 vectors,checks,checks-failures,failures,directed,randomized);
        if(failures!=0) $fatal(1,"Pipeline register verification failed");
        $finish;
    end
endmodule
