`timescale 1ns/1ps
// ===========================================================================
//  Discription : This file provides integrating MAC design - 4 Macs version - 4x8x8 with boundary, stress and random test.
// Author: Hubo
// ===========================================================================
(* use_dsp = "no" *)
module mul4x8x8_wallace
(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        in_valid,
    input  wire [31:0] in_a,
    input  wire [31:0] in_b,
    output wire        out_valid,
    output wire [17:0] out_sum 
`ifdef DEBUG_PRODUCT
  , output wire [63:0] product
`endif
);

// ------------------------------------------------------------------
// 1. ------------slice
wire [7:0] a0 = in_a[ 7: 0], a1 = in_a[15: 8],
           a2 = in_a[23:16], a3 = in_a[31:24];
wire [7:0] b0 = in_b[ 7: 0], b1 = in_b[15: 8],
           b2 = in_b[23:16], b3 = in_b[31:24];

// 2.  -------Four multipliers----
wire [15:0] p0, p1, p2, p3;
wire        v0, v1, v2, v3;
wallace_mult8 u0 (.clk(clk), .rst_n(rst_n), .in_valid(in_valid), .a(a0), .b(b0), .out_valid(v0), .product(p0));
wallace_mult8 u1 (.clk(clk), .rst_n(rst_n), .in_valid(in_valid), .a(a1), .b(b1), .out_valid(v1), .product(p1));
wallace_mult8 u2 (.clk(clk), .rst_n(rst_n), .in_valid(in_valid), .a(a2), .b(b2), .out_valid(v2), .product(p2));
wallace_mult8 u3 (.clk(clk), .rst_n(rst_n), .in_valid(in_valid), .a(a3), .b(b3), .out_valid(v3), .product(p3));

// 3.  ------------------------1-cycle align register
reg [15:0] p0_r, p1_r, p2_r, p3_r;
reg        v_r;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        p0_r <= 0; p1_r <= 0; p2_r <= 0; p3_r <= 0; v_r <= 0;
    end else begin
        p0_r <= p0; p1_r <= p1; p2_r <= p2; p3_r <= p3;
        v_r  <= v0 & v1 & v2 & v3;          // all ready
    end
end

// 4. --------adder_tree_var -> adjust to 4 lane
wire [63:0] prod_bus = {p3_r, p2_r, p1_r, p0_r};
wire [17:0] sum18;
adder_tree_var #(
    .LANES (4),
    .INW   (16),
    .OUTW  (18) 
) u_tree (
    .clk       (clk),
    .rst_n     (rst_n),
    .in_valid  (v_r),
    .prod_flat (prod_bus),
    .out_valid (out_valid),
    .sum       (sum18)
);

assign out_sum = sum18;

`ifdef DEBUG_PRODUCT
assign product = prod_bus;
`endif
endmodule
