`timescale 1ns/1ps
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
  , output wire [63:0] product   // optional debug
`endif
);

// ------------------------------------------------------------------
// 1-D slicing - pure Verilog-2001
// ------------------------------------------------------------------
wire [7:0] a0 = in_a[ 7: 0];
wire [7:0] a1 = in_a[15: 8];
wire [7:0] a2 = in_a[23:16];
wire [7:0] a3 = in_a[31:24];

wire [7:0] b0 = in_b[ 7: 0];
wire [7:0] b1 = in_b[15: 8];
wire [7:0] b2 = in_b[23:16];
wire [7:0] b3 = in_b[31:24];

// ------------------------------------------------------------------
// Four 8¡Á8 Wallace multipliers
// ------------------------------------------------------------------
wire [15:0] p0, p1, p2, p3;
wire        v0, v1, v2, v3;

wallace_mult8 u0 (.clk(clk), .rst_n(rst_n), .in_valid(in_valid),
                  .a(a0), .b(b0), .out_valid(v0), .product(p0));
wallace_mult8 u1 (.clk(clk), .rst_n(rst_n), .in_valid(in_valid),
                  .a(a1), .b(b1), .out_valid(v1), .product(p1));
wallace_mult8 u2 (.clk(clk), .rst_n(rst_n), .in_valid(in_valid),
                  .a(a2), .b(b2), .out_valid(v2), .product(p2));
wallace_mult8 u3 (.clk(clk), .rst_n(rst_n), .in_valid(in_valid),
                  .a(a3), .b(b3), .out_valid(v3), .product(p3));

// ------------------------------------------------------------------
// One-cycle align register to guarantee lane sync
// ------------------------------------------------------------------
reg [15:0] p0_r, p1_r, p2_r, p3_r;
reg        v_r;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        p0_r <= 16'd0;
        p1_r <= 16'd0;
        p2_r <= 16'd0;
        p3_r <= 16'd0;
        v_r  <= 1'b0;
    end else begin
        p0_r <= p0;
        p1_r <= p1;
        p2_r <= p2;
        p3_r <= p3;
        v_r  <= v0 & v1 & v2 & v3;   // all lanes ready
    end
end

// ------------------------------------------------------------------
// 4-to-1 adder tree
// ------------------------------------------------------------------
adder_tree4 u_tree (
    .clk      (clk),
    .rst_n    (rst_n),
    .in_valid (v_r),
    .p0       (p0_r),
    .p1       (p1_r),
    .p2       (p2_r),
    .p3       (p3_r),
    .out_valid(out_valid),
    .sum      (out_sum)
);

// ------------------------------------------------------------------
// Debug bus (optional, synthesis off if macro undefined)
// ------------------------------------------------------------------
`ifdef DEBUG_PRODUCT
assign product = {p3_r, p2_r, p1_r, p0_r};
`endif

endmodule
