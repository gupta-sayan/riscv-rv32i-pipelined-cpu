module ex_event_mux (
    input  logic        idex_valid,
    input  logic [31:0] idex_pc,

    input  logic        lsu_evt_valid, // fault candidate from lsu_ex
    input  logic [3:0]  lsu_evt_cause,

    input  logic        target_misaligned, // fault candidate from branch_unit

    output logic        ex_evt_valid,
    output logic [3:0]  ex_evt_cause,
    output logic [31:0] ex_evt_pc
);

always_comb begin
    ex_evt_valid = 1'b0;
    ex_evt_cause = 4'h0;
    ex_evt_pc    = 32'b0;

    if (idex_valid && lsu_evt_valid) begin // LSU fault selection
        ex_evt_valid = 1'b1;
        ex_evt_cause = lsu_evt_cause;
        ex_evt_pc    = idex_pc;
    end
    else if (idex_valid && target_misaligned) begin // Branch misalignment fault selection
        ex_evt_valid = 1'b1;
        ex_evt_cause = 4'h9;
        ex_evt_pc    = idex_pc;
    end
    // question of later on
    // LSU takes priority over branch misalignment faults
    // what if both occur.
end

endmodule
