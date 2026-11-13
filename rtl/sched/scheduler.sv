//=============================================================================
// 文件: rtl/sched/scheduler.sv
// 功能: 调度子系统顶层（仲裁 + 读请求生成）
//=============================================================================
`default_nettype none

module scheduler #(
  parameter int PORT_NUM  = 8,
  parameter int QUEUE_NUM = 512
) (
  input  wire clk,
  input  wire rst_n,
  input  wire [PORT_NUM-1:0][PORT_NUM-1:0] voq_nonempty,
  output logic [PORT_NUM-1:0] rd_req_valid,
  output logic [PORT_NUM-1:0][$clog2(QUEUE_NUM)-1:0] rd_req_qid,
  output logic [PORT_NUM-1:0] xbar_sel_valid
);

  // 子模块：islip_arbiter(宽通道) + rr_arbiter(窄通道)（例化待细化）

endmodule

`default_nettype wire
