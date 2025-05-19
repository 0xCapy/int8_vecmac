`timescale 1ns/1ps
// =============================================================================
//  tb_vector_mac_param - pure Verilog-2001 testbench
//  ? set LANE_P to 1 or 4 -> TB & DUT will match automatically
//  ? works with vector_mac_top_param.v (parameterised top)
// =============================================================================
module tb_vector_mac_param;

    // -------------------------------------------------------------------------
    // *** choose which version to test ***
    // -------------------------------------------------------------------------
    parameter integer LANE_P = 1;    //******Change this when you wanna test other MACs combo 1for 1Mac 4 for 4 Macs

    // -------------------------------------------------------------------------
    // constants
    // -------------------------------------------------------------------------
    parameter ELEMS = 1000;           // keep the same as DUT

    // -------------------------------------------------------------------------
    // clock & reset
    // -------------------------------------------------------------------------
    reg clk = 1'b0;
    always #5 clk = ~clk;             // 100 MHz

    reg rst_n;

    // -------------------------------------------------------------------------
    // DUT ports
    // -------------------------------------------------------------------------
    reg           vec_valid;
    reg  [31:0]   vec_a;
    reg  [31:0]   vec_b;
    wire          result_valid;
    wire [31:0]   result_sum;

    // -------------------------------------------------------------------------
    // DUT instance - only 1 line differs from old TB
    // -------------------------------------------------------------------------
    vector_mac_top_param #(
        .ELEMS(ELEMS),
        .ACTIVE_LANES(LANE_P)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .vec_valid(vec_valid),
        .vec_a(vec_a),
        .vec_b(vec_b),
        .result_valid(result_valid),
        .result_sum(result_sum)
    );

    // -------------------------------------------------------------------------
    // monitor: catch single-cycle result_valid
    // -------------------------------------------------------------------------
    reg        done_flag;
    reg [31:0] golden_sum;

    always @(posedge clk) begin
        if (result_valid) begin
            if (result_sum !== golden_sum) begin
                $display("### FAIL  lanes=%0d  dut=%h  gold=%h",
                         LANE_P, result_sum, golden_sum);
                $stop;
            end
            else
                $display("### PASS  lanes=%0d  sum=%h", LANE_P, result_sum);
            done_flag <= 1'b1;
        end
        else
            done_flag <= 1'b0;
    end

    // -------------------------------------------------------------------------
    // task: send one vector (length ELEMS) and build golden
    // -------------------------------------------------------------------------
    integer beats, idx, i;
    reg [17:0] prod;
    task run_vector;
        integer lane_cnt;
        reg [31:0] va_tmp, vb_tmp;
    begin
        lane_cnt = LANE_P;                            // =1 or 4
        beats    = (ELEMS + lane_cnt - 1) / lane_cnt;
        golden_sum = 0;

        for (idx = 0; idx < beats; idx = idx + 1) begin
            // random data
            va_tmp = $random;
            vb_tmp = $random;

            // build golden
            if (lane_cnt == 1) begin
                prod       = va_tmp[7:0] * vb_tmp[7:0];
                golden_sum = golden_sum + prod;
            end
            else begin      // lane_cnt == 4
                prod = 0;
                for (i = 0; i < 4; i = i + 1)
                    prod = prod + va_tmp[i*8 +: 8] * vb_tmp[i*8 +: 8];
                golden_sum = golden_sum + prod;
            end

            // drive to DUT
            @(posedge clk);
            vec_valid <= 1'b1;
            vec_a     <= va_tmp;
            vec_b     <= vb_tmp;

            @(posedge clk);
            vec_valid <= 1'b0;        // idle one cycle
        end

        wait (done_flag);
        @(posedge clk);               // let done_flag clear
    end
    endtask

    // -------------------------------------------------------------------------
    // test sequence
    // -------------------------------------------------------------------------
    initial begin
        // init
        rst_n     = 1'b0;
        vec_valid = 1'b0;
        vec_a     = 0;
        vec_b     = 0;
        done_flag = 1'b0;

        // release reset
        repeat (4) @(posedge clk);
        rst_n = 1'b1;

        // run one vector
        run_vector;

        $display("\n=== ALL TESTS PASSED ===");
        $finish;
    end

endmodule
