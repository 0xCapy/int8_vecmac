`timescale 1ns/1ps
// ===========================================================================
//  Discription : This file provides integrating MAC design - 16 Macs version - 16x8x8 with boundary, stress and random test.
// Author: Hubo
// ===========================================================================
(* use_dsp = "no" *)
module mul16x8x8_wallace
(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         in_valid,
    input  wire [127:0] in_a,
    input  wire [127:0] in_b,
    output reg          out_valid,
    output reg  [19:0]  out_sum
);
    // 0.---------------------declarations
    genvar  g;
    integer i;

    // 1.-----------slice 16 lanes
    wire [7:0] a [0:15];
    wire [7:0] b [0:15];
    generate
        for (g = 0; g < 16; g = g + 1) begin : G_SLICE
            assign a[g] = in_a[g*8 +: 8];
            assign b[g] = in_b[g*8 +: 8];
        end
    endgenerate

    // 2.  ------------sixteen multipliers 
    wire [15:0] p [0:15];
    wire        v_lane [0:15];
    generate
        for (g = 0; g < 16; g = g + 1) begin : G_MUL
            wallace_mult8 u_mul (
                .clk      (clk),
                .rst_n    (rst_n),
                .in_valid (in_valid),
                .a        (a[g]),
                .b        (b[g]),
                .out_valid(v_lane[g]),
                .product  (p[g])
            );
        end
    endgenerate

    // 3. ----------------1-cycle align
    reg [15:0] p_r [0:15];
    reg        v_r;                
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 16; i = i + 1) p_r[i] <= 16'd0;
            v_r <= 1'b0;
        end
        else begin
            for (i = 0; i < 16; i = i + 1) p_r[i] <= p[i];
            v_r <= v_lane[0];      // all delay one for sync
        end
    end

    // 4.------------- flatten  to 256-bit bus
    wire [255:0] prod_bus;
    generate
        for (g = 0; g < 16; g = g + 1)
            assign prod_bus[g*16 +: 16] = p_r[g];
    endgenerate

    // 5. ----------------------adder tree (4--tage)  OUTW = 20
    wire        tree_valid;
    wire [19:0] tree_sum;
    adder_tree_var #(
        .LANES (16),
        .INW   (16),
        .OUTW  (20)
    ) u_tree (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (v_r),
        .prod_flat (prod_bus),
        .out_valid (tree_valid),
        .sum       (tree_sum)
    );

    // 6. ----------------------output reg  (+1 cycle)--------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            out_sum   <= 20'd0;
        end
        else begin
            out_valid <= tree_valid;
            out_sum   <= tree_sum;
        end
    end
endmodule
