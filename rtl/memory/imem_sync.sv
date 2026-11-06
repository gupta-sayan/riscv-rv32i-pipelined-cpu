
module imem_sync (
    input  logic        clk,
    input  logic        imem_en,
    input  logic [31:0] imem_addr,

    output logic [31:0] imem_rdata
);

logic [31:0] mem [0:4095];

logic [11:0] word_index;

assign word_index = imem_addr[13:2];

always_ff @(posedge clk) begin
    if (imem_en) begin
        imem_rdata <= mem[word_index];
    end
end

endmodule
