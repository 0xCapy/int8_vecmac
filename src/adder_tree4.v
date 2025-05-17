`timescale 1ns/1ps
// =============================================

(* use_dsp = "no" *)
module adder_tree4 #(
    parameter W_IN  = 16,
    parameter W_MID = W_IN + 1,
    parameter W_OUT = W_IN + 2
)(
    input  wire                clk,
    input  wire                rst_n,
    input  wire                in_valid,
    input  wire [W_IN-1:0]     p0, p1, p2, p3,
    output reg                 out_valid,
    output reg  [W_OUT-1:0]    sum 
);
    // ---------- p0+p1 , p2+p3 
    reg [W_MID-1:0] s01_r, s23_r;   // 17-bit each
    reg             v1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v1   <= 1'b0;
        end else begin
            v1   <= in_valid;
            s01_r<= p0 + p1; 
            s23_r<= p2 + p3;
        end
    end

    // ----------  s01 + s23  
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
        end else begin
            out_valid <= v1;
            sum       <= s01_r + s23_r;
        end
    end
endmodule
