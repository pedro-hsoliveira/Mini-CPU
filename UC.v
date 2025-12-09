module UC(
    input [17:0] sw,
    input ligar,
    input enviar,

    output [3:0] dest,
    output [3:0] src1,
    output [3:0] src2,
    output [15:0] imm_ext,

    output reg alu_src,
    output reg [2:0] alu_op,
    output reg write_enable,
	 output reg clear
);

    // Decodificação dos campos
    wire [2:0] opcode = sw[17:15];
    
    assign dest = sw[14:11];
    assign src1 = sw[10:7];
    assign src2 = sw[6:3];

    // Lógica do Imediato
    wire       sinal = sw[6];
    wire [5:0] valor = sw[5:0];
    
    // --- A CORREÇÃO MÁGICA ESTÁ AQUI ---
    // Se sinal=1 (Negativo), fazemos "menos valor" (Matemática real).
    // Se sinal=0 (Positivo), apenas preenchemos com zeros.
    assign imm_ext = (sinal) ? -{10'b0, valor} : {10'b0, valor};
	 
    // Lógica de Controle
    always @(*) begin
        write_enable = 0;
        alu_op = 3'b000;
        alu_src = 0;
		  clear=0;
		  

        case (opcode)
            3'b000: begin // LOAD
                write_enable = 1;
                alu_src = 1;      
                alu_op = 3'b000;  
            end
            
            3'b001: begin // ADD
                write_enable = 1;
                alu_src = 0;
                alu_op = 3'b001;
            end
            
            3'b010: begin // ADDI
                write_enable = 1;
                alu_src = 1;
                alu_op = 3'b001;  // Soma (A + Imm)
            end
            
            3'b011: begin // SUB
                write_enable = 1;
                alu_src = 0;
                alu_op = 3'b011;
            end
            
            3'b100: begin // SUBI
                write_enable = 1;
                alu_src = 1;
                alu_op = 3'b011;
            end
            
            3'b101: begin // MUL
                write_enable = 1;
                alu_src = 0;
                alu_op = 3'b101;
            end
				
				3'b110: begin //CLEAR
					write_enable = 1;
               alu_src = 0;
               alu_op = 3'b110;
					clear = 1;
				end
					
				
        endcase
    end

endmodule