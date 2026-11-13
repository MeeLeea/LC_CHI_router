//=============================================================================
// 文件: rtl/ingress/flit_decode.sv
// 功能: Opcode / Size / Order / Domain / NodeID 字段提取
//=============================================================================
`default_nettype none

module flit_decode (
  input  wire [511:0]        flit_raw,
  input  wire [1:0]          ch_sel,     // 通道选择
  output wire [7:0]          opcode,
  output wire [2:0]          size,
  output wire [2:0]          order,
  output wire [1:0]          domain,
  output wire [15:0]         tgt_id,
  output wire [15:0]         src_id,
  output wire                qos
);

  // 字段位置待依 Arm IHI0050 对照表最终确认（风险 R-05）
  assign opcode  = flit_raw[7:0];
  assign size    = flit_raw[10:8];
  assign order   = flit_raw[13:11];
  assign domain  = flit_raw[15:14];
  assign tgt_id  = flit_raw[31:16];
  assign src_id  = flit_raw[47:32];
  assign qos     = flit_raw[48];

endmodule

`default_nettype wire
