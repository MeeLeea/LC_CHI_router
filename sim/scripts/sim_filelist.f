#=============================================================================
# 文件: sim/scripts/sim_filelist.f
# 状态: 【已迁移 · 请勿使用本文件】
#
# 说明:
#   本文件是第一轮生成的早期版本，仅包含 rtl/ 与 4 个原始 tb 文件，
#   缺少后续新增的 11 个 TB 文件（chi_tb_pkg / chi_clk_rst_if /
#   chi_coverage / chi_assertions / 7 个模块级 TB），若误用会导致
#   xelab 找不到 work.chi_tb_* 顶层。
#
# 唯一有效清单:
#   scripts/sim_filelist.f        ← 请使用这个（46 条，含全部 RTL + TB + glbl.v）
#
# 唯一有效脚本:
#   scripts/start.tcl             全量回归
#   scripts/run_one.tcl           单 tb 定向回归
#   scripts/README.md             命令行用法
#
# 保留本文件仅为兼容旧路径引用；内容不再维护。
#=============================================================================
