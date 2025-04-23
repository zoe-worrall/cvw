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

    output logic [5:0]   a_cnt,       // exponent difference between pe and ze
    output logic         no_product,  // whether the product is zero/subnormal
    
    output logic [VEC_SIZE:0] sm, // the sum of the product and z mantissas

    output logic [7:0]   m_shift, // additional adjustment for adjusting decimal

    output logic [5:0]  diff_count, // the difference between ze and pe exponents
    output logic        which_nx,   // used to determine if subnormal
    output logic        subtract_1, ms // used to adjust if z or product is subnormal and negative
    );

    logic [VEC_SIZE:0] am; // aligned zm for sum
    logic [VEC_SIZE:0] pm; // aligned pm for sum


    ///////////////////////////////////////////////////////////////////////////////
    // Adjustment Variable Calculations
    ///////////////////////////////////////////////////////////////////////////////
    
    always_comb begin
        // Assigning a_cnt (relative difference between pe and ze)
        // 
        //     - if pe is smaller than ze and both are negative, then a_cnt needs to 
        //          subtract 32 from its answer due to a wrapping error
        //     - otherwise, a_cnt is just the difference between pe and ze
        // 
        if ((pe!=16) & (pe[5] & ze[4] & (pe[4:0] < ze)))
            if ((pe - ze) == 6'b110000)  a_cnt = (pe - ze);
            else                         a_cnt = (pe - ze - 32);
        else                             a_cnt = (pe - ze);

        // Assigning diff_count (overall difference between pe and ze)
        //
        //     - As opposed to a_cnt, diff_count is a signed value that
        //         tells the exact difference between pe and ze
        //
        if (({1'b0,pe}>{2'b00,ze}))      diff_count = ({1'b0,pe} - {2'b00,ze});
        else                             diff_count = ({2'b00,ze} - {1'b0,pe});

        // Assigning which_nx
        //    This is used to determine what should be done if either z or the
        //      product is too small (only applies if negative)
        //
        //    If zs and ps are different, and their difference is wide while
        //       z's value is too small, small adjustments may need to be
        //       made in post
        //
        if ((zs ^ ps) & (diff_count > 30) & (zm == 0))   which_nx = 0;
        else                                             which_nx = 1;
        
        // Assigning subtract_1
        //    This is used to determine if 1'b1 should be subtracted from sm
        //
        if (ps ^ zs)
            if (no_product) subtract_1 = 0;
            else            subtract_1 = (am=='0);
        else                subtract_1 = 0;

        // Assigning no_product (used to determine if product is zero/subnormal)
        //      - if either x or y is zero, then the product is zero
        //
        no_product = ((~x_zero) & (xe==0)) | ((~y_zero) & (ye==0)) | (a_cnt[5]&(~z_zero));
    end

    assign ms = (pm > am) ? ((xs & ~ys) | (~xs & ys)) : zs; //(pe > ze) ? (pe[4:0] == ze) ? () ? ((xs & ~ys) | (~xs & ys)) : zs : ((~xs & ys) | (xs & ~ys)) : zs;//~(xs ^ ys) : zs;

    ///////////////////////////////////////////////////////////////////////////////
    // Addition
    ///////////////////////////////////////////////////////////////////////////////
   
    assign am = (a_cnt[5]) ? { {VEC_SIZE{1'b0}}, 1'b1, zm, {(END_BITS+10)'(1'b0)} } << (~a_cnt + 1'b1) : ( { {VEC_SIZE{1'b0}}, 1'b1, zm, {(END_BITS+10)'(1'b0)} } >> a_cnt);
    assign pm = (x_zero | y_zero) ? 0 : { {VEC_SIZE{1'b0}}, mid_pm, {(END_BITS)'(1'b0)}};

    // Calculates the proper shifting (m_shift) and the sum of pm and am
    fma16_mshifter #(VEC_SIZE, END_BITS) mshifter(.pm, .am, .z_zero, .a_cnt, .no_product, .diff_sign(~z_zero & (zs ^ ps)), .m_shift, .sm);


endmodule