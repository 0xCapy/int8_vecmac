`timescale 1ns/1ps
// ============================================================================
// 8×8×8 Wallace MAC  -  LANES = 8   (unsigned INT8)
// Author : Hubo     Platform : Vivado 2021.1   (pure Verilog-2001)
// ---------------------------------------------------------------------------
// ? in_a / in_b : 64-bit, 8×INT8 packed（lane0 = byte[7:0]）
// ? 产品：8 × 255 × 255 = 520 200  < 2??   → OUTW = 19 bits
// ? 延迟：mult 3 + align 1 + adder_tree 3 + out_reg 1 = **8 cycles**
// ============================================================================
(* use_dsp = "no" *)
module mul8x8x8_wallace
(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        in_valid,
    input  wire [63:0] in_a,
    input  wire [63:0] in_b,
    output reg         out_valid,
    output reg  [18:0] out_sum
`ifdef DEBUG_PRODUCT
  , output reg  [127:0] product
`endif
);

    // --------------------------------------------------------------------
    // 0. declarations
    // --------------------------------------------------------------------
    genvar  g;
    integer i;

    // --------------------------------------------------------------------
    // 1. slice 8 lanes (8×8-bit)
    // --------------------------------------------------------------------
    wire [7:0] a [0:7];
    wire [7:0] b [0:7];

    generate
        for (g = 0; g < 8; g = g + 1) begin : G_SLICE
            assign a[g] = in_a[g*8 +: 8];
            assign b[g] = in_b[g*8 +: 8];
        end
    endgenerate

    // --------------------------------------------------------------------
    // 2. eight 8×8 multipliers (3-cycle wallace_mult8)
    // --------------------------------------------------------------------
    wire [15:0] p [0:7];
    wire        v_lane [0:7];

    generate
        for (g = 0; g < 8; g = g + 1) begin : G_MUL
            wallace_mult8 u_mul (
                .clk       (clk),
                .rst_n     (rst_n),
                .in_valid  (in_valid),
                .a         (a[g]),
                .b         (b[g]),
                .out_valid (v_lane[g]),
                .product   (p[g])
            );
        end
    endgenerate

    // --------------------------------------------------------------------
    // 3. pipeline valid  (sync to multiplier latency = 3)
    // --------------------------------------------------------------------
    reg [2:0] v_pipe;                     // shift register
    always @(posedge clk or negedge rst_n)
        if (!rst_n)   v_pipe <= 3'b000;
        else          v_pipe <= {v_pipe[1:0], in_valid};

    wire v_sync = v_pipe[2];              // 与 p[] 同时有效

    // --------------------------------------------------------------------
    // 4. 1-cycle align register
    // --------------------------------------------------------------------
    reg [15:0] p_r [0:7];
    reg        v_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i = i + 1) p_r[i] <= 16'd0;
            v_r <= 1'b0;
        end
        else begin
            for (i = 0; i < 8; i = i + 1) p_r[i] <= p[i];
            v_r <= v_sync;               // 绝无 X
        end
    end

    // --------------------------------------------------------------------
    // 5. flatten to 128-bit bus
    // --------------------------------------------------------------------
    wire [127:0] prod_bus;
    generate
        for (g = 0; g < 8; g = g + 1)
            assign prod_bus[g*16 +: 16] = p_r[g];
    endgenerate

    // --------------------------------------------------------------------
    // 6. adder_tree_var (LANES=8  OUTW=19)
    // --------------------------------------------------------------------
    wire        tree_valid;
    wire [18:0] tree_sum;

    adder_tree_var #(
        .LANES (8),
        .INW   (16),
        .OUTW  (19)
    ) u_tree (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (v_r),
        .prod_flat (prod_bus),
        .out_valid (tree_valid),
        .sum       (tree_sum)
    );

    // --------------------------------------------------------------------
    // 7. output register (＋1 cycle)
    // --------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            out_sum   <= 19'd0;
`ifdef DEBUG_PRODUCT
            product   <= 128'd0;
`endif
        end
        else begin
            out_valid <= tree_valid;
            out_sum   <= tree_sum;
`ifdef DEBUG_PRODUCT
            product   <= prod_bus;
`endif
        end
    end

endmodule
