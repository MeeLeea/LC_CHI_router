//=============================================================================
// 文件: rtl/csr/err_regs.sv
// 功能: 错误状态 / 使能 / 中断聚合
//=============================================================================
`default_nettype none

module err_regs #(
  parameter int ERR_SRC_NUM = 8
) (
  input  wire clk,
  input  wire rst_n,
  input  wire [ERR_SRC_NUM-1:0] err_evt,     // 各来源错误脉冲
  input  wire [ERR_SRC_NUM-1:0] err_en_wdata,
  input  wire                   err_en_wr,
  input  wire                   err_status_clr,
  output logic [ERR_SRC_NUM-1:0] err_status,
  output logic                   irq
);

  logic [ERR_SRC_NUM-1:0] err_en;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)                     err_en     <= '0;
    else if (err_en_wr)             err_en     <= err_en_wdata;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)                     err_status <= '0;
    else if (err_status_clr)        err_status <= '0;
    else                            err_status <= err_status | (err_evt & err_en);
  end

  assign irq = |err_status;

endmodule

`default_nettype wire
