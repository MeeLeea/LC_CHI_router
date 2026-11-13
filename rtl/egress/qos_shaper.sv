//=============================================================================
// 文件: rtl/egress/qos_shaper.sv
// 功能: WRR + token bucket 整形
//=============================================================================
`default_nettype none

module qos_shaper #(
  parameter int QOS_CLASS = 4,
  parameter int TOK_W     = 12
) (
  input  wire clk,
  input  wire rst_n,
  input  wire [QOS_CLASS-1:0]         req,
  input  wire [QOS_CLASS-1:0][TOK_W-1:0] weight,    // WRR 权重（CSR）
  input  wire [QOS_CLASS-1:0][TOK_W-1:0] bucket_max, // 桶深阈值（CSR）
  output logic [QOS_CLASS-1:0]        grant
);

  // TODO: WRR 轮转 + token bucket 补充/消耗

endmodule

`default_nettype wire
