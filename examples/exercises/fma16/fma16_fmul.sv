/**
    A System Verilog program that 
// For a refresher, I advise using https://www.geeksforgeeks.org/multiplying-floating-point-numbers/


    Zoe Worrall - zworrall@g.hmc.edu
    E154 System on Chip
    February 12, 2025
*/

module fma16_fmul(
    x, 
    y, 
    z, 
    result, 
    flags	
);

input [15:0] x;
input [15:0] y;
input [15:0] z;

output [15:0] result;
output [3:0]  flags;

/*** PARAMETERS ***/
// value calculation

reg        sign_x, sign_y, sign_z;

reg [4:0]  exp_x, exp_y, exp_z;

reg [9:0] frac_z;
reg [10:0] frac_x, frac_y;
wire [21:0] middle_frac;

assign sign_x = x[15];
assign sign_y = y[15];
assign sign_z = ((sign_x & sign_y) | (~sign_x & ~sign_y)) ? 0 : 1; // aka XOR

assign exp_x = x[14:10]; // 4 bits
assign exp_y = y[14:10]; // 4 bits

assign frac_x = {1'b1, x[9:0]};
assign frac_y = {1'b1, y[9:0]};

assign middle_frac = frac_x * frac_y;
assign exp_z = (middle_frac[21]) ? {exp_x + exp_y - 5'b01110} : {exp_x + exp_y - 5'b01111};//(frac_z[11]) ? exp_x + exp_y + 1 : exp_x + exp_y;

assign frac_z = (middle_frac[21]) ? middle_frac[20:11] : middle_frac[19:10];

assign result = {sign_z, exp_z, frac_z};
assign flags = 0;

endmodule