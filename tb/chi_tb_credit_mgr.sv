//=============================================================================
// 文件: tb/chi_tb_credit_mgr.sv
// 功能: credit_mgr 模块级定向 TB —— 发送/回补/耗尽/下溢观察/并行通道
// 说明: RTL 有真实实现（generate + 优先级 if/else），可给出真实判定
// 用法: xelab --snapshot chi_tb_credit_mgr_behav work.chi_tb_credit_mgr work.glbl
// 自检: 所有变量在 module 级声明；层次引用 u_dut.cred 仅用于 TB 观测
//=============================================================================
`default_nettype none
`timescale 1ns/1ps

module chi_tb_credit_mgr;

  localparam int CH_NUM   = 4;
  localparam int CRD_W    = 8;
  localparam int INIT_CRD = 16;

  logic              clk;
  logic              rst_n;
  logic [CH_NUM-1:0] send_flit;
  logic [CH_NUM-1:0] crd_return;
  logic [CH_NUM-1:0] crd_avail;

  int unsigned      n_err;
  int               i;
  int               k;
  logic [CRD_W-1:0] before_val;
  logic [CRD_W-1:0] v_before;

  initial begin
    clk = 1'b0;
    forever #1 clk = ~clk;
  end

  initial begin
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
  end

  credit_mgr #(
    .CH_NUM   (CH_NUM),
    .CRD_W    (CRD_W),
    .INIT_CRD (INIT_CRD)
  ) u_dut (
    .clk        (clk),
    .rst_n      (rst_n),
    .send_flit  (send_flit),
    .crd_return (crd_return),
    .crd_avail  (crd_avail)
  );

  // 读内部 credit（层次引用，仅 TB 观测用）
  function automatic logic [CRD_W-1:0] get_cred(input int ch);
    return u_dut.cred[ch];
  endfunction

  task automatic check(input logic cond, input string msg);
    if (!cond) begin
      n_err = n_err + 1;
      $display("[TB][ERROR] %s  (t=%0t)", msg, $time);
    end
  endtask

  task automatic pulse(input logic [CH_NUM-1:0] snd, input logic [CH_NUM-1:0] rtn);
    @(negedge clk);
    send_flit  = snd;
    crd_return = rtn;
    @(posedge clk);
    #0.1;
    @(negedge clk);
    send_flit  = '0;
    crd_return = '0;
    @(posedge clk);
    #0.1;
  endtask

  initial begin
    send_flit  = '0;
    crd_return = '0;
    n_err      = 0;

    // -----------------------------------------------------------------------
    // TC1: 复位值 = INIT_CRD，crd_avail 全 1
    // -----------------------------------------------------------------------
    rst_n = 1'b0;
    repeat (2) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;
    @(posedge clk);
    #0.1;
    for (i = 0; i < CH_NUM; i++) begin
      check(get_cred(i) === CRD_W'(INIT_CRD),
            $sformatf("TC1 ch%0d 复位值应为 %0d, 实际 %0d", i, INIT_CRD, get_cred(i)));
      check(crd_avail[i] === 1'b1, $sformatf("TC1 ch%0d crd_avail 应为 1", i));
    end
    $display("[TB] TC1 复位值: cred[0]=%0d (期望 %0d)", get_cred(0), INIT_CRD);

    // -----------------------------------------------------------------------
    // TC2: 单纯 send -> 每拍减 1
    // -----------------------------------------------------------------------
    for (k = 0; k < 5; k++) begin
      pulse(CH_NUM'(1) << 0, '0);
    end
    check(get_cred(0) === CRD_W'(INIT_CRD - 5),
          $sformatf("TC2 发送 5 次后应为 %0d, 实际 %0d", INIT_CRD - 5, get_cred(0)));
    $display("[TB] TC2 发送 5 次: cred[0]=%0d", get_cred(0));

    // -----------------------------------------------------------------------
    // TC3: 单纯 crd_return -> 每拍加 1
    // -----------------------------------------------------------------------
    for (k = 0; k < 3; k++) begin
      pulse('0, CH_NUM'(1) << 0);
    end
    check(get_cred(0) === CRD_W'(INIT_CRD - 2),
          $sformatf("TC3 回补 3 次后应为 %0d, 实际 %0d", INIT_CRD - 2, get_cred(0)));
    $display("[TB] TC3 回补 3 次: cred[0]=%0d", get_cred(0));

    // -----------------------------------------------------------------------
    // TC4: 同时 send+return -> 保持
    // -----------------------------------------------------------------------
    before_val = get_cred(0);
    pulse(CH_NUM'(1) << 0, CH_NUM'(1) << 0);
    check(get_cred(0) === before_val,
          $sformatf("TC4 同时 send+return 应保持 %0d, 实际 %0d", before_val, get_cred(0)));
    $display("[TB] TC4 同时 send+return: 保持 %0d", before_val);

    // -----------------------------------------------------------------------
    // TC5: 耗尽至 0 -> crd_avail 变 0
    // -----------------------------------------------------------------------
    while (get_cred(0) != '0) begin
      pulse(CH_NUM'(1) << 0, '0);
    end
    check(crd_avail[0] === 1'b0, "TC5 credit=0 时 crd_avail 应为 0");
    $display("[TB] TC5 耗尽: cred[0]=%0d, avail=%b", get_cred(0), crd_avail[0]);

    // -----------------------------------------------------------------------
    // TC6: 耗尽后继续 send -> 观察是否下溢（RTL 无下限保护）
    // -----------------------------------------------------------------------
    v_before = get_cred(0);
    pulse(CH_NUM'(1) << 0, '0);
    $display("[TB] TC6 耗尽后继续 send: %0d -> %0d", v_before, get_cred(0));
    if (get_cred(0) === CRD_W'(v_before - 1)) begin
      $display("[TB][WARN] TC6 检测到 credit 下溢（RTL 无下限保护），应上报 ERR_CREDIT_UF");
    end

    // -----------------------------------------------------------------------
    // TC7: 4 通道并行独立记账
    // -----------------------------------------------------------------------
    @(negedge clk);
    rst_n = 1'b0;
    repeat (2) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);
    pulse(CH_NUM'('b0001), '0);
    pulse(CH_NUM'('b0010), '0);
    pulse(CH_NUM'('b0010), '0);
    pulse(CH_NUM'('b0100), '0);
    pulse(CH_NUM'('b0100), '0);
    pulse(CH_NUM'('b0100), '0);
    pulse('0, CH_NUM'('b1000));
    check(get_cred(0) === CRD_W'(INIT_CRD - 1), "TC7 ch0 应减 1");
    check(get_cred(1) === CRD_W'(INIT_CRD - 2), "TC7 ch1 应减 2");
    check(get_cred(2) === CRD_W'(INIT_CRD - 3), "TC7 ch2 应减 3");
    check(get_cred(3) === CRD_W'(INIT_CRD + 1), "TC7 ch3 应加 1");
    $display("[TB] TC7 并行独立记账: ch0=%0d ch1=%0d ch2=%0d ch3=%0d",
             get_cred(0), get_cred(1), get_cred(2), get_cred(3));

    // -----------------------------------------------------------------------
    // TC8: 异步复位立即恢复 INIT_CRD
    // -----------------------------------------------------------------------
    @(negedge clk);
    rst_n = 1'b0;
    #0.5;
    check(get_cred(0) === CRD_W'(INIT_CRD),
          $sformatf("TC8 异步复位应立即恢复 %0d, 实际 %0d", INIT_CRD, get_cred(0)));
    repeat (2) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);
    $display("[TB] TC8 异步复位: cred[0]=%0d", get_cred(0));

    // -----------------------------------------------------------------------
    // 汇总
    // -----------------------------------------------------------------------
    $display("======================== chi_tb_credit_mgr =======================");
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