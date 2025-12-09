module lcd_ini (
    input clk,
    input reset,
    
    input [2:0] opcode_in,
    input [3:0] reg_index_in,
    input [15:0] reg_value_in,
    input update_in, 
    
    output [7:0] LCD_DATA,
    output LCD_RS, LCD_RW, LCD_EN, LCD_ON, LCD_BLON,
    output reg inicializado
);

    // --- SINAIS E REGISTRADORES ---
    reg [7:0] lcd_data_in;
    reg lcd_rs_in;
    reg lcd_start;
    wire lcd_done;

    // Instância do driver (NÃO ALTERAR SEU DRIVER)
    lcd_controller u_lcd_driver (
        .clk(clk), .reset(reset),
        .data_in(lcd_data_in), .rs_in(lcd_rs_in), .start(lcd_start), .done(lcd_done),
        .LCD_DATA(LCD_DATA), .LCD_RS(LCD_RS), .LCD_RW(LCD_RW), .LCD_EN(LCD_EN),
        .LCD_ON(LCD_ON), .LCD_BLON(LCD_BLON)
    );

    reg [4:0] state; 
    reg [31:0] delay_boot; 
    reg [7:0] mensagem [0:31]; 
    reg [5:0] char_index; // Índice de qual letra estamos escrevendo
    
    // --- DETECTOR DE BORDA (TRIGGER) ---
    // O mini_cpu manda um sinal longo. Nós pegamos apenas a subida.
    reg update_prev;
    wire update_posedge;
    assign update_posedge = update_in && !update_prev; 

    // Variáveis auxiliares
    integer i;

    // Comandos LCD HD44780
    localparam CMD_INIT_FUNC = 8'h38;
    localparam CMD_DISPLAY   = 8'h0C;
    localparam CMD_CLEAR     = 8'h01;
    localparam CMD_ENTRY     = 8'h06;
    localparam CMD_NEW_LINE  = 8'hC0;
    localparam CMD_HOME      = 8'h02;

    // --- FUNÇÃO PARA HEXADECIMAL (Rápida e Leve) ---
    function [7:0] to_hex(input [3:0] val);
        begin
            if (val < 10) to_hex = 8'h30 + val;       // 0-9
            else          to_hex = 8'h41 + (val - 10); // A-F
        end
    endfunction

    // --- MÁQUINA DE ESTADOS PRINCIPAL ---
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= 0;
            lcd_start <= 0;
            inicializado <= 0;
            delay_boot <= 0;
            char_index <= 0;
            update_prev <= 0;
            // Limpa buffer visual
            for(i=0; i<32; i=i+1) mensagem[i] <= " ";
        end else begin
            // Atualiza histórico do botão para detecção de borda
            update_prev <= update_in;

            case (state)
                // ==========================================
                // SEQUÊNCIA DE INICIALIZAÇÃO (BOOT)
                // ==========================================
                0: begin 
                    // Espera 20ms (1.000.000 ciclos @ 50MHz)
                    if (delay_boot < 32'd1_000_000) delay_boot <= delay_boot + 1'b1; 
                    else state <= 1; 
                end
                
                1: begin lcd_data_in <= CMD_INIT_FUNC; lcd_rs_in <= 0; lcd_start <= 1; state <= 2; end
                2: begin if (lcd_start) lcd_start <= 0; if (lcd_done) state <= 3; end
                
                3: begin lcd_data_in <= CMD_DISPLAY;   lcd_rs_in <= 0; lcd_start <= 1; state <= 4; end
                4: begin if (lcd_start) lcd_start <= 0; if (lcd_done) state <= 5; end
                
                5: begin lcd_data_in <= CMD_CLEAR;     lcd_rs_in <= 0; lcd_start <= 1; state <= 6; end
                6: begin if (lcd_start) lcd_start <= 0; if (lcd_done) state <= 7; end
                
                7: begin lcd_data_in <= CMD_ENTRY;     lcd_rs_in <= 0; lcd_start <= 1; state <= 8; end
                8: begin 
                    if (lcd_start) lcd_start <= 0; 
                    if (lcd_done) begin 
                        inicializado <= 1; 
                        state <= 11; // Vai para IDLE
                    end 
                end

                // ==========================================
                // IDLE - ESPERANDO O BOTÃO
                // ==========================================
                11: begin
                    // Se o mini_cpu mandou atualizar (borda de subida)
                    if (update_posedge) begin
                        state <= 12; 
                    end
                end

                // ==========================================
                // PREPARA A MENSAGEM (FORMATACAO)
                // ==========================================
                12: begin
                    // 1. Limpa tudo com espaços primeiro
                    for(i=0; i<32; i=i+1) mensagem[i] = " ";

                    // 2. Escreve OPCODE (Texto)
                    case(opcode_in)
                        3'b000: begin mensagem[0]="L"; mensagem[1]="O"; mensagem[2]="A"; mensagem[3]="D"; end
                        3'b001: begin mensagem[0]="A"; mensagem[1]="D"; mensagem[2]="D"; end
                        3'b010: begin mensagem[0]="A"; mensagem[1]="D"; mensagem[2]="D"; mensagem[3]="I"; end
                        3'b011: begin mensagem[0]="S"; mensagem[1]="U"; mensagem[2]="B"; end
                        3'b100: begin mensagem[0]="S"; mensagem[1]="U"; mensagem[2]="B"; mensagem[3]="I"; end
                        3'b101: begin mensagem[0]="M"; mensagem[1]="U"; mensagem[2]="L"; end
                        3'b110: begin mensagem[0]="C"; mensagem[1]="L"; mensagem[2]="R"; mensagem[3]="R"; end
                        default:begin mensagem[0]="?"; end
                    endcase

                    // 3. Escreve Registrador Alvo [Rx]
                    mensagem[10] = "[";
						  mensagem[11] = reg_index_in[3]? "1" : "0";
						  mensagem[12] = reg_index_in[2]? "1" : "0";
						  mensagem[13] = reg_index_in[1]? "1" : "0";
						  mensagem[14] = reg_index_in[0]? "1" : "0";
						  mensagem[15] = "]";

                    // 4. Escreve Valor na Linha 2 (Em HEXADECIMAL)
                    // Formato: "Val: xxxx"
                    if (opcode_in == 3'b110) begin 
                         // Se for Clear
                         mensagem[16]="O"; mensagem[17]="K"; 
                    end else begin
                         // Converte 16 bits para 4 caracteres Hex
                         mensagem[27] = to_hex(reg_value_in[15:12]);
                         mensagem[28] = to_hex(reg_value_in[11:8]);
                         mensagem[29] = to_hex(reg_value_in[7:4]);
                         mensagem[30] = to_hex(reg_value_in[3:0]);
                         mensagem[31] = "h"; // Sufixo Hex
                    end
                    
                    // Vai resetar cursor para inicio
                    state <= 13; 
                end

                // ==========================================
                // RESET DO CURSOR (HOME)
                // ==========================================
                13: begin lcd_data_in <= CMD_HOME; lcd_rs_in <= 0; lcd_start <= 1; state <= 14; end
                14: begin if (lcd_start) lcd_start <= 0; if (lcd_done) begin char_index <= 0; state <= 9; end end

                // ==========================================
                // LOOP DE ESCRITA DA MENSAGEM (CORRIGIDO)
                // ==========================================
                9: begin
                    if (char_index == 32) begin
                        state <= 11; // Terminou tudo, volta pro IDLE
                    end 
                    else if (char_index == 16) begin
                        // CHEGOU NA METADE: MANDA COMANDO DE PULAR LINHA
                        lcd_data_in <= CMD_NEW_LINE; 
                        lcd_rs_in   <= 0; // 0 = Comando
                        lcd_start   <= 1;
                        state       <= 15; // Estado especial para pular linha
                    end 
                    else begin
                        // DADO NORMAL
                        lcd_data_in <= mensagem[char_index];
                        lcd_rs_in   <= 1; // 1 = Dado
                        lcd_start   <= 1;
                        state       <= 10;
                    end
                end

                // Espera escrever o caractere
                10: begin 
                    if (lcd_start) lcd_start <= 0;
                    if (lcd_done) begin 
                        char_index <= char_index + 1'b1;
                        state <= 9; 
                    end
                end

                // Espera o comando de pular linha
                15: begin
                    if (lcd_start) lcd_start <= 0;
                    if (lcd_done) begin
                        // ATENÇÃO: Não incrementamos o char_index aqui.
                        // O char[16] é um dado que ainda precisa ser escrito.
                        // Mas precisamos impedir que ele entre no loop infinito do 'else if (char_index == 16)'
                        // Truque simples: vamos escrever o char 16 manualmente aqui e pular para 17.
                        
                        lcd_data_in <= mensagem[16];
                        lcd_rs_in   <= 1; // Dado
                        lcd_start   <= 1;
                        state       <= 16; // Vai para um estado dummy de espera
                    end
                end
                
                // Finaliza a escrita do primeiro caractere da segunda linha
                16: begin
                    if (lcd_start) lcd_start <= 0;
                    if (lcd_done) begin
                        char_index <= 17; // Pula para o próximo
                        state <= 9;
                    end
                end
                
            endcase
        end
    end

endmodule