/**
	A module that finds aligns am and pm, and computes 
    the difference between exponents and the state of the product's
    exponent (no_product) for future use

    Zoe Worrall - zworrall@g.hmc.edu
    E154 System on Chip
    April 22, 2025
*/
module fma16_align_and_sum  #(parameter VEC_SIZE, parameter END_BITS) (
    input  logic         ps, zs, xs, ys, // signs of product and z

    input  logic [5:0]   pe,         // product exponent
    input  logic [4:0]   xe, ye, ze, // exponents of x, y, z

    input  logic [9:0]   zm,         // z mantissa
    input  logic [21:0]  mid_pm,     // product mantissa

    input  logic         x_zero, y_zero, z_zero, // Zero Flags
    
    output logic [VEC_SIZE:0] sm, // the sum of the product and z mantissas

    output logic [7:0]   m_shift, // additional adjustment for adjusting decimal

    output logic product_greater,

    output logic [5:0]  diff_count, // the difference between ze and pe exponents
    output logic [1:0]  which_nx,   // used to determine if subnormal
    output logic        subtract_1, z_visible, ms // used to adjust if z or product is subnormal and negative
    );

    logic [VEC_SIZE:0] am; // aligned zm for sum
    logic [VEC_SIZE:0] pm; // aligned pm for sum

    logic [5:0] diff_pe_ze;
    logic       none_zero;
    
    assign diff_pe_ze = (pe - ze);

    logic [6:0] pot_acnt;
    assign pot_acnt = pe-{1'b0,ze}; //($signed(pe - ze) > 7'd0) ? (pe - ze) : (ze - pe);

    //                     if negative, make sure its greater than 11
    assign z_visible = (diff_pe_ze[5]) ? ((~diff_pe_ze + 1'b1) > 6'd11) : (diff_pe_ze > 6'd11); 

    logic smth_shifted_out;
    // this happens if m_shift is 
    assign smth_shifted_out = (|sm[END_BITS+m_shift:0])

    logic extra;

    ///////////////////////////////////////////////////////////////////////////////
    // Adjustment Variable Calculations
    ///////////////////////////////////////////////////////////////////////////////
    
    always_comb begin

        // Assigning diff_count (overall difference between pe and ze)
        //
        //     - As opposed to a_cnt, diff_count is a signed value that
        //         tells the exact difference between pe and ze
        //
        {extra, diff_count} = ({1'b0,pe} - {2'b00,ze});

        // Assigning which_nx (which inexact)
        //    This is used to determine what should be done if either z or the
        //      product is too small (only applies if negative)
        //
        //    If zs and ps are different, and their difference is wide while
        //       z's value is too small, small adjustments may need to be
        //       made in post
        //
        //     If z is the smaller of the two, which_nx is 0
        //     If p is the smaller of the two, which_nx is 1
        
        // if pe isn't negative, is bigger than z, if pe is greater than 15, and z isn't 0, which_nx is 0
        if      (!pe[5] & (pe[4:0] >= ze) & (({2'b00,xe} + {2'b00,ye}) > 5'b01111) & (~z_zero))  which_nx = 0;

        // if z is greater, that means we'll be subtracting from z
        else if ((pm!='0)  & (~z_zero))  which_nx = 1;

        else                             which_nx = 3;
    end

    // Assigning no_product (used to determine if product is zero/subnormal)
    //      - if either x or y is zero, then the product is zero
    //
    assign no_product =  (diff_pe_ze < -7'd23) | (diff_pe_ze > 7'd23); //((~x_zero) & (xe==0)) | ((~y_zero) & (ye==0)) | (pot_acnt[6]&(~(ze==0)));


    // a_cnt_pos is only positive if product is greater than ze  ~pot_acnt[6] & |pot_acnt[5:4
    assign ms = (pot_acnt==0) ? ((pm>am) ? ps : zs) : (pe==-6'd13) ? zs : (z_visible) ? (pm>am) ? ps : zs : (~pot_acnt[6]) ? ps : (pm>am) ? ps : zs;  // calculating final sign of result


    ///////////////////////////////////////////////////////////////////////////////
    // Addition
    ///////////////////////////////////////////////////////////////////////////////
    
    logic [VEC_SIZE-1:0] zm_bf_shift;
    logic [5:0] pos_pe;

    assign pos_pe = ~pe + 1'b1;
    assign big_z = (~pot_acnt[6] & pot_acnt>=30) ? (pe[5] & ~ze[4] & (pos_pe>={1'b0, ze})) ? 1'b0 : 1'b1 : 1'b0;
    assign zm_bf_shift = { {(VEC_SIZE-END_BITS-10-10){1'b0}}, (ze!=0), zm, {(END_BITS+10)'(1'b0)} };

    logic [VEC_SIZE:0] testy_am;
    assign testy_am = (pot_acnt[6]) ? zm_bf_shift << ( ~pot_acnt + 1'b1  ) : zm_bf_shift >> pot_acnt;
    assign pm = (x_zero | y_zero) ? 0 : { {(VEC_SIZE-21-END_BITS){1'b0}}, mid_pm, {(END_BITS)'(1'b0)}};

    // determine if we're going to need to subtract 1
    fma16_sub_one #(VEC_SIZE, END_BITS) sub_one(.ps, .zs, .pe, .ze, .diff_pe_ze, .zm, .x_zero, .y_zero, .z_zero, .am, .sm, .pm, .subtract_1);
        
    // sum am and pm together into sm
    fma16_sum #(VEC_SIZE, END_BITS) sum(.pm, .am, .a_cnt(pot_acnt), .diff_sign(~z_zero & (zs ^ ps)), .no_product, .z_zero, .sm); // Calculates the sum of the product and z mantissas

    // determine how much to shift the mantissa in order to get the leading 1
    fma16_mshifter #(VEC_SIZE, END_BITS) mshifter(.sm, .a_cnt(pot_acnt), .diff_sign(~z_zero & (zs ^ ps)), .m_shift);

endmodule
