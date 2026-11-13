//=============================================================================
// 文件: tb/chi_agent_hn.sv
// 功能: HN 侧响应 agent —— 接收 REQ；回送 RSP/DAT；可发起反向 SNP
// 依赖: tb/chi_tb_pkg.sv
// 说明: 纯 SV（无 UVM class），task 级激励
// 关键: BP_MODE=0 时 req_ready 恒 1，放行 DUT 出口
// 自检: 任务参数使用「位置参数」调用（Xsim 对命名参数 : 语法支持不稳）
//=============================================================================
`default_nettype none
`timescale 1ns/1ps

module chi_agent_hn #(
  parameter int PORT_ID  = 0,
  parameter int WIDE_W   = 512,
  parameter int NARROW_W = 256,
  parameter int BP_MODE  = 0,      // 0=ready恒1  1=rand 50%  2=ready恒0
  parameter int BP_SEED  = 32'h8765_4321
) (
  input  wire                clk,
  input  wire                rst_n,
  // 自 DUT 出口接收 REQ
  input  wire                req_valid,
  output logic               req_ready,
  input  wire [WIDE_W-1:0]   req_data,
  // 至 DUT 入口发送 RSP
  output logic               rsp_valid,
  input  wire                rsp_ready,
  output logic [NARROW_W-1:0] rsp_data,
  // 至 DUT 入口发送 DAT
  output logic               dat_valid,
  input  wire                dat_ready,
  output logic [WIDE_W-1:0]  dat_data,
  // 至 DUT 入口发送 SNP
  output logic               snp_valid,
  input  wire                snp_ready,
  output logic [NARROW_W-1:0] snp_data
);

  logic [WIDE_W-1:0]   dat_data_q;
  logic                dat_valid_q;
  logic [NARROW_W-1:0] rsp_data_q;
  logic                rsp_valid_q;
  logic [NARROW_W-1:0] snp_data_q;
  logic                snp_valid_q;
  int                  bp_seed;

  // 观测统计
  int unsigned n_req_rcvd;
  int unsigned n_rsp_sent;
  int unsigned n_dat_sent;
  int unsigned n_snp_sent;

  assign rsp_valid = rsp_valid_q;
  assign rsp_data  = rsp_data_q;
  assign dat_valid = dat_valid_q;
  assign dat_data  = dat_data_q;
  assign snp_valid = snp_valid_q;
  assign snp_data  = snp_data_q;

  initial begin
    req_ready   = 1'b0;
    rsp_valid_q = 1'b0;
    rsp_data_q  = '0;
    dat_valid_q = 1'b0;
    dat_data_q  = '0;
    snp_valid_q = 1'b0;
    snp_data_q  = '0;
    bp_seed     = BP_SEED;
    n_req_rcvd  = 0;
    n_rsp_sent  = 0;
    n_dat_sent  = 0;
    n_snp_sent  = 0;
  end

  function automatic logic next_ready(input int mode);
    logic r;
    bp_seed = chi_tb_pkg::lfsr_next(bp_seed);
    case (mode)
      0:       r = 1'b1;
      1:       r = bp_seed[5];
      default: r = 1'b0;
    endcase
    return r;
  endfunction

  // ---------------------------------------------------------------------------
  // REQ 接收侧 ready + 观测
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      req_ready  <= 1'b0;
      n_req_rcvd <= 0;
    end else begin
      req_ready <= next_ready(BP_MODE);
      if (req_valid && req_ready) n_req_rcvd <= n_req_rcvd + 1;
    end
  end

  // ---------------------------------------------------------------------------
  // RSP 发送（位置参数）：
  //   send_rsp(opcode, domain, tgt_id, src_id, txn_id, payload)
  // ---------------------------------------------------------------------------
  task automatic send_rsp(
    input logic [7:0]          opcode,
    input logic [1:0]          domain,
    input logic [15:0]         tgt_id,
    input logic [15:0]         src_id,
    input logic [7:0]          txn_id,
    input logic [NARROW_W-1:0] payload
  );
    @(negedge clk);
    rsp_data_q  = chi_tb_pkg::pack_narrow_flit(opcode, 3'd0, 3'd0, domain,
                                               tgt_id, src_id, 1'b0, txn_id, payload);
    rsp_valid_q = 1'b1;
    @(posedge clk);
    while (!rsp_ready) @(posedge clk);
    @(negedge clk);
    rsp_valid_q = 1'b0;
    rsp_data_q  = '0;
    n_rsp_sent  = n_rsp_sent + 1;
  endtask

  // ---------------------------------------------------------------------------
  // DAT 发送（位置参数）：
  //   send_dat(opcode, domain, tgt_id, src_id, txn_id, payload, is_last)
  //   is_last 编码进 payload 最高位（TB 私有约定，scoreboard 据此判尾）
  // ---------------------------------------------------------------------------
  task automatic send_dat(
    input logic [7:0]          opcode,
    input logic [1:0]          domain,
    input logic [15:0]         tgt_id,
    input logic [15:0]         src_id,
    input logic [7:0]          txn_id,
    input logic [WIDE_W-1:0]   payload,
    input logic                is_last
  );
    logic [WIDE_W-1:0] d;
    @(negedge clk);
    d = chi_tb_pkg::pack_wide_flit(opcode, 3'd0, 3'd0, domain,
                                   tgt_id, src_id, 1'b0, txn_id, payload);
    d[WIDE_W-1] = is_last;
    dat_data_q  = d;
    dat_valid_q = 1'b1;
    @(posedge clk);
    while (!dat_ready) @(posedge clk);
    @(negedge clk);
    dat_valid_q = 1'b0;
    dat_data_q  = '0;
    n_dat_sent  = n_dat_sent + 1;
  endtask

  // ---------------------------------------------------------------------------
  // SNP 发送（位置参数）：
  //   send_snp(opcode, domain, tgt_id, src_id, txn_id, payload)
  // ---------------------------------------------------------------------------
  task automatic send_snp(
    input logic [7:0]          opcode,
    input logic [1:0]          domain,
    input logic [15:0]         tgt_id,
    input logic [15:0]         src_id,
    input logic [7:0]          txn_id,
    input logic [NARROW_W-1:0] payload
  );
    @(negedge clk);
    snp_data_q  = chi_tb_pkg::pack_narrow_flit(opcode, 3'd0, 3'd0, domain,
                                               tgt_id, src_id, 1'b0, txn_id, payload);
    snp_valid_q = 1'b1;
    @(posedge clk);
    while (!snp_ready) @(posedge clk);
    @(negedge clk);
    snp_valid_q = 1'b0;
    snp_data_q  = '0;
    n_snp_sent  = n_snp_sent + 1;
  endtask

endmodule

`default_nettype wire