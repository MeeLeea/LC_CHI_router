//=============================================================================
// 文件: rtl/csr/csr_subsys.sv
// 功能: CSR 子系统顶层（APB4 -> route_table / qos_regs / pmu / err）
//=============================================================================
`default_nettype none

module csr_subsys #(
  parameter int AW       = 16,
  parameter int DW       = 32,
  parameter int PORT_NUM = 8,
  parameter int QOS_CLASS = 4
) (
  // APB4
  input  wire          pclk,
  input  wire          presetn,
  input  wire          psel,
  input  wire          penable,
  input  wire          pwrite,
  input  wire [AW-1:0] paddr,
  input  wire [DW-1:0] pwdata,
  input  wire [DW/8-1:0] pstrb,
  output logic [DW-1:0] prdata,
  output logic         pready,
  output logic         pslverr,
  // 对外配置输出
  output logic [PORT_NUM-1:0][2:0] route_default_port,
  output logic [QOS_CLASS-1:0][11:0] qos_weight,
  output logic [QOS_CLASS-1:0][11:0] qos_bucket_max,
  // 错误 / 中断
  input  wire [7:0]     err_evt,
  output logic          irq
);

  // 子模块：apb_slave / route_table / qos_regs / pmu_counters / err_regs

endmodule

`default_nettype wire
