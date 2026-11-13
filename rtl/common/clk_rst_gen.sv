//=============================================================================
// 文件: rtl/common/clk_rst_gen.sv
// 功能: 时钟门控 + 异步复位同步释放
// 决策: D-05 已定 —— 异步复位同步释放，单功能时钟域
//=============================================================================
`default_nettype none

module clk_rst_gen (
  input  wire clk,          // 功能时钟
  input  wire rst_async_n,  // 异步复位（低有效）
  input  wire cg_en,        // 时钟门控使能（子系统级）
  output wire rst_sync_n,   // 同步释放后的复位
  output wire gclk          // 门控后时钟
);

  // ---- 异步复位同步释放（2 级） ----
  logic [1:0] rst_sync;
  always_ff @(posedge clk or negedge rst_async_n) begin
    if (!rst_async_n) rst_sync <= 2'b00;
    else              rst_sync <= {rst_sync[0], 1'b1};
  end
  assign rst_sync_n = rst_sync[1];

  // ---- 时钟门控（ICG 单元可替换实现） ----
  logic en_latch;
  always_latch begin
    if (!clk) en_latch = cg_en;
  end
  `ifdef FPGA
    assign gclk = clk & en_latch;   // FPGA 原型：直接与门
  `else
    assign gclk = clk & en_latch;   // ASIC：替换为 ICG 宏
  `endif

endmodule

`default_nettype wire
