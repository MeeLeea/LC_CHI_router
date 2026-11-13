//=============================================================================
// 文件: rtl/sched/islip_arbiter.sv
// 功能: iSLIP 2-round 仲裁（宽通道 REQ+DAT）
// 风险: R-01 迭代收敛不足 -> ROUND_N 可参数化
//=============================================================================
`default_nettype none

module islip_arbiter #(
  parameter int N = 8,
  parameter int ROUND_N = 2
) (
  input  wire           clk,
  input  wire           rst_n,
  input  wire            req_valid,
  input  wire [N-1:0]    req,        // 每输出来源请求
  output logic [N-1:0]   grant,
  output logic           grant_valid
);

  // TODO: 2-round 迭代匹配 + grant 指针（round-robin 位置）更新
  assign grant       = '0;
  assign grant_valid = 1'b0;

endmodule

`default_nettype wire
