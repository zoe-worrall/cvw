/**
	A module that finds A_count and shifts products

    Zoe Worrall - zworrall@g.hmc.edu
    E154 System on Chip
    February 12, 2025
*/

module fma16_shift  #(parameter VEC_SIZE, parameter END_BITS) (
    input  logic [5:0]   pe,
    input  logic [4:0]   xe, ye, ze,
    input  logic [9:0]   zm,
    input  logic [21:0]  mid_pm,
    input  logic         x_zero, y_zero, z_zero,
    output logic [5:0]   a_cnt,
    output logic         no_product,
    output logic [VEC_SIZE:0] am, pm
    );

    // to check for problems
    logic [6:0] error;
    assign error = ((pe != 16) & pe[5] & ze[4] & (pe[4:0] < ze)) ? ((pe - ze) == 6'b110000) ? (pe - ze) : (pe - ze - 32) : (pe - ze);

    assign a_cnt = ((pe != 16) & pe[5] & ze[4] & (pe[4:0] < ze)) ? ((pe - ze) == 6'b110000) ? (pe - ze) : (pe - ze - 32) : (pe - ze); //  - 6'b001111 - 6'b001111;   // maximum is 32
    
    assign no_product = ((xe==0) | (ye==0) | (a_cnt[5]&(~z_zero))) ? 1'b1 : 1'b0;
   
    assign am = (a_cnt[5]) ? { {VEC_SIZE{1'b0}}, 1'b1, zm, {(END_BITS+10)'(1'b0)} } << (~a_cnt + 1'b1) : ( { {VEC_SIZE{1'b0}}, 1'b1, zm, {(END_BITS+10)'(1'b0)} } >> a_cnt);

    assign pm = (x_zero | y_zero) ? 0 : { {VEC_SIZE{1'b0}}, mid_pm, {(END_BITS)'(1'b0)}};

endmodule