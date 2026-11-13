//=============================================================================
// 文件: tb/sram_model/sram_behavioral.sv
// 功能: 行为级 SRAM（1R1W），用于 RTL 仿真替代 sram_wrapper 内宏
//=============================================================================
`default_nettype none
`timescale 1ns/1ps

module sram_behavioral #(
  parameter int DW    = 512,
  parameter int AW    = 5,
  parameter int DEPTH = 1 << AW
) (
  input  wire          clk,
  input  wire          wr_en,
  input  wire [AW-1:0] wr_addr,
  input  wire [DW-1:0] wr_data,
  input  wire          rd_en,
  input  wire [AW-1:0] rd_addr,
  output logic [DW-1:0] rd_data
);

  logic [DW-1:0] mem [DEPTH];

  always_ff @(posedge clk) begin
    if (wr_en) mem[wr_addr] <= wr_data;
    if (rd_en) rd_data     <= mem[rd_addr];
  end

endmodule

`default_nettype wire
