//=============================================================================
// 文件: rtl/xbar/crossbar_a.sv
// 功能: 8×8×512b 选通（REQ+DAT 宽通道）
// 风险: R-04 布线拥塞 -> 预留时序预算，必要时分级
//=============================================================================
`default_nettype none

module crossbar_a #(
  parameter int PORT_NUM = 8,
  parameter int DW       = 512
) (
  input  wire clk,
  input  wire rst_n,
  input  wire [PORT_NUM-1:0]                 in_valid,
  input  wire [PORT_NUM-1:0][DW-1:0]         in_data,
  input  wire [PORT_NUM-1:0][$clog2(PORT_NUM)-1:0] sel,  // 目标输出
  output logic [PORT_NUM-1:0]                out_valid,
  output logic [PORT_NUM-1:0][DW-1:0]        out_data
);

  // 每输出做 PORT_NUM:1 选通（含寄存器切分，待时序评估）

endmodule

`default_nettype wire
