/**
    A System Verilog program that 
// For a refresher, I advise using https://www.geeksforgeeks.org/multiplying-floating-point-numbers/
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
reg [3:0]  exp_x, exp_y, exp_z;
reg [11:0] frac_z;

assign sign_x = x[15];
assign sign_y = y[15];
assign sign_z = ((sign_x & sign_y) | (~sign_x & ~sign_y)) ? 0 : 1; // aka XOR

assign exp_x = x[14:11];
assign exp_y = y[14:11];

assign frac_z = x[11]*y[11];

assign exp_z = (frac_z[11]) ? exp_x + exp_y + 1 : exp_x + exp_y;

assign result = {x[11], y[11], 2'b0, frac_z}; //{sign_z, exp_z, frac_z};
assign flags = 0;

endmodule