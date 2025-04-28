/**
	A module that calculates the result of an fma16 calculation.

    Zoe Worrall - zworrall@g.hmc.edu
    E154 System on Chip
    April 23, 2025
*/
module fma16_result #(parameter VEC_SIZE, parameter END_BITS) (
    input  logic [VEC_SIZE-1:0] sm,   // the sum of the product and z mantissas
    input  logic              se,
    input  logic [7:0]        m_shift,
    input  logic              ms,   // the sign of the result
    input  logic              product_invisible, z_invisible,


    output logic              nx,
    output logic [4:0]        me, // the exponent of the result
    output logic [15:0]       mult // the final result of the fma16 calculation
    );

    // Variables used for calculations
    logic [7:0]        pos_m_shift;
    logic [9:0]        mm_rounded;
    logic [VEC_SIZE-1:0] mm;
    logic [7:0]        sum_pe;
    logic [7:0]        dif_pe;
    logic nx_bits;

    assign pos_m_shift = ~m_shift + 1;

    ///////////////////////////////////////////////////////////////////////////////
    // Calculates Values for Result
    ///////////////////////////////////////////////////////////////////////////////
    assign me = se + m_shift;
    assign mm = (m_shift[7]) ? sm << pos_m_shift : sm >> pos_m_shift;

    fma16_round #(VEC_SIZE, END_BITS) rounder(.ms, .mm, .mm_rounded, .nx_bits);

    assign      mult = {ms, me, mm_rounded}; 

    ///////////////////////////////////////////////////////////////////////////////
    // Calculates Rounding
    ///////////////////////////////////////////////////////////////////////////////


    assign nx = product_invisible | z_invisible; // | nx_bits

    // Calculates how to round the result
    // fma16_round #(VEC_SIZE, END_BITS) rounder(.ms, .mm, .roundmode, .subtract_1, .fin_mm);

endmodule