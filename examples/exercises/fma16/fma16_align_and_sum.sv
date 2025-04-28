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
    output logic        subtract_1, z_visible, prod_visible, ms // used to adjust if z or product is subnormal and negative
    );

    // logic product_greater;

    logic [VEC_SIZE:0] am; // aligned zm for sum
    logic [VEC_SIZE:0] pm; // aligned pm for sum

    logic [5:0] diff_pe_ze;
    logic       none_zero;
    
    assign diff_pe_ze = (pe - ze);

    logic [6:0] pot_acnt;
    assign pot_acnt = pe-{1'b0,ze}; //($signed(pe - ze) > 7'd0) ? (pe - ze) : (ze - pe);


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
    //
    //               v  if there was no shift in the zm_bf, that means that we didn't lose any bits and we can just compare which one's bigger
    //                                                    
    //                                                    v -13 is just a weird number; if it's there, that means that the system's predominated by z
    //
    //                                                                        v check to see if z was moved off of the page - if it wasn't check which of pm or am is bigger
    //
    //                                                                                                            v if this is a negative value, ps takes precedence
    //
    //                                                                                                                                      v  if pe is bigger than ze, pe was "negative" when computed meaning that x and y are too small
    //
    //                                                                                                                                                                    v this still has the potential to be wrong; there may be a case where p was way too small
    // assign ms = (pot_acnt==0) ? ((pm>am) ? ps : zs) : (pe==-6'd13) ? zs : (z_visible) ? (pm>am) ? ps : zs : (~pot_acnt[6]) ? ps : (pm>am) ? ps : zs;  // calculating final sign of result


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
    
    assign product_greater = (pm==testy_am)?1:(testy_am>pm)?0:(testy_am[VEC_SIZE:END_BITS]!='0)?1:(pe[5]&pe>{1'b0,ze})?0:1;   //(am!='0)?1:(pe>{1'b0, ze})?(~pe[5])?0:((pe==-6'd13)?0:1):0);

    /// just added product_greater logi
    assign am = (pot_acnt[6]) ? zm_bf_shift << ( ~pot_acnt + 1'b1  ) : (pot_acnt>35 & ~product_greater) ? zm << ( ~diff_pe_ze) : zm_bf_shift >> pot_acnt;

    logic pot_ms;
    assign ms = (product_greater) ? ps : zs;

    
    // z is visible if the total shift between exponents is between -11 and 11.
    //                     if negative, make sure its greater than 11
    // assign z_visible = (diff_pe_ze[5]) ? ((~diff_pe_ze + 1'b1) > 6'd11) : (diff_pe_ze > 6'd11); 
    always_comb begin
        if      (pot_acnt[6])  z_visible = 1'b0;
        else if (pot_acnt==1)  z_visible = |{zm_bf_shift[END_BITS:0]};
        else if (pot_acnt==2)  z_visible = |{zm_bf_shift[END_BITS+1:0]};
        else if (pot_acnt==3)  z_visible = |{zm_bf_shift[END_BITS+2:0]};
        else if (pot_acnt==4)  z_visible = |{zm_bf_shift[END_BITS+3:0]};
        else if (pot_acnt==5)  z_visible = |{zm_bf_shift[END_BITS+4:0]};
        else if (pot_acnt==6)  z_visible = |{zm_bf_shift[END_BITS+5:0]};
        else if (pot_acnt==7)  z_visible = |{zm_bf_shift[END_BITS+6:0]};
        else if (pot_acnt==8)  z_visible = |{zm_bf_shift[END_BITS+7:0]};
        else if (pot_acnt==9)  z_visible = |{zm_bf_shift[END_BITS+8:0]};
        else if (pot_acnt==10) z_visible = |{zm_bf_shift[END_BITS+9:0]};
        else if (pot_acnt==11) z_visible = |{zm_bf_shift[END_BITS+10:0]};
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
        else if (pot_acnt==30) z_visible = |{zm_bf_shift[END_BITS+28:0]};
        else  z_visible = 1'b0; //  z_visible = ((ze!=0) | |zm);
    end


    logic [7:0] pos_m_shift;
    assign pos_m_shift = ~m_shift + 1;
        // prod is visible if prior to m_shift, there is nothing in the bits between it and the end
        // if we are able to see the product after shifting
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
        else if (pos_m_shift==19) prod_visible = |{pm[END_BITS+17:0]}; // 20 bits of pm
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

    // determine if we're going to need to subtract 1
    fma16_sub_one #(VEC_SIZE, END_BITS) sub_one(.ps, .zs, .pe, .ze, .diff_pe_ze, .zm, .x_zero, .y_zero, .z_zero, .am, .sm, .pm, .subtract_1);
        
    // sum am and pm together into sm
    fma16_sum #(VEC_SIZE, END_BITS) sum(.pm, .am, .a_cnt(pot_acnt), .diff_sign(~z_zero & (zs ^ ps)), .no_product, .z_zero, .sm); // Calculates the sum of the product and z mantissas

    // determine how much to shift the mantissa in order to get the leading 1
    fma16_mshifter #(VEC_SIZE, END_BITS) mshifter(.sm, .a_cnt(pot_acnt), .diff_sign(~z_zero & (zs ^ ps)), .m_shift);

endmodule
