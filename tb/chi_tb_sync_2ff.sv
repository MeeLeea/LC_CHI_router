//=============================================================================
// 文件: tb/chi_tb_sync_2ff.sv
// 功能: sync_2ff 模块级定向 TB —— 单 bit / 准静态总线 / 复位 / CDC 相位
// 说明: RTL 有真实实现（2 级触发器），可给出真实判定
// 用法: xelab --snapshot chi_tb_sync_2ff_behav work.chi_tb_sync_2ff work.glbl
// 自检: 所有变量在 module 级声明；不用 fork 内声明
//=============================================================================
`default_nettype none
`timescale 1ns/1ps

module chi_tb_sync_2ff;

  // 两个异步时钟域：src 500MHz，dst 333MHz（非整数比，制造相位漂移）
  logic clk_src;
  logic clk_dst;
  logic rst_n;

  logic       d_async_1b;
  logic       q_sync_1b;
  logic [7:0] d_async_bus;
  logic [7:0] q_sync_bus;

  int unsigned n_err;
  int          i;
  int          cyc;
  logic [7:0]  bus_val;

  // 源时钟 500 MHz
  initial begin
    clk_src = 1'b0;
    forever #1 clk_src = ~clk_src;
  end

  // 目标时钟 333 MHz（周期 3ns），初始相位偏移 0.7ns
  initial begin
    clk_dst = 1'b0;
    #0.7;
    forever #1.5 clk_dst = ~clk_dst;
  end

  initial begin
    rst_n = 1'b0;
    repeat (5) @(posedge clk_dst);
    rst_n = 1'b1;
  end

  sync_2ff #(.W(1), .BUS(1'b0)) u_sync_1b (
    .clk     (clk_dst),
    .rst_n   (rst_n),
    .d_async (d_async_1b),
    .q_sync  (q_sync_1b)
  );

  sync_2ff #(.W(8), .BUS(1'b1)) u_sync_bus (
    .clk     (clk_dst),
    .rst_n   (rst_n),
    .d_async (d_async_bus),
    .q_sync  (q_sync_bus)
  );

  task automatic check(input logic cond, input string msg);
    if (!cond) begin
      n_err = n_err + 1;
      $display("[TB][ERROR] %s  (t=%0t)", msg, $time);
    end
  endtask

  // 等待 q_sync_1b 达到期望值，返回消耗周期数
  task automatic wait_1b(input logic exp_val, output int used_cyc);
    used_cyc = 0;
    while ((q_sync_1b !== exp_val) && (used_cyc < 10)) begin
      @(posedge clk_dst);
      used_cyc = used_cyc + 1;
    end
  endtask

  // 等待 q_sync_bus 达到期望值
  task automatic wait_bus(input logic [7:0] exp_val, output int used_cyc);
    used_cyc = 0;
    while ((q_sync_bus !== exp_val) && (used_cyc < 10)) begin
      @(posedge clk_dst);
      used_cyc = used_cyc + 1;
    end
  endtask

  initial begin
    d_async_1b  = 1'b0;
    d_async_bus = 8'h00;
    n_err       = 0;

    // -----------------------------------------------------------------------
    // TC1: 复位期间 q_sync 必须为 0
    // -----------------------------------------------------------------------
    rst_n = 1'b0;
    d_async_1b  = 1'b1;
    d_async_bus = 8'hA5;
    repeat (3) @(posedge clk_dst);
    #0.1;
    check(q_sync_1b === 1'b0, "TC1 复位期间 q_sync_1b 非 0");
    check(q_sync_bus === 8'h00, "TC1 复位期间 q_sync_bus 非 0");
    $display("[TB] TC1 复位期间输出: 1b=%b bus=%h", q_sync_1b, q_sync_bus);
    @(negedge clk_dst);
    rst_n = 1'b1;

    // -----------------------------------------------------------------------
    // TC2: 单 bit 同步延迟应为 2~3 个 dst 周期
    // -----------------------------------------------------------------------
    @(negedge clk_dst);
    d_async_1b = 1'b1;
    wait_1b(1'b1, cyc);
    check(q_sync_1b === 1'b1, "TC2 单bit 0->1 未在 10 周期内到达");
    check((cyc >= 2) && (cyc <= 3),
          $sformatf("TC2 2FF 延迟应为 2~3 周期, 实际 %0d", cyc));
    $display("[TB] TC2 单bit 0->1 同步延迟 = %0d 个 dst 周期", cyc);

    @(negedge clk_dst);
    d_async_1b = 1'b0;
    wait_1b(1'b0, cyc);
    check(q_sync_1b === 1'b0, "TC2 单bit 1->0 未到达");
    $display("[TB] TC2 单bit 1->0 同步延迟 = %0d 个 dst 周期", cyc);

    // -----------------------------------------------------------------------
    // TC3: 准静态总线同步 —— 数据稳定后 2~3 周期内更新
    // -----------------------------------------------------------------------
    for (i = 0; i < 16; i++) begin
      bus_val = 8'(i * 17 + 3);
      @(negedge clk_dst);
      d_async_bus = bus_val;
      wait_bus(bus_val, cyc);
      check(q_sync_bus === bus_val,
            $sformatf("TC3 总线同步失败: 期望 %h 实际 %h", bus_val, q_sync_bus));
      check((cyc >= 2) && (cyc <= 3),
            $sformatf("TC3 总线 2FF 延迟应为 2~3 周期, 实际 %0d", cyc));
    end
    $display("[TB] TC3 准静态总线同步: 16 组值全部通过");

    // -----------------------------------------------------------------------
    // TC4: 输出不得出现 X
    // -----------------------------------------------------------------------
    for (i = 0; i < 50; i++) begin
      @(posedge clk_dst);
      #0.1;
      check(!$isunknown(q_sync_1b),  "TC4 q_sync_1b 出现 X");
      check(!$isunknown(q_sync_bus), "TC4 q_sync_bus 出现 X");
    end
    $display("[TB] TC4 输出无 X: 50 周期检查通过");

    // -----------------------------------------------------------------------
    // TC5: 复位错位 —— dst 域复位期间 src 域持续翻转，释放后输出稳定
    // -----------------------------------------------------------------------
    @(negedge clk_dst);
    rst_n = 1'b0;
    // 并行：src 域翻转 20 拍；同时 dst 域检查复位保持
    fork
      begin : blk_src_toggle
        for (int k = 0; k < 20; k++) begin
          @(negedge clk_src);
          d_async_1b  = ~d_async_1b;
          d_async_bus = d_async_bus + 8'h1;
        end
      end
      begin : blk_dst_check
        repeat (4) @(posedge clk_dst);
        #0.1;
        check(q_sync_1b === 1'b0,  "TC5 复位错位期间 q_sync_1b 非 0");
        check(q_sync_bus === 8'h00, "TC5 复位错位期间 q_sync_bus 非 0");
      end
    join
    @(negedge clk_dst);
    rst_n = 1'b1;
    repeat (5) @(posedge clk_dst);
    check(!$isunknown(q_sync_1b),  "TC5 复位释放后 q_sync_1b 为 X");
    check(!$isunknown(q_sync_bus), "TC5 复位释放后 q_sync_bus 为 X");
    $display("[TB] TC5 复位错位: 通过");

    // -----------------------------------------------------------------------
    // 汇总
    // -----------------------------------------------------------------------
    repeat (2) @(posedge clk_dst);
    $display("======================== chi_tb_sync_2ff =========================");
    if (n_err == 0) begin
      $display("  RESULT: PASS  (0 error)");
    end else begin
      $display("  RESULT: FAIL  (%0d error)", n_err);
      $display("SOME TESTS FAILED");
    end
    $display("==================================================================");
    $finish;
  end

  initial begin
    #200000;
    $display("[TB][ERROR] TIMEOUT");
    $display("SOME TESTS FAILED");
    $finish;
  end

endmodule

`default_nettype wire