`timescale 1ns/1ps
module tb_mul4x8x8_wallace;
    // clock & reset
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0; initial #20 rst_n=1;

    // DUT I/O
    reg  in_valid=0;
    reg  [31:0] in_a=0, in_b=0;
    wire out_valid;
    wire [63:0] product;

    mul4x8x8_wallace dut(
        .clk(clk), .rst_n(rst_n),
        .in_valid(in_valid),
        .in_a(in_a), .in_b(in_b),
        .out_valid(out_valid),
        .product(product)
    );

    // stimulus
    integer i;
    reg [7:0] a0,a1,a2,a3,b0,b1,b2,b3;
    reg [15:0] r0,r1,r2,r3;

    initial begin
        @(posedge rst_n);
        for(i=0;i<10000;i=i+1) begin
            a0=$random; a1=$random; a2=$random; a3=$random;
            b0=$random; b1=$random; b2=$random; b3=$random;
            in_a={a3,a2,a1,a0};
            in_b={b3,b2,b1,b0};
            in_valid=1'b1;

            r0=a0*b0; r1=a1*b1; r2=a2*b2; r3=a3*b3;

            @(posedge clk); in_valid=0;

            // wait exactly 3 clocks
            @(posedge clk); @(posedge clk);

            if(!out_valid) begin
                $display("ERROR: out_valid low @%0t",$time); $stop;
            end
            if(product!={r3,r2,r1,r0}) begin
                $display("MISMATCH iter=%0d exp=%h got=%h",
                         i,{r3,r2,r1,r0},product); $stop;
            end
        end
        $display("*** TB finished without mismatches. ***");
        $finish;
    end
endmodule
