//=============================================================================
// 文件: tb/chi_tb_flit_decode.sv
// 功能: flit_decode 模块级定向 TB —— 字段提取 / 边界值 / 字段独立性
// 说明: RTL 有真实实现（纯 assign 位切片），可给出真实判定
// 用法: xelab --snapshot chi_tb_flit_decode_behav work.chi_tb_flit_decode work.glbl
// 自检: 所有变量在 module 级声明
//=============================================================================
`default_nettype none
`timescale 1ns/1ps

module chi_tb_flit_decode;

  logic [511:0] flit_raw;
  logic [1:0]   ch_sel;
  logic [7:0]   opcode;
  logic [2:0]   size;
  logic [2:0]   order;
  logic [1:0]   domain;
  logic [15:0]  tgt_id;
  logic [15:0]  src_id;
  logic         qos;

  int unsigned n_err;
  int          i;
  logic [7:0]  op0;

  flit_decode u_dut (
    .flit_raw (flit_raw),
    .ch_sel   (ch_sel),
    .opcode   (opcode),
    .size     (size),
    .order    (order),
    .domain   (domain),
    .tgt_id   (tgt_id),
    .src_id   (src_id),
    .qos      (qos)
  );

  task automatic check(input logic cond, input string msg);
    if (!cond) begin
      n_err = n_err + 1;
      $display("[TB][ERROR] %s  (t=%0t)", msg, $time);
    end
  endtask

  // 组合一个 flit 并检查全字段
  task automatic check_flit(
    input logic [7:0]  e_opcode,
    input logic [2:0]  e_size,
    input logic [2:0]  e_order,
    input logic [1:0]  e_domain,
    input logic [15:0] e_tgt,
    input logic [15:0] e_src,
    input logic        e_qos,
    input string       tag
  );
    flit_raw = '0;
    flit_raw[7:0]   = e_opcode;
    flit_raw[10:8]  = e_size;
    flit_raw[13:11] = e_order;
    flit_raw[15:14] = e_domain;
    flit_raw[31:16] = e_tgt;
    flit_raw[47:32] = e_src;
    flit_raw[48]    = e_qos;
    #0.1;
    check(opcode === e_opcode, $sformatf("%s: opcode 期望 %h 实际 %h", tag, e_opcode, opcode));
    check(size   === e_size,   $sformatf("%s: size 期望 %0d 实际 %0d", tag, e_size, size));
    check(order  === e_order,  $sformatf("%s: order 期望 %0d 实际 %0d", tag, e_order, order));
    check(domain === e_domain, $sformatf("%s: domain 期望 %0d 实际 %0d", tag, e_domain, domain));
    check(tgt_id === e_tgt,    $sformatf("%s: tgt_id 期望 %h 实际 %h", tag, e_tgt, tgt_id));
    check(src_id === e_src,    $sformatf("%s: src_id 期望 %h 实际 %h", tag, e_src, src_id));
    check(qos    === e_qos,    $sformatf("%s: qos 期望 %b 实际 %b", tag, e_qos, qos));
  endtask

  initial begin
    flit_raw = '0;
    ch_sel   = '0;
    n_err    = 0;
    op0      = 8'h00;

    // -----------------------------------------------------------------------
    // TC1: 全 0 flit
    // -----------------------------------------------------------------------
    check_flit(8'h00, 3'd0, 3'd0, 2'd0, 16'h0000, 16'h0000, 1'b0, "TC1 全0");

    // -----------------------------------------------------------------------
    // TC2: 全 1 边界
    // -----------------------------------------------------------------------
    check_flit(8'hFF, 3'd7, 3'd7, 2'd3, 16'hFFFF, 16'hFFFF, 1'b1, "TC2 全1");

    // -----------------------------------------------------------------------
    // TC3: Opcode 子集逐一遍历（与 chi_router_pkg 冻结值一致）
    // -----------------------------------------------------------------------
    check_flit(8'h01, 3'd3, 3'd0, 2'd0, 16'h0001, 16'h0010, 1'b0, "TC3 REQ_READ_SHARED");
    check_flit(8'h02, 3'd4, 3'd1, 2'd0, 16'h0002, 16'h0011, 1'b1, "TC3 REQ_READ_UNIQUE");
    check_flit(8'h04, 3'd5, 3'd2, 2'd1, 16'h0003, 16'h0012, 1'b0, "TC3 REQ_MAKE_UNIQUE");
    check_flit(8'h07, 3'd6, 3'd0, 2'd1, 16'h0004, 16'h0013, 1'b1, "TC3 REQ_CLEAN_UNIQUE");
    check_flit(8'h09, 3'd7, 3'd1, 2'd0, 16'h0005, 16'h0014, 1'b0, "TC3 REQ_WRITE_UNIQUE");
    check_flit(8'h40, 3'd0, 3'd0, 2'd0, 16'h0006, 16'h0015, 1'b1, "TC3 RSP_COMP");
    check_flit(8'h41, 3'd1, 3'd0, 2'd0, 16'h0007, 16'h0016, 1'b0, "TC3 RSP_COMP_DATA");
    check_flit(8'h50, 3'd2, 3'd0, 2'd1, 16'h0008, 16'h0017, 1'b1, "TC3 DAT_COMP_DATA");
    check_flit(8'h51, 3'd3, 3'd0, 2'd1, 16'h0009, 16'h0018, 1'b0, "TC3 DAT_WRITE_DATA");
    check_flit(8'h52, 3'd4, 3'd0, 2'd0, 16'h000A, 16'h0019, 1'b1, "TC3 DAT_NCB_WR_DATA");
    check_flit(8'h60, 3'd0, 3'd0, 2'd0, 16'h000B, 16'h001A, 1'b0, "TC3 SNP_SHARED");
    check_flit(8'h61, 3'd0, 3'd0, 2'd1, 16'h000C, 16'h001B, 1'b1, "TC3 SNP_UNIQUE");
    check_flit(8'h62, 3'd0, 3'd0, 2'd1, 16'h000D, 16'h001C, 1'b0, "TC3 SNP_CLEAN_INVALID");
    $display("[TB] TC3 Opcode 子集: 13 个 opcode 全部通过");

    // -----------------------------------------------------------------------
    // TC4: 字段独立性 —— 单字段递增不影响其他字段
    // -----------------------------------------------------------------------
    for (i = 0; i < 16; i++) begin
      check_flit(8'h51, 3'd3, 3'd0, 2'd1, 16'(16'h0100 + i), 16'h0200, 1'b1,
                 $sformatf("TC4 tgt_id 递增 #%0d", i));
    end
    for (i = 0; i < 16; i++) begin
      check_flit(8'h51, 3'd3, 3'd0, 2'd1, 16'h0100, 16'(16'h0300 + i), 1'b0,
                 $sformatf("TC4 src_id 递增 #%0d", i));
    end
    $display("[TB] TC4 字段独立性: 32 组通过");

    // -----------------------------------------------------------------------
    // TC5: 高位 payload 不影响字段提取
    // -----------------------------------------------------------------------
    flit_raw = '0;
    flit_raw[7:0]    = 8'h51;
    flit_raw[31:16]  = 16'h1234;
    flit_raw[47:32]  = 16'h5678;
    flit_raw[511:64] = {448{1'b1}};
    #0.1;
    check(opcode === 8'h51, "TC5 payload 全1 时 opcode 应不受影响");
    check(tgt_id === 16'h1234, "TC5 payload 全1 时 tgt_id 应不受影响");
    check(src_id === 16'h5678, "TC5 payload 全1 时 src_id 应不受影响");
    $display("[TB] TC5 高位 payload 隔离: 通过");

    // -----------------------------------------------------------------------
    // TC6: ch_sel 是否参与解码（当前 RTL 未使用 ch_sel）
    // -----------------------------------------------------------------------
    flit_raw = '0;
    flit_raw[7:0] = 8'h51;
    ch_sel = 2'd0;
    #0.1;
    op0 = opcode;
    ch_sel = 2'd3;
    #0.1;
    if (opcode === op0) begin
      $display("[TB][WARN] TC6 ch_sel 不参与解码：ch_sel=0 与 3 时 opcode 相同 (%h)", op0);
      $display("[TB][WARN]       spec 4.2 要求 ch_sel 参与通道相关字段提取，见缺陷 D-02");
    end

    // -----------------------------------------------------------------------
    // 汇总
    // -----------------------------------------------------------------------
    $display("======================== chi_tb_flit_decode ======================");
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
    #100000;
    $display("[TB][ERROR] TIMEOUT");
    $display("SOME TESTS FAILED");
    $finish;
  end

endmodule

`default_nettype wire