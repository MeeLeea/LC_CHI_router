//=============================================================================
// 文件: rtl/buffer/sram_wrapper.sv
// 功能: SRAM 行为模型 / 厂家宏统一封装（单端口读、单端口写 1R1W）
// 决策: D-04 已定 —— 统一抽象，仿真用行为模型，综合换宏/BRAM
//=============================================================================
`default_nettype none

module sram_wrapper #(
  parameter int DW    = 512,
  parameter int AW    = 5,
  parameter int DEPTH = 1 << AW,
  parameter int BANKS = 1
) (
  input  wire            clk,
  input  wire            rst_n,
  // 写口
  input  wire [BANKS-1:0] wr_en,
  input  wire [AW-1:0]    wr_addr,
  input  wire [DW-1:0]    wr_data,
  // 读口
  input  wire [BANKS-1:0] rd_en,
  input  wire [AW-1:0]    rd_addr,
  output logic [DW-1:0]   rd_data
);

  logic [DW-1:0] mem [DEPTH];

  always_ff @(posedge clk) begin
    if (|wr_en) mem[wr_addr] <= wr_data;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) rd_data <= '0;
    else if (|rd_en) rd_data <= mem[rd_addr];
  end

  // 综合时按 BANKS/DW/DEPTH 例化对应厂家宏（TBD：宏列表见 syn/scripts/syn.tcl）

endmodule

`default_nettype wire
