
module alu (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [3:0]  alu_op,
    output logic [31:0] result
);

always_comb begin
    case (alu_op)
    // Arethmetic operations
        4'b0000: result = a + b;
        4'b0001: result = a - b;
    // Logical operations
        4'b0010: result = a & b;
        4'b0011: result = a | b;
        4'b0100: result = a ^ b;
    // Shift operations
        4'b0101: result = a << b[4:0]; //sll
        4'b0110: result = a >> b[4:0]; //srl
        4'b0111: result = $signed(a) >>> b[4:0]; //sra
    // Comparison operations
        4'b1000: result = ($signed(a) < $signed(b) ? 32'd1 : 32'd0); //slt
        4'b1001: result = (a<b) ? 32'd1 : 32'd0; //sltu
        4'b1010: result = b; //lui
        default: result = 32'b0;
    endcase
end
endmodule
