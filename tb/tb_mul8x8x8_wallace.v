`timescale 1ns/1ps
// ============================================================================
//  tb_mul8x8x8_wallace  (with full-throttle stress test)
//  Description: This file is for test 8x8x8 integrating MAC module
//  Author: Hubo 17/05/2025
// ============================================================================
module tb_mul8x8x8_wallace;
    parameter BUSW         = 64;
    parameter LATENCY      = 8;        // pipeline cycles to out_valid
    parameter DEPTH        = 16384;    // FIFO depth
    parameter RAND_BEATS   = 10000;    // low-duty random
    parameter STRESS_BEATS = 4096;     // full-duty stress

    // ---------------------------------------------------------------------
    // clock & reset
    reg clk = 0;  always #5 clk = ~clk;   // 100 MHz
    reg rst_n = 0;
    // DUT ports
    reg             in_valid = 0;
    reg  [BUSW-1:0] in_a = 0, in_b = 0;
    wire            out_valid;
    wire [18:0]     out_sum;

    mul8x8x8_wallace dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .in_valid (in_valid),
        .in_a     (in_a),
        .in_b     (in_b),
        .out_valid(out_valid),
        .out_sum  (out_sum)
    );
    // ---------------------------------------------------------------------
    // golden FIFO (scoreboard)
    reg [18:0] fifo [0:DEPTH-1];
    reg [13:0] wr_ptr = 0, rd_ptr = 0;
    integer    pass = 0, fail = 0, in_cnt = 0, out_cnt = 0;
    // reset release
    initial begin
        repeat (4) @(posedge clk);   // 20 ns
        rst_n = 1;
    end

    // ---------------------------------------------------------------------
    // task: push expected result into FIFO
    task push_exp;
        input [BUSW-1:0] a_d, b_d;
        integer k;
        reg [18:0] dot;
        reg [7:0]  ba, bb;
    begin
        dot = 0;
        for (k = 0; k < 8; k = k + 1) begin
            ba  = a_d[k*8 +: 8];
            bb  = b_d[k*8 +: 8];
            dot = dot + ba * bb;        // 19-bit safe
        end
        fifo[wr_ptr] = dot;
        wr_ptr       = wr_ptr + 1;
    end
    endtask

    // ---------------------------------------------------------------------
    // task: apply one beat (with 1-cycle gap afterwards)
    task apply_vec;
        input [BUSW-1:0] a_d, b_d;
    begin
        @(posedge clk);
        in_valid <= 1'b1;  in_a <= a_d;  in_b <= b_d;
        push_exp(a_d, b_d);  in_cnt = in_cnt + 1;
        @(posedge clk);
        in_valid <= 1'b0;
    end
    endtask

    // ---------------------------------------------------------------------
    // stimulus
    integer r;
    reg [BUSW-1:0] rand_a, rand_b;

    initial begin : STIM
        wait (rst_n);

        // ---------- boundary ----------
        apply_vec(64'h0,                   64'h0);
        apply_vec(64'hFFFF_FFFF_FFFF_FFFF, 64'hFFFF_FFFF_FFFF_FFFF);
        apply_vec(64'hFF,                  64'hFF);
        apply_vec(64'hFF00_FF00_FF00_FF00, 64'h00FF_00FF_00FF_00FF);
        apply_vec(64'h0123_4567_89AB_CDEF, 64'hFEDC_BA98_7654_3210);

        // ---------- random beats (low duty, RAND_BEATS) ----------
        for (r = 0; r < RAND_BEATS; r = r + 1) begin
            rand_a = {$random,$random};   // 64-bit
            rand_b = {$random,$random};
            apply_vec(rand_a, rand_b);
        end

        // ---------- full-throttle stress beats ----------
        for (r = 0; r < STRESS_BEATS; r = r + 1) begin
            @(posedge clk);
            in_valid <= 1'b1;
            rand_a   = {$random,$random};
            rand_b   = {$random,$random};
            in_a     <= rand_a;
            in_b     <= rand_b;
            push_exp(rand_a, rand_b);
            in_cnt   = in_cnt + 1;
        end
        @(posedge clk) in_valid <= 1'b0;

        // ---------- wait for pipeline to flush ------
        repeat (LATENCY+4) @(posedge clk);
        wait (out_cnt == in_cnt);
        #20;
        $display("***** PASS=%0d  FAIL=%0d ***", pass, fail);
        if (fail === 0)
            $display("*** All tests passed including boundary + random + stress *****");
        $finish;
    end

    // ---------------------------------------------------------------------
    // checker
    always @(posedge clk) begin
        if (out_valid) begin
            if (out_sum === fifo[rd_ptr])
                pass = pass + 1;
            else begin
                $display("Mismatch @%0t  exp=%0d  got=%0d",
                         $time, fifo[rd_ptr], out_sum);
                fail = fail + 1;
            end
            rd_ptr  = rd_ptr + 1;
            out_cnt = out_cnt + 1;
        end
    end

endmodule
