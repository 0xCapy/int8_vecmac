`timescale 1ns/1ps
// ======================================================================
//  Testbench for adder_tree4 (2-stage, 4Ã—16-bit âž? 18-bit)
module tb_adder_tree4;

    // ===== DUT ports =====
    reg         clk = 0;
    reg         rst_n = 0;
    reg         in_valid = 0;
    reg  [15:0] p0 = 0, p1 = 0, p2 = 0, p3 = 0;
    wire        out_valid;
    wire [17:0] sum;

    adder_tree4 dut (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid),
        .p0(p0), .p1(p1), .p2(p2), .p3(p3),
        .out_valid(out_valid), .sum(sum)
    );

    // 100 MHz
    always #5 clk = ~clk;

    // ===== golden model =====
    function automatic [17:0] gold4 (
        input [15:0] a, b, c, d
    );
        gold4 = a + b + c + d; 
    endfunction

    integer i;
    integer err = 0;
    reg [17:0] gold;

    initial begin
        $display("\n=== Adder-Tree4 standalone TB ===");
        // reset
        rst_n = 0; repeat (3) @(posedge clk); rst_n = 1;

        for (i = 0; i < 1000; i = i + 1) begin
            // ---- random inputs ----
            @(negedge clk);
            p0 = $urandom;  // 16-bit
            p1 = $urandom;
            p2 = $urandom;
            p3 = $urandom;
            in_valid = 1;
            gold = gold4(p0, p1, p2, p3);

            @(negedge clk);          
            in_valid = 0;

            // wait pipeline latency = 2 clk
            @(posedge clk); @(posedge clk);

            if (out_valid !== 1'b1 || sum !== gold) begin
                $display("FAIL @vec %0d  exp=%h  got=%h", i, gold, sum);
                err = err + 1;
            end
        end

        if (err == 0)
            $display("=== PASS : all vectors matched ===");
        else
            $display("=== %0d mismatches ===", err);
        $finish;
    end
endmodule
