//=============================================================================
// 文件: tb/chi_tb_rr_arbiter.sv
// 功能: rr_arbiter 模块级定向 TB —— 轮转公平性 / 单请求 / 全请求 / 复位
// 说明: 该模块 RTL 有真实实现（always_comb 轮转 + ptr 更新），可给出真实判定
// 用法: xelab --snapshot chi_tb_rr_arbiter_behav work.chi_tb_rr_arbiter work.glbl
// 自检: 所有变量在 module 级声明，不在 initial/always 内声明
//=============================================================================
`default_nettype none
`timescale 1ns/1ps

module chi_tb_rr_arbiter;

  localparam int N = 8;

  logic          clk;
  logic          rst_n;
  logic [N-1:0]  req;
  logic [N-1:0]  grant;

  int unsigned n_err;
  int          i;
  int          cyc;
  logic [N-1:0] seen_mask;
  logic [N-1:0] g_first;

  // 时钟
  initial begin
    clk = 1'b0;
    forever #1 clk = ~clk;
  end

  // 复位
  initial begin
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
  end

  rr_arbiter #(.N(N)) u_dut (
    .clk   (clk),
    .rst_n (rst_n),
    .req   (req),
    .grant (grant)
  );

  task automatic check(input logic cond, input string msg);
    if (!cond) begin
      n_err = n_err + 1;
      $display("[TB][ERROR] %s  (t=%0t)", msg, $time);
    end
  endtask

  function automatic logic is_onehot_or_zero(input logic [N-1:0] v);
    return ($countones(v) <= 1);
  endfunction

  initial begin
    req       = '0;
    n_err     = 0;
    seen_mask = '0;
    g_first   = '0;

    // 等待复位释放后再开始功能检查（RTL 契约: 复位期间 grant=0，不做功能判定）
    wait (rst_n === 1'b1);
    @(negedge clk);

    // -----------------------------------------------------------------------
    // TC1: 无请求 -> grant 应为 0
    // -----------------------------------------------------------------------
    @(negedge clk);
    req = '0;
    @(posedge clk);
    #0.1;
    check(grant == '0, "TC1 无请求时 grant 非 0");
    $display("[TB] TC1 无请求: grant=%b", grant);

    // -----------------------------------------------------------------------
    // TC2: 单请求 -> 精确授权该位
    // -----------------------------------------------------------------------
    for (i = 0; i < N; i++) begin
      @(negedge clk);
      req = (N'(1) << i);
      @(posedge clk);
      #0.1;
      check(grant == (N'(1) << i),
            $sformatf("TC2 单请求 idx=%0d 授权错误 grant=%b", i, grant));
    end
    $display("[TB] TC2 单请求逐位授权: 完成");

    // -----------------------------------------------------------------------
    // TC3: 全请求 -> one-hot 且轮转覆盖全部索引（公平性）
    // -----------------------------------------------------------------------
    @(negedge clk);
    req = '1;
    seen_mask = '0;
    for (i = 0; i < 2 * N; i++) begin
      @(posedge clk);
      #0.1;
      check(is_onehot_or_zero(grant),
            $sformatf("TC3 全请求时 grant 非 one-hot: %b", grant));
      check(grant != '0, "TC3 全请求时 grant 为 0（应有授权）");
      if (i == 0) g_first = grant;
      seen_mask = seen_mask | grant;
    end
    check(seen_mask == {N{1'b1}},
          $sformatf("TC3 轮转未覆盖全部索引: seen=%b", seen_mask));
    $display("[TB] TC3 全请求轮转: 覆盖掩码=%b", seen_mask);

    // -----------------------------------------------------------------------
    // TC4: 请求撤除后 grant 归零
    // -----------------------------------------------------------------------
    @(negedge clk);
    req = '0;
    @(posedge clk);
    #0.1;
    check(grant == '0, "TC4 请求撤除后 grant 未归零");
    $display("[TB] TC4 请求撤除: grant=%b", grant);

    // -----------------------------------------------------------------------
    // TC5: 复位行为 —— 复位期间 grant=0，释放后从 idx0 起授权
    // -----------------------------------------------------------------------
    @(negedge clk);
    rst_n = 1'b0;
    repeat (2) @(posedge clk);
    @(negedge clk);
    req = '1;
    @(posedge clk);
    #0.1;
    check(grant == '0, "TC5 复位期间 grant 非 0");
    @(negedge clk);
    rst_n = 1'b1;
    #0.1;
    // grant 为组合输出：复位释放当拍（周期内）即应给出 idx0 授权，勿跨时钟沿采样
    check(grant == N'(1),
          $sformatf("TC5 复位释放后应立即从 idx0 授权, 实际 grant=%b", grant));
    @(posedge clk);
    #0.1;
    // idx0 授权已在该拍消耗，下一拍应轮转到 idx1
    check(grant == (N'(1) << 1),
          $sformatf("TC5 释放后下一拍应轮转到 idx1, 实际 grant=%b", grant));
    $display("[TB] TC5 复位行为: 复位后 grant=%b", grant);

    // -----------------------------------------------------------------------
    // 汇总
    // -----------------------------------------------------------------------
    repeat (2) @(posedge clk);
    $display("======================== chi_tb_rr_arbiter ========================");
    if (n_err == 0) begin
      $display("  RESULT: PASS  (0 error)");
    end else begin
      $display("  RESULT: FAIL  (%0d error)", n_err);
      $display("SOME TESTS FAILED");
    end
    $display("==================================================================");
    $finish;
  end

  // 超时保护
  initial begin
    #100000;
    $display("[TB][ERROR] TIMEOUT");
    $display("SOME TESTS FAILED");
    $finish;
  end

endmodule

`default_nettype wire