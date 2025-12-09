module mini_cpu (
    input clock,
    input reset,        // KEY[0]
    input enviar,       // KEY[3]
    input [17:0] sw,    // Switches
    output [15:0] ledr, // Resultado (LEDR)
    output [7:0] ledg   // Debug Estado (LEDG)
);

    // --- Fios de Interconexão ---
    // Saídas da UC
    wire [2:0] opcode; // Opcode decodificado (não usado diretamente aqui, mas útil para debug)
    wire [3:0] dest, src1, src2;
    wire [15:0] imm_ext_uc; // Imediato já estendido vindo da UC
    wire alu_src_uc;        // Controle do MUX da ULA
    wire [2:0] alu_op_uc;   // Operação da ULA
    wire write_enable_uc;   // Sinal de "Intenção de Gravar" da UC

    // Saídas da Memória
    wire [15:0] dado_reg1;
    wire [15:0] dado_reg2;

    // Saídas da ULA e MUX
    wire [15:0] entrada_b_ula; // Saída do MUX -> Entrada B da ULA
    wire [15:0] resultado_ula; // Saída da ULA
    
    // Controle da FSM (Sequencial)
    reg fsm_write_enable;        // Sinal FINAL de gravação (Sincronizado)
    reg [15:0] dado_para_gravar; // Dado que será efetivamente gravado (Registrador temporário)

    // --- 1. Instância da Unidade de Controle (UC) ---
    UC unidade_controle (
        .sw(sw),
        .ligar(1'b1), // Fixo em 1 por enquanto
        .enviar(enviar),
        // Outputs
        // .opcode(opcode), // Se sua UC tiver essa saída, descomente
        .dest(dest),
        .src1(src1),
        .src2(src2),
        .imm_ext(imm_ext_uc), // Conecta o imediato estendido
        .alu_src(alu_src_uc),
        .alu_op(alu_op_uc),
        .write_enable(write_enable_uc)
    );

    // --- 2. Instância da Memória RAM ---
    memory banco_registradores (
        .clock(clock),
        .reset(~reset),       // Reset ativo alto na memória (KEY0 é ativo baixo na placa)
        .write_enable(fsm_write_enable), // Controlado pela FSM (só grava no estado WRITE)
        .addr_dest(dest),     // Endereço de escrita (vem da UC)
        .addr_src1(src1),     // Endereço de leitura A (vem da UC)
        .addr_src2(src2),     // Endereço de leitura B (vem da UC)
        .data_in(dado_para_gravar), // Dado a ser escrito (vem do Reg Temporário)
        .out_src1(dado_reg1), // Dado lido A -> Vai para ULA A
        .out_src2(dado_reg2)  // Dado lido B -> Vai para MUX
    );

    // --- 3. Multiplexador da Entrada B da ULA ---
    // Se alu_src da UC for 1, usa Imediato. Se 0, usa Registrador 2.
    assign entrada_b_ula = (alu_src_uc) ? imm_ext_uc : dado_reg2;

    // --- 4. Instância da ULA ---
    alu ula (
        .A(dado_reg1),       // Sempre Reg 1
        .B(entrada_b_ula),   // Reg 2 ou Imediato (decidido pelo MUX)
        .op(alu_op_uc),      // Operação (vem da UC)
        .result(resultado_ula)
    );

    // --- 5. Máquina de Estados (FSM) ---
    // A FSM controla o TEMPO (Quando gravar, quando esperar).
    reg [2:0] estado;
    localparam IDLE     = 3'd0;
    localparam DECODE   = 3'd1;
    localparam EXECUTE  = 3'd2;
    localparam WRITE    = 3'd3;
    localparam WAIT_REL = 3'd4;

    assign ledg = {5'b0, estado}; // Mostra estado nos 3 primeiros LEDs verdes
    assign ledr = dado_para_gravar; // Mostra o último dado manipulado nos LEDs vermelhos

    always @(posedge clock) begin
        if (~reset) begin // Reset ativo baixo
            estado <= IDLE;
            fsm_write_enable <= 0;
            dado_para_gravar <= 0;
        end else begin
            case (estado)
                IDLE: begin
                    fsm_write_enable <= 0;
                    if (!enviar) estado <= DECODE; // Se apertou KEY3 (ativo baixo)
                end

                DECODE: begin
                    // A UC já configurou os MUXes e a ULA combinacionalmente.
                    // Vamos para EXECUTE para dar um ciclo de tempo para a ULA estabilizar o resultado.
                    estado <= EXECUTE; 
                end
                
                EXECUTE: begin
                    // Captura o resultado da ULA (que já deve estar pronto)
                    dado_para_gravar <= resultado_ula;
                    estado <= WRITE;
                end

                WRITE: begin
                    // Só gera o pulso de escrita SE a instrução atual exige gravação (LOAD, ADD...)
                    // Se for uma instrução que não grava (ex: CMP, JMP), write_enable_uc seria 0.
                    if (write_enable_uc) begin
                        fsm_write_enable <= 1;
                    end
                    estado <= WAIT_REL;
                end

                WAIT_REL: begin
                    fsm_write_enable <= 0; // Desliga a escrita imediatamente
                    if (enviar) estado <= IDLE; // Espera soltar o botão (voltar pra 1)
                end
            endcase
        end
    end

endmodule