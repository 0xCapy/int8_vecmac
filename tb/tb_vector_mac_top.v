`timescale 1ns/1ps
// ============================================================================
//  tb_vector_mac_param  -  vector-level checker for vector_mac_top_param
//  Discription : This file test top design with full senerio-based situarion which is required in handout.
//  ********How to use? -- By switiching "LANE_P" from 1/4/8/16, it will automatically test corespond design.
//  Author: Hubo 17/05/2025
// ============================================================================
module tb_vector_mac_top_para;

    // ---------- choose MAC version ----------
    parameter integer LANE_P = 4;          // 1 or 4 or 8 or 16 for diff macs

    // ---------- constants ----------
    parameter integer ELEMS  = 1000;
    parameter integer BUSW   = 128;
    parameter integer DEPTH  = 4096;       // FIFO depth
    parameter integer RAND_VEC = 100;   

    // ---------- clock & reset ----------
    reg clk = 0;            always #2.5 clk = ~clk;   // 200 MHz
    reg rst_n = 0;

    // ---------- DUT ----------
    reg              vec_valid = 0;
    reg  [BUSW-1:0]  vec_a     = 0;
    reg  [BUSW-1:0]  vec_b     = 0;
    wire             result_valid;
    wire [31:0]      result_sum;

    vector_mac_top_param #(
        .ELEMS        (ELEMS),
        .ACTIVE_LANES (LANE_P)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .vec_valid(vec_valid),
        .vec_a(vec_a), .vec_b(vec_b),
        .result_valid(result_valid),
        .result_sum(result_sum)
    );

    // ---------- lane mask (active bytes = 1) ----------
    reg [BUSW-1:0] lane_mask;
    integer mi;
    initial begin
        lane_mask = {BUSW{1'b0}};
        for (mi = 0; mi < LANE_P; mi = mi + 1)
            lane_mask[mi*8 +: 8] = 8'hFF;
    end

    // ---------- ring-buffer FIFO ----------
    reg [31:0] fifo_data [0:DEPTH-1];
    reg [11:0] wr_ptr = 0, rd_ptr = 0;
    integer in_vec_cnt = 0, out_vec_cnt = 0, pass = 0, fail = 0;

    // ---------- reset release ----------
    initial begin
        repeat (5) @(posedge clk);
        rst_n = 1;
    end

    // ---------- drive one vector ----------
    task drive_vector;
        input integer pattern_sel;
        integer beats, bt, ln;
        reg [BUSW-1:0] a_beat, b_beat;
        reg [31:0]     vec_sum;
    begin
        beats   = (ELEMS + LANE_P - 1) / LANE_P;
        vec_sum = 0;

        for (bt = 0; bt < beats; bt = bt + 1) begin
            case (pattern_sel)
                0: begin a_beat = 0;              b_beat = 0;              end
                1: begin a_beat = lane_mask;      b_beat = lane_mask;      end
                2: begin a_beat = lane_mask & {BUSW{1'b1}};   // all FF in active bytes
                   b_beat = a_beat; end
                3: begin a_beat = lane_mask & (bt & 1 ? 128'h00 : 128'hFF); // Chansfer
                   b_beat = ~a_beat & lane_mask; end
                4: begin a_beat = lane_mask & 128'h0123_4567_89AB_CDEF_FEDC_BA98_7654_3210;
                   b_beat = lane_mask & 128'h89AB_CDEF_0123_4567_7654_3210_FEDC_BA98; end
                default: begin                  // random
                   a_beat = {4{$random}} & lane_mask;
                   b_beat = {4{$random}} & lane_mask;
                end
            endcase

            // ---- accumulate vector golden ----
            for (ln = 0; ln < LANE_P; ln = ln + 1)
                vec_sum = vec_sum +
                          a_beat[ln*8 +: 8] * b_beat[ln*8 +: 8];

            // ---- drive beat ----
            @(posedge clk);
            vec_valid <= 1'b1;  vec_a <= a_beat;  vec_b <= b_beat;
        end

        // pull valid low & idle one cycle
        @(posedge clk);
        vec_valid <= 1'b0;

        // ---- push expected to FIFO ----
        fifo_data[wr_ptr] = vec_sum;
        wr_ptr = wr_ptr + 1;
        in_vec_cnt = in_vec_cnt + 1;
    end
    endtask

    // ---------- stimulus ----------
    integer rv;
    initial begin : STIM
        wait (rst_n);

        // 5 directed vectors
        drive_vector(0);
        drive_vector(1);
        drive_vector(2);
        drive_vector(3);
        drive_vector(4);

        // random vectors
        for (rv = 0; rv < RAND_VEC; rv = rv + 1)
            drive_vector(-1);

        // wait until all results checked
        wait (out_vec_cnt == in_vec_cnt);
        #50;
        $display("PASS=%0d  FAIL=%0d", pass, fail);
        if (fail == 0) begin
            $display("*****All tests passed for %0dx8x8 design***", LANE_P );
        end
        $finish;
    end

    // ---------- checker ----------
    always @(posedge clk) begin
        if (result_valid) begin
            if (result_sum === fifo_data[rd_ptr])
                pass = pass + 1;
            else begin
                $display("Mismatch @%0t  exp=%0d  got=%0d",
                         $time, fifo_data[rd_ptr], result_sum);
                fail = fail + 1;
            end
            rd_ptr = rd_ptr + 1;
            out_vec_cnt = out_vec_cnt + 1;
        end
    end
endmodule
