// Timing-study-only instruction memory: same registered-read / hold-when-disabled
// behavior as rtl/memory/imem_sync.sv, plus a loader write port so the array is a
// real RAM (the repo's imem_sync has no writer, so synthesis would constant-fold it).
module timing_imem (
    input  logic        clk,
    input  logic        imem_en,
    input  logic [31:0] imem_addr,
    output logic [31:0] imem_rdata,
    input  logic        ld_we,
    input  logic [11:0] ld_addr,
    input  logic [31:0] ld_data
);
    (* ram_style = "block" *) logic [31:0] mem [0:4095];

    always_ff @(posedge clk) begin
        if (ld_we)
            mem[ld_addr] <= ld_data;
        if (imem_en)
            imem_rdata <= mem[imem_addr[13:2]];
    end
endmodule
