//=============================================================================
// 文件: rtl/chi_router_top.sv
// 功能: 顶层 —— 例化 ingress / buffer / sched / xbar / egress / csr
// 组成见 doc/design_spec.md 第 3 章
//=============================================================================
`default_nettype none

module chi_router_top #(
  parameter int PORT_NUM = 8,
  parameter int WIDE_W   = 512,
  parameter int NARROW_W = 256,
  parameter int POOL_NUM = 8,
  parameter int BANK_PER_POOL = 16
) (
  input  wire clk,
  input  wire rst_async_n,
  // ---- 链路侧（每端口 4 通道） ----
  input  wire [PORT_NUM-1:0][3:0]      link_in_valid,
  output wire [PORT_NUM-1:0][3:0]      link_in_ready,
  input  wire [PORT_NUM-1:0][WIDE_W-1:0]   link_in_req,
  input  wire [PORT_NUM-1:0][NARROW_W-1:0] link_in_rsp,
  input  wire [PORT_NUM-1:0][WIDE_W-1:0]   link_in_dat,
  input  wire [PORT_NUM-1:0][NARROW_W-1:0] link_in_snp,
  output wire [PORT_NUM-1:0][3:0]      link_out_valid,
  input  wire [PORT_NUM-1:0][3:0]      link_out_ready,
  output wire [PORT_NUM-1:0][WIDE_W-1:0]   link_out_req,
  output wire [PORT_NUM-1:0][NARROW_W-1:0] link_out_rsp,
  output wire [PORT_NUM-1:0][WIDE_W-1:0]   link_out_dat,
  output wire [PORT_NUM-1:0][NARROW_W-1:0] link_out_snp,
  // ---- APB4 CSR ----
  input  wire        pclk,
  input  wire        presetn,
  input  wire        psel,
  input  wire        penable,
  input  wire        pwrite,
  input  wire [15:0] paddr,
  input  wire [31:0] pwdata,
  output wire [31:0] prdata,
  output wire        pready,
  output wire        pslverr,
  output wire        irq
);

  // ---------------- 时钟复位 ----------------
  wire rst_sync_n;
  wire gclk;
  clk_rst_gen u_clk_rst_gen (
    .clk         (clk),
    .rst_async_n (rst_async_n),
    .cg_en       (1'b1),
    .rst_sync_n  (rst_sync_n),
    .gclk        (gclk)
  );

  // ---------------- 子系统例化（待架构细化后接线） ----------------
  // buffer_subsys  u_buffer_subsys (...);
  // port_ingress   u_ingress[PORT_NUM] (...);
  // scheduler      u_scheduler (...);
  // crossbar_a     u_xbar_a (...);
  // crossbar_b     u_xbar_b (...);
  // port_egress    u_egress[PORT_NUM] (...);
  // csr_subsys     u_csr_subsys (...);

  // ---------------- 骨架阶段输出 tie-off ----------------
  // 子系统未接线前，输出不得悬空（未驱动 wire 为 X）：
  //   - 违反 RST-03（复位期间 link_out_valid 应为 0），断言 A1 会持续报错
  //   - CSR 侧 prdata/pslverr 为 X 会导致 APB 读回 X
  // 骨架契约：
  //   - 出口链路 valid=0（无出口活动，见 doc 报告 D-01）
  //   - 入口 ready=1（恒接收：系统级 TB 的 agent 发送任务需完成握手，
  //     否则 send_req/send_dat 死等导致激励超时；scoreboard 只在
  //     出口 fire 时比对，入口接收不会误报）
  //   - APB 读立即完成且返回 0、无错误
  // 子系统接线后删除本段 tie-off。
  assign link_out_valid = '0;
  assign link_out_req   = '0;
  assign link_out_rsp   = '0;
  assign link_out_dat   = '0;
  assign link_out_snp   = '0;
  assign link_in_ready  = '1;

  assign prdata  = '0;
  assign pready  = 1'b1;
  assign pslverr = '0;
  assign irq     = '0;

endmodule

`default_nettype wire
