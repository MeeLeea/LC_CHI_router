//=============================================================================
// 文件: rtl/csr/route_table.sv
// 功能: NodeID -> 端口 映射表（供 ingress/route_lookup 使用）
//=============================================================================
`default_nettype none

module route_table #(
  parameter int NODEID_W = 16,
  parameter int PORT_NUM = 8,
  parameter int ENTRIES  = 256,
  parameter int AW_W     = $clog2(ENTRIES)
) (
  input  wire clk,
  input  wire rst_n,
  input  wire                  cfg_wr,
  input  wire [AW_W-1:0]       cfg_addr,
  input  wire [15:0]           cfg_nodeid,
  input  wire [2:0]            cfg_port,
  input  wire [15:0]           lookup_nodeid,
  output logic [2:0]           lookup_port,
  output logic                 lookup_valid
);

  // TODO: CAM 或 hash 查表实现（待架构选择）

endmodule

`default_nettype wire
