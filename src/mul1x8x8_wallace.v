`timescale 1ns/1ps
// ===========================================================================
//  Discription : This file provides integrating MAC design - 1 single Mac version - 1x8x8
// Author: Hubo
// ===========================================================================
(* use_dsp = "no" *)
module mul1x8x8_wallace
(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        in_valid,
    input  wire [31:0] in_a,
    input  wire [31:0] in_b,
    output wire        out_valid,
    output wire [17:0] out_sum
`ifdef DEBUG_PRODUCT
  , output wire [15:0] product         // One for debug
`endif
);

    // -------- Lowest 8 bits-------
    wire [7:0] a0 = in_a[7:0];
    wire [7:0] b0 = in_b[7:0];

    // --------Wallace ---------------------------
    wire [15:0] p0;
    wire        v0;
    wallace_mult8 u0 (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid),
        .a(a0), .b(b0), .out_valid(v0), .product(p0)
    );

    // -------- 1-lane adder_tree (pass-through, 2 regs) ------
    wire [17:0] sum18;
    adder_tree_var #(
        .LANES (1),       // Switch LANES=1
        .INW   (16),
        .OUTW  (18)
    ) u_tree (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (v0),
        .prod_flat (p0), 
        .out_valid (out_valid),
        .sum       (sum18)
    );
    assign out_sum = sum18;

`ifdef DEBUG_PRODUCT
    assign product = p0;
`endif
endmodule
