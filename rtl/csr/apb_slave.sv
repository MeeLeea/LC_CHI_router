//=============================================================================
// 文件: rtl/csr/apb_slave.sv
// 功能: APB4 从机（0/1 等待可配）
//=============================================================================
`default_nettype none

module apb_slave #(
  parameter int AW = 16,
  parameter int DW = 32
) (
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
  // 内部寄存器访问
  output logic         reg_wr,
  output logic         reg_rd,
  output logic [AW-1:0] reg_addr,
  output logic [DW-1:0] reg_wdata,
  input  wire [DW-1:0]  reg_rdata
);

  assign reg_wr = psel & penable & pwrite;
  assign reg_rd = psel & penable & ~pwrite;
  assign reg_addr  = paddr;
  assign reg_wdata = pwdata;
  assign prdata = reg_rdata;
  assign pready  = 1'b1;   // 0-wait 默认（可配 1-wait，见 design_spec）
  assign pslverr = 1'b0;

endmodule

`default_nettype wire
