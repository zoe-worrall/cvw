/**
	A module that assigns the constants used in FMA16

    Zoe Worrall - zworrall@g.hmc.edu
    E154 System on Chip
    April 22, 2025
*/

module fma16_classification(
    input  logic [15:0] x, y, z,  // the multiplicand, multiplier, and addend of this fma16 instruction
    input  logic        mul, add, negp, negz,  // bits indicating mul, add, negp, and negz signals to the board

    output logic        xs, ys, zs, // the signs of x, y, and z
    output logic [4:0]  xe, ye, ze, // the exponents of x, y, and z
    output logic [9:0]  xm, ym, zm, // the mantissa of x, y, and z

    output logic        x_zero, y_zero, z_zero, // whether x, y, z are zero
    output logic        x_inf, y_inf, z_inf,    // whether x, y, z are infinity
    output logic        x_nan, y_nan, z_nan     // whether x, y, z are NaN
    );

    // parameters defined to check for zero, infinity, and NaNa
    parameter inf_val = 16'b0111_1100_0000_0000;
    parameter neg_inf_val = 16'b1111_1100_0000_0000;

    parameter nan_val = 16'b0_11111_10_0000_0000;
    parameter neg_zero = 16'b1_00000_0000000000;


    // Assigning Base Constants for Zeros, Infinities, and NaNs
    // Zeros
    assign x_zero = ((x==0) | (x==neg_zero));
    assign y_zero = ((y==0) | (y==neg_zero)) & mul;
    assign z_zero = ((z==0) | (z==neg_zero)) | ~add;

    // Infinities
    assign x_inf = ((x==inf_val) | (x==neg_inf_val));
    assign y_inf = ((y==inf_val) | (y==neg_inf_val)) & mul;
    assign z_inf = ((z==inf_val) | (z==neg_inf_val)) & add;

    // NaNs
    assign x_nan = (((x[15:10]==6'b111_111) | (x[15:10]==6'b011_111)) & ~x_inf);
    assign y_nan = (((y[15:10]==6'b111_111) | (y[15:10]==6'b011_111)) & ~y_inf) & mul;
    assign z_nan = (((z[15:10]==6'b111_111) | (z[15:10]==6'b011_111)) & ~z_inf) & add;

    // Assigning Signs, Exponents, and Mantissas for x, y, and z
    assign {xs, xe, xm} = x;
    assign {ys, ye, ym} = (~mul) ? 16'h3c00 : (negp) ? { 1'b1^y[15], y[14:0] } : y; // if adding, y should be itself
    assign {zs, ze, zm} = (~add) ? 16'h0000 : (negz) ? { 1'b1^z[15], z[14:0] } : z;

endmodule