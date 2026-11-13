//=============================================================================
// 文件: rtl/egress/credit_mgr.sv
// 功能: 下游 L-credit 记账 + 上游回补
//=============================================================================
`default_nettype none

module credit_mgr #(
  parameter int CH_NUM = 4,
  parameter int CRD_W  = 8,
  parameter int INIT_CRD = 16
) (
  input  wire               clk,
  input  wire               rst_n,
  input  wire [CH_NUM-1:0]  send_flit,     // 本周期向下游发 flit
  input  wire [CH_NUM-1:0]  crd_return,    // 下游返回 credit
  output logic [CH_NUM-1:0] crd_avail
);

  logic [CH_NUM-1:0][CRD_W-1:0] cred;

  genvar g;
  generate
    for (g = 0; g < CH_NUM; g++) begin : g_cred
      always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)                cred[g] <= CRD_W'(INIT_CRD);
        else if (send_flit[g] && !crd_return[g]) cred[g] <= cred[g] - 1'b1;
        else if (!send_flit[g] && crd_return[g]) cred[g] <= cred[g] + 1'b1;
      end
      assign crd_avail[g] = (cred[g] != '0);
    end
  endgenerate

endmodule

`default_nettype wire
