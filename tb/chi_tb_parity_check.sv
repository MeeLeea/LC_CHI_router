//=============================================================================
// 文件: tb/chi_tb_parity_check.sv
// 功能: parity_check 模块级定向 TB —— 正确/错误 parity / valid=0 / 随机
// 说明: RTL 有真实实现（^flit_data 比对），可给出真实判定
// 用法: xelab --snapshot chi_tb_parity_check_behav work.chi_tb_parity_check work.glbl
// 自检: 所有变量在 module 级声明
//=============================================================================
`default_nettype none
`timescale 1ns/1ps

module chi_tb_parity_check;

  localparam int W = 512;

  logic          clk;
  logic          rst_n;
  logic          flit_valid;
  logic [W-1:0]  flit_data;
  logic          parity_rx;
  logic          err_pulse;
  logic          pkt_drop;

  int unsigned n_err;
  int          i;
  logic [W-1:0] rnd_data;
  logic         rnd_par;
  logic         rnd_inj;

  initial begin
    clk = 1'b0;
    forever #1 clk = ~clk;
  end

  initial begin
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
  end

  parity_check #(.W(W)) u_dut (
    .clk        (clk),
    .rst_n      (rst_n),
    .flit_valid (flit_valid),
    .flit_data  (flit_data),
    .parity_rx  (parity_rx),
    .err_pulse  (err_pulse),
    .pkt_drop   (pkt_drop)
  );

  task automatic check(input logic cond, input string msg);
    if (!cond) begin
      n_err = n_err + 1;
      $display("[TB][ERROR] %s  (t=%0t)", msg, $time);
    end
  endtask

  task automatic drive_beat(
    input logic [W-1:0] data,
    input logic         prx,
    input logic         vld,
    input logic         exp_err,
    input string        tag
  );
    @(negedge clk);
    flit_data  = data;
    parity_rx  = prx;
    flit_valid = vld;
    @(posedge clk);
    #0.1;
    check(err_pulse === exp_err,
          $sformatf("%s: err_pulse 期望 %b 实际 %b", tag, exp_err, err_pulse));
    check(pkt_drop === exp_err,
          $sformatf("%s: pkt_drop 期望 %b 实际 %b", tag, exp_err, pkt_drop));
    $display("[TB] %s: calc_par=%b rx=%b valid=%b -> err=%b drop=%b",
             tag, ^data, prx, vld, err_pulse, pkt_drop);
  endtask

  initial begin
    flit_valid = 1'b0;
    flit_data  = '0;
    parity_rx  = 1'b0;
    n_err      = 0;

    // -----------------------------------------------------------------------
    // TC1: 复位期间输出为 0
    // -----------------------------------------------------------------------
    rst_n = 1'b0;
    repeat (2) @(posedge clk);
    #0.1;
    check(err_pulse === 1'b0, "TC1 复位期间 err_pulse 非 0");
    check(pkt_drop === 1'b0, "TC1 复位期间 pkt_drop 非 0");
    @(negedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);

    // -----------------------------------------------------------------------
    // TC2: 正确 parity -> 无错误
    // -----------------------------------------------------------------------
    drive_beat(512'h0, 1'b0, 1'b1, 1'b0, "TC2 全0 parity=0");
    drive_beat(512'h1, 1'b1, 1'b1, 1'b0, "TC2 单bit parity=1");
    drive_beat(512'h3, 1'b0, 1'b1, 1'b0, "TC2 双bit parity=0");

    // -----------------------------------------------------------------------
    // TC3: 错误 parity -> err_pulse 与 pkt_drop 同时拉高
    // -----------------------------------------------------------------------
    drive_beat(512'h0, 1'b1, 1'b1, 1'b1, "TC3 全0 parity=1(错)");
    drive_beat(512'h1, 1'b0, 1'b1, 1'b1, "TC3 单bit parity=0(错)");
    drive_beat({64{8'hFF}}, 1'b1, 1'b1, 1'b1, "TC3 全1 parity=1(错)");

    // -----------------------------------------------------------------------
    // TC4: valid=0 -> 不报错
    // -----------------------------------------------------------------------
    drive_beat(512'h0, 1'b1, 1'b0, 1'b0, "TC4 valid=0 parity错");
    drive_beat(512'h1, 1'b0, 1'b0, 1'b0, "TC4 valid=0 parity错");

    // -----------------------------------------------------------------------
    // TC5: 随机 100 组，50% 注入错误
    // -----------------------------------------------------------------------
    for (i = 0; i < 100; i++) begin
      rnd_data = {$urandom, $urandom, $urandom, $urandom,
                  $urandom, $urandom, $urandom, $urandom,
                  $urandom, $urandom, $urandom, $urandom,
                  $urandom, $urandom, $urandom, $urandom};
      rnd_par = ^rnd_data;
      rnd_inj = $urandom & 1'b1;
      drive_beat(rnd_data, rnd_inj ? ~rnd_par : rnd_par, 1'b1, rnd_inj,
                 $sformatf("TC5 rand#%0d", i));
    end

    // -----------------------------------------------------------------------
    // 汇总
    // -----------------------------------------------------------------------
    @(negedge clk);
    flit_valid = 1'b0;
    repeat (2) @(posedge clk);
    $display("======================== chi_tb_parity_check ======================");
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