`timescale 1ns/1ps
// ============================================================================
//  tb_mul8x8x8_wallace – standalone testbench for mul8x8x8_wallace
//  • BUS  : 64-bit  (8 × unsigned INT8 packed)
//  • CLK  : 100 MHz (#5 ns)
//  • LAT  : 8 cycles  (mult 3 + align 1 + tree 3 + out 1)
//  • 5 boundary + 10 000 random beats
// ============================================================================
module tb_mul8x8x8_wallace;

    // --------------------------------------------------------------------- 
    // constants
    // --------------------------------------------------------------------- 
    parameter BUSW    = 64;          // 8 × 8-bit
    parameter LATENCY = 8;           // pipeline cycles to out_valid
    parameter DEPTH   = 16384;       // FIFO depth
    parameter RAND_BEATS = 10000;

    // --------------------------------------------------------------------- 
    // clock & reset  (100 MHz)
    // --------------------------------------------------------------------- 
    reg clk = 0;          always #5 clk = ~clk;
    reg rst_n = 0;

    // --------------------------------------------------------------------- 
    // DUT
    // --------------------------------------------------------------------- 
    reg             in_valid = 0;
    reg  [BUSW-1:0] in_a = 0, in_b = 0;
    wire            out_valid;
    wire [18:0]     out_sum;

    mul8x8x8_wallace dut (
        .clk(clk), .rst_n(rst_n),
        .in_valid(in_valid),
        .in_a(in_a), .in_b(in_b),
        .out_valid(out_valid),
        .out_sum(out_sum)
    );

    // --------------------------------------------------------------------- 
    // golden FIFO
    // --------------------------------------------------------------------- 
    reg [18:0] fifo [0:DEPTH-1];
    reg [13:0] wr_ptr = 0, rd_ptr = 0;
    integer    pass = 0, fail = 0, in_cnt = 0, out_cnt = 0;

    // --------------------------------------------------------------------- 
    // reset release
    // --------------------------------------------------------------------- 
    initial begin
        repeat (4) @(posedge clk);
        rst_n = 1;
    end

    // --------------------------------------------------------------------- 
    // task: push expected result
    // --------------------------------------------------------------------- 
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
            dot = dot + ba * bb;           // 19-bit safe
        end
        fifo[wr_ptr] = dot;
        wr_ptr = wr_ptr + 1;
    end
    endtask

    // --------------------------------------------------------------------- 
    // task: send one beat
    // --------------------------------------------------------------------- 
    task apply_vec;
        input [BUSW-1:0] a_d, b_d;
    begin
        @(posedge clk);
        in_valid <= 1'b1; in_a <= a_d; in_b <= b_d;
        push_exp(a_d, b_d); in_cnt = in_cnt + 1;
        @(posedge clk);
        in_valid <= 1'b0;                 // 插 1-cycle 空拍，易看波形
    end
    endtask

    // --------------------------------------------------------------------- 
    // stimulus
    // --------------------------------------------------------------------- 
    integer r;
    initial begin : STIM
        wait (rst_n);

        // ---- 5 boundary beats ----
        apply_vec(64'h0,              64'h0             );
        apply_vec(64'hFFFF_FFFF_FFFF_FFFF,
                  64'hFFFF_FFFF_FFFF_FFFF);
        apply_vec(64'hFF,             64'hFF            ); // 仅 lane0=FF
        apply_vec(64'hFF00_FF00_FF00_FF00,
                  64'h00FF_00FF_00FF_00FF);
        apply_vec(64'h0123_4567_89AB_CDEF,
                  64'hFEDC_BA98_7654_3210);

        // ---- random beats ----
        for (r = 0; r < RAND_BEATS; r = r + 1)
            apply_vec({2{$random}}, {2{$random}});   // 64-bit rand

        // ---- wait pipeline flush ----
        repeat (LATENCY+4) @(posedge clk);
        wait (out_cnt == in_cnt);
        #20;
        $display("PASS=%0d  FAIL=%0d", pass, fail);
        $finish;
    end

    // --------------------------------------------------------------------- 
    // checker
    // --------------------------------------------------------------------- 
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
