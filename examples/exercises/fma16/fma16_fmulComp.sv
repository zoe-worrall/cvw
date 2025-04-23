/**
	A module that finds ms, me, and mm for the system

    Zoe Worrall - zworrall@g.hmc.edu
    E154 System on Chip
    February 12, 2025
*/

module fma16_mulcomponents  #(parameter VEC_SIZE, parameter END_BITS) (
        input  logic [7:0]  m_shift,
        input  logic [VEC_SIZE:0] sm, am, // pm,
        input  logic xs, ys, zs,
        input  logic subnormal_p,
        input  logic z_zero,
        input  logic [5:0] pe,
        input  logic [4:0] ze,
        // output logic       ms,
        output logic [4:0] me,
        output logic [9:0] mm_part,
        output logic [VEC_SIZE:0] mm
    );

    logic [7:0] pos_m_shift;
    assign pos_m_shift = (~m_shift + 1'b1);

    assign mm = m_shift[7] ? (sm >>> (pos_m_shift)) : (sm <<< (m_shift));
    assign mm_part = ((pe != 16) & pe[5] & ze[4] & (pe[4:0] < ze)) ? '0 : mm[(END_BITS+19):(END_BITS+10)];

    logic [7:0]  sum_pe, dif_pe;
    assign      sum_pe = { {2{pe[5]}}, pe} + pos_m_shift; // adding the additional conversions based off of however big of a shift we have
    assign      dif_pe = { {2{pe[5]}}, pe} - m_shift;

    always_comb begin
        if      (pe=={1'b0,ze} & (mm=='0)) me = '0;
        // else if (z_zero & subnormal_p)     me = pe;
        // else if (m_shift == 8'b0)          me = pe[4:0];
        else if (m_shift[7])               me = sum_pe[4:0];
        else                               me = dif_pe[4:0];
    end

    // assign ms = (pm > am) ? ((xs&~ys)|(~xs&ys)) : zs;

endmodule