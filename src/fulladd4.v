`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01.02.2022 14:18:24
// Design Name: 
// Module Name: fulladd4
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


module fulladd4(
    input [3:0] A,
    input [3:0] B,
    input Cin,
    output [3:0] SUM,
    output Cout
    );
    
    assign {cout, SUM} = A + B + Cin;
    
endmodule
