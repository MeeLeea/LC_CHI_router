# =============================================================================
# 文件: scripts/start.tcl
# 功能: Vivado Xsim 仿真工程启动脚本（filelist 驱动，批处理模式）
# 用法（在工程根目录下，PowerShell 或 CMD）:
#   vivado -mode batch -source scripts/start.tcl
# 说明:
#   - 仅做 Xsim 仿真（xvlog / xelab / xsim），不创建综合工程
#   - 严禁 add_files / glob 目录通配（会把 RTL 与 TB 混入同一编译集）
#   - 编译对象严格等于 scripts/sim_filelist.f 中列出的文件，不增不删
#   - 产物: ./reports/*.log、./cov_db/*.ucdb、./reports/coverage_report.txt
# =============================================================================

set script_dir  [file dirname [file normalize [info script]]]
set proj_root   [file normalize [file join $script_dir ..]]

# 切到工程根（sim_filelist.f 中路径相对工程根）
cd $proj_root
puts "\[INFO\] 工程根目录: $proj_root"

# -----------------------------------------------------------------------------
# 0. 目录准备
# -----------------------------------------------------------------------------
file mkdir ./reports
file mkdir ./cov_db
file mkdir ./sim.dir

# -----------------------------------------------------------------------------
# 1. 读取 filelist（缺失则显式报错，禁止编造）
# -----------------------------------------------------------------------------
set fl_path "./scripts/sim_filelist.f"
if {![file exists $fl_path]} {
    puts "ERROR: 找不到 $fl_path —— 请前端/仿真负责人补齐 sim_filelist.f，脚本不自行编造文件列表"
    exit 1
}

set fl [open $fl_path r]
set raw_lines [split [read $fl] "\n"]
close $fl

set src_files   {}
set incdirs     {}
set defines     {}
set glbl_entry  ""

foreach line $raw_lines {
    set l [string trim $line]
    # 跳过空行与 # 注释
    if {$l eq "" || [string index $l 0] eq "#"} { continue }
    # +incdir+ / +define+ 透传
    if {[string match "+incdir+*" $l]} {
        foreach d [split [string range $l 8 end] "+"] {
            if {$d ne ""} { lappend incdirs $d }
        }
        continue
    }
    if {[string match "+define+*" $l]} {
        foreach d [split [string range $l 8 end] "+"] {
            if {$d ne ""} { lappend defines $d }
        }
        continue
    }
    # glbl.v：含 $env(XILINX_VIVADO) 的条目单独处理
    if {[string match "*glbl.v" $l]} {
        set glbl_entry $l
        continue
    }
    lappend src_files $l
}

puts "\[INFO\] filelist 中源文件条目数 = [llength $src_files]"

# -----------------------------------------------------------------------------
# 2. 逐文件 file exists 核验（任一缺失即报错退出）
# -----------------------------------------------------------------------------
set missing {}
foreach f $src_files {
    if {![file exists $f]} { lappend missing $f }
}

# glbl.v 单独核验
set glbl_path ""
if {$glbl_entry ne ""} {
    if {![info exists ::env(XILINX_VIVADO)]} {
        puts "ERROR: 环境变量 XILINX_VIVADO 未设置，无法定位 glbl.v（请通过 vivado 批处理启动）"
        exit 1
    }
    set glbl_path [file join $::env(XILINX_VIVADO) "data/verilog/src/glbl.v"]
    if {![file exists $glbl_path]} {
        puts "ERROR: 找不到 glbl.v: $glbl_path"
        exit 1
    }
    puts "\[INFO\] glbl.v = $glbl_path"
} else {
    puts "ERROR: sim_filelist.f 中缺少 glbl.v 条目（xelab 需要 glbl 模块）"
    exit 1
}

if {[llength $missing] > 0} {
    puts "ERROR: 以下文件在 sim_filelist.f 中列出但磁盘不存在，请前端补齐后重试："
    foreach m $missing { puts "       - $m" }
    exit 1
}
puts "\[INFO\] 全部 [llength $src_files] 个文件核验通过（file exists OK）"

# -----------------------------------------------------------------------------
# 3. 编译（xvlog -f sim_filelist.f，一次编译全部源文件）
#    注意：xvlog 在 Vivado batch 下为外部可执行程序，须用 exec 前缀
# -----------------------------------------------------------------------------
# 清理旧 snapshot，规避 Windows 文件锁（ld.exe: Permission denied）
foreach d [glob -nocomplain ./xsim.dir/*_behav] {
    puts "\[INFO\] 清理旧 snapshot: $d"
    catch {file delete -force $d}
}

set xvlog_cmd [list xvlog -sv --incr --relax --nolog]
foreach d $incdirs  { lappend xvlog_cmd -i $d }
foreach d $defines  { lappend xvlog_cmd -d $d }
lappend xvlog_cmd -f $fl_path

# glbl.v 单独追加编译（显式加入，不经 filelist 二次解析）
lappend xvlog_cmd -i [file join $::env(XILINX_VIVADO) "data/verilog/src"]

puts "\[INFO\] 执行: $xvlog_cmd"
if {[catch {exec {*}$xvlog_cmd 2>@1} xvlog_out]} {
    puts "ERROR: xvlog 编译失败："
    puts $xvlog_out
    exit 1
} else {
    puts $xvlog_out
}
puts "\[INFO\] xvlog 编译完成"

# glbl.v 单独编译进同一默认库
set glbl_cmd [list xvlog -v --incr --relax --nolog $glbl_path]
puts "\[INFO\] 执行: $glbl_cmd"
if {[catch {exec {*}$glbl_cmd 2>@1} glbl_out]} {
    puts "WARN: glbl.v 编译失败（若已由 filelist 编译可忽略）：$glbl_out"
} else {
    puts $glbl_out
}

# -----------------------------------------------------------------------------
# 4. 生成 xsim_run.tcl（xsim 子进程内执行的 Tcl）
#    coverage save / run all 为 xsim Tcl 命令
# -----------------------------------------------------------------------------
set run_tcl_path "./scripts/xsim_run.tcl"
set fh [open $run_tcl_path w]
puts $fh "# ============================================================================="
puts $fh "# 文件: scripts/xsim_run.tcl（由 start.tcl 自动生成，勿手工修改）"
puts $fh "# 功能: xsim 子进程内执行 —— 覆盖率按 tb 分文件保存 + run all"
puts $fh "# 说明: tb 名经 env(SIM_TB) 由调用方（start.tcl / run_one.tcl）传入"
puts $fh "# ============================================================================="
puts $fh ""
puts $fh "set tb_name \$::env(SIM_TB)"
puts $fh "puts \"\[INFO\] xsim_run.tcl: SIM_TB = \$tb_name\""
puts $fh ""
puts $fh "file mkdir ./cov_db"
puts $fh ""
puts $fh "# 覆盖率按 tb 分文件保存，避免多 tb 相互覆盖"
puts $fh "catch { coverage save -onexit ./cov_db/\${tb_name}_coverage.ucdb }"
puts $fh ""
puts $fh "# 运行直到 \$finish"
puts $fh "run all"
puts $fh ""
puts $fh "puts \"\[INFO\] xsim_run.tcl: run all 完成\""
close $fh
puts "\[INFO\] 已生成 $run_tcl_path"

# -----------------------------------------------------------------------------
# 5. 逐 tb 执行 xelab + xsim
# -----------------------------------------------------------------------------
# tb 列表（每个 tb 单独 xelab/xsim，覆盖率按 tb 分文件）
# 系统级 tb 需按用例宏分别编译，故以「tb 名 + define」成对列出
set tb_specs [list \
    [list "chi_tb_rr_arbiter"  {}] \
    [list "chi_tb_parity_check" {}] \
    [list "chi_tb_sync_2ff"    {}] \
    [list "chi_tb_pool_credit" {}] \
    [list "chi_tb_tail_lock"   {}] \
    [list "chi_tb_credit_mgr"  {}] \
    [list "chi_tb_flit_decode" {}] \
    [list "chi_router_tb_top"  {TC_SMOKE}] \
    [list "chi_router_tb_top"  {TC_CONGESTION}] \
    [list "chi_router_tb_top"  {TC_ORDERING}] \
]

set pass_cnt 0
set fail_cnt 0
set fail_list {}

foreach spec $tb_specs {
    set tb      [lindex $spec 0]
    set tb_defs [lindex $spec 1]

    # snapshot 名：系统级 tb 多用例时加宏后缀，避免互相覆盖
    set snap $tb
    if {[llength $tb_defs] > 0} {
        set snap "${tb}_[string tolower [join $tb_defs "_"]]"
    }

    puts ""
    puts "=========================================================="
    puts "\[SIM\] tb = $tb  defines = $tb_defs"
    puts "=========================================================="

    # 清理同名 snapshot
    catch {file delete -force "./xsim.dir/${snap}_behav"}

    # ---- xelab ----
    set xelab_cmd [list xelab --incr --debug typical --relax --mt 2 -cov all \
        -L work -L unisims_ver -L unimacro_ver -L secureip \
        --snapshot ${snap}_behav]
    foreach d $tb_defs { lappend xelab_cmd -d $d }
    lappend xelab_cmd work.$tb work.glbl

    puts "\[INFO\] 执行: $xelab_cmd"
    if {[catch {exec {*}$xelab_cmd 2>@1} elab_out]} {
        puts "ERROR: $tb xelab 失败："
        puts $elab_out
        lappend fail_list "$tb ($tb_defs) - xelab"
        incr fail_cnt
        continue
    }
    puts "\[INFO\] $tb xelab 完成"

    # ---- xsim ----
    set env(SIM_TB) $snap
    set xsim_cmd [list xsim ${snap}_behav \
        -tclbatch ./scripts/xsim_run.tcl \
        -covdb_dir ./cov_db \
        -log ./reports/${snap}_simulate.log]

    puts "\[INFO\] 执行: $xsim_cmd"
    set sim_err ""
    if {[catch {exec {*}$xsim_cmd 2>@1} sim_out]} {
        set sim_err $sim_out
        puts "WARN: $tb xsim 返回非零：$sim_err"
    }

    # ---- 判定：读日志，识别 SOME TESTS FAILED / [ERROR] ----
    set log_file "./reports/${snap}_simulate.log"
    set verdict "SUCCESS"
    if {[file exists $log_file]} {
        set lf [open $log_file r]
        set content [read $lf]
        close $lf
        if {[string match "*SOME TESTS FAILED*" $content] || [string match "*\[ERROR\]*" $content]} {
            set verdict "FAILED"
        }
    } elseif {$sim_err ne ""} {
        set verdict "FAILED"
    }

    if {$verdict eq "SUCCESS"} {
        puts "\[RESULT\] $tb ($tb_defs) : SUCCESS"
        incr pass_cnt
    } else {
        puts "\[RESULT\] $tb ($tb_defs) : FAILED"
        lappend fail_list "$tb ($tb_defs)"
        incr fail_cnt
    }
}

# -----------------------------------------------------------------------------
# 6. 覆盖率报告汇总
# -----------------------------------------------------------------------------
puts ""
puts "\[INFO\] 汇总覆盖率报告 ..."
catch {
    report_coverage -file ./reports/coverage_report.txt -cov_db_dir ./cov_db
}
if {[file exists ./reports/coverage_report.txt]} {
    puts "\[INFO\] 覆盖率报告: ./reports/coverage_report.txt"
} else {
    puts "\[WARN\] 覆盖率报告生成失败（仅告警，不阻断流程）"
}

# -----------------------------------------------------------------------------
# 7. 收尾汇总
# -----------------------------------------------------------------------------
puts ""
puts "=========================================================="
puts "\[SUMMARY\] PASS = $pass_cnt   FAIL = $fail_cnt"
if {$fail_cnt > 0} {
    puts "\[SUMMARY\] 失败项："
    foreach f $fail_list { puts "           - $f" }
    puts "SOME TESTS FAILED"
} else {
    puts "\[SUMMARY\] ALL TESTS PASSED"
}
puts "=========================================================="

exit 0