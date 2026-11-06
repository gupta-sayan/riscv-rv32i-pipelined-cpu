
module branch_unit (
    input  logic [31:0] rs1,
    input  logic [31:0] rs2,
    input  logic [31:0] pc,
    input  logic [31:0] imm,
    input  logic [2:0]  br_kind,
    input  logic        is_jal,
    input  logic        is_jalr,

    output logic        redirect_valid,
    output logic [31:0] redirect_pc,
    output logic        target_misaligned
);

logic branch_taken;
logic [31:0] pc_target;
logic [31:0] jalr_target;
assign pc_target = pc + imm;
assign jalr_target = (rs1 + imm) & 32'hfffffffe;

always_comb begin
    branch_taken = 1'b0;

    case (br_kind)

        3'b001: begin
            branch_taken = (rs1 == rs2); // beq
        end
        3'b010: begin
            branch_taken = (rs1 != rs2); // bne
        end
        3'b011: begin
            branch_taken = ($signed(rs1) < $signed(rs2)); // blt
        end
        3'b100: begin
            branch_taken = ($signed(rs1) >= $signed(rs2)); // bge
        end
        3'b101: begin
            branch_taken = (rs1 < rs2); // bltu
        end
        3'b110: begin
            branch_taken = (rs1 >= rs2); // bgeu
        end
        default: begin
            branch_taken = 1'b0;
        end

    endcase
end

always_comb begin // redirect pc
    redirect_pc = 32'b0;

    if (is_jalr) begin
        redirect_pc = jalr_target;
    end
    else if (is_jal || branch_taken) begin
        redirect_pc = pc_target;
    end
end

always_comb begin // target misaligned check
    target_misaligned = 1'b0;

    if (is_jal || is_jalr || branch_taken) begin
        if (redirect_pc[1:0] != 2'b00) begin
            target_misaligned = 1'b1;
        end
    end
end

assign redirect_valid = (is_jalr || is_jal || branch_taken) && !target_misaligned; // final redirect valid signal

endmodule
