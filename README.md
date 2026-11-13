# CHI 路由器 RTL 工程

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

## 回归状态（2026-11-13）

全量回归 10/10 PASS（7 个模块级 tb + 3 个系统级用例），日志见 `reports/*_simulate.log`，覆盖率 ucdb 落在 `cov_db/`。

- 判定规则：日志含 `SOME TESTS FAILED` 或 `[ERROR]` 即判 FAILED，由 `start.tcl` / `run_one.tcl` 自动扫描。
- 遗留告警（非阻断）：`report_coverage` 汇总在 vivado batch 下不可用，ucdb 已按 tb 分文件正常落盘。

### 骨架阶段 RTL 契约

`rtl/chi_router_top.sv` 子系统尚未接线，当前为骨架 tie-off：

- 出口链路 `link_out_valid/req/rsp/dat/snp = 0`（无出口活动，报告 D-01）
- 入口 `link_in_ready = 1`（恒接收：系统级 TB 的 agent 发送任务需完成握手，否则激励超时）
- APB 读立即完成、返回 0、无 `pslverr`；CSR 无实际寄存器

子系统接线后删除该 tie-off 段。
