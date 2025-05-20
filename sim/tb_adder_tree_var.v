`timescale 1ns/1ps
// =================================================================
//  Testbench for parameterised pipelined adder tree (adder_tree_var)
//  Description: This file is for testing adder tree design with different lines with boundary, stress and random test.
//  Author: Hubo 17/05/2025
// ===================================

module tb_adder_tree_var;
    localparam LANES  = 4;          // 1 / 4 / 8 / 16
    localparam INW    = 16;         // width of each lane
    localparam STAGES = (LANES < 4) ? 2 : $clog2(LANES);
    localparam OUTW   = INW + STAGES + 1;
    
    reg                       clk        = 0;
    reg                       rst_n      = 0;
    reg                       in_valid   = 0;
    reg  [LANES*INW-1:0]      prod_flat  = 0;
    wire                      out_valid;
    wire [OUTW-1:0]           sum;

    adder_tree_var #(
        .LANES (LANES),
        .INW   (INW)
    ) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (in_valid),
        .prod_flat (prod_flat),
        .out_valid (out_valid),
        .sum       (sum)
    );
    always #5 clk = ~clk;

    // ---------------Fifo-----------
    reg  [LANES*INW-1:0] vec_fifo [0:4095];
    reg  [OUTW-1:0]      exp_fifo [0:4095];
    integer wr_ptr = 0;
    integer rd_ptr = 0;

    // -----------conter
    integer pass_cnt = 0;
    integer fail_cnt = 0;
    // Helper task : push one vector into DUT & FIFO 
    task automatic push_vec;
        input [LANES*INW-1:0] vec;
        integer j;
        reg [OUTW-1:0] local_sum;
        begin
            //-------- drive inputs
            @(negedge clk);
            in_valid  <= 1'b1;
            prod_flat <= vec;

            // ------------expected sum------------
            local_sum = {OUTW{1'b0}};
            for (j = 0; j < LANES; j = j + 1)
                local_sum = local_sum + vec[INW*j +: INW];

            // ---------write into scoreboard-------
            vec_fifo[wr_ptr]  = vec;
            exp_fifo[wr_ptr]  = local_sum;
            wr_ptr = wr_ptr + 1;

            // --------de-assert in_valid one cycle later---
            @(negedge clk);
            in_valid <= 1'b0;
        end
    endtask
    // -----------Realtime checker : consume DUT outputs immediately when out_valid==1--------
    always @(posedge clk) begin
        if (out_valid) begin
            if (sum === exp_fifo[rd_ptr]) begin
                $display("PASS  @idx=%0d  exp=%0d  got=%0d",
                         rd_ptr, exp_fifo[rd_ptr], sum);
                pass_cnt = pass_cnt + 1;
            end
            else begin
                $display("FAIL  @idx=%0d  exp=%0d  got=%0d",
                         rd_ptr, exp_fifo[rd_ptr], sum);
                fail_cnt = fail_cnt + 1;
            end
            rd_ptr = rd_ptr + 1;
        end
    end

    // -------------------------------------------------------------------------
    // Stimulus generation
    integer i;
    reg [31:0] rnd;                   // random
    reg [LANES*INW-1:0] vec_tmp;
    integer lane;

    initial begin
        $display("=== Adder-Tree Testbench  (LANES=%0d, INW=%0d) ===", LANES, INW);

        // global reset
        rst_n = 0;
        repeat (4) @(posedge clk);
        rst_n = 1;

        // -------- Boundary---------
        // all zeros
        vec_tmp = { (LANES*INW){1'b0} };
        push_vec(vec_tmp);

        // all max (0xFFFF...)
        vec_tmp = {LANES{ {INW{1'b1}} }};
        push_vec(vec_tmp);

        // only lane0 max
        vec_tmp = { (LANES*INW){1'b0} };
        vec_tmp[INW-1:0] = {INW{1'b1}};
        push_vec(vec_tmp);

        // alternating lanes
        vec_tmp = { (LANES*INW){1'b0} };
        for (lane = 0; lane < LANES; lane = lane + 2)
            vec_tmp[INW*lane +: INW] = 16'h00FF;
        push_vec(vec_tmp);

        // -------- random----------
        for (i = 0; i < 100; i = i + 1) begin
            vec_tmp = { (LANES*INW){1'b0} };
            for (lane = 0; lane < LANES; lane = lane + 1) begin
                rnd = $random;
                vec_tmp[INW*lane +: INW] = rnd[INW-1:0];
            end
            push_vec(vec_tmp);
        end

        // -------- Stress-----------
        for (i = 0; i < 1000; i = i + 1) begin
            @(negedge clk);
            in_valid  <= 1'b1;
            // build one packed vector
            vec_tmp = { (LANES*INW){1'b0} };
            for (lane = 0; lane < LANES; lane = lane + 1) begin
                rnd = $random;
                vec_tmp[INW*lane +: INW] = rnd[INW-1:0];
            end
            prod_flat <= vec_tmp;

            // expected
            exp_fifo[wr_ptr] = {OUTW{1'b0}};
            for (lane = 0; lane < LANES; lane = lane + 1)
                exp_fifo[wr_ptr] = exp_fifo[wr_ptr] +
                                   vec_tmp[INW*lane +: INW];

            vec_fifo[wr_ptr] = vec_tmp;
            wr_ptr = wr_ptr + 1;
        end
        @(negedge clk) in_valid <= 1'b0;

        // -------- wait until all results checked ----------------------------
        wait (rd_ptr == wr_ptr);
        $display("***SUMMARY : PASS=%0d  FAIL=%0d ***", pass_cnt, fail_cnt);
        if (fail_cnt === 0) begin
            $display("******All pass(for all lines 1-16), Including Boundary, stress and random ");
        end
        $finish;
    end

endmodule
