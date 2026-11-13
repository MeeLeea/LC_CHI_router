//=============================================================================
// 文件: rtl/buffer/buffer_subsys.sv
// 功能: 缓冲子系统顶层（8 Pool × 16 bank）
// 决策: D-03 Pool 划分策略 Open —— 见 doc/design_spec.md 4.1
//=============================================================================
`default_nettype none

module buffer_subsys #(
  parameter int PORT_NUM      = 8,
  parameter int POOL_NUM      = 8,
  parameter int BANK_PER_POOL = 16,
  parameter int WIDE_W        = 512,
  parameter int NARROW_W      = 256,
  parameter int QUEUE_NUM     = 512
) (
  input  wire clk,
  input  wire rst_n,
  // 上报给 scheduler 的队列状态
  output logic [PORT_NUM-1:0][PORT_NUM-1:0] voq_nonempty,  // [in][out]
  output logic [POOL_NUM-1:0]               pool_crd_avail,
  // 读请求 / 读数据
  input  wire [PORT_NUM-1:0] rd_req_valid,
  input  wire [PORT_NUM-1:0][$clog2(QUEUE_NUM)-1:0] rd_req_qid,
  output logic [PORT_NUM-1:0] rd_data_valid,
  output logic [PORT_NUM-1:0][WIDE_W-1:0] rd_data
);

  // 子模块例化（待架构细化）：
  // sram_wrapper  × (POOL_NUM * BANK_PER_POOL)
  // voq_linklist  × 1
  // pool_credit   × 1

endmodule

`default_nettype wire
