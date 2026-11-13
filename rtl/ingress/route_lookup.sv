//=============================================================================
// 文件: rtl/ingress/route_lookup.sv
// 功能: NodeID -> 输出端口 查表（CSR 可配）
// 说明: 表本体在 csr/route_table.sv，本模块仅为组合查表 + 默认端口/非法丢弃
//=============================================================================
`default_nettype none

module route_lookup #(
  parameter int NODEID_W = 16,
  parameter int PORT_NUM = 8
) (
  input  wire [NODEID_W-1:0]          tgt_id,
  input  wire [PORT_NUM*3-1:0]        tbl_flat,      // CSR 配置项（TBD 结构）
  input  wire [2:0]                   default_port,
  output logic [$clog2(PORT_NUM)-1:0] out_port,
  output logic                        hit,           // 0 => 非法 NodeID，丢弃
  output logic                        drop
);

  // TODO: 按 tbl_flat 做地址译码（依赖 CSR 最终格式）
  assign out_port = '0;
  assign hit      = 1'b0;
  assign drop     = ~hit;

endmodule

`default_nettype wire
