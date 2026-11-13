//=============================================================================
// 文件: rtl/csr/pmu_counters.sv
// 功能: 吞吐 / 占用 / 冲突计数
//=============================================================================
`default_nettype none

module pmu_counters #(
  parameter int PORT_NUM = 8,
  parameter int CNT_W    = 32
) (
  input  wire clk,
  input  wire rst_n,
  input  wire [PORT_NUM-1:0] evt_flit_out,     // 吞吐事件
  input  wire [PORT_NUM-1:0] evt_voq_conflict, // 冲突事件
  input  wire [PORT_NUM-1:0][15:0] occupancy,  // 占用快照
  input  wire                pmu_snap,         // 快照/清零
  output logic [CNT_W-1:0]   cnt_flit_out,
  output logic [CNT_W-1:0]   cnt_conflict,
  output logic [PORT_NUM-1:0][15:0] occ_snap
);

  // TODO: 分端口计数 + saturating / 快照逻辑

endmodule

`default_nettype wire
