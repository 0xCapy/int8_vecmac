// -----------------------------------------------------------------------------
//  Testbench for 4×(8×8) unsigned Wallace-Tree Multiplier
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module tb_mul4x8x8_wallace;
  //-------------------------------------------------------
  //  Parameters
  //-------------------------------------------------------
  localparam CLK_PERIOD = 5;            // 200 MHz
  localparam TEST_NUM   = 10000;
  integer i;

  //-------------------------------------------------------
  //  DUT interface
  //-------------------------------------------------------
  reg         clk  = 0;
  reg         rst_n = 0;
  reg         in_valid = 0;
  reg  [7:0]  in_a [0:3];
  reg  [7:0]  in_b [0:3];
  wire        out_valid;
  wire [15:0] product [0:3];

  //-------------------------------------------------------
  //  Clock & reset
  //-------------------------------------------------------
  always #(CLK_PERIOD/2) clk = ~clk;

  initial begin
    #7 rst_n = 1;               // release reset after some time
  end

  //-------------------------------------------------------
  //  DUT instantiation
  //-------------------------------------------------------
  mul4x8x8_wallace dut (
    .clk       (clk),
    .rst_n     (rst_n),
    .in_valid  (in_valid),
    .in_a0     (in_a[0]),
    .in_a1     (in_a[1]),
    .in_a2     (in_a[2]),
    .in_a3     (in_a[3]),
    .in_b0     (in_b[0]),
    .in_b1     (in_b[1]),
    .in_b2     (in_b[2]),
    .in_b3     (in_b[3]),
    .out_valid (out_valid),
    .p0        (product[0]),
    .p1        (product[1]),
    .p2        (product[2]),
    .p3        (product[3])
  );

  //-------------------------------------------------------
  //  Random stimulus & checker
  //-------------------------------------------------------
  reg [31:0] seed = 32'h5A5AA5A5;
  reg [15:0] golden [0:3];

  task automatic rand_vec;
    output [7:0] ra, rb;
    begin
      seed = {$random(seed)};
      ra   = seed[7:0];
      seed = {$random(seed)};
      rb   = seed[7:0];
    end
  endtask

  initial begin
    @(posedge rst_n);            // wait reset de-assert
    for (i = 0; i < TEST_NUM; i = i + 1) begin
      // random generate four pairs each cycle
      in_valid = 1'b1;
      rand_vec(in_a[0], in_b[0]);
      rand_vec(in_a[1], in_b[1]);
      rand_vec(in_a[2], in_b[2]);
      rand_vec(in_a[3], in_b[3]);
      golden[0] = in_a[0] * in_b[0];
      golden[1] = in_a[1] * in_b[1];
      golden[2] = in_a[2] * in_b[2];
      golden[3] = in_a[3] * in_b[3];
      @(posedge clk);            // 1-cycle pipeline in DUT
      in_valid = 1'b0;
      @(posedge clk);            // wait out_valid
      if (out_valid) begin
        if (product[0] !== golden[0] ||
            product[1] !== golden[1] ||
            product[2] !== golden[2] ||
            product[3] !== golden[3]) begin
          $display("Mismatch at vector %0d!", i);
          $display("A=%0d,B=%0d, P=%0d, G=%0d",
                   in_a[0], in_b[0], product[0], golden[0]);
          $fatal(1);
        end
      end
    end
    $display("TB finished without mismatches.");
    $finish;
  end
endmodule
