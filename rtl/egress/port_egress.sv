//=============================================================================
// 文件: rtl/egress/port_egress.sv
// 功能: 单端口 egress 顶层
// 组成: credit_mgr / order_guard / tail_lock / qos_shaper
//=============================================================================
`default_nettype none

module port_egress #(
  parameter int PORT_NUM = 8,
  parameter int PORT_ID  = 0,
  parameter int DW       = 512
) (
  input  wire clk,
  input  wire rst_n,
  // 来自 xbar
  input  wire        in_valid,
  input  wire [DW-1:0] in_data,
  // 链路输出
  output wire        link_valid,
  output wire [DW-1:0] link_data,
  input  wire        link_ready,
  // credit 回补给上游
  input  wire [3:0]  crd_return,
  output wire [3:0]  crd_avail
);

  // 子模块例化待架构细化

endmodule

`default_nettype wire
