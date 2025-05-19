`timescale 1ns/1ps
// ================================================================
//  accumulator_var  -  runtime-programmable beat counter
//  lanes_i : 1 / 2 / 4 / 8 / 16 
//  W_IN    : 20-bit partial_sum  (16*255*255 - 2^20)
//  W_ACC   : 32-bit final_sum    (1000*255*255 - 2^32)
// ============================================================================
module accumulator_var #(
    parameter integer ELEMS  = 1000,
    parameter integer W_IN   = 20,
    parameter integer W_ACC  = 32
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire                 in_valid,     // one beat
    input  wire [W_IN-1:0]      partial_sum,  // unsigned
    input  wire [4:0]           lanes_i,
    output reg  [W_ACC-1:0]     final_sum,    // dot-product
    output reg                  result_valid  // 1-cycle pulse
);
    // ------------------------------------------------------------------------
    // beats_max LUT : ceil(ELEMS / lanes) - 1  (store as unsigned)
    // ------------------------------------------------------------------------
    function [15:0] beats_max;   // 16-bit covers ELEMS -65535
        input [4:0] lc;
        begin
            case (lc)
                5'd1  : beats_max = ELEMS - 1;                                // 1000-1
                5'd2  : beats_max = ((ELEMS + 1 ) >> 1)  - 1;                 // (1001>>1)-1 = 499
                5'd4  : beats_max = ((ELEMS + 3 ) >> 2)  - 1;                 // 249
                5'd8  : beats_max = ((ELEMS + 7 ) >> 3)  - 1;                 // 124
                5'd16 : beats_max = ((ELEMS + 15) >> 4)  - 1;                 // 62
                default: beats_max = ((ELEMS + 3 ) >> 2)  - 1;                // fallback 4-lane
            endcase
        end
    endfunction

    // counter width = ceil(log2(ELEMS))
    localparam integer CNT_W = $clog2(ELEMS);
    reg  [CNT_W-1:0] cnt;
    wire last_beat = (cnt == beats_max(lanes_i));

    // running accumulator
    reg [W_ACC-1:0] acc_reg;

    // ------------------------------------------------------------------------
    // main sequential logic
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_reg      <= {W_ACC{1'b0}};
            cnt          <= {CNT_W{1'b0}};
            final_sum    <= {W_ACC{1'b0}};
            result_valid <= 1'b0;
        end
        else if (in_valid) begin
            // accumulate this beat
            acc_reg   <= last_beat ? {W_ACC{1'b0}}
                                   : acc_reg + partial_sum;

            // beat counter
            cnt       <= last_beat ? {CNT_W{1'b0}}
                                   : cnt + 1'b1;

            // output
            final_sum    <= acc_reg + partial_sum;
            result_valid <= last_beat;      // pulse on final beat
        end
        else begin
            result_valid <= 1'b0;           // clear pulse
        end
    end
endmodule
