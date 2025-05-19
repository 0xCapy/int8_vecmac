`timescale 1ns/1ps
// ===========================================================================
//  Discription : This file provides top layeer for all design
// How to use? By switching 'ACTIVE_LINE' in 1.4.8.16 to try different design - 1-16MACs
// Author: Hubo
// ===========================================================================
module vector_mac_top_param #(
    parameter integer ELEMS        = 1000,   // vector length
    parameter integer ACTIVE_LANES = 8       // 1 or 4 or 8 or 16
)(
    input  wire           clk,
    input  wire           rst_n,
    input  wire           vec_valid,
    input  wire [127:0]   vec_a,
    input  wire [127:0]   vec_b,
    output wire           result_valid,
    output wire [31:0]    result_sum
);

    // ---------------1. instantiate only the selected MAC core
    wire        core_vld;
    wire [19:0] core_sum;

generate
    if (ACTIVE_LANES == 1) begin : G_MAC1
        mul1x8x8_wallace u_core (
            .clk(clk), .rst_n(rst_n),
            .in_valid (vec_valid),
            .in_a     (vec_a[7:0]),
            .in_b     (vec_b[7:0]),
            .out_valid(core_vld),
            .out_sum  (core_sum[17:0])
        );
        assign core_sum[19:18] = 2'b0;
    end
    else if (ACTIVE_LANES == 4) begin : G_MAC4
        mul4x8x8_wallace u_core (
            .clk(clk), .rst_n(rst_n),
            .in_valid (vec_valid),
            .in_a     (vec_a[31:0]),
            .in_b     (vec_b[31:0]),
            .out_valid(core_vld),
            .out_sum  (core_sum[17:0])
        );
        assign core_sum[19:18] = 2'b0;
    end
    else if (ACTIVE_LANES == 8) begin : G_MAC8
        mul8x8x8_wallace u_core (
            .clk(clk), .rst_n(rst_n),
            .in_valid (vec_valid),
            .in_a     (vec_a[63:0]),
            .in_b     (vec_b[63:0]),
            .out_valid(core_vld),
            .out_sum  (core_sum[18:0])
        );
        assign core_sum[19] = 1'b0;
    end
    else if (ACTIVE_LANES == 16) begin : G_MAC16
        mul16x8x8_wallace u_core (
            .clk(clk), .rst_n(rst_n),
            .in_valid (vec_valid),
            .in_a     (vec_a),
            .in_b     (vec_b),
            .out_valid(core_vld),
            .out_sum  (core_sum)
        );
    end
    else begin : G_DUMMY 
        assign core_vld = vec_valid;
        assign core_sum = 20'd0;
    end
endgenerate
    // ------------------------2. accumulator (beats = ceil(ELEMS / ACTIVE_LANES))
    accumulator_var #(.ELEMS(ELEMS)) u_acc (
        .clk         (clk),
        .rst_n       (rst_n),
        .in_valid    (core_vld),
        .partial_sum (core_sum),
        .lanes_i     (ACTIVE_LANES[4:0]),
        .final_sum   (result_sum),
        .result_valid(result_valid)
    );

endmodule
