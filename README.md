# This is a introduce about this project

## CHI 路由器 RTL 工程

目录结构：

- `rtl/` — 设计源码
- `tb/` — testbench
- `sim/` — 仿真 filelist 与用例
- `syn/` — 综合脚本与约束
- `scripts/` — 流程脚本

## 仿真运行方式（Vivado Xsim）

```powershell
# 1. 配置环境（每次新开 PowerShell 会话执行一次）
. .\scripts\env.ps1

# 2. 全量回归（编译 + 全部 tb）
vivado -mode batch -source scripts/start.tcl

# 3. 单 testbench 定向回归
vivado -mode batch -source scripts/run_one.tcl -tclargs chi_tb_rr_arbiter
vivado -mode batch -source scripts/run_one.tcl -tclargs chi_router_tb_top TC_SMOKE
```

Vivado 安装路径：`D:\AMDTools\2025.2\Vivado`（由 `scripts/env.ps1` 配置，路径变更时修改该文件）。
