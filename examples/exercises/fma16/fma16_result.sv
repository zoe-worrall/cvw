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

    input  logic              which_nx,  // used to determine if subnormal
    input  logic              subtract_1, // used to adjust if we have to subtract a small number from a bigger one
    
    input  logic [4:0]        ze, // exponent of z
    input  logic [9:0]        zm, // mantissa of z
    input  logic [5:0]        pe, // exponent of the product

    input  logic [1:0]        roundmode, // the rounding mode of the system

    output logic [4:0]        me, // the exponent of the result
    output logic [VEC_SIZE:0] fin_mm, // the final result (takes rounding into account)
    output logic [15:0]       mult // the final result of the fma16 calculation
    );

    // Variables used for calculations
    logic [7:0]        pos_m_shift;
    logic [9:0]        mm_part;
    logic [VEC_SIZE:0] mm;
    logic [7:0]        sum_pe;
    logic [7:0]        dif_pe;


    ///////////////////////////////////////////////////////////////////////////////
    // Calculates Values for Result
    ///////////////////////////////////////////////////////////////////////////////

    // To help with faster calculations later, find the 2's complement of m_shift
    assign pos_m_shift = ~m_shift + 1'b1;

    // Calculates the mantissa and the 16-bit representation of the result if there is no rounding
    assign      mm = m_shift[7] ? (sm >>> (pos_m_shift)) : sm <<< (m_shift);
    assign      mm_part = ((pe != 16) & pe[5] & ze[4] & (pe[4:0] < ze)) ? '0 : fin_mm[(END_BITS+19):(END_BITS+10)];

    // Used to find either the sum or the difference of the product and z mantissas; we want to add a positive shift
    assign      sum_pe = { {2{pe[5]}}, pe} + pos_m_shift; // adding the additional conversions based off of however big of a shift we have
    assign      dif_pe = { {2{pe[5]}}, pe} - m_shift;



    ///////////////////////////////////////////////////////////////////////////////
    // Calculates Result Components
    ///////////////////////////////////////////////////////////////////////////////

    // Calculating the exponent and full value of the result; the output of the round mode is used to determine flags
    assign      me = (pe == {1'b0, ze} & (mm == 0)) ? 0 : ( m_shift == 8'b0) ? (pe[4:0]) : (m_shift[7]) ?  sum_pe[4:0] : dif_pe[4:0]; // 2's complement of m_cnt : (pe - m_shift);
    assign      mult = (which_nx == 0) ? {ms, ze-1'b1, zm-1'b1} : (subtract_1) ? {ms, me-1'b1, mm_part-1'b1} : {ms, me, mm_part};



    ///////////////////////////////////////////////////////////////////////////////
    // Calculates Rounding
    ///////////////////////////////////////////////////////////////////////////////

    // Calculates how to round the result
    fma16_round #(VEC_SIZE, END_BITS) rounder(.ms, .mm, .roundmode, .subtract_1, .fin_mm);

endmodule