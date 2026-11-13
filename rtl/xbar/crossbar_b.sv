//=============================================================================
// 文件: rtl/xbar/crossbar_b.sv
// 功能: 8×8×256b 选通（RSP+SNP 窄通道）
//=============================================================================
`default_nettype none

module crossbar_b #(
  parameter int PORT_NUM = 8,
  parameter int DW       = 256
) (
  input  wire clk,
  input  wire rst_n,
  input  wire [PORT_NUM-1:0]                 in_valid,
  input  wire [PORT_NUM-1:0][DW-1:0]         in_data,
  input  wire [PORT_NUM-1:0][$clog2(PORT_NUM)-1:0] sel,
  output logic [PORT_NUM-1:0]                out_valid,
  output logic [PORT_NUM-1:0][DW-1:0]        out_data
);

  // 每输出做 PORT_NUM:1 选通

endmodule

`default_nettype wire
