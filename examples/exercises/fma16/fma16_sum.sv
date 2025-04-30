/**
	A module that returns an mshift value that is used to further adjust
    a given sum with a given a_cnt value.

    Zoe Worrall - zworrall@g.hmc.edu
    E154 System on Chip
    April 22, 2025
*/

module fma16_sum #(parameter VEC_SIZE, parameter END_BITS) (
        input  logic [VEC_SIZE:0]   pm, // centered product mantissa
        input  logic [VEC_SIZE:0]   am, // centered added mantissa
        input  logic [6:0]          a_cnt, // exponent difference between pe and ze for adjusting

        input logic                 diff_sign, // sign of the difference between the product and z mantissas
        input logic                 no_product, // whether the product is zero
        input logic                 z_zero, // whether z is zero

        input  logic                big_z,

        output logic [VEC_SIZE:0]   sm // the sum of the product and z mantissas
    );

    // Internal Logic
    logic [VEC_SIZE:0] diff_sum, pos_sum; // the difference between the product and z mantissas
    logic [6:0] a_cnt_pos; // the positive value of a_cnt

    assign a_cnt_pos = (~a_cnt + 1'b1); // the inverted value of a_cnt (used if a_cnt is negative)
    assign diff_sum = (pm > am) ? (pm - am) : (am - pm); // the difference between am and pm
    assign pos_sum = (am + pm); // the sum of am and pm
  
    always_comb begin

        // if the z is bigger than the product, then we need to either add or subtract values
        if (big_z)  
        begin
            if (~diff_sign) begin
                sm = (z_zero) ? pm : pos_sum;
            end else begin
                sm = (z_zero) ? pm : diff_sum;
            end
        end 
        
        // Otherwise, separate into add and subtract
        else begin
            if (diff_sign)
                if (a_cnt[6] & (a_cnt != -6'd2) & (a_cnt != -6'd1)) 
                    sm = diff_sum;
                else  
                    sm = (z_zero) ? (pm) : diff_sum;
            else sm = (z_zero) ? (no_product) ? diff_sum : pm : pos_sum;
        end

    end

endmodule



