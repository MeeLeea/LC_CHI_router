# =============================================================================
# 文件: scripts/run_one.tcl
# 功能: 单 testbench 定向回归脚本（filelist 驱动，复用 start.tcl 已编译产物）
# 用法（在工程根目录下）:
#   vivado -mode batch -source scripts/run_one.tcl -tclargs <tb_name> [<define>]
# 示例:
#   vivado -mode batch -source scripts/run_one.tcl -tclargs chi_tb_rr_arbiter
#   vivado -mode batch -source scripts/run_one.tcl -tclargs chi_router_tb_top TC_SMOKE
#   vivado -mode batch -source scripts/run_one.tcl -tclargs chi_router_tb_top TC_CONGESTION
#   vivado -mode batch -source scripts/run_one.tcl -tclargs chi_router_tb_top TC_ORDERING
# 不传参数时默认跑 chi_tb_rr_arbiter
#
# 前置条件:
#   - 已执行过 scripts/start.tcl（work 库已存在，无需重新 xvlog）
#   - 若仅改了 TB 代码，需重跑 start.tcl 或本脚本加 -recompile
#
# 说明:
#   - 不创建/打开 Vivado 工程，直接复用 ./xsim.dir 工作库
#   - 仅重新 xelab + xsim
# =============================================================================

set script_dir [file dirname [file normalize [info script]]]
set proj_root  [file normalize [file join $script_dir ..]]
cd $proj_root

# -----------------------------------------------------------------------------
# 0. 参数解析
# -----------------------------------------------------------------------------
set tb_name  [lindex $argv 0]
set tb_define [lindex $argv 1]

if {$tb_name eq ""} { set tb_name "chi_tb_rr_arbiter" }

# 全部可用 tb 名（与 start.tcl 的 tb_specs 保持一致）
set valid_tbs [list \
    "chi_tb_rr_arbiter" \
    "chi_tb_parity_check" \
    "chi_tb_sync_2ff" \
    "chi_tb_pool_credit" \
    "chi_tb_tail_lock" \
    "chi_tb_credit_mgr" \
    "chi_tb_flit_decode" \
    "chi_router_tb_top" \
]

if {[lsearch -exact $valid_tbs $tb_name] < 0} {
    puts "ERROR: 未知 testbench '$tb_name'"
    puts "可用 tb 列表："
    foreach t $valid_tbs { puts "  - $t" }
    puts ""
    puts "说明: chi_router_tb_top 需通过第 2 个 -tclargs 参数指定用例宏："
    puts "  TC_SMOKE / TC_CONGESTION / TC_ORDERING"
    exit 1
}

# -----------------------------------------------------------------------------
# 1. 目录准备
# -----------------------------------------------------------------------------
file mkdir ./reports
file mkdir ./cov_db

# -----------------------------------------------------------------------------
# 2. 检查工作库是否存在（start.tcl 已编译产物）
# -----------------------------------------------------------------------------
if {![file exists "./xsim.dir"]} {
    puts "ERROR: 未找到 ./xsim.dir —— 请先执行 scripts/start.tcl 完成 xvlog 编译"
    exit 1
}

# -----------------------------------------------------------------------------
# 3. glbl.v 定位（xelab 需要 glbl 模块）
# -----------------------------------------------------------------------------
if {![info exists ::env(XILINX_VIVADO)]} {
    puts "ERROR: 环境变量 XILINX_VIVADO 未设置，无法定位 glbl.v（请通过 vivado 批处理启动）"
    exit 1
}
set glbl_path [file join $::env(XILINX_VIVADO) "data/verilog/src/glbl.v"]
if {![file exists $glbl_path]} {
    puts "ERROR: 找不到 glbl.v: $glbl_path"
    exit 1
}

# -----------------------------------------------------------------------------
# 4. snapshot 名（系统级 tb 带宏后缀，避免与 start.tcl 产物冲突）
# -----------------------------------------------------------------------------
set snap $tb_name
set defs {}
if {$tb_define ne ""} {
    set defs [list $tb_define]
    set snap "${tb_name}_[string tolower $tb_define]"
}

puts "=========================================================="
puts "\[SIM\] single tb = $tb_name   define = $tb_define   snapshot = ${snap}_behav"
puts "=========================================================="

# 清理同名 snapshot（规避 Windows 文件锁）
catch {file delete -force "./xsim.dir/${snap}_behav"}

# -----------------------------------------------------------------------------
# 5. xelab
# -----------------------------------------------------------------------------
set xelab_cmd [list xelab --incr --debug typical --relax --mt 2 \
    -L work -L unisims_ver -L unimacro_ver -L secureip \
    --snapshot ${snap}_behav]
foreach d $defs { lappend xelab_cmd -d $d }
lappend xelab_cmd work.$tb_name work.glbl

puts "\[INFO\] 执行: $xelab_cmd"
if {[catch {exec {*}$xelab_cmd 2>@1} elab_out]} {
    puts "ERROR: $tb_name xelab 失败："
    puts $elab_out
    exit 1
}
puts "\[INFO\] xelab 完成"

# -----------------------------------------------------------------------------
# 6. xsim（覆盖率按 tb 分文件保存）
# -----------------------------------------------------------------------------
set env(SIM_TB) $snap
set xsim_cmd [list xsim ${snap}_behav \
    -tclbatch ./scripts/xsim_run.tcl \
    --cov_db_dir ./cov_db \
    -log ./reports/${snap}_simulate.log]

puts "\[INFO\] 执行: $xsim_cmd"
set sim_err ""
if {[catch {exec {*}$xsim_cmd 2>@1} sim_out]} {
    set sim_err $sim_out
    puts "WARN: xsim 返回非零：$sim_err"
}

# -----------------------------------------------------------------------------
# 7. 判定
# -----------------------------------------------------------------------------
set log_file "./reports/${snap}_simulate.log"
set verdict "SUCCESS"
if {[file exists $log_file]} {
    set lf [open $log_file r]
    set content [read $lf]
    close $lf
    if {[string match "*SOME TESTS FAILED*" $content] || [string first "\[ERROR\]" $content] >= 0} {
        set verdict "FAILED"
    }
} elseif {$sim_err ne ""} {
    set verdict "FAILED"
}

puts "=========================================================="
if {$verdict eq "SUCCESS"} {
    puts "\[RESULT\] $tb_name ($tb_define) : SUCCESS"
    puts "\[INFO\] 日志: $log_file"
    puts "\[INFO\] 覆盖率: ./cov_db/${snap}_coverage.ucdb"
    puts "=========================================================="
    exit 0
} else {
    puts "\[RESULT\] $tb_name ($tb_define) : FAILED"
    puts "\[INFO\] 日志: $log_file"
    puts "SOME TESTS FAILED"
    puts "=========================================================="
    exit 1
}