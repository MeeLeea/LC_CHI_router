//=============================================================================
// 文件: tb/chi_tb_pool_credit.sv
// 功能: pool_credit 模块级定向 TB —— 分配/回补/耗尽/同时操作/并行/复位
// 说明: RTL 有真实实现（generate + unique case），可给出真实判定
// 用法: xelab --snapshot chi_tb_pool_credit_behav work.chi_tb_pool_credit work.glbl
// 自检: 所有变量在 module 级声明
//=============================================================================
`default_nettype none
`timescale 1ns/1ps

module chi_tb_pool_credit;

  localparam int POOL_NUM = 8;
  localparam int CRD_W    = 8;
  localparam int INIT_CRD = 16;

  logic                           clk;
  logic                           rst_n;
  logic [POOL_NUM-1:0]            alloc_en;
  logic [POOL_NUM-1:0]            free_en;
  logic [POOL_NUM-1:0]            crd_avail;
  logic [POOL_NUM-1:0][CRD_W-1:0] crd_cnt;

  int unsigned      n_err;
  int               i;
  int               k;
  logic [CRD_W-1:0] before_val;

  initial begin
    clk = 1'b0;
    forever #1 clk = ~clk;
  end

  initial begin
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
  end

  pool_credit #(
    .POOL_NUM (POOL_NUM),
    .CRD_W    (CRD_W),
    .INIT_CRD (INIT_CRD)
  ) u_dut (
    .clk       (clk),
    .rst_n     (rst_n),
    .alloc_en  (alloc_en),
    .free_en   (free_en),
    .crd_avail (crd_avail),
    .crd_cnt   (crd_cnt)
  );

  task automatic check(input logic cond, input string msg);
    if (!cond) begin
      n_err = n_err + 1;
      $display("[TB][ERROR] %s  (t=%0t)", msg, $time);
    end
  endtask

  // 单拍驱动（脉冲式）
  task automatic pulse(input logic [POOL_NUM-1:0] al, input logic [POOL_NUM-1:0] fr);
    @(negedge clk);
    alloc_en = al;
    free_en  = fr;
    @(posedge clk);
    #0.1;
    @(negedge clk);
    alloc_en = '0;
    free_en  = '0;
    @(posedge clk);
    #0.1;
  endtask

  initial begin
    alloc_en = '0;
    free_en  = '0;
    n_err    = 0;

    // -----------------------------------------------------------------------
    // TC1: 复位值 = INIT_CRD，crd_avail 全 1
    // -----------------------------------------------------------------------
    rst_n = 1'b0;
    repeat (2) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;
    @(posedge clk);
    #0.1;
    for (i = 0; i < POOL_NUM; i++) begin
      check(crd_cnt[i] === CRD_W'(INIT_CRD),
            $sformatf("TC1 pool%0d 复位值应为 %0d, 实际 %0d",
                      i, INIT_CRD, crd_cnt[i]));
      check(crd_avail[i] === 1'b1,
            $sformatf("TC1 pool%0d 复位后 crd_avail 应为 1", i));
    end
    $display("[TB] TC1 复位值: crd_cnt[0]=%0d (期望 %0d)", crd_cnt[0], INIT_CRD);

    // -----------------------------------------------------------------------
    // TC2: 连续分配 INIT_CRD-1 次 -> 计数为 1，avail 仍为 1
    // -----------------------------------------------------------------------
    for (k = 0; k < INIT_CRD - 1; k++) begin
      pulse(POOL_NUM'(1) << 0, '0);
    end
    check(crd_cnt[0] === CRD_W'(1),
          $sformatf("TC2 分配 %0d 次后应为 1, 实际 %0d", INIT_CRD - 1, crd_cnt[0]));
    check(crd_avail[0] === 1'b1, "TC2 credit=1 时 crd_avail 应为 1");
    $display("[TB] TC2 分配 %0d 次: crd_cnt[0]=%0d, avail=%b",
             INIT_CRD - 1, crd_cnt[0], crd_avail[0]);

    // -----------------------------------------------------------------------
    // TC3: 再分配 1 次 -> 计数到 0，avail 变 0
    // -----------------------------------------------------------------------
    pulse(POOL_NUM'(1) << 0, '0);
    check(crd_cnt[0] === '0, $sformatf("TC3 应为 0, 实际 %0d", crd_cnt[0]));
    check(crd_avail[0] === 1'b0, "TC3 credit=0 时 crd_avail 应为 0");
    $display("[TB] TC3 credit 耗尽: crd_cnt[0]=%0d, avail=%b", crd_cnt[0], crd_avail[0]);

    // -----------------------------------------------------------------------
    // TC4: 回补 1 次 -> 计数回到 1，avail 恢复
    // -----------------------------------------------------------------------
    pulse('0, POOL_NUM'(1) << 0);
    check(crd_cnt[0] === CRD_W'(1), $sformatf("TC4 回补后应为 1, 实际 %0d", crd_cnt[0]));
    check(crd_avail[0] === 1'b1, "TC4 回补后 crd_avail 应为 1");
    $display("[TB] TC4 回补: crd_cnt[0]=%0d, avail=%b", crd_cnt[0], crd_avail[0]);

    // -----------------------------------------------------------------------
    // TC5: 同时 alloc+free -> 计数保持（RTL unique case default 分支）
    // -----------------------------------------------------------------------
    before_val = crd_cnt[0];
    pulse(POOL_NUM'(1) << 0, POOL_NUM'(1) << 0);
    check(crd_cnt[0] === before_val,
          $sformatf("TC5 同时 alloc+free 应保持 %0d, 实际 %0d", before_val, crd_cnt[0]));
    $display("[TB] TC5 同时 alloc+free: 保持 %0d -> %0d", before_val, crd_cnt[0]);

    // -----------------------------------------------------------------------
    // TC6: 全 pool 并行分配 -> 各 pool 独立无串扰
    // -----------------------------------------------------------------------
    pulse({POOL_NUM{1'b1}}, '0);
    for (i = 0; i < POOL_NUM; i++) begin
      check(crd_cnt[i] === CRD_W'(1),
            $sformatf("TC6 pool%0d 并行分配后应为 1, 实际 %0d", i, crd_cnt[i]));
    end
    $display("[TB] TC6 全 pool 并行分配: 8 个 pool 计数一致 = %0d", crd_cnt[0]);

    // -----------------------------------------------------------------------
    // TC7: 异步复位立即恢复 INIT_CRD
    // -----------------------------------------------------------------------
    @(negedge clk);
    rst_n = 1'b0;
    #0.5;
    check(crd_cnt[0] === CRD_W'(INIT_CRD),
          $sformatf("TC7 异步复位应立即恢复 %0d, 实际 %0d", INIT_CRD, crd_cnt[0]));
    repeat (2) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);
    $display("[TB] TC7 异步复位恢复: crd_cnt[0]=%0d", crd_cnt[0]);

    // -----------------------------------------------------------------------
    // 汇总
    // -----------------------------------------------------------------------
    $display("======================== chi_tb_pool_credit ======================");
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