
module hazard_ctrl (
    // Current instruction in ID
    input  logic       ifid_valid,
    input  logic       id_evt_valid,
    input  logic       ifid_uses_rs1,
    input  logic       ifid_uses_rs2,
    input  logic [4:0] ifid_rs1,
    input  logic [4:0] ifid_rs2,

    // Older instruction in EX
    input  logic       idex_valid,
    input  logic       idex_mem_read,
    input  logic [4:0] idex_rd,

    // Hazard control outputs
    output logic       hold_if,
    output logic       bubble_ex
);


always_comb begin
    hold_if   = 1'b0;
    bubble_ex = 1'b0;

    if (ifid_valid && !id_evt_valid &&
        idex_valid && idex_mem_read &&
        (idex_rd != 5'd0)) begin

        if ((ifid_uses_rs1 && (ifid_rs1 == idex_rd)) ||
            (ifid_uses_rs2 && (ifid_rs2 == idex_rd))) begin

            hold_if   = 1'b1;
            bubble_ex = 1'b1;
        end
    end
end


endmodule
