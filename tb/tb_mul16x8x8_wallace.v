`timescale 1ns/1ps
// ============================================================================
//  tb_mul16x8x8_wallace  -  standalone testbench (200 MHz)
// ============================================================================

module tb_mul16x8x8_wallace;

    // ---------- DUT ----------
    reg              clk   = 0;
    reg              rst_n = 0;
    reg              in_valid = 0;
    reg  [127:0]     in_a  = 0;
    reg  [127:0]     in_b  = 0;
    wire             out_valid;
    wire [19:0]      out_sum;

    mul16x8x8_wallace dut (
        .clk(clk), .rst_n(rst_n),
        .in_valid(in_valid),
        .in_a(in_a), .in_b(in_b),
        .out_valid(out_valid), .out_sum(out_sum)
    );

    // ---------- 200 MHz clock ----------
    always #2.5 clk = ~clk;

    // ---------- golden FIFO ----------
    localparam DEPTH = 32768; 
    reg [19:0] fifo_data [0:DEPTH-1];
    reg [15:0] wr_ptr = 0, rd_ptr = 0;
    integer    in_cnt = 0, out_cnt = 0, pass = 0, fail = 0;

    // ---------- reset ----------
    initial begin
        repeat (5) @(posedge clk);
        rst_n = 1;
    end

    task push_exp;
        input [127:0] a, b;
        integer idx;
        reg [7:0]  byte_a, byte_b;
        reg [19:0] sum_lane;
    begin
        sum_lane = 0;
        for (idx = 0; idx < 16; idx = idx + 1) begin
            byte_a   = a[idx*8 +: 8];
            byte_b   = b[idx*8 +: 8];
            sum_lane = sum_lane + byte_a * byte_b;   // 20-bit safe
        end
        fifo_data[wr_ptr] = sum_lane;
        wr_ptr = wr_ptr + 1;
    end
    endtask

    task apply_vec;
        input [127:0] a, b;
    begin
        @(posedge clk);
        in_valid <= 1'b1;  in_a <= a;  in_b <= b;
        push_exp(a, b);    in_cnt = in_cnt + 1;
        @(posedge clk);
        in_valid <= 1'b0;                       // 1-cycle 
    end
    endtask

    // ---------- stimulus ----------
    integer k;
    reg [127:0] alt_pat;
    initial begin : STIM
        wait (rst_n);

        alt_pat = {128{1'b0}};
        for (k = 0; k < 16; k = k + 2)
            alt_pat[k*8 +: 8] = 8'hFF;

        apply_vec(128'h0,               128'h0              );
        apply_vec({16{8'hFF}},          {16{8'hFF}}         );
        apply_vec(128'h0000_0000_0000_00FF,
                  128'h0000_0000_0000_00FF);
        apply_vec(128'hFF00_0000_0000_0000,
                  128'h00FF_FFFF_FFFF_FFFF);
        apply_vec(128'h0123_4567_89AB_CDEF_FEDC_BA98_7654_3210,
                  128'h89AB_CDEF_0123_4567_7654_3210_FEDC_BA98);

        repeat (10000) begin
            @(posedge clk);
            if ($random % 2)
                apply_vec({4{$random}}, {4{$random}});
        end

        wait (out_cnt == in_cnt);
        #50;
        $display("PASS=%0d  FAIL=%0d", pass, fail);
        $finish;
    end

    // ---------- checker ----------
    always @(posedge clk) begin
        if (out_valid) begin
            if (out_sum === fifo_data[rd_ptr])
                pass = pass + 1;
            else begin
                $display("Mismatch @%0t  exp=%0d  got=%0d",
                         $time, fifo_data[rd_ptr], out_sum);
                fail = fail + 1;
            end
            rd_ptr  = rd_ptr  + 1;
            out_cnt = out_cnt + 1;
        end
    end

endmodule
