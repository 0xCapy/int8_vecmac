`timescale 1ns/1ps
// =============================================================================
//  Half-Adder
// =============================================================================
module ha(input wire a, input wire b, output wire s, output wire c);
    assign s = a ^ b;
    assign c = a & b;
endmodule

// =============================================================================
//  Full-Adder   (第三输入端口名就是 c)
// =============================================================================
module fa(input wire a, input wire b, input wire c,
          output wire s, output wire cout);
    assign s    = a ^ b ^ c;
    assign cout = (a & b) | (a & c) | (b & c);
endmodule

// =============================================================================
//  8 × 8 Wallace Tree multiplier  -- 3-stage pipeline (latency = 3 clk)
// =============================================================================
(* use_dsp = "no" *)
module wallace_mult8(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        in_valid,
    input  wire [7:0]  a,
    input  wire [7:0]  b,
    output wire        out_valid,
    output wire [15:0] product
);
    // -------------------------------------------------------------------------
    // 0) Partial-product rows  (each bit driven **一次**)
    // -------------------------------------------------------------------------
    wire [15:0] pp [7:0];         // 2-D vector array is合法 in Verilog-2001
    genvar gi, gj;
    generate
        for (gi = 0; gi < 8; gi = gi + 1) begin : ROW
            for (gj = 0; gj < 8; gj = gj + 1) begin : COL
                assign pp[gi][gj+gi] = a[gi] & b[gj];
            end
        end
    endgenerate

    // -------------------------------------------------------------------------
    // 1) Layer-1  (8  rows → 6 rows)   >>>  P1 register
    // -------------------------------------------------------------------------
    wire [15:0] l1s [2:0], l1c [2:0];
    generate
        for (gj = 0; gj < 16; gj = gj + 1) begin : L1
            wire sA,cA,sB,cB;
            fa fa0(.a(pp[0][gj]),.b(pp[1][gj]),.c(pp[2][gj]),.s(sA),.cout(cA));
            ha ha0(.a(pp[3][gj]),.b(pp[4][gj]),           .s(sB),.c(cB));

            assign l1s[0][gj]=sA;  assign l1c[0][gj]=cA;
            assign l1s[1][gj]=sB;  assign l1c[1][gj]=cB;
            assign l1s[2][gj]=pp[5][gj];
            assign l1c[2][gj]=pp[6][gj];
        end
    endgenerate

    reg [15:0] r1s0,r1c0,r1s1,r1c1,r1s2,r1c2;
    reg        v1;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) v1<=0;
        else begin
            v1<=in_valid;
            r1s0<=l1s[0]; r1c0<=l1c[0];
            r1s1<=l1s[1]; r1c1<=l1c[1];
            r1s2<=l1s[2]; r1c2<=l1c[2];
        end
    end

    // -------------------------------------------------------------------------
    // 2) Layer-2  (6  rows → 4 rows)   >>>  P2 register
    // -------------------------------------------------------------------------
    wire [15:0] l2s [1:0], l2c [1:0];
    generate
        for (gj = 0; gj < 16; gj = gj + 1) begin : L2
            wire sA,cA,sB,cB;
            fa fa1(.a(r1s0[gj]),.b(r1s1[gj]),.c(r1s2[gj]),.s(sA),.cout(cA));
            fa fa2(.a(r1c0[gj]),.b(r1c1[gj]),.c(r1c2[gj]),.s(sB),.cout(cB));
            assign l2s[0][gj]=sA;  assign l2c[0][gj]=cA;
            assign l2s[1][gj]=sB;  assign l2c[1][gj]=cB;
        end
    endgenerate

    reg [15:0] r2s0,r2c0,r2s1,r2c1;
    reg        v2;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) v2<=0;
        else begin
            v2<=v1;
            r2s0<=l2s[0]; r2c0<=l2c[0];
            r2s1<=l2s[1]; r2c1<=l2c[1];
        end
    end

    // -------------------------------------------------------------------------
    // 3) Layer-3  (4 rows → 2 rows) + final 17-bit CPA
    // -------------------------------------------------------------------------
    wire [15:0] s3, c3;
    generate
        for (gj = 0; gj < 16; gj = gj + 1) begin : L3
            wire sA,cA;
            fa fa3(.a(r2s0[gj]),.b(r2s1[gj]),.c(r2c0[gj]),.s(sA),.cout(cA));
            assign s3[gj] = sA;
            assign c3[gj] = cA;
        end
    endgenerate

    wire [16:0] sum17   = {1'b0, s3};
    wire [16:0] carry17 = {c3,   1'b0};   // 全体左移 1 位
    wire [16:0] final17 = sum17 + carry17;

    reg  [15:0] product_r;
    reg         v3;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) v3<=0;
        else begin
            v3<=v2;
            product_r<=final17[15:0];
        end
    end

    assign product   = product_r;
    assign out_valid = v3;   // latency = 3 clk
endmodule

// =============================================================================
// 4-lane wrapper  mul4x8x8_wallace
// =============================================================================
(* use_dsp = "no" *)
module mul4x8x8_wallace(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         in_valid,
    input  wire [31:0]  in_a,
    input  wire [31:0]  in_b,
    output wire         out_valid,
    output wire [63:0]  product
);
    wire [7:0] a0=in_a[7:0],   a1=in_a[15:8],
               a2=in_a[23:16], a3=in_a[31:24];
    wire [7:0] b0=in_b[7:0],   b1=in_b[15:8],
               b2=in_b[23:16], b3=in_b[31:24];

    wire v0,v1,v2,v3;
    wire [15:0] p0,p1,p2,p3;

    wallace_mult8 u0(.clk(clk),.rst_n(rst_n),.in_valid(in_valid),.a(a0),.b(b0),.out_valid(v0),.product(p0));
    wallace_mult8 u1(.clk(clk),.rst_n(rst_n),.in_valid(in_valid),.a(a1),.b(b1),.out_valid(v1),.product(p1));
    wallace_mult8 u2(.clk(clk),.rst_n(rst_n),.in_valid(in_valid),.a(a2),.b(b2),.out_valid(v2),.product(p2));
    wallace_mult8 u3(.clk(clk),.rst_n(rst_n),.in_valid(in_valid),.a(a3),.b(b3),.out_valid(v3),.product(p3));

    assign product   = {p3,p2,p1,p0};
    assign out_valid = v0;   // 同一拍
endmodule
