`timescale 1ns/1ps
(* use_dsp = "no" *)
module mul4x8x8_wallace (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        in_valid,
    input  wire [31:0] in_a,
    input  wire [31:0] in_b,
    output wire        out_valid,
    output wire [17:0] out_sum,
    output wire [63:0] product
);
    wire [7:0] a[3:0], b[3:0];
    assign {a[3],a[2],a[1],a[0]} = in_a;
    assign {b[3],b[2],b[1],b[0]} = in_b;

    wire [15:0] p[3:0];
    wire [3:0]  v;
    
    wire [17:0] tree_sum; //for adder tree
    wire        tree_valid;
    genvar i;
    generate
        for(i=0;i<4;i=i+1) begin : MUL
            wallace_mult8 u (
                .clk(clk), .rst_n(rst_n),
                .in_valid(in_valid),
                .a(a[i]), .b(b[i]),
                .out_valid(v[i]), .product(p[i])
            );
        end
    endgenerate
    // ========= adder-tree =======
    adder_tree4 u_tree (
        .clk      (clk),
        .rst_n    (rst_n),
        .in_valid (v[0]),     // v[3:0] work syncly, so i pick only v[0]
        .p0(p[0]), .p1(p[1]), .p2(p[2]), .p3(p[3]),
        .out_valid(tree_valid),
        .sum      (tree_sum)
    );

    assign product   = {p[3],p[2],p[1],p[0]}; //testing only
    assign out_valid = v[0];   //four pipline go together
endmodule
