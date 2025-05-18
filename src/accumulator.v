// ============================================================================
//  Generic accumulator - adaptable to 1/2/4/8/16-lane adder_tree_var
//  Author  : <your name>        Platform : Vivado 2021.1
// ----------------------------------------------------------------------------
//  Parameters
//    LANES      : parallel MAC units (1/2/4/8/16)
//    ELEMS      : elements in one dot-product (e.g. 1000)
//    INW_BASE   : 16-bit partial product width (8×8)
// ----------------------------------------------------------------------------
//  Derived
//    BEATS  = ceil(ELEMS / LANES)            // how many partial_sum per result
//    STAGES = (LANES < 4) ? 2 : $clog2(LANES)
//    W_IN   = INW_BASE + STAGES              // adder_tree_var output width
//    W_ACC  = W_IN + $clog2(BEATS)           // enough guard bits
// ============================================================================
`timescale 1ns/1ps
module accumulator #(
    parameter integer LANES     = 4,         // 1/2/4/8/16
    parameter integer ELEMS     = 1000,      // vector length
    parameter integer INW_BASE  = 16,

    // ----------- derived, normally keep default ---------------------------
    parameter integer BEATS  = (ELEMS + LANES - 1) / LANES,
    parameter integer STAGES = (LANES < 4) ? 2 : $clog2(LANES),
    parameter integer W_IN   = INW_BASE + STAGES,           // 1-2-4 ?18, 8?19, 16?20
    parameter integer W_ACC  = W_IN + $clog2(BEATS)         // full-scale accumulator
)(
    input  wire                 clk,
    input  wire                 rst_n,        // async low
    input  wire                 in_valid,     // one beat from adder_tree
    input  wire [W_IN-1:0]      partial_sum,  // OUTW of adder_tree_var
    output reg  [W_ACC-1:0]     final_sum,    // dot-product result
    output reg                  result_valid
);
    // running accumulation & beat counter
    reg [W_ACC-1:0] acc_reg;
    localparam CNT_W = (BEATS <= 1) ? 1 : $clog2(BEATS);
    reg [CNT_W-1:0] cnt;
    wire last_beat = (cnt == BEATS-1);

    // ------------------------------------------------ main logic ----------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_reg      <= {W_ACC{1'b0}};
            cnt          <= {CNT_W{1'b0}};
            final_sum    <= {W_ACC{1'b0}};
            result_valid <= 1'b0;
        end
        else if (in_valid) begin
            acc_reg   <= last_beat ? {W_ACC{1'b0}}
                                   : acc_reg + partial_sum;
            cnt       <= last_beat ? {CNT_W{1'b0}}
                                   : cnt + 1'b1;

            final_sum <= acc_reg + partial_sum; // 本拍的累加結果
            result_valid <= last_beat;          // 發脈衝
        end
        else begin
            result_valid <= 1'b0;               // 清脈衝
        end
    end
endmodule
