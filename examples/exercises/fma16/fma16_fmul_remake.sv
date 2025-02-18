/**
    A System Verilog program that 
// For a refresher, I advise using https://www.geeksforgeeks.org/multiplying-floating-point-numbers/


    Zoe Worrall - zworrall@g.hmc.edu
    E154 System on Chip
    February 12, 2025
*/

module fma16_fmul_remake(
    x, 
    y,
    result, 
    flags	
);

input [15:0] x;
input [15:0] y;

output [15:0] result;
output [3:0]  flags;

/*** PARAMETERS ***/
// value calculation

reg        sign_x, sign_y, sign_z;

reg [5:0]  exp_z;

reg [9:0] frac_z;
reg [10:0] frac_x, frac_y;
wire [10:0] mant_z;

assign sign_z = x[15] ^ y[15];
assign exp_z = x[14:10] + y[14:10] - 4'b0111;

assign mant_x = {1'b1, x[9:0]};
assign mant_y = {1'b1, y[9:0]};

assign mant_z = [20:11];

assign result = {sign_z, exp_z, mant_z};
assign flags = 0;

endmodule