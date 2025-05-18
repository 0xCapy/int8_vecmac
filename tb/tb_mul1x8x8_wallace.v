`timescale 1ns/1ps
// =============================================================================
//  tb_mul1x8x8_wallace  (REV-E) - fixed-5-cycle pipeline checker
// -----------------------------------------------------------------------------
//  ? mul1x8x8_wallace = 3-cycle multiplier + 2-cycle adder_tree -- LATENCY = 5.
// =============================================================================
module tb_mul1x8x8_wallace;

// ---------- clock & reset ---------------------------------------------------
localparam CLK_HALF = 5;   // 100 MHz ¡ú 10 ns
reg clk = 0; always #CLK_HALF clk = ~clk;

reg rst_n = 0;
initial #20 rst_n = 1;

// ---------- DUT -------------------------------------------------------------
reg         in_valid = 0;
reg  [31:0] in_a = 0, in_b = 0;
wire        out_valid;
wire [17:0] out_sum;

mul1x8x8_wallace dut (
    .clk(clk), .rst_n(rst_n),
    .in_valid(in_valid), .in_a(in_a), .in_b(in_b),
    .out_valid(out_valid), .out_sum(out_sum)
);

// ---------- 5-cycle expectation pipeline ------------------------------------
localparam LAT = 5;
reg [17:0] exp_pipe [0:LAT-1];
integer idx;

// shift pipeline each clk
always @(posedge clk) begin
    if (rst_n) begin
        for (idx = 0; idx < LAT-1; idx = idx + 1)
            exp_pipe[idx] <= exp_pipe[idx+1];
        exp_pipe[LAT-1] <= (in_valid) ? calc_expect(in_a[7:0], in_b[7:0]) : 18'dx;
    end
end

// ---------- function to calc 18-bit expected (dummy)
function [17:0] calc_expect;
    input [7:0] a; input [7:0] b;
    reg [15:0] mul;
begin
    mul = a * b;
    calc_expect = {2'b00, mul};
end
endfunction

// ---------- stimulus --------------------------------------------------------
integer i, errors; initial errors = 0;

initial begin
    @(posedge rst_n);
    // 4 boundary
    send(8'h00, 8'h00);
    send(8'hFF, 8'hFF);
    send(8'h01, 8'h7F);
    send(8'h80, 8'h80);
    // 100 random
    for (i=0;i<100;i=i+1) send($random, $random);
    @(posedge clk); in_valid<=0; in_a<=0; in_b<=0;
    repeat(110) @(posedge clk);
    if (errors==0) $display(">>> MUL1x8x8 TB PASSED (104 vectors)");
    else $fatal("TB FAILED with %0d error(s)", errors);
    $finish;
end

// task send
task send;
    input [7:0] a8; input [7:0] b8;
begin
    @(posedge clk);
    in_valid <= 1; in_a <= {24'd0,a8}; in_b <= {24'd0,b8};
end
endtask

// result compare
always @(posedge clk) begin
    if (out_valid) begin
        if (out_sum !== exp_pipe[0]) begin
            errors = errors + 1;
            $display("Mismatch @%0t : got %05x expected %05x", $time, out_sum, exp_pipe[0]);
        end
    end
end

endmodule
