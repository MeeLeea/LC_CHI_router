//=============================================================================
// 文件: rtl/filelist.f
// 功能: CHI Router 编译顺序清单（编码规范见 doc/design_spec.md 2.4 C-04）
// 顺序: pkg -> common -> buffer -> ingress -> sched -> xbar -> egress -> csr -> top
//=============================================================================

// ---- 1. 全局定义（必须最先编译） ----
rtl/chi_router_pkg.sv

// ---- 2. common ----
rtl/common/sync_2ff.sv
rtl/common/clk_rst_gen.sv

// ---- 3. buffer ----
rtl/buffer/sram_wrapper.sv
rtl/buffer/voq_linklist.sv
rtl/buffer/pool_credit.sv
rtl/buffer/buffer_subsys.sv

// ---- 4. ingress ----
rtl/ingress/flit_decode.sv
rtl/ingress/parity_check.sv
rtl/ingress/route_lookup.sv
rtl/ingress/pool_alloc.sv
rtl/ingress/port_ingress.sv

// ---- 5. sched ----
rtl/sched/rr_arbiter.sv
rtl/sched/islip_arbiter.sv
rtl/sched/scheduler.sv

// ---- 6. xbar ----
rtl/xbar/crossbar_a.sv
rtl/xbar/crossbar_b.sv

// ---- 7. egress ----
rtl/egress/credit_mgr.sv
rtl/egress/tail_lock.sv
rtl/egress/order_guard.sv
rtl/egress/qos_shaper.sv
rtl/egress/port_egress.sv

// ---- 8. csr ----
rtl/csr/apb_slave.sv
rtl/csr/route_table.sv
rtl/csr/qos_regs.sv
rtl/csr/pmu_counters.sv
rtl/csr/err_regs.sv
rtl/csr/csr_subsys.sv

// ---- 9. top ----
rtl/chi_router_top.sv
