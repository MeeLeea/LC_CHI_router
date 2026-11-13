//=============================================================================
// 文件: rtl/buffer/pool_credit.sv
// 功能: per-pool credit 计数与回补
//=============================================================================
`default_nettype none

module pool_credit #(
  parameter int POOL_NUM = 8,
  parameter int CRD_W    = 8,
  parameter int INIT_CRD = 16
) (
  input  wire              clk,
  input  wire              rst_n,
  input  wire [POOL_NUM-1:0] alloc_en,   // 分配一个 flit
  input  wire [POOL_NUM-1:0] free_en,    // 回补一个 flit
  output logic [POOL_NUM-1:0] crd_avail, // 仍有 credit
  output logic [POOL_NUM-1:0][CRD_W-1:0] crd_cnt
);

  genvar g;
  generate
    for (g = 0; g < POOL_NUM; g++) begin : g_crd
      always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) crd_cnt[g] <= CRD_W'(INIT_CRD);
        else begin
          unique case ({alloc_en[g], free_en[g]})
            2'b10:   crd_cnt[g] <= crd_cnt[g] - 1'b1;
            2'b01:   crd_cnt[g] <= crd_cnt[g] + 1'b1;
            default: crd_cnt[g] <= crd_cnt[g];
          endcase
        end
      end
      assign crd_avail[g] = (crd_cnt[g] != '0);
    end
  endgenerate

endmodule

`default_nettype wire
