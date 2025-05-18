`timescale 1ns/1ps
module tb_vector_mac_top_fix;

    //----------------------------------------------------------------
    // DUT signals
    //----------------------------------------------------------------
    reg         clk = 0;
    reg         rst_n = 0;
    reg         in_valid = 0;
    reg  [31:0] in_a = 0, in_b = 0;
    wire        out_valid;
    wire [31:0] mac_out;

    vector_mac_top dut (
        .clk(clk), .rst_n(rst_n),
        .in_valid(in_valid),
        .in_a(in_a), .in_b(in_b),
        .out_valid(out_valid),
        .mac_out(mac_out)
    );

    // 100 MHz clock
    always #5 clk = ~clk;

    //----------------------------------------------------------------
    // parameters
    //----------------------------------------------------------------
    localparam DELAY = 6;      // core latency (sum_valid 出现延迟)
    localparam BEATS = 250;    // 250×4 = 1000 elements per MAC

    //----------------------------------------------------------------
    // helper : 8-bit dot-product
    //----------------------------------------------------------------
    function [17:0] dot4(input [31:0] a, b);
        reg [7:0] a0,a1,a2,a3,b0,b1,b2,b3;
    begin
        {a3,a2,a1,a0} = a;
        {b3,b2,b1,b0} = b;
        dot4 = a0*b0 + a1*b1 + a2*b2 + a3*b3;
    end
    endfunction

    //----------------------------------------------------------------
    // delay-FIFO to align with hardware latency
    //----------------------------------------------------------------
    reg [17:0] fifo [0:DELAY-1];
    reg        v_fifo[0:DELAY-1];

    integer k;
    task push_fifo(input [17:0] d, input v);
    begin
        for (k=DELAY-1; k>0; k=k-1) begin
            fifo [k] <= fifo [k-1];
            v_fifo[k] <= v_fifo[k-1];
        end
        fifo [0]  <= d;
        v_fifo[0] <= v;
    end
    endtask

    //----------------------------------------------------------------
    // golden accumulator
    //----------------------------------------------------------------
    reg [31:0] gold_acc = 0;
    integer beat_cnt = 0;
    integer pass = 0, fail = 0;

    //----------------------------------------------------------------
    // stimulus : 5 boundary + 10 000 random
    //----------------------------------------------------------------
    task drive(input [31:0] a, b);
    begin
        @(posedge clk);
        in_valid <= 1; in_a <= a; in_b <= b;
        @(posedge clk);
        in_valid <= 0;
    end
    endtask

    integer i;
    initial begin
        // reset
        repeat(5) @(posedge clk);
        rst_n = 1;

        // boundary patterns
        drive(32'h0000_0000, 32'h0000_0000);
        drive(32'hFFFF_FFFF, 32'hFFFF_FFFF);
        drive(32'h0000_00FF, 32'h0000_00FF);
        drive(32'hFF00_0000, 32'h00FF_FFFF);
        drive(32'h1234_5678, 32'h8765_4321);

        // 10 000 random
        for (i=0; i<10000; i=i+1) begin
            @(posedge clk);
            if ($random%2)
                drive($random, $random);
        end

        // drain pipeline
        repeat(1000) @(posedge clk);

        if (fail==0) $display("#### VECTOR_MAC_TOP PASS ####");
        else         $display("FAIL=%0d", fail);
        $finish;
    end

    //----------------------------------------------------------------
    // main checker ── 每拍移位 FIFO，out_valid 时比较
    //----------------------------------------------------------------
    always @(posedge clk) begin
        // push current dot4 (if in_valid) into FIFO
        push_fifo(dot4(in_a,in_b), in_valid);

        // consume FIFO head WHEN head_valid
        if (v_fifo[DELAY-1]) begin
            gold_acc = gold_acc + fifo[DELAY-1];
            beat_cnt = beat_cnt + 1;
            if (beat_cnt == BEATS) beat_cnt = 0;
        end

        // compare at DUT out_valid (== last beat)
        if (out_valid) begin
            if (gold_acc === mac_out) pass = pass + 1;
            else begin
                $display("Mismatch @%0t  exp=%0d  got=%0d",
                         $time, gold_acc, mac_out);
                fail = fail + 1;
            end
            gold_acc = 0;   // clear for next window
        end
    end
endmodule
