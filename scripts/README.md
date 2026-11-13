# scripts/ — CHI Router 仿真脚本说明

> 环境：Vivado Xsim（Windows，PowerShell 或 CMD）
> 工程根：本仓库根目录（含 `rtl/`、`tb/`、`scripts/`）
> 所有命令**必须在工程根目录下执行**（`sim_filelist.f` 内路径相对工程根）

---

## 1. 文件清单

| 文件 | 作用 |
|------|------|
| `scripts/sim_filelist.f` | Xsim 编译清单（`xvlog -f` 专用）。由前端 `rtl/filelist.f` 扩展 TB 文件而来，**仅用于仿真，不回写综合** |
| `scripts/start.tcl` | 全量回归：读 filelist → `xvlog` 编译 → 逐 tb `xelab` + `xsim` → 覆盖率汇总 |
| `scripts/run_one.tcl` | 单 tb 定向回归：复用 `start.tcl` 的已编译工作库，仅重跑 `xelab` + `xsim` |
| `scripts/xsim_run.tcl` | 由 `start.tcl` 自动生成，在 `xsim` 子进程内执行 `coverage save` + `run all` |

---

## 2. 前置条件

1. `vivado` 可执行文件在 `PATH` 中（或使用完整路径 `& "D:\Xilinx\Vivado\2023.2\bin\vivado.bat"`）。
2. 环境变量 `XILINX_VIVADO` 已由 Vivado 启动脚本自动设置（脚本用它定位 `glbl.v`）。若未设置，脚本会显式报错退出。
3. `scripts/sim_filelist.f` 中列出的文件全部存在；缺失时 `start.tcl` 会列出缺失清单并退出（**不会自行编造文件列表**）。

---

## 3. 全量回归（start.tcl）

### PowerShell

```powershell
cd D:\chi_router
& vivado -mode batch -source scripts/start.tcl
```

### CMD

```cmd
cd /d D:\chi_router
vivado -mode batch -source scripts\start.tcl
```

### 执行流程

1. `file mkdir ./reports ./cov_db ./sim.dir`
2. 读 `scripts/sim_filelist.f`，过滤 `#` 注释与空行
3. 逐文件 `file exists` 核验；缺失则打印清单并 `exit 1`
4. 清理 `./xsim.dir/*_behav` 旧 snapshot（规避 Windows 文件锁）
5. `exec xvlog -sv --incr --relax --nolog -f scripts/sim_filelist.f`
6. `exec xvlog -v ... $env(XILINX_VIVADO)/data/verilog/src/glbl.v`
7. 生成 `scripts/xsim_run.tcl`
8. 逐 tb：`exec xelab ... --snapshot <snap>_behav work.<tb> work.glbl`
9. 逐 tb：`exec xsim <snap>_behav -tclbatch ./scripts/xsim_run.tcl -covdb_dir ./cov_db -log ./reports/<snap>_simulate.log`
10. 读日志判定：含 `SOME TESTS FAILED` 或 `[ERROR]` → FAILED
11. `report_coverage -file ./reports/coverage_report.txt -cov_db_dir ./cov_db`（`catch` 包裹，失败仅告警）

### 产物

| 路径 | 内容 |
|------|------|
| `./reports/<snap>_simulate.log` | 每个 tb 的仿真日志 |
| `./reports/coverage_report.txt` | 覆盖率汇总报告 |
| `./cov_db/<snap>_coverage.ucdb` | 每个 tb 独立的覆盖率数据库 |
| `./xsim.dir/<snap>_behav/` | xelab snapshot |

---

## 4. 单 tb 定向回归（run_one.tcl）

### 用法

```
vivado -mode batch -source scripts/run_one.tcl -tclargs <tb_name> [<define>]
```

* `<tb_name>`（必填，缺省为 `chi_tb_rr_arbiter`）：testbench 顶层模块名
* `<define>`（选填）：用例宏，仅 `chi_router_tb_top` 需要

### 示例

```powershell
# 模块级：RR 仲裁器
& vivado -mode batch -source scripts/run_one.tcl -tclargs chi_tb_rr_arbiter

# 模块级：parity 校验
& vivado -mode batch -source scripts/run_one.tcl -tclargs chi_tb_parity_check

# 模块级：2FF 同步器（跨时钟域）
& vivado -mode batch -source scripts/run_one.tcl -tclargs chi_tb_sync_2ff

# 模块级：pool credit
& vivado -mode batch -source scripts/run_one.tcl -tclargs chi_tb_pool_credit

# 模块级：tail_lock 尾锁
& vivado -mode batch -source scripts/run_one.tcl -tclargs chi_tb_tail_lock

# 模块级：credit_mgr
& vivado -mode batch -source scripts/run_one.tcl -tclargs chi_tb_credit_mgr

# 模块级：flit_decode
& vivado -mode batch -source scripts/run_one.tcl -tclargs chi_tb_flit_decode

# 系统级：冒烟用例
& vivado -mode batch -source scripts/run_one.tcl -tclargs chi_router_tb_top TC_SMOKE

# 系统级：拥塞用例
& vivado -mode batch -source scripts/run_one.tcl -tclargs chi_router_tb_top TC_CONGESTION

# 系统级：保序用例
& vivado -mode batch -source scripts/run_one.tcl -tclargs chi_router_tb_top TC_ORDERING
```

### 全部可用 tb 名列表

| # | tb 名 | 需 `<define>` | 说明 |
|---|-------|---------------|------|
| 1 | `chi_tb_rr_arbiter` | 否 | RR 仲裁轮转公平性、单/全请求、复位 |
| 2 | `chi_tb_parity_check` | 否 | parity 校验、错误注入、valid=0 |
| 3 | `chi_tb_sync_2ff` | 否 | 单 bit / 准静态总线同步、复位错位、CDC 相位 |
| 4 | `chi_tb_pool_credit` | 否 | credit 分配/回补/耗尽/并行独立 |
| 5 | `chi_tb_tail_lock` | 否 | 尾锁锁定/解锁/末 beat/边界 qid |
| 6 | `chi_tb_credit_mgr` | 否 | 发送/回补/耗尽/下溢观察/并行通道 |
| 7 | `chi_tb_flit_decode` | 否 | 字段提取、Opcode 子集、边界值 |
| 8 | `chi_router_tb_top` | **是** | 系统级；`TC_SMOKE` / `TC_CONGESTION` / `TC_ORDERING` |

### 注意

* `run_one.tcl` **不创建/打开 Vivado 工程**，直接复用 `xsim.dir` 工作库。
* 必须先跑过一次 `start.tcl`（否则 `xsim.dir` 不存在，脚本会报错退出）。
* 若修改了 TB/RTL 源码，需重跑 `start.tcl` 重新编译，再跑 `run_one.tcl`。
* 系统级 tb 的 snapshot 名带宏后缀（如 `chi_router_tb_top_tc_smoke_behav`），与 `start.tcl` 产物一致。

---

## 5. 常用调试命令

### 查看仿真日志（日志可能很长，建议按文件读）

```powershell
Get-Content .\reports\chi_tb_rr_arbiter_simulate.log -Tail 60
```

### 搜索失败关键字

```powershell
Select-String -Path .\reports\*.log -Pattern "SOME TESTS FAILED","\[ERROR\]","\[ASSERT\]"
```

### 清理残留 xsim 进程（snapshot 链接失败时）

```powershell
Get-Process xsim -ErrorAction SilentlyContinue | Stop-Process -Force
```

### 清理旧 snapshot（Windows 文件锁）

```powershell
Remove-Item -Recurse -Force .\xsim.dir\*_behav -ErrorAction SilentlyContinue
```

### 清空覆盖率库

```powershell
Remove-Item -Recurse -Force .\cov_db\* -ErrorAction SilentlyContinue
```

---

## 6. 耗时预期

| 场景 | 预计耗时 |
|------|----------|
| `start.tcl` 全量（1 次 xvlog + 10 次 xelab/xsim） | 5–15 分钟 |
| `run_one.tcl` 单模块级 tb | 1–3 分钟 |
| `run_one.tcl` 系统级 tb | 2–5 分钟 |

Vivado 批处理编译 + 仿真 3–10 分钟属正常，非卡死。

---

## 7. 故障排查

| 现象 | 原因 | 处理 |
|------|------|------|
| `ERROR: 找不到 ./scripts/sim_filelist.f` | 清单缺失 | 请前端补齐，脚本不编造文件列表 |
| `ERROR: 以下文件在 sim_filelist.f 中列出但磁盘不存在` | 文件缺失 | 按清单补齐对应文件 |
| `ERROR: 环境变量 XILINX_VIVADO 未设置` | 未通过 Vivado 启动 | 使用 `vivado -mode batch` 启动，勿直接调 `xvlog` |
| `ld.exe: Permission denied` | snapshot 被占用 | 清理 `xsim.dir/*_behav`，并杀掉残留 `xsim` 进程 |
| `ERROR: 未找到 ./xsim.dir` | 未先编译 | 先跑 `start.tcl` |
| `HDL 9-1206` 语法错误 | 标识符与 SV 保留字冲突 | 检查 covergroup bins/cross 名，改用前后缀规避 |
| `xelab` 报 `work.<tb>` 找不到 | 该 tb 未在 `sim_filelist.f` 中 | 将 tb 文件加入清单 |