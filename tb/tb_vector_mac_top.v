`timescale 1ns/1ps
// ============================================================================
//  tb_vector_mac_param_full - pure Verilog-2001 thorough testbench
//  ? CLK : 200 MHz  (#2.5 ns half-period)
//  ? ELEMS constant  = 1000
//  ? ACTIVE_LANES param selects 1-MAC or 4-MAC implementation
// ======================================================================

module tb_vector_mac_param_full;

    // -----------------------------------------------------------------
    // *** choose implementation under test ***
    // -------------------------------------------------------------------------
    parameter integer ACTIVE_LANES = 4;    // Choose your macs

    // ----------------------------------------------------------------
    // constants
    // ----------------------------------------------------------------------
    parameter integer ELEMS = 1000;

    // ------------------------------------------------------------------------
    // 200 MHz clock & async reset
    reg clk = 1'b0;
    always #2.5 clk = ~clk;                // 200 MHz

    reg rst_n;

    // -------------------------------------------------------------------------
    // DUT signals
    // ------------------------------------------------------------------
    reg           vec_valid;
    reg  [31:0]   vec_a;
    reg  [31:0]   vec_b;
    wire          result_valid;
    wire [31:0]   result_sum;

    vector_mac_top_param #(
        .ELEMS        (ELEMS),
        .ACTIVE_LANES (ACTIVE_LANES)
    ) dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .vec_valid    (vec_valid),
        .vec_a        (vec_a),
        .vec_b        (vec_b),
        .result_valid (result_valid),
        .result_sum   (result_sum)
    );

    // ------------------------------------------------------------------
    // monitor - catch single-cycle result_valid
    // -------------------------------------------------------------------------
    reg        done_flag;
    reg [31:0] golden_sum;

    always @(posedge clk) begin
        if (result_valid) begin
            if (result_sum !== golden_sum) begin
                $display("### FAIL  lanes=%0d  dut=%h  gold=%h",
                         ACTIVE_LANES, result_sum, golden_sum);
                $stop;
            end
            else
                $display("### PASS  lanes=%0d  sum=%h",
                         ACTIVE_LANES, result_sum);
            done_flag <= 1'b1;
        end
        else
            done_flag <= 1'b0;
    end

    // --------------------------------------------------------------------
    // task : drive one vector (idle_cycles = 0 / 1)
    // randomize = 1  ¡ú random data
    // randomize = 0  ¡ú use pattern_a / pattern_b
    // -------------------------------------------------------------------
    integer beats, idx, i;
    reg [17:0] prod;
    task drive_vector;
        input [31:0] pattern_a;
        input [31:0] pattern_b;
        input integer randomize;
        input integer idle_cycles;
        reg [31:0] va_tmp, vb_tmp;
    begin
        beats = (ELEMS + ACTIVE_LANES - 1) / ACTIVE_LANES;
        golden_sum = 0;

        for (idx = 0; idx < beats; idx = idx + 1) begin
            // choose data
            if (randomize)
                begin va_tmp = $random; vb_tmp = $random; end
            else
                begin va_tmp = pattern_a; vb_tmp = pattern_b; end

            // golden model
            if (ACTIVE_LANES == 1) begin
                prod        = va_tmp[7:0] * vb_tmp[7:0];
                golden_sum  = golden_sum + prod;
            end
            else begin                               // 4-lanes
                prod = 0;
                for (i = 0; i < 4; i = i + 1)
                    prod = prod + va_tmp[i*8 +: 8] * vb_tmp[i*8 +: 8];
                golden_sum = golden_sum + prod;
            end

            // drive beat
            @(posedge clk);
            vec_valid <= 1'b1;
            vec_a     <= va_tmp;
            vec_b     <= vb_tmp;

            @(posedge clk);
            if (idle_cycles) vec_valid <= 1'b0;      // insert gap
        end

        @(posedge clk) vec_valid <= 1'b0;

        // wait monitor
        wait (done_flag);
        @(posedge clk);
    end
    endtask

    // -------------------------------------------------------------------------
    // test sequence
    // ---------------------------------------------------------------
    integer s;
    initial begin
        // async reset glitch
        rst_n = 1'b1;
        #1 rst_n = 1'b0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        // directed boundary tests
        drive_vector(32'h00000000, 32'h00000000, 0, 1); // all-zero
        drive_vector(32'hFFFFFFFF, 32'hFFFFFFFF, 0, 1); // all-255
        drive_vector(32'hFF00FF00, 32'h00FF00FF, 0, 1); // alt pattern

        // back-to-back (0 idle)
        drive_vector(32'h00000000, 32'h00000000, 0, 0);

        // random stress (20 vectors)
        for (s = 0; s < 20; s = s + 1)
            drive_vector(32'h0, 32'h0, 1, 1);

        $display("\n=== ALL TESTS PASSED ===");
        $finish;
    end

endmodule
