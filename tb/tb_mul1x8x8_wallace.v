`timescale 1ns/1ps
// =============================================================================
//  tb_mul1x8x8_wallace  (REV-F) - add full-throttle stress test
//  Discription : This file test 1x8x8 Mac Intergrating design
//  Author: Hubo 17/05/2025
// =============================================================================
module tb_mul1x8x8_wallace;

    // ------------------------------------------------------------------------
    // clock & reset
    // ------------------------------------------------------------------------
    localparam CLK_HALF = 5; 
    reg clk = 0;  always #CLK_HALF clk = ~clk;

    reg rst_n = 0;
    initial #20 rst_n = 1;

    // ------------------------------------------------------------------------
    // DUT
    reg         in_valid = 0;
    reg  [31:0] in_a = 0, in_b = 0;
    wire        out_valid;
    wire [17:0] out_sum;

    mul1x8x8_wallace dut (
        .clk(clk), .rst_n(rst_n),
        .in_valid(in_valid), .in_a(in_a), .in_b(in_b),
        .out_valid(out_valid), .out_sum(out_sum)
    );

    // ------------------------------------------------------------------------
    // 5-cycle expectation shift-register
    localparam LAT = 5;
    reg [17:0] exp_pipe [0:LAT-1];
    integer    idx;

    always @(posedge clk)
        if (rst_n) begin
            for (idx = 0; idx < LAT-1; idx = idx + 1)
                exp_pipe[idx] <= exp_pipe[idx+1];
            exp_pipe[LAT-1] <= (in_valid) ? calc_expect(in_a[7:0], in_b[7:0])
                                          : 18'hx;
        end

    // function: expected 18-bit result
    function [17:0] calc_expect;
        input [7:0] a8, b8;
        reg  [15:0] mul;
    begin
        mul = a8 * b8;
        calc_expect = {2'b00, mul};
    end
    endfunction

    // ------------------------------------------------------------------------
    // stimulus
    integer i, errors; initial errors = 0;
    parameter RAND_BEATS   = 100;   // random with idle cycle
    parameter STRESS_BEATS = 2000;  // continuous stream

    initial begin
        @(posedge rst_n);

        // ---- 4 boundary vectors -
        send(8'h00, 8'h00);
        send(8'hFF, 8'hFF);
        send(8'h01, 8'h7F);
        send(8'h80, 8'h80);

        // ---- 100 random vectors (1-cycle gap) --
        for (i = 0; i < RAND_BEATS; i = i + 1)
            send($random, $random);

        // ---- full-throttle stress vectors ----
        for (i = 0; i < STRESS_BEATS; i = i + 1) begin
            @(posedge clk);
            in_valid <= 1'b1;
            in_a     <= {24'd0, $random};
            in_b     <= {24'd0, $random};
        end
        @(posedge clk) begin
            in_valid <= 1'b0;
            in_a     <= 32'd0;
            in_b     <= 32'd0;
        end

        // ---- allow pipeline flush --
        repeat (LAT + 20) @(posedge clk);

        // ---- summary ----
        if (errors == 0)
            $display("******* MUL1x8x8 TB PASSED including boundary + random + stress***)");
        else
            $fatal("TB FAILED with %0d error(s)", errors);
        $finish;
    end

    // task: single vector with 1-cycle idle after
    task send;
        input [7:0] a8, b8;
    begin
        @(posedge clk);
        in_valid <= 1'b1;
        in_a     <= {24'd0, a8};
        in_b     <= {24'd0, b8};
        @(posedge clk);
        in_valid <= 1'b0;
    end
    endtask

    // result checker
    always @(posedge clk)
        if (out_valid)
            if (out_sum !== exp_pipe[0]) begin
                errors = errors + 1;
                $display("Mismatch @%0t : got %05x  exp %05x",
                         $time, out_sum, exp_pipe[0]);
            end

endmodule
