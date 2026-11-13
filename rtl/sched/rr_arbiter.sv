//=============================================================================
// 文件: rtl/sched/rr_arbiter.sv
// 功能: RR 仲裁（窄通道 RSP+SNP）
//=============================================================================
`default_nettype none

module rr_arbiter #(
  parameter int N = 8
) (
  input  wire           clk,
  input  wire           rst_n,
  input  wire [N-1:0]   req,
  output logic [N-1:0]  grant
);

  logic [$clog2(N)-1:0] ptr;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) ptr <= '0;
    else if (|grant) ptr <= (ptr + 1'b1); // 简化实现，待加优先级掩码
  end

  always_comb begin
    grant = '0;
    // 复位期间强制 grant=0（组合输出不依赖寄存器状态，须显式门控）
    if (rst_n) begin
      for (int i = 0; i < N; i++) begin
        int idx = (ptr + i) % N;
        if (req[idx] && !(|grant)) grant[idx] = 1'b1;
      end
    end
  end

endmodule

`default_nettype wire
