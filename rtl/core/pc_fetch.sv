
module pc_fetch (
    input  logic        clk,
    input  logic        rst,
    input  logic        hold_if,
    input  logic        fetch_redirect_valid,
    input  logic [31:0] redirect_pc,
    input  logic        stop_fetch,

    output logic [31:0] imem_addr,
    output logic        imem_en,
    output logic        fetch_issue,
    output logic        fetch_token_fault
);

logic [31:0] fetch_pc;

logic imem_in_range;

assign imem_in_range = (fetch_pc[31:14] == 18'd0);

assign imem_addr = fetch_pc;

assign fetch_issue = !rst && !stop_fetch && !hold_if;

assign imem_en = fetch_issue && imem_in_range;

assign fetch_token_fault = fetch_issue && !imem_in_range;

always_ff @(posedge clk) begin
    if (rst) begin
        fetch_pc <= 32'h00000000;
    end
    else if (fetch_redirect_valid) begin
        fetch_pc <= redirect_pc;
    end
    else if (!stop_fetch && !hold_if) begin
        fetch_pc <= fetch_pc + 32'd4;
    end
end


endmodule
