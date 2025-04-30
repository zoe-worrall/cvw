/**
	A module that finds aligns am and pm, and computes 
    the difference between exponents and the state of the product's
    exponent for future use

    Zoe Worrall - zworrall@g.hmc.edu
    E154 System on Chip
    April 30, 2025
*/

module fma16_align_and_sum  #(parameter VEC_SIZE, parameter END_BITS) (
    input  logic         ps, zs, xs, ys, // signs of product and z

    input  logic [5:0]   pe,         // product exponent
    input  logic [4:0]   xe, ye, ze, // exponents of x, y, z

    input  logic [9:0]   zm,         // z mantissa
    input  logic [21:0]  mid_pm,     // product mantissa

    input  logic         x_zero, y_zero, z_zero, // Zero Flags

    output logic [5:0]   a_cnt,       // exponent difference between pe and ze
    
    output logic [VEC_SIZE:0] sm, // the sum of the product and z mantissas

    output logic [7:0]   m_shift, // additional adjustment for adjusting decimal

    output logic        big_z, z_is_solution, // whether z dwarfs product or not (i.e. if z is way bigger than the product)

    output logic        one_less_mshift,

    output logic [1:0]  which_nx,   // used to determine if subnormal
    output logic        subtract_1, z_visible, prod_visible, ms // used to adjust if z or product is subnormal and negative
    );

    // Zm Is Shifted
    logic [VEC_SIZE-1:0] zm_bf_shift;
    logic [VEC_SIZE:0] am; // aligned zm for sum
    logic [VEC_SIZE:0] pm; // aligned pm for sum

    // bit adjustment variables
    logic product_greater; // if the product is greater than am
    logic [5:0] diff_pe_ze; // Used to correct a_cnt being the wrong size
    logic [6:0] pot_acnt; // The number of bits am is shifted to be added with pm
    logic [7:0] shift_amt; // Used if z is the solution to correct for odd magnitude behavior
    logic [7:0] pos_m_shift; // Positive version of m_shift in the case that m_shift is negative
    logic [7:0] actual_difference; // The difference between pe and ze - what a_cnt should've been
    logic       no_product; // whether or not the adder can see the product when adding


    ///////////////////////////////////////////////////////////////////////////////
    // Major Variable Assignment
    ///////////////////////////////////////////////////////////////////////////////
    
    assign zm_bf_shift = { {(VEC_SIZE-END_BITS-10-10){1'b0}}, (ze!=0), zm, {(END_BITS+10)'(1'b0)} };

    /// Zm Changes
    assign am = (pot_acnt[6]) ? zm_bf_shift << ( ~pot_acnt + 1'b1  ) : (big_z) ? (z_is_solution) ? zm_bf_shift : (zm_bf_shift << shift_amt) : zm_bf_shift >> pot_acnt; //(big_z) ? (zm_bf_shift << priority_encode_zero) : (pot_acnt[6]) ? zm_bf_shift << ( ~pot_acnt + 1'b1  ) : zm_bf_shift >> pot_acnt;
    assign pm = (x_zero | y_zero | z_is_solution) ? '0 : { {(VEC_SIZE-21-END_BITS){1'b0}}, mid_pm, {(END_BITS)'(1'b0)}};
    
    assign ms = (product_greater) ? ps : zs;
    assign pos_m_shift = ~m_shift + 1; 


    ///////////////////////////////////////////////////////////////////////////////
    // Modules
    ///////////////////////////////////////////////////////////////////////////////
    
    // Modules to Determine:
    // 1. The sum of pm and am
    // 2. The alignment of am relative to pm
    // 3. Whether or not we need to subtract one from the solution

    // determine if 1 needs to be subtracted
    fma16_sub_one #(VEC_SIZE, END_BITS) sub_one(.ps, .zs, .pe, .ze, .diff_pe_ze, .big_z, .z_is_solution, .zm, .x_zero, .y_zero, .z_zero, .am, .sm, .pm, .subtract_1);
        
    // sum am and pm together into sm
    fma16_sum #(VEC_SIZE, END_BITS) sum(.pm, .am, .a_cnt(pot_acnt), .big_z, .diff_sign(~z_zero & (zs ^ ps)), .no_product, .z_zero, .sm); // Calculates the sum of the product and z mantissas

    // determine how much to shift the mantissa in order to get the leading 1
    fma16_mshifter #(VEC_SIZE, END_BITS) mshifter(.sm, .big_z, .a_cnt(pot_acnt), .one_less_mshift, .diff_sign(~z_zero & (zs ^ ps)), .m_shift);



    ////////////////////////////// BIT WRAPPING ADJUSTMENT ///////////////////////////////
    //
    // I made a mistake with bit sizing. This means that a_cnt is two bits smaller than it should
    // be throughout most of the program. To rectify this, I have multiple binary bits that help
    // to determine what its behavior should be.
    //
    ///////////////////////////////////////////////////////////////////////////////
    // Adjustment Variable Calculations
    ///////////////////////////////////////////////////////////////////////////////
    always_comb begin

        // Assigning a_cnt (relative difference between pe and ze)
        // 
        //     - if pe is smaller than ze and both are negative, then a_cnt needs to 
        //          subtract 32 from its answer due to a wrapping error
        //     - otherwise, a_cnt is just the difference between pe and ze
        if ((pe==-6'd13) & (ze < -5'd1) & ($signed(diff_pe_ze)>$signed(20)))
            if (diff_pe_ze == 6'b110000)  a_cnt = diff_pe_ze;
            else                          a_cnt = diff_pe_ze; //{ ~diff_pe_ze[5], diff_pe_ze[4:0] };
        else                              a_cnt = diff_pe_ze;


        // Assigning which_nx ("which inexact")
        // if pe isn't negative, is bigger than z, if pe is greater than 15, and z isn't 0, which_nx is 0
        //     If z is the smaller of the two, which_nx is 0
        // if z is greater, that means we'll be subtracting from z
        //     If p is the smaller of the two, which_nx is 1
        if      (!pe[5] & (pe[4:0] >= ze) & (({2'b00,xe} + {2'b00,ye}) > 5'b01111) & (~z_zero))  which_nx = 0;
        else if ((pm!='0)  & (~z_zero))  which_nx = 1;
        else                             which_nx = 3;

    end

    assign diff_pe_ze = (pe - ze);                                              // Used to compute shifts in some places to account for pe being wrong size
    assign pot_acnt = pe-{1'b0,ze};                                             // The amount that am is shifted by
    assign no_product =  (diff_pe_ze < -7'd23) | (diff_pe_ze > 7'd23);          // Assigning no_product (used to determine if product is zero/subnormal)
    assign big_z = (~pot_acnt[6] & pe[5] & (pe!=-6'd13));                       // If ze is so big that it would cause pe to go from negative to positive 
    assign actual_difference = {3'b0, xe} + {3'b0, ye} - 8'd15 - {3'b0, ze};    // This should have been what a_cnt was, and is used to rectify differences
    assign z_is_solution = (big_z & (~actual_difference + 1'b1)>(8'd11));       // Determines if z actually causes pe to wrap around the block
    assign shift_amt = (~actual_difference+1'b1);                               // The amount of shift if z is a solution and there's a weird magnitude difference

    // If the product is greater than the added value: used to determine ms
    assign product_greater = (pm==am)?1:(am>pm)?0:(am[VEC_SIZE:END_BITS]!='0)?1:(pe[5]&pe>{1'b0,ze})?0:1; 

    ////////////////////////////////////////////////////////////////////////////////////


    ////////////////////////////// Priority Encoders ///////////////////////////////
    // These are used to determine whether or not you can see z or the multiplier

    // Z is Visible to the Adder
    always_comb begin
        if      (pot_acnt[6])  z_visible = 1'b0;
        else if (pot_acnt==11) z_visible = |{zm_bf_shift[END_BITS+10:0]}; // all bits before this have to be 0
        else if (pot_acnt==12) z_visible = |{zm_bf_shift[END_BITS+11:0]};
        else if (pot_acnt==13) z_visible = |{zm_bf_shift[END_BITS+12:0]};
        else if (pot_acnt==14) z_visible = |{zm_bf_shift[END_BITS+13:0]};
        else if (pot_acnt==15) z_visible = |{zm_bf_shift[END_BITS+14:0]};
        else if (pot_acnt==16) z_visible = |{zm_bf_shift[END_BITS+15:0]};
        else if (pot_acnt==17) z_visible = |{zm_bf_shift[END_BITS+16:0]};
        else if (pot_acnt==18) z_visible = |{zm_bf_shift[END_BITS+17:0]};
        else if (pot_acnt==19) z_visible = |{zm_bf_shift[END_BITS+18:0]};
        else if (pot_acnt==20) z_visible = |{zm_bf_shift[END_BITS+19:0]};
        else if (pot_acnt==21) z_visible = |{zm_bf_shift[END_BITS+20:0]};
        else if (pot_acnt==22) z_visible = |{zm_bf_shift[END_BITS+21:0]};
        else if (pot_acnt==23) z_visible = |{zm_bf_shift[END_BITS+22:0]};
        else if (pot_acnt==24) z_visible = |{zm_bf_shift[END_BITS+22:0]};
        else if (pot_acnt==25) z_visible = |{zm_bf_shift[END_BITS+23:0]};
        else if (pot_acnt==26) z_visible = |{zm_bf_shift[END_BITS+24:0]};
        else if (pot_acnt==27) z_visible = |{zm_bf_shift[END_BITS+25:0]};
        else if (pot_acnt==28) z_visible = |{zm_bf_shift[END_BITS+26:0]};
        else if (pot_acnt==29) z_visible = |{zm_bf_shift[END_BITS+27:0]};
        else                   z_visible = 1'b0; //  z_visible = ((ze!=0) | |zm);
    end

    // Product is Visible to the Adder
    always_comb begin
        if       (~(m_shift[7]))  prod_visible = 1'b0;
        else if (pos_m_shift==1)  prod_visible = |{pm[END_BITS-1:0]};
        else if (pos_m_shift==2)  prod_visible = |{pm[END_BITS+0:0]};
        else if (pos_m_shift==3)  prod_visible = |{pm[END_BITS+1:0]};
        else if (pos_m_shift==4)  prod_visible = |{pm[END_BITS+2:0]};
        else if (pos_m_shift==5)  prod_visible = |{pm[END_BITS+3:0]};
        else if (pos_m_shift==6)  prod_visible = |{pm[END_BITS+4:0]};
        else if (pos_m_shift==7)  prod_visible = |{pm[END_BITS+5:0]};
        else if (pos_m_shift==8)  prod_visible = |{pm[END_BITS+6:0]};
        else if (pos_m_shift==9)  prod_visible = |{pm[END_BITS+7:0]};
        else if (pos_m_shift==10) prod_visible = |{pm[END_BITS+8:0]};
        else if (pos_m_shift==11) prod_visible = |{pm[END_BITS+9:0]};
        else if (pos_m_shift==12) prod_visible = |{pm[END_BITS+10:0]};
        else if (pos_m_shift==13) prod_visible = |{pm[END_BITS+11:0]};
        else if (pos_m_shift==14) prod_visible = |{pm[END_BITS+12:0]};
        else if (pos_m_shift==15) prod_visible = |{pm[END_BITS+13:0]};
        else if (pos_m_shift==16) prod_visible = |{pm[END_BITS+14:0]};
        else if (pos_m_shift==17) prod_visible = |{pm[END_BITS+15:0]};
        else if (pos_m_shift==18) prod_visible = |{pm[END_BITS+16:0]};
        else if (pos_m_shift==19) prod_visible = |{pm[END_BITS+17:0]};
        else if (pos_m_shift==20) prod_visible = |{pm[END_BITS+18:0]};
        else if (pos_m_shift==21) prod_visible = |{pm[END_BITS+19:0]};
        else if (pos_m_shift==22) prod_visible = |{pm[END_BITS+20:0]};
        else if (pos_m_shift==23) prod_visible = |{pm[END_BITS+21:0]};
        else if (pos_m_shift==24) prod_visible = |{pm[END_BITS+22:0]};
        else if (pos_m_shift==25) prod_visible = |{pm[END_BITS+23:0]};
        else if (pos_m_shift==26) prod_visible = |{pm[END_BITS+24:0]};
        else if (pos_m_shift==27) prod_visible = |{pm[END_BITS+25:0]};
        else if (pos_m_shift==28) prod_visible = |{pm[END_BITS+26:0]};
        else if (pos_m_shift==29) prod_visible = |{pm[END_BITS+27:0]};
        else if (pos_m_shift==30) prod_visible = |{pm[END_BITS+28:0]};
        else if (pos_m_shift==31) prod_visible = |{pm[END_BITS+29:0]};
        else                      prod_visible = 1'b0;
    end




endmodule