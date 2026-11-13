//=============================================================================
// 文件: rtl/csr/qos_regs.sv
// 功能: 权重 / 阈值 / 优先级映射寄存器
//=============================================================================
`default_nettype none

module qos_regs #(
  parameter int QOS_CLASS = 4,
  parameter int DW        = 12
) (
  input  wire clk,
  input  wire rst_n,
  input  wire wr_en,
  input  wire [AW-1:0] addr,
  input  wire [31:0]   wdata,
  output logic [QOS_CLASS-1:0][DW-1:0] weight,
  output logic [QOS_CLASS-1:0][DW-1:0] bucket_max
);

  localparam int AW = 4;

  // TODO: 寄存器地址映射（见 design_spec 第 6 章 CSR Map，待补）

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      weight     <= '{default: DW'(1)};
      bucket_max <= '{default: DW'(64)};
    end else if (wr_en) begin
      // 按 addr 写入对应字段
    end
  end

endmodule

`default_nettype wire
