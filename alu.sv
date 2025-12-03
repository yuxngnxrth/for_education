`timescale 1ns / 1ps

import alu_opcodes_pkg::*;

module alu (
    input  logic  [31:0] a_i,      // Первый операнд
    input  logic  [31:0] b_i,      // Второй операнд  
    input  logic  [ 4:0] alu_op_i,  // Код операции ALU {cmp, mod, opcode}
    output logic  [31:0] result_o,// Результат операции
    output logic  flag_o          // Флаг сравнения
);
    logic [31:0] sum_result;
    logic carry_out;
    
    fulladder32 adder_inst (
        .a_i(a_i),
        .b_i(b_i),
        .carry_i(1'b0),
        .sum_o(sum_result),
        .carry_o(carry_out)
    );
    
    // Вычисление result_o
    always_comb begin
        case (alu_op_i)
            ALU_ADD:  result_o = sum_result;
            ALU_SUB:  result_o = a_i - b_i;
            ALU_SLL:  result_o = a_i << b_i[4:0];
            ALU_SLTS: result_o = {31'b0, ($signed(a_i) < $signed(b_i))};
            ALU_SLTU: result_o = {31'b0, (a_i < b_i)};
            ALU_XOR:  result_o = a_i ^ b_i;
            ALU_SRL:  result_o = a_i >> b_i[4:0];
            ALU_SRA:  result_o = $signed(a_i) >>> b_i[4:0];
            ALU_OR:   result_o = a_i | b_i;
            ALU_AND:  result_o = a_i & b_i;
            default:  result_o = 32'b0;
        endcase
    end

    // Вычисление flag_o
    always_comb begin
        case (alu_op_i)
            ALU_EQ:  flag_o = (a_i == b_i);
            ALU_NE:  flag_o = (a_i != b_i);
            ALU_LTS: flag_o = ($signed(a_i) < $signed(b_i));
            ALU_GES: flag_o = ($signed(a_i) >= $signed(b_i));
            ALU_LTU: flag_o = (a_i < b_i);
            ALU_GEU: flag_o = (a_i >= b_i);
            default: flag_o = 1'b0;
        endcase
    end

endmodule