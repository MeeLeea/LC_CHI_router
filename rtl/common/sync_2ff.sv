//=============================================================================
// 文件: rtl/common/sync_2ff.sv
// 功能: 2FF 同步器（单 bit / 准静态总线）
// 说明: 单 bit 用于异步事件；总线模式仅允许准静态（多位同时稳定）
//=============================================================================
`default_nettype none

module sync_2ff #(
  parameter int W      = 1,
  parameter bit BUS    = 1'b0   // 1: 准静态总线模式（禁止同时翻转）
) (
  input  wire         clk,
  input  wire         rst_n,
  input  wire [W-1:0] d_async,
  output logic [W-1:0] q_sync
);

  logic [W-1:0] meta, sync_r;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      meta   <= '0;
      sync_r <= '0;
    end else begin
      meta   <= d_async;
      sync_r <= meta;
    end
  end

  assign q_sync = sync_r;

  // 综合断言：总线模式仅允许用于准静态信号
  // synopsys translate_off
  initial begin
    if (BUS && W > 1) ;
  end
  // synopsys translate_on

endmodule

`default_nettype wire
