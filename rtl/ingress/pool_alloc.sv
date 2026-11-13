//=============================================================================
// 文件: rtl/ingress/pool_alloc.sv
// 功能: free-list 分配、VOQ 入队、REQ 紧凑化打包
//=============================================================================
`default_nettype none

module pool_alloc #(
  parameter int PORT_NUM  = 8,
  parameter int POOL_NUM  = 8,
  parameter int QUEUE_NUM = 512,
  parameter int BANK_PER_POOL = 16
) (
  input  wire clk,
  input  wire rst_n,
  // 来自 ingress 的 beat
  input  wire        beat_valid,
  input  wire [$clog2(PORT_NUM)-1:0] out_port,
  input  wire        out_ready,
  // 缓冲写口
  output logic       buf_wr_en,
  output logic [$clog2(POOL_NUM)-1:0] buf_pool,
  output logic [$clog2(BANK_PER_POOL)-1:0] buf_bank,
  output logic [10:0] buf_addr,
  // 入队
  output logic       enq_vld,
  output logic [$clog2(QUEUE_NUM)-1:0] enq_qid
);

  // TODO: free-list 管理 + VOQ 入队打包逻辑（待架构细化）

endmodule

`default_nettype wire
