`timescale 1ns/1ps
module tb_mul4x8x8_wallace;

    // ==== DUT ports ====
    reg         clk = 0;
    reg         rst_n = 0;
    reg         in_valid = 0;
    reg  [31:0] in_a = 0, in_b = 0;
    wire        out_valid;
    wire [17:0] out_sum;      // ★ 18-bit result

    mul4x8x8_wallace dut (
        .clk(clk), .rst_n(rst_n),
        .in_valid(in_valid), .in_a(in_a), .in_b(in_b),
        .out_valid(out_valid), .out_sum(out_sum)
    );

    // 100 MHz
    always #5 clk = ~clk;

    // ==== test vectors ====
    reg [31:0] vec_a[0:9], vec_b[0:9];

    // --- 8×8→16，再 4 个相加 → 18-bit ---
    function automatic [17:0] gold_sum (
        input [31:0] A, input [31:0] B
    );
        integer k;
        reg [17:0] acc;       // 宽 18
        reg [15:0] p;
        begin
            acc = 18'd0;
            for (k = 0; k < 4; k = k + 1) begin
                p = A[8*k +: 8] * B[8*k +: 8];
                acc = acc + p;          // 自然扩位
            end
            gold_sum = acc;
        end
    endfunction

    integer i;
    reg [17:0] gold;

    initial begin
        // 向量 (与之前相同)
        vec_a[0]=32'h00000000; vec_b[0]=32'h00000000;
        vec_a[1]=32'hFFFFFFFF; vec_b[1]=32'hFFFFFFFF;
        vec_a[2]=32'h000000FF; vec_b[2]=32'h000000FF;
        vec_a[3]=32'hFF000000; vec_b[3]=32'h00FFFFFF;
        vec_a[4]=32'h12345678; vec_b[4]=32'h87654321;
        vec_a[5]=32'hD04C5281; vec_b[5]=32'h0F299FFB;
        vec_a[6]=32'h1CC5BADC; vec_b[6]=32'h8997A3A3;
        vec_a[7]=32'h8A0F2715; vec_b[7]=32'h3217491B;
        vec_a[8]=32'hB1AB2EED; vec_b[8]=32'hF70AEFBB;
        vec_a[9]=32'hB711705A; vec_b[9]=32'hC2B09C09;

        $display("\n=== 4×8×8 Wallace + Adder-Tree TB ===");
        rst_n = 0; repeat(3) @(posedge clk); rst_n = 1;

        for (i = 0; i < 10; i = i + 1) begin
            @(negedge clk);
            in_a = vec_a[i];  in_b = vec_b[i];
            in_valid = 1;
            gold = gold_sum(vec_a[i], vec_b[i]);
            @(negedge clk) in_valid = 0;

            wait (out_valid); @(posedge clk);

            if (out_sum !== gold) begin
                $display("FAIL  idx=%0d A=%h B=%h  DUT=%h  GOLD=%h",
                         i, vec_a[i], vec_b[i], out_sum, gold);
            end else begin
                $display(" PASS idx=%0d -- 0x%05h", i, out_sum);
            end
            repeat(2) @(posedge clk);
        end
        $display("=== All done ===");
        $finish;
    end
endmodule
