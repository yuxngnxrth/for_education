`timescale 1ns / 1ps

module CYBERcobra (
    input  logic         clk_i,
    input  logic         rst_i,
    input  logic [15:0]  sw_i,
    output logic [31:0]  out_o
);

    // Основные провода
    logic [31:0] pc, pc_plus_4, pc_next;
    logic [31:0] instruction;
    logic [31:0] alu_result, reg_data1, reg_data2, write_back_data;
    logic alu_flag, reg_write_en;
    
    // Декодирование инструкции CYBERcobra
    logic J, B;
    logic [1:0] WS;
    logic [4:0] ALUop, RA1, RA2, WA;
    logic [7:0] offset;
    logic [22:0] const23;
    
    assign J = instruction[31];
    assign B = instruction[30];
    assign WS = instruction[29:28];
    assign ALUop = instruction[27:23];
    assign RA1 = instruction[22:18];
    assign RA2 = instruction[17:13];
    assign offset = instruction[12:5];
    assign WA = instruction[4:0];
    assign const23[22:0] = instruction[27:5];
    
    // Знакорасширенные константы
    logic [31:0] rf_const;        // 23?32 бита для регистров
    logic [31:0] branch_target;   // 8?32 бита ?4 для переходов
    
    assign rf_const = {{9{const23[22]}}, const23};
    assign branch_target = {{22{offset[7]}}, offset, 2'b00};
    
    // Счетчик команд
    always_ff @(posedge clk_i) begin
        if (rst_i) pc <= 32'b0;
        else pc <= pc_next;
    end
    
    // Память инструкций
    logic [31:0] imem [0:127];
    initial $readmemh("program.mem", imem);
    assign instruction = imem[pc[31:2]];
    
    // Сумматор PC+4
    fulladder32 pc_adder(.a_i(pc), .b_i(32'd4), .carry_i(1'b0), .sum_o(pc_plus_4));
    
    // АЛУ
    alu alu_inst(
        .a_i(reg_data1),
        .b_i(reg_data2), 
        .alu_op_i(ALUop),
        .result_o(alu_result),
        .flag_o(alu_flag)
    );
    
    // Регистровый файл
    register_file reg_file(
        .clk_i(clk_i),
        .write_enable_i(reg_write_en),
        .write_addr_i(WA),
        .read_addr1_i(RA1),
        .read_addr2_i(RA2),
        .write_data_i(write_back_data),
        .read_data1_o(reg_data1),
        .read_data2_o(reg_data2)
    );
    
    // Логика управления
    assign reg_write_en = !J && !B;  // Запрет записи при переходах
    
    // Мультиплексор источника записи
    always_comb begin
        case (WS)
            2'b00: write_back_data = rf_const;
            2'b01: write_back_data = alu_result;
            2'b10: write_back_data = {16'b0, sw_i};
            default: write_back_data = 32'b0;
        endcase
    end
    
    // Мультиплексор следующего PC
    assign pc_next = (J || (B && alu_flag)) ? (pc + branch_target) : pc_plus_4;
    
    // Выход
    assign out_o = reg_data1;

endmodule