/**
	A module that multiplies the constants in FMA 16 and returns the relevant
    sign, exponent, and mantissa of the product.

    Zoe Worrall - zworrall@g.hmc.edu
    E154 System on Chip
    April 22, 2025
*/

module fma16_pcalc(
    input  logic        xs, ys,  // the signs of x, y
    input  logic [4:0]  xe, ye,  // the exponents of x, y
    input  logic [9:0]  xm, ym,  // the mantissa of x, y

    input  logic        x_zero, y_zero, // whether x, y are zero
    
    output logic        ps,      // the sign of the product
    output logic [5:0]  pe,      // the exponent of the product
    output logic [21:0] mid_pm   // the product of the mantissas
    );

    assign ps = xs ^ ys; // product sign

    assign pe = (x_zero | y_zero) ? '0 : (xe + ye - 5'b01111); // product exponent

    // define the product bits of x/y before multiplying in case one is subnormal
    logic x_front, y_front;
    assign x_front = (xe == 0) ? 1'b0 : 1'b1; // 0 if subnormal
    assign y_front = (ye == 0) ? 1'b0 : 1'b1; // 0 if subnormal
    
    assign mid_pm = {x_front, xm} * {y_front, ym}; // product of mantissa

endmodule