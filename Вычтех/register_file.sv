`timescale 1ns / 1ps
module register_file(
  input  logic        clk_i,
  input  logic        write_enable_i,

  input  logic [ 4:0] write_addr_i,
  input  logic [ 4:0] read_addr1_i,
  input  logic [ 4:0] read_addr2_i,

  input  logic [31:0] write_data_i,
  output logic [31:0] read_data1_o,
  output logic [31:0] read_data2_o
);
// Регистровый файл с 32 регистрами (32x32 бита)
  logic [31:0] rf_mem [31:0];
  
  // Порт записи (синхронный)
  always_ff @(posedge clk_i) begin
    if (write_enable_i && (write_addr_i != 5'b0)) begin
      rf_mem[write_addr_i] <= write_data_i;
    end
  end
  
  
  // Порт чтения 1 (асинхронный)
  always_comb begin
    if (read_addr1_i == 5'b0) begin
      read_data1_o = 32'b0;  // Нулевой регистр всегда возвращает 0
    end else begin
      read_data1_o = rf_mem[read_addr1_i];
    end
  end
  
  // Порт чтения 2 (асинхронный)
  always_comb begin
    if (read_addr2_i == 5'b0) begin
      read_data2_o = 32'b0;  // Нулевой регистр всегда возвращает 0
    end else begin
      read_data2_o = rf_mem[read_addr2_i];
    end
  end

endmodule