//=============================================================================
// 文件: tb/chi_assertions.sv
// 功能: 协议断言集合 —— 握手 / 复位 / credit 不下溢 / 保序 / APB
// 说明:
//   - 以文件作用域 bind 挂到 RTL，不改动 RTL 源码
//   - 分层策略：
//       * 跨模块时序性质  -> SVA 并发断言（property/assert property）
//       * 逐端口/逐通道检查 -> always_ff + 立即断言（避免 generate 内声明
//         property 带来的 Xsim 兼容风险）
//   - 仅使用 Xsim 支持的 SVA 子集：|->、|=>、$rose/$fell/$stable/disable iff
//     不使用 local variable 序列匹配、expect、多时钟序列
//   - 信号连接一律用「显式端口绑定到被绑模块内部信号名」，不做跨层次引用
//=============================================================================
`default_nettype none
`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// 顶层链路协议断言
// -----------------------------------------------------------------------------
module chi_top_assertions #(
  parameter int PORT_NUM = 8,
  parameter int WIDE_W   = 512,
  parameter int NARROW_W = 256
) (
  input wire        clk,
  input wire        rst_async_n,
  input wire [PORT_NUM-1:0][3:0]      link_out_valid,
  input wire [PORT_NUM-1:0][3:0]      link_out_ready,
  input wire [PORT_NUM-1:0][WIDE_W-1:0]   link_out_req,
  input wire [PORT_NUM-1:0][WIDE_W-1:0]   link_out_dat,
  input wire [PORT_NUM-1:0][NARROW_W-1:0] link_out_rsp,
  input wire [PORT_NUM-1:0][NARROW_W-1:0] link_out_snp
);

  // ---------------------------------------------------------------------------
  // A1: 复位期间出口 valid 必须全 0（RST-03）
  // ---------------------------------------------------------------------------
  property p_rst_no_valid;
    @(posedge clk)
      (!rst_async_n) |-> (link_out_valid == '0);
  endproperty

  assert property (p_rst_no_valid)
    else $error("[ASSERT][A1] 复位期间 link_out_valid 非 0");

  // ---------------------------------------------------------------------------
  // A2: REQ 通道 valid 拉高后须保持到 ready 采样成功
  //     逐端口用立即断言实现（避免 32 个 generate 内 property）
  // ---------------------------------------------------------------------------
  logic [PORT_NUM-1:0] req_pend;   // 上一拍已 valid 但未 ready
  int p;

  always_ff @(posedge clk or negedge rst_async_n) begin
    if (!rst_async_n) begin
      req_pend <= '0;
    end else begin
      for (p = 0; p < PORT_NUM; p++) begin
        // A2: 前一拍 valid&&!ready，本拍 valid 必须仍为 1
        if (req_pend[p] && !link_out_valid[p][0]) begin
          $error("[ASSERT][A2] port=%0d REQ valid 在 ready 前被撤销", p);
        end
        req_pend[p] <= link_out_valid[p][0] && !link_out_ready[p][0];
      end
    end
  end

  // ---------------------------------------------------------------------------
  // A3: valid 有效期间 REQ 数据保持稳定（spec 4.1「valid 有效时稳定」）
  // ---------------------------------------------------------------------------
  logic [PORT_NUM-1:0][WIDE_W-1:0] req_hold;

  always_ff @(posedge clk or negedge rst_async_n) begin
    if (!rst_async_n) begin
      req_hold <= '0;
    end else begin
      for (p = 0; p < PORT_NUM; p++) begin
        if (req_pend[p] && (link_out_req[p] !== req_hold[p])) begin
          $error("[ASSERT][A3] port=%0d REQ data 在 valid 期间变化: %h -> %h",
                 p, req_hold[p], link_out_req[p]);
        end
        req_hold[p] <= link_out_req[p];
      end
    end
  end

  // ---------------------------------------------------------------------------
  // A4: valid 有效时对应通道数据不得含 X
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_async_n) begin
    if (!rst_async_n) begin
      // 复位期间不检查
    end else begin
      for (p = 0; p < PORT_NUM; p++) begin
        if (link_out_valid[p][0] && $isunknown(link_out_req[p])) begin
          $error("[ASSERT][A4] port=%0d REQ valid 时数据含 X", p);
        end
        if (link_out_valid[p][1] && $isunknown(link_out_rsp[p])) begin
          $error("[ASSERT][A4] port=%0d RSP valid 时数据含 X", p);
        end
        if (link_out_valid[p][2] && $isunknown(link_out_dat[p])) begin
          $error("[ASSERT][A4] port=%0d DAT valid 时数据含 X", p);
        end
        if (link_out_valid[p][3] && $isunknown(link_out_snp[p])) begin
          $error("[ASSERT][A4] port=%0d SNP valid 时数据含 X", p);
        end
      end
    end
  end

endmodule

// -----------------------------------------------------------------------------
// credit 不下溢 / 不溢出断言（DL-01 / DL-03）
//   绑定目标：credit_mgr（内部数组名为 cred）
// -----------------------------------------------------------------------------
module chi_credit_assertions #(
  parameter int CH_NUM   = 4,
  parameter int CRD_W    = 8,
  parameter int INIT_CRD = 16
) (
  input wire                   clk,
  input wire                   rst_n,
  input wire [CH_NUM-1:0]      send_flit,
  input wire [CH_NUM-1:0][CRD_W-1:0] crd_cnt
);

  // A5: credit 为 0 时不得发送（防下溢）
  property p_no_send_at_zero;
    @(posedge clk) disable iff (!rst_n)
      (crd_cnt[0] == '0) |-> !send_flit[0];
  endproperty

  assert property (p_no_send_at_zero)
    else $error("[ASSERT][A5] ch=0 credit=0 仍发送 flit");

  // A6: credit 不得超过初始上限（防溢出）
  property p_crd_no_over;
    @(posedge clk) disable iff (!rst_n)
      (crd_cnt[0] <= CRD_W'(INIT_CRD));
  endproperty

  assert property (p_crd_no_over)
    else $error("[ASSERT][A6] ch=0 credit 超过上限 %0d", INIT_CRD);

  // 其余通道用立即断言（逐通道，无 generate property）
  int c;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // 复位期间不检查
    end else begin
      for (c = 1; c < CH_NUM; c++) begin
        if ((crd_cnt[c] == '0) && send_flit[c]) begin
          $error("[ASSERT][A5] ch=%0d credit=0 仍发送 flit", c);
        end
        if (crd_cnt[c] > CRD_W'(INIT_CRD)) begin
          $error("[ASSERT][A6] ch=%0d credit=%0d 超过上限 %0d",
                 c, crd_cnt[c], INIT_CRD);
        end
      end
    end
  end

endmodule

// -----------------------------------------------------------------------------
// 保序断言：tail_lock 锁定期间只允许 locked_qid 出队（ORD-02）
//   绑定目标：tail_lock
// -----------------------------------------------------------------------------
module chi_order_assertions #(
  parameter int QUEUE_NUM = 512,
  parameter int QW        = 9
) (
  input wire        clk,
  input wire        rst_n,
  input wire        locked,
  input wire [QW-1:0] locked_qid,
  input wire        beat_valid,
  input wire [QW-1:0] beat_qid
);

  // A7: 锁定期间出队 qid 必须等于 locked_qid
  property p_lock_hold;
    @(posedge clk) disable iff (!rst_n)
      (locked && beat_valid) |-> (beat_qid == locked_qid);
  endproperty

  assert property (p_lock_hold)
    else $error("[ASSERT][A7] tail_lock 锁定期间出现异 qid 出队: locked=%0d beat=%0d",
                locked_qid, beat_qid);

  // A8: 无 beat 时锁定状态须保持（不得自行解锁）
  property p_lock_persist;
    @(posedge clk) disable iff (!rst_n)
      (locked && !beat_valid) |=> locked;
  endproperty

  assert property (p_lock_persist)
    else $error("[ASSERT][A8] tail_lock 在无 beat 情况下自行解锁");

endmodule

// -----------------------------------------------------------------------------
// APB4 协议断言
//   绑定目标：chi_router_top
// -----------------------------------------------------------------------------
module chi_apb_assertions (
  input wire        pclk,
  input wire        presetn,
  input wire        psel,
  input wire        penable,
  input wire        pwrite,
  input wire        pready,
  input wire [15:0] paddr,
  input wire [31:0] pwdata
);

  // A9: 等待周期内 paddr/pwrite/pwdata 保持稳定
  property p_apb_ctrl_stable;
    @(posedge pclk) disable iff (!presetn)
      (psel && penable && !pready)
      |=> ($stable(paddr) && $stable(pwrite) && $stable(pwdata));
  endproperty

  assert property (p_apb_ctrl_stable)
    else $error("[ASSERT][A9] APB 等待周期内 paddr/pwrite/pwdata 变化");

  // A10: penable 不得在 psel 无效时拉高
  property p_apb_penable_after_psel;
    @(posedge pclk) disable iff (!presetn)
      penable |-> psel;
  endproperty

  assert property (p_apb_penable_after_psel)
    else $error("[ASSERT][A10] APB penable 在 psel 无效时拉高");

  // A11: 写传输必须伴随 pwrite=1；读传输 pwrite=0
  property p_apb_pwrite_known;
    @(posedge pclk) disable iff (!presetn)
      (psel && penable) |-> !$isunknown(pwrite);
  endproperty

  assert property (p_apb_pwrite_known)
    else $error("[ASSERT][A11] APB pwrite 在传输期间为 X");

endmodule

// =============================================================================
// bind 语句（文件作用域，不改动 RTL 源码）
// =============================================================================

// ---- 顶层链路协议 ----
bind chi_router_top chi_top_assertions #(
  .PORT_NUM (PORT_NUM),
  .WIDE_W   (WIDE_W),
  .NARROW_W (NARROW_W)
) u_top_assert (
  .clk            (clk),
  .rst_async_n    (rst_async_n),
  .link_out_valid (link_out_valid),
  .link_out_ready (link_out_ready),
  .link_out_req   (link_out_req),
  .link_out_dat   (link_out_dat),
  .link_out_rsp   (link_out_rsp),
  .link_out_snp   (link_out_snp)
);

// ---- APB4 ----
bind chi_router_top chi_apb_assertions u_apb_assert (
  .pclk    (pclk),
  .presetn (presetn),
  .psel    (psel),
  .penable (penable),
  .pwrite  (pwrite),
  .pready  (pready),
  .paddr   (paddr),
  .pwdata  (pwdata)
);

// ---- credit 不下溢（绑定 credit_mgr，内部数组 cred 与端口 crd_cnt 同名映射）----
bind credit_mgr chi_credit_assertions #(
  .CH_NUM   (CH_NUM),
  .CRD_W    (CRD_W),
  .INIT_CRD (INIT_CRD)
) u_crd_assert (
  .clk       (clk),
  .rst_n     (rst_n),
  .send_flit (send_flit),
  .crd_cnt   (cred)
);

// ---- 尾锁保序 ----
bind tail_lock chi_order_assertions #(
  .QUEUE_NUM (QUEUE_NUM),
  .QW        ($clog2(QUEUE_NUM))
) u_ord_assert (
  .clk       (clk),
  .rst_n     (rst_n),
  .locked    (locked),
  .locked_qid(locked_qid),
  .beat_valid(beat_valid),
  .beat_qid  (beat_qid)
);

`default_nettype wire