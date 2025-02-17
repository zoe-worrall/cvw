/**
    A System Verilog program that 
// For a refresher, I advise using https://www.geeksforgeeks.org/multiplying-floating-point-numbers/


    Zoe Worrall - zworrall@g.hmc.edu
    E154 System on Chip
    February 17, 2025
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

reg needToRound;
reg [9:0] mantissaTo1, mantissaTo0;

// the final bit of the mantissa if it needs to be changed
reg rne_bit, rtz_bit, rdn_bit, rup_bit;


// bits for normal calculations
reg        sign_x, sign_y, sign_z;

reg [4:0] exp_x, exp_y;
reg [4:0]  exp_z;
reg [10:0] mant_x, mant_y;

reg [20:0] midd_mant;
reg [9:0] mant_z;

// --------------ROUNDING CALCULATION---------------- //
// ROUNDING
assign needToRound = midd_mant[9:0] > 0;
assign mantissaTo1 = midd_mant[9:0]-9'b1000_00000;

// RNE
assign rne_bit = ((mantissaTo1==0)||(mantissaTo1>9'b1000_00000)) ? 0 : 1; // if the initial value is closer to 0 vs closer to 1


// --------------ACTUAL VALUE CALCULATION---------------- //

// sign
assign sign_z = x[15] ^ y[15];

// exponential
assign exp_x = x[14:10];
assign exp_y = y[14:10];

// if we round up, we will sometimes need the exponent to be one lower
assign exp_z = (needToRound && rne_bit) ? {exp_x + exp_y - 4'b1110} : {exp_x + exp_y - 4'b1111};

// mantissa
assign mant_x = {1'b1, x[9:0]};
assign mant_y = {1'b1, y[9:0]};
assign midd_mant = mant_x * mant_y;
assign mant_z = (needToRound) ? {midd_mant[19:11], rne_bit} : midd_mant[19:10];

// ----------------- OUTPUTS ------------------------- //


assign result = {sign_z, exp_z, mant_z};
assign flags[3:1] = 0;

assign flags[0] = (midd_mant[9:0] > 0) ? 1 : 0;

endmodule