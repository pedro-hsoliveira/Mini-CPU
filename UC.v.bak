module UC(
    input [17:0] sw,
    input ligar,
    input enviar,

    // Saídas de Dados (Decodificação direta)
    output [3:0] dest,
    output [3:0] src1,
    output [3:0] src2,
    output [15:0] imm_ext, // Imediato Estendido

    // Saídas de Controle
    output reg alu_src,      // 0=Reg, 1=Imm
    output reg [2:0] alu_op, // Operação da ULA
    output reg write_enable  // Habilita escrita na memória
);

    // Decodificação dos campos
    wire [2:0] opcode = sw[17:15];
    assign dest = sw[14:11];
    assign src1 = sw[7:4];
    assign src2 = sw[3:0];

    // Lógica do Imediato (Extensão de Sinal)
    wire       sinal = sw[6];
    wire [5:0] valor = sw[5:0];
    
    // Se sinal=1 (Negativo), preenche com 1s. Se 0, com 0s.
    assign imm_ext = (sinal) ? {10'b1111111111, valor} : {10'b0000000000, valor};

    // Lógica de Controle
    always @(*) begin
        // Valores Default
        write_enable = 0;
        alu_op = 3'b000;
        alu_src = 0;

        case (opcode)
            3'b000: begin // LOAD
                write_enable = 1;
                alu_src = 1;      // Usa Imediato
                alu_op = 3'b000;  // Passa B
            end
            
            3'b001: begin // ADD
                write_enable = 1;
                alu_src = 0;      // Usa Reg2
                alu_op = 3'b001;  // Soma
            end
            
            3'b010: begin // ADDI
                write_enable = 1;
                alu_src = 1;      // Usa Imediato
                alu_op = 3'b001;  // Soma
            end
            
            3'b011: begin // SUB
                write_enable = 1;
                alu_src = 0;      // Usa Reg2
                alu_op = 3'b011;  // Subtrai
            end
            
            3'b100: begin // SUBI
                write_enable = 1;
                alu_src = 1;      // Usa Imediato
                alu_op = 3'b011;  // Subtrai
            end
            
            3'b101: begin // MUL
                write_enable = 1;
                alu_src = 0;      // Usa Reg2
                alu_op = 3'b101;  // Multiplica
            end
            
            // CLEAR e DISPLAY podem ser implementados depois
        endcase
    end

endmodule