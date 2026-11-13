//=============================================================================
// 文件: rtl/chi_router_pkg.sv
// 功能: 全局参数 / 枚举 / struct 定义（必须最先编译）
// 规范: SystemVerilog-2017, 2 空格缩进
//=============================================================================
`ifndef CHI_ROUTER_PKG_SV
`define CHI_ROUTER_PKG_SV

package chi_router_pkg;

  // ---------------- 规模参数 ----------------
  parameter int PORT_NUM      = 8;                 // 双向端口数
  parameter int WIDE_W        = 512;               // 宽通道(REQ/DAT)位宽
  parameter int NARROW_W      = 256;               // 窄通道(RSP/SNP)位宽
  parameter int NODEID_W      = 16;                // CHI NodeID 位宽
  parameter int POOL_NUM      = 8;                 // Pool 数量
  parameter int BANK_PER_POOL = 16;                // 每 Pool bank 数
  parameter int FLIT_PER_BANK = 1;                 // 每 bank 存 flit 数
  parameter int QUEUE_NUM     = 512;               // 总 VOQ 队列数
  parameter int QUEUE_PER_IN  = 64;                // 每输入队列数
  parameter int QOS_CLASS     = 4;                 // QoS 优先级数

  // ---------------- 通道枚举 ----------------
  typedef enum logic [1:0] {
    CH_REQ = 2'd0,
    CH_RSP = 2'd1,
    CH_DAT = 2'd2,
    CH_SNP = 2'd3
  } chi_channel_e;

  // ---------------- 域 / 顺序 ----------------
  typedef enum logic [1:0] { DOMAIN_NON_SYNC = 2'd0, DOMAIN_OTHER = 2'd1 } chi_domain_e;
  typedef enum logic [2:0] { ORD_NONE = 3'd0, ORD_ANY = 3'd1, ORD_STRICT = 3'd2 } chi_order_e;

  // ---------------- 关键 Opcode 子集 ----------------
  typedef enum logic [7:0] {
    // REQ
    OP_REQ_READ_SHARED   = 8'h01,
    OP_REQ_READ_UNIQUE   = 8'h02,
    OP_REQ_MAKE_UNIQUE   = 8'h04,
    OP_REQ_CLEAN_UNIQUE  = 8'h07,
    OP_REQ_WRITE_UNIQUE  = 8'h09,
    // RSP
    OP_RSP_COMP          = 8'h40,
    OP_RSP_COMP_DATA     = 8'h41,
    // DAT
    OP_DAT_COMP_DATA     = 8'h50,
    OP_DAT_WRITE_DATA    = 8'h51,
    OP_DAT_NCB_WR_DATA   = 8'h52,
    // SNP
    OP_SNP_SHARED        = 8'h60,
    OP_SNP_UNIQUE        = 8'h61,
    OP_SNP_CLEAN_INVALID = 8'h62
  } chi_opcode_e;

  // ---------------- 字段抽取结果 ----------------
  typedef struct packed {
    chi_channel_e ch;         // 通道
    chi_opcode_e  opcode;     // 操作码
    logic [2:0]   size;       // 传输大小编码
    chi_order_e   order;      // 顺序要求
    chi_domain_e  domain;     // 一致性域
    logic [NODEID_W-1:0] tgt_id;   // 目标 NodeID
    logic [NODEID_W-1:0] src_id;   // 源 NodeID
    logic         qos;        // QoS 位
    logic [7:0]   txn_id;     // 事务 ID
  } chi_flit_info_t;

  // ---------------- 通用 valid/ready 反压 ----------------
  typedef struct packed {
    logic valid;
    logic ready;
  } vld_rdy_t;

  // ---------------- 内部宽/窄 beat ----------------
  typedef struct packed {
    logic [WIDE_W-1:0]   data;
    logic                parity;
    chi_flit_info_t      info;
  } beat_wide_t;

  typedef struct packed {
    logic [NARROW_W-1:0] data;
    logic                parity;
    chi_flit_info_t      info;
  } beat_narrow_t;

endpackage

`endif
