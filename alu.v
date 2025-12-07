module alu (
    input [15:0] A,
    input [15:0] B,
    input [2:0] op,
    output reg [15:0] result
);

    // Operações baseadas no Opcode
    // 000: Passa B (LOAD)
    // 001: Soma (ADD/ADDI)
    // 011: Subtração (SUB/SUBI)
    // 101: Multiplicação (MUL)
    
    always @(*) begin
        case(op)
            3'b000: result = B;        // LOAD: Passa o imediato direto
            3'b001: result = A + B;    // ADD/ADDI
            3'b011: result = A - B;    // SUB/SUBI
            3'b101: result = A * B;    // MUL
            default: result = 16'd0;
        endcase
    end

endmodule