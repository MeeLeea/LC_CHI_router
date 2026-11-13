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

endmodule

`default_nettype wire
