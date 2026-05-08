`timescale 1ns / 1ps

module fulladder(
  input  logic a_i,
  input  logic b_i,
  input  logic carry_i,
  output logic sum_o,
  output logic carry_o
  );

//Назначаем провода
logic AxorB;
logic AxorBxorCarry;
logic AandB;
logic AandCarry;
logic AandBorAandCarry;
logic BandCarry;

//sum_o
assign AxorB = a_i ^ b_i;
assign AxorBxorCarry = AxorB ^ carry_i;
assign sum_o = AxorBxorCarry;

//carry_o
assign AandB = a_i & b_i;
assign AandCarry = a_i & carry_i;
assign BandCarry = b_i & carry_i;
assign AandBorAandCarry = AandB | AandCarry;
assign carry_o = AandBorAandCarry | BandCarry;

endmodule

module fulladder32(
    input  logic [31:0] a_i,
    input  logic [31:0] b_i,
    input  logic        carry_i,
    output logic [31:0] sum_o,
    output logic        carry_o
    );

    logic [32:0] carry;
    assign carry[0] = carry_i;    
    
fulladder adder_i [31:0]( 
    .carry_i(carry[31:0]),
    .carry_o(carry[32:1]),
    .a_i(a_i),
    .b_i(b_i),
    .sum_o(sum_o)
);
    assign carry_o = carry[32];
    
endmodule