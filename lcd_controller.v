module lcd_controller (
    input clk,
    input reset,
    
    input [7:0] data_in,
    input rs_in,
    input start,
    output reg done,
    
    output [7:0] LCD_DATA,
    output reg LCD_RS,
    output LCD_RW,
    output reg LCD_EN,
    output LCD_ON,
    output LCD_BLON
);

    assign LCD_RW   = 1'b0; 
    assign LCD_ON   = 1'b1; 
    assign LCD_BLON = 1'b1; 
    assign LCD_DATA = data_bus;

    reg [7:0] data_bus;
    reg [31:0] contador; // 32 bits para segurança
    
    localparam IDLE      = 0;
    localparam SETUP     = 1; 
    localparam PULSE_HI  = 2; 
    localparam PULSE_LO  = 3; 
    localparam WAIT_HOLD = 4; 

    reg [2:0] estado;

    // Delay de segurança entre comandos (5ms é muito seguro)
    localparam DELAY_SAFE = 32'd250_000; 
    
    // Largura do pulso Enable (2us)
    localparam PULSE_WIDTH = 32'd100;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            estado <= IDLE;
            LCD_EN <= 0;
            LCD_RS <= 0;
            done <= 0;
            data_bus <= 8'h00;
            contador <= 0;
        end 
        else begin
            case (estado)
                IDLE: begin
                    done <= 0;
                    LCD_EN <= 0;
                    if (start) begin
                        data_bus <= data_in;
                        LCD_RS   <= rs_in;
                        estado   <= SETUP;
                        contador <= 0;
                    end
                end

                SETUP: begin
                    LCD_EN <= 0;
                    if (contador < PULSE_WIDTH) begin
                        contador <= contador + 1'b1;
                    end else begin
                        estado <= PULSE_HI;
                        contador <= 0;
                    end
                end

                PULSE_HI: begin
                    LCD_EN <= 1;
                    if (contador < PULSE_WIDTH) begin
                        contador <= contador + 1'b1;
                    end else begin
                        estado <= PULSE_LO;
                        contador <= 0;
                    end
                end

                PULSE_LO: begin
                    LCD_EN <= 0;
                    estado <= WAIT_HOLD;
                    contador <= 0;
                end

                WAIT_HOLD: begin
                    if (contador < DELAY_SAFE) begin
                        contador <= contador + 1'b1;
                    end else begin
                        done <= 1;
                        estado <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule