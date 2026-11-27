// Timing-study wrapper: rv32i_core_top + real dmem_sync + timing_imem.
// Built for out-of-context synthesis, so port count does not matter; all core
// outputs are kept as ports so nothing is optimized away.
module timing_top #(
    parameter bit TRACE_EN = 1'b0
) (
    input  logic        clk,
    input  logic        rst,
    input  logic        ld_we,
    input  logic [11:0] ld_addr,
    input  logic [31:0] ld_data,

    output logic        halted,
    output logic [31:0] fault_pc,
    output logic [3:0]  fault_cause,
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
    logic [31:0] imem_addr, imem_rdata, dmem_addr, dmem_wdata, dmem_rdata;
    logic        imem_en, dmem_re, dmem_we;
    logic [3:0]  dmem_wmask;

    rv32i_core_top #(.TRACE_EN(TRACE_EN)) u_core (.*);

    timing_imem u_imem (
        .clk(clk), .imem_en(imem_en), .imem_addr(imem_addr), .imem_rdata(imem_rdata),
        .ld_we(ld_we), .ld_addr(ld_addr), .ld_data(ld_data)
    );

    dmem_sync u_dmem (
        .clk(clk), .dmem_addr(dmem_addr), .dmem_re(dmem_re), .dmem_we(dmem_we),
        .dmem_wmask(dmem_wmask), .dmem_wdata(dmem_wdata), .dmem_rdata(dmem_rdata)
    );
endmodule
