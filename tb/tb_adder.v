// ============================================================
// adder_tb.v
// Testbench for full_adder_Behavioral (1-bit) and fulladd4 (4-bit)
// ============================================================
`timescale 1ns/1ps

module adder_tb;

  //------------------ 1-bit full adder signals ------------------
  reg  X1, X2, Cin1;
  wire S, Cout1;

  //------------------ 4-bit ripple-carry adder signals ----------
  reg  [3:0] A, B;
  reg        Cin4;
  wire [3:0] SUM;
  wire       Cout4;

  //------------------ Device Under Test (DUT) -------------------
  full_adder_Behavioral dut1 (
      .X1   (X1),
      .X2   (X2),
      .Cin  (Cin1),
      .S    (S),
      .Cout (Cout1)
  );

  fulladd4 dut4 (
      .A    (A),
      .B    (B),
      .Cin  (Cin4),
      .SUM  (SUM),
      .Cout (Cout4)
  );

  wire exp_S1    = X1 ^ X2 ^ Cin1;
  wire exp_Cout1 = (X1 & X2) | (X1 & Cin1) | (X2 & Cin1);

  wire [4:0] exp4 = A + B + Cin4;   // {Cout, SUM}

  integer errors;
  initial begin
    errors = 0;

    // Exhaustive test for 1-bit adder (8 vectors)
    for (integer i = 0; i < 8; i = i + 1) begin
      {X1, X2, Cin1} = i[2:0];
      #1;
      if (S !== exp_S1 || Cout1 !== exp_Cout1) begin
        $display("1-bit mismatch: X1=%b X2=%b Cin=%b -> S=%b (exp %b) Cout=%b (exp %b)",
                 X1, X2, Cin1, S, exp_S1, Cout1, exp_Cout1);
        errors = errors + 1;
      end
    end

    // Random test for 4-bit adder (100 vectors)
    for (integer j = 0; j < 100; j = j + 1) begin
      A    = $urandom;
      B    = $urandom;
      Cin4 = $urandom;
      #1;
      if ({Cout4, SUM} !== exp4) begin
        $display("4-bit mismatch: A=%h B=%h Cin=%b -> SUM=%h (exp %h) Cout=%b (exp %b)",
                 A, B, Cin4, SUM, exp4[3:0], Cout4, exp4[4]);
        errors = errors + 1;
      end
    end

    if (errors == 0)
      $display("All tests passed.");
    else
      $display("%0d error(s) found.", errors);

    $finish;
  end

  initial begin
    $dumpfile("adder_tb.vcd");
    $dumpvars(0, adder_tb);
  end

endmodule
