module reg_file (
    input  logic        clk,
    input  logic        rst,
    input  logic [4:0]  rs1_addr,
    input  logic [4:0]  rs2_addr,
    output logic [31:0] rs1_data,
    output logic [31:0] rs2_data,
    input  logic        rd_we,
    input  logic [4:0]  rd_addr,
    input  logic [31:0] rd_data
);

logic [31:0] register[0:31];

// x0 is 0 else data is register data
// read port 1
assign rs1_data = (rs1_addr == 5'd0) ? 32'b0 : register[rs1_addr];
// read port 2
assign rs2_data = (rs2_addr == 5'd0) ? 32'b0 : register[rs2_addr];

always_ff @(posedge clk) begin
    if(!rst && rd_we && (rd_addr != 5'd0)) begin
        register[rd_addr] <= rd_data;
    end
end


endmodule
