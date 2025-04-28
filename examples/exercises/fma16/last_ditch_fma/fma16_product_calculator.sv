/**
	A module that multiplies the constants in FMA 16 and returns the relevant
    sign, exponent, and mantissa of the product.

    Zoe Worrall - zworrall@g.hmc.edu
    E154 System on Chip
    April 22, 2025
*/

module fma16_product_calculator(
    input  logic        xs, ys,  // the signs of x, y
    input  logic [4:0]  xe, ye,  // the exponents of x, y
    input  logic [9:0]  xm, ym,  // the mantissa of x, y
    input  logic        negp, 

    input  logic        x_zero, y_zero, // whether x, y are zero
    
    output logic        ps,      // the sign of the product
    output logic [6:0]  pe,      // the exponent of the product
    output logic [21:0] mid_pm   // the product of the mantissas
    );

    assign ps = xs ^ ys ^ negp; // product sign

    assign pe = (x_zero | y_zero) ? '0 : ({2'b00, xe} + {2'b00, ye} - 7'b001111); // product exponent

    assign mid_pm = {(xe!=0), xm} * {(ye!=0), ym}; // product of mantissa

endmodule