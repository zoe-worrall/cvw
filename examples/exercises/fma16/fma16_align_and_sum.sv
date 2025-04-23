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

    // Exponents of product, x, y, and z
    input  logic [5:0]   pe,  // product exponent
    input  logic [4:0]   xe, ye, ze, // exponents of x, y, z

    // Mantissas of product and z
    input  logic [9:0]   zm,  // z mantissa
    input  logic [21:0]  mid_pm, // product mantissa

    // Zero flags
    input  logic         x_zero, y_zero, z_zero,

    output logic [5:0]   a_cnt,  // exponent difference between pe and ze
    output logic         no_product, // whether the product is zero/subnormal
    
    output logic [VEC_SIZE:0] am, // aligned zm for sum
    output logic [VEC_SIZE:0] pm, // aligned pm
    output logic [VEC_SIZE:0] sm, // the sum of the product and z mantissas

    output logic [7:0]   m_shift, // additional adjustment for adjusting decimal

    output logic [5:0]  diff_count, // the difference between ze and pe exponents
    output logic        which_nx,   // used to determine if subnormal
    output logic        subtract_1, ms // used to adjust if z or product is subnormal and negative
    );

    always_comb begin
        // assigning a_cnt (relative difference between pe and ze)
        if ((pe!=16) & (pe[5] & ze[4] & (pe[4:0] < ze)))
            if ((pe - ze) == 6'b110000)  a_cnt = (pe - ze);
            else                         a_cnt = (pe - ze - 32);
        else                             a_cnt = (pe - ze);

        // assigning diff_count (overall difference between pe and ze)
        if (({1'b0,pe}>{2'b00,ze}))      diff_count = ({1'b0,pe} - {2'b00,ze});
        else                             diff_count = ({2'b00,ze} - {1'b0,pe});

        // assigning which_nx (used to determine if subnormal)
        if ((zs ^ ps) & (diff_count > 30) & (zm == 0))   which_nx = 0;
        else                                             which_nx = 1;
        
        // assigning subtract_1 (used to adjust if z or product is subnormal and negative)
        if (ps ^ zs)
            if (no_product) subtract_1 = 0;
            else            subtract_1 = (am=='0);
        else                subtract_1 = 0;

        // assigning no_product (used to determine if product is zero/subnormal)
        no_product = ((~x_zero) & (xe==0)) | ((~y_zero) & (ye==0)) | (a_cnt[5]&(~z_zero));
    end

    assign am = (a_cnt[5]) ? { {VEC_SIZE{1'b0}}, 1'b1, zm, {(END_BITS+10)'(1'b0)} } << (~a_cnt + 1'b1) : ( { {VEC_SIZE{1'b0}}, 1'b1, zm, {(END_BITS+10)'(1'b0)} } >> a_cnt);

    assign pm = (x_zero | y_zero) ? 0 : { {VEC_SIZE{1'b0}}, mid_pm, {(END_BITS)'(1'b0)}};

    assign ms = (pm > am) ? ((xs & ~ys) | (~xs & ys)) : zs; //(pe > ze) ? (pe[4:0] == ze) ? () ? ((xs & ~ys) | (~xs & ys)) : zs : ((~xs & ys) | (xs & ~ys)) : zs;//~(xs ^ ys) : zs;

    // calculate sm and m_shift
    fma16_align_add #(VEC_SIZE, END_BITS) adder(.pm, .am, .a_cnt, .ps, .zs, .xe, .ye, .z_zero, .no_product, .m_shift, .sm);


endmodule