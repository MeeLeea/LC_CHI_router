//=============================================================================
// 文件: rtl/egress/order_guard.sv
// 功能: 三层保序检查（PoS 域 / packet 尾锁 / SN 序）
// 风险: R-02
//=============================================================================
`default_nettype none

module order_guard #(
  parameter int PORT_NUM = 8,
  parameter int NODEID_W = 16
) (
  input  wire clk,
  input  wire rst_n,
  input  wire                     req_valid,
  input  wire [NODEID_W-1:0]      tgt_id,
  input  wire [1:0]               order,
  input  wire [1:0]               domain,
  output logic                    allow,       // 本 flit 允许出队
  output logic                    violate      // 检出序违规（PMU/错误上报）
);

  // TODO: 三层检查实现
  assign allow   = 1'b1;
  assign violate = 1'b0;

endmodule

`default_nettype wire
