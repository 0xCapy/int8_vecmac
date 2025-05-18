`timescale 1ns/1ps
// =============================================================================
//  Automatic multi-configuration testbench for adder_tree_var  (REV-B)
//  ? Instantiates 5 sub-TBs to cover LANES = 1,2,4,8,16 in one run.
//  ? Each sub-TB now uses an EXPECTED FIFO instead of shift-register so the
//    in_valid / out_valid cadence is always aligned - fixes false mismatches.
//  ? Boundary-value vectors followed by random vectors.
//  ? Prints "TB PASSED for LANES = N" per config; top prints "ALL CONFIGS PASSED"
//    only if *no* errors occurred in *any* sub-TB.
//  ? Pure Verilog-2001 (Vivado 2021.1).
// =============================================================================

// -----------------------------------------------------------------------------
// 1)  Parameterised sub-testbench (tb_lane)
// -----------------------------------------------------------------------------
module tb_lane #(parameter integer LANES = 4);
    // ----- Derived widths -----
    localparam integer INW    = 16;
    localparam integer STAGES = (LANES < 4) ? 2 : $clog2(LANES);  // DUT latency
    localparam integer OUTW   = INW + STAGES + 1;

    // ----- Clock / reset -----
    reg clk = 0; always #5 clk = ~clk;   // 100 MHz
    reg rst_n = 0;
    initial begin repeat (4) @(posedge clk); rst_n = 1; end

    // ----- DUT signals -----
    reg                   in_valid;
    reg  [LANES*INW-1:0]  prod_flat;
    wire                  out_valid;
    wire [OUTW-1:0]       sum;

    adder_tree_var #(
        .LANES (LANES),
        .INW   (INW)
    ) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (in_valid),
        .prod_flat (prod_flat),
        .out_valid (out_valid),
        .sum       (sum)
    );

    // ------------------------------------------------------------------
    // EXPECTED FIFO  --  aligns calc_sum with out_valid exactly
    // ------------------------------------------------------------------
    reg [OUTW-1:0] exp_fifo [0:1023];
    integer        wptr = 0, rptr = 0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin wptr <= 0; rptr <= 0; end
        else begin
            // push when in_valid
            if (in_valid) begin
                exp_fifo[wptr] <= calc_sum(prod_flat);
                wptr <= wptr + 1;
            end
            // pop/compare when out_valid
            if (out_valid) begin
                if (sum !== exp_fifo[rptr]) begin
                    $display("ERROR [LANES=%0d] @%0t : got %h exp %h", LANES, $time, sum, exp_fifo[rptr]);
                    err_cnt = err_cnt + 1;
                end
                rptr <= rptr + 1;
            end
        end
    end

    // ----- Sum helper -----
    function [OUTW-1:0] calc_sum;
        input [LANES*INW-1:0] vec;
        integer j; reg [OUTW-1:0] acc; begin
            acc = {OUTW{1'b0}};
            for (j = 0; j < LANES; j = j + 1)
                acc = acc + {{(OUTW-INW){1'b0}}, vec[INW*j +: INW]};
            calc_sum = acc;
        end
    endfunction

    // ----- Vector helpers -----
    function [LANES*INW-1:0] make_vec_all;
        input [INW-1:0] val; integer k; reg [LANES*INW-1:0] tmp; begin
            for (k = 0; k < LANES; k = k + 1) tmp[INW*k +: INW] = val;
            make_vec_all = tmp;
        end
    endfunction

    function [LANES*INW-1:0] make_vec_alt;
        input [INW-1:0] v0, v1; integer k; reg [LANES*INW-1:0] tmp; begin
            for (k = 0; k < LANES; k = k + 1) tmp[INW*k +: INW] = (k & 1) ? v1 : v0;
            make_vec_alt = tmp;
        end
    endfunction

    // ----- Stimulus driver -----
    task automatic send_vec;
        input [LANES*INW-1:0] vec; begin
            @(posedge clk); in_valid <= 1; prod_flat <= vec;
            @(posedge clk); in_valid <= 0;
        end
    endtask

    // ----- Main stimulus -----
    integer k, err_cnt = 0;
    localparam integer N_RAND = 100;

    initial begin
        in_valid  = 0; prod_flat = 0;
        @(posedge rst_n);
        // boundary patterns
        send_vec( make_vec_all({INW{1'b0}})          );
        send_vec( make_vec_all({INW{1'b1}})          );
        send_vec( make_vec_all(16'h8000)             );
        send_vec( make_vec_all(16'h0001)             );
        send_vec( make_vec_alt(16'h0000,16'hFFFF)    );
        send_vec( make_vec_alt(16'h7FFF,16'h8001)    );
        send_vec( make_vec_alt(16'hAAAA,16'h5555)    );
        send_vec( make_vec_alt(16'h0001,16'h0002)    );
        // random patterns
        for (k = 0; k < N_RAND; k = k + 1)
            send_vec( $urandom & {LANES*INW{1'b1}} );
        // wait for pipeline to flush
        repeat (STAGES+6) @(posedge clk);
        if (err_cnt == 0) $display("TB PASSED for LANES=%0d", LANES);
        pass_flag = (err_cnt == 0);
    end

    // expose status to top
    reg pass_flag = 0;
endmodule

// -----------------------------------------------------------------------------
// 2)  Top-level wrapper : aggregates all configurations
// -----------------------------------------------------------------------------
module tb_adder_tree_var;
    // instantiate sub-TBs
    tb_lane #(.LANES(1 )) tb1();
    tb_lane #(.LANES(2 )) tb2();
    tb_lane #(.LANES(4 )) tb4();
    tb_lane #(.LANES(8 )) tb8();
    tb_lane #(.LANES(16)) tb16();

    // monitor completion: wait until all pass_flags are asserted
    initial begin
        // wait reset done (largest latency path)
        wait(tb16.rst_n === 1);
        // wait until every sub-tb sets its pass flag
        wait(tb1.pass_flag & tb2.pass_flag & tb4.pass_flag & tb8.pass_flag & tb16.pass_flag);
        $display("ALL CONFIGS PASSED");
        $finish;
    end
endmodule
