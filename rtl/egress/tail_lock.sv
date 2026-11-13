//=============================================================================
// 文件: rtl/egress/tail_lock.sv
// 功能: 尾锁 —— 同 packet 多 beat 锁定，保证同包 beat 连续出队
// 风险: R-02 组合逻辑过长 -> 状态机化
//=============================================================================
`default_nettype none

module tail_lock #(
  parameter int QUEUE_NUM = 512
) (
  input  wire clk,
  input  wire rst_n,
  input  wire beat_valid,
  input  wire beat_is_last,     // 本 beat 为 packet 末 beat
  input  wire [$clog2(QUEUE_NUM)-1:0] beat_qid,
  output logic locked,          // 1 => 只允许 beat_qid 出队
  output logic [$clog2(QUEUE_NUM)-1:0] locked_qid
);

  logic lock_r;
  logic [$clog2(QUEUE_NUM)-1:0] lock_qid_r;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      lock_r     <= 1'b0;
      lock_qid_r <= '0;
    end else if (beat_valid) begin
      if (beat_is_last) begin
        lock_r     <= 1'b0;
      end else begin
        lock_r     <= 1'b1;
        lock_qid_r <= beat_qid;
      end
    end
  end

  assign locked     = lock_r;
  assign locked_qid = lock_qid_r;

endmodule

`default_nettype wire
