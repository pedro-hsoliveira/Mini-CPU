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

    reg [7:0] lcd_data_in;
    reg lcd_rs_in;
    reg lcd_start;
    wire lcd_done;

    lcd_controller u_lcd_driver (
        .clk(clk), .reset(reset),
        .data_in(lcd_data_in), .rs_in(lcd_rs_in), .start(lcd_start), .done(lcd_done),
        .LCD_DATA(LCD_DATA), .LCD_RS(LCD_RS), .LCD_RW(LCD_RW), .LCD_EN(LCD_EN),
        .LCD_ON(LCD_ON), .LCD_BLON(LCD_BLON)
    );

    reg [4:0] state; 
    reg [31:0] delay_boot; 
    reg [7:0] mensagem [0:31]; 
    reg [5:0] char_index;
    
    integer i;
    reg [15:0] abs_value;
    reg [15:0] temp_val;
    reg [3:0] digito;

    localparam CMD_FUNCTION_SET = 8'h38;
    localparam CMD_DISPLAY_ON   = 8'h0C;
    localparam CMD_CLEAR        = 8'h01;
    localparam CMD_ENTRY_MODE   = 8'h06;
    localparam CMD_NEW_LINE     = 8'hC0;
    localparam CMD_HOME         = 8'h02;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= 0;
            lcd_start <= 0;
            inicializado <= 0;
            delay_boot <= 0;
            char_index <= 0;
            for(i=0; i<32; i=i+1) mensagem[i] <= " ";
        end else begin
            case (state)
                // --- INICIALIZAÇÃO (0 a 8 igual) ---
                0: begin if (delay_boot < 32'd2_000_000) delay_boot <= delay_boot + 1'b1; else state <= 1; end
                1: begin lcd_data_in <= CMD_FUNCTION_SET; lcd_rs_in <= 0; lcd_start <= 1; state <= 2; end
                2: begin if (lcd_start) lcd_start <= 0; if (lcd_done) state <= 3; end
                3: begin lcd_data_in <= CMD_DISPLAY_ON; lcd_rs_in <= 0; lcd_start <= 1; state <= 4; end
                4: begin if (lcd_start) lcd_start <= 0; if (lcd_done) state <= 5; end
                5: begin lcd_data_in <= CMD_CLEAR; lcd_rs_in <= 0; lcd_start <= 1; state <= 6; end
                6: begin if (lcd_start) lcd_start <= 0; if (lcd_done) state <= 7; end
                7: begin lcd_data_in <= CMD_ENTRY_MODE; lcd_rs_in <= 0; lcd_start <= 1; state <= 8; end
                8: begin 
                    if (lcd_start) lcd_start <= 0; 
                    if (lcd_done) begin 
                        state <= 12; // Vai atualizar primeira vez
                        inicializado <= 1; 
                    end 
                end

                // --- CALCULA MENSAGEM (ESTADO 12) ---
                12: begin
                    // 1. Opcode
                    case(opcode_in)
                        3'b000: begin mensagem[0]="L"; mensagem[1]="O"; mensagem[2]="A"; mensagem[3]="D"; end
                        3'b001: begin mensagem[0]="A"; mensagem[1]="D"; mensagem[2]="D"; mensagem[3]=" "; end
                        3'b010: begin mensagem[0]="A"; mensagem[1]="D"; mensagem[2]="D"; mensagem[3]="I"; end
                        3'b011: begin mensagem[0]="S"; mensagem[1]="U"; mensagem[2]="B"; mensagem[3]=" "; end
                        3'b100: begin mensagem[0]="S"; mensagem[1]="U"; mensagem[2]="B"; mensagem[3]="I"; end
                        3'b101: begin mensagem[0]="M"; mensagem[1]="U"; mensagem[2]="L"; mensagem[3]=" "; end
                        3'b110: begin mensagem[0]="C"; mensagem[1]="L"; mensagem[2]="R"; mensagem[3]=" "; end
                        default:begin mensagem[0]="-"; mensagem[1]="-"; mensagem[2]="-"; mensagem[3]="-"; end
                    endcase

                    mensagem[4]=" "; mensagem[5]=" "; 
                    
                    // 2. Índice
                    if (opcode_in == 3'b110) begin 
                         mensagem[6]=" "; mensagem[7]=" "; mensagem[8]=" "; 
                         mensagem[9]=" "; mensagem[10]=" "; mensagem[11]=" ";
                    end else begin
                         mensagem[6] = "[";
                         mensagem[7] = (reg_index_in[3]) ? "1" : "0";
                         mensagem[8] = (reg_index_in[2]) ? "1" : "0";
                         mensagem[9] = (reg_index_in[1]) ? "1" : "0";
                         mensagem[10] = (reg_index_in[0]) ? "1" : "0";
                         mensagem[11] = "]";
                    end
                    
                    mensagem[12]=" "; mensagem[13]=" "; mensagem[14]=" "; mensagem[15]=" ";

                    // 3. Valor
                    if (opcode_in == 3'b110) begin // CLEAR -> Mostra "OK"
                        for(i=16; i<32; i=i+1) mensagem[i] = " ";
                        mensagem[16]="O"; mensagem[17]="K";
                    end else begin
                        if (reg_value_in[15] == 1) begin
                            mensagem[25] = "-";
                            abs_value = -reg_value_in; 
                        end else begin
                            mensagem[25] = "+";
                            abs_value = reg_value_in;
                        end

                        temp_val = abs_value;
                        digito = temp_val % 10; mensagem[30] = "0" + digito; temp_val = temp_val / 10;
                        digito = temp_val % 10; mensagem[29] = "0" + digito; temp_val = temp_val / 10;
                        digito = temp_val % 10; mensagem[28] = "0" + digito; temp_val = temp_val / 10;
                        digito = temp_val % 10; mensagem[27] = "0" + digito; temp_val = temp_val / 10;
                        digito = temp_val % 10; mensagem[26] = "0" + digito;

                        for(i=16; i<25; i=i+1) mensagem[i] = " ";
                        mensagem[31] = " ";
                    end

                    state <= 13; 
                    char_index <= 0;
                end

                // --- RESET CURSOR (HOME) ---
                13: begin
                    lcd_data_in <= CMD_HOME; lcd_rs_in <= 0; lcd_start <= 1; state <= 14;
                end
                14: begin if (lcd_start) lcd_start <= 0; if (lcd_done) state <= 9; end

                // --- ESCRITA ---
                9: begin
                    if (char_index == 16) begin
                        lcd_data_in <= CMD_NEW_LINE; lcd_rs_in <= 0; lcd_start <= 1; state <= 10;
                    end else if (char_index < 32) begin
                        lcd_data_in <= mensagem[char_index]; lcd_rs_in <= 1; lcd_start <= 1; state <= 10;
                    end else begin
                        state <= 11; // Terminou
                    end
                end

                10: begin 
                    if (lcd_start) lcd_start <= 0;
                    if (lcd_done) begin 
                        if (char_index != 16 || lcd_rs_in == 1) char_index <= char_index + 1'b1;
                        state <= 9; 
                    end
                end

                // --- IDLE (MUDANÇA AQUI) ---
                11: begin
                    // Agora obedece o pulso da CPU!
                    if (update_in) begin
                        state <= 12; // Vai atualizar e sai daqui
                    end
                end
                
                // Adicionei um estado "wait for release" implícito ao voltar para o 12, 
                // pois ao terminar de escrever (que leva tempo), o update_in já deve ter baixado
                // (se o usuário soltou o botão).
            endcase
        end
    end

endmodule