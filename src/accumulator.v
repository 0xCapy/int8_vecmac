// ============================================================================
//  accumulator.v  - beat-counter accumulator with end-pulse
// ============================================================================
`timescale 1ns/1ps
module accumulator
#(
    parameter W_IN   = 18,
    parameter BEATS  = 250,                 // 1000 elems / parallel-4
    parameter W_ACC  = 32                   // <= 2^32 about 4e9
)
(
    input  wire                 clk,
    input  wire                 rst_n,       // async 
    input  wire                 in_valid,    
    input  wire [W_IN-1:0]      partial_sum,
    output reg  [W_ACC-1:0]     final_sum,
    output reg                  result_valid 
);

    // --------------------------------------------------------------------
    // registers
    // --------------------------------------------------------------------
    reg [W_ACC-1:0] running_sum;
    // counter width = ceil(log2(BEATS))
    localparam CNT_W = (BEATS <= 2)   ? 1 :
                       (BEATS <= 4)   ? 2 :
                       (BEATS <= 8)   ? 3 :
                       (BEATS <= 16)  ? 4 :
                       (BEATS <= 32)  ? 5 :
                       (BEATS <= 64)  ? 6 :
                       (BEATS <= 128) ? 7 : 8;
    reg [CNT_W-1:0] cnt;

    wire last_beat = (cnt == BEATS-1);

    // --------------------------------------------------------------------
    // main FSM: accumulate, roll over at last beat
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            running_sum  <= {W_ACC{1'b0}};
            cnt          <= {CNT_W{1'b0}};
            final_sum    <= {W_ACC{1'b0}};
            result_valid <= 1'b0;
        end
        else if (in_valid) begin
            running_sum  <= last_beat ? {W_ACC{1'b0}}
                                      : running_sum + partial_sum;
            cnt          <= last_beat ? {CNT_W{1'b0}}
                                      : cnt + 1'b1;
            final_sum    <= running_sum + partial_sum;
            result_valid <= last_beat;
        end
        else begin
            result_valid <= 1'b0;
        end
    end

endmodule
