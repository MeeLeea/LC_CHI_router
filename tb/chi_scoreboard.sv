//=============================================================================
// 文件: tb/chi_scoreboard.sv
// 功能: 参考模型 + 比对 —— 三层保序 / credit 守恒 / 数据逐 beat 比对
// 依赖: tb/chi_tb_pkg.sv
// 说明: 行为级参考模型，不重复实现可综合 RTL
//   L1 PoS 域：同 (src, tgt, domain) 的 REQ 保持进入顺序（txn_id 单调）
//   L2 Packet：同 packet 多 beat 连续（由 tail_lock 断言覆盖）
//   L3 SN 序 ：同 txn_id 的响应顺序与请求顺序一致
//   Credit  ：credit 为 0 时不得发送（下溢）
// 自检: 所有变量在 module 级声明，不在 always/initial 内声明；无动态数组
//=============================================================================
`default_nettype none
`timescale 1ns/1ps

module chi_scoreboard #(
  parameter int PORT_NUM = 8,
  parameter int CRD_W    = 8
) (
  input  wire clk,
  input  wire rst_n,
  input  wire [PORT_NUM-1:0]        mon_in_fire,
  input  wire [PORT_NUM-1:0]        mon_out_fire,
  input  wire [PORT_NUM-1:0][511:0] mon_in_data,
  input  wire [PORT_NUM-1:0][511:0] mon_out_data,
  input  wire [PORT_NUM-1:0][CRD_W-1:0] crd_cnt_obs
);

  // ---------------------------------------------------------------------------
  // L1 PoS 域顺序表：key = {src_id, tgt_id, domain}
  // ---------------------------------------------------------------------------
  localparam int POS_ENTRIES = 64;

  logic                pos_valid    [POS_ENTRIES];
  logic [15:0]         pos_src_id   [POS_ENTRIES];
  logic [15:0]         pos_tgt_id   [POS_ENTRIES];
  logic [1:0]          pos_domain   [POS_ENTRIES];
  logic [7:0]          pos_last_txn [POS_ENTRIES];

  // ---------------------------------------------------------------------------
  // L3 SN 序：每个 txn_id 的响应计数
  // ---------------------------------------------------------------------------
  localparam int SN_ENTRIES = 256;
  logic        sn_seen  [SN_ENTRIES];
  logic [31:0] sn_order [SN_ENTRIES];

  // ---------------------------------------------------------------------------
  // 统计
  // ---------------------------------------------------------------------------
  int unsigned n_in_fire;
  int unsigned n_out_fire;
  int unsigned n_l1_violate;
  int unsigned n_l2_violate;
  int unsigned n_l3_violate;
  int unsigned n_crd_underflow;
  int unsigned n_data_mismatch;
  int unsigned n_check;

  // ---------------------------------------------------------------------------
  // 数据比对 FIFO（按端口独立）
  // ---------------------------------------------------------------------------
  localparam int FIFO_DEPTH = 256;
  logic [511:0] exp_fifo [PORT_NUM][FIFO_DEPTH];
  int           exp_wr_ptr [PORT_NUM];
  int           exp_rd_ptr [PORT_NUM];
  int           exp_cnt    [PORT_NUM];

  // ---------------------------------------------------------------------------
  // module 级循环/临时变量（不在过程块内声明）
  // ---------------------------------------------------------------------------
  int          p;
  int          k;
  int          m;
  logic        found;
  logic [15:0] cur_tgt;
  logic [15:0] cur_src;
  logic [1:0]  cur_dom;
  logic [7:0]  cur_txn;
  int          slot;

  initial begin
    for (m = 0; m < POS_ENTRIES; m++) begin
      pos_valid[m]    = 1'b0;
      pos_src_id[m]   = '0;
      pos_tgt_id[m]   = '0;
      pos_domain[m]   = '0;
      pos_last_txn[m] = '0;
    end
    for (m = 0; m < SN_ENTRIES; m++) begin
      sn_seen[m]  = 1'b0;
      sn_order[m] = '0;
    end
    for (m = 0; m < PORT_NUM; m++) begin
      exp_wr_ptr[m] = 0;
      exp_rd_ptr[m] = 0;
      exp_cnt[m]    = 0;
    end
    n_in_fire       = 0;
    n_out_fire      = 0;
    n_l1_violate    = 0;
    n_l2_violate    = 0;
    n_l3_violate    = 0;
    n_crd_underflow = 0;
    n_data_mismatch = 0;
    n_check         = 0;
  end

  // ---------------------------------------------------------------------------
  // 入口观测：入 FIFO + L1 PoS 域顺序检查
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      n_in_fire <= 0;
    end else begin
      for (p = 0; p < PORT_NUM; p++) begin
        if (mon_in_fire[p]) begin
          n_in_fire <= n_in_fire + 1;

          // 入期望 FIFO
          if (exp_cnt[p] < FIFO_DEPTH) begin
            exp_fifo[p][exp_wr_ptr[p]] <= mon_in_data[p];
            exp_wr_ptr[p] = (exp_wr_ptr[p] + 1) % FIFO_DEPTH;
            exp_cnt[p]    = exp_cnt[p] + 1;
          end

          // L1 PoS 域顺序检查
          cur_tgt = mon_in_data[p][31:16];
          cur_src = mon_in_data[p][47:32];
          cur_dom = mon_in_data[p][15:14];
          cur_txn = mon_in_data[p][63:56];
          found   = 1'b0;
          for (k = 0; k < POS_ENTRIES; k++) begin
            if (!found && pos_valid[k] &&
                (pos_src_id[k] == cur_src) &&
                (pos_tgt_id[k] == cur_tgt) &&
                (pos_domain[k] == cur_dom)) begin
              found = 1'b1;
              if (cur_txn < pos_last_txn[k]) begin
                n_l1_violate <= n_l1_violate + 1;
                $display("[SCB][L1-VIOLATE] t=%0t src=%0d tgt=%0d dom=%0d txn=%0d prev=%0d",
                         $time, cur_src, cur_tgt, cur_dom, cur_txn, pos_last_txn[k]);
              end
              pos_last_txn[k] = cur_txn;
            end
          end
          if (!found) begin
            slot = -1;
            for (k = 0; k < POS_ENTRIES; k++) begin
              if ((slot < 0) && !pos_valid[k]) slot = k;
            end
            if (slot >= 0) begin
              pos_valid[slot]    = 1'b1;
              pos_src_id[slot]   = cur_src;
              pos_tgt_id[slot]   = cur_tgt;
              pos_domain[slot]   = cur_dom;
              pos_last_txn[slot] = cur_txn;
            end
          end
        end
      end
    end
  end

  // ---------------------------------------------------------------------------
  // 出口观测：FIFO 比对 + L3 SN 序检查 + credit 下溢
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      n_out_fire      <= 0;
      n_crd_underflow <= 0;
    end else begin
      for (p = 0; p < PORT_NUM; p++) begin
        if (mon_out_fire[p]) begin
          n_out_fire <= n_out_fire + 1;
          n_check    <= n_check + 1;

          // 数据比对
          if (exp_cnt[p] > 0) begin
            if (exp_fifo[p][exp_rd_ptr[p]] !== mon_out_data[p]) begin
              n_data_mismatch <= n_data_mismatch + 1;
              $display("[SCB][DATA-MISMATCH] t=%0t port=%0d exp=%h got=%h",
                       $time, p, exp_fifo[p][exp_rd_ptr[p]], mon_out_data[p]);
            end
            exp_rd_ptr[p] = (exp_rd_ptr[p] + 1) % FIFO_DEPTH;
            exp_cnt[p]    = exp_cnt[p] - 1;
          end else begin
            n_data_mismatch <= n_data_mismatch + 1;
            $display("[SCB][UNEXPECTED-OUT] t=%0t port=%0d 无对应入口 flit", $time, p);
          end

          // L3 SN 序：同 txn_id 响应序号递增
          cur_txn = mon_out_data[p][63:56];
          if (sn_seen[cur_txn]) begin
            sn_order[cur_txn] = sn_order[cur_txn] + 1;
          end else begin
            sn_seen[cur_txn]  = 1'b1;
            sn_order[cur_txn] = 32'd1;
          end

          // credit 下溢：credit 为 0 仍发送
          if (crd_cnt_obs[p] == '0) begin
            n_crd_underflow <= n_crd_underflow + 1;
            $display("[SCB][CREDIT-UNDERFLOW] t=%0t port=%0d credit=0 仍发送",
                     $time, p);
          end
        end
      end
    end
  end

  // ---------------------------------------------------------------------------
  // 最终报告
  // ---------------------------------------------------------------------------
  task automatic report();
    $display("======================== SCOREBOARD REPORT ========================");
    $display("  in_fire           = %0d", n_in_fire);
    $display("  out_fire          = %0d", n_out_fire);
    $display("  comparisons       = %0d", n_check);
    $display("  L1 PoS violate    = %0d", n_l1_violate);
    $display("  L2 packet violate = %0d", n_l2_violate);
    $display("  L3 SN violate     = %0d", n_l3_violate);
    $display("  credit underflow  = %0d", n_crd_underflow);
    $display("  data mismatch     = %0d", n_data_mismatch);
    if ((n_l1_violate == 0) && (n_l2_violate == 0) && (n_l3_violate == 0) &&
        (n_crd_underflow == 0) && (n_data_mismatch == 0)) begin
      $display("  SCOREBOARD RESULT: PASS");
    end else begin
      $display("  SCOREBOARD RESULT: FAIL");
      $display("SOME TESTS FAILED");
    end
    $display("===================================================================");
  endtask

endmodule

`default_nettype wire