`timescale 1ns/1ps
module vector_mac_top (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        in_valid,
    input  wire [31:0] in_a,
    input  wire [31:0] in_b,
    output wire        out_valid,   // = result_valid
    output wire [31:0] mac_out
);

    // ---------------- core : 4×8×8 MAC ----------------
    wire [17:0] sum18;
    wire        sum_valid;

    mul4x8x8_wallace u_core (
        .clk      (clk),
        .rst_n    (rst_n),
        .in_valid (in_valid),
        .in_a     (in_a),
        .in_b     (in_b),
        .out_valid(sum_valid),
        .out_sum  (sum18)
    );

    // --------------- accumulator ----------------------
    accumulator #(.W_IN(18), .BEATS(250), .W_ACC(32)) u_accu (
        .clk         (clk),
        .rst_n       (rst_n),
        .in_valid    (sum_valid),  // enable every core beat
        .partial_sum (sum18),
        .final_sum   (mac_out),
        .result_valid(out_valid)
    );

endmodule
