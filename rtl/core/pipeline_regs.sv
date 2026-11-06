module pipeline_regs #(parameter bit TRACE_EN = 1'b1) 
(
    input  logic        clk,
    input  logic        rst,

    input  logic [31:0] imem_addr, // IF Stage
    input  logic        fetch_issue,
    input  logic        fetch_token_fault,

    input  logic        kill_if, // IF/ID control
    input  logic        hold_if, // IF/ID control

    output logic        ifid_valid, // IF/ID registered outputs
    output logic [31:0] ifid_pc,
    output logic        ifid_fetch_fault,

    input logic         kill_id, // ID/EX controls
    input logic         bubble_ex, 
    input logic         id_valid,
    input logic [31:0] id_pc,
    input logic [31:0] id_instr,
    input logic [4:0]  id_rs1,
    input logic [4:0]  id_rs2,
    input logic [4:0]  id_rd,
    input logic [31:0] id_rs1_value,
    input logic [31:0] id_rs2_value,
    input logic [31:0] id_imm,
    input logic [3:0] id_alu_op,
    input logic [2:0] id_imm_kind,
    input logic [1:0] id_op_a_sel,
    input logic [1:0] id_op_b_sel,
    input logic [2:0] id_br_kind,
    input logic       id_uses_rs1,
    input logic       id_uses_rs2,
    input logic       id_is_jal,
    input logic       id_is_jalr,
    input logic       id_mem_read,
    input logic       id_mem_write,
    input logic [1:0] id_mem_size,
    input logic       id_load_unsigned,
    input logic       id_reg_write,
    input logic [1:0] id_wb_sel,

    output logic        idex_valid, // ID/EX registered outputs
    output logic [31:0] idex_pc,
    output logic [31:0] idex_instr,
    output logic [4:0]  idex_rs1,
    output logic [4:0]  idex_rs2,
    output logic [4:0]  idex_rd,
    output logic [31:0] idex_rs1_value,
    output logic [31:0] idex_rs2_value,
    output logic [31:0] idex_imm,
    output logic [3:0] idex_alu_op,
    output logic [2:0] idex_imm_kind,
    output logic [1:0] idex_op_a_sel,
    output logic [1:0] idex_op_b_sel,
    output logic [2:0] idex_br_kind,
    output logic       idex_uses_rs1,
    output logic       idex_uses_rs2,
    output logic       idex_is_jal,
    output logic       idex_is_jalr,
    output logic       idex_mem_read,
    output logic       idex_mem_write,
    output logic [1:0] idex_mem_size,
    output logic       idex_load_unsigned,
    output logic       idex_reg_write,
    output logic [1:0] idex_wb_sel,

    input  logic       kill_ex, // EX/MEM controls
    input  logic       ex_valid,
    input logic [31:0] ex_pc,
    input logic [31:0] ex_instr,
    input logic [4:0]  ex_rd,
    input logic        ex_reg_write,
    input logic [1:0]  ex_wb_sel,
    input logic [31:0] ex_result,
    input logic       ex_mem_read,
    input logic       ex_mem_write,
    input logic [1:0] ex_mem_size,
    input logic       ex_load_unsigned,
    input logic [1:0] ex_load_lane,
    input logic [31:0] ex_mem_addr,
    input logic [31:0] ex_mem_wdata,
    input logic [3:0]  ex_mem_wmask,

    output logic      exmem_valid, // EX/MEM registered outputs
    output logic [31:0] exmem_pc,
    output logic [31:0] exmem_instr,
    output logic [4:0]  exmem_rd,
    output logic        exmem_reg_write,
    output logic [1:0]  exmem_wb_sel,
    output logic [31:0] exmem_ex_result,
    output logic       exmem_mem_read,
    output logic       exmem_mem_write,
    output logic [1:0] exmem_mem_size,
    output logic       exmem_load_unsigned,
    output logic [1:0] exmem_load_lane,
    output logic [31:0] exmem_mem_addr,
    output logic [31:0] exmem_mem_wdata,
    output logic [3:0]  exmem_mem_wmask,

    input  logic        mem_valid, // MEM/WB controls
    input  logic [31:0] mem_pc,
    input  logic [4:0]  mem_rd,
    input  logic        mem_reg_write,
    input  logic [31:0] mem_wb_data,
    input logic        mem_read,
    input logic        mem_write,
    input logic [31:0] mem_instr,
    input logic [31:0] mem_addr,
    input logic [31:0] mem_wdata,
    input logic [3:0]  mem_wmask,
    input logic [31:0] mem_rdata,

    output logic        memwb_valid, // MEM/WB registered outputs
    output logic [31:0] memwb_pc,
    output logic [4:0]  memwb_rd,
    output logic        memwb_reg_write,
    output logic [31:0] memwb_wb_data,
    output logic        memwb_mem_read,
    output logic        memwb_mem_write,
    output logic [31:0] memwb_instr,
    output logic [31:0] memwb_mem_addr,
    output logic [31:0] memwb_mem_wdata,
    output logic [3:0]  memwb_mem_wmask,
    output logic [31:0] memwb_mem_rdata
);

always_ff @(posedge clk) begin 
    if (rst) begin
        ifid_valid       <= 1'b0;
        ifid_pc          <= 32'b0;
        ifid_fetch_fault <= 1'b0;
    end
    else if (kill_if) begin
        ifid_valid       <= 1'b0;
        ifid_pc          <= 32'b0;
        ifid_fetch_fault <= 1'b0;
    end
    else if (!hold_if) begin
        ifid_valid       <= fetch_issue;
        ifid_pc          <= fetch_issue ? imem_addr : 32'b0;
        ifid_fetch_fault <= fetch_issue && fetch_token_fault;
    end
end

always_ff @(posedge clk) begin // ID/EX validity register
    if (rst) begin
        idex_valid <= 1'b0;
    end
    else if (kill_id) begin
        idex_valid <= 1'b0;
    end
    else if (bubble_ex) begin
        idex_valid <= 1'b0;
    end
    else begin
        idex_valid <= id_valid;
    end
end

always_ff @(posedge clk) begin // ID/EX instruction identity and register addresses
    if (rst || kill_id || bubble_ex) begin
        idex_pc  <= 32'b0;
        idex_rs1 <= 5'b0;
        idex_rs2 <= 5'b0;
        idex_rd  <= 5'b0;
    end
    else begin
        idex_pc  <= id_valid ? id_pc  : 32'b0;
        idex_rs1 <= id_valid ? id_rs1 : 5'b0;
        idex_rs2 <= id_valid ? id_rs2 : 5'b0;
        idex_rd  <= id_valid ? id_rd  : 5'b0;
    end
end

always_ff @(posedge clk) begin // ID/EX register values and immediate
    if (rst || kill_id || bubble_ex) begin
        idex_rs1_value <= 32'b0;
        idex_rs2_value <= 32'b0;
        idex_imm       <= 32'b0;
    end
    else begin
        idex_rs1_value <= id_valid ? id_rs1_value : 32'b0;
        idex_rs2_value <= id_valid ? id_rs2_value : 32'b0;
        idex_imm       <= id_valid ? id_imm       : 32'b0;
    end
end

always_ff @(posedge clk) begin // ID/EX ALU and branch control
    if (rst || kill_id || bubble_ex) begin
        idex_alu_op   <= 4'b0;
        idex_imm_kind <= 3'b0;
        idex_op_a_sel <= 2'b0;
        idex_op_b_sel <= 2'b0;
        idex_br_kind  <= 3'b0;
    end
    else begin
        idex_alu_op   <= id_valid ? id_alu_op   : 4'b0;
        idex_imm_kind <= id_valid ? id_imm_kind : 3'b0;
        idex_op_a_sel <= id_valid ? id_op_a_sel : 2'b0;
        idex_op_b_sel <= id_valid ? id_op_b_sel : 2'b0;
        idex_br_kind  <= id_valid ? id_br_kind  : 3'b0;
    end
end

always_ff @(posedge clk) begin // ID/EX register usage and jump flags
    if (rst || kill_id || bubble_ex) begin
        idex_uses_rs1 <= 1'b0;
        idex_uses_rs2 <= 1'b0;
        idex_is_jal   <= 1'b0;
        idex_is_jalr  <= 1'b0;
    end
    else begin
        idex_uses_rs1 <= id_valid && id_uses_rs1;
        idex_uses_rs2 <= id_valid && id_uses_rs2;
        idex_is_jal   <= id_valid && id_is_jal;
        idex_is_jalr  <= id_valid && id_is_jalr;
    end
end

always_ff @(posedge clk) begin // ID/EX memory and write-back control
    if (rst || kill_id || bubble_ex) begin
        idex_mem_read      <= 1'b0;
        idex_mem_write     <= 1'b0;
        idex_mem_size      <= 2'b0;
        idex_load_unsigned <= 1'b0;
        idex_reg_write     <= 1'b0;
        idex_wb_sel        <= 2'b0;
    end
    else begin
        idex_mem_read      <= id_valid && id_mem_read;
        idex_mem_write     <= id_valid && id_mem_write;
        idex_mem_size      <= id_valid ? id_mem_size : 2'b0;
        idex_load_unsigned <= id_valid && id_load_unsigned;
        idex_reg_write     <= id_valid && id_reg_write;
        idex_wb_sel        <= id_valid ? id_wb_sel : 2'b0;
    end
end

generate // ID/EX instruction trace
    if (TRACE_EN) begin : gen_idex_trace
        always_ff @(posedge clk) begin
            if (rst || kill_id || bubble_ex) begin
                idex_instr <= 32'b0;
            end
            else begin
                idex_instr <= id_valid ? id_instr : 32'b0;
            end
        end
    end
    else begin : gen_idex_no_trace
        assign idex_instr = 32'b0;
    end
endgenerate





always_ff @(posedge clk) begin // EX/MEM validity register
    if (rst) begin
        exmem_valid <= 1'b0;
    end
    else if (kill_ex) begin
        exmem_valid <= 1'b0;
    end
    else begin
        exmem_valid <= ex_valid;
    end
end

always_ff @(posedge clk) begin // EX/MEM instruction identity and register addresses
    if (rst || kill_ex) begin
        exmem_pc         <= 32'b0;
        exmem_rd         <= 5'b0;
        exmem_reg_write  <= 1'b0;
        exmem_wb_sel     <= 2'b0;
        exmem_ex_result  <= 32'b0;
    end
    else begin
        exmem_pc         <= ex_valid ? ex_pc        : 32'b0;
        exmem_rd         <= ex_valid ? ex_rd        : 5'b0;
        exmem_reg_write  <= ex_valid && ex_reg_write;
        exmem_wb_sel     <= ex_valid ? ex_wb_sel    : 2'b0;
        exmem_ex_result  <= ex_valid ? ex_result    : 32'b0;
    end
end

always_ff @(posedge clk) begin // EX/MEM memory and write-back control
    if (rst || kill_ex) begin
        exmem_mem_read      <= 1'b0;
        exmem_mem_size      <= 2'b0;
        exmem_load_unsigned <= 1'b0;
        exmem_load_lane     <= 2'b0;
    end
    else begin
        exmem_mem_read      <= ex_valid && ex_mem_read;
        exmem_mem_size      <= ex_valid ? ex_mem_size : 2'b0;
        exmem_load_unsigned <= ex_valid && ex_load_unsigned;
        exmem_load_lane     <= ex_valid ? ex_load_lane : 2'b0;
    end
end

generate // EX/MEM instruction trace
    if (TRACE_EN) begin : gen_exmem_trace
        always_ff @(posedge clk) begin
            if (rst || kill_ex) begin
                exmem_instr     <= 32'b0;
                exmem_mem_addr  <= 32'b0;
                exmem_mem_wdata <= 32'b0;
                exmem_mem_wmask <= 4'b0;
                exmem_mem_write <= 1'b0;
            end
            else begin
                exmem_instr     <= ex_valid ? ex_instr     : 32'b0;
                exmem_mem_addr  <= ex_valid ? ex_mem_addr  : 32'b0;
                exmem_mem_wdata <= ex_valid ? ex_mem_wdata : 32'b0;
                exmem_mem_wmask <= ex_valid ? ex_mem_wmask : 4'b0;
                exmem_mem_write <= ex_valid && ex_mem_write;
            end
        end
    end
    else begin : gen_exmem_no_trace
        assign exmem_instr     = 32'b0;
        assign exmem_mem_addr  = 32'b0;
        assign exmem_mem_wdata = 32'b0;
        assign exmem_mem_wmask = 4'b0;
        assign exmem_mem_write = 1'b0;
    end
endgenerate

always_ff @(posedge clk) begin // MEM/WB instruction identity and register addresses
    if (rst) begin
        memwb_valid     <= 1'b0;
        memwb_pc        <= 32'b0;
        memwb_rd        <= 5'b0;
        memwb_reg_write <= 1'b0;
        memwb_wb_data   <= 32'b0;
    end
    else begin
        memwb_valid     <= mem_valid;
        memwb_pc        <= mem_valid ? mem_pc      : 32'b0;
        memwb_rd        <= mem_valid ? mem_rd      : 5'b0;
        memwb_reg_write <= mem_valid && mem_reg_write;
        memwb_wb_data   <= mem_valid ? mem_wb_data : 32'b0;
    end
end

generate // MEM/WB instruction trace
    if (TRACE_EN) begin : gen_memwb_trace
        always_ff @(posedge clk) begin
            if (rst) begin
                memwb_instr     <= 32'b0;
                memwb_mem_read  <= 1'b0;
                memwb_mem_write <= 1'b0;
                memwb_mem_addr  <= 32'b0;
                memwb_mem_wdata <= 32'b0;
                memwb_mem_wmask <= 4'b0;
                memwb_mem_rdata <= 32'b0;
            end
            else begin
                memwb_instr     <= mem_valid ? mem_instr : 32'b0;
                memwb_mem_read  <= mem_valid && mem_read;
                memwb_mem_write <= mem_valid && mem_write;
                memwb_mem_addr  <= mem_valid ? mem_addr  : 32'b0;
                memwb_mem_wdata <= mem_valid ? mem_wdata : 32'b0;
                memwb_mem_wmask <= mem_valid ? mem_wmask : 4'b0;
                memwb_mem_rdata <= mem_valid ? mem_rdata : 32'b0;
            end
        end
    end
    else begin : gen_memwb_no_trace
        assign memwb_instr     = 32'b0;
        assign memwb_mem_read  = 1'b0;
        assign memwb_mem_write = 1'b0;
        assign memwb_mem_addr  = 32'b0;
        assign memwb_mem_wdata = 32'b0;
        assign memwb_mem_wmask = 4'b0;
        assign memwb_mem_rdata = 32'b0;
    end
endgenerate

endmodule
