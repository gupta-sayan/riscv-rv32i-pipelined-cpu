module forward_unit (
    // Current instruction in EX
    input  logic        idex_valid,
    input  logic [4:0]  idex_rs1,
    input  logic [4:0]  idex_rs2,
    input  logic        idex_uses_rs1,
    input  logic        idex_uses_rs2,
    input  logic        idex_is_store,

    // Newest producer: EX/MEM
    input  logic        exmem_valid,
    input  logic [4:0]  exmem_rd,
    input  logic        exmem_reg_write,
    input  logic        exmem_result_ready,

    // Older producer: MEM/WB
    input  logic        memwb_valid,
    input  logic [4:0]  memwb_rd,
    input  logic        memwb_reg_write,

    // Forwarding decisions
    output logic [1:0]  fwd_a_sel,
    output logic [1:0]  fwd_b_sel,
    output logic [1:0]  fwd_store_sel,

    // Design-error indication
    output logic        fwd_nonready_error
);

always_comb begin
    fwd_a_sel          = 2'b00;
    fwd_b_sel          = 2'b00;
    fwd_store_sel      = 2'b00;
    fwd_nonready_error = 1'b0;

    if (idex_valid && idex_uses_rs1 &&
        exmem_valid && exmem_reg_write &&
        (exmem_rd != 5'd0) &&
        (exmem_rd == idex_rs1)) begin

        if (exmem_result_ready)
            fwd_a_sel = 2'b01;
        else begin
            fwd_a_sel = 2'b11;
            fwd_nonready_error = 1'b1;
        end
    end

    else if (idex_valid && idex_uses_rs1 &&
             memwb_valid && memwb_reg_write &&
             (memwb_rd != 5'd0) &&
             (memwb_rd == idex_rs1)) begin

        fwd_a_sel = 2'b10;
    end


    if (idex_valid && idex_uses_rs2 &&
        exmem_valid && exmem_reg_write &&
        (exmem_rd != 5'd0) &&
        (exmem_rd == idex_rs2)) begin

        if (exmem_result_ready)
            fwd_b_sel = 2'b01;
        else begin
            fwd_b_sel = 2'b11;
            fwd_nonready_error = 1'b1;
        end
    end
    else if (idex_valid && idex_uses_rs2 &&
             memwb_valid && memwb_reg_write &&
             (memwb_rd != 5'd0) &&
             (memwb_rd == idex_rs2)) begin

        fwd_b_sel = 2'b10;
    end


    if (idex_valid && idex_is_store && idex_uses_rs2) begin
        fwd_store_sel = fwd_b_sel;
    end
end

endmodule
