`timescale 1ns/1ps
// =============================================================================
//  tb_mul4x8x8_wallace  - boundary + random + full-throttle stress
//  Discription : This file test 4x8x8 Mac Intergrating design
//  Author: Hubo 17/05/2025
// =============================================================================
module tb_mul4x8x8_wallace;
    reg         clk = 0, rst_n = 0, in_valid = 0;
    reg  [31:0] in_a  = 0, in_b  = 0;
    wire        out_valid;
    wire [17:0] out_sum;

    mul4x8x8_wallace dut (
        .clk(clk), .rst_n(rst_n),
        .in_valid(in_valid),
        .in_a(in_a), .in_b(in_b),
        .out_valid(out_valid),
        .out_sum(out_sum)
    );
    always #5 clk = ~clk;

    // ------------------------------------------------------------------------
    // Scoreboard FIFO
    localparam DEPTH = 16384;
    reg [17:0] fifo_data [0:DEPTH-1];
    reg [15:0] wr_ptr = 0, rd_ptr = 0;
    integer    in_cnt = 0, out_cnt = 0, pass = 0, fail = 0;

    // reset
    initial begin
        repeat (5) @(posedge clk);
        rst_n = 1;
    end

    // ------------------------------------------------------------------------
    // task : push expected dot-product into FIFO
    task push_exp;
        input [31:0] a, b;
        reg [7:0] a0,a1,a2,a3, b0,b1,b2,b3;
        reg [17:0] dot;
    begin
        a0 = a[7:0];   a1 = a[15:8];  a2 = a[23:16];  a3 = a[31:24];
        b0 = b[7:0];   b1 = b[15:8];  b2 = b[23:16];  b3 = b[31:24];
        dot = a0*b0 + a1*b1 + a2*b2 + a3*b3;   // 18-bit safe
        fifo_data[wr_ptr] = dot;
        wr_ptr = wr_ptr + 1;
    end
    endtask

    // ------------------------------------------------------------------------
    // task : send one vector (1-cycle gap afterwards)
    task apply_vec;
        input [31:0] a, b;
    begin
        @(posedge clk);
        in_valid <= 1'b1;  in_a <= a;  in_b <= b;
        push_exp(a, b);  in_cnt = in_cnt + 1;
        @(posedge clk);
        in_valid <= 1'b0;
    end
    endtask

    // ------------------------------------------------------------------------
    // stimulus
    integer i, r;
    reg [31:0] rand_a, rand_b;
    parameter RAND_BEATS   = 10000;
    parameter STRESS_BEATS = 4096;

    initial begin : STIM
        wait (rst_n);

        // -------- boundary --------
        apply_vec(32'h0000_0000, 32'h0000_0000);
        apply_vec(32'hFFFF_FFFF, 32'hFFFF_FFFF);
        apply_vec(32'h0000_00FF, 32'h0000_00FF);
        apply_vec(32'hFF00_0000, 32'h00FF_FFFF);
        apply_vec(32'h1234_5678, 32'h8765_4321);

        // -------- random (1-cycle idle) --------
        for (i = 0; i < RAND_BEATS; i = i + 1)
            apply_vec($random, $random);

        // -------- full-throttle stress vectors --------
        for (r = 0; r < STRESS_BEATS; r = r + 1) begin
            @(posedge clk);
            in_valid <= 1'b1;
            rand_a   = $random;
            rand_b   = $random;
            in_a     <= rand_a;
            in_b     <= rand_b;
            push_exp(rand_a, rand_b);
            in_cnt   = in_cnt + 1;
        end
        @(posedge clk) in_valid <= 1'b0;

        // -------- wait for pipeline flush --------
        wait (out_cnt == in_cnt);
        #20;
        $display("PASS=%0d  FAIL=%0d", pass, fail);
        if (fail == 0)
            $display("*****All tests passed (boundary + random + stress) ***");
        else
            $display("=== FAILED with %0d mismatches ===", fail);
        $finish;
    end

    // ------------------------------------------------------------------------
    // checker
    always @(posedge clk) begin
        if (out_valid) begin
            if (out_sum === fifo_data[rd_ptr])
                pass = pass + 1;
            else begin
                $display("Mismatch @%0t  EXP=%0d  GOT=%0d",
                         $time, fifo_data[rd_ptr], out_sum);
                fail = fail + 1;
            end
            rd_ptr  = rd_ptr + 1;
            out_cnt = out_cnt + 1;
        end
    end

endmodule
