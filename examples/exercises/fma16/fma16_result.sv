/**
	A module that calculates the result of an fma16 calculation.

    Zoe Worrall - zworrall@g.hmc.edu
    E154 System on Chip
    April 23, 2025
*/
module fma16_result #(parameter VEC_SIZE, parameter END_BITS) (
    input  logic [VEC_SIZE:0] sm,   // the sum of the product and z mantissas

    input  logic              ms,   // the sign of the result
    input  logic [7:0]        m_shift,  // an additional shift value to correctly set up the final result's me

    input  logic [1:0]        which_nx,  // used to determine if subnormal
    input  logic              subtract_1, // used to adjust if we have to subtract a small number from a bigger one
    input  logic              z_visible,
    input  logic              prod_visible,

    input  logic              big_z, shouldve_been_zero, // if z is so big that it dwarfs the product, and also a check to make sure that -pe != ze (wrong size for pe)
    
    input  logic              zs, // sign of z
    input  logic [4:0]        ze, // exponent of z
    input  logic [9:0]        zm, // mantissa of z
    input  logic [5:0]        pe, // exponent of the product

    input  logic [1:0]        roundmode, // the rounding mode of the system

    output logic [4:0]        me, // the exponent of the result
    output logic              nx,
    output logic [15:0]       mult // the final result of the fma16 calculation
    );

    // Variables used for calculations
    logic [7:0]        pos_m_shift;
    logic [9:0]        mm_rounded;
    logic [VEC_SIZE:0] mm;
    logic [7:0]        sum_pe;
    logic [7:0]        dif_pe;


    ///////////////////////////////////////////////////////////////////////////////
    // Calculates Values for Result
    ///////////////////////////////////////////////////////////////////////////////

    // To help with faster calculations later, find the 2's complement of m_shift
    assign pos_m_shift = ~m_shift + 1'b1;

    logic fix_z_vis;

    // Calculates what could potentially be the mantissa of the multiplicand:
    //
    //      *  currently in the process of reworking this section; this was initially the if statement
    //            indicated below, that caught that when specific cases applied, the answer was 0.
    //            Making this expand to broader regions, as I have a fear that this was case specific.
    //            
    // assign      mm_part = fin_mm[(END_BITS+19):(END_BITS+10)]; //((pe != 16) & pe[5] & ze[4] & (pe[4:0] < ze)) ? '0 : fin_mm[(END_BITS+19):(END_BITS+10)];

    // Used to find either the sum or the difference of the product and z mantissas; we want to add a positive shift
    assign      sum_pe = { {2{pe[5]}}, pe} + pos_m_shift; // adding the additional conversions based off of however big of a shift we have
    assign      dif_pe = { {2{pe[5]}}, pe} - m_shift;

    ///////////////////////////////////////////////////////////////////////////////
    // Calculates Result Components
    ///////////////////////////////////////////////////////////////////////////////

    // Calculating the exponent and full value of the result; the output of the round mode is used to determine flags
    // m_shift is 0 when:
        // 1. the product is zero
        // 2. the product is subnormal
        // 3. the product is normal, but am was 0
    always_comb begin
        if (pe == {1'b0, ze} & (mm == 0)) 
        begin
            me = 0;
            mm = '0;
            fix_z_vis = 0;
        end

        else if (pe == -6'd13)
        begin
            me = (ze!=5'd1) ? ze - (~|zm & subtract_1) : ze; //((subtract_1 | ms) & ~|zm); // ze - ((subtract_1 | ms) & ~|zm);  // fin_mm[(END_BITS+19):(END_BITS+10)]
            mm =  { {(VEC_SIZE-END_BITS-10-10){1'b0}}, (ze!=0), zm, {(END_BITS+10)'(1'b0)} };
            fix_z_vis = (ze==-5'd2) ? 1'b0 : 1'b1;
        end

        else if (subtract_1) begin
             // if which_nx is 0, the product is much greater than the z, meaning subnormal things ensue
                if (which_nx == 0) 
                begin
                    me = sum_pe - (~|sm[END_BITS+19:END_BITS]); // *not every time that z=1 do you need to subtract(ze!=5'd1) ? sum_pe - subtract_1 : sum_pe; // (~|(sm[19+END_BITS:0])); // subtract one bit if z was much smaller, sm is big
                    mm = (m_shift[7]) ?  (sm >>> (pos_m_shift)) : sm <<< (m_shift);
                    fix_z_vis = 0;
                    // mm_part = fin_mm; //[(END_BITS+19):(END_BITS+10)] - 1'b1;
                end

                else if (which_nx == 1) // this means that product was smaller than z
                begin
                    if (shouldve_been_zero) begin
                            me = sum_pe;
                            mm = sm;
                            fix_z_vis = 0;
                    end else begin
                        me = ze - 1'b1;
                        mm =  { {(VEC_SIZE-END_BITS-10-10){1'b0}}, (ze!=0), zm, {(END_BITS+10)'(1'b0)} };
                        fix_z_vis = 1;
                    end
                    // mm_part = zm;
                end

                else
                begin
                    if (big_z) begin
                        me = ze - 1'b1;
                        mm = { {(VEC_SIZE-END_BITS-10-10){1'b0}}, (ze!=0), zm, {(END_BITS+10)'(1'b0)} };
                        fix_z_vis = 1;
                    end
                    else begin
                        me = sum_pe;
                        mm = (m_shift[7]) ? (sm >>> (pos_m_shift)) : sm <<< (m_shift);
                        fix_z_vis = 0;
                    end
                    // mm_part = fin_mm; // [(END_BITS+19):(END_BITS+10)];
                end
        end

        else if (m_shift[7])
        begin
            if (shouldve_been_zero) begin
                me = ze + (~m_shift+1'b1+8'b00001111);
                mm = (m_shift[7]) ? (sm >>> (pos_m_shift)) : sm <<< (m_shift);
                fix_z_vis=0;
            end
            else begin
                me = sum_pe[4:0];
                mm = (m_shift[7]) ? (sm >>> (pos_m_shift)) : sm <<< (m_shift);
                fix_z_vis = 0;
            end
            // mm_part = fin_mm; // [(END_BITS+19):(END_BITS+10)];
        end

        else
        begin
            if (big_z) begin
                if (shouldve_been_zero) begin
                    me = ze;
                    mm = sm;
                    fix_z_vis = 0;
                end else begin
                    me = ze;
                    mm = { {(VEC_SIZE-END_BITS-10-10){1'b0}}, (ze!=0), zm, {(END_BITS+10)'(1'b0)} };
                    fix_z_vis = 1;
                end
            end
            else begin
                me = dif_pe[4:0]; // 2's complement of m_cnt : (pe - m_shift);
                mm = (m_shift[7]) ? (sm >>> (pos_m_shift)) : sm <<< (m_shift);
                fix_z_vis = 0;
            end
            // mm_part = fin_mm; //[(END_BITS+19):(END_BITS+10)];
        end
    end
    // if which_nx is 0, pm is greater than am
    // if m_shift == 0, that means that this was assigned post-humously, which means you don't need to subtract 1 from the exponent

    // m_shift == 0, pot_acnt = 29, pm = 400_000 -> don't subtract from exponent
    // m_shift == 0, pot_acnt = 29, pm = 600_000 -> subtract from exponent
    assign      mult = {ms, me, mm_rounded}; // (subtract_1) ? (which_nx==0) ? {ms, me-(~m_shift&~|(sm[19+END_BITS:0])), mm_part-1'b1} : (which_nx==1) ? {ms, ze-1'b1, zm-1'b1} : {ms, me, mm_part} : {ms, me, mm_part};


    ///////////////////////////////////////////////////////////////////////////////
    // Calculates Rounding
    ///////////////////////////////////////////////////////////////////////////////

    logic nx_bits;

    assign nx = nx_bits | prod_visible | (z_visible ^ fix_z_vis);

    // Calculates how to round the result
    // fma16_round #(VEC_SIZE, END_BITS) rounder(.ms, .mm, .roundmode, .subtract_1, .fin_mm);

    fma16_round #(VEC_SIZE, END_BITS) rounder(.ms, .mm, .roundmode, .subtract_1, .mm_rounded, .nx_bits);

endmodule