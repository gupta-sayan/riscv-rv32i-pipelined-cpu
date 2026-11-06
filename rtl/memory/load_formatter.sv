module load_formatter (
    input  logic [31:0] dmem_rdata,
    input  logic [1:0]  load_lane,
    input  logic [1:0]  mem_size,
    input  logic        load_unsigned,

    output logic [31:0] load_result
);

logic [7:0] selected_byte;
logic [15:0] selected_halfword;
always_comb begin
    case (load_lane)
        2'b00: selected_byte = dmem_rdata[7:0];
        2'b01: selected_byte = dmem_rdata[15:8];
        2'b10: selected_byte = dmem_rdata[23:16];
        2'b11: selected_byte = dmem_rdata[31:24];
        default: selected_byte = 8'b0;
    endcase
end

always_comb begin
    case (load_lane[1])
        1'b0: selected_halfword = dmem_rdata[15:0];
        1'b1: selected_halfword = dmem_rdata[31:16];
    endcase
end

always_comb begin
    load_result = 32'b0;

    case (mem_size)

        2'b00: begin // Byte
            if (load_unsigned) begin
                load_result = {24'b0, selected_byte};
            end
            else begin
                load_result = {{24{selected_byte[7]}}, selected_byte};
            end
        end

        2'b01: begin // Halfword
            if (load_unsigned) begin
                load_result = {16'b0, selected_halfword};
            end
            else begin
                load_result = {{16{selected_halfword[15]}}, selected_halfword};
            end
        end

        2'b10: begin // Word
            load_result = dmem_rdata;
        end

        default: begin
            load_result = 32'b0;
        end

    endcase
end

endmodule
