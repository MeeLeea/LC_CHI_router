//=============================================================================
// 文件: rtl/ingress/port_ingress.sv
// 功能: 单端口 ingress 顶层（4 通道）
//=============================================================================
`default_nettype none

module port_ingress #(
  parameter int PORT_NUM = 8,
  parameter int PORT_ID  = 0
) (
  input  wire clk,
  input  wire rst_n,
  // 四通道链路输入（valid/ready 反压）
  input  wire [3:0]  link_valid,
  output wire [3:0]  link_ready,
  input  wire [511:0] link_req,
  input  wire [255:0] link_rsp,
  input  wire [511:0] link_dat,
  input  wire [255:0] link_snp,
  // 送 buffer
  output wire        buf_wr_en,
  output wire [$clog2(PORT_NUM)-1:0] buf_out_port,
  output wire        err_evt
);

  // 子模块：flit_decode / parity_check / route_lookup / pool_alloc
  // （例化待架构细化）

endmodule

`default_nettype wire
