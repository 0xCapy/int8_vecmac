`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 31.01.2022 16:50:15
// Design Name: 
// Module Name: multipilier
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module multipilier(
    input [3:0] a_in,
    input [3:0] b_in,
    input clk,
    input rst,
    output [7:0] out,
    input start,
    output finish
    );
    //create registers for input and outputs 
    reg [7:0] out_reg;
    reg finish_reg;
    reg [8:0] a_in_reg;
    reg [3:0] b_in_reg;
    reg [8:0] bits;
    //define reset, instead of messing up with the actual input and output value, we play with the registers
    always @ (negedge rst) begin
        out_reg = 0;
        a_in_reg = 0;
        b_in_reg = 0;    
    end
    //load input values
    always @ (posedge clk) begin
        if (!rst) begin
            case (start)
                1'b0: begin
                    a_in_reg[3:0] = a_in;
                    a_in_reg[7:4] = 0;
                    b_in_reg = b_in;
                    finish_reg = 0; //define this signal just in case it turns randomly.
                    out_reg = 0;
                    bits = 4;
                end
                1'b1: begin
                    if (b_in_reg[0]==1) begin
                        out_reg = out_reg + a_in_reg;
                    end
                    bits = bits - 1;
                    a_in_reg = a_in_reg << 1;
                    b_in_reg = b_in_reg >> 1;
                end
            endcase
            if (bits==0) begin
                finish_reg = 1'b1;
            end
        end
    end
    //assign the value in registers into the output ports
    assign out = out_reg;
    assign finish = finish_reg;
endmodule
