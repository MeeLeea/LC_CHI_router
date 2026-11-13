# CHI Router 设计规格书 (design_spec.md)

> 状态：**骨架 v0.1（待随架构设计逐步填充）**
> 目标协议：CHI-BE（REQ / RSP / DAT / SNP 四通道）
> 实现路径：可综合 RTL（SystemVerilog-2017），主力仿真器 VCS，后端 DC/Genus

---

## 0. 文档变更记录

| 版本 | 日期 | 作者 | 说明 |
|------|------|------|------|
| 0.1  | TBD  | TBD  | 建立骨架，章节占位 |

---

## 1. 术语与缩写

| 缩写 | 全称 | 说明 |
|------|------|------|
| CHI | Coherent Hub Interface | Arm AMBA 5 一致性总线协议 |
| RN | Request Node | 请求节点（发起方） |
| HN | Home Node | 归属节点（一致性管理者） |
| SN | Slave Node | 从节点 |
| VOQ | Virtual Output Queue | 虚输出队列，消除 HoL 阻塞 |
| iSLIP | iterative SLIP | 迭代匹配仲裁算法 |
| PoS | Point of Serialization | 序列化点 |
| L-credit | Link credit | 链路级 credit 流控 |
| PMU | Performance Monitoring Unit | 性能计数器 |
| WRR | Weighted Round Robin | 加权轮询 |

---

## 2. 需求与约束（环节 1 产出）

### 2.1 功能需求
- F-01 8 个双向端口（8×8 mesh/torus 拓扑适配），每端口 4 通道全双工。
- F-02 支持 CHI-BE Opcode 子集：REQ(ReadShared/ReadUnique/CleanUnique/MakeUnique/WriteUnique/...)、RSP(Comp/CompData 拆包)、DAT(CompData/WriteData/NonCopyBackWrData)、SNP(SnpShared/SnpUnique/...)。
- F-03 NodeID → 输出端口查表转发，表项 CSR 可配、支持默认端口与非法 NodeID 丢弃。
- F-04 per-flit parity 校验，错误可上报并聚合到中断。
- F-05 VOQ 缓冲：8 Pool × 16 bank，512 队列（每输入 64）。
- F-06 三层保序：PoS 域内同源地址序、同 packet 多 beat 尾锁、同 SN 序。
- F-07 WRR + token bucket QoS 整形，权重/阈值 CSR 可配。
- F-08 APB4 CSR 访问；PMU 吞吐/占用/冲突计数。

### 2.2 性能需求（**待量化，见 4.1 决策点 D-01**）
| 指标 | 目标值 | 备注 |
|------|--------|------|
| 单链路带宽 | TBD (建议 512b × f) | 宽通道 512b，窄通道 256b |
| 峰值吞吐 | TBD | 需 xbar 线速、无内部阻塞 |
| 端口时延 | TBD cycles（cut-through 目标） | store-and-forward 备选 |
| 频率 | TBD MHz | |
| 缓冲深度 | 128 flit/端口（8 Pool × 16 bank 语义待定义） | |

### 2.3 功耗 / 面积 / 工艺 / 成本
- 工艺：TBD（建议 16/12nm 或 FPGA 原型 XCVU13P）
- 面积：SRAM 主导（512b×depth×16bank×8pool），逻辑以 xbar/sched 为主
- 功耗：时钟门控（clk_rst_gen），SRAM 按 bank 使能；目标 TBD mW/port
- 成本：单 die 集成，无外部 PHY

### 2.4 约束
- C-01 编码规范：SystemVerilog-2017、2 空格缩进、低有效异步复位 `rst_n`、无 latch、无 `initial`（TB 除外）。
- C-02 单一功能时钟域 `clk`，APB 侧若异步仅准静态总线经 2FF 同步。
- C-03 所有跨模块接口 valid/ready 反压；不允许组合环回路径跨两级以上。
- C-04 编译顺序由 `rtl/filelist.f` 决定：pkg → common → 各子系统 → top。

---

## 3. 架构方案（环节 2 产出，待填充）

### 3.1 顶层框图
```
      ┌──────────────────────── chi_router_top ────────────────────────┐
RN ──▶│ port_ingress ×8 → buffer_subsys → scheduler → xbar_a/xbar_b     │
      │        │(route_lookup)              │            │              │
      │        └──────────── csr_subsys (APB4) ──────────┘              │
HN ◀──│ port_egress ×8 ←───────────────────────────────────┘            │
      └─────────────────────────────────────────────────────────────────┘
```
（详细框图待补）

### 3.2 通道与位宽
| 通道 | 位宽 | 子系统 | 仲裁 |
|------|------|--------|------|
| REQ  | 512b | ingress 打包 → buffer → sched | iSLIP 2-round |
| DAT  | 512b | buffer → xbar_a | iSLIP 2-round |
| RSP  | 256b | buffer → xbar_b | RR |
| SNP  | 256b | buffer → xbar_b | RR |

### 3.3 存储组织
- Pool 划分策略：TBD（决策点 D-03）
- 地址映射 / free-list / linklist 指针格式：TBD

### 3.4 保序与 QoS
- order_guard 三层检查规则：TBD
- tail_lock 生命周期：TBD
- qos_shaper token bucket 参数：CSR 可配

---

## 4. 关键决策点与风险（环节 3 产出）

### 4.1 待用户拍板决策点
| ID | 决策点 | 选项 | 状态 |
|----|--------|------|------|
| D-01 | 性能目标量化（频率/带宽/时延） | — | **Open** |
| D-02 | 转发模式：cut-through vs store-and-forward | 影响首字时延与缓冲需求 | **Open** |
| D-03 | Pool 划分：共享 vs 按通道/端口静态划分 | 影响 HoL 与面积 | **Open** |
| D-04 | SRAM 宏来源（厂家宏 / 行为模型 / BRAM） | 已定：统一 sram_wrapper 抽象 | Closed |
| D-05 | 复位策略 | 已定：异步复位同步释放，单时钟域 | Closed |
| D-06 | 握手协议 | 已定：valid/ready 反压 | Closed |

### 4.2 风险登记
| ID | 风险 | 影响 | 缓解 |
|----|------|------|------|
| R-01 | iSLIP 收敛迭代不足导致吞吐下降 | 中 | 2-round + 参数化 round 数 |
| R-02 | 三层保序组合逻辑过长 | 高 | tail_lock 状态机化、寄存器切分 |
| R-03 | 512 队列 linklist 指针 SRAM 带宽瓶颈 | 高 | 多 bank + 读指针预取 |
| R-04 | xbar 8×8×512b 布线拥塞 | 中 | 分级 xbar / 时序预算预留 |
| R-05 | CHI 协议细节偏差（Opcode/字段） | 高 | 依 Arm IHI0050 + 评审对照表 |

---

## 5. 验证策略（待填充）

- TB：chi_router_tb_top + RN/HN agent + scoreboard
- 用例：tc_smoke / tc_congestion / tc_ordering
- 覆盖：功能覆盖（Opcode×路由×QoS）、credit 边界、错误注入

## 6. 综合与约束（待填充）

- syn/constraints/chi_router.sdc：时钟、IO 延时、false path、clock gating
- syn/scripts/syn.tcl：DC 流程

## 7. 评审记录（环节 4）

| 日期 | 评审项 | 结论 | 遗留 |
|------|--------|------|------|
| TBD  | 架构评审 | — | — |
