/**
	A module that finds aligns am and pm, and computes 
    the difference between exponents and the state of the product's
    exponent (no_product) for future use

    Zoe Worrall - zworrall@g.hmc.edu
    E154 System on Chip
    April 22, 2025
*/

module fma16_align_and_sum  #(parameter VEC_SIZE, parameter END_BITS) (
    input  logic         ps,
    input  logic         xs, ys, zs, // signs of product and z
    input  logic         negp,

    input  logic [6:0]   pe, // product exponent
    input  logic [4:0]   ze, // exponents of x, y, z

    input  logic [9:0]   zm,         // z mantissa
    input  logic [21:0]  mid_pm,     // product mantissa

    input  logic         x_zero, y_zero, z_zero, // Zero Flags

    output logic         z_invisible, product_invisible, inverse_addend,
    
    output logic              ss,
    output logic [6:0]        se,
    output logic [VEC_SIZE-1:0] sm, // the sum of the product and z mantissas
    output logic [7:0]   m_shift // additional adjustment for adjusting decimal
    );

    logic [VEC_SIZE-1:0] pot_am, am; // aligned zm for sum; pot_am is meant to exist in case am is negative
    logic [21:0] pm; // aligned pm for sum
    logic no_z;

    logic [6:0] a_cnt;
    assign a_cnt = pe - { 2'b0, ze } + 13; 

    logic [VEC_SIZE-1:0] zm_bf_shift;
    assign zm_bf_shift = { {(VEC_SIZE-END_BITS-10-10){1'b0}}, (ze!=0), zm, {(END_BITS+10)'(1'b0)} };

    // if a_cnt is positive, and if its bigger than WIDTH, that means that pe was too big compared to ze (hence becomes invisible**)
    // if a_cnt is negative, that means that ze was big enough to cancel out pe (becomes ~~invisible~~)
    always_comb begin
        if ($signed(a_cnt)>$signed(VEC_SIZE)) z_invisible = 1'b1;
        else                                  z_invisible = 1'b0;

        if (x_zero|y_zero)          product_invisible = 0;
        else if (a_cnt[6] & z_zero) product_invisible = 0;
        else                        product_invisible = 1;
    end

    ///////////////////////////////////////////////////////////////////////////////
    // Addition
    ///////////////////////////////////////////////////////////////////////////////
    
    logic [VEC_SIZE-1:0] zm_shifted;
    
    assign zm_shifted = zm_bf_shift >> a_cnt;

    assign pot_am = (z_invisible) ? '0 : (product_invisible) ? zm_bf_shift : zm_shifted;
    assign am = (inverse_addend) ? ~pot_am : pot_am;

    // According to me snooping around Prof. Harris' and other people's code, we should actually have some
    // bit that stays around and lets us know that we've "left something behind", i.e. that when rounding,
    // some value that disappeared needs to be moved back.
    assign dont_leave_me = (z_invisible) ? (~z_zero) : ((product_invisible) ? (~(x_zero|y_zero)) : (|am[9:0]));

    assign pm = (product_invisible) ? '0 : mid_pm;


    fma16_sum #(VEC_SIZE, END_BITS) sum(.zs, .negp, .ps, .ze, .pe, .dont_leave_me, .product_invisible, .mid_pm, .am, .a_cnt, .ss, .se, .sm);

    fma16_mshifter #(VEC_SIZE, END_BITS) mshifter(.sm, .m_shift);

    // // determine if we're going to need to subtract 1
    // fma16_sub_one #(VEC_SIZE, END_BITS) sub_one(.ps, .zs, .pe, .ze, .diff_pe_ze, .zm, .x_zero, .y_zero, .z_zero, .am, .sm, .pm, .subtract_1);
        

endmodule