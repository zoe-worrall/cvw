    /**
        A module that runs an fma16 calculation
        Takes in x, y as multipliers and z as an addend

        Zoe Worrall - zworrall@g.hmc.edu
        E154 System on Chip
        April 23, 2025
    */

module fma16(
        // Inputs
        input logic [15:0]  x, // the multiplicand of the fma16
        input logic [15:0]  y, // the multiplier of the fma16
        input logic [15:0]  z, // the addend of the fma16

        input logic         mul,       // whether the system is multiplying
        input logic         add,       // whether the system is adding
        input logic         negp,      // whether we should negate the product
        input logic         negz,      // whether we should negate the addend

        input logic  [1:0]  roundmode, // 00: round to zero, 01: round to even, 10: round down, 11: round up (toward positive infinity)
        
        // Outputs
        output logic [15:0] result,    // the resulting 16 bits out of fma16
        output logic [3:0]  flags      // the flags of the system (invalid, overflow, underflow, inexact)
    ); 


    parameter WIDTH = 36;   // the size of a the vector used when summing/multiplying
    parameter ENDING_ZEROS = 2; // the number of extra zeros at the end that aid in rounding

    // Parameters for the size of vectors within the system
    parameter nan_val = 16'b0_111_11_1000000000;
    
    // Components of x, y, and z
    logic         xs, ys, zs; // the signs of x, y, z
    logic [4:0]   xe, ye, ze; // the exponents of x, y, z
    logic [9:0]   xm, ym, zm; // the mantissa of x, y, z

    // Product components
    logic        ps;     // the sign of the product
    logic [6:0]  pe;     // the exponent of the product
    logic [21:0] mid_pm;     // product of the mantissa; used in pm, but not expanded to its full WIDTH size yet

    logic x_zero, x_inf, x_nan;  // whether x is zero, infinity, or NaN
    logic y_zero, y_inf, y_nan;  // whether y is zero, infinity, or NaN
    logic z_zero, z_inf, z_nan;  // whether z is zero, infinity, or NaN
    logic [2:0] op_ctrl;

    logic a_sticky;

    logic ss;
    logic [6:0] se;
    logic [WIDTH-1:0] sm;

    logic inverted_add;
    logic addend_s;

    logic sum_s;
    logic sum_e;
    logic tot_shift;

    logic product_invisible, z_invisible, inverse_addend;

    logic [WIDTH-1:0]   am;            
    logic [21:0]        without_prod;  
    logic               no_product;  

    ///////////////////////////////////////////////////////
    //         Defining Parameters and Variables         //
    ///////////////////////////////////////////////////////

    ////////////////////// Calculations //////////////////////

    ///////////////////////////////////////////////////////////////////////////////
    // Calculate The Constants of the system
    //      - Assigns the signs, exponents, and mantissas of x, y, and z
    //      - Assigns whether x, y, and z are zero, infinity, or NaN
    //      - Assigns operation control bits **classificiations
    ///////////////////////////////////////////////////////////////////////////////

    fma16_classification classifier(.x, .y, .z,           // x, y, and z for fma16
                                        .mul, .add, .negp, .negz,             // operation control bits
                                        .xs, .ys, .zs,        // the signs of x, y, z
                                        .xe, .ye, .ze,        // the exponents of x, y, z
                                        .xm, .ym, .zm,        // the mantissa of x, y, z
                                        .x_zero, .y_zero, .z_zero, // assigning whether x, y, z are zero
                                        .x_inf, .y_inf, .z_inf,    // assigning whether x, y, z are infinity
                                        .x_nan, .y_nan, .z_nan     // assigning whether x, y, z are NaN
    );

    ///////////////////////////////////////////////////////////////////////////////
    // Calculate the Products of the system
    //      - Calculates the sign, exponent, and mantissa of the product
    ///////////////////////////////////////////////////////////////////////////////

    fma16_product_calculator calculate_prod( // input: x and y sign, exponent, and mantissa
                                .xs, .ys, 
                                .xe, .ye, 
                                .xm, .ym,
                                .x_zero, .y_zero,  // input: x and y are zero
                                .negp,

                                // outputs (products)
                                .ps, .pe, .mid_pm  // product sign, exponent, and mantissa
    );

    logic [7:0] m_shift;

    ///////////////////////////////////////////////////////////////////////////////
    // Calculate the Adjustments and Variables of the System
    //      - Calculates adjustment flags that are used to further correct
    //      - Calculates the summation of the product (pm) and addend (am)
    //      - Calculates the decimal shift necessary to adjust final result
    ///////////////////////////////////////////////////////////////////////////////

    fma16_align_and_sum #(WIDTH, ENDING_ZEROS) sum_prod(.xs, .ys,
                                                        .negp, 
                                                        
                                                        .ps, .pe, .mid_pm,

                                                        .zs, .ze, .zm,

                                                        .x_zero, .y_zero, .z_zero,

                                                        .z_invisible, .product_invisible, .inverse_addend,

                                                        .m_shift, // shift amount for leading 1's
                                                        .ss, .se, .sm // which nx to use and the difference between the exponents
    );
    

    ///////////////////////////////////////////////////////////////////////////////
    // Calculate a Potential Result that will be used if the system is not NaN, Inf, or Zero
    //      - Calculates the result of the system
    //      - Calculates the final exponent and mantissa of the result
    //      - Rounds the result based on the rounding mode of the system
    ///////////////////////////////////////////////////////////////////////////////

    
    ///////////////////////////////////////////////////////////////////////////////
    // Calculates the Flags
    //      - Overflow is assigned when the exponent & mantissa is too large
    //      - Inexact is assigned when the result is not exact to the actual value
    //      - Invalid is assigned when an operation that is not allowed/undefined is performed
    //      - Underflow is assigned when the exponent & mantissa is too small
    ///////////////////////////////////////////////////////////////////////////////

    // Check to see (if inexact) how rounding might need to work
    logic error;
    logic raise_flag;
    logic nv, of, uf, nx; // invalid, overflow, underflow, inexact

    logic ms;
    logic [4:0] me;
    logic [15:0] mult;

    fma16_result #(WIDTH, ENDING_ZEROS) calc_result( .sm,  // the sum of the product and addend mantissas
                                                     .ms, 
                                                     .m_shift, // the sum of the mantissa and the shift amount
                                                     .ms,

                                                     .product_invisible,
                                                     .z_invisible,

                                                     // outputs (final result without taking errors into account)
                                                    .me, // .fin_mm(mm),
                                                    .nx,
                                                    .mult // the exponent and mantissa of the result
    );


    // Flag Logic (based on Rounding)
    // Overflow
    assign of = 1'b0; // me[5] ? 1'b1 : 1'b0;

    // inexact if the result is not exact to the actual value
    // assign nx = 1'b1; //(mm == 0) ? 1'b0 : ((mm - { {(WIDTH-1-10-10-ENDING_ZEROS){1'b0}}, 1'b1, mult[9:0], (10+ENDING_ZEROS)'(1'b0) }) != 0) ? 1'b1 : 1'b0; // if data is left out of mm_part, this 
    
    // Invalid if any input is NaN
    assign nv = ((x_zero & y_inf) | (y_zero & x_inf)); // | ((mult == nan_val) & (x!=16'h7fff) & (y!=16'h7fff)));

    assign uf = 0;


    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // Assigning the flags of the system; these are used to determine if the result is valid or not
    assign flags = {nv, of, uf, nx}; // { invalid, overflow, underflow, inexact }

    // Assign result based on the NaN, Zero, and Infinity values of the system; apply these rules before assigning mult
    assign result = (x_nan | y_nan | z_nan) ? nan_val : ((x_zero & (y_inf | x_nan)) | (y_zero & (x_inf | x_nan))) ? nan_val : (x_zero | y_zero) ? (z[14:0]==0) ? {((xs^ys) & zs), 15'b0} : z : (mult[14:0]==0) ? {((xs^ys) & zs), 15'b0}  :  mult; // (zs & ~z_zero & (mult == 16'b0100_0000_0000_0000)) ? 16'b0011_1111_1111_1111 : mult;
    


    endmodule