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

    
    ///////////////////////////////////////////////////////
    //         Defining Parameters and Variables         //
    ///////////////////////////////////////////////////////

    // Parameters for the size of vectors within the system
    parameter WIDTH = 64;   // the size of a the vector used when summing/multiplying
    parameter ENDING_ZEROS = 2; // the number of extra zeros at the end that aid in rounding

    parameter inf_val = 16'b0111_1100_0000_0000;
    parameter neg_inf_val = 16'b1111_1100_0000_0000;

    parameter nan_val = 16'b0_11111_10_0000_0000;
    parameter neg_zero = 16'b1_00000_0000000000;

    parameter min_val = 16'b0_00001_0000000000; // e-14 * 1.0
    parameter min_neg_val = 16'b1_00001_0000000000;

    parameter max_val = 16'b0_11110_00_0000_0000;
    parameter max_neg_val = 16'b1_11110_00_0000_0000;


    // Components of x, y, and z
    logic         xs, ys, zs; // the signs of x, y, z
    logic [4:0]   xe, ye, ze; // the exponents of x, y, z
    logic [9:0]   xm, ym, zm; // the mantissa of x, y, z

    // Product components
    logic        ps;     // the sign of the product
    logic [5:0]  pe;     // the exponent of the product
    logic [21:0] mid_pm; // product of the mantissa; used in pm, but not expanded to its full WIDTH size yet

    // Result components
    logic ms; // sign of the final result
    logic [4:0] me; // the exponent of the final result
    logic [WIDTH:0] mm; // the mantissa of the final result

    logic big_z, z_is_solution;




    // list of definitions for whether x, y, and z are zero, infinity, or NaN
    logic x_zero, x_inf, x_nan;  // whether x is zero, infinity, or NaN
    logic y_zero, y_inf, y_nan;  // whether y is zero, infinity, or NaN
    logic z_zero, z_inf, z_nan;  // whether z is zero, infinity, or NaN

    logic subtract; // whether the system should subtract z from x*y
    logic can_add, can_multiply; // whether the system can add / multiply
    logic no_product, z_visible, subtract_1, prod_visible; // if the product is zero/subnormal
    logic [1:0] which_nx; // whether the product or z is inexact ( [ z is inexact, product is inexact] )
    
    logic product_greater;

    logic one_less_mshift;


    // Final Variables (from the FMA algorithm); these are what are added/tell exactly what is being added

    logic [WIDTH:0] am;  // zm adjusted to be centered in a vector of WIDTH size based on a_cnt
    logic [WIDTH:0] pm;  // the product of the mantissa adjusted to be centered in a vector of WIDTH size
    logic [WIDTH:0] sm;  // the sum of the product and z mantissas

    // Adjusting for the zero of the system
    logic [5:0] a_cnt;   // the exponent difference between pe and ze
    logic [7:0] m_shift; // additional adjustment atop the adjustment of ze and pe

    logic [15:0] mult; // Potential final result if no NaN, Zero, or Infinity issues
   
    //  OpCtrl:
    //    Fma: {not multiply-add?, negate prod?, negate Z?}
    //        000 - fmadd
    //        001 - fmsub
    //        010 - fnmsub
    //        011 - fnmadd
    //        100 - mul
    //        110 - add
    //        111 - sub
    



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

    fma16_pcalc calculate_prod( .xs, .ys, .xe, .ye, .xm, .ym,  // input: x and y sign, exponent, and mantissa
                                .x_zero, .y_zero,  // input: x and y are zero
                                
                                // outputs (products)
                                .ps, .pe, .mid_pm  // product sign, exponent, and mantissa
    );


    ///////////////////////////////////////////////////////////////////////////////
    // Calculate the Adjustments and Variables of the System
    //      - Calculates adjustment flags that are used to further correct
    //      - Calculates the summation of the product (pm) and addend (am)
    //      - Calculates the decimal shift necessary to adjust final result
    ///////////////////////////////////////////////////////////////////////////////

    fma16_align_and_sum #(WIDTH, ENDING_ZEROS) sum_prod( .ps, .zs, .xs, .ys, // signs of product, x, y, z
                                                        .pe, .xe, .ye, .ze, // product exponent, x exponent, y exponent, z exponent
                                                        .zm, .mid_pm,      // product mantissa, product mantissa
                                                        .x_zero, .y_zero, .z_zero, // whether x, y, z are zero

                                                        .a_cnt,   // exponent difference
                                                        .m_shift, // shift amount for leading 1's

                                                        .which_nx, .subtract_1, .ms,
                                                        .z_visible, .prod_visible,

                                                        .big_z, .z_is_solution,
                                                        .one_less_mshift,
                                                        
                                                        .sm // which nx to use and the difference between the exponents
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
    logic block_nx;
    logic nv, of, uf, nx; // invalid, overflow, underflow, inexact

    fma16_result #(WIDTH, ENDING_ZEROS) calc_result( .sm,  // the sum of the product and addend mantissas
                                                     .ms, .m_shift, // the sum of the mantissa and the shift amount
                                                     .which_nx, .subtract_1,  // which nx to use, which subtract
                                                     .z_visible, .prod_visible,  // used for inexact
                                                     .roundmode,     // the rounding mode of the system
                                                     .zs, .ze, .zm,  // the exponent and mantissa of z
                                                     .ps, .pe, .mid_pm,

                                                     .one_less_mshift,

                                                     .big_z, .z_is_solution,
                                                     
                                                     // outputs (final result without taking errors into account)
                                                    .me, // .fin_mm(mm),
                                                    .nx(block_nx),
                                                    .mult // the exponent and mantissa of the result
    );


    // Flag Logic (based on Rounding)
    // Overflow
    assign of = 1'b0; // me[5] ? 1'b1 : 1'b0;

    // Invalid if any input is NaN
    // assign nv = 1'b0; //((result==nan_val) & ~(x_zero&y_zero)) | (((x_zero|y_zero) & z_inf) & (x^y)) | ((x_zero|y_zero) & z_inf & xs & ys); //((x_zero & y_inf) | (y_zero & x_inf)); // | ((mult == nan_val) & (x!=16'h7fff) & (y!=16'h7fff)));

    assign uf = 0;


    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


    // 7fff = 0_11111_111111111111 - Inf
    // 7e00 = 0_11111_100000000000 - NaN
    // 8000 = neg_zero
    logic nan_result;
    assign nan_result = (mult==nan_val);

    logic inf_result;
    assign inf_result = ((mult==inf_val) | (mult==neg_inf_val));

    logic max_result;
    assign max_result = (mult[14:10]==5'b11111);

    logic zero_result;
    assign zero_result = (mult[14:0]=='0);

    logic max_input;
    assign max_input = (x==max_val) | (x==max_neg_val);

    logic [15:0] fix_result;
    logic fix_flag;
    logic f_nx;
    logic f_nv;
    always_comb begin
        fix_flag = 0;
        f_nx = 0;
        f_nv = 0;

        if (x_nan|y_nan|z_nan|x_inf|y_inf|z_inf|x_zero|y_zero|z_zero|max_result|zero_result) begin
            fix_flag = 1;
            fix_result = mult;
            
            
            if (x_inf|y_inf|z_inf|max_result) begin
                if (z_inf|z_nan) begin
                    if (z_inf)         begin fix_result = z; end
                    else               begin 
                        if (z[8:0]==9'b1_1111_1111 | z[8:0]==9'b0_0000_0000) 
                                       begin fix_result = nan_val; f_nv = 0; end
                        else
                                       begin fix_result = nan_val; f_nv = 1; end
                    end
                end
                else if (y_inf)        begin fix_result = y; end
                else if (max_result)   begin fix_result = {ms, max_val[14:0]}; f_nv = 1; end
                else                   begin fix_result = inf_val;  end
            end 
            
            
            else if (x_zero & y_zero & z_zero) begin
                if ((zs&xs) ^ (zs&ys)) begin fix_result = neg_zero; end
                else                   begin fix_result = '0; end
            end 


            else if ((x_zero|y_zero) & z_inf) begin
                if (x_zero & y_zero)
                                       begin fix_result = nan_val; end
                else
                    if (x^y)           begin fix_result = z; end
                    else if (xs)       begin fix_result = nan_val; end
                    else               begin fix_result = nan_val; end
            end 


            else if (x_nan | y_nan | z_nan) begin 
                        if (x_nan)      begin fix_result = x; end
                        else if (y_nan) begin fix_result = y; end
                        else            begin fix_result = z; end  
            end


            else if (x_zero & (y_inf | z_nan) | (y_zero) & (x_inf | z_nan))
                                       begin fix_result = nan_val; end


            else if (x_zero | y_zero)  begin
                    if (z_zero)        begin 
                                             fix_result = {((xs^ys) & zs), 15'b0}; 
                    end else           begin fix_flag = { ((xs^ys) & zs), 15'b0 };  end
            end 

            else if (zero_result)      begin 
                if (~x_zero & ~y_zero & ~z_zero)
                                       begin fix_result = '0; end
                else if(zs) begin
                    if (ys) begin
                        if (xs)        begin fix_result = '0 ; f_nx = 1;  end
                        else           begin fix_result = 16'h8000 ; f_nx = 1;  end
                    end else begin
                        if (xs)        begin fix_result = (ms & ~(x_zero) & ~y_zero & ~z_zero) ? '0 : 16'h8000 ; f_nx = 1;  end
                        else           begin fix_result = '0 ; f_nx = 1;  end
                    end
                end else begin
                    if (ys) begin
                        if (xs)        begin fix_result = '0; f_nx = 1;  end
                        else           begin fix_result = 16'h8000 ; f_nx = 1;  end
                    end else begin
                        if (xs)        begin fix_result = 16'h8000 ; f_nx = 1;  end
                        else           begin fix_result = '0; f_nx = 1;  end
                    end
                end
                
            end

            else if (max_result)       begin fix_result = max_val; f_nv = 1; end


            else                       begin fix_result = 16'hxxxx; fix_flag = 0; end

        end
    end

    assign nx = (fix_flag) ? f_nx : block_nx;
    // assign nv = ((result==nan_val) & ~(x_zero&y_zero)) | (((x_zero|y_zero) & z_inf) & (x^y)) | ((x_zero|y_zero) & z_inf & xs & ys); //((x_zero & y_inf) | (y_zero & x_inf)); // | ((mult == nan_val) & (x!=16'h7fff) & (y!=16'h7fff)));

    assign nv = (fix_flag) ? f_nv : 0;

    // Assigning the flags of the system; these are used to determine if the result is valid or not
    assign flags = {nv, of, uf, nx}; // { invalid, overflow, underflow, inexact }

    // Assign result based on the NaN, Zero, and Infinity values of the system; apply these rules before assigning mult
    assign result = (fix_flag) ? fix_result : mult; //result = (x_zero & y_zero & z_zero) ? ((zs&xs)^(zs&ys)) ? neg_zero : '0 : ((x_zero|y_zero) & z_inf) ? (x^y) ? z : nan_val : (x_nan | y_nan | z_nan) ? nan_val : ((x_zero & (y_inf | z_nan)) | (y_zero & (x_inf | z_nan))) ? nan_val : (x_zero | y_zero) ? (z[14:0]==0) ? {((xs^ys) & zs), 15'b0} : z : (mult[14:0]==0) ? {((xs^ys) & zs), 15'b0}  :  mult; // (zs & ~z_zero & (mult == 16'b0100_0000_0000_0000)) ? 16'b0011_1111_1111_1111 : mult;
    


    endmodule