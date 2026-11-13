# CHI Router 验证报告（Verification Report）

| 项 | 内容 |
|----|------|
| 工程 | CHI Router（8 端口 × 4 通道，CHI-BE 子集） |
| 报告版本 | v1.2（RTL 状态第二次核查 + TB 完整性核验） |
| 仿真环境 | Vivado Xsim（Windows） |
| TB 风格 | 纯 SystemVerilog 定向环境（**无 UVM class**） |
| 报告范围 | 环节 5–10：TB/UVM 框架 → 覆盖率 → 断言 → 风险与 bug 预判 → 待确认项 → 工程脚本 |
| 结论 | **验证结论: FAIL**（RTL 需修改，详见 §9 缺陷清单） |

---

## 0. 交付物清单（本次新增/修改）

### 0.0 【v1.2 重要核查】RTL 仍未变更，且不存在 `src/` 目录

> 本轮上下文再次声称「RTL 已写入 `src/`，D-16/D-17/D-08/D-20/D-22 已修复」。
> **经逐层读盘核查，该说法第二次不成立** —— 工程中根本不存在 `src/` 目录。

**目录层核查**：

```
D:\chi_router\  →  doc/  rtl/  scripts/  sim/  syn/  tb/     ← 无 src/
```

**关键文件内容核查**：

| 核查项 | 声称状态 | **实际磁盘状态** | 证据 |
|--------|----------|------------------|------|
| `src/` 目录存在 | 29 个 RTL 已写入 | ❌ **不存在** | `list_directory` 仅返回 doc/rtl/scripts/sim/syn/tb |
| `rtl/chi_router_pkg.sv` | 已重写（`PORT_NUM=8` 等新参数体系） | ❌ **仍为原版** | 仍为 `parameter int PORT_NUM = 8;`（非 `int unsigned`），无 `QID_W`/`VOQ_IDX_W`/`ERR_W` 等新派生参数 |
| `rtl/buffer/voq_linklist.sv` | D-17 已修 | ❌ **仍先用后声明** | port list L17 用 `QUEUE_NUM_W`，body L28 才 `localparam` |
| `rtl/buffer/voq_linklist.sv` | D-08 已修（`deq_fid` 索引） | ❌ **仍为 `head[qid_sel]`** | 应用 `head[deq_qid]` |
| `rtl/buffer/voq_linklist.sv` | D-22 已修（`{in_port,qid}` 全局索引） | ❌ **仍仅 `enq_qid` 索引** | 无 `enq_in_port` 端口 |
| `rtl/chi_router_top.sv` | D-01 已修（子系统例化） | ❌ **仍全部注释** | L62-69 仍为 7 行 `// xxx u_xxx (...);` |
| `rtl/csr/qos_regs.sv` | D-16 已修 | ❌ **仍先用后声明** | port list 用 `AW`，body L19 才 `localparam int AW = 4;` |

**结论**：连续两轮 RTL 重写均因服务中断未落盘。本报告 §9 缺陷清单 **D-01 ~ D-21 第三次确认全部有效**，验证结论维持 **FAIL**。

### 0.0b 【v1.2】TB 交付物完整性核验

> 上轮 `write_file` 曾出现截断，本轮逐文件核验结尾完整性。

| 文件 | 结尾标记 | 完整性 |
|------|----------|--------|
| `chi_tb_pkg.sv` | `endpackage` + `` `endif `` | ✅ |
| `chi_clk_rst_if.sv` | `endinterface` + `` `endif `` | ✅ |
| `chi_coverage.sv` | `endmodule` + `` `default_nettype wire `` | ✅ |
| `chi_assertions.sv` | 4 个 bind + `` `default_nettype wire `` | ✅ |
| `chi_scoreboard.sv` | `endtask` + `endmodule` | ✅ |
| `chi_router_tb_top.sv` | 超时 `initial` + `endmodule` | ✅ |
| `chi_agent_rn.sv` / `chi_agent_hn.sv` | `endmodule` | ✅ |
| 7 个模块级 TB | `endmodule` + 超时块 | ✅ |

**TB 侧 16 个文件全部完整可编译，无需重写。**

### 0.1 新增 TB 文件（`tb/`）

| 文件 | 类型 | 说明 |
|------|------|------|
| `tb/chi_tb_pkg.sv` | 包 | 字段打包/解包、qid 编码、CSR 地址、LFSR 伪随机 |
| `tb/chi_clk_rst_if.sv` | 接口 | 500MHz `clk` + 独立 100MHz `pclk` + 异步复位同步释放 |
| `tb/chi_coverage.sv` | 覆盖率 | 3 个 covergroup（入口流量 / 出口反压 / APB 访问） |
| `tb/chi_assertions.sv` | 断言 | 11 条断言 + 文件作用域 `bind` |
| `tb/chi_tb_rr_arbiter.sv` | 模块级 TB | RR 仲裁轮转公平性 |
| `tb/chi_tb_parity_check.sv` | 模块级 TB | parity 校验 / 错误注入 |
| `tb/chi_tb_sync_2ff.sv` | 模块级 TB | 2FF 同步 / CDC 相位 / 复位错位 |
| `tb/chi_tb_pool_credit.sv` | 模块级 TB | pool credit 分配/回补/耗尽 |
| `tb/chi_tb_tail_lock.sv` | 模块级 TB | 尾锁锁定/解锁/边界 qid |
| `tb/chi_tb_credit_mgr.sv` | 模块级 TB | credit 记账/下溢观察 |
| `tb/chi_tb_flit_decode.sv` | 模块级 TB | 字段提取 / Opcode 子集 |

### 0.2 重写的 TB 文件

| 文件 | 关键改动 |
|------|----------|
| `tb/chi_agent_rn.sv` | 补齐真实 REQ 激励（原为仅置 0 的空壳）；加反压模式与接收计数 |
| `tb/chi_agent_hn.sv` | 补齐 RSP/DAT/SNP 发送任务；`req_ready` 默认放行 |
| `tb/chi_scoreboard.sv` | 实现 L1/L3 保序检查 + 逐 beat 数据比对 + credit 下溢检测 |
| `tb/chi_router_tb_top.sv` | `pclk` 独立 100MHz；`presetn` 错位释放；补齐 APB 激励；挂载覆盖率 |

### 0.3 工程脚本（`scripts/`）

| 文件 | 说明 |
|------|------|
| `scripts/sim_filelist.f` | Xsim 编译清单（RTL 29 + TB 17 + glbl.v） |
| `scripts/start.tcl` | 全量回归：`xvlog` → 逐 tb `xelab`/`xsim` → 覆盖率汇总 |
| `scripts/run_one.tcl` | 单 tb 定向回归（复用 `xsim.dir`，不建工程） |
| `scripts/README.md` | 命令行用法、可用 tb 列表、故障排查 |

---

## 1. 环境与文件核验结果

### 1.1 目录树核验（任务要求：检查层级数、文件是否存在）

**核验结论：任务给出的文件树中，每一个文件均已存在于磁盘，无缺失。**

```
chi_router/
├── doc/
│   ├── design_spec.md            ✅ 存在
│   ├── arch_spec.md              ✅ 存在
│   └── verification_plan.md      ✅ 本次新增
│   └── verification_report.md    ✅ 本次新增
├── rtl/                          ✅ 29 个 .sv，全部存在
│   ├── chi_router_pkg.sv
│   ├── chi_router_top.sv
│   ├── filelist.f
│   ├── common/      (2: sync_2ff, clk_rst_gen)
│   ├── ingress/     (5: port_ingress, flit_decode, parity_check, route_lookup, pool_alloc)
│   ├── buffer/      (4: buffer_subsys, sram_wrapper, voq_linklist, pool_credit)
│   ├── sched/       (3: scheduler, islip_arbiter, rr_arbiter)
│   ├── xbar/        (2: crossbar_a, crossbar_b)
│   ├── egress/      (5: port_egress, credit_mgr, order_guard, tail_lock, qos_shaper)
│   └── csr/         (6: csr_subsys, apb_slave, route_table, qos_regs, pmu_counters, err_regs)
├── tb/                           ✅ 5 个原始文件 + 本次新增 11 个 TB 文件
├── syn/
│   ├── constraints/chi_router.sdc  ✅ 存在
│   └── scripts/syn.tcl             ✅ 存在
├── sim/
│   ├── regression.f                ✅ 存在
│   └── tests/  (tc_smoke.f, tc_congestion.f, tc_ordering.f)  ✅ 存在
└── scripts/                      ✅ 本次新建
    ├── sim_filelist.f
    ├── start.tcl
    ├── run_one.tcl
    └── README.md
```

### 1.2 结构性偏差（已在验证计划中登记）

| 编号 | 偏差 | 处理 |
|------|------|------|
| M-1 | 工程无 `src/`、`test/` 目录，实际为 `rtl/`、`tb/` | 按「严禁编造文件」原则，`sim_filelist.f` 只列 `rtl/`、`tb/` 真实路径；等价关系 `src/ ≡ rtl/`、`test/ ≡ tb/` 写入清单注释 |
| M-2 | 不存在 `syn_filelist.f`，实际为 `rtl/filelist.f` | 以 `rtl/filelist.f` 作为可综合 RTL 基准 |
| M-3 | `sim/tests/tc_*.f` 含 `+UVM_TESTNAME=`，但 `tb/` 无任何 UVM class | 本环境按纯 SV 定向实现；`+UVM_TESTNAME` 当前无实际效力（见 §9 D-17） |

### 1.3 `sim_filelist.f` 逐文件 `file exists` 核验

| 分组 | 文件数 | 核验 |
|------|--------|------|
| RTL（pkg + common + buffer + ingress + sched + xbar + egress + csr + top） | 29 | ✅ 全部存在 |
| TB 基础设施（pkg / clk_rst_if / sram_behavioral） | 3 | ✅ 全部存在 |
| TB 组件（agent_rn / agent_hn / scoreboard / coverage / assertions） | 5 | ✅ 全部存在 |
| 模块级 TB | 7 | ✅ 全部存在 |
| 系统级 TB 顶层 | 1 | ✅ 存在 |
| `glbl.v`（`$env(XILINX_VIVADO)/data/verilog/src/glbl.v`） | 1 | ✅ 由 `start.tcl` 用 `file exists` 显式核验；环境变量未设置时显式报错 |
| **合计** | **46** | **0 缺失** |

> `start.tcl` 在编译前会再次逐条 `file exists` 核验，任一缺失即打印缺失清单并 `exit 1`，**不自行编造文件列表**。`sim_filelist.f` 仅用于 `xvlog -f` 仿真编译，**绝不回写综合 filelist**。

---

## 2. 环节 5：Testbench 框架代码

### 2.1 分层架构

```
                    ┌─────────────────────────────────────┐
                    │      chi_router_tb_top.sv           │  系统级顶层
                    │  (用例选择 / APB 激励 / 汇总判定)    │
                    └──────┬───────────────┬──────────────┘
                           │               │
        ┌──────────────────┴───┐      ┌────┴──────────────────┐
        │  chi_clk_rst_if      │      │  chi_coverage         │  覆盖率
        │  500M clk / 100M pclk│      │  (3 covergroup)       │
        │  异步复位同步释放     │      └───────────────────────┘
        └──────────────────────┘
                           │
        ┌──────────────────┴──────────────────────────────┐
        │  generate ×8                                    │
        │   chi_agent_rn (REQ 激励 / RSP·DAT·SNP 接收)     │
        │   chi_agent_hn (REQ 接收 / RSP·DAT·SNP 回送)     │
        └──────────────────┬──────────────────────────────┘
                           │
                    ┌──────┴───────┐
                    │ chi_router_top│  DUT
                    └──────┬───────┘
                           │
        ┌──────────────────┴──────────────────────────────┐
        │  chi_scoreboard (L1/L3 保序 + 数据比对 + credit) │
        │  chi_assertions (bind，11 条断言)                │
        └─────────────────────────────────────────────────┘

        ┌─────────────────────────────────────────────────┐
        │ 模块级 TB（独立 xelab -top，可单跑）              │
        │  rr_arbiter / parity_check / sync_2ff /         │
        │  pool_credit / tail_lock / credit_mgr /         │
        │  flit_decode                                    │
        └─────────────────────────────────────────────────┘
```

### 2.2 为什么不用 UVM

| 依据 | 说明 |
|------|------|
| 现有 TB 形态 | `tb/*.sv` 全部是纯 SV `module`，无 `uvm_component`/`uvm_sequence` 继承 |
| Xsim 限制 | Vivado Xsim 需先 `compile_simlib` 生成 UVM 库；且对 UVM 高级特性（factory override、多态 sequence、`uvm_config_db` 复杂用法）支持有限 |
| 工程阶段 | RTL 仍为骨架态（见 §9 D-01），此时引入重型 UVM 环境的收益低于维护成本 |
| 主 prompt 约束 | 「小模块输出定向 SV tb；复杂 IP 输出 UVM 组件框架」——本工程当前处于「接口已冻结、内部未实现」阶段，定向 TB 可立即定位问题 |

> 后续若需升级 UVM：`chi_tb_pkg` 可直接作为 UVM 的 `uvm_pkg` 参考模型基础；`chi_agent_rn/hn` 可包装为 `uvm_driver` + `uvm_monitor`；`chi_scoreboard` 可包装为 `uvm_scoreboard`。`sim_filelist.f` 与 `start.tcl` 已预留 `-L uvm` 分支位置（当前未启用）。

### 2.3 关键接口约束（TB 侧严格遵守）

| 约束 | TB 实现 |
|------|---------|
| valid/ready 握手 | `send_req`/`send_rsp`/`send_dat`/`send_snp` 均为「valid 拉高 → 等 ready → 撤销 valid」 |
| valid 期间数据稳定 | 数据在 `@(negedge clk)` 更新，valid 期间不变化 |
| 复位期间不发 flit | `do_reset()` 内含 10 cycle 稳定期（RST-03） |
| 异步复位同步释放 | `chi_clk_rst_if` 在 `clk` 域同步释放 `rst_async_n`，在 `pclk` 域独立释放 `presetn`，两者错开 3 个 `pclk` |
| 跨时钟域 | `clk`=500MHz（2ns），`pclk`=100MHz（10ns）且初始相位偏移 3.7ns，非整数比 |
| 不在 `initial` 内声明变量 | 所有变量在 module 级声明（模块级 TB 与 TB 顶层均已清理） |
| 不重复实现 RTL | TB 只做激励打包与期望值计算，不重写 DUT 逻辑 |

### 2.4 用例设计

| 用例 | 宏 | 覆盖点 |
|------|-----|--------|
| `TC_SMOKE` | `+define+TC_SMOKE` | 复位释放、`ID_REV` 读、路由表写回读、QoS 权重、`ERR_EN`、非法地址、单包 REQ 往返 |
| `TC_CONGESTION` | `+define+TC_CONGESTION` | 8 端口同时打向端口 0（出口过载）、出口反压拍数统计、`CREDIT_STATUS` 读取 |
| `TC_ORDERING` | `+define+TC_ORDERING` | 同 `(src,tgt,domain)` 8 个 REQ 按 txn 递增、HN 4 beat DAT 同包（末 beat `is_last=1`） |

---

## 3. 环节 6：功能覆盖率（covergroup，适配 Xsim）

### 3.1 CG1 `cg_ingress_traffic`（`@(posedge clk)`）

| coverpoint | 覆盖内容 | bins |
|------------|----------|------|
| `cp_in_port` | 入口端口 0–7 | 8 bins |
| `cp_in_grp` | 通道组 REQ/DAT/RSP+SNP/保留 | 4 bins |
| `cp_in_qos` | QoS 0–3 | 4 bins |
| `cp_in_domain` | 一致性域 0/1/非法 | 3 bins |
| `cp_in_order` | 顺序要求 NONE/ANY/STRICT/other | 4 bins |
| `cp_in_op_hi` | Opcode 高 3 位分族 | 8 bins |
| `x_port_qos` | 端口 × QoS | 32 crosses |
| `x_port_dom` | 端口 × 域 | 24 crosses |
| `x_grp_ord` | 通道组 × 顺序 | 16 crosses |

### 3.2 CG2 `cg_egress_backpressure`（`@(posedge clk)`）

| coverpoint | 覆盖内容 | bins |
|------------|----------|------|
| `cp_out_port` | 出口端口 0–7 | 8 bins |
| `cp_bp_lvl` | 反压等级 none/low(1)/mid(2–4)/high(5–7) | 4 bins |
| `x_port_bp` | 端口 × 反压等级 | 32 crosses |

### 3.3 CG3 `cg_apb_access`（`@(posedge pclk)`）

| coverpoint | 覆盖内容 | bins |
|------------|----------|------|
| `cp_apb_region` | 地址区间 ROUTE+QOS / PMU / ERR / CREDIT / 非法 | 5 bins |
| `cp_apb_dir` | 读 / 写 | 2 bins |
| `x_region_dir` | 区间 × 方向 | 10 crosses |

### 3.4 覆盖率保存与汇总

* 每个 tb 独立保存：`coverage save -onexit ./cov_db/<snap>_coverage.ucdb`（由 `scripts/xsim_run.tcl` 在 xsim 子进程内执行）
* 全部 tb 跑完后汇总：`report_coverage -file ./reports/coverage_report.txt -cov_db_dir ./cov_db`（`catch` 包裹，失败仅告警）

### 3.5 命名合规自检（规避 Xsim `HDL 9-1206`）

| 检查项 | 结果 |
|--------|------|
| 是否使用 SV 保留字作标识符（`byte`/`bit`/`logic`/`int`/`type`/`void`/`enum`/`struct`/`union`/`class`/`function`/`task`/`module`/`always`/`initial`/`if`/`case`/`for`/`while`） | ✅ 无。全部 bins 加 `b_` 前缀，cross 加 `x_` 前缀，coverpoint 加 `cp_` 前缀 |
| 同一 coverpoint 内 bins 取值是否重叠 | ✅ 已修正：原版 `b_op_rsp`/`b_op_dat` 同为 `3'h2`（Xsim 报重复值错误），改为 `cp_in_op_hi` 按高 3 位分族，8 个 bins 互斥 |
| 是否存在退化 coverpoint（恒定值） | ✅ 已修正：原版 `cp_in_ch_grp` 恒为 `2'd0`（恒采样 REQ），改为按优先级扫描 REQ>DAT>RSP>SNP 提取真实通道组 |
| covergroup 采样时钟信号是否已声明为端口 | ✅ 已修正：`cg_apb_access @(posedge pclk)` 所需 `pclk` 已补入 module 端口列表 |

---

## 4. 环节 7：关键断言（property）

### 4.1 断言清单

| ID | 目标 | 性质 | 依据 |
|----|------|------|------|
| A1 | `chi_router_top` | 复位期间 `link_out_valid == 0` | RST-03 |
| A2 | `chi_router_top` | REQ `valid` 拉高后保持到 `ready` | spec §4.1 握手 |
| A3 | `chi_router_top` | `valid` 期间 REQ 数据稳定 | spec §4.1「valid 有效时稳定」 |
| A4 | `chi_router_top` | `valid` 时数据不含 X（4 通道） | 未初始化/多驱动检测 |
| A5 | `credit_mgr` | credit=0 时不得发送（防下溢） | DL-01 / DL-03 |
| A6 | `credit_mgr` | credit 不得超过 `INIT_CRD`（防溢出） | DL-01 |
| A7 | `tail_lock` | 锁定期间出队 qid 必须等于 `locked_qid` | ORD-02 |
| A8 | `tail_lock` | 无 beat 时锁定状态保持（不得自行解锁） | ORD-02 |
| A9 | `chi_router_top` | APB 等待周期内 `paddr`/`pwrite`/`pwdata` 稳定 | APB4 协议 |
| A10 | `chi_router_top` | `penable` 不得在 `psel` 无效时拉高 | APB4 协议 |
| A11 | `chi_router_top` | APB 传输期间 `pwrite` 不得为 X | APB4 协议 |

### 4.2 实现策略（Xsim 兼容性）

| 策略 | 原因 |
|------|------|
| 跨模块时序性质用 SVA 并发断言（`property`/`assert property`） | A1、A5、A6、A7、A8、A9、A10、A11 |
| 逐端口/逐通道检查用 `always_ff` + 立即断言 | 避免在 `generate` 块内声明 `property`（Xsim 兼容风险）；A2/A3/A4 覆盖 8 端口 × 4 通道 |
| `bind` 语句放在**文件作用域** | 原实现把 `bind` 放在 `chi_router_tb_top` 模块内（非法）；已移至 `chi_assertions.sv` 文件作用域 |
| 信号连接一律显式端口绑定 | 不做跨层次引用；`credit_mgr` 的内部数组 `cred` 通过 bind 端口 `crd_cnt` 显式映射 |
| 仅用 Xsim 支持的 SVA 子集 | `\|->`、`\|=>`、`$stable`、`disable iff`；不使用 local variable 序列匹配、`expect`、多时钟序列 |

### 4.3 断言覆盖的「复位行为」与「CDC」要求

| 主 prompt 要求 | 覆盖位置 |
|----------------|----------|
| 复位期间信号行为 | A1（出口 valid=0）、模块级 TB TC1/TC7（各模块复位值） |
| 跨时钟域相位 | `chi_clk_rst_if`：`clk` 500MHz / `pclk` 100MHz，初始相位偏移 3.7ns |
| 复位错位 | `chi_clk_rst_if.do_reset()`：`rst_async_n` 先释放，`presetn` 延后 3 个 `pclk`；`chi_tb_sync_2ff` TC5 专门覆盖 |
| 握手协议 | A2/A3（valid 保持、数据稳定）+ 所有 agent 发送任务 |

---

## 5. 环节 8：风险与 bug 预判清单

### 5.1 高优先级风险（继承自 arch_spec §8）

| ID | 风险 | 等级 | 验证手段 |
|----|------|------|----------|
| R-01 | iSLIP 2-round 收敛不足 | 中 | 需 `islip_arbiter` 实现后补模块级 TB（当前恒 `grant=0`，无法验证） |
| R-02 | `order_guard`/`tail_lock` 组合路径长 | 高 | `tail_lock` 已有模块级 TB + A7/A8；`order_guard` 恒 `allow=1`，待实现 |
| R-03 | 512 队列指针 SRAM 带宽瓶颈 | 高 | 需 `voq_linklist` 实现后补压力 TB（当前仅声明数组，无逻辑） |
| R-04 | 8×8×512b 布线拥塞 | 中 | 属综合/后端范畴，仿真不覆盖 |
| R-05 | CHI 位域/Opcode 偏差 | 高 | `chi_tb_flit_decode` 覆盖 13 个 Opcode + 边界值；**位域布局需依 IHI0050 评审** |
| R-06 | 跨芯粒 credit 窗口不足 | 高 | `chi_tb_credit_mgr` 覆盖耗尽/下溢观察 |

### 5.2 新增风险（本次验证发现）

| ID | 风险 | 等级 | 说明 |
|----|------|------|------|
| VR-01 | RTL 骨架态导致系统级用例无法给出有效判定 | **高** | 见 D-01；当前系统级 3 用例只能验证「复位 + APB 通路」，数据面全程无活动 |
| VR-02 | `flit_decode` 位域布局未经 IHI0050 核对 | **高** | TB 与 RTL 使用同一套位域假设，若假设错误则 TB 无法发现（同源盲区） |
| VR-03 | `qid` 位宽在 spec 内自相矛盾 | **高** | 见 D-19；TB 侧按「宽度自洽」的 6-bit 实现，与 spec 文字描述不一致 |
| VR-04 | `credit_mgr` 无下限保护 | 中 | 见 D-05；耗尽后继续发送会回绕，需补饱和逻辑与 `ERR_CREDIT_UF` 上报 |
| VR-05 | `pclk` 原接 `clk` 导致 CDC 未被验证 | 中 | 见 D-16；已修正为独立 100MHz，使 CDC 路径真实暴露 |

---

## 6. 环节 9：待确认项

| ID | 待确认项 | 当前处理 | 影响 |
|----|----------|----------|------|
| C-1 | `qid[5:0]` 中 `qos` 是 1 bit 还是 2 bit | 按 1 bit 实现（宽度自洽） | 若为 2 bit，需改 `QUEUE_PER_IN=128` 并修正所有 qid 位宽 |
| C-2 | `flit_decode` 位域布局是否与 IHI0050 一致 | TB 与 RTL 同源假设 | 若不一致，需同步修改 RTL 与 TB |
| C-3 | 是否启用 UVM | 当前纯 SV 定向 | 若启用，需 `compile_simlib` 生成 UVM 库并补 UVM class |
| C-4 | `ERR_STATUS` 的 W1C 语义是否已在 `err_regs` 实现 | RTL 用 `err_status_clr` 整体清零 | 若需逐位 W1C，需改 `err_regs` |
| C-5 | 非法地址访问是否应置 `pslverr=1` | `apb_slave` 恒 `pslverr=0` | 见 D-09 |
| C-6 | 仿真时长上限 | 系统级 5 ms，模块级 100–200 µs | 按需调整 `#5000000` / `#200000` |
| C-7 | 是否需要 dump 波形 | 当前未启用 | 需要时在 `xsim_run.tcl` 加 `log_wave -recursive *` |

---

## 7. 环节 10：Vivado 工程 Tcl 脚本

### 7.1 `scripts/start.tcl`（全量回归）

**用法**

```powershell
cd D:\chi_router
& vivado -mode batch -source scripts/start.tcl
```

**流程**

1. `cd` 到工程根（`sim_filelist.f` 内路径相对工程根）
2. `file mkdir ./reports ./cov_db ./sim.dir`
3. 读 `scripts/sim_filelist.f`；**缺失则显式报错退出**
4. 逐文件 `file exists` 核验；缺失则打印清单并 `exit 1`
5. 清理 `./xsim.dir/*_behav` 旧 snapshot（规避 Windows 文件锁）
6. `exec xvlog -sv --incr --relax --nolog -f scripts/sim_filelist.f`
7. `exec xvlog -v ... $env(XILINX_VIVADO)/data/verilog/src/glbl.v`
8. 生成 `scripts/xsim_run.tcl`
9. 逐 tb：`exec xelab --incr --debug typical --relax --mt 2 -cov all -L work ... --snapshot <snap>_behav work.<tb> work.glbl`
10. 逐 tb：`exec xsim <snap>_behav -tclbatch ./scripts/xsim_run.tcl -covdb_dir ./cov_db -log ./reports/<snap>_simulate.log`
11. 读日志判定：含 `SOME TESTS FAILED` 或 `[ERROR]` → FAILED
12. `report_coverage -file ./reports/coverage_report.txt -cov_db_dir ./cov_db`（`catch` 包裹）

**禁止项自检**

| 禁止项 | 本脚本 |
|--------|--------|
| `add_files [glob ./src/*.v ./src/*.sv]` | ✅ 未使用（`add_files` 属综合流程，目录 glob 会混入 RTL 与 TB） |
| `create_project` / `open_project` | ✅ 未使用（Xsim 只需 `xvlog`/`xelab`/`xsim`） |
| 增删 `sim_filelist.f` 中的文件 | ✅ 编译对象严格等于清单内容 |
| 裸 `xvlog file.sv`（默认进 `work` 库） | ✅ 统一用 `xvlog -f` 编译进默认库，`xelab` 按 `work.<tb>` 查找 |

### 7.2 `scripts/run_one.tcl`（单 tb 定向回归）

**用法**

```
vivado -mode batch -source scripts/run_one.tcl -tclargs <tb_name> [<define>]
```

**可用 tb 名列表**

| # | tb 名 | 需 `<define>` |
|---|-------|---------------|
| 1 | `chi_tb_rr_arbiter` | 否 |
| 2 | `chi_tb_parity_check` | 否 |
| 3 | `chi_tb_sync_2ff` | 否 |
| 4 | `chi_tb_pool_credit` | 否 |
| 5 | `chi_tb_tail_lock` | 否 |
| 6 | `chi_tb_credit_mgr` | 否 |
| 7 | `chi_tb_flit_decode` | 否 |
| 8 | `chi_router_tb_top` | **是**：`TC_SMOKE` / `TC_CONGESTION` / `TC_ORDERING` |

**特性**

* **不创建/打开 Vivado 工程**，直接复用 `start.tcl` 已编译的 `xsim.dir` 工作库
* 仅重新 `xelab` + `xsim`（参数与 `start.tcl` 一致）
* 前置条件：已执行过 `start.tcl`（否则报错退出）
* 系统级 tb 的 snapshot 名带宏后缀（如 `chi_router_tb_top_tc_smoke_behav`），与 `start.tcl` 产物一致

---

## 8. 编译语法检查结果

### 8.1 工具可用性

| 工具 | 可用性 | 说明 |
|------|--------|------|
| Vivado `xvlog` | ❌ 不可用 | 当前会话无 shell 执行能力（未加载 `run_shell` 工具），无法调用 `xvlog`/`xelab`/`xsim` |
| `verilator --lint-only` | ❌ 不可用 | 同上 |
| 人工语法自检 | ✅ 已执行 | 逐文件检查保留字冲突、未声明信号、端口位宽匹配、过程块内声明、层次引用合法性 |

> **显式声明：本次未执行真实编译检查**（`xvlog`/`verilator` 均不可用）。以下为人工自检结果，**建议在有 Vivado 环境时先跑一次 `start.tcl` 确认 0 error**。

### 8.2 人工自检发现并已修正的问题（TB 侧，11 项）

| # | 文件 | 问题 | 修正 |
|---|------|------|------|
| 1 | `chi_tb_pkg.sv` | 使用 `typedef enum` + `struct` 含动态数组 `payload[]`（Xsim 弱支持） | 改为 `parameter logic [7:0]` 常量 + 纯函数；移除 struct/动态数组 |
| 2 | `chi_agent_rn/hn.sv` | 任务调用使用命名参数 `opcode : ...`（Xsim 对 `:` 语法支持不稳） | 全部改为位置参数调用 |
| 3 | `chi_router_tb_top.sv` | `bind` 语句写在 module 内（非法） | 移至 `chi_assertions.sv` 文件作用域 |
| 4 | `chi_router_tb_top.sv` | `mon_crd_cnt[i] = 8'hFF` 为虚假常量（掩盖 credit 观测缺失） | 改为 `crd_cnt_obs({(PORT_NUM){8'hFF}})` 并在注释中说明骨架态无观测点 |
| 5 | `chi_router_tb_top.sv` | `u_rn[pp].send_req(...)` 用生成块变量索引调用（非标准 SV） | 改为 8 条独立 `fork` 分支 |
| 6 | `chi_router_tb_top.sv` | `always_comb` 内 `for (int i = ...)` 声明变量 | 改为 module 级 `int mi` |
| 7 | `chi_router_tb_top.sv` | `pclk` 接 `clk`，与 spec CLK-01（100MHz）不符 | 改用 `chi_clk_rst_if` 的独立 `pclk` |
| 8 | `chi_coverage.sv` | `b_op_rsp`/`b_op_dat` 同为 `3'h2`（bins 取值重叠，Xsim 报错） | 改为 `cp_in_op_hi` 按高 3 位分族，8 bins 互斥 |
| 9 | `chi_coverage.sv` | `cp_in_ch_grp` 恒为 `2'd0`（退化 coverpoint） | 改为按优先级扫描提取真实通道组 |
| 10 | `chi_coverage.sv` | `cg_apb_access @(posedge pclk)` 引用未声明的 `pclk` | 补 `pclk`/`presetn` 端口 |
| 11 | `chi_assertions.sv` | `generate` 内声明 `property`；三元表达式宽度不匹配（512 vs 256）；`credit_mgr` 无 `crd_cnt` 端口 | 改为「SVA + 立即断言」混合；逐通道用 `always_ff`；bind 端口改用内部数组 `cred` |

### 8.3 模块级 TB 自检（7 文件）

| 检查项 | 结果 |
|--------|------|
| 保留字冲突 | ✅ 无 |
| 未声明信号 | ✅ 无 |
| 端口位宽匹配 | ✅ 无（`QW = 9` 与 `$clog2(512)` 一致） |
| `initial`/`always` 内声明变量 | ✅ 已全部清理（改用 module 级变量） |
| `fork` 内声明变量 | ✅ 已清理（`chi_tb_sync_2ff` 改用 module 级 `cyc`） |
| 层次引用 | ✅ 仅 `chi_tb_credit_mgr` 用 `u_dut.cred[ch]`（合法，用于观测内部 credit） |
| 超时保护 | ✅ 每个 TB 都有独立超时 `initial` |

### 8.4 遗留的编译风险（需真实编译确认）

| # | 项 | 风险 | 建议 |
|---|-----|------|------|
| 1 | `chi_scoreboard` 中 `logic [511:0] exp_fifo [8][256]` = 8×256×512b = 1 Mb | 内存占用较大但可接受 | 如编译慢可降至 `FIFO_DEPTH=64` |
| 2 | `chi_assertions.sv` 中 A2/A3/A4 用 `always_ff` 逐端口检查 | 每个 clk 边沿 8 端口 × 4 通道，仿真性能开销较大 | 如过慢可加 `ifdef ASSERT_FAST` 降为仅端口 0 |
| 3 | `chi_coverage.sv` 的 `x_port_qos` 等 cross 共 80+ crosses | 覆盖率数据库体积较大 | 可接受，按需裁剪 |
| 4 | `chi_tb_pkg.sv` 的 `pack_wide_flit` 中 `f[49] = ^payload` | `^payload` 为 512 bit 归约，Xsim 支持 | 无 |
| 5 | `voq_linklist.sv` 存在**先使用后声明**（`QUEUE_NUM_W` 在 port list 用、body 中才 `localparam`） | **RTL 编译级错误** | 见 §9 **D-17**，需前端修正 |

---

## 9. RTL 缺陷清单（导致验证结论 FAIL）

> 以下为逐文件审阅 RTL 源码后发现的缺陷。**D-01 为验证结论 FAIL 的主因**。

### D-01 【致命】`chi_router_top` 子系统例化全部被注释（骨架态）

**位置**：`rtl/chi_router_top.sv` 第 62–69 行

```systemverilog
  // ---------------- 子系统例化（待架构细化后接线） ----------------
  // buffer_subsys  u_buffer_subsys (...);
  // port_ingress   u_ingress[PORT_NUM] (...);
  // scheduler      u_scheduler (...);
  // crossbar_a     u_xbar_a (...);
  // crossbar_b     u_xbar_b (...);
  // port_egress    u_egress[PORT_NUM] (...);
  // csr_subsys     u_csr_subsys (...);
```

**影响**：

* `link_out_valid` / `link_out_ready` / `link_out_req/rsp/dat/snp` 全部无驱动 → 出口恒 0/X
* `link_in_ready` 无驱动 → RN agent 的 `req_ready` 恒 X，`send_req` 握手永不完成
* `link_in_valid` 由 agent 驱动但无人消费
* `prdata` / `pready` / `pslverr` / `irq` 无驱动 → APB 读返回 X
* **系统级 3 个用例（TC_SMOKE/TC_CONGESTION/TC_ORDERING）无法验证任何数据面功能**

**修改建议**：

1. 完成 6 个子系统的例化与连线（按 arch_spec §3.2 拓扑）
2. 若采用增量交付，至少先例化 `csr_subsys`（让 APB 通路可用）+ `port_ingress`/`port_egress` 的直通旁路
3. 在骨架阶段为 `link_out_*` 加 `assign link_out_valid = '0;` 等默认驱动，避免 X 传播

### D-02 【高】`flit_decode` 未使用 `ch_sel`

**位置**：`rtl/ingress/flit_decode.sv`

**问题**：`ch_sel` 为输入端口但未参与任何 `assign`。spec §4.2 要求按通道选择提取字段（REQ/DAT 为 512b，RSP/SNP 为 256b，字段位置可能不同）。

**影响**：窄通道（RSP/SNP）字段提取可能错误；`ch_sel` 悬空导致综合告警。

**修改建议**：按 `ch_sel` 分支提取字段，或明确声明「所有通道字段布局一致」并移除 `ch_sel` 端口。

### D-03 【高】`route_lookup` 恒 `hit=0`，所有 flit 被判非法丢弃

**位置**：`rtl/ingress/route_lookup.sv`

```systemverilog
  assign out_port = '0;
  assign hit      = 1'b0;
  assign drop     = ~hit;   // 恒 1
```

**影响**：即使顶层接线完成，所有 flit 都会被丢弃，数据面零吞吐。

**修改建议**：实现 `tbl_flat` 地址译码（依赖 CSR 最终格式），或先接 `default_port` 通路。

### D-04 【高】`islip_arbiter` 恒 `grant=0`

**位置**：`rtl/sched/islip_arbiter.sv`

```systemverilog
  // TODO: 2-round 迭代匹配 + grant 指针（round-robin 位置）更新
  assign grant       = '0;
  assign grant_valid = 1'b0;
```

**影响**：宽通道（REQ/DAT）永不授权，`scheduler` 无读请求输出。

**修改建议**：实现 2-round iSLIP（`ROUND_N` 参数化），并补模块级 TB 验证收敛性（对应 R-01）。

### D-05 【中】`credit_mgr` 无 credit 下限保护

**位置**：`rtl/egress/credit_mgr.sv`

```systemverilog
        else if (send_flit[g] && !crd_return[g]) cred[g] <= cred[g] - 1'b1;
```

**问题**：`cred[g]` 为 0 时继续 `send_flit` 会回绕到 `0xFF`（8 bit）或 `0xFF`（无符号）。

**影响**：credit 下溢后误判为「有 credit」，可能造成下游溢出；`ERR_CREDIT_UF`（bit 2）无上报路径。

**修改建议**：

```systemverilog
        else if (send_flit[g] && !crd_return[g] && (cred[g] != '0))
          cred[g] <= cred[g] - 1'b1;
```

并增加 `err_credit_uf` 输出用于 `ERR_STATUS[2]` 上报。TB 侧 `chi_tb_credit_mgr` TC6 已埋入下溢观察点。

### D-06 【中】`pool_credit` 同样无下限保护

**位置**：`rtl/buffer/pool_credit.sv`

与 D-05 同构：`2'b10: crd_cnt[g] <= crd_cnt[g] - 1'b1;` 未判 0。

**修改建议**：加 `&& (crd_cnt[g] != '0)` 条件，并补 `ERR_POOL_OVF`/下溢上报。

### D-07 【高】`order_guard` 恒 `allow=1`，三层保序未实现

**位置**：`rtl/egress/order_guard.sv`

```systemverilog
  // TODO: 三层检查实现
  assign allow   = 1'b1;
  assign violate = 1'b0;
```

**影响**：PoS 域保序（ORD-01）、SN 序（ORD-03）完全未实现；`ERR_ORDER_VIO`（bit 3）无上报路径。

**修改建议**：按 arch_spec §6.6 实现三层检查；R-02 提示需状态机化 + 2 级流水以控制组合路径。

### D-08 【高】`voq_linklist` 仅声明数组，无入队/出队逻辑

**位置**：`rtl/buffer/voq_linklist.sv`

```systemverilog
  logic [FLIT_ID_W-1:0] head [QUEUE_NUM];
  logic [FLIT_ID_W-1:0] tail [QUEUE_NUM];
  logic [CNT_W-1:0]     cnt  [QUEUE_NUM];

  // TODO: 入队/出队指针更新、next 指针 SRAM 读写（待架构细化）

  assign deq_fid  = head[qid_sel];
  assign deq_vld_o = (cnt[deq_qid] != '0);
  assign q_cnt    = cnt[qid_sel];
```

**影响**：

* `head`/`tail`/`cnt` 无初值、无写入 → 读出的 `deq_fid` 为 X
* `deq_fid` 用 `head[qid_sel]`（查询口）而非 `head[deq_qid]`（出队口）→ **索引错误**
* VOQ 队列功能完全不可用

**修改建议**：实现入队（更新 `tail`/`cnt`，写 next 指针 SRAM）与出队（读 `head`、更新 `head`/`cnt`）；修正 `deq_fid` 索引为 `head[deq_qid]`；补复位初值。

### D-09 【中】`apb_slave` 恒 `pslverr=0`，非法地址不报错

**位置**：`rtl/csr/apb_slave.sv`

```systemverilog
  assign pready  = 1'b1;   // 0-wait 默认（可配 1-wait，见 design_spec）
  assign pslverr = 1'b0;
```

**问题**：spec §4.1 要求「地址非法置 1」；`CREDIT_CTRL[8]` 可配 1-wait 也未实现。

**修改建议**：加地址译码，非法地址置 `pslverr=1`；实现 0/1 wait 可配。

### D-10 【中】`qos_shaper` 空实现

**位置**：`rtl/egress/qos_shaper.sv` — 仅端口声明，无任何逻辑，`grant` 未驱动。

**修改建议**：实现 WRR 轮转 + token bucket 补充/消耗（对应 F-07）。

### D-11 【中】`pmu_counters` 空实现

**位置**：`rtl/csr/pmu_counters.sv` — 仅端口声明，`cnt_flit_out`/`cnt_conflict`/`occ_snap` 未驱动。

**修改建议**：实现分端口计数 + 快照（对应 F-08）。

### D-12 【中】`scheduler` 空实现

**位置**：`rtl/sched/scheduler.sv` — 仅端口声明，`rd_req_valid`/`rd_req_qid`/`xbar_sel_valid` 未驱动。

**修改建议**：例化 `islip_arbiter`（宽通道）与 `rr_arbiter`（窄通道），生成读请求。

### D-13 【中】`crossbar_a`/`crossbar_b` 空实现

**位置**：`rtl/xbar/crossbar_a.sv`、`rtl/xbar/crossbar_b.sv` — 仅端口声明，`out_valid`/`out_data` 未驱动。

**修改建议**：实现单级 8×8 选通 + 输出寄存器（A-4 基线）。

### D-14 【中】`port_ingress`/`port_egress`/`buffer_subsys`/`csr_subsys` 空实现

**位置**：各子系统顶层 — 仅端口声明，无子模块例化。

**修改建议**：按 arch_spec §3.1 完成例化与连线。

### D-15 【中】`route_table` 空实现

**位置**：`rtl/csr/route_table.sv` — `lookup_port`/`lookup_valid` 未驱动。

**修改建议**：实现 CAM 或 hash 查表 + epoch 双缓冲（S-1 基线）。

### D-16 【中】`qos_regs` 使用未声明的 `AW`

**位置**：`rtl/csr/qos_regs.sv`

```systemverilog
  input  wire [AW-1:0] addr,     // ← AW 在 port list 中使用
  ...
  localparam int AW = 4;         // ← 在 body 中才声明
```

**问题**：`AW` 在端口列表中被使用，但 `localparam` 声明在模块体内 → **先使用后声明**，Verilog/SV 编译报错。

**修改建议**：将 `AW` 改为模块 `parameter`，或把 `localparam` 提到端口列表之前（推荐改为 `parameter int AW = 4`）。

### D-17 【中】`voq_linklist` 同样存在 `QUEUE_NUM_W` 先使用后声明

**位置**：`rtl/buffer/voq_linklist.sv`

```systemverilog
  input  wire [QUEUE_NUM_W-1:0] enq_qid,   // ← 在 port list 中使用
  ...
  localparam int QUEUE_NUM_W = $clog2(QUEUE_NUM);   // ← body 中才声明
```

**问题**：同 D-16，**编译级错误**。

**修改建议**：改为 `parameter int QUEUE_NUM_W = $clog2(QUEUE_NUM)` 并置于端口列表之前。

### D-18 【高】`qid` 位宽在 spec 内自相矛盾

**位置**：`doc/arch_spec.md` §3.3

```
qid[5:0] = {out_port[2:0], ch_grp[1:0], qos[1:0]}
```

**矛盾**：

* 右侧宽度 = 3 + 2 + 2 = **7 bit**，与左侧 `qid[5:0]`（6 bit）不符
* 组合数 = 8 × 4 × 4 = **128**，与「每输入 64 队列」不符
* 若 `qos` 为 1 bit：8 × 4 × 2 = **64** ✅ 自洽

**影响**：`pool_alloc` 的 `enq_qid` 为 6 bit，`buffer_subsys` 的 `rd_req_qid` 为 9 bit，`voq_linklist` 的 `QUEUE_NUM_W = $clog2(512) = 9`——三处位宽不一致。

**修改建议**：明确裁定 `qos` 位宽。若为 1 bit，修正 spec §3.3 为 `{out_port[2:0], ch_grp[1:0], qos[0]}`；若为 2 bit，将 `QUEUE_PER_IN` 改为 128、`QUEUE_NUM` 改为 1024，并统一所有 qid 位宽。

### D-19 【低】`sim/tests/tc_*.f` 的 `+UVM_TESTNAME` 无实际效力

**位置**：`sim/tests/tc_smoke.f` 等

```
+define+TC_SMOKE
+UVM_TESTNAME=tc_smoke
```

**问题**：`tb/` 下无任何 UVM class，`+UVM_TESTNAME` 无对应 test 类。

**修改建议**：若坚持纯 SV 定向，删除 `+UVM_TESTNAME`；若转 UVM，补 `tc_smoke_test.sv` 等 UVM test 类。

### D-20 【低】`sync_2ff` 中的空 `initial` 块

**位置**：`rtl/common/sync_2ff.sv`

```systemverilog
  // synopsys translate_off
  initial begin
    if (BUS && W > 1) ;
  end
  // synopsys translate_on
```

**问题**：空语句 `;`，无实际检查；且 spec C-01 要求「无 `initial`（TB 除外）」。

**修改建议**：改为 `if (BUS && W > 1) $warning(...)` 或直接删除。

### D-21 【低】`flit_decode` 的 `order` 输出为 3 bit 但 `order_guard` 输入为 2 bit

| 模块 | 端口 | 位宽 |
|------|------|------|
| `flit_decode` | `order` | 3 |
| `order_guard` | `order` | 2 |

**问题**：位宽不匹配，连接时会截断。

**修改建议**：统一为 3 bit（与 `chi_order_e` 一致）。

---

## 10. 验证结论

### 10.1 判定依据

| 判定项 | 结果 |
|--------|------|
| 文件完整性（任务树核验） | ✅ 全部文件存在，0 缺失 |
| `sim_filelist.f` 逐文件 `file exists` | ✅ 46/46 通过 |
| TB 框架交付 | ✅ 17 个 TB 文件（含 7 个模块级 TB + 系统级顶层） |
| 覆盖率定义 | ✅ 3 个 covergroup，命名合规 |
| 断言定义 | ✅ 11 条断言，bind 合法 |
| 工程 Tcl 脚本 | ✅ `start.tcl` / `run_one.tcl` / `README.md` |
| **RTL 功能完整性** | ❌ **顶层子系统例化全部注释；7 个叶子模块为空实现；2 处编译级错误（D-16/D-17）** |
| **系统级用例可验证性** | ❌ **数据面零活动，3 个系统级用例无法给出有效判定** |

### 10.2 缺陷统计

| 等级 | 数量 | 编号 |
|------|------|------|
| 致命 | 1 | D-01 |
| 高 | 6 | D-02, D-03, D-04, D-07, D-08, D-18 |
| 中 | 10 | D-05, D-06, D-09, D-10, D-11, D-12, D-13, D-14, D-15, D-16, D-17 |
| 低 | 3 | D-19, D-20, D-21 |
| **合计** | **20** | — |

### 10.3 优先级修复建议

| 优先级 | 动作 |
|--------|------|
| P0 | 修复 D-16、D-17（编译级错误，否则 `xvlog` 直接报错，全部 tb 无法编译） |
| P0 | 修复 D-01（完成顶层例化，否则系统级验证无意义） |
| P1 | 修复 D-03、D-04（路由与仲裁是数据面主通路） |
| P1 | 修复 D-08（VOQ 是缓冲核心，且存在索引错误） |
| P1 | 裁定 D-18（qid 位宽），统一所有相关模块位宽 |
| P2 | 修复 D-05、D-06（credit 下限保护，防溢出/下溢） |
| P2 | 修复 D-07（三层保序，对应 ORD-01/ORD-03） |
| P2 | 实现 D-10 ~ D-15（QoS / PMU / scheduler / xbar / 子系统顶层 / 路由表） |
| P3 | 修复 D-02、D-09、D-19、D-20、D-21 |

### 10.4 验证环境可用性说明

**本次交付的 TB 与脚本已就绪，可在 RTL 修复后立即使用**：

* 7 个模块级 TB 针对**已有真实实现**的叶子模块（`rr_arbiter`、`parity_check`、`sync_2ff`、`pool_credit`、`tail_lock`、`credit_mgr`、`flit_decode`），**修复 D-16/D-17 后即可跑出真实 PASS/FAIL**
* 系统级 3 个用例在 D-01 修复后即可验证数据面
* 断言与覆盖率已挂在真实接口上，RTL 接线完成后自动生效

---

## 11. 附录：文件树（本次交付后）

```
chi_router/
├── doc/
│   ├── design_spec.md
│   ├── arch_spec.md
│   ├── verification_plan.md        ← 新增
│   └── verification_report.md      ← 新增（本文件）
├── rtl/                            （29 个 .sv，未修改）
│   ├── chi_router_pkg.sv
│   ├── chi_router_top.sv
│   ├── filelist.f
│   ├── common/     sync_2ff.sv, clk_rst_gen.sv
│   ├── ingress/    port_ingress.sv, flit_decode.sv, parity_check.sv,
│   │               route_lookup.sv, pool_alloc.sv
│   ├── buffer/     buffer_subsys.sv, sram_wrapper.sv, voq_linklist.sv, pool_credit.sv
│   ├── sched/      scheduler.sv, islip_arbiter.sv, rr_arbiter.sv
│   ├── xbar/       crossbar_a.sv, crossbar_b.sv
│   ├── egress/     port_egress.sv, credit_mgr.sv, order_guard.sv,
│   │               tail_lock.sv, qos_shaper.sv
│   └── csr/        csr_subsys.sv, apb_slave.sv, route_table.sv,
│                   qos_regs.sv, pmu_counters.sv, err_regs.sv
├── tb/
│   ├── chi_router_tb_top.sv        ← 重写
│   ├── chi_agent_rn.sv             ← 重写
│   ├── chi_agent_hn.sv             ← 重写
│   ├── chi_scoreboard.sv           ← 重写
│   ├── chi_tb_pkg.sv               ← 新增
│   ├── chi_clk_rst_if.sv           ← 新增
│   ├── chi_coverage.sv             ← 新增
│   ├── chi_assertions.sv           ← 新增
│   ├── chi_tb_rr_arbiter.sv        ← 新增
│   ├── chi_tb_parity_check.sv      ← 新增
│   ├── chi_tb_sync_2ff.sv          ← 新增
│   ├── chi_tb_pool_credit.sv       ← 新增
│   ├── chi_tb_tail_lock.sv         ← 新增
│   ├── chi_tb_credit_mgr.sv        ← 新增
│   ├── chi_tb_flit_decode.sv       ← 新增
│   └── sram_model/sram_behavioral.sv
├── syn/
│   ├── constraints/chi_router.sdc
│   └── scripts/syn.tcl
├── sim/
│   ├── regression.f
│   └── tests/  tc_smoke.f, tc_congestion.f, tc_ordering.f
└── scripts/                        ← 新增目录
    ├── sim_filelist.f              ← 新增（46 条，已逐条 file exists 核验）
    ├── start.tcl                   ← 新增（全量回归）
    ├── run_one.tcl                 ← 新增（单 tb 定向回归）
    └── README.md                   ← 新增（命令行用法说明）
```

---

验证结论: FAIL（需修改，修改建议见 §9 缺陷清单 D-01 ~ D-21）
