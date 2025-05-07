 /* ---------------------------------------------------------
 File        : multipilier.v
 Function    : 4x4 unsigned shift-and-add multiplier
 Latency     : 5 clock cycles (start to finish)
 Throughput  : 1 result every 5 cycles
---------------------------------------------------------
Improvement:
 Unified synchronous logic in one always block
Added BUSY state to latch the start pulse
Corrected datapath widths (out[7:0], a_in_reg[8:0])
Replaced blocking (=) with non-blocking (<=) assignments
Finish flag now asserted for exactly one clock
 ---------------------------------------------------------
Verification:
Self-checking testbench: tb_mult.sv
30 random operand pairs (0-15) + boundary 15x15
wait(finish) then assert out == a*b
Prints All random + boundary cases passed on success
--------------------------------------------------------- */

module multipilier (
    input  wire        clk,
    input  wire        rst, 
    input  wire        start,
    input  wire [3:0]  a_in,
    input  wire [3:0]  b_in,
    output wire [7:0]  out,
    output wire        finish
);
    reg  [7:0] out_reg;
    reg        finish_reg;
    reg  [8:0] a_in_reg; 
    reg  [3:0] b_in_reg;
    reg  [2:0] bits; 
    reg        busy;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            out_reg    <= 0;
            a_in_reg   <= 0;
            b_in_reg   <= 0;
            bits       <= 3'd0;
            busy       <= 1'b0;
            finish_reg <= 1'b0;
        end else begin
            if (!busy) begin
                finish_reg <= 1'b0;  
                if (start) begin 
                    busy     <= 1'b1;
                    bits     <= 3'd4;
                    out_reg  <= 0;
                    a_in_reg <= {5'd0, a_in};
                    b_in_reg <= b_in;
                end
            end
            else begin
                if (b_in_reg[0])
                    out_reg <= out_reg + a_in_reg;

                a_in_reg <= a_in_reg << 1;
                b_in_reg <= b_in_reg >> 1;
                bits     <= bits - 1;

                if (bits == 3'd1) begin
                    busy       <= 1'b0;  
                    finish_reg <= 1'b1; 
                end
            end
        end
    end

    assign out    = out_reg;
    assign finish = finish_reg;

endmodule
