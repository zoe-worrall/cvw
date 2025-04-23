/**
	A module that returns an mshift value that is used to further adjust
    a given sum with a given a_cnt value.

    Zoe Worrall - zworrall@g.hmc.edu
    E154 System on Chip
    April 22, 2025
*/

module fma16_mshifter #(parameter VEC_SIZE, parameter END_BITS) (
        input  logic [VEC_SIZE:0] pm, // centered product mantissa
        input  logic [VEC_SIZE:0] am, // centered added mantissa
        input  logic [5:0]        a_cnt, // exponent difference between pe and ze for adjusting

        input  logic              no_product, // whether the product is zero/subnormal
        input  logic              diff_sign,  // whether the product and z have different signs
        input  logic              z_zero, // whether z is zero
        
        output logic [7:0]        m_shift, // additional adjustment to find the first 1 in the array
        output logic [VEC_SIZE:0] sm // the sum of the product and z mantissas
    );

    logic [VEC_SIZE:0] diff_sum; // the difference between the product and z mantissas
    logic [5:0] a_cnt_pos; // the positive value of a_cnt
    assign a_cnt_pos = (~a_cnt + 1'b1); // the inverted value of a_cnt (used if a_cnt is negative)

    always_comb begin
        m_shift = 8'bxxxxxxx; // should be invalid if not set in this combination block
        diff_sum = (pm > am) ? (pm - am) : (am - pm);

        // 
        // If the product and the addend are opposite, then the 1 value being searched for is
        //    either within the first three bits of the centered added plot, or it is in the
        //    trailing 20 bits.
        //
        //    {VEC_SIZE}'0  |   (21 bits of pm)  |  {END_BITS}'0  }
        //     (10 bits of am)  
        if (diff_sign) begin // if z is negative
            // if a_cnt is too big, then we can see am - pe to diff_sum sm, before computing its actual location. If a_cnt is big enough, we don't need to worry about the "middle zone"
            if (a_cnt[5] & (a_cnt != -6'd2) & (a_cnt != -6'd1)) begin // a_cnt = -3 to all other negatives
                if      (diff_sum[END_BITS + 20 + a_cnt_pos + 1'b1])       m_shift = { {2{1'b1}}, a_cnt - 1'b1 };
                else if (diff_sum[END_BITS + 20 + a_cnt_pos + 0])          m_shift = { {2{1'b1}}, a_cnt };
                else if (diff_sum[END_BITS + 20 + a_cnt_pos - 1'b1])       m_shift = { {2{1'b1}}, (a_cnt + 1'b1) };
                else if (diff_sum[END_BITS + 20 + a_cnt_pos - 6'b000010])  m_shift = { {2{1'b1}}, (a_cnt + 6'b000010) };

                sm = diff_sum;
            end else begin  // a_cnt is -2 or above, we need to diff_sum that 74 or 73 doesn't have any bits
                if      (diff_sum[END_BITS + 22])                  m_shift = -2;
                else if (diff_sum[END_BITS + 21])                  m_shift = -1;
                else if (diff_sum[END_BITS + 20])                  m_shift =  0;
                else if (diff_sum[END_BITS + 19])                  m_shift =  1;
                else if (diff_sum[END_BITS + 18])                  m_shift =  2;
                else if (diff_sum[END_BITS + 17])                  m_shift =  3;
                else if (diff_sum[END_BITS + 16])                  m_shift =  4;
                else if (diff_sum[END_BITS + 15])                  m_shift =  5;
                else if (diff_sum[END_BITS + 14])                  m_shift =  6;
                else if (diff_sum[END_BITS + 13])                  m_shift =  7;
                else if (diff_sum[END_BITS + 12])                  m_shift =  8;
                else if (diff_sum[END_BITS + 11])                  m_shift =  9;
                else if (diff_sum[END_BITS + 10])                  m_shift = 10;
                else if (diff_sum[END_BITS +  9])                  m_shift = 11;
                else if (diff_sum[END_BITS +  8])                  m_shift = 12;
                else if (diff_sum[END_BITS +  7])                  m_shift = 13;
                else if (diff_sum[END_BITS +  6])                  m_shift = 14;
                else if (diff_sum[END_BITS +  5])                  m_shift = 15;
                else if (diff_sum[END_BITS +  4])                  m_shift = 16;
                else if (diff_sum[END_BITS +  3])                  m_shift = 18;
                else if (diff_sum[END_BITS +  2])                  m_shift = 19;
                else if (diff_sum[END_BITS +  1])                  m_shift = 20;
                else if (diff_sum[END_BITS +  0])                  m_shift = 21;
                else if (diff_sum[END_BITS -  1])                  m_shift = 22;
                else if (diff_sum[END_BITS -  2])                  m_shift = 23;
                else                                            m_shift = 24;

                sm = (z_zero) ? (pm) : diff_sum;
            end
        end else begin          // if z is positive
            sm = (z_zero) ? (no_product) ? (pm - am) : pm : (am + pm);
            if (a_cnt[5]) begin
                if (sm==0) m_shift = 0;
                else if (sm[END_BITS + 20 + a_cnt_pos + 1])    m_shift = (a_cnt == 6'b100000) ?  8'b1111_1111 : { {2{1'b1}}, (a_cnt - 1'b1) };
                else if (sm[END_BITS + 20 + a_cnt_pos])        m_shift = { 2'b11, a_cnt };
                else if (sm[END_BITS + 20 + a_cnt_pos - 1])    m_shift = (a_cnt == -6'd1) ? 0 : {  {2{1'b1}}, (a_cnt + 1'b1) };
            end else begin
                if (sm==0) m_shift = 0;
                else if      (sm[END_BITS + 22])                    m_shift = -2;
                else if (sm[END_BITS + 21])                    m_shift = -1;
                else if (sm[END_BITS + 20])                    m_shift =  0;
            end
        end
    end


endmodule