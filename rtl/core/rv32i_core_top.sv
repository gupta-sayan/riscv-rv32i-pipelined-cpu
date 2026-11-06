module rv32i_core_top #(
    parameter bit TRACE_EN = 1'b1
) (
    input  logic clk,
    input  logic rst,

    // Instruction memory
    output logic [31:0] imem_addr,
    output logic        imem_en,
    input  logic [31:0] imem_rdata,

    // Data memory interface
    output logic [31:0] dmem_addr,
    output logic        dmem_re,
    output logic        dmem_we,
    output logic [3:0]  dmem_wmask,
    output logic [31:0] dmem_wdata,
    input  logic [31:0] dmem_rdata,

    // Always-on terminal diagnostics
    output logic        halted,
    output logic [31:0] fault_pc,
    output logic [3:0]  fault_cause,

    // Registered retirement trace
    output logic        retire_valid,
    output logic [31:0] retire_pc,
    output logic [31:0] retire_instr,
    output logic [4:0]  retire_rd,
    output logic        retire_rd_we,
    output logic [31:0] retire_rd_data,

    // Retirement memory metadata
    output logic        retire_mem_valid,
    output logic        retire_mem_write,
    output logic [31:0] retire_mem_addr,
    output logic [3:0]  retire_mem_wmask,
    output logic [31:0] retire_mem_wdata,
    output logic [31:0] retire_mem_rdata
);

// IF stage
logic fetch_issue;
logic fetch_token_fault;
logic fetch_redirect_valid;

logic hold_if;
logic kill_if;
logic stop_fetch;

logic [31:0] redirect_pc;

// IF/ID stage registers
logic ifid_valid;
logic [31:0] ifid_pc;
logic ifid_fetch_fault;

// Fault controller
logic kill_id;
logic kill_ex;
logic bubble_ex;
logic enter_drain;

//ID/EX pipeline registers
logic idex_valid;
logic [31:0] idex_pc;
logic [31:0] idex_instr;

logic [4:0]  idex_rs1;
logic [4:0]  idex_rs2;
logic [4:0]  idex_rd;

logic [31:0] idex_rs1_value;
logic [31:0] idex_rs2_value;
logic [31:0] idex_imm;

//ID/EX execution controls
logic [3:0] idex_alu_op;
logic [2:0] idex_imm_kind;

logic [1:0] idex_op_a_sel;
logic [1:0] idex_op_b_sel;

logic [2:0] idex_br_kind;
logic idex_uses_rs1;
logic idex_uses_rs2;
logic idex_is_jal;
logic idex_is_jalr;

logic idex_mem_read;
logic idex_mem_write;
logic [1:0] idex_mem_size;
logic idex_load_unsigned;

logic idex_reg_write;
logic [1:0] idex_wb_sel;

//EX/MEM boundery 
logic exmem_valid;
logic [31:0] exmem_pc;
logic [31:0] exmem_instr;

logic [4:0]  exmem_rd;
logic exmem_reg_write;
logic [1:0]  exmem_wb_sel;
logic [31:0] exmem_ex_result;

//EX/MEM memory trace
logic exmem_mem_read;
logic [1:0]  exmem_mem_size;
logic exmem_load_unsigned;
logic [1:0]  exmem_load_lane;

logic [31:0] exmem_mem_addr;
logic [31:0] exmem_mem_wdata;
logic [3:0]  exmem_mem_wmask;
logic exmem_mem_write;

//MEM/WB boundery
logic memwb_valid;
logic [31:0] memwb_pc;

logic [4:0]  memwb_rd;
logic memwb_reg_write;
logic [31:0] memwb_wb_data;

//trace
logic [31:0] memwb_instr;

logic memwb_mem_read;
logic memwb_mem_write;

logic [31:0] memwb_mem_addr;
logic [31:0] memwb_mem_wdata;
logic [3:0]  memwb_mem_wmask;
logic [31:0] memwb_mem_rdata;

//ID stage
logic id_valid;
logic decode_legal;

logic id_is_ecall; //Terminal event
logic id_is_ebreak;
logic id_terminal;

logic id_evt_valid; 
logic [3:0]  id_evt_cause;
logic [31:0] id_evt_pc;

logic [4:0]  decode_rs1;
logic [4:0]  decode_rs2;
logic [4:0]  decode_rd;

logic [31:0] rf_rs1_data;
logic [31:0] rf_rs2_data;

logic [31:0] id_rs1_value;
logic [31:0] id_rs2_value;
logic [31:0] id_imm;

logic [3:0]  decode_alu_op;
logic [2:0]  decode_imm_kind;

logic [1:0]  decode_op_a_sel;
logic [1:0]  decode_op_b_sel;

logic [2:0]  decode_br_kind;
logic decode_uses_rs1;
logic decode_uses_rs2;
logic decode_is_jal;
logic decode_is_jalr;

logic decode_mem_read;
logic decode_mem_write;
logic [1:0]  decode_mem_size;
logic decode_load_unsigned;

logic decode_reg_write;
logic [1:0]  decode_wb_sel;

//EX stage
logic [31:0] ex_result_value;
logic [1:0]  ex_load_lane;

logic [31:0] ex_mem_addr;
logic [31:0] ex_mem_wdata;
logic [3:0]  ex_mem_wmask;

logic ex_evt_valid;
logic [3:0]  ex_evt_cause;
logic [31:0] ex_evt_pc;

logic ex_redirect_valid;

logic [31:0] mem_wb_data;

logic [1:0] fwd_a_sel;
logic [1:0] fwd_b_sel;
logic [1:0] fwd_store_sel;

logic fwd_nonready_error;
logic fwd_nonready_sticky;

logic exmem_result_ready;

logic [31:0] ex_rs1_forwarded;
logic [31:0] ex_rs2_forwarded;
logic [31:0] ex_store_forwarded;

//alu
logic [31:0] alu_operand_a;
logic [31:0] alu_operand_b;
logic [31:0] alu_result;

logic branch_target_misaligned;

logic lsu_evt_valid;
logic [3:0] lsu_evt_cause;

//run control
logic run_active;

logic [31:0] load_result; // result of load

//WB signals
logic wb_rd_we;
logic [4:0]  wb_rd;
logic [31:0] wb_data;

// fetch unit
pc_fetch u_pc_fetch (
    .clk (clk),
    .rst (rst),

    .hold_if (hold_if),
    .stop_fetch (stop_fetch),

    .fetch_redirect_valid (fetch_redirect_valid),
    .redirect_pc (redirect_pc),

    .imem_addr (imem_addr),
    .imem_en   (imem_en),

    .fetch_issue (fetch_issue),
    .fetch_token_fault (fetch_token_fault)
);

// decoder
decoder u_decoder (
    .instr(imem_rdata),
    .pc(ifid_pc),
    .fetch_fault(ifid_fetch_fault),

    .legal(decode_legal),
    .rs1(decode_rs1),
    .rs2(decode_rs2),
    .rd(decode_rd),

    .uses_rs1(decode_uses_rs1),
    .uses_rs2(decode_uses_rs2),

    .alu_op(decode_alu_op),
    .imm_kind(decode_imm_kind),
    .op_a_sel(decode_op_a_sel),
    .op_b_sel(decode_op_b_sel),

    .br_kind(decode_br_kind),
    .is_jal(decode_is_jal),
    .is_jalr(decode_is_jalr),

    .mem_read(decode_mem_read),
    .mem_write(decode_mem_write),
    .mem_size(decode_mem_size),
    .load_unsigned(decode_load_unsigned),

    .reg_write(decode_reg_write),
    .wb_sel(decode_wb_sel)
);

// immidiate generator
imm_gen u_imm_gen (
    .instr(imem_rdata),
    .imm_kind(decode_imm_kind),
    .imm(id_imm)
);

//Register file
reg_file u_reg_file (
    .clk(clk),
    .rst(rst),

    .rs1_addr(decode_rs1),
    .rs2_addr(decode_rs2),

    .rs1_data(rf_rs1_data),
    .rs2_data(rf_rs2_data),

    .rd_we(wb_rd_we),
    .rd_addr(wb_rd),
    .rd_data(wb_data)
);

assign id_rs1_value = (decode_rs1 == 5'd0) ? 32'b0 :
                    (wb_rd_we && (wb_rd == decode_rs1)) ? wb_data :
                    rf_rs1_data;

assign id_rs2_value = (decode_rs2 == 5'd0) ? 32'b0 :
                    (wb_rd_we && (wb_rd == decode_rs2)) ? wb_data :
                    rf_rs2_data;

assign id_is_ecall = ifid_valid && !ifid_fetch_fault && (imem_rdata == 32'h00000073);

assign id_is_ebreak = ifid_valid && !ifid_fetch_fault && (imem_rdata == 32'h00100073);

assign id_terminal = ifid_valid && (
                                    ifid_fetch_fault ||
                                    !decode_legal ||
                                    id_is_ebreak ||
                                    id_is_ecall);

assign id_valid = ifid_valid && !id_terminal;

//ID stage terminal event signal
assign id_evt_valid = id_terminal;
assign id_evt_pc    = ifid_pc;

always_comb begin
    id_evt_cause = 4'd0;

    if (ifid_valid) begin
        if (ifid_fetch_fault)
            id_evt_cause = 4'd1;
        else if (!decode_legal)
            id_evt_cause = 4'd2;
        else if (id_is_ebreak)
            id_evt_cause = 4'd3;
        else if (id_is_ecall)
            id_evt_cause = 4'd4;
    end
end

// Fault control module
fault_ctrl u_fault_ctrl (
    .clk(clk),
    .rst(rst),

    .ex_evt_valid(ex_evt_valid),
    .ex_evt_cause(ex_evt_cause),
    .ex_evt_pc(ex_evt_pc),

    .redirect_valid(ex_redirect_valid),
    .idex_valid(idex_valid),

    .id_evt_valid(id_evt_valid),
    .id_evt_cause(id_evt_cause),
    .id_evt_pc(id_evt_pc),

    .exmem_valid(exmem_valid),
    .memwb_valid(memwb_valid),

    .fetch_redirect_valid(fetch_redirect_valid),

    .kill_if(kill_if),
    .kill_id(kill_id),
    .kill_ex(kill_ex),

    .enter_drain(enter_drain),
    .stop_fetch(stop_fetch),
    .halted(halted),
    .fault_pc(fault_pc),
    .fault_cause(fault_cause)
);

// hazard detection module
hazard_ctrl u_hazard_ctrl (
    .ifid_valid(ifid_valid),
    .id_evt_valid(id_evt_valid),
    .ifid_uses_rs1(decode_uses_rs1),
    .ifid_uses_rs2(decode_uses_rs2),
    .ifid_rs1(decode_rs1),
    .ifid_rs2(decode_rs2),

    .idex_valid(idex_valid),
    .idex_mem_read(idex_mem_read),
    .idex_rd(idex_rd),

    .hold_if(hold_if),
    .bubble_ex(bubble_ex)
);

// Forwarding unit module
forward_unit u_forward_unit (
    .idex_valid(idex_valid),
    .idex_rs1(idex_rs1),
    .idex_rs2(idex_rs2),
    .idex_uses_rs1(idex_uses_rs1),
    .idex_uses_rs2(idex_uses_rs2),
    .idex_is_store(idex_mem_write),

    .exmem_valid(exmem_valid),
    .exmem_rd(exmem_rd),
    .exmem_reg_write(exmem_reg_write),
    .exmem_result_ready(exmem_result_ready),

    .memwb_valid(memwb_valid),
    .memwb_rd(memwb_rd),
    .memwb_reg_write(memwb_reg_write),

    .fwd_a_sel(fwd_a_sel),
    .fwd_b_sel(fwd_b_sel),
    .fwd_store_sel(fwd_store_sel),
    .fwd_nonready_error(fwd_nonready_error)
);


assign exmem_result_ready = !exmem_mem_read; //result availability
// forwording logic for rs1
always_comb begin
    case (fwd_a_sel)
        2'b00: ex_rs1_forwarded = idex_rs1_value;
        2'b01: ex_rs1_forwarded = exmem_ex_result;
        2'b10: ex_rs1_forwarded = memwb_wb_data;
        default: ex_rs1_forwarded = idex_rs1_value;
    endcase
end
// forwarding logic for rs2
always_comb begin
    case (fwd_b_sel)
        2'b00: ex_rs2_forwarded = idex_rs2_value;
        2'b01: ex_rs2_forwarded = exmem_ex_result;
        2'b10: ex_rs2_forwarded = memwb_wb_data;
        default: ex_rs2_forwarded = idex_rs2_value;
    endcase
end
// forwarding logic for store
always_comb begin
    case (fwd_store_sel)
        2'b00: ex_store_forwarded = idex_rs2_value;
        2'b01: ex_store_forwarded = exmem_ex_result;
        2'b10: ex_store_forwarded = memwb_wb_data;
        default: ex_store_forwarded = idex_rs2_value;
    endcase
end
// sticky forwarding error
always_ff @(posedge clk) begin
    if (rst) begin
        fwd_nonready_sticky <= 1'b0;
    end
    else if (fwd_nonready_error) begin
        fwd_nonready_sticky <= 1'b1;
    end
end

// alu operand a selection
always_comb begin
    case (idex_op_a_sel)
        2'b00: alu_operand_a = ex_rs1_forwarded;
        2'b01: alu_operand_a = idex_pc;
        2'b10: alu_operand_a = 32'b0;
        default: alu_operand_a = 32'b0;
    endcase
end

// alu operand b selection
always_comb begin
    case (idex_op_b_sel)
        2'b00: alu_operand_b = ex_rs2_forwarded;
        2'b01: alu_operand_b = idex_imm;
        2'b10: alu_operand_b = 32'd4;
        default: alu_operand_b = 32'b0;
    endcase
end

//alu
alu u_alu (
    .a(alu_operand_a),
    .b(alu_operand_b),
    .alu_op(idex_alu_op),
    .result(alu_result)
);

// alu result
assign ex_result_value = (idex_is_jal || idex_is_jalr) ? (idex_pc + 32'd4) : alu_result;

// ex branch unit
branch_unit u_branch_unit (
    .rs1(ex_rs1_forwarded),
    .rs2(ex_rs2_forwarded),
    .pc(idex_pc),
    .imm(idex_imm),
    .br_kind(idex_br_kind),
    .is_jal(idex_is_jal),
    .is_jalr(idex_is_jalr),

    .redirect_valid(ex_redirect_valid),
    .redirect_pc(redirect_pc),
    .target_misaligned(branch_target_misaligned)
);

// EX fault detection
ex_event_mux u_ex_event_mux (
    .idex_valid(idex_valid),
    .idex_pc(idex_pc),

    .lsu_evt_valid(lsu_evt_valid),
    .lsu_evt_cause(lsu_evt_cause),

    .target_misaligned(branch_target_misaligned),

    .ex_evt_valid(ex_evt_valid),
    .ex_evt_cause(ex_evt_cause),
    .ex_evt_pc(ex_evt_pc)
);

// EX stage — Load/Store Unit
assign run_active = !stop_fetch;

lsu_ex u_lsu_ex (
    .eff_addr(alu_result),
    .store_data(ex_store_forwarded),
    .mem_size(idex_mem_size),
    .mem_read(idex_mem_read),
    .mem_write(idex_mem_write),
    .idex_valid(idex_valid),
    .run_active(run_active),
    .rst(rst),

    .dmem_addr(dmem_addr),
    .dmem_re(dmem_re),
    .dmem_we(dmem_we),
    .dmem_wmask(dmem_wmask),
    .dmem_wdata(dmem_wdata),

    .lsu_evt_valid(lsu_evt_valid),
    .lsu_evt_cause(lsu_evt_cause)
);

assign ex_load_lane = alu_result[1:0];

assign ex_mem_addr  = dmem_addr;
assign ex_mem_wdata = dmem_wdata;
assign ex_mem_wmask = dmem_wmask;

//load formatter (MEM)
load_formatter u_load_formatter (
    .dmem_rdata(dmem_rdata),
    .load_lane(exmem_load_lane),
    .mem_size(exmem_mem_size),
    .load_unsigned(exmem_load_unsigned),
    .load_result(load_result)
);

// MEM writeback
always_comb begin
    case (exmem_wb_sel)
        2'b01:  mem_wb_data = exmem_ex_result;
        2'b10:  mem_wb_data = load_result;
        default: mem_wb_data = 32'b0;
    endcase
end

// WB Stage
wb_trace #(
    .TRACE_EN(TRACE_EN)
) u_wb_trace (
    .clk(clk),
    .rst(rst),
    .halted(halted),

    .memwb_valid(memwb_valid),
    .memwb_pc(memwb_pc),
    .memwb_rd(memwb_rd),
    .memwb_reg_write(memwb_reg_write),
    .memwb_wb_data(memwb_wb_data),

    .memwb_instr(memwb_instr),
    .memwb_mem_read(memwb_mem_read),
    .memwb_mem_write(memwb_mem_write),
    .memwb_mem_addr(memwb_mem_addr),
    .memwb_mem_wdata(memwb_mem_wdata),
    .memwb_mem_wmask(memwb_mem_wmask),
    .memwb_mem_rdata(memwb_mem_rdata),

    .wb_rd_we(wb_rd_we),
    .wb_rd(wb_rd),
    .wb_data(wb_data),

    .retire_valid(retire_valid),
    .retire_pc(retire_pc),
    .retire_instr(retire_instr),
    .retire_rd(retire_rd),
    .retire_rd_we(retire_rd_we),
    .retire_rd_data(retire_rd_data),

    .retire_mem_valid(retire_mem_valid),
    .retire_mem_write(retire_mem_write),
    .retire_mem_addr(retire_mem_addr),
    .retire_mem_wmask(retire_mem_wmask),
    .retire_mem_wdata(retire_mem_wdata),
    .retire_mem_rdata(retire_mem_rdata)
);



//pipeline registers
pipeline_regs #(.TRACE_EN(TRACE_EN)) u_pipeline_regs (
    .clk (clk),
    .rst (rst),

    // IF/ID input controls
    .imem_addr (imem_addr),
    .fetch_issue (fetch_issue),
    .fetch_token_fault (fetch_token_fault),
    .kill_if (kill_if),
    .hold_if (hold_if),

    // IF/ID registered outputs
    .ifid_valid (ifid_valid),
    .ifid_pc (ifid_pc),
    .ifid_fetch_fault(ifid_fetch_fault),

    // ID/EX controls and decoded instruction inputs
    .kill_id(kill_id),
    .bubble_ex(bubble_ex),

    .id_valid(id_valid),
    .id_pc(ifid_pc),
    .id_instr(imem_rdata),

    .id_rs1(decode_rs1),
    .id_rs2(decode_rs2),
    .id_rd(decode_rd),

    .id_rs1_value(id_rs1_value),
    .id_rs2_value(id_rs2_value),
    .id_imm(id_imm),

    .id_alu_op(decode_alu_op),
    .id_imm_kind(decode_imm_kind),
    .id_op_a_sel(decode_op_a_sel),
    .id_op_b_sel(decode_op_b_sel),
    .id_br_kind(decode_br_kind),

    .id_uses_rs1(decode_uses_rs1),
    .id_uses_rs2(decode_uses_rs2),
    .id_is_jal(decode_is_jal),
    .id_is_jalr(decode_is_jalr),

    .id_mem_read(decode_mem_read),
    .id_mem_write(decode_mem_write),
    .id_mem_size(decode_mem_size),
    .id_load_unsigned(decode_load_unsigned),

    .id_reg_write(decode_reg_write),
    .id_wb_sel(decode_wb_sel),

    // ID/EX registered outputs
    .idex_valid(idex_valid),
    .idex_pc(idex_pc),
    .idex_instr(idex_instr),

    .idex_rs1(idex_rs1),
    .idex_rs2(idex_rs2),
    .idex_rd(idex_rd),

    .idex_rs1_value(idex_rs1_value),
    .idex_rs2_value(idex_rs2_value),
    .idex_imm(idex_imm),

    .idex_alu_op(idex_alu_op),
    .idex_imm_kind(idex_imm_kind),
    .idex_op_a_sel(idex_op_a_sel),
    .idex_op_b_sel(idex_op_b_sel),

    .idex_br_kind(idex_br_kind),
    .idex_uses_rs1(idex_uses_rs1),
    .idex_uses_rs2(idex_uses_rs2),
    .idex_is_jal(idex_is_jal),
    .idex_is_jalr(idex_is_jalr),

    .idex_mem_read(idex_mem_read),
    .idex_mem_write(idex_mem_write),
    .idex_mem_size(idex_mem_size),
    .idex_load_unsigned(idex_load_unsigned),

    .idex_reg_write(idex_reg_write),
    .idex_wb_sel(idex_wb_sel),

    // EX/MEM control and instruction inputs
    .kill_ex(kill_ex),

    .ex_valid(idex_valid),
    .ex_pc(idex_pc),
    .ex_instr(idex_instr),
    .ex_rd(idex_rd),

    .ex_reg_write(idex_reg_write),
    .ex_wb_sel(idex_wb_sel),

    .ex_result(ex_result_value),

    .ex_mem_read(idex_mem_read),
    .ex_mem_write(idex_mem_write),
    .ex_mem_size(idex_mem_size),
    .ex_load_unsigned(idex_load_unsigned),
    .ex_load_lane(ex_load_lane),

    .ex_mem_addr(ex_mem_addr),
    .ex_mem_wdata(ex_mem_wdata),
    .ex_mem_wmask(ex_mem_wmask),

    // EX/MEM registered outputs
    .exmem_valid(exmem_valid),
    .exmem_pc(exmem_pc),
    .exmem_instr(exmem_instr),

    .exmem_rd(exmem_rd),
    .exmem_reg_write(exmem_reg_write),
    .exmem_wb_sel(exmem_wb_sel),

    .exmem_ex_result(exmem_ex_result),

    // Registered load/store controls
    .exmem_mem_read(exmem_mem_read),
    .exmem_mem_write(exmem_mem_write),
    .exmem_mem_size(exmem_mem_size),
    .exmem_load_unsigned(exmem_load_unsigned),
    .exmem_load_lane(exmem_load_lane),

    // Registered memory-operation metadata
    .exmem_mem_addr(exmem_mem_addr),
    .exmem_mem_wdata(exmem_mem_wdata),
    .exmem_mem_wmask(exmem_mem_wmask),

    // MEM/WB inputs
    .mem_valid(exmem_valid),
    .mem_pc(exmem_pc),
    .mem_rd(exmem_rd),
    .mem_reg_write(exmem_reg_write),

    // Final MEM-stage writeback value
    .mem_wb_data(mem_wb_data),

    // Memory-operation metadata
    .mem_read(exmem_mem_read),
    .mem_write(exmem_mem_write),
    .mem_instr(exmem_instr),
    .mem_addr(exmem_mem_addr),
    .mem_wdata(exmem_mem_wdata),
    .mem_wmask(exmem_mem_wmask),
    .mem_rdata(dmem_rdata),

    // MEM/WB registered outputs
    .memwb_valid(memwb_valid),
    .memwb_pc(memwb_pc),
    .memwb_instr(memwb_instr),

    .memwb_rd(memwb_rd),
    .memwb_reg_write(memwb_reg_write),
    .memwb_wb_data(memwb_wb_data),

    // trace data
    .memwb_mem_read(memwb_mem_read),
    .memwb_mem_write(memwb_mem_write),
    .memwb_mem_addr(memwb_mem_addr),
    .memwb_mem_wdata(memwb_mem_wdata),
    .memwb_mem_wmask(memwb_mem_wmask),
    .memwb_mem_rdata(memwb_mem_rdata)
);

endmodule
