//=============================================================================
// 文件: tb/chi_coverage.sv
// 功能: 功能覆盖率收集 —— 适配 Vivado Xsim 的 covergroup
// 说明:
//   - 所有 bins/cross 标识符避开 SV 保留字（不用 byte/bit/logic/int/type/
//     void/enum/struct/union/class 等），统一加 b_/x_/cp_ 前后缀
//   - 同一 coverpoint 内 bins 取值集合互不重叠（Xsim 对重复值报错）
//   - covergroup 定义在 module 内（Xsim 对 package 内 covergroup 支持较弱）
//   - 采样点挂在真实存在的顶层接口上
//=============================================================================
`default_nettype none
`timescale 1ns/1ps

module chi_coverage #(
  parameter int PORT_NUM = 8
) (
  input wire clk,
  input wire rst_async_n,
  input wire [PORT_NUM-1:0][3:0]   link_in_valid,
  input wire [PORT_NUM-1:0][3:0]   link_in_ready,
  input wire [PORT_NUM-1:0][3:0]   link_out_valid,
  input wire [PORT_NUM-1:0][3:0]   link_out_ready,
  input wire [PORT_NUM-1:0][511:0] link_in_req,
  input wire [PORT_NUM-1:0][511:0] link_in_dat,
  input wire [PORT_NUM-1:0][255:0] link_in_rsp,
  input wire [PORT_NUM-1:0][255:0] link_in_snp,
  input wire        pclk,
  input wire        presetn,
  input wire        psel,
  input wire        penable,
  input wire        pwrite,
  input wire [15:0] paddr
);

  // ---------------------------------------------------------------------------
  // 采样辅助信号（module 级）
  // ---------------------------------------------------------------------------
  logic        in_fire_any;
  logic        out_fire_any;
  logic [2:0]  in_port_idx;
  logic [2:0]  out_port_idx;
  logic [1:0]  in_grp;
  logic [1:0]  in_qos;
  logic [7:0]  in_opcode;
  logic [2:0]  in_order;
  logic [1:0]  in_domain;
  logic [2:0]  out_bp_lvl;
  logic        apb_access;
  logic [3:0]  apb_region;

  int i, j;

  // ---------------------------------------------------------------------------
  // 入口活跃端口提取：优先级 REQ > DAT > RSP > SNP，取最低活跃端口
  // ---------------------------------------------------------------------------
  always_comb begin : proc_in_scan
    in_fire_any  = 1'b0;
    in_port_idx  = 3'd0;
    in_grp       = 2'd0;
    in_opcode    = 8'h00;
    in_order     = 3'd0;
    in_domain    = 2'd0;
    in_qos       = 2'd0;

    for (i = PORT_NUM - 1; i >= 0; i--) begin
      if (link_in_valid[i][0] && link_in_ready[i][0]) begin
        in_fire_any = 1'b1;
        in_port_idx = i[2:0];
        in_grp      = 2'd0;
      end else if (link_in_valid[i][2] && link_in_ready[i][2]) begin
        in_fire_any = 1'b1;
        in_port_idx = i[2:0];
        in_grp      = 2'd1;
      end else if (link_in_valid[i][1] && link_in_ready[i][1]) begin
        in_fire_any = 1'b1;
        in_port_idx = i[2:0];
        in_grp      = 2'd2;
      end else if (link_in_valid[i][3] && link_in_ready[i][3]) begin
        in_fire_any = 1'b1;
        in_port_idx = i[2:0];
        in_grp      = 2'd2;
      end
    end

    // 字段提取（按 flit_decode.sv 布局，取自 REQ 通道）
    in_opcode = link_in_req[in_port_idx][7:0];
    in_order  = link_in_req[in_port_idx][13:11];
    in_domain = link_in_req[in_port_idx][15:14];
    in_qos    = link_in_req[in_port_idx][49:48];
  end

  // ---------------------------------------------------------------------------
  // 出口活跃端口 + 反压等级
  // ---------------------------------------------------------------------------
  always_comb begin : proc_out_scan
    out_fire_any = 1'b0;
    out_port_idx = 3'd0;
    out_bp_lvl   = 3'd0;

    for (j = PORT_NUM - 1; j >= 0; j--) begin
      if ((link_out_valid[j][0] && link_out_ready[j][0]) ||
          (link_out_valid[j][2] && link_out_ready[j][2])) begin
        out_fire_any = 1'b1;
        out_port_idx = j[2:0];
      end
    end

    // 反压等级：出口 valid=1 且 ready=0 的通道总数（饱和到 7）
    for (j = 0; j < PORT_NUM; j++) begin
      for (i = 0; i < 4; i++) begin
        if (link_out_valid[j][i] && !link_out_ready[j][i]) begin
          if (out_bp_lvl != 3'd7) out_bp_lvl = out_bp_lvl + 3'd1;
        end
      end
    end
  end

  // ---------------------------------------------------------------------------
  // APB 地址区间
  // ---------------------------------------------------------------------------
  assign apb_access = psel && penable;

  always_comb begin : proc_apb_region
    case (paddr[15:8])
      8'h00:   apb_region = 4'd0;   // ROUTE + QOS
      8'h01:   apb_region = 4'd1;   // PMU
      8'h02:   apb_region = 4'd2;   // ERR
      8'h03:   apb_region = 4'd3;   // CREDIT
      default: apb_region = 4'd15;  // 非法地址
    endcase
  end

  // ---------------------------------------------------------------------------
  // CG1: 入口通道 / 端口 / QoS / 域 / 顺序 / Opcode
  // ---------------------------------------------------------------------------
  covergroup cg_ingress_traffic @(posedge clk);
    option.per_instance = 1;
    option.name         = "cg_ingress_traffic";

    cp_in_port: coverpoint in_port_idx iff (in_fire_any) {
      bins b_p0 = {3'd0};
      bins b_p1 = {3'd1};
      bins b_p2 = {3'd2};
      bins b_p3 = {3'd3};
      bins b_p4 = {3'd4};
      bins b_p5 = {3'd5};
      bins b_p6 = {3'd6};
      bins b_p7 = {3'd7};
    }

    cp_in_grp: coverpoint in_grp iff (in_fire_any) {
      bins b_grp_req     = {2'd0};
      bins b_grp_dat     = {2'd1};
      bins b_grp_rsp_snp = {2'd2};
      bins b_grp_rsvd    = {2'd3};
    }

    cp_in_qos: coverpoint in_qos iff (in_fire_any) {
      bins b_q0 = {2'd0};
      bins b_q1 = {2'd1};
      bins b_q2 = {2'd2};
      bins b_q3 = {2'd3};
    }

    cp_in_domain: coverpoint in_domain iff (in_fire_any) {
      bins b_dom0 = {2'd0};
      bins b_dom1 = {2'd1};
      bins b_dom_x = {2'd2, 2'd3};   // 非法编码
    }

    cp_in_order: coverpoint in_order iff (in_fire_any) {
      bins b_ord_none   = {3'd0};
      bins b_ord_any    = {3'd1};
      bins b_ord_strict = {3'd2};
      bins b_ord_other  = {[3'd3:3'd7]};
    }

    // Opcode 按高 3 位分族，取值互不重叠
    cp_in_op_hi: coverpoint in_opcode[7:5] iff (in_fire_any) {
      bins b_hi_0 = {3'b000};   // REQ 族（0x01~0x1F）
      bins b_hi_1 = {3'b001};
      bins b_hi_2 = {3'b010};   // RSP 族（0x40~0x5F）
      bins b_hi_3 = {3'b011};   // SNP 族（0x60~0x7F）
      bins b_hi_4 = {3'b100};
      bins b_hi_5 = {3'b101};
      bins b_hi_6 = {3'b110};
      bins b_hi_7 = {3'b111};
    }

    // 交叉：端口 × QoS —— 验证 VOQ 索引 {out_port, ch_grp, qos} 组合覆盖
    x_port_qos: cross cp_in_port, cp_in_qos;
    // 交叉：端口 × 域 —— PoS 域保序需覆盖各组合
    x_port_dom: cross cp_in_port, cp_in_domain;
    // 交叉：通道组 × 顺序要求
    x_grp_ord: cross cp_in_grp, cp_in_order;
  endgroup

  // ---------------------------------------------------------------------------
  // CG2: 出口端口 × 反压等级
  // ---------------------------------------------------------------------------
  covergroup cg_egress_backpressure @(posedge clk);
    option.per_instance = 1;
    option.name         = "cg_egress_backpressure";

    cp_out_port: coverpoint out_port_idx iff (out_fire_any) {
      bins b_p0 = {3'd0};
      bins b_p1 = {3'd1};
      bins b_p2 = {3'd2};
      bins b_p3 = {3'd3};
      bins b_p4 = {3'd4};
      bins b_p5 = {3'd5};
      bins b_p6 = {3'd6};
      bins b_p7 = {3'd7};
    }

    cp_bp_lvl: coverpoint out_bp_lvl {
      bins b_bp_none = {3'd0};
      bins b_bp_low  = {3'd1};
      bins b_bp_mid  = {[3'd2:3'd4]};
      bins b_bp_high = {[3'd5:3'd7]};
    }

    x_port_bp: cross cp_out_port, cp_bp_lvl;
  endgroup

  // ---------------------------------------------------------------------------
  // CG3: APB 访问覆盖
  // ---------------------------------------------------------------------------
  covergroup cg_apb_access @(posedge pclk);
    option.per_instance = 1;
    option.name         = "cg_apb_access";

    cp_apb_region: coverpoint apb_region iff (apb_access) {
      bins b_route_qos = {4'd0};
      bins b_pmu       = {4'd1};
      bins b_err       = {4'd2};
      bins b_credit    = {4'd3};
      bins b_illegal   = {4'd15};
    }

    cp_apb_dir: coverpoint pwrite iff (apb_access) {
      bins b_read  = {1'b0};
      bins b_write = {1'b1};
    }

    x_region_dir: cross cp_apb_region, cp_apb_dir;
  endgroup

  // ---------------------------------------------------------------------------
  // 实例化
  // ---------------------------------------------------------------------------
  cg_ingress_traffic     cg_ing;
  cg_egress_backpressure cg_egr;
  cg_apb_access          cg_apb;

  initial begin
    cg_ing = new();
    cg_egr = new();
    cg_apb = new();
  end

endmodule

`default_nettype wire