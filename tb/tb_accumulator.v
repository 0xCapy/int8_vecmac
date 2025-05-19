`timescale 1ns/1ps
// =============================================================================
//  tb_accumulator_var 
//  ycles lanes_i through 1 / 2 / 4 / 8 / 16
// =============================================================================
module tb_accumulator_var;
    //--------------------------------------------------------------------
    // DUT
    //--------------------------------------------------------------------
    localparam integer ELEMS  = 1000;   // elements per vector
    localparam integer W_IN   = 20;     // partial_sum width
    localparam integer W_ACC  = 32;     // accumulator width

    //--------------------------------------------------------------------
    // Clock & reset
    //--------------------------------------------------------------------
    reg clk = 0;
    always #5 clk = ~clk;

    reg rst_n = 0;

    //--------------------------------------------------------------------
    // DUT I/O
    //--------------------------------------------------------------------
    reg               in_valid     = 0;
    reg  [W_IN-1:0]   partial_sum  = 0;
    reg  [4:0]        lanes_i      = 5'd1;     // 1 /2 /4 /8 /16
    wire              result_valid;
    wire [W_ACC-1:0]  final_sum;

    accumulator_var #(
        .ELEMS (ELEMS),
        .W_IN  (W_IN),
        .W_ACC (W_ACC)
    ) dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .in_valid     (in_valid),
        .partial_sum  (partial_sum),
        .lanes_i      (lanes_i),
        .final_sum    (final_sum),
        .result_valid (result_valid)
    );

    //--------------------------------------------------------------------
    // Stimulus helpers
    //--------------------------------------------------------------------
    integer beats, beat;
    reg [W_ACC-1:0] golden;
    integer pass = 0, fail = 0;

    // --- task: send one full vector ----------------------------------
    task automatic send_vector;
        input [4:0] lane_cnt;   // 1,2,4,8,16
        input integer cid;      // case id: 0?3 boundary, >=4 random
        integer stride;
        reg [W_IN-1:0] ps;      // partial_sum of current beat
    begin
        //---------------- reset ----------------
        rst_n    <= 0; in_valid <= 0; partial_sum <= 0;
        repeat (5) @(posedge clk);
        rst_n    <= 1;
        //----------------------------------------------------------------
        lanes_i  <= lane_cnt;
        stride   = lane_cnt;                       // stride = lanes
        beats    = (ELEMS + stride - 1) / stride;  // ceil(ELEMS/stride)

        golden   = 0;
        //----------------------------------------------------------------
        // drive beats
        //----------------------------------------------------------------
        for (beat = 0; beat < beats; beat = beat + 1) begin
            @(posedge clk);
            // generate one unsigned partial_sum (max 20?bit)
            case (cid)
                0 : ps = 0;
                1 : ps = 1;
                2 : ps = 20'hFFFFF;
                3 : ps = 20'h80000;
                default: ps = $urandom_range(0, 20'hFFFFF);
            endcase
            // accumulate software golden first 
            golden      = golden + ps;
            in_valid    <= 1'b1;
            partial_sum <= ps;
        end

        // send idle cycle
        @(posedge clk);
        in_valid    <= 1'b0;
        partial_sum <= 0;

        // wait for DUT result
        wait (result_valid);
        @(posedge clk);
        if (final_sum === golden) begin
            $display("PASS  | lanes=%0d case=%0d result=%0d", lane_cnt, cid, final_sum);
            pass = pass + 1;
        end else begin
            $display("FAIL! | lanes=%0d case=%0d exp=%0d got=%0d", lane_cnt, cid, golden, final_sum);
            fail = fail + 1;
        end
    end
    endtask

    //--------------------------------------------------------------------
    // Main test sequence
    //--------------------------------------------------------------------
    integer lc, cid;
    initial begin
        for (lc = 0; lc < 5; lc = lc + 1) begin
            for (cid = 0; cid < 14; cid = cid + 1)  // 4 boundary and 10 random
                send_vector(5'd1 << lc, cid);
        end

        $display("-----------------------------------------------");
        $display("TOTAL PASS = %0d  FAIL = %0d", pass, fail);
        $display("-----------------------------------------------");
        $finish;
    end
endmodule
