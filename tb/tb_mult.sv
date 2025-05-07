`timescale 1ns/1ps
module tb_mult;

  //--------------------------------------------------------------------
  localparam CLK_HALF = 5ns;
  localparam N_CASES  = 30; 
  reg             clk  = 0;
  reg             rst  = 1;
  reg             start = 0;
  reg  [3:0]      a_in;
  reg  [3:0]      b_in;
  wire [7:0]      out;
  wire            finish;

  //--------------------------------------------------------------------
  always #CLK_HALF clk = ~clk;

  //--------------------------------------------------------------------
  multipilier dut (
      .a_in   (a_in),
      .b_in   (b_in),
      .clk    (clk),
      .rst    (rst),
      .out    (out),
      .start  (start),
      .finish (finish)
  );

  //--------------------------------------------------------------------
  integer i;
  initial begin

    repeat(3) @(posedge clk);
    rst = 0;                   
    @(posedge clk);


    for(i = 0; i < N_CASES; i = i + 1) begin
      a_in  = $urandom_range(0,15);
      b_in  = $urandom_range(0,15);

      start = 1;
      @(posedge clk);
      start = 0;

      wait(finish);

      if(out !== a_in * b_in) begin
        $error("[%0t] wrong: %0d * %0d = %0d (result =  %0d)",
               $time, a_in, b_in, a_in*b_in, out);
      end
      @(posedge clk);     
    end

    // bondary
    a_in = 4'hF; b_in = 4'hF; start = 1; @(posedge clk); start = 0;
    wait(finish);
    if(out !== 8'd225) $error("should be 225, result = %0d", out);

    $display("ALL PASS");
    #10 $finish;
  end
endmodule
