/**
	A module that calculates the result of an fma16 calculation.

    Zoe Worrall - zworrall@g.hmc.edu
    E154 System on Chip
    April 23, 2025
*/
module fma16_subnormal_fix #(parameter VEC_SIZE, parameter END_BITS) (
    input  logic [VEC_SIZE:0] sm, fin_mm,  // the sum of the product and z mantissas

    input  logic              ms,   // the sign of the result
    input  logic [7:0]        m_shift,  // an additional shift value to correctly set up the final result's me

    input  logic [1:0]        which_nx,  // used to determine if subnormal
    input  logic              subtract_1, // used to adjust if we have to subtract a small number from a bigger one
    input  logic              z_visible,
    
    input  logic [4:0]        ze, // exponent of z
    input  logic [9:0]        zm, // mantissa of z
    input  logic [5:0]        pe, // exponent of the product

    output logic [4:0]        me, // the exponent of the result
    output logic [9:0]       mm_part // the final result of the fma16 calculation
    );

    // Variables used for calculations
    logic [7:0]        pos_m_shift;
    logic [VEC_SIZE:0] mm;

    logic [7:0]        sum_pe;
    logic [7:0]        dif_pe;
    // Used to find either the sum or the difference of the product and z mantissas; we want to add a positive shift
    assign      sum_pe = { {2{pe[5]}}, pe} + pos_m_shift; // adding the additional conversions based off of however big of a shift we have
    assign      dif_pe = { {2{pe[5]}}, pe} - m_shift;

    // To help with faster calculations later, find the 2's complement of m_shift
    assign pos_m_shift = ~m_shift + 1'b1;

    // Calculating the exponent and full value of the result; the output of the round mode is used to determine flags
    // m_shift is 0 when:
        // 1. the product is zero
        // 2. the product is subnormal
        // 3. the product is normal, but am was 0
    

    // Calculating the exponent and full value of the result; the output of the round mode is used to determine flags
    // m_shift is 0 when:
        // 1. the product is zero
        // 2. the product is subnormal
        // 3. the product is normal, but am was 0
    always_comb begin
        if (pe == {1'b0, ze} & (mm == 0)) 
        begin
            me = 0;
            mm_part = 0;
        end

        else if (pe == -6'd13)
        begin

            me = ze - ((subtract_1 | ms) & ~|zm); // ze - ((subtract_1 | ms) & ~|zm);  // fin_mm[(END_BITS+19):(END_BITS+10)]
            if (ze==5'b11110)
                if (~|zm) begin
                    if (subtract_1^ms)
                            if (ms) mm_part = zm-1'b1;
                            else    mm_part = zm-1'b1;
                    else         mm_part = zm-(subtract_1);
                end
                else begin
                    if (subtract_1 | ms)   mm_part = zm-(ms^subtract_1);
                    else                   mm_part = zm-(subtract_1);
                end
            else
                if (~|zm) begin
                    if (subtract_1^ms)
                            if (ms) mm_part = zm-1'b1;
                            else    mm_part = zm-1'b1;
                    else         mm_part = zm-(subtract_1);
                end
                else begin
                    if (subtract_1 | ms)   mm_part = zm-(ms^subtract_1);
                    else                   mm_part = zm-(subtract_1);
                end
        end

        else if ( m_shift==8'b0 ) 
        begin

            if (subtract_1) // something subnormal happened somewhere
            begin
                // some rounding things belong here in the future (this it truncation)
                if (which_nx == 0) 
                begin
                    me = sum_pe - (~m_shift  & ~|(sm[19+END_BITS:0])); // subtract one bit if z was much smaller, sm is big
                    mm_part = fin_mm[(END_BITS+19):(END_BITS+10)] - 1'b1;
                end

                else if (which_nx == 1)
                begin
                    me = ze - 1'b1;
                    mm_part = zm;
                end

                else
                begin
                    me = sum_pe;
                    mm_part = fin_mm[(END_BITS+19):(END_BITS+10)];
                end
            end

            else // we didn't subtract shit, so we need to check that 
            begin
                me = sum_pe;
                mm_part = fin_mm[(END_BITS+19):(END_BITS+10)];
            end

        end

        else if (m_shift[7])
        begin
            me = sum_pe[4:0];
            mm_part = fin_mm[(END_BITS+19):(END_BITS+10)];
        end

        else
        begin
            me = dif_pe[4:0]; // 2's complement of m_cnt : (pe - m_shift);
            mm_part = fin_mm[(END_BITS+19):(END_BITS+10)];
        end
    end

endmodule