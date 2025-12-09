module mini_cpu (
    input clock,
    input reset,        // KEY[0] (Ativo Baixo)
    input enviar,       // KEY[3] (Ativo Baixo)
    input [17:0] sw,    // Switches
    
    output [15:0] ledr, // Resultado
    output [7:0] ledg,  // Debug
    
    output [7:0] LCD_DATA,
    output LCD_RS, LCD_RW, LCD_EN, LCD_ON, LCD_BLON
);

    // Fios internos
    wire [2:0] opcode; 
    assign opcode = sw[17:15]; 

    wire [3:0] dest, src1, src2;
    wire [15:0] imm_ext_uc;
    wire alu_src_uc;        
    wire [2:0] alu_op_uc;   
    wire write_enable_uc;   
    wire resetMemory;       

    wire [15:0] dado_reg1, dado_reg2;
    wire [15:0] entrada_b_ula; 
    wire [15:0] resultado_ula; 
    
    reg fsm_write_enable;        
    reg [15:0] dado_para_gravar; 
    
    // Registradores do LCD
    reg [2:0]  lcd_opcode_reg;
    reg [3:0]  lcd_dest_reg;
    reg [15:0] lcd_value_reg;
    reg        lcd_update_signal;

    // 1. Unidade de Controle
    UC unidade_controle (
        .sw(sw),
        .ligar(1'b1), 
        .enviar(enviar),
        .dest(), .src1(src1), .src2(src2), 
        .imm_ext(imm_ext_uc),
        .alu_src(alu_src_uc),
        .alu_op(alu_op_uc),
        .write_enable(write_enable_uc),
        .clear(resetMemory)
    );
    assign dest = sw[14:11]; 

    // 2. Memória
    memory banco_registradores (
        .clock(clock),
        .reset(~reset || resetMemory),       
        .write_enable(fsm_write_enable), 
        .addr_dest(dest),     
        .addr_src1(src1),     
        .addr_src2(src2),     
        .data_in(dado_para_gravar), 
        .out_src1(dado_reg1), 
        .out_src2(dado_reg2)  
    );

    // 3. MUX e ULA
    assign entrada_b_ula = (alu_src_uc) ? imm_ext_uc : dado_reg2;

    alu ula (
        .A(dado_reg1),       
        .B(entrada_b_ula),   
        .op(alu_op_uc),      
        .result(resultado_ula)
    );
    
    // 5. LCD
    wire lcd_pronto;
    
    lcd_ini meu_lcd (
        .clk(clock),
        .reset(~reset), 
        .opcode_in(lcd_opcode_reg), 
        .reg_index_in(lcd_dest_reg),
        .reg_value_in(lcd_value_reg),
        .update_in(lcd_update_signal), 
        .LCD_DATA(LCD_DATA),
        .LCD_RS(LCD_RS), .LCD_RW(LCD_RW), .LCD_EN(LCD_EN),
        .LCD_ON(LCD_ON), .LCD_BLON(LCD_BLON),
        .inicializado(lcd_pronto)
    );

    // 6. FSM
    reg [2:0] estado;
    localparam IDLE     = 3'd0;
    localparam DECODE   = 3'd1;
    localparam EXECUTE  = 3'd2;
    localparam WRITE    = 3'd3;
    localparam WAIT_REL = 3'd4;

    assign ledg = {lcd_pronto, 4'b0, estado}; 
    assign ledr = dado_para_gravar; 

    always @(posedge clock) begin
        if (~reset) begin 
            estado <= IDLE;
            fsm_write_enable <= 0;
            dado_para_gravar <= 0;
            
            lcd_opcode_reg <= 3'b111;
            lcd_dest_reg <= 0;
            lcd_value_reg <= 0;
            lcd_update_signal <= 0;
        end else begin
            case (estado)
                IDLE: begin
                    fsm_write_enable <= 0;
                    lcd_update_signal <= 0; 
                    if (!enviar) estado <= DECODE; 
                end

                DECODE: begin
                    if (opcode == 3'b000) begin 
                        dado_para_gravar <= imm_ext_uc;
                        estado <= WRITE;
                    end else begin
                        estado <= EXECUTE; 
                    end
                end
                
                EXECUTE: begin
                    dado_para_gravar <= resultado_ula;
                    estado <= WRITE;
                end

                WRITE: begin
                    if (write_enable_uc) fsm_write_enable <= 1;
                    
                    // Latch dos dados
                    lcd_opcode_reg <= opcode;
                    lcd_dest_reg   <= dest;
                    lcd_value_reg  <= dado_para_gravar;
                    
                    // Liga o sinal
                    lcd_update_signal <= 1; 
                    
                    estado <= WAIT_REL;
                end

                WAIT_REL: begin
                    fsm_write_enable <= 0; 
                    
                    // --- CORREÇÃO DE TIMING AQUI ---
                    // O sinal 'lcd_update_signal' continua '1' (do estado anterior)
                    // enquanto o usuário estiver segurando o botão.
                    
                    if (enviar) begin // Botão solto (nível 1)
                        lcd_update_signal <= 0; // Desliga o sinal
                        estado <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule