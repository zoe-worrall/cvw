/**
	A module that assigns the constants used in FMA 16

    Zoe Worrall - zworrall@g.hmc.edu
    E154 System on Chip
    April 19, 2025
*/

module fma16_assignCons(
    input  logic [15:0] x, y, z,
    input  logic [2:0]  op_ctrl,
    output logic        xs, ys, zs,
    output logic [4:0]  xe, ye, ze,
    output logic [9:0]  xm, ym, zm,
    output logic        subtract, can_add, can_multiply,
    output logic        x_zero, y_zero, z_zero,
    output logic        x_inf, y_inf, z_inf,
    output logic        x_nan, y_nan, z_nan
    );

    parameter inf_val = 16'b0_11111_0000000000;
    parameter nan_val = 16'b0_111_11_1000000000;

    parameter neg_zero = 16'b1_00000_0000000000;

    // Assigning Base Variables
    assign x_zero = ((x==0) | (x==neg_zero));
    assign y_zero = ((y==0) | (y==neg_zero));
    assign z_zero = ((z==0) | (z==neg_zero));

    assign x_inf = (x==16'b0_11111_0000000000);
    assign y_inf = (y==16'b0_11111_0000000000);
    assign z_inf = (z==16'b0_11111_0000000000);

    assign x_nan  = ((x[15:10]==6'b011_111) & (x[9:0]!=0));
    assign y_nan = ((y[15:10]==6'b011_111) & (y[9:0]!=0));
    assign z_nan = ((z[15:10]==6'b011_111) & (z[9:0]!=0));

    assign subtract      = ((op_ctrl==3'b001) | (op_ctrl==3'b010) | (op_ctrl==3'b111)) ? 1'b1 : 1'b0;
    assign can_multiply  = ~(op_ctrl[1]);
    assign can_add       = ~(op_ctrl[0]) | (op_ctrl==3'b111) | (op_ctrl==3'b001);
    
    // Assigning Sections and Multiples
    assign {xs, xe, xm} = x;
    assign {ys, ye, ym} = y;
    assign {zs, ze, zm} = z;

endmodule