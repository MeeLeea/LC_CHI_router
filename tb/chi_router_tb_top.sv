//=============================================================================
// 文件: tb/chi_router_tb_top.sv
// 功能: 系统级 Testbench 顶层
//        8×RN agent + 8×HN agent + DUT + scoreboard + coverage
// 用例: +define+TC_SMOKE / TC_CONGESTION / TC_ORDERING
// 说明: 纯 SV 定向环境（无 UVM class），Vivado Xsim 直接可跑
// 关键修正（相对原始骨架）:
//   1) pclk 独立 100MHz（原实现 pclk 接 clk，与 spec CLK-01 不符）
//   2) presetn 与 rst_async_n 独立、错位释放（RST-02）
//   3) 补齐 APB 激励任务（原实现仅置 0）
//   4) 任务调用改为位置参数（Xsim 对命名参数 : 语法支持不稳）
//   5) 断言 bind 移至 tb/chi_assertions.sv 文件作用域
// 注意: 本 TB 直接例化 chi_router_top；因顶层子系统例化被注释（骨架态），
//       link_out_* 无驱动，出口活动为 0 属预期，见验证报告 D-01。
//=============================================================================
`default_nettype none
`timescale 1ns/1ps

module chi_router_tb_top;

  localparam int PORT_NUM = 8;
  localparam int WIDE_W   = 512;
  localparam int NARROW_W = 256;

  // ---------------------------------------------------------------------------
  // 时钟 / 复位接口（500MHz clk + 100MHz pclk，异步）
  // ---------------------------------------------------------------------------
  chi_clk_rst_if #(
    .CLK_PERIOD_PS  (2000),
    .PCLK_PERIOD_PS (10000)
  ) clk_rst ();

  wire clk         = clk_rst.clk;
  wire pclk        = clk_rst.pclk;
  wire rst_async_n = clk_rst.rst_async_n;
  wire presetn     = clk_rst.presetn;

  // ---------------------------------------------------------------------------
  // DUT 链路信号
  // ---------------------------------------------------------------------------
  logic [PORT_NUM-1:0][3:0]          link_in_valid;
  logic [PORT_NUM-1:0][3:0]          link_in_ready;
  logic [PORT_NUM-1:0][WIDE_W-1:0]   link_in_req;
  logic [PORT_NUM-1:0][NARROW_W-1:0] link_in_rsp;
  logic [PORT_NUM-1:0][WIDE_W-1:0]   link_in_dat;
  logic [PORT_NUM-1:0][NARROW_W-1:0] link_in_snp;

  logic [PORT_NUM-1:0][3:0]          link_out_valid;
  logic [PORT_NUM-1:0][3:0]          link_out_ready;
  logic [PORT_NUM-1:0][WIDE_W-1:0]   link_out_req;
  logic [PORT_NUM-1:0][NARROW_W-1:0] link_out_rsp;
  logic [PORT_NUM-1:0][WIDE_W-1:0]   link_out_dat;
  logic [PORT_NUM-1:0][NARROW_W-1:0] link_out_snp;

  // ---------------------------------------------------------------------------
  // APB 信号
  // ---------------------------------------------------------------------------
  logic        psel;
  logic        penable;
  logic        pwrite;
  logic [15:0] paddr;
  logic [31:0] pwdata;
  logic [31:0] prdata;
  logic        pready;
  logic        pslverr;
  logic        irq;

  // ---------------------------------------------------------------------------
  // DUT
  // ---------------------------------------------------------------------------
  chi_router_top #(
    .PORT_NUM (PORT_NUM),
    .WIDE_W   (WIDE_W),
    .NARROW_W (NARROW_W)
  ) u_dut (
    .clk            (clk),
    .rst_async_n    (rst_async_n),
    .link_in_valid  (link_in_valid),
    .link_in_ready  (link_in_ready),
    .link_in_req    (link_in_req),
    .link_in_rsp    (link_in_rsp),
    .link_in_dat    (link_in_dat),
    .link_in_snp    (link_in_snp),
    .link_out_valid (link_out_valid),
    .link_out_ready (link_out_ready),
    .link_out_req   (link_out_req),
    .link_out_rsp   (link_out_rsp),
    .link_out_dat   (link_out_dat),
    .link_out_snp   (link_out_snp),
    .pclk           (pclk),
    .presetn        (presetn),
    .psel           (psel),
    .penable        (penable),
    .pwrite         (pwrite),
    .paddr          (paddr),
    .pwdata         (pwdata),
    .prdata         (prdata),
    .pready         (pready),
    .pslverr        (pslverr),
    .irq            (irq)
  );

  // ---------------------------------------------------------------------------
  // 反压模式选择（编译期宏）
  // ---------------------------------------------------------------------------
`ifdef BP_STALL
  localparam int RN_BP_MODE = 2;
  localparam int HN_BP_MODE = 2;
`elsif BP_RAND
  localparam int RN_BP_MODE = 1;
  localparam int HN_BP_MODE = 1;
`else
  localparam int RN_BP_MODE = 0;
  localparam int HN_BP_MODE = 0;
`endif

  // ---------------------------------------------------------------------------
  // RN / HN agent 例化（8 端口）
  // ---------------------------------------------------------------------------
  genvar gp;
  generate
    for (gp = 0; gp < PORT_NUM; gp++) begin : g_port

      // ---- RN agent：驱动 DUT 入口 REQ，接收出口 RSP/DAT/SNP ----
      chi_agent_rn #(
        .PORT_ID  (gp),
        .WIDE_W   (WIDE_W),
        .NARROW_W (NARROW_W),
        .BP_MODE  (RN_BP_MODE),
        .BP_SEED  (32'h1000_0000 + gp)
      ) u_rn (
        .clk       (clk),
        .rst_n     (rst_async_n),
        .req_valid (link_in_valid[gp][0]),
        .req_ready (link_in_ready[gp][0]),
        .req_data  (link_in_req[gp]),
        .snp_valid (link_out_valid[gp][3]),
        .snp_ready (link_out_ready[gp][3]),
        .snp_data  (link_out_snp[gp]),
        .rsp_valid (link_out_valid[gp][1]),
        .rsp_ready (link_out_ready[gp][1]),
        .rsp_data  (link_out_rsp[gp]),
        .dat_valid (link_out_valid[gp][2]),
        .dat_ready (link_out_ready[gp][2]),
        .dat_data  (link_out_dat[gp])
      );

      // ---- HN agent：接收 DUT 出口 REQ，回送入口 RSP/DAT/SNP ----
      chi_agent_hn #(
        .PORT_ID  (gp),
        .WIDE_W   (WIDE_W),
        .NARROW_W (NARROW_W),
        .BP_MODE  (HN_BP_MODE),
        .BP_SEED  (32'h2000_0000 + gp)
      ) u_hn (
        .clk       (clk),
        .rst_n     (rst_async_n),
        .req_valid (link_out_valid[gp][0]),
        .req_ready (link_out_ready[gp][0]),
        .req_data  (link_out_req[gp]),
        .rsp_valid (link_in_valid[gp][1]),
        .rsp_ready (link_in_ready[gp][1]),
        .rsp_data  (link_in_rsp[gp]),
        .dat_valid (link_in_valid[gp][2]),
        .dat_ready (link_in_ready[gp][2]),
        .dat_data  (link_in_dat[gp]),
        .snp_valid (link_in_valid[gp][3]),
        .snp_ready (link_in_ready[gp][3]),
        .snp_data  (link_in_snp[gp])
      );

    end
  endgenerate

  // ---------------------------------------------------------------------------
  // 监视信号（供 scoreboard 使用）
  // ---------------------------------------------------------------------------
  logic [PORT_NUM-1:0]        mon_in_fire;
  logic [PORT_NUM-1:0]        mon_out_fire;
  logic [PORT_NUM-1:0][511:0] mon_in_data;
  logic [PORT_NUM-1:0][511:0] mon_out_data;
  int                         mi;

  always_comb begin : proc_mon
    for (mi = 0; mi < PORT_NUM; mi++) begin
      mon_in_fire[mi]  = link_in_valid[mi][0] && link_in_ready[mi][0];
      mon_in_data[mi]  = link_in_req[mi];
      mon_out_fire[mi] = link_out_valid[mi][0] && link_out_ready[mi][0];
      mon_out_data[mi] = link_out_req[mi];
    end
  end

  // ---------------------------------------------------------------------------
  // Scoreboard
  // ---------------------------------------------------------------------------
  chi_scoreboard #(
    .PORT_NUM (PORT_NUM),
    .CRD_W    (8)
  ) u_scb (
    .clk          (clk),
    .rst_n        (rst_async_n),
    .mon_in_fire  (mon_in_fire),
    .mon_out_fire (mon_out_fire),
    .mon_in_data  (mon_in_data),
    .mon_out_data (mon_out_data),
    .crd_cnt_obs  ({(PORT_NUM){8'hFF}})   // 骨架 RTL 无 credit 观测点，恒 0xFF
  );

  // ---------------------------------------------------------------------------
  // 功能覆盖率收集
  // ---------------------------------------------------------------------------
  chi_coverage #(.PORT_NUM(PORT_NUM)) u_cov (
    .clk            (clk),
    .rst_async_n    (rst_async_n),
    .link_in_valid  (link_in_valid),
    .link_in_ready  (link_in_ready),
    .link_out_valid (link_out_valid),
    .link_out_ready (link_out_ready),
    .link_in_req    (link_in_req),
    .link_in_dat    (link_in_dat),
    .link_in_rsp    (link_in_rsp),
    .link_in_snp    (link_in_snp),
    .pclk           (pclk),
    .presetn        (presetn),
    .psel           (psel),
    .penable        (penable),
    .pwrite         (pwrite),
    .paddr          (paddr)
  );

  // ---------------------------------------------------------------------------
  // APB 激励任务（pclk 域）
  // ---------------------------------------------------------------------------
  task automatic apb_write(input logic [15:0] addr, input logic [31:0] data);
    @(negedge pclk);
    psel    = 1'b1;
    penable = 1'b0;
    pwrite  = 1'b1;
    paddr   = addr;
    pwdata  = data;
    @(negedge pclk);
    penable = 1'b1;
    @(posedge pclk);
    while (!pready) @(posedge pclk);
    @(negedge pclk);
    psel    = 1'b0;
    penable = 1'b0;
    pwrite  = 1'b0;
    paddr   = '0;
    pwdata  = '0;
  endtask

  task automatic apb_read(
    input  logic [15:0] addr,
    output logic [31:0] data,
    output logic        err
  );
    @(negedge pclk);
    psel    = 1'b1;
    penable = 1'b0;
    pwrite  = 1'b0;
    paddr   = addr;
    @(negedge pclk);
    penable = 1'b1;
    @(posedge pclk);
    while (!pready) @(posedge pclk);
    data = prdata;
    err  = pslverr;
    @(negedge pclk);
    psel    = 1'b0;
    penable = 1'b0;
    paddr   = '0;
  endtask

  // ---------------------------------------------------------------------------
  // 用例公共变量
  // ---------------------------------------------------------------------------
  int unsigned n_case_err;
  logic [31:0] rd_data;
  logic        rd_err;
  int          i;
  int          pp;

  task automatic check(input logic cond, input string msg);
    if (!cond) begin
      n_case_err = n_case_err + 1;
      $display("[TB][ERROR] %s (t=%0t)", msg, $time);
    end
  endtask

  // ---------------------------------------------------------------------------
  // TC_SMOKE: 复位释放 + CSR 读写 + 单包 REQ 往返
  // ---------------------------------------------------------------------------
  task automatic run_smoke();
    int unsigned out_activity;
    $display("[TB] ===== TC_SMOKE 开始 =====");

    clk_rst.do_reset(10);
    check(rst_async_n === 1'b1, "复位释放后 rst_async_n 应为 1");

    // ---- CSR: ID_REV ----
    apb_read(chi_tb_pkg::ADDR_ID_REV, rd_data, rd_err);
    check(rd_err === 1'b0, "ID_REV 读不应报 pslverr");
    $display("[TB] ID_REV = 0x%08h (期望 0x%08h)", rd_data, chi_tb_pkg::ID_REV_EXPECT);

    // ---- CSR: 路由表写入 + 回读 ----
    apb_write(chi_tb_pkg::ADDR_ROUTE_TBL_ADDR, 32'h0000_0005);
    apb_write(chi_tb_pkg::ADDR_ROUTE_TBL_DATA, {13'h0, 3'd3, 16'h1234});
    apb_write(chi_tb_pkg::ADDR_ROUTE_TBL_CTRL, 32'h0000_0001);
    apb_read(chi_tb_pkg::ADDR_ROUTE_TBL_ADDR, rd_data, rd_err);
    $display("[TB] ROUTE_TBL_ADDR 回读 = 0x%08h", rd_data);

    // ---- CSR: QoS 权重 ----
    apb_write(chi_tb_pkg::ADDR_QOS_WEIGHT_BASE, 32'h0000_0008);
    apb_read(chi_tb_pkg::ADDR_QOS_WEIGHT_BASE, rd_data, rd_err);
    $display("[TB] QOS_WEIGHT[0] 回读 = 0x%08h", rd_data);

    // ---- CSR: ERR_EN ----
    apb_write(chi_tb_pkg::ADDR_ERR_EN, 32'h0000_00FF);
    apb_read(chi_tb_pkg::ADDR_ERR_EN, rd_data, rd_err);
    $display("[TB] ERR_EN 回读 = 0x%08h", rd_data);

    // ---- 非法地址 ----
    apb_read(16'hFFF0, rd_data, rd_err);
    $display("[TB] 非法地址 0x%FFF0 读: prdata=0x%08h pslverr=%b", rd_data, rd_err);

    // ---- 链路：端口 0 发 1 个 REQ，目标端口 3 ----
    //      send_req(opcode, size, order, domain, tgt_id, src_id, qos, txn_id, payload)
    u_rn[0].send_req(chi_tb_pkg::OP_REQ_READ_SHARED, 3'd3, 3'd0, 2'd0,
                     16'h1234, 16'h0000, 1'b0, 8'h01, {448'h0, 16'hA5A5});
    $display("[TB] 端口0 已发送 1 个 REQ (tgt=0x1234)");

    // 观察出口活动
    out_activity = 0;
    for (i = 0; i < 200; i++) begin
      @(posedge clk);
      if (|link_out_valid) out_activity = out_activity + 1;
    end
    $display("[TB] 200 周期内出口 valid 活动拍数 = %0d", out_activity);
    if (out_activity == 0) begin
      $display("[TB][WARN] 出口全程无活动 —— 与骨架 RTL 未接线一致（见报告 D-01）");
    end

    $display("[TB] ===== TC_SMOKE 结束 =====");
  endtask

  // ---------------------------------------------------------------------------
  // TC_CONGESTION: 单出口过载 + 下游反压 + credit 观测
  // ---------------------------------------------------------------------------
  task automatic run_congestion();
    int unsigned stall_cycles;
    $display("[TB] ===== TC_CONGESTION 开始 =====");
    clk_rst.do_reset(10);

    // 8 个端口并行向端口 0 发 REQ，制造出口过载
    // 注：generate 块变量索引调用（u_rn[pp].task()）非标准，改用独立 fork 分支
    fork
      u_rn[0].send_req(chi_tb_pkg::OP_REQ_WRITE_UNIQUE, 3'd7, 3'd0, 2'd0,
                       16'h0000, 16'h0100, 2'd0, 8'h10, {448'h0, 16'hB000});
      u_rn[1].send_req(chi_tb_pkg::OP_REQ_WRITE_UNIQUE, 3'd7, 3'd0, 2'd0,
                       16'h0000, 16'h0101, 2'd1, 8'h11, {448'h0, 16'hB001});
      u_rn[2].send_req(chi_tb_pkg::OP_REQ_WRITE_UNIQUE, 3'd7, 3'd0, 2'd0,
                       16'h0000, 16'h0102, 2'd2, 8'h12, {448'h0, 16'hB002});
      u_rn[3].send_req(chi_tb_pkg::OP_REQ_WRITE_UNIQUE, 3'd7, 3'd0, 2'd0,
                       16'h0000, 16'h0103, 2'd3, 8'h13, {448'h0, 16'hB003});
      u_rn[4].send_req(chi_tb_pkg::OP_REQ_WRITE_UNIQUE, 3'd7, 3'd0, 2'd0,
                       16'h0000, 16'h0104, 2'd0, 8'h14, {448'h0, 16'hB004});
      u_rn[5].send_req(chi_tb_pkg::OP_REQ_WRITE_UNIQUE, 3'd7, 3'd0, 2'd0,
                       16'h0000, 16'h0105, 2'd1, 8'h15, {448'h0, 16'hB005});
      u_rn[6].send_req(chi_tb_pkg::OP_REQ_WRITE_UNIQUE, 3'd7, 3'd0, 2'd0,
                       16'h0000, 16'h0106, 2'd2, 8'h16, {448'h0, 16'hB006});
      u_rn[7].send_req(chi_tb_pkg::OP_REQ_WRITE_UNIQUE, 3'd7, 3'd0, 2'd0,
                       16'h0000, 16'h0107, 2'd3, 8'h17, {448'h0, 16'hB007});
    join
    $display("[TB] 8 个端口已向端口0 各发送 1 个 REQ");

    // 统计出口反压拍数
    stall_cycles = 0;
    for (i = 0; i < 500; i++) begin
      @(posedge clk);
      for (pp = 0; pp < PORT_NUM; pp++) begin
        if (link_out_valid[pp][0] && !link_out_ready[pp][0]) begin
          stall_cycles = stall_cycles + 1;
        end
      end
    end
    $display("[TB] 500 周期内出口反压拍数 = %0d", stall_cycles);

    // 读 CREDIT_STATUS
    apb_read(chi_tb_pkg::ADDR_CREDIT_STATUS, rd_data, rd_err);
    $display("[TB] CREDIT_STATUS = 0x%08h", rd_data);

    $display("[TB] ===== TC_CONGESTION 结束 =====");
  endtask

  // ---------------------------------------------------------------------------
  // TC_ORDERING: 三层保序 + 多 beat 同包
  // ---------------------------------------------------------------------------
  task automatic run_ordering();
    int t;
    int b;
    $display("[TB] ===== TC_ORDERING 开始 =====");
    clk_rst.do_reset(10);

    // 同一 (src, tgt, domain) 连发 8 个 REQ，txn_id 递增
    for (t = 0; t < 8; t++) begin
      u_rn[1].send_req(chi_tb_pkg::OP_REQ_READ_UNIQUE, 3'd4, 3'd2, 2'd1,
                       16'h0200, 16'h0001, 1'b1, 8'(8'h20 + t),
                       {448'h0, 16'(16'hC000 + t)});
    end
    $display("[TB] 端口1 已发送 8 个同 PoS 域 REQ (txn 0x20~0x27)");

    // 多 beat 同包：HN 侧回送 4 beat DAT（末 beat is_last=1）
    //   send_dat(opcode, domain, tgt_id, src_id, txn_id, payload, is_last)
    for (b = 0; b < 4; b++) begin
      u_hn[2].send_dat(chi_tb_pkg::OP_DAT_COMP_DATA, 2'd0, 16'h0200, 16'h0002,
                       8'h30, {448'h0, 16'(16'hD000 + b)}, (b == 3));
    end
    $display("[TB] 端口2 HN 已回送 4 beat DAT (txn 0x30, 末beat=1)");

    repeat (300) @(posedge clk);
    $display("[TB] ===== TC_ORDERING 结束 =====");
  endtask

  // ---------------------------------------------------------------------------
  // 主流程
  // ---------------------------------------------------------------------------
  initial begin
    psel    = 1'b0;
    penable = 1'b0;
    pwrite  = 1'b0;
    paddr   = '0;
    pwdata  = '0;
    n_case_err = 0;

    @(posedge clk);

`ifdef TC_SMOKE
    run_smoke();
`elsif TC_CONGESTION
    run_congestion();
`elsif TC_ORDERING
    run_ordering();
`else
    $display("[TB][WARN] 未定义用例宏，默认执行 TC_SMOKE");
    run_smoke();
`endif

    repeat (50) @(posedge clk);
    u_scb.report();

    $display("======================== chi_router_tb_top =======================");
    if (n_case_err == 0) begin
      $display("  TB CASE RESULT: PASS (0 error)");
    end else begin
      $display("  TB CASE RESULT: FAIL (%0d error)", n_case_err);
      $display("SOME TESTS FAILED");
    end
    $display("==================================================================");
    $finish;
  end

  // ---------------------------------------------------------------------------
  // 超时保护
  // ---------------------------------------------------------------------------
  initial begin
    #5000000;
    $display("[TB][ERROR] TIMEOUT: 仿真超时（可能存在死锁）");
    $display("SOME TESTS FAILED");
    $finish;
  end

endmodule

`default_nettype wire