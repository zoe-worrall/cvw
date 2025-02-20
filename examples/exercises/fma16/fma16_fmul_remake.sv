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
reg [9:0] mantissa_hf;

// the final bit of the mantissa if it needs to be changed
reg rne_bit, rtz_bit, rdn_bit, rup_bit;


// bits for normal calculations
reg        sign_x, sign_y, sign_z;

reg [4:0] exp_x, exp_y, og_exp;
reg [4:0] rne_exp, exp_z;
reg [10:0] mant_x, mant_y;

reg [21:0] midd_mant;
reg [9:0] mant_z, rne_mant_z;

// --------------ROUNDING CALCULATION---------------- //
// ROUNDING
assign needToRound = midd_mant[9:0] > 0;
// assign mantissaTo1 = midd_mant[9:0]-9'b1000_00000;

// RNE
assign rne_bit = ~(midd_mant[9:0] > 10'b01000_00000);

// --------------ACTUAL VALUE CALCULATION---------------- //

// sign
assign sign_z = x[15] ^ y[15];

// exponential
assign exp_x = x[14:10];
assign exp_y = y[14:10];
assign og_exp = exp_x + exp_y - 4'b1111;

assign rne_exp = (midd_mant[21]) ? og_exp+1 : og_exp;


// mantissa
assign mant_x = {1'b1, x[9:0]};
assign mant_y = {1'b1, y[9:0]};
assign midd_mant = mant_x * mant_y;


// RNE: if it's halfway, we round to 0
// 	if bit 21 is set (i.e. it becomes 1) then that means that exp should be +1 and mant should be shifte
assign rne_mant_z = (midd_mant[21]) ? (midd_mant[20]) ? midd_mant[20:11] : midd_mant[19:11] + {{(9){1'b0}}, rne_bit} : {midd_mant[19:11], 1'b0}; //{ midd_mant[19:11], 1'b0 } ;

// Assign Post-rounding
assign exp_z = (needToRound) ? rne_exp : og_exp;
assign mant_z = (needToRound) ? rne_mant_z : midd_mant[19:10];


// ----------------- OUTPUTS ------------------------- //


assign result =  {sign_z, exp_z, mant_z};
assign flags[3:1] = 0;

assign flags[0] = (midd_mant[9:0] > 0) ? 1 : 0;

endmodule