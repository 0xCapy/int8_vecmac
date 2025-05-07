`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01.02.2022 14:34:51
// Design Name: 
// Module Name: full_adder_Behavioral
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


module full_adder_Behavioral(input X1, X2, Cin, output S, Cout);

    reg [1:0] temp;
    always @(*)
    begin
        temp = {1'b0, X1} + {1'b0, X2} + {1'b0, Cin};
    end
    assign S = temp[0];
    assign Cout = temp[1];
    
endmodule
