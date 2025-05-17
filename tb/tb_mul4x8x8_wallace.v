`timescale 1ns/1ps
// -------------------------------------------------------------
//  Testbench : tb_mul4x8x8_wallace 
// -------------------------------------------------------------
module tb_mul4x8x8_wallace;

    // ===== DUT ports =====
    reg         clk = 0;
    reg         rst_n = 0;
    reg         in_valid = 0;
    reg  [31:0] in_a  = 32'd0;
    reg  [31:0] in_b  = 32'd0;
    wire        out_valid;
    wire [63:0] product;

    mul4x8x8_wallace dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .in_valid (in_valid),
        .in_a     (in_a),
        .in_b     (in_b),
        .out_valid(out_valid),
        .product  (product)
    );

    // 100 MHz clock
    always #5 clk = ~clk;

    // ===== Test vectors =====
    reg [31:0] vec_a [0:9];
    reg [31:0] vec_b [0:9];
    reg [63:0] gold  [0:9];

    integer i;

    initial begin
        vec_a[0] = 32'h00000000; vec_b[0] = 32'h00000000; gold[0] = 64'h0000000000000000;
        vec_a[1] = 32'hFFFFFFFF; vec_b[1] = 32'hFFFFFFFF; gold[1] = 64'hFE01FE01FE01FE01;
        vec_a[2] = 32'h000000FF; vec_b[2] = 32'h000000FF; gold[2] = 64'h000000000000FE01;
        vec_a[3] = 32'hFF000000; vec_b[3] = 32'h00FFFFFF; gold[3] = 64'h0000000000000000;
        vec_a[4] = 32'h12345678; vec_b[4] = 32'h87654321; gold[4] = 64'h097E148416820F78;
        vec_a[5] = 32'hD04C5281; vec_b[5] = 32'h0F299FFB; gold[5] = 64'h0C300C2C32EE7E7B;
        vec_a[6] = 32'h1CC5BADC; vec_b[6] = 32'h8997A3A3; gold[6] = 64'h0EFC7433766E8C14;
        vec_a[7] = 32'h8A0F2715; vec_b[7] = 32'h3217491B; gold[7] = 64'h1AF401590B1F0237;
        vec_a[8] = 32'hB1AB2EED; vec_b[8] = 32'hF70AEFBB; gold[8] = 64'hAAC706AE2AF2AD1F;
        vec_a[9] = 32'hB711705A; vec_b[9] = 32'hC2B09C09; gold[9] = 64'h8AAE0BB04440032A;

        // ------------ Reset sequence -------------
        $display("\n=== Wallace 4¡Á8¡Á8 Multiplier TB ===");
        rst_n = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;

        // ------------ Apply vectors --------------
        for (i = 0; i < 10; i = i + 1) begin
            @(negedge clk);
            in_a     = vec_a[i];
            in_b     = vec_b[i];
            in_valid = 1;
            @(negedge clk);
            in_valid = 0;

            //wait pipline
            wait (out_valid);
            @(posedge clk);

            if (product !== gold[i]) begin
                $display("FAIL idx=%0d  in_a=0x%08h in_b=0x%08h", i, vec_a[i], vec_b[i]);
                $display("   DUT =0x%016h  GOLD=0x%016h", product, gold[i]);
            end
            else begin
                $display(" PASS idx=%0d ======= 0x%016h", i, product);
            end

            repeat (2) @(posedge clk); 
        end

        $display("=== All tests completed ===");
        $finish;
    end
endmodule
