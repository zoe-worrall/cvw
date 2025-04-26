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
    
    output logic [VEC_SIZE:0] sm, // the sum of the product and z mantissas

    output logic [7:0]   m_shift, // additional adjustment for adjusting decimal

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

    assign z_visible = am[END_BITS+19:0]!=0; 

    logic extra;

    ///////////////////////////////////////////////////////////////////////////////
    // Adjustment Variable Calculations
    ///////////////////////////////////////////////////////////////////////////////
    
    always_comb begin
        // Assigning a_cnt (relative difference between pe and ze)
        // 
        //     - if pe is smaller than ze and both are negative, then a_cnt needs to 
        //          subtract 32 from its answer due to a wrapping error
        //     - otherwise, a_cnt is just the difference between pe and ze
        //   1_11110
        if ((pe==-6'd13) & (ze < -5'd1) & ($signed(diff_pe_ze)>$signed(20)))
            if (diff_pe_ze == 6'b110000)  a_cnt = diff_pe_ze;
            else                          a_cnt = diff_pe_ze; //{ ~diff_pe_ze[5], diff_pe_ze[4:0] };
        else                              a_cnt = diff_pe_ze;

        // Assigning diff_count (overall difference between pe and ze)
        //
        //     - As opposed to a_cnt, diff_count is a signed value that
        //         tells the exact difference between pe and ze
        //
        if (({1'b0,pe}>{2'b00,ze}))  {extra, diff_count} = ({1'b0,pe} - {2'b00,ze});
        else                         {extra, diff_count} = ({2'b00,ze} - {1'b0,pe});

        // Assigning which_nx (which inexact)
        //    This is used to determine what should be done if either z or the
        //      product is too small (only applies if negative)
        //
        //    If zs and ps are different, and their difference is wide while
        //       z's value is too small, small adjustments may need to be
        //       made in post
        //
        //     If z is the smaller of the two, which_nx is 0
        if      ((pe > ze) & (~z_zero))  which_nx = 0;
        else if ((pm!='0)  & (~z_zero))  which_nx = 1;
        else                             which_nx = 3;
        
        // Assigning subtract_1
        //    This is used to determine if 1'b1 should be subtracted from sm
        //
        if (ps ^ zs)
        begin
            // between -24 and 24, don't subtract anything
            if ((($signed(diff_pe_ze) > -7'd24) & ($signed(diff_pe_ze) < 7'd24))) 
                subtract_1 = 0;

            // subtract 1 if: 
                // z is small enough and the product is big (i.e. am is 0, and z is not zero or exponent of 1 (smallest))
                // product is small enough (but not zero) and z is big enough
            else
                if (  (am[VEC_SIZE:END_BITS]=='0) & (~(z_zero)) ) begin
                    if (pe==-6'd13)
                        subtract_1 = (ze==5'd1) ? |zm : 1'b1;
                    else
                        subtract_1 = 1'b1;

                end else if (pm=='0 & (~(x_zero|y_zero))) begin
                    subtract_1 = 1'b1;

                end else begin
                    subtract_1 = 1'b0;
                end

        end
        else    begin  subtract_1 = 0; end
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
    assign zm_bf_shift = { {(VEC_SIZE-END_BITS-10-10){1'b0}}, (ze!=0), zm, {(END_BITS+10)'(1'b0)} };

    assign am = (pot_acnt[6]) ? zm_bf_shift << ( ~pot_acnt + 1'b1  ) : zm_bf_shift >> pot_acnt;
    assign pm = (x_zero | y_zero) ? 0 : { {(VEC_SIZE-21-END_BITS){1'b0}}, mid_pm, {(END_BITS)'(1'b0)}};

    // Calculates the proper shifting (m_shift) and the sum of pm and am
    fma16_mshifter #(VEC_SIZE, END_BITS) mshifter(.pm, .am, .z_zero, .a_cnt(pot_acnt), .no_product, .diff_sign(~z_zero & (zs ^ ps)), .m_shift, .sm);


endmodule