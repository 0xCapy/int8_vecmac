`timescale 1ns/1ps
// -----------------------------------------------------------------------------
//  Testbench : tb_mul4x8x8_wallace   (Vivado 2021.1 compatible)
//  Validates the 4-lane 8¡Á8 Wallace multiplier - 1-cycle latency.
// -----------------------------------------------------------------------------
module tb_mul4x8x8_wallace;
  //-------------------------------------------------------------------
  //  Clock & Reset
  //-------------------------------------------------------------------
  reg clk   = 1'b0;
  reg rst_n = 1'b0;
  always #5 clk = ~clk;               // 100?MHz ¡ú 10 ns period

  //-------------------------------------------------------------------
  //  DUT interface signals (bus-based)
  //-------------------------------------------------------------------
  reg         in_valid = 1'b0;
  reg [31:0]  in_a     = 32'd0;       // {lane3, lane2, lane1, lane0}
  reg [31:0]  in_b     = 32'd0;
  wire        out_valid;
  wire [63:0] product;                // {p3, p2, p1, p0}

  //-------------------------------------------------------------------
  //  Instantiate Device Under Test
  //-------------------------------------------------------------------
  mul4x8x8_wallace dut (
    .clk      (clk),
    .rst_n    (rst_n),
    .in_valid (in_valid),
    .in_a     (in_a),
    .in_b     (in_b),
    .out_valid(out_valid),
    .product  (product)
  );

  //-------------------------------------------------------------------
  //  Random stimulus (uses plain scalars for full Verilog-2001 support)
  //-------------------------------------------------------------------
  integer i;
  reg [7:0] a0, a1, a2, a3;
  reg [7:0] b0, b1, b2, b3;
  reg [15:0] ref0, ref1, ref2, ref3;

  localparam integer SEED = 32'h5A5AA5A5;

  initial begin
    // Reset pulse
    #25 rst_n = 1'b1;

    // Iterate 1000 random transactions
    for (i = 0; i < 1000; i = i + 1) begin
      @(negedge clk);
      // Generate random operands and references
      a0 = $urandom(SEED ^ (i*4 + 0));
      a1 = $urandom(SEED ^ (i*4 + 1));
      a2 = $urandom(SEED ^ (i*4 + 2));
      a3 = $urandom(SEED ^ (i*4 + 3));
      b0 = $urandom(SEED ^ (i*4 + 4));
      b1 = $urandom(SEED ^ (i*4 + 5));
      b2 = $urandom(SEED ^ (i*4 + 6));
      b3 = $urandom(SEED ^ (i*4 + 7));

      ref0 = a0 * b0;
      ref1 = a1 * b1;
      ref2 = a2 * b2;
      ref3 = a3 * b3;

      // Pack into 32-bit buses (lane3..lane0)
      in_a   = {a3, a2, a1, a0};
      in_b   = {b3, b2, b1, b0};
      in_valid = 1'b1;

      @(negedge clk);
      in_valid = 1'b0;                // single-cycle pulse

      // Wait exactly 1 cycle for output and compare
      @(posedge clk);
      if (!out_valid) $fatal("out_valid should be high after 1 cycle");

      if (product !== {ref3, ref2, ref1, ref0}) begin
        $display("\nMismatch @iter %0d", i);
        $display(" a=%h b=%h -> dut=%h | exp=%h%h%h%h", in_a, in_b,
                 product, ref3, ref2, ref1, ref0);
        $fatal;
      end
    end

    $display("\n*** TB finished without mismatches. ***\n");
    $finish;
  end
endmodule