`timescale 1ns/1ps
// ==================================================================
//  Testbench for 8¡Á8 Wallace-Tree Multiplier
//  Description: This file test unit multiplier including boundary, random, stress tests
//  Author: Hubo 17/05/2025
// ==================================================================
module tb_wallace_mult8;

    // -----------------------------------------------------------------------
    // DUT interface signals
    reg         clk       = 0;
    reg         rst_n     = 0;
    reg         in_valid  = 0;
    reg  [7:0]  a         = 8'd0;
    reg  [7:0]  b         = 8'd0;
    wire        out_valid;
    wire [15:0] product;

    // -----------------------------------------------------------------------
    // Instantiate Device Under Test
    // ------------------------------------------------------------
    wallace_mult8 dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (in_valid),
        .a         (a),
        .b         (b),
        .out_valid (out_valid),
        .product   (product)
    );

    // -----------------------------------------------------------------------
    // 100 MHz clock
    // -----------------------------------------------------------------------
    always #5 clk = ~clk;

    // -----------------------------------------------------------------------
    // FIFO
    reg [7:0]   a_fifo   [0:2047];
    reg [7:0]   b_fifo   [0:2047];
    reg [15:0]  exp_fifo [0:2047];
    integer wr_ptr = 0;
    integer rd_ptr = 0;

    integer pass_cnt = 0;
    integer fail_cnt = 0;

    // -----------------------------------------------------------------------
    // Task
    // -----------------------------------------------------------------------
    task push_vec;
        input [7:0] va;
        input [7:0] vb;
        begin
            @(negedge clk);
            in_valid <= 1'b1;
            a        <= va;
            b        <= vb;

            a_fifo  [wr_ptr] = va;
            b_fifo  [wr_ptr] = vb;
            exp_fifo[wr_ptr] = va * vb;
            wr_ptr = wr_ptr + 1;

            @(negedge clk);
            in_valid <= 1'b0;
        end
    endtask

    // ----------------------------------------------------
    // Real-time checker
    always @(posedge clk) begin
        if (out_valid) begin
            if (product === exp_fifo[rd_ptr]) begin
                $display("PASS  @idx=%0d  %0d * %0d = %0d",
                         rd_ptr, a_fifo[rd_ptr], b_fifo[rd_ptr], product);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("FAIL  @idx=%0d  %0d * %0d  EXP=%0d  GOT=%0d",
                         rd_ptr, a_fifo[rd_ptr], b_fifo[rd_ptr],
                         exp_fifo[rd_ptr], product);
                fail_cnt = fail_cnt + 1;
            end
            rd_ptr = rd_ptr + 1;
        end
    end

    // -----------------------------------------------------------------------
    // Stimulus
    integer i;
    reg [31:0] rnd;
    reg [7:0]  rand_a;
    reg [7:0]  rand_b;

    initial begin
        $display("Wallace-8¡Á8 Multiplier Testbench Start");
        rst_n = 0;
        repeat (4) @(posedge clk);
        rst_n = 1;

        // ---------- Boundary tests -------
        push_vec(8'h00, 8'h00);   // 0 x 0
        push_vec(8'hFF, 8'hFF);   // 255 x 255
        push_vec(8'h01, 8'hFF);   // 1  x 255
        push_vec(8'h80, 8'h02);   // 128 x 2

        // ---------- 100 random vectors ----------
        for (i = 0; i < 100; i = i + 1) begin
            rnd     = $random;    // 32-bit
            rand_a  = rnd[7:0];
            rand_b  = rnd[15:8];
            push_vec(rand_a, rand_b);
        end

        // ---------- Stress test 1000pair-----
        for (i = 0; i < 1000; i = i + 1) begin
            rnd    = $random;
            rand_a = rnd[7:0];
            rand_b = rnd[15:8];

            @(negedge clk);
            in_valid <= 1'b1;
            a        <= rand_a;
            b        <= rand_b;

            a_fifo  [wr_ptr] = rand_a;
            b_fifo  [wr_ptr] = rand_b;
            exp_fifo[wr_ptr] = rand_a * rand_b;
            wr_ptr = wr_ptr + 1;
        end
        @(negedge clk);
        in_valid <= 1'b0;

        wait (rd_ptr == wr_ptr);
        $display("*** SUMMARY : PASS=%0d  FAIL=%0d ***", pass_cnt, fail_cnt);
        if (fail_cnt === 0) begin
            $display("******All pass, Including Boundary, stress and random ");
        end
        $finish;
    end

endmodule
