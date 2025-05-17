`timescale 1ns/1ps
(* use_dsp = "no" *)
module accumulator #(
    parameter W_IN  = 18,    // from adder-tree
    parameter BEATS = 250,   // 1000 elems ¡Â ²¢ÐÐ4
    localparam W_ACC = 26    // ?log2(255?¡Á1000)?
)(
    input  wire               clk,
    input  wire               rst_n,
    input  wire               in_valid,
    input  wire [W_IN-1:0]    partial_sum,
    output reg  [W_ACC-1:0]   final_sum,
    output reg                result_valid
);
    reg [W_ACC-1:0] running_sum;
    reg [$clog2(BEATS)-1:0] cnt;
    wire last_beat = (cnt == BEATS-1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            running_sum  <= 0;
            cnt          <= 0;
            result_valid <= 0;
        end else if (in_valid) begin
            running_sum  <= last_beat ? 0 : running_sum + partial_sum;
            cnt          <= last_beat ? 0 : cnt + 1'b1;
            final_sum    <= last_beat ? running_sum + partial_sum : 0;
            result_valid <= last_beat;
        end else begin
            result_valid <= 0;
        end
    end
endmodule
