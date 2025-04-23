/**
	A module that calculates the exponent and mantissa of an fma16 calculation

    Zoe Worrall - zworrall@g.hmc.edu
    E154 System on Chip
    February 12, 2025
*/

// center is defined at 73

module fma16_result #(parameter VEC_SIZE, parameter END_BITS) (
    input  logic [VEC_SIZE:0] sm,

    input  logic              ms,
    input  logic [7:0]        m_shift,

    input  logic              which_nx,
    input  logic              subtract_1,
    
    input  logic [4:0]        ze,
    input  logic [5:0]        pe,
    input  logic [9:0]        zm,

    output logic [4:0]        me,
    output logic [VEC_SIZE:0] mm,
    output logic [15:0]       mult
    );

    logic [7:0] pos_m_shift;
    logic [9:0] mm_part;
    logic [7:0]     sum_pe;
    logic [7:0]     dif_pe;
    assign pos_m_shift = ~m_shift + 1'b1;

    assign      mm = m_shift[7] ? (sm >>> (pos_m_shift)) : sm <<< (m_shift);
    assign      mm_part = ((pe != 16) & pe[5] & ze[4] & (pe[4:0] < ze)) ? '0 : mm[(END_BITS+19):(END_BITS+10)];

    assign      sum_pe = { {2{pe[5]}}, pe} + pos_m_shift; // adding the additional conversions based off of however big of a shift we have
    assign      dif_pe = { {2{pe[5]}}, pe} - m_shift;

    assign      me = (pe == {1'b0, ze} & (mm == 0)) ? 0 : ( m_shift == 8'b0) ? (pe[4:0]) : (m_shift[7]) ?  sum_pe[4:0] : dif_pe[4:0]; // 2's complement of m_cnt : (pe - m_shift);
    
    assign      mult = (which_nx == 0) ? {ms, ze-1'b1, zm-1'b1} : (subtract_1) ? {ms, me-1'b1, mm_part-1'b1} : {ms, me, mm_part};


endmodule