/**
	A module that properly finds the mcount for alignment

    Zoe Worrall - zworrall@g.hmc.edu
    E154 System on Chip
    February 12, 2025
*/

// center is defined at 73

module fma16_align_add #(parameter VEC_SIZE, parameter END_BITS) (
    input  logic [VEC_SIZE:0] pm, am,
    input  logic [5:0]   a_cnt,
    input  logic [4:0]   xe, ye,
    input  logic         ps, zs, z_zero, no_product,
    output logic [7:0]   m_shift,
    output logic [VEC_SIZE:0] sm
    );

    logic diff_sign;
    logic [5:0] a_cnt_pos;

    assign diff_sign  = ~z_zero & (zs ^ ps);
    assign a_cnt_pos  = ~a_cnt + 1'b1;
    
    fma16_mshifter #(VEC_SIZE, END_BITS) mshifter(.pm, .am, .z_zero, .a_cnt, .no_product, .diff_sign, .m_shift, .sm);

endmodule