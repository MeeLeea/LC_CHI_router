//=============================================================================
// 文件: rtl/buffer/voq_linklist.sv
// 功能: 512 队列（每输入 64）× 指针管理 —— head/tail/count 链表
// 风险: R-03 指针 SRAM 带宽瓶颈 -> 多 bank + 读指针预取
//=============================================================================
`default_nettype none

module voq_linklist #(
  parameter int QUEUE_NUM = 512,
  parameter int FLIT_ID_W = 11,     // 单 pool 内 flit 索引位宽
  parameter int CNT_W     = 12
) (
  input  wire               clk,
  input  wire               rst_n,
  // 入队
  input  wire               enq_vld,
  input  wire [QUEUE_NUM_W-1:0] enq_qid,
  input  wire [FLIT_ID_W-1:0]   enq_fid,
  // 出队
  input  wire               deq_vld,
  input  wire [QUEUE_NUM_W-1:0] deq_qid,
  output logic [FLIT_ID_W-1:0]  deq_fid,
  output logic              deq_vld_o,
  // 状态查询
  input  wire [QUEUE_NUM_W-1:0] qid_sel,
  output logic [CNT_W-1:0]      q_cnt
);

  localparam int QUEUE_NUM_W = $clog2(QUEUE_NUM);

  logic [FLIT_ID_W-1:0] head [QUEUE_NUM];
  logic [FLIT_ID_W-1:0] tail [QUEUE_NUM];
  logic [CNT_W-1:0]     cnt  [QUEUE_NUM];

  // TODO: 入队/出队指针更新、next 指针 SRAM 读写（待架构细化）

  assign deq_fid  = head[qid_sel];
  assign deq_vld_o = (cnt[deq_qid] != '0);
  assign q_cnt    = cnt[qid_sel];

endmodule

`default_nettype wire
