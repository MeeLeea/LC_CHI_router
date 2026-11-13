//=============================================================================
// 文件: sim/regression.f
// 功能: 回归列表（编译源 + 用例子清单）
//=============================================================================
-f ../rtl/filelist.f
../tb/sram_model/sram_behavioral.sv
../tb/chi_agent_rn.sv
../tb/chi_agent_hn.sv
../tb/chi_scoreboard.sv
../tb/chi_router_tb_top.sv

// ---- 用例 ----
-f tests/tc_smoke.f
-f tests/tc_congestion.f
-f tests/tc_ordering.f
