`timescale 1ns/1ps
// ============================================================================
//  Universal?16-lane pipelined adder tree
//    * LANES  : 1/2/4/8/16  (power-of-2)
//    * INW    : width of each partial product (default 16)
//    * OUTW   : INW + log2(LANES) + 2 guard bits
//    * Pipeline stages = max(2, log2(LANES))
// Author : Hubo
// ============================================================================
module adder_tree_var #(
    parameter integer LANES  = 4,                               // 1 for 16 lanes
    parameter integer INW    = 16,
    parameter integer STAGES = (LANES < 4) ? 2 : $clog2(LANES), // 2for 4lanes
    parameter integer OUTW   = INW + STAGES + 1                 // guard
)(
    input  wire                       clk,
    input  wire                       rst_n,
    input  wire                       in_valid,
    input  wire [LANES*INW-1:0]       prod_flat, // L partial products
    output wire                       out_valid,
    output wire [OUTW-1:0]            sum
);
// -----------------------------------------------------
// 0)  unpack & zero-extend to OUTW bits
// ------------------------------------------------------------------
wire [OUTW-1:0] s0 [0:LANES-1];
genvar gi;
generate
    for (gi = 0; gi < LANES; gi = gi + 1)
        assign s0[gi] = {{(OUTW-INW){1'b0}}, prod_flat[INW*gi +: INW]};
endgenerate

// --------------------------------------------------------------
// 1)  valid pipeline  (depth = STAGES)
// ------------------------------------------------------------------
reg [STAGES-1:0] v_pipe;
always @(posedge clk or negedge rst_n)
    if (!rst_n)           v_pipe <= {STAGES{1'b0}};
    else                  v_pipe <= {v_pipe[STAGES-2:0], in_valid};

// -------------------------------------------------------------
// 2)  stage-1
// ------------------------------------------------------------------
localparam L1 = (LANES>1) ? LANES/2 : 1;
wire [OUTW-1:0] w1 [0:L1-1];          // combinational sums
reg  [OUTW-1:0] r1 [0:L1-1];          // 1-clk registers

generate
    if (LANES > 1) begin
        for (gi = 0; gi < L1; gi = gi + 1)
            assign w1[gi] = s0[2*gi] + s0[2*gi+1];
    end
    else begin
        assign w1[0] = s0[0];
    end
endgenerate

integer i;
always @(posedge clk or negedge rst_n)
    if (!rst_n)
        for (i = 0; i < L1; i = i + 1) r1[i] <= {OUTW{1'b0}};
    else
        for (i = 0; i < L1; i = i + 1) r1[i] <= w1[i];

// ------------------------------------------------------------------
// 3)  stage-2 STAGES>1
// ---------------------------------------------------------------
generate
if (STAGES > 1) begin : GEN_LVL2
    localparam L2 = (LANES>2) ? LANES/4 : 1;
    wire [OUTW-1:0] w2 [0:L2-1];
    reg  [OUTW-1:0] r2 [0:L2-1];

    if (LANES > 2) begin
        for (gi = 0; gi < L2; gi = gi + 1)
            assign w2[gi] = r1[2*gi] + r1[2*gi+1];
    end
    else begin
        assign w2[0] = r1[0];
    end

    always @(posedge clk or negedge rst_n)
        if (!rst_n)
            for (i = 0; i < L2; i = i + 1) r2[i] <= {OUTW{1'b0}};
        else
            for (i = 0; i < L2; i = i + 1) r2[i] <= w2[i];
end
endgenerate

// ------------------------------------------------------------------
// 4)  stage-3 STAGES>2
// ------------------------------------------------
generate
if (STAGES > 2) begin : GEN_LVL3
    localparam L3 = LANES/8;          
    wire [OUTW-1:0] w3 [0:L3-1];
    reg  [OUTW-1:0] r3 [0:L3-1];

    for (gi = 0; gi < L3; gi = gi + 1)
        assign w3[gi] = GEN_LVL2.r2[2*gi] + GEN_LVL2.r2[2*gi+1];

    always @(posedge clk or negedge rst_n)
        if (!rst_n)
            for (i = 0; i < L3; i = i + 1) r3[i] <= {OUTW{1'b0}};
        else
            for (i = 0; i < L3; i = i + 1) r3[i] <= w3[i];
end
endgenerate

// ----------------------------------------------------
// 5)  stage-4 STAGES>3 for 16-lane
// ------------------------------------------------------------
generate
if (STAGES > 3) begin : GEN_LVL4
    wire [OUTW-1:0] w4 = GEN_LVL3.r3[0] + GEN_LVL3.r3[1];
    reg  [OUTW-1:0] r4;

    always @(posedge clk or negedge rst_n)
        if (!rst_n)       r4 <= {OUTW{1'b0}};
        else              r4 <= w4;

    assign sum = r4;
end
// ------------------------------------------------------------------
// Final map
// --------------------------------------------------------------
else if (STAGES == 3) begin
    assign sum = GEN_LVL3.r3[0];
end
else if (STAGES == 2) begin
    assign sum = GEN_LVL2.r2[0];
end
else begin
    assign sum = {2'b00, r1[0][INW-1:0]}; // LANES==1 pass-through
end
endgenerate

assign out_valid = v_pipe[STAGES-1];

endmodule
