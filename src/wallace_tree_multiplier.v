`timescale 1ns/1ps
// ===========================================================================
//  Half- & Full-Adder
module ha(input wire a, b, output wire s, c);
    assign s = a ^ b;
    assign c = a & b;
endmodule

module fa(input wire a, b, cin, output wire s, cout);
    assign s    = a ^ b ^ cin;
    assign cout = (a & b) | (a & cin) | (b & cin);
endmodule

// ===============================================
// 8 x 8 Wallace Tree multiplier - 3-stage pipeline, no DSP
(* use_dsp = "no" *)
module wallace_mult8 (
    input  wire        clk,
    input  wire        rst_n,      // active-low reset
    input  wire        in_valid,
    input  wire [7:0]  a,
    input  wire [7:0]  b,
    output wire        out_valid,
    output wire [15:0] product
);
    // ---------------- constants -------------------------------------------
    localparam W = 17;             // 16 bits + 1 carry bit

// 0) Partial products 
// ------------------------------------------------------------------
    wire [W-1:0] pp [7:0];
    
    genvar gi, gj;
    generate
        for (gi = 0; gi < 8; gi = gi + 1) begin : ROW
            for (gj = 0; gj < W; gj = gj + 1) begin : COL
                if (gj >= gi && gj < gi + 8) begin
                    assign pp[gi][gj] = a[gi] & b[gj - gi];
                end else begin
                    assign pp[gi][gj] = 1'b0;
                end
            end
        end
    endgenerate
    // ---------------- 1) layer-1 : 8 to 6 rows ---------------------
    wire [W-1:0] l1s0,l1s1,l1s2,l1c0,l1c1,l1c2;
    generate
        for (gj = 0; gj < 16; gj = gj + 1) begin : L1
            fa fa0 (pp[0][gj], pp[1][gj], pp[2][gj],
                     l1s0[gj], l1c0[gj+1]);
            ha ha0 (pp[3][gj], pp[4][gj],
                     l1s1[gj], l1c1[gj+1]);
            fa fa1 (pp[5][gj], pp[6][gj], pp[7][gj],
                     l1s2[gj], l1c2[gj+1]);
        end
    endgenerate
    assign {l1c0[0],l1c1[0],l1c2[0]} = 3'b000;
    assign {l1s0[16],l1s1[16],l1s2[16]} = 3'b000;

    // -------- P1 registers --------------
    reg [W-1:0] r1s0,r1s1,r1s2,r1c0,r1c1,r1c2;
    reg         v1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v1 <= 1'b0;
        end else if (in_valid) begin
            v1   <= 1'b1;
            r1s0 <= l1s0;  r1c0 <= l1c0;
            r1s1 <= l1s1;  r1c1 <= l1c1;
            r1s2 <= l1s2;  r1c2 <= l1c2;
        end else begin
            v1 <= 1'b0;
        end
    end
    // ---------------- 2) layer-2 : 6 to 4 rows -----------------
    wire [W-1:0] l2s0,l2s1,l2c0,l2c1;
    generate
        for (gj = 0; gj < W-1; gj = gj + 1) begin : L2
            fa fa2 (r1s0[gj], r1s1[gj], r1s2[gj],
                     l2s0[gj], l2c0[gj+1]);
            fa fa3 (r1c0[gj], r1c1[gj], r1c2[gj],
                     l2s1[gj], l2c1[gj+1]);
        end
    endgenerate
    assign l2s0[W-1] = r1s0[W-1] ^ r1s1[W-1] ^ r1s2[W-1];
    assign l2s1[W-1] = r1c0[W-1] ^ r1c1[W-1] ^ r1c2[W-1];
    assign {l2c0[0],l2c1[0]} = 2'b00;

    // -------- P2 registers -------------------------------------------------
    reg [W-1:0] r2s0,r2s1,r2c0,r2c1;
    reg         v2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v2 <= 1'b0;
        end else if (v1) begin
            v2   <= 1'b1;
            r2s0 <= l2s0;  r2c0 <= l2c0;
            r2s1 <= l2s1;  r2c1 <= l2c1;
        end else begin
            v2 <= 1'b0;
        end
    end
    // ---------------- 3) layer-3 : 4 to 2 rows
    wire [W-1:0] s3, c3;
    generate
        for (gj = 0; gj < W-1; gj = gj + 1) begin : L3
            fa fa4 (r2s0[gj], r2s1[gj], r2c0[gj],
                     s3[gj], c3[gj+1]);
        end
    endgenerate
    assign s3[W-1] = r2s0[W-1] ^ r2s1[W-1] ^ r2c0[W-1];
    assign c3      [0] = 1'b0;


    // ---------------- CPA (17-bit) ---------------
    wire [17:0] final18 = {1'b0, s3}
                       +  c3 
                       +  r2c1;  
    // -------- P3 registers & outputs --------------------------------
    reg [15:0] product_r;
    reg        v3;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v3 <= 1'b0;
        end else if (v2) begin
            v3       <= 1'b1;
            product_r<= final18[15:0];
        end else begin
            v3 <= 1'b0;
        end
    end
    assign product   = product_r;
    assign out_valid = v3;   // 3-cycle latency
endmodule
