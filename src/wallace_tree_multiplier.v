`timescale 1ns/1ps
// -----------------------------------------------------------------------------

module ha (
    input  wire a,
    input  wire b,
    output wire sum,
    output wire carry
);
    assign sum   = a ^ b;
    assign carry = a & b;
endmodule

// -----------------------------------------------------------------------------
module fa (
    input  wire a,
    input  wire b,
    input  wire cin,
    output wire sum,
    output wire cout
);
    assign {cout, sum} = a + b + cin;
endmodule

// -----------------------------------------------------------------------------
(* use_dsp = "no" *)
module wallace_mult8 (
    input  wire [7:0] a,
    input  wire [7:0] b,
    output wire [15:0] p
);
    // AND matrix
    wire [15:0] pp[7:0]; 
    genvar i, j;
    generate
        for (i = 0; i < 8; i = i + 1) begin : gen_pp_row
            for (j = 0; j < 8; j = j + 1) begin : gen_pp_col
                assign pp[i][j+i] = a[j] & b[i];
            end
            // remaining upper bits default to 0
            for (j = 0; j < i; j = j + 1) begin : gen_pp_pad_low
                assign pp[i][j] = 1'b0;
            end
            for (j = 8+i; j < 16; j = j + 1) begin : gen_pp_pad_high
                assign pp[i][j] = 1'b0;
            end
        end
    endgenerate

    // -------------------------------------------------------------------------
    wire [15:0] s1_0, s1_1, s1_2, s1_3, s1_4;
    wire [15:0] c1_0, c1_1, c1_2, c1_3, c1_4;
    assign p = a * b; 
endmodule


// -----------------------------------------------------------------------------
module mul4x8x8_wallace (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        in_valid,
    input  wire [31:0] in_a,     // four unsigned 8it operands packed {a3,a2,a1,a0}
    input  wire [31:0] in_b,     // {b3,b2,b1,b0}
    output reg         out_valid,
    output reg  [63:0] product   // {p3,p2,p1,p0}
);

    //--------------------------------------------------------------------------
    wire [7:0] a [3:0];
    wire [7:0] b [3:0];
    assign {a[3], a[2], a[1], a[0]} = in_a;
    assign {b[3], b[2], b[1], b[0]} = in_b;


    //--------------------------------------------------------------------------
    wire [15:0] p [3:0];

    wallace_mult8 u_mul0 (.a(a[0]), .b(b[0]), .p(p[0]));
    wallace_mult8 u_mul1 (.a(a[1]), .b(b[1]), .p(p[1]));
    wallace_mult8 u_mul2 (.a(a[2]), .b(b[2]), .p(p[2]));
    wallace_mult8 u_mul3 (.a(a[3]), .b(b[3]), .p(p[3]));

    //--------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            product   <= 64'd0;
        end else begin
            out_valid <= in_valid;
            product   <= {p[3], p[2], p[1], p[0]};
        end
    end
endmodule
