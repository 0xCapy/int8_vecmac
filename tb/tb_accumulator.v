`timescale 1ns/1ps
// ============================================================================
//  tb_accumulator_var.v   (REV-E - auto-terminate, no manual run-time setup)
//  Author : <your name>   (Vivado 2021.1, Verilog-2001)
// ============================================================================

`define USE_ACCUMULATOR   // <

module tb_accumulator_var;
    // ---------------------------------------------------------------------
    // Five instances
    // ---------------------------------------------------------------------
    tb_lane #(.LANES(1 )) u_tb1 ();
    tb_lane #(.LANES(2 )) u_tb2 ();
    tb_lane #(.LANES(4 )) u_tb4 ();
    tb_lane #(.LANES(8 )) u_tb8 ();
    tb_lane #(.LANES(16)) u_tb16();

    initial begin
        fork
            begin : TIMEOUT
                // 100 ?s
                #100_000;
                $display("\n[TB] *** TIMEOUT - simulation did not finish in time ***\n");
                $fatal;
            end
            begin : PASS_WAIT
                wait (u_tb1.done & u_tb2.done & u_tb4.done & u_tb8.done & u_tb16.done);
                disable TIMEOUT;
                $display("\n[TB] ALL ACCUMULATOR CONFIGS PASSED\n");
                $finish;
            end
        join
    end
endmodule

// =============================================================================
//  Sub-TB for a single LANES value (parameterised)
// =============================================================================
module tb_lane #(
    parameter integer LANES     = 4,
    parameter integer ELEMS     = 1000,
    parameter integer INW_BASE  = 16
)();
    localparam integer STAGES = (LANES < 4) ? 2 : $clog2(LANES);
    localparam integer W_IN   = INW_BASE + STAGES;          // 1/2/4¡ú18, 8¡ú19, 16¡ú20
    localparam integer BEATS  = (ELEMS + LANES - 1) / LANES;
    localparam integer W_ACC  = W_IN + $clog2(BEATS);       // guard bits

    reg                    clk  = 0;
    reg                    rst_n= 0;
    reg                    in_valid = 0;
    reg  [W_IN-1:0]        partial_sum = 0;
    wire [W_ACC-1:0]       final_sum;
    wire                   result_valid;

    // ---------------- Clock 100 MHz --------------------------------------
    always #5 clk = ~clk;

    // ---------------- DUT -------------------------------------------------
`ifdef USE_ACCUMULATOR
    accumulator #(
        .W_IN  (W_IN),
        .BEATS (BEATS),
        .W_ACC (W_ACC)
    ) dut ( .clk(clk), .rst_n(rst_n), .in_valid(in_valid),
             .partial_sum(partial_sum), .final_sum(final_sum),
             .result_valid(result_valid) );
`else
    accumulator_var #(
        .LANES    (LANES),
        .ELEMS    (ELEMS),
        .INW_BASE (INW_BASE)
    ) dut ( .clk(clk), .rst_n(rst_n), .in_valid(in_valid),
             .partial_sum(partial_sum), .final_sum(final_sum),
             .result_valid(result_valid) );
`endif

    // ---------------- Stimulus & Reference -------------------------------
    integer beat_cnt;
    reg [W_ACC-1:0] ref_sum;
    integer seed = 32'h1234 ^ LANES;   // ensure different per sub-TB

    initial begin
        // Reset phase
        rst_n = 0;
        @(posedge clk); rst_n = 1;

        ref_sum   = 0;
        beat_cnt  = 0;

        // Feed BEATS samples
        while (beat_cnt < BEATS) begin
            @(posedge clk);
            in_valid = 1;
            // -------- boundary vectors first 4 beats -------------------
            case (beat_cnt)
                0: partial_sum = {W_IN{1'b0}};                           // all-0
                1: partial_sum = {W_IN{1'b1}};                           // all-1
                2: partial_sum = {{(W_IN-1){1'b0}}, 1'b1};              // 1
                3: partial_sum = 1'b1 << (W_IN-1);                      // MSB only
                default: partial_sum = $random(seed) & {W_IN{1'b1}};    // random
            endcase

            ref_sum  = ref_sum + partial_sum;
            beat_cnt = beat_cnt + 1;
        end

        @(posedge clk); in_valid = 0;
    end

    // ---------------- Checker -------------------------------------------
    reg done_r = 0;
    always @(posedge clk) begin
        if (result_valid) begin
            if (final_sum !== ref_sum) begin
                $display("ERROR [LANES=%0d] : Expected %h , Got %h", LANES, ref_sum, final_sum);
                $fatal;
            end else begin
                $display("ACC TB PASSED for LANES = %0d", LANES);
                done_r <= 1'b1;
            end
        end
    end

    // ---------------- Done flag exported to top ---------------
    wire done = done_r;
endmodule
