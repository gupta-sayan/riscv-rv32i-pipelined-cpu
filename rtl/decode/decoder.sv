module decoder(
    input logic [31:0] instr,
    input logic [31:0] pc,
    input logic        fetch_fault,

    output logic        legal,
    output logic [4:0]  rs1,
    output logic [4:0]  rs2,
    output logic [4:0]  rd,

    output logic        uses_rs1,
    output logic        uses_rs2,

    output logic [3:0]  alu_op,
    output logic [2:0]  imm_kind,

    output logic [1:0]  op_a_sel,
    output logic [1:0]  op_b_sel,

    output logic [2:0]  br_kind,
    output logic        is_jal,
    output logic        is_jalr,

    output logic        mem_read,
    output logic        mem_write,
    output logic [1:0]  mem_size,
    output logic        load_unsigned,

    output logic        reg_write,
    output logic [1:0]  wb_sel
);

logic [6:0] opcode;
logic [2:0] funct3;
logic [6:0] funct7;

assign opcode = instr[6:0];
assign funct3 = instr[14:12];
assign funct7 = instr[31:25];

//default values
always_comb begin
    legal         = 1'b0;

    rs1           = instr[19:15];
    rs2           = instr[24:20];
    rd            = instr[11:7];

    uses_rs1      = 1'b0;
    uses_rs2      = 1'b0;

    alu_op        = 4'b0000;
    imm_kind      = 3'b000;

    op_a_sel      = 2'b00;
    op_b_sel      = 2'b00;

    br_kind       = 3'b000;
    is_jal        = 1'b0;
    is_jalr       = 1'b0;

    mem_read      = 1'b0;
    mem_write     = 1'b0;
    mem_size      = 2'b00;
    load_unsigned = 1'b0;

    reg_write     = 1'b0;
    wb_sel        = 2'b00;

    if (!fetch_fault) begin
        case (opcode)

            7'b0110011: begin  // R-type instructions

                case (funct3)

                    3'b000: begin
                        if(funct7 == 7'b0000000) begin
                            legal = 1'b1;
                            alu_op = 4'b0000; //add
                        end
                        else if (funct7 == 7'b0100000) begin
                            legal = 1'b1;
                            alu_op = 4'b0001; //sub
                        end
                    end
                    3'b001: begin
                        if(funct7 == 7'b0000000) begin
                            legal = 1'b1;
                            alu_op = 4'b0101; //sll
                        end
                    end
                    3'b010: begin
                        if (funct7 == 7'b0000000) begin
                            legal = 1'b1;
                            alu_op = 4'b1000; //slt
                        end
                    end
                    3'b011: begin
                        if (funct7 == 7'b0000000) begin
                            legal = 1'b1;
                            alu_op = 4'b1001; //sltu
                        end
                    end
                    3'b100: begin
                        if (funct7 == 7'b0000000) begin
                            legal = 1'b1;
                            alu_op = 4'b0100; //xor
                        end
                    end
                    3'b101: begin
                        if (funct7 == 7'b0000000) begin
                            legal = 1'b1;
                            alu_op = 4'b0110; //srl     
                        end
                        else if (funct7 == 7'b0100000) begin
                            legal = 1'b1;
                            alu_op = 4'b0111; //sra
                        end
                    end
                    3'b110: begin
                        if (funct7 == 7'b0000000) begin
                            legal = 1'b1;
                            alu_op = 4'b0011; //or
                        end
                    end
                    3'b111: begin
                        if(funct7 == 7'b0000000) begin
                            legal = 1'b1;
                            alu_op = 4'b0010; //and
                        end
                    end
                endcase
                
                if(legal) begin
                    uses_rs1 = 1'b1;
                    uses_rs2 = 1'b1;
                    reg_write = (rd != 5'd0);
                    wb_sel = 2'b01; //EX_result
                end
            end

            7'b0010011: begin // I-type instructions
                case(funct3) 
                    3'b000: begin
                        legal = 1'b1;
                        alu_op = 4'b0000; // addi
                    end
                    3'b010: begin
                            legal = 1'b1;
                            alu_op = 4'b1000; //slti
                    end
                    3'b011: begin
                            legal = 1'b1;
                            alu_op = 4'b1001; //sltiu
                    end
                    3'b100: begin
                            legal = 1'b1;
                            alu_op = 4'b0100; //xori
                    end
                    3'b110: begin
                            legal = 1'b1;
                            alu_op = 4'b0011; //ori
                    end
                    3'b111: begin
                            legal = 1'b1;
                            alu_op = 4'b0010; //andi
                    end
                    3'b001: begin
                        if (funct7 == 7'b0000000) begin
                            legal = 1'b1;
                            alu_op = 4'b0101; //slli
                        end
                    end
                    3'b101: begin
                        if (funct7 == 7'b0000000) begin
                            legal = 1'b1;
                            alu_op = 4'b0110; //srli     
                        end
                        else if (funct7 == 7'b0100000) begin
                            legal = 1'b1;
                            alu_op = 4'b0111; //srai
                        end
                    end
                endcase
                if (legal) begin
                    uses_rs1 = 1'b1;
                    imm_kind = 3'b001; //I-type
                    op_b_sel = 2'b01; //ALU oprand B = immediate
                    reg_write = (rd!= 5'd0);
                    wb_sel = 2'b01; //EX_result
                end
            end

            7'b0110111: begin // LUI instruction
                legal = 1'b1;
                imm_kind = 3'b100; // imm genaration (u-type)
                op_a_sel = 2'b10; // ALU oprand A = 0
                op_b_sel = 2'b01; // ALU oprand B = immediate
                alu_op = 4'b1010; // pass B
                reg_write = (rd != 5'd0);
                wb_sel = 2'b01; // EX_result
            end

            7'b0010111: begin // AUIPC
                legal     = 1'b1;
                imm_kind  = 3'b100;  // U-type
                op_a_sel  = 2'b01;   // PC
                op_b_sel  = 2'b01;   // Immediate
                alu_op    = 4'b0000; // ADD
                reg_write = (rd != 5'd0);
                wb_sel    = 2'b01;   // EX_RESULT
            end

            7'b0000011: begin // LOAD

                case (funct3)
                    3'b000: begin // LB
                        legal = 1'b1;
                        mem_size = 2'b00;
                        load_unsigned = 1'b0;
                    end
                    3'b001: begin // LH
                        legal = 1'b1;
                        mem_size = 2'b01;
                        load_unsigned = 1'b0;
                    end
                    3'b010: begin // LW
                        legal = 1'b1;
                        mem_size = 2'b10;
                        load_unsigned = 1'b0;
                    end
                    3'b100: begin // LBU
                        legal = 1'b1;
                        mem_size = 2'b00;
                        load_unsigned = 1'b1;
                    end
                    3'b101: begin // LHU
                        legal = 1'b1;
                        mem_size = 2'b01;
                        load_unsigned = 1'b1;
                    end
                    default: begin

                    end
                endcase

                if (legal) begin
                    uses_rs1  = 1'b1;
                    imm_kind  = 3'b001;
                    op_a_sel  = 2'b00;
                    op_b_sel  = 2'b01;
                    alu_op    = 4'b0000;
                    mem_read  = 1'b1;
                    reg_write = (rd != 5'd0);
                    wb_sel    = 2'b10; // LOAD_DATA
                end

            end

            7'b0100011: begin // STORE
                case (funct3)
                    3'b000: begin // SB
                        legal    = 1'b1;
                        mem_size = 2'b00; // BYTE
                    end
                    3'b001: begin // SH
                        legal    = 1'b1;
                        mem_size = 2'b01; // HALF
                    end
                    3'b010: begin // SW
                        legal    = 1'b1;
                        mem_size = 2'b10; // WORD
                    end
                    default: begin
                        // Invalid store encoding
                    end
                endcase

                if (legal) begin
                    uses_rs1  = 1'b1;
                    uses_rs2  = 1'b1;
                    imm_kind  = 3'b010;  // S-type
                    op_a_sel  = 2'b00;   // rs1
                    op_b_sel  = 2'b01;   // immediate
                    alu_op    = 4'b0000; // ADD
                    mem_write = 1'b1;
                end
            end


            7'b1100011: begin // BRANCH

                case (funct3)
                    3'b000: begin // BEQ
                        legal = 1'b1;
                        br_kind = 3'b001;
                    end
                    3'b001: begin // BNE
                        legal = 1'b1;
                        br_kind = 3'b010;
                    end
                    3'b100: begin // BLT
                        legal = 1'b1;
                        br_kind = 3'b011;
                    end
                    3'b101: begin // BGE
                        legal = 1'b1;
                        br_kind = 3'b100;
                    end
                    3'b110: begin // BLTU
                        legal = 1'b1;
                        br_kind = 3'b101;
                    end
                    3'b111: begin // BGEU
                        legal = 1'b1;
                        br_kind = 3'b110;
                    end
                    default: begin
                        
                    end
                endcase

                if (legal) begin
                    uses_rs1 = 1'b1;
                    uses_rs2 = 1'b1;
                    imm_kind = 3'b011; // B-type immediate
                end
            end

            7'b1101111: begin // JAL
                legal     = 1'b1;
                imm_kind  = 3'b101;  // J-type immediate
                is_jal    = 1'b1;
                reg_write = (rd != 5'd0);
                wb_sel    = 2'b01;   // EX_RESULT (PC + 4 link)
            end

            7'b1100111: begin // JALR
                if (funct3 == 3'b000) begin
                    legal     = 1'b1;
                    uses_rs1  = 1'b1;
                    imm_kind  = 3'b001; // I-type immediate
                    is_jalr   = 1'b1;
                    reg_write = (rd != 5'd0);
                    wb_sel    = 2'b01;  // EX_RESULT (PC + 4 link)
                end
            end

            7'b0001111: begin // FENCE
                if (funct3 == 3'b000) begin
                    legal = 1'b1;
                end
            end

            7'b1110011: begin // SYSTEM
                if (instr == 32'h00000073) begin
                    legal = 1'b1; // ECALL
                end
                else if (instr == 32'h00100073) begin
                    legal = 1'b1; // EBREAK
                end
            end


            default: begin

            end

        endcase

    end
end

endmodule
