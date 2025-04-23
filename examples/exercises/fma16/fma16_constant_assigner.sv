/**
	A module that assigns the constants used in FMA16

    Zoe Worrall - zworrall@g.hmc.edu
    E154 System on Chip
    April 22, 2025
*/

module fma16_constant_assigner(
    input  logic [15:0] x, y, z,  // the multiplicand, multiplier, and addend of this fma16 instruction
    input  logic [2:0]  op_ctrl,  // bits indicating mul, add, negp, and negz signals to the board

    output logic        xs, ys, zs, // the signs of x, y, and z
    output logic [4:0]  xe, ye, ze, // the exponents of x, y, and z
    output logic [9:0]  xm, ym, zm, // the mantissa of x, y, and z

    output logic        x_zero, y_zero, z_zero, // whether x, y, z are zero
    output logic        x_inf, y_inf, z_inf,    // whether x, y, z are infinity
    output logic        x_nan, y_nan, z_nan     // whether x, y, z are NaN
    );

    // parameters defined to check for zero, infinity, and NaN
    parameter inf_val = 16'b0_11111_0000000000;
    parameter nan_val = 16'b0_111_11_1000000000;
    parameter neg_zero = 16'b1_00000_0000000000;


    // Assigning Base Constants for Zeros, Infinities, and NaNs
    // Zeros
    assign x_zero = ((x==0) | (x==neg_zero));
    assign y_zero = ((y==0) | (y==neg_zero));
    assign z_zero = ((z==0) | (z==neg_zero));

    // Infinities
    assign x_inf = (x==16'b0_11111_0000000000);
    assign y_inf = (y==16'b0_11111_0000000000);
    assign z_inf = (z==16'b0_11111_0000000000);

    // NaNs
    assign x_nan  = ((x[15:10]==6'b011_111) & (x[9:0]!=0));
    assign y_nan = ((y[15:10]==6'b011_111) & (y[9:0]!=0));
    assign z_nan = ((z[15:10]==6'b011_111) & (z[9:0]!=0));

    // Assigning Signs, Exponents, and Mantissas for x, y, and z
    assign {xs, xe, xm} = x;
    assign {ys, ye, ym} = y;
    assign {zs, ze, zm} = z;

endmodule