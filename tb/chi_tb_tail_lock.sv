//=============================================================================
// 文件: tb/chi_tb_tail_lock.sv
// 功能: tail_lock 模块级定向 TB —— 锁定/解锁/末 beat/复位/边界 qid
// 说明: RTL 有真实实现（状态寄存器），可给出真实判定；覆盖 ORD-02
// 用法: xelab --snapshot chi_tb_tail_lock_behav work.chi_tb_tail_lock work.glbl
// 自检: 所有变量在 module 级声明
//=============================================================================
`default_nettype none
`timescale 1ns/1ps

module chi_tb_tail_lock;

  localparam int QUEUE_NUM = 512;
  localparam int QW        = 9;   // $clog2(512)

  logic          clk;
  logic          rst_n;
  logic          beat_valid;
  logic          beat_is_last;
  logic [QW-1:0] beat_qid;
  logic          locked;
  logic [QW-1:0] locked_qid;

  int unsigned n_err;
  int          i;

  initial begin
    clk = 1'b0;
    forever #1 clk = ~clk;
  end

  initial begin
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
  end

  tail_lock #(.QUEUE_NUM(QUEUE_NUM)) u_dut (
    .clk          (clk),
    .rst_n        (rst_n),
    .beat_valid   (beat_valid),
    .beat_is_last (beat_is_last),
    .beat_qid     (beat_qid),
    .locked       (locked),
    .locked_qid   (locked_qid)
  );

  task automatic check(input logic cond, input string msg);
    if (!cond) begin
      n_err = n_err + 1;
      $display("[TB][ERROR] %s  (t=%0t)", msg, $time);
    end
  endtask

  task automatic drive_beat(
    input logic [QW-1:0] qid,
    input logic          is_last,
    input logic          vld
  );
    @(negedge clk);
    beat_qid     = qid;
    beat_is_last = is_last;
    beat_valid   = vld;
    @(posedge clk);
    #0.1;
  endtask

  initial begin
    beat_valid   = 1'b0;
    beat_is_last = 1'b0;
    beat_qid     = '0;
    n_err        = 0;

    // -----------------------------------------------------------------------
    // TC1: 复位后未锁定
    // -----------------------------------------------------------------------
    rst_n = 1'b0;
    repeat (2) @(posedge clk);
    #0.1;
    check(locked === 1'b0, "TC1 复位期间 locked 应为 0");
    check(locked_qid === '0, "TC1 复位期间 locked_qid 应为 0");
    @(negedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);
    #0.1;
    check(locked === 1'b0, "TC1 复位释放后 locked 应为 0");
    $display("[TB] TC1 复位: locked=%b locked_qid=%0d", locked, locked_qid);

    // -----------------------------------------------------------------------
    // TC2: 非末 beat -> 进入锁定，记录 qid
    // -----------------------------------------------------------------------
    drive_beat(QW'(9'd42), 1'b0, 1'b1);
    check(locked === 1'b1, "TC2 非末 beat 后应进入锁定");
    check(locked_qid === QW'(9'd42),
          $sformatf("TC2 locked_qid 应为 42, 实际 %0d", locked_qid));
    $display("[TB] TC2 非末beat: locked=%b locked_qid=%0d", locked, locked_qid);

    // -----------------------------------------------------------------------
    // TC3: 锁定期间同 qid 继续 beat -> 保持锁定
    // -----------------------------------------------------------------------
    for (i = 0; i < 3; i++) begin
      drive_beat(QW'(9'd42), 1'b0, 1'b1);
      check(locked === 1'b1, $sformatf("TC3 第 %0d 个同 qid beat 后应保持锁定", i));
      check(locked_qid === QW'(9'd42), "TC3 locked_qid 应保持 42");
    end
    $display("[TB] TC3 同 packet 连续 beat: 锁定保持");

    // -----------------------------------------------------------------------
    // TC4: 末 beat -> 解锁
    // -----------------------------------------------------------------------
    drive_beat(QW'(9'd42), 1'b1, 1'b1);
    check(locked === 1'b0, "TC4 末 beat 后应解锁");
    $display("[TB] TC4 末beat: locked=%b", locked);

    // -----------------------------------------------------------------------
    // TC5: 无 beat（valid=0）时锁定保持
    // -----------------------------------------------------------------------
    drive_beat(QW'(9'd100), 1'b0, 1'b1);
    check(locked === 1'b1, "TC5 前置: 应已锁定");
    for (i = 0; i < 5; i++) begin
      drive_beat(QW'(9'd100), 1'b0, 1'b0);
      check(locked === 1'b1, $sformatf("TC5 无 beat 第 %0d 拍后 locked 应保持 1", i));
      check(locked_qid === QW'(9'd100), "TC5 locked_qid 应保持 100");
    end
    $display("[TB] TC5 无 beat 保持锁定: 5 拍通过");

    // -----------------------------------------------------------------------
    // TC6: 换 qid 的非末 beat -> locked_qid 更新
    // -----------------------------------------------------------------------
    drive_beat(QW'(9'd200), 1'b0, 1'b1);
    check(locked === 1'b1, "TC6 换 qid 后应保持锁定");
    check(locked_qid === QW'(9'd200),
          $sformatf("TC6 locked_qid 应更新为 200, 实际 %0d", locked_qid));
    $display("[TB] TC6 换 qid: locked_qid=%0d", locked_qid);

    // -----------------------------------------------------------------------
    // TC7: 复位中锁定 -> 立即清零
    // -----------------------------------------------------------------------
    @(negedge clk);
    rst_n = 1'b0;
    #0.5;
    check(locked === 1'b0, "TC7 异步复位应立即清 locked");
    check(locked_qid === '0, "TC7 异步复位应立即清 locked_qid");
    repeat (2) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);
    $display("[TB] TC7 复位清零: locked=%b locked_qid=%0d", locked, locked_qid);

    // -----------------------------------------------------------------------
    // TC8: 边界 qid（0 与 511）
    // -----------------------------------------------------------------------
    drive_beat(QW'(9'd0), 1'b0, 1'b1);
    check(locked_qid === QW'(9'd0), "TC8 qid=0 边界");
    drive_beat(QW'(9'd0), 1'b1, 1'b1);
    check(locked === 1'b0, "TC8 qid=0 末beat 解锁");
    drive_beat(QW'(9'd511), 1'b0, 1'b1);
    check(locked_qid === QW'(9'd511),
          $sformatf("TC8 qid=511 边界, 实际 %0d", locked_qid));
    drive_beat(QW'(9'd511), 1'b1, 1'b1);
    check(locked === 1'b0, "TC8 qid=511 末beat 解锁");
    $display("[TB] TC8 边界 qid: 0 与 511 通过");

    // -----------------------------------------------------------------------
    // 汇总
    // -----------------------------------------------------------------------
    repeat (2) @(posedge clk);
    $display("======================== chi_tb_tail_lock ========================");
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