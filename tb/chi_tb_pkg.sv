//=============================================================================
// 文件: tb/chi_tb_pkg.sv
// 功能: TB 侧共享定义 —— 字段打包/解包、qid 编码、CSR 地址、LFSR
// 说明: 纯 SystemVerilog（无 UVM class），适配 Vivado Xsim
//       与 rtl/chi_router_pkg.sv 的字段布局严格对齐（见 flit_decode.sv）
// 约束: 不重复实现可综合 RTL 逻辑；仅提供激励打包与期望值计算
// 自检: 不使用保留字作标识符；不含动态数组/类/约束等 Xsim 弱支持特性
//=============================================================================
`ifndef CHI_TB_PKG_SV
`define CHI_TB_PKG_SV

package chi_tb_pkg;

  // ---------------------------------------------------------------------------
  // 规模参数（与 RTL 顶层端口一致）
  // ---------------------------------------------------------------------------
  parameter int PORT_NUM   = 8;
  parameter int WIDE_W     = 512;
  parameter int NARROW_W   = 256;
  parameter int NODEID_W   = 16;
  parameter int QOS_CLASS  = 4;
  parameter int QUEUE_NUM  = 512;

  // ---------------------------------------------------------------------------
  // 通道位序（对应 tb 顶层 link_*_valid[3:0] 的位索引）
  // ---------------------------------------------------------------------------
  parameter int CH_BIT_REQ = 0;
  parameter int CH_BIT_RSP = 1;
  parameter int CH_BIT_DAT = 2;
  parameter int CH_BIT_SNP = 3;

  // ---------------------------------------------------------------------------
  // CHI-BE Opcode 子集（与 rtl/chi_router_pkg.sv 冻结值一致）
  // ---------------------------------------------------------------------------
  parameter logic [7:0] OP_REQ_READ_SHARED   = 8'h01;
  parameter logic [7:0] OP_REQ_READ_UNIQUE   = 8'h02;
  parameter logic [7:0] OP_REQ_MAKE_UNIQUE   = 8'h04;
  parameter logic [7:0] OP_REQ_CLEAN_UNIQUE  = 8'h07;
  parameter logic [7:0] OP_REQ_WRITE_UNIQUE  = 8'h09;
  parameter logic [7:0] OP_RSP_COMP          = 8'h40;
  parameter logic [7:0] OP_RSP_COMP_DATA     = 8'h41;
  parameter logic [7:0] OP_DAT_COMP_DATA     = 8'h50;
  parameter logic [7:0] OP_DAT_WRITE_DATA    = 8'h51;
  parameter logic [7:0] OP_DAT_NCB_WR_DATA   = 8'h52;
  parameter logic [7:0] OP_SNP_SHARED        = 8'h60;
  parameter logic [7:0] OP_SNP_UNIQUE        = 8'h61;
  parameter logic [7:0] OP_SNP_CLEAN_INVALID = 8'h62;

  // ---------------------------------------------------------------------------
  // CSR 地址映射（与 arch_spec 5.1 一致）
  // ---------------------------------------------------------------------------
  parameter logic [15:0] ADDR_ROUTE_TBL_ADDR  = 16'h0000;
  parameter logic [15:0] ADDR_ROUTE_TBL_DATA  = 16'h0004;
  parameter logic [15:0] ADDR_ROUTE_TBL_CTRL  = 16'h0008;
  parameter logic [15:0] ADDR_ROUTE_DEF_PORT  = 16'h000C;
  parameter logic [15:0] ADDR_QOS_WEIGHT_BASE = 16'h0010;
  parameter logic [15:0] ADDR_QOS_BUCKET_BASE = 16'h0020;
  parameter logic [15:0] ADDR_QOS_PRIO_MAP    = 16'h0030;
  parameter logic [15:0] ADDR_PMU_CTRL        = 16'h0040;
  parameter logic [15:0] ADDR_PMU_FLIT_OUT    = 16'h0044;
  parameter logic [15:0] ADDR_PMU_CONFLICT    = 16'h0048;
  parameter logic [15:0] ADDR_PMU_OCC_BASE    = 16'h004C;
  parameter logic [15:0] ADDR_ERR_STATUS      = 16'h0080;
  parameter logic [15:0] ADDR_ERR_EN          = 16'h0084;
  parameter logic [15:0] ADDR_ERR_IRQ_STATUS  = 16'h0088;
  parameter logic [15:0] ADDR_CREDIT_CTRL     = 16'h00A0;
  parameter logic [15:0] ADDR_CREDIT_STATUS   = 16'h00A4;
  parameter logic [15:0] ADDR_ID_REV          = 16'h00F0;

  // 版本号复位值（arch_spec 5.1）
  parameter logic [31:0] ID_REV_EXPECT = 32'h0001_0000;

  // ---------------------------------------------------------------------------
  // 错误源位定义（arch_spec 5.2）
  // ---------------------------------------------------------------------------
  parameter int ERR_BIT_PARITY         = 0;
  parameter int ERR_BIT_ROUTE_MISS     = 1;
  parameter int ERR_BIT_CREDIT_UF      = 2;
  parameter int ERR_BIT_ORDER_VIO      = 3;
  parameter int ERR_BIT_VOQ_OVF        = 4;
  parameter int ERR_BIT_POOL_OVF       = 5;
  parameter int ERR_BIT_EPOCH_MISMATCH = 6;

  // ---------------------------------------------------------------------------
  // 字段布局（与 flit_decode.sv 的 assign 一一对应）
  //   [7:0]   opcode
  //   [10:8]  size
  //   [13:11] order
  //   [15:14] domain
  //   [31:16] tgt_id
  //   [47:32] src_id
  //   [48]    qos
  //   [49]    parity（parity_check 用 ^flit_data 比对）
  //   [63:56] txn_id（TB 私有扩展，用于 scoreboard 配对）
  //   其余位为 payload
  // ---------------------------------------------------------------------------

  // 宽 flit 打包
  function automatic logic [WIDE_W-1:0] pack_wide_flit(
    input logic [7:0]          opcode,
    input logic [2:0]          size,
    input logic [2:0]          order,
    input logic [1:0]          domain,
    input logic [NODEID_W-1:0] tgt_id,
    input logic [NODEID_W-1:0] src_id,
    input logic                qos,
    input logic [7:0]          txn_id,
    input logic [WIDE_W-1:0]   payload
  );
    logic [WIDE_W-1:0] f;
    f        = payload;
    f[7:0]   = opcode;
    f[10:8]  = size;
    f[13:11] = order;
    f[15:14] = domain;
    f[31:16] = tgt_id;
    f[47:32] = src_id;
    f[48]    = qos;
    f[49]    = ^payload;   // parity 覆盖 payload
    f[63:56] = txn_id;
    return f;
  endfunction

  // 窄 flit 打包
  function automatic logic [NARROW_W-1:0] pack_narrow_flit(
    input logic [7:0]          opcode,
    input logic [2:0]          size,
    input logic [2:0]          order,
    input logic [1:0]          domain,
    input logic [NODEID_W-1:0] tgt_id,
    input logic [NODEID_W-1:0] src_id,
    input logic                qos,
    input logic [7:0]          txn_id,
    input logic [NARROW_W-1:0] payload
  );
    logic [NARROW_W-1:0] f;
    f        = payload;
    f[7:0]   = opcode;
    f[10:8]  = size;
    f[13:11] = order;
    f[15:14] = domain;
    f[31:16] = tgt_id;
    f[47:32] = src_id;
    f[48]    = qos;
    f[49]    = ^payload;
    f[63:56] = txn_id;
    return f;
  endfunction

  // 字段解包（TB 侧参考模型用，不替代 RTL flit_decode）
  function automatic logic [7:0] get_opcode(input logic [WIDE_W-1:0] f);
    return f[7:0];
  endfunction

  function automatic logic [NODEID_W-1:0] get_tgt_id(input logic [WIDE_W-1:0] f);
    return f[31:16];
  endfunction

  function automatic logic [NODEID_W-1:0] get_src_id(input logic [WIDE_W-1:0] f);
    return f[47:32];
  endfunction

  function automatic logic [7:0] get_txn_id(input logic [WIDE_W-1:0] f);
    return f[63:56];
  endfunction

  function automatic logic get_parity(input logic [WIDE_W-1:0] f);
    return f[49];
  endfunction

  // ---------------------------------------------------------------------------
  // VOQ qid 编码（6 bit，与 rtl 冻结的 qid[5:0] 宽度一致）：
  //   qid[5:0] = {out_port[2:0], ch_grp[1:0], qos[0]}
  //   ch_grp: 0=REQ, 1=DAT, 2=RSP+SNP, 3=保留
  // 注意（缺陷 D-19）：
  //   arch_spec §3.3 写为 {out_port[2:0], ch_grp[1:0], qos[1:0]} = 7 bit，
  //   与「qid[5:0]」及「每输入 64 队列」自相矛盾：
  //     8(out_port) × 4(ch_grp) × 4(qos) = 128 ≠ 64
  //     8(out_port) × 4(ch_grp) × 2(qos) = 64  → qos 为 1 bit
  //   本函数按「宽度自洽」的 1-bit qos 实现；若最终裁定 qos=2 bit，
  //   需同步把 QUEUE_PER_IN 改为 128 并修正所有 qid 位宽。
  // ---------------------------------------------------------------------------
  function automatic logic [5:0] make_qid(
    input logic [2:0] out_port,
    input logic [1:0] ch_grp,
    input logic       qos
  );
    return {out_port, ch_grp, qos};
  endfunction

  // 通道位索引 → ch_grp 映射（RSP/SNP 合并为 2）
  function automatic logic [1:0] ch_to_grp(input int ch_bit);
    logic [1:0] g;
    case (ch_bit)
      CH_BIT_REQ: g = 2'd0;
      CH_BIT_DAT: g = 2'd1;
      CH_BIT_RSP: g = 2'd2;
      CH_BIT_SNP: g = 2'd2;
      default:    g = 2'd3;
    endcase
    return g;
  endfunction

  // ---------------------------------------------------------------------------
  // 简单 LFSR 伪随机（避免 $urandom 在部分 Xsim 版本上种子不可控）
  // ---------------------------------------------------------------------------
  function automatic int lfsr_next(input int seed);
    int s;
    s = seed;
    s = s ^ (s << 13);
    s = s ^ (s >> 17);
    s = s ^ (s << 5);
    if (s == 0) s = 32'h0BAD_F00D;
    return s;
  endfunction

endpackage

`endif