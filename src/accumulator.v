`timescale 1ns/1ps
(* use_dsp = "no" *)
module accumulator #(
    parameter W_IN  = 18,
    parameter BEATS = 2
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 in_valid,
    input  wire [W_IN-1:0]      partial_sum,
    output reg  [W_IN:0]        final_sum,    // W_IN+1
    output reg                  result_valid
);
    reg [W_IN:0] running_sum;
    reg [$clog2(BEATS)-1:0] cnt;

    wire last_beat = (cnt == BEATS-1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            running_sum  <= {(W_IN+1){1'b0}};
            cnt          <= 'd0;
            result_valid <= 1'b0;
        end
        else if (in_valid) begin
            // --------- accumulate or clear ----------
            running_sum <= last_beat ? {(W_IN+1){1'b0}}  
                                     : running_sum + partial_sum;

            // --------- counter ----------
            cnt <= last_beat ? 'd0 : cnt + 1'b1;

            // --------- output ----------
            final_sum    <= last_beat ? running_sum + partial_sum : {(W_IN+1){1'b0}};
            result_valid <= last_beat;
        end
        else begin
            result_valid <= 1'b0;
        end
    end
endmodule
