//=============================================================================
// 文件: rtl/ingress/parity_check.sv
// 功能: per-flit parity 校验与错误上报
//=============================================================================
`default_nettype none

module parity_check #(
  parameter int W = 512
) (
  input  wire          clk,
  input  wire          rst_n,
  input  wire          flit_valid,
  input  wire [W-1:0]  flit_data,
  input  wire          parity_rx,      // 收到的 parity 位
  output logic         err_pulse,      // 单周期错误脉冲
  output logic         pkt_drop       // 本 beat 应丢弃
);

  wire parity_calc = ^flit_data;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      err_pulse <= 1'b0;
      pkt_drop  <= 1'b0;
    end else begin
      err_pulse <= flit_valid & (parity_calc != parity_rx);
      pkt_drop  <= flit_valid & (parity_calc != parity_rx);
    end
  end

endmodule

`default_nettype wire
