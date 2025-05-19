`timescale 1ns/1ps
// ============================================================================
//  vector_mac_top_param
//  ? ACTIVE_LANES = 1  ¡ú  synthesize only 1-MAC core
//  ? ACTIVE_LANES = 4  ¡ú  synthesize only 4-MAC core
//  ? other values      ¡ú  output fixed zero (placeholder)
// ============================================================================
module vector_mac_top_param #(
    parameter integer ELEMS        = 1000,   // vector length
    parameter integer ACTIVE_LANES = 4       // **set to 1 or 4 before impl**
)(
    input  wire        clk,
    input  wire        rst_n,       // async low
    input  wire        vec_valid,
    input  wire [31:0] vec_a,
    input  wire [31:0] vec_b,
    output wire        result_valid,
    output wire [31:0] result_sum
);

    // ------------------------------------------------------------------------
    // choose one MAC core according to ACTIVE_LANES
    // ------------------------------------------------------------------------
    wire        core_valid;
    wire [19:0] core_sum;

generate
    if (ACTIVE_LANES == 1) begin : g_mac1
        // ---------- 1-lane core ----------
        mul1x8x8_wallace u_core1 (
            .clk(clk), .rst_n(rst_n),
            .in_valid (vec_valid),
            .in_a     (vec_a),
            .in_b     (vec_b),
            .out_valid(core_valid),
            .out_sum  (core_sum[17:0])
        );
        assign core_sum[19:18] = 2'b00;
    end
    else if (ACTIVE_LANES == 4) begin : g_mac4
        // ---------- 4-lane core ----------
        mul4x8x8_wallace u_core4 (
            .clk(clk), .rst_n(rst_n),
            .in_valid (vec_valid),
            .in_a     (vec_a),
            .in_b     (vec_b),
            .out_valid(core_valid),
            .out_sum  (core_sum[17:0])
        );
        assign core_sum[19:18] = 2'b00;
    end
    else begin : g_stub
        // ---------- placeholder ----------
        assign core_valid = 1'b0;
        assign core_sum   = 20'd0;
    end
endgenerate

    // ------------------------------------------------------------------------
    // accumulator (already fixed beats_max bug)
    // ------------------------------------------------------------------------
    accumulator_var #(
        .ELEMS(ELEMS)
    ) u_acc (
        .clk         (clk),
        .rst_n       (rst_n),
        .in_valid    (core_valid),
        .partial_sum (core_sum),
        .lanes_i     (ACTIVE_LANES[4:0]),
        .final_sum   (result_sum),
        .result_valid(result_valid)
    );

endmodule
