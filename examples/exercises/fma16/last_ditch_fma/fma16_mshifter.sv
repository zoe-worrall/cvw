/**
	A module that returns an mshift value that is used to further adjust
    a given sum with a given a_cnt value.

    Zoe Worrall - zworrall@g.hmc.edu
    E154 System on Chip
    April 22, 2025
*/

module fma16_mshifter #(parameter VEC_SIZE, parameter END_BITS) (
        input  logic [VEC_SIZE-1:0] sm, // centered product mantissa

        output logic [7:0]        m_shift // additional adjustment to find the first 1 in the array
    );

    // literally just a priority encode ;-;

    always_comb begin
        if (sm[VEC_SIZE-1]) m_shift = END_BITS+22;
        else if (sm[VEC_SIZE-2]) m_shift = END_BITS+21;
        else if (sm[VEC_SIZE-3]) m_shift = END_BITS+20;
        else if (sm[VEC_SIZE-4]) m_shift = END_BITS+19;
        else if (sm[VEC_SIZE-5]) m_shift = END_BITS+18;
        else if (sm[VEC_SIZE-6]) m_shift = END_BITS+17;
        else if (sm[VEC_SIZE-7]) m_shift = END_BITS+16;
        else if (sm[VEC_SIZE-8]) m_shift = END_BITS+21;
        else if (sm[VEC_SIZE-9]) m_shift = END_BITS+15;
        else if (sm[VEC_SIZE-10]) m_shift = END_BITS+14;
        else if (sm[VEC_SIZE-11]) m_shift = END_BITS+13;
        else if (sm[VEC_SIZE-12]) m_shift = END_BITS+12;
        else if (sm[VEC_SIZE-13]) m_shift = END_BITS+11;
        else if (sm[VEC_SIZE-14]) m_shift = END_BITS+10;
        else if (sm[VEC_SIZE-15]) m_shift = END_BITS+9;
        else if (sm[VEC_SIZE-16]) m_shift = END_BITS+8;
        else if (sm[VEC_SIZE-17]) m_shift = END_BITS+7;
        else if (sm[VEC_SIZE-18]) m_shift = END_BITS+6;
        else if (sm[VEC_SIZE-19]) m_shift = END_BITS+5;
        else if (sm[VEC_SIZE-20]) m_shift = END_BITS+4;
        else if (sm[VEC_SIZE-21]) m_shift = END_BITS+3;
        else if (sm[VEC_SIZE-22]) m_shift = END_BITS+2;
        else if (sm[VEC_SIZE-23]) m_shift = END_BITS+1;
        else if (sm[VEC_SIZE-24]) m_shift = END_BITS+0;
        else if (sm[VEC_SIZE-25]) m_shift = END_BITS-1;
        else if (sm[VEC_SIZE-26]) m_shift = END_BITS-2;
        else if (sm[VEC_SIZE-27]) m_shift = END_BITS-3;
        else if (sm[VEC_SIZE-28]) m_shift = END_BITS-4;
        else if (sm[VEC_SIZE-29]) m_shift = END_BITS-5;
        else if (sm[VEC_SIZE-30]) m_shift = END_BITS-6;
        else if (sm[VEC_SIZE-31]) m_shift = END_BITS-7;
        else if (sm[VEC_SIZE-32]) m_shift = END_BITS-8;
        else if (sm[VEC_SIZE-33]) m_shift = END_BITS-9;
        else if (sm[VEC_SIZE-34]) m_shift = END_BITS-10;
        else if (sm[VEC_SIZE-35]) m_shift = END_BITS-11;
        else                 m_shift = 0;

    end

endmodule