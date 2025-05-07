/*------------------------------------------------------------
Multipilier2.v  -  4-bit ¡Á 4-bit unsigned multiplier
Shift-add algorithm with internal two-phase clock
start  : hold High during operation, Low = idle
Finish : 1-cycle pulse, auto-cleared when start goes Low
Fixed carry width, non-blocking regs, and Finish clearing
------------------------------------------------------------*/

module Multipilier2 (
    input  wire        reset,   // async, high-active
    input  wire        start,   // keep high during operation
    input  wire [3:0]  A,
    input  wire [3:0]  B,
    output reg  [7:0]  O,
    output wire        Finish
);

    /* ---------------- two-phase clock generator -------------- */
    wire Phi0 , Phi1 ;
    wire m1   , m2 , m3 , m4 ;
    nand      u0 (m1 , start , m2);
    buf  #20  u1 (m2 , m1);
    buf  #10  u2 (Phi0, m1);
    not  #2   u5 (m4 , Phi0);
    assign m3 = ~m1;
    and  #2   u4 (Phi1, m3 , m4);

    /* ---------------- registers ------------------------------ */
    reg  [3:0] State;
    reg  [8:0] ACC;
    reg        Finish_reg;
    assign Finish = Finish_reg;

    /* --------- main FSM runs on internal two-phase clocks ---- */
    always @(posedge Phi0 or posedge Phi1 or posedge reset) begin
        if (reset) begin
            State      <= 4'd0;
            ACC        <= 9'd0;
            O          <= 8'd0;
            Finish_reg <= 1'b0;
        end
        else if (Phi0 || Phi1) begin
            case (State)
              4'd0: begin
                  ACC[8:4]   <= 5'd0;
                  ACC[3:0]   <= A;
                  State      <= 4'd1;
              end
              4'd1,4'd3,4'd5,4'd7: begin
                  if (ACC[0])
                      ACC[8:4] <= ACC[8:4] + B;   // carry-safe add
                  State <= State + 1;
              end
              4'd2,4'd4,4'd6,4'd8: begin
                  ACC   <= {1'b0, ACC[8:1]};      // logical shift-right
                  State <= State + 1;
              end
              4'd9: begin
                  O          <= ACC[7:0];
                  Finish_reg <= 1'b1;             // raise done
                  State      <= 4'd0;             // back to idle
              end
              default: State <= 4'd0;
            endcase
        end
    end

    /* --------- NEW: async clear Finish when start is released */
    always @(negedge start or posedge reset) begin
        if (reset)      Finish_reg <= 1'b0;
        else            Finish_reg <= 1'b0;       // clear on start low
    end

endmodule
