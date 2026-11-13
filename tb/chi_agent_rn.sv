//=============================================================================
// 文件: tb/chi_agent_rn.sv
// 功能: RN 侧激励 agent —— 发起 REQ；接收 RSP/DAT/SNP（可配反压）
// 依赖: tb/chi_tb_pkg.sv
// 说明: 纯 SV（无 UVM class），task 级激励，Vivado Xsim 可直接编译运行
// 约束: 不实现任何可综合 RTL 逻辑，仅产生/吸收接口波形
// 自检: 任务参数使用「位置参数」调用（Xsim 对命名参数 : 语法支持不稳）
//=============================================================================
`default_nettype none
`timescale 1ns/1ps

module chi_agent_rn #(
  parameter int PORT_ID  = 0,
  parameter int WIDE_W   = 512,
  parameter int NARROW_W = 256,
  parameter int BP_MODE  = 0,     // 0=ready恒1  1=rand 50%  2=ready恒0(停流)
  parameter int BP_SEED  = 32'h1234_5678
) (
  input  wire                clk,
  input  wire                rst_n,
  // 链路发送（至 DUT 入口）
  output logic               req_valid,
  input  wire                req_ready,
  output logic [WIDE_W-1:0]  req_data,
  // 链路接收（自 DUT 出口）
  input  wire                snp_valid,
  output logic               snp_ready,
  input  wire [NARROW_W-1:0] snp_data,
  input  wire                rsp_valid,
  output logic               rsp_ready,
  input  wire [NARROW_W-1:0] rsp_data,
  input  wire                dat_valid,
  output logic               dat_ready,
  input  wire [WIDE_W-1:0]   dat_data
);

  logic [WIDE_W-1:0] req_data_q;
  logic              req_valid_q;
  int                bp_seed;

  // 统计（供报告读取）
  int unsigned n_rsp_rcvd;
  int unsigned n_dat_rcvd;
  int unsigned n_snp_rcvd;
  int unsigned n_req_sent;

  assign req_valid = req_valid_q;
  assign req_data  = req_data_q;

  initial begin
    req_valid_q = 1'b0;
    req_data_q  = '0;
    snp_ready   = 1'b0;
    rsp_ready   = 1'b0;
    dat_ready   = 1'b0;
    bp_seed     = BP_SEED;
    n_rsp_rcvd  = 0;
    n_dat_rcvd  = 0;
    n_snp_rcvd  = 0;
    n_req_sent  = 0;
  end

  // ---------------------------------------------------------------------------
  // 接收侧 ready 生成（反压/停流场景）
  // ---------------------------------------------------------------------------
  function automatic logic next_ready(input int mode);
    logic r;
    bp_seed = chi_tb_pkg::lfsr_next(bp_seed);
    case (mode)
      0:       r = 1'b1;
      1:       r = bp_seed[3];      // 约 50% 随机就绪
      default: r = 1'b0;            // 恒反压
    endcase
    return r;
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rsp_ready <= 1'b0;
      dat_ready <= 1'b0;
      snp_ready <= 1'b0;
    end else begin
      rsp_ready <= next_ready(BP_MODE);
      dat_ready <= next_ready(BP_MODE);
      snp_ready <= next_ready(BP_MODE);
    end
  end

  // 接收计数
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      n_rsp_rcvd <= 0;
      n_dat_rcvd <= 0;
      n_snp_rcvd <= 0;
    end else begin
      if (rsp_valid && rsp_ready) n_rsp_rcvd <= n_rsp_rcvd + 1;
      if (dat_valid && dat_ready) n_dat_rcvd <= n_dat_rcvd + 1;
      if (snp_valid && snp_ready) n_snp_rcvd <= n_snp_rcvd + 1;
    end
  end

  // ---------------------------------------------------------------------------
  // REQ 发送任务（位置参数）：
  //   send_req(opcode, size, order, domain, tgt_id, src_id, qos, txn_id, payload)
  //   严格 valid/ready 握手；valid 拉高后保持到 ready；data 在 valid 期间稳定
  // ---------------------------------------------------------------------------
  task automatic send_req(
    input logic [7:0]          opcode,
    input logic [2:0]          size,
    input logic [2:0]          order,
    input logic [1:0]          domain,
    input logic [15:0]         tgt_id,
    input logic [15:0]         src_id,
    input logic                qos,
    input logic [7:0]          txn_id,
    input logic [WIDE_W-1:0]   payload
  );
    @(negedge clk);
    req_data_q  = chi_tb_pkg::pack_wide_flit(opcode, size, order, domain,
                                             tgt_id, src_id, qos, txn_id, payload);
    req_valid_q = 1'b1;
    @(posedge clk);
    while (!req_ready) @(posedge clk);
    @(negedge clk);
    req_valid_q = 1'b0;
    req_data_q  = '0;
    n_req_sent  = n_req_sent + 1;
  endtask

  // 背靠背发送（valid 不撤销，用于吞吐/拥塞场景）
  task automatic send_req_b2b(
    input logic [7:0]          opcode,
    input logic [2:0]          size,
    input logic [2:0]          order,
    input logic [1:0]          domain,
    input logic [15:0]         tgt_id,
    input logic [15:0]         src_id,
    input logic                qos,
    input logic [7:0]          txn_id,
    input logic [WIDE_W-1:0]   payload
  );
    req_data_q  = chi_tb_pkg::pack_wide_flit(opcode, size, order, domain,
                                             tgt_id, src_id, qos, txn_id, payload);
    req_valid_q = 1'b1;
    @(posedge clk);
    while (!req_ready) @(posedge clk);
    n_req_sent = n_req_sent + 1;
    @(negedge clk);
  endtask

  task automatic stop_req();
    @(negedge clk);
    req_valid_q = 1'b0;
    req_data_q  = '0;
  endtask

endmodule

`default_nettype wire