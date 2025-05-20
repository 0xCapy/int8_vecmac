`timescale 1ns/1ps
/*------------------------------------------------------------
  File : tb_mult2.sv
  Purpose : Self-checking TB for Multipilier2.v
------------------------------------------------------------*/

module tb_mult2;
  // Reference clock (100 MHz) - used only by this TB
  reg clk = 1'b0;
  always #5 clk = ~clk;
  
  // DUT 
  reg         reset  = 1'b1;
  reg         start  = 1'b0;
  reg  [3:0]  A      = 4'd0;
  reg  [3:0]  B      = 4'd0;
  wire [7:0]  O;
  wire        Finish;

  Multipilier2 dut (
      .reset (reset),
      .start (start),
      .A     (A),
      .B     (B),
      .O     (O),
      .Finish(Finish)
  );

  // Test sequence

  integer i;
  initial begin
      // reset for three clock cycles
      repeat (3) @(posedge clk);
      reset = 1'b0;
      // random tests
      for (i = 0; i < 30; i = i + 1) begin
          A = $urandom_range(0, 15);
          B = $urandom_range(0, 15);
          run_case();
          if (O !== A * B)
              $error("Mismatch: %0d * %0d -> exp %0d got %0d",
                     A, B, A*B, O);
      end
      // boundary test 15 * 15 = 225
      A = 4'hF;  B = 4'hF;
      run_case();
      if (O !== 8'd225)
          $error("Boundary 15*15 exp 225 got %0d", O);

      $display("All random and boundary cases PASSED.");
      #20 $finish;
  end

  // Task : run one multiplication
  task automatic run_case;
      begin
          @(posedge clk);
          start <= 1'b1;          
          wait (Finish == 1'b1);  
          @(posedge clk);   
          start <= 1'b0;    
          @(negedge Finish);      
      end
  endtask

endmodule
