module wb_trace #(
    parameter bit TRACE_EN = 1'b1
) (
    input  logic clk,
    input  logic rst,
    input  logic halted,

    // MEM/WB stage
    input  logic        memwb_valid,
    input  logic [31:0] memwb_pc,
    input  logic [4:0]  memwb_rd,
    input  logic        memwb_reg_write,
    input  logic [31:0] memwb_wb_data,
    //trace
    input  logic [31:0] memwb_instr,
    input  logic        memwb_mem_read,
    input  logic        memwb_mem_write,
    input  logic [31:0] memwb_mem_addr,
    input  logic [31:0] memwb_mem_wdata,
    input  logic [3:0]  memwb_mem_wmask,
    input  logic [31:0] memwb_mem_rdata,

    output logic        wb_rd_we,
    output logic [4:0]  wb_rd,
    output logic [31:0] wb_data,

    output logic        retire_valid,
    output logic [31:0] retire_pc,
    output logic [31:0] retire_instr,
    output logic [4:0]  retire_rd,
    output logic        retire_rd_we,
    output logic [31:0] retire_rd_data,

    output logic        retire_mem_valid,
    output logic        retire_mem_write,
    output logic [31:0] retire_mem_addr,
    output logic [3:0]  retire_mem_wmask,
    output logic [31:0] retire_mem_wdata,
    output logic [31:0] retire_mem_rdata
);

always_comb begin
    wb_rd   = memwb_rd;
    wb_data = memwb_wb_data;

    wb_rd_we = memwb_valid && memwb_reg_write && (memwb_rd != 5'd0) && !rst && !halted;
end

generate
    if (TRACE_EN) begin : gen_retire_trace

        always_ff @(posedge clk) begin
            if (rst) begin
                retire_valid   <= 1'b0;
                retire_pc      <= 32'b0;
                retire_instr   <= 32'b0;
                retire_rd      <= 5'b0;
                retire_rd_we   <= 1'b0;
                retire_rd_data <= 32'b0;

                retire_mem_valid <= 1'b0;
                retire_mem_write <= 1'b0;
                retire_mem_addr  <= 32'b0;
                retire_mem_wmask <= 4'b0;
                retire_mem_wdata <= 32'b0;
                retire_mem_rdata <= 32'b0;
            end

            else begin
                retire_valid   <= memwb_valid && !halted;

                retire_pc      <= memwb_pc;
                retire_instr   <= memwb_instr;
                retire_rd      <= memwb_rd;

                retire_rd_we   <= wb_rd_we;
                retire_rd_data <= memwb_wb_data;

                retire_mem_valid <= memwb_valid && (memwb_mem_read || memwb_mem_write) && !halted;

                retire_mem_write <= memwb_mem_write;
                retire_mem_addr  <= memwb_mem_addr;
                retire_mem_wmask <= memwb_mem_wmask;
                retire_mem_wdata <= memwb_mem_wdata;
                retire_mem_rdata <= memwb_mem_rdata;
            end
        end

    end

    else begin : gen_no_retire_trace    // Static TRACE_EN=0 configuration:
        assign retire_valid     = 1'b0;
        assign retire_pc        = 32'b0;
        assign retire_instr     = 32'b0;
        assign retire_rd        = 5'b0;
        assign retire_rd_we     = 1'b0;
        assign retire_rd_data   = 32'b0;

        assign retire_mem_valid = 1'b0;
        assign retire_mem_write = 1'b0;
        assign retire_mem_addr  = 32'b0;
        assign retire_mem_wmask = 4'b0;
        assign retire_mem_wdata = 32'b0;
        assign retire_mem_rdata = 32'b0;
    end

endgenerate

endmodule
