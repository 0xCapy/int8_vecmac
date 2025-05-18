`timescale 1ns/1ps
module tb_mul4x8x8_wallace;

   // ---- DUT ----
   reg         clk = 0, rst_n = 0, in_valid = 0;
   reg  [31:0] in_a  = 0, in_b = 0;
   wire        out_valid;
   wire [17:0] out_sum;

   mul4x8x8_wallace dut(
      .clk(clk), .rst_n(rst_n), .in_valid(in_valid),
      .in_a(in_a), .in_b(in_b), .out_valid(out_valid), .out_sum(out_sum)
   );

   // 100 MHz clk
   always #5 clk = ~clk;

   // ---------- golden FIFO (ring buffer) ----------
   localparam DEPTH = 16384;       // 深度足够覆盖所有随机向量
   reg [17:0] fifo_data [0:DEPTH-1];
   reg [15:0] wr_ptr = 0, rd_ptr = 0;
   integer    in_cnt = 0, out_cnt = 0, pass = 0, fail = 0;

   // ---------- reset ----------
   initial begin
      repeat (5) @(posedge clk);
      rst_n = 1;
   end

   // ---------- stimulus ----------
   task push_exp;
      input [31:0] a, b;
      reg   [7:0] a0,a1,a2,a3,b0,b1,b2,b3;
      reg  [17:0] dot;
   begin
      {a3,a2,a1,a0} = a;
      {b3,b2,b1,b0} = b;
      dot = a0*b0 + a1*b1 + a2*b2 + a3*b3;
      fifo_data[wr_ptr] = dot;
      wr_ptr = wr_ptr + 1;
   end
   endtask

   task apply_vec;
      input [31:0] a,b;
   begin
      @(posedge clk);
      in_valid <= 1; in_a <= a; in_b <= b;
      push_exp(a,b); in_cnt = in_cnt + 1;
      @(posedge clk);
      in_valid <= 0;
   end
   endtask

   initial begin : STIM
      wait (rst_n);

      // 5 boundary
      apply_vec(32'h0000_0000, 32'h0000_0000);
      apply_vec(32'hFFFF_FFFF, 32'hFFFF_FFFF);
      apply_vec(32'h0000_00FF, 32'h0000_00FF);
      apply_vec(32'hFF00_0000, 32'h00FF_FFFF);
      apply_vec(32'h1234_5678, 32'h8765_4321);

      // 10 000 random
      repeat (10000) begin
         @(posedge clk);
         if ($random % 2) begin
            apply_vec($random, $random);
         end
      end

      // drain
      wait (out_cnt == in_cnt);
      #20;
      $display("PASS=%0d  FAIL=%0d", pass, fail);
      $finish;
   end

   // ---------- checker ----------
   always @(posedge clk) begin
      if (out_valid) begin
         if (out_sum === fifo_data[rd_ptr]) begin
            pass = pass + 1;
         end else begin
            $display("Mismatch @%0t  exp=%0d got=%0d",
                     $time, fifo_data[rd_ptr], out_sum);
            fail = fail + 1;
         end
         rd_ptr = rd_ptr + 1;
         out_cnt = out_cnt + 1;
      end
   end
endmodule
