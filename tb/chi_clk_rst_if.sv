//=============================================================================
// 文件: tb/chi_clk_rst_if.sv
// 功能: 时钟/复位激励接口 —— 500MHz clk + 独立 100MHz pclk + 异步复位同步释放
// 说明: 覆盖 spec CLK-01/CLK-02、RST-01/02/03 与跨时钟域相位/复位错位场景
// 约束: 不重复实现 RTL clk_rst_gen；本文件仅产生外部激励波形
//=============================================================================
`ifndef CHI_CLK_RST_IF_SV
`define CHI_CLK_RST_IF_SV

`timescale 1ns/1ps

interface chi_clk_rst_if #(
  parameter int CLK_PERIOD_PS  = 2000,   // 500 MHz -> 2.000 ns
  parameter int PCLK_PERIOD_PS = 10000   // 100 MHz -> 10.000 ns
);

  logic clk;
  logic pclk;

  logic rst_async_n;   // 数据面异步复位（低有效，异步断言/同步释放）
  logic presetn;       // 配置面同步复位（低有效）

  // 复位释放后稳定期计数（RST-03: >= 10 clk cycle 不接受 flit）
  int unsigned rst_release_cycles;

  // ---------------------------------------------------------------------------
  // 500 MHz 数据面时钟
  // ---------------------------------------------------------------------------
  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD_PS / 2000.0) clk = ~clk;
  end

  // ---------------------------------------------------------------------------
  // 100 MHz 配置面时钟（独立、异步于 clk）
  // 初始相位偏移 3.7 ns，制造非整数比相位关系，暴露 CDC 采样边界
  // ---------------------------------------------------------------------------
  initial begin
    pclk = 1'b0;
    #3.7;
    forever #(PCLK_PERIOD_PS / 2000.0) pclk = ~pclk;
  end

  // ---------------------------------------------------------------------------
  // 复位驱动：异步断言、同步释放
  //   - rst_async_n 在 clk 域同步释放
  //   - presetn     在 pclk 域同步释放，且与 rst_async_n 释放时刻错开
  //     （覆盖 RST-02 每域独立同步器、复位错位场景）
  // ---------------------------------------------------------------------------
  task automatic do_reset(input int assert_cycles);
    rst_async_n = 1'b0;
    presetn     = 1'b0;
    repeat (assert_cycles) @(posedge clk);
    // 先释放数据面复位
    @(posedge clk);
    rst_async_n = 1'b1;
    // 配置面复位错开 3 个 pclk 释放，制造复位错位
    repeat (3) @(posedge pclk);
    presetn = 1'b1;
    // RST-03 稳定期
    rst_release_cycles = 10;
    repeat (rst_release_cycles) @(posedge clk);
  endtask

  // 复位期间保持断言（用于复位中注入 flit 的异常场景）
  task automatic assert_reset();
    rst_async_n = 1'b0;
    presetn     = 1'b0;
  endtask

  task automatic release_reset();
    @(posedge clk);
    rst_async_n = 1'b1;
    repeat (3) @(posedge pclk);
    presetn = 1'b1;
    repeat (10) @(posedge clk);
  endtask

  // 上电默认：复位保持
  initial begin
    rst_async_n = 1'b0;
    presetn     = 1'b0;
    rst_release_cycles = 0;
  end

endinterface

`endif