module lsu_ex (
    input  logic [31:0] eff_addr,
    input  logic [31:0] store_data,
    input  logic [1:0]  mem_size,
    input  logic        mem_read,
    input  logic        mem_write,
    input  logic        idex_valid,
    input  logic        run_active,
    input  logic        rst,

    output logic [31:0] dmem_addr,
    output logic        dmem_re,
    output logic        dmem_we,
    output logic [3:0]  dmem_wmask,
    output logic [31:0] dmem_wdata,

    output logic        lsu_evt_valid,
    output logic [3:0]  lsu_evt_cause
);

logic access_misaligned;
logic address_in_dmem;

always_comb begin
    access_misaligned = 1'b0;

    case (mem_size)
        2'b00: access_misaligned = 1'b0;                // Byte
        2'b01: access_misaligned = eff_addr[0];         // Halfword
        2'b10: access_misaligned = |eff_addr[1:0];      // Word
        default: access_misaligned = 1'b0;
    endcase
end

assign address_in_dmem = (eff_addr >= 32'h00010000) && (eff_addr <= 32'h00013FFF);

always_comb begin
    dmem_wmask = 4'b0000;

    case (mem_size)
        2'b00: dmem_wmask = 4'b0001 << eff_addr[1:0]; // SB
        2'b01: dmem_wmask = 4'b0011 << eff_addr[1:0]; // SH
        2'b10: dmem_wmask = 4'b1111;                  // SW
        default: dmem_wmask = 4'b0000;
    endcase
end

always_comb begin
    dmem_wdata = 32'b0;

    case (mem_size)
        2'b00: dmem_wdata = {24'b0, store_data[7:0]} << (8 * eff_addr[1:0]);  // SB
        2'b01: dmem_wdata = {16'b0, store_data[15:0]} << (8 * eff_addr[1:0]); // SH
        2'b10: dmem_wdata = store_data;                                         // SW
        default: dmem_wdata = 32'b0;
    endcase
end

always_comb begin
    lsu_evt_valid = 1'b0;
    lsu_evt_cause = 4'h0;

    if (run_active && !rst && idex_valid) begin

        if (mem_read) begin
            if (access_misaligned) begin
                lsu_evt_valid = 1'b1;
                lsu_evt_cause = 4'h5;
            end
            else if (!address_in_dmem) begin
                lsu_evt_valid = 1'b1;
                lsu_evt_cause = 4'h6;
            end
        end

        else if (mem_write) begin
            if (access_misaligned) begin
                lsu_evt_valid = 1'b1;
                lsu_evt_cause = 4'h7;
            end
            else if (!address_in_dmem) begin
                lsu_evt_valid = 1'b1;
                lsu_evt_cause = 4'h8;
            end
        end

    end
end

assign dmem_re = run_active && 
                !rst && 
                idex_valid &&
                mem_read && 
                !mem_write &&
                !access_misaligned && 
                address_in_dmem &&
                (mem_size != 2'b11);

assign dmem_we = run_active && 
                !rst && 
                idex_valid &&
                mem_write && 
                !mem_read &&
                !access_misaligned && 
                address_in_dmem &&
                (mem_size != 2'b11);

assign dmem_addr = eff_addr;

endmodule
