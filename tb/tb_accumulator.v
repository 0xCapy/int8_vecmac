`timescale 1ns/1ps
// ==========================================================================
//  Self-checking Testbench for accumulator.v
//  ? W_IN  : 18 (partial_sum width)
//  ? BEATS : 2 (two partial sums per vector)
//  ? VECT  : 500 random vectors
//  ? result_valid rises the same cycle as the last in_valid
// ==========================================================================
module tb_accumulator;

    // ---------- parameters ----------
    localparam W_IN  = 18;
    localparam BEATS = 2;
    localparam VECT  = 500;          // number of vectors to test

    // ---------- clock & reset ----------
    reg clk = 0;  always #5 clk = ~clk;   // 100 MHz
    reg rst_n = 0;

    // ---------- DUT I/O ----------
    reg                 in_valid = 0;
    reg  [W_IN-1:0]     partial_sum = 0;
    wire [W_IN:0]       final_sum;
    wire                result_valid;

    accumulator #(
        .W_IN (W_IN ),
        .BEATS(BEATS)
    ) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .in_valid   (in_valid),
        .partial_sum(partial_sum),
        .final_sum  (final_sum),
        .result_valid(result_valid)
    );

    // ---------- scoreboard ----------
    integer i, beat;
    integer err = 0;
    reg [W_IN:0] gold;

    initial begin
        $display("\n=== Accumulator TB  (BEATS=%0d , VECT=%0d) ===", BEATS, VECT);

        // reset 3?cycles
        repeat (3) @(posedge clk);
        rst_n = 1;

        // main stimulus loop
        for (i = 0; i < VECT; i = i + 1) begin
            gold = 0;

            // feed BEATS partial sums back-to-back
            for (beat = 0; beat < BEATS; beat = beat + 1) begin
                @(negedge clk);
                partial_sum = $urandom_range(0, (1<<W_IN)-1);
                gold        = gold + partial_sum;
                in_valid    <= 1;

                @(posedge clk);              // sample by DUT
                in_valid    <= 0;            // clear immediately
            end

            // wait for 1-cycle pulse of result_valid
            @(posedge result_valid);  #0;    // make sure final_sum stable

            // compare
            if (final_sum !== gold) begin
                $display("FAIL vec=%0d  EXP=%h  GOT=%h", i, gold, final_sum);
                err = err + 1;
            end
        end

        // summary
        if (err == 0)
            $display("=== PASS : all %0d vectors matched ===", VECT);
        else
            $display("=== %0d mismatches detected ===", err);

        $finish;
    end
endmodule
