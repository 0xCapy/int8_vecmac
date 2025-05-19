`timescale 1ns/1ps
// ============================================================================
//  tb_mul16x8x8_wallace  - boundary + random + full-throttle stress
//  Discription : This file test 16x8x8 Mac Intergrating design
//  Author: Hubo 17/05/2025
// ============================================================================

module tb_mul16x8x8_wallace;

    // ---------------- DUT ----------------
    reg              clk = 0, rst_n = 0, in_valid = 0;
    reg  [127:0]     in_a = 0,  in_b = 0;
    wire             out_valid;
    wire [19:0]      out_sum;

    mul16x8x8_wallace dut (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid),
        .in_a(in_a), .in_b(in_b), .out_valid(out_valid), .out_sum(out_sum)
    );

    // 200 MHz clock
    always #2.5 clk = ~clk;

    // ------------ FIFO ------------
    localparam DEPTH = 65536;
    reg [19:0] fifo_data [0:DEPTH-1];
    reg [15:0] wr_ptr = 0, rd_ptr = 0;
    integer    in_cnt = 0, out_cnt = 0, pass = 0, fail = 0;

    // reset
    initial begin
        repeat (5) @(posedge clk);
        rst_n = 1;
    end

    // ----------------gold value ---
    task push_exp;
        input [127:0] a, b;
        integer idx;            // lane index
        reg [7:0] ba, bb;
        reg [19:0] dot;
    begin
        dot = 0;
        for (idx = 0; idx < 16; idx = idx + 1) begin
            ba  = a[idx*8 +: 8];
            bb  = b[idx*8 +: 8];
            dot = dot + ba * bb;   // 20-bit safe
        end
        fifo_data[wr_ptr] = dot;
        wr_ptr = wr_ptr + 1;
    end
    endtask

    // ===== helper£º1-cycle =====
    task apply_vec;
        input [127:0] a, b;
    begin
        @(posedge clk);
        in_valid <= 1'b1;  in_a <= a;  in_b <= b;
        push_exp(a, b);    in_cnt = in_cnt + 1;
        @(posedge clk);
        in_valid <= 1'b0;
    end
    endtask

    // ---------------- stimulus ---------
    integer i;
    reg [127:0] rand_a, rand_b;
    parameter RAND_BEATS   = 10000;
    parameter STRESS_BEATS = 8192;

    initial begin : STIM
        wait (rst_n);

        // ---boundary
        apply_vec(128'h0,                        128'h0);
        apply_vec({16{8'hFF}},                   {16{8'hFF}});
        apply_vec(128'h0000_0000_0000_00FF,      128'h0000_0000_0000_00FF);
        apply_vec(128'hFF00_0000_0000_0000,      128'h00FF_FFFF_FFFF_FFFF);
        apply_vec(128'h0123_4567_89AB_CDEF_FEDC_BA98_7654_3210,
                  128'h89AB_CDEF_0123_4567_7654_3210_FEDC_BA98);

        // --random
        for (i = 0; i < RAND_BEATS; i = i + 1)
            apply_vec({4{$random}}, {4{$random}});

        // -stress test
        for (i = 0; i < STRESS_BEATS; i = i + 1) begin
            @(posedge clk);
            in_valid <= 1'b1;
            rand_a   = {4{$random}};
            rand_b   = {4{$random}};
            in_a     <= rand_a;
            in_b     <= rand_b;
            push_exp(rand_a, rand_b);
            in_cnt = in_cnt + 1;
        end
        @(posedge clk) in_valid <= 1'b0;

        // wait for all done
        wait (out_cnt == in_cnt);
        #20;
        $display("PASS=%0d  FAIL=%0d", pass, fail);
        if (fail == 0) begin
            $display("*****All tests passed includ boundary + random + stress ***");
        end
        $finish;
    end

    // ---------------- checker ----------------
    always @(posedge clk) begin
        if (out_valid) begin
            if (out_sum === fifo_data[rd_ptr])
                pass = pass + 1;
            else begin
                $display("Mismatch @%0t  exp=%0d  got=%0d",
                         $time, fifo_data[rd_ptr], out_sum);
                fail = fail + 1;
            end
            rd_ptr  = rd_ptr + 1;
            out_cnt = out_cnt + 1;
        end
    end

endmodule
