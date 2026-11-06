
module dmem_sync (
    input  logic        clk,
    input  logic [31:0] dmem_addr,
    input  logic        dmem_re,
    input  logic        dmem_we,
    input  logic [3:0]  dmem_wmask,
    input  logic [31:0] dmem_wdata,

    output logic [31:0] dmem_rdata
);

logic [31:0] mem [0:4095];

logic [11:0] word_index;

assign word_index = dmem_addr[13:2];

always_ff @(posedge clk) begin
    if (dmem_re) begin
        dmem_rdata <= mem[word_index];
    end
end

always_ff @(posedge clk) begin
    if (dmem_we) begin
        if (dmem_wmask[0])
            mem[word_index][7:0] <= dmem_wdata[7:0];

        if (dmem_wmask[1])
            mem[word_index][15:8] <= dmem_wdata[15:8];

        if (dmem_wmask[2])
            mem[word_index][23:16] <= dmem_wdata[23:16];

        if (dmem_wmask[3])
            mem[word_index][31:24] <= dmem_wdata[31:24];
    end
end

endmodule
