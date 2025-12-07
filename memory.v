module memory (
    input clock,
    input reset,          // Para o botão de ligar/desligar ou instrução CLEAR
    input write_enable,   // Sinal de controle: '1' escreve, '0' apenas lê
    input [3:0] addr_dest, // Endereço de onde vai escrever (4 bits para 16 posições)
    input [3:0] addr_src1, // Endereço de leitura 1
    input [3:0] addr_src2, // Endereço de leitura 2
    input [15:0] data_in,  // Dado que vem da ULA ou Imediato para ser salvo
    output [15:0] out_src1, // Dado saindo do registrador 1
    output [15:0] out_src2  // Dado saindo do registrador 2
);

    reg [15:0] ram [0:15];
    integer i;

    // Leitura Assíncrona (Acontece a qualquer momento)
    assign out_src1 = ram[addr_src1];
    assign out_src2 = ram[addr_src2];

    // Escrita Síncrona (Só acontece na borda do clock)
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 16; i = i + 1) begin
                ram[i] <= 16'b0;
            end
        end
        else if (write_enable) begin
            ram[addr_dest] <= data_in;
        end
    end

endmodule