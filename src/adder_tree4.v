// adder_tree4_piped.v £¨¸Ä³ÉÁ½ÅÄ£©
module adder_tree4 (
    input  wire        clk, rst_n,
    input  wire        in_valid,
    input  wire [15:0] p0, p1, p2, p3,
    output wire        out_valid,
    output wire [17:0] sum
);
    // stage-1
    (* keep = "true" *)reg [16:0] s0, s1;        // 17-bit
    (* keep = "true" *)reg        v1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s0 <= 0; s1 <= 0; v1 <= 0;
        end else begin
            s0 <= p0 + p1;
            s1 <= p2 + p3;
            v1 <= in_valid;
        end
    end

    // stage-2
    reg [17:0] sum_r;
    reg        v2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum_r <= 0; v2 <= 0;
        end else begin
            sum_r <= s0 + s1;
            v2    <= v1;
        end
    end

    assign sum       = sum_r;
    assign out_valid = v2;
endmodule
