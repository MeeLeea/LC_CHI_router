#=============================================================================
# 文件: syn/scripts/syn.tcl
# 功能: DC (Design Compiler) 综合脚本骨架
#=============================================================================

# ---------------- 环境 ----------------
set DESIGN      chi_router_top
set RTL_DIR     ../../rtl
set OUT_DIR     ./out
set RPT_DIR     ./rpt

file mkdir $OUT_DIR
file mkdir $RPT_DIR

# ---------------- 库（按实际工艺替换，TBD） ----------------
# set link_path "* /path/to/stdcell.db /path/to/sram.db"
# set target_library "stdcell.db sram.db"
# set link_library   "* $target_library"

# ---------------- 读入 RTL ----------------
set_app_var search_path [list . $RTL_DIR $RTL_DIR/common $RTL_DIR/ingress \
                              $RTL_DIR/buffer $RTL_DIR/sched $RTL_DIR/xbar \
                              $RTL_DIR/egress $RTL_DIR/csr]
analyze -format sverilog -f $RTL_DIR/filelist.f
elaborate $DESIGN
current_design $DESIGN
link

# ---------------- 约束 ----------------
source ../constraints/chi_router.sdc

# ---------------- 综合 ----------------
# compile_ultra -gate_clock -no_autoungroup

# ---------------- 输出 ----------------
# write -format verilog -hierarchy -output $OUT_DIR/${DESIGN}.v
# write_sdc $OUT_DIR/${DESIGN}.sdc
# report_timing -max_paths 20 > $RPT_DIR/timing.rpt
# report_area -hierarchy     > $RPT_DIR/area.rpt
# report_power               > $RPT_DIR/power.rpt
