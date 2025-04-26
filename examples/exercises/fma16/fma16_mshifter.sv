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
        input  logic [6:0]        a_cnt, // exponent difference between pe and ze for adjusting

        input  logic              no_product, // whether the product is zero/subnormal
        input  logic              diff_sign,  // whether the product and z have different signs
        input  logic              z_zero, // whether z is zero
        
        output logic [7:0]        m_shift, // additional adjustment to find the first 1 in the array
        output logic [VEC_SIZE:0] sm // the sum of the product and z mantissas
    );

    // Internal Logic
    logic [VEC_SIZE:0] diff_sum; // the difference between the product and z mantissas
    logic [6:0] a_cnt_pos; // the positive value of a_cnt
    
    /**
    *  Uses previous calculations in order to determine the m_shift value
    *
    *  Patterns in Each Scenario are Followed to Assign a Relevant m_shift:
    *
    *   If am and pm are different signs:
    *       * If a_cnt is less than -2, then that means that z is smaller than the product; thus, the
    *            leading one is dependent on how far forward am has been shifted (so m_shift is set to some
    *            mathematical function of a_cnt)
    *       * If a_cnt is greater than -3, then that means that z is larger than the product; thus, the
    *            leading one is somewhere above the first decimal point. This is the most hardware-heavy
    *            case, as it requires a lot of bit shifting to find the leading one
    *       > sm is set to be the difference between the product and z mantissas, since they're being subtracted
    *            from each other; we additionally check to see if am should be cancelled (z_zero)
    *   
    *   If am and pm are the same sign:
    *       * If a_cnt is negative, then the only locations that the leading one can be is one of three
    *             places about whether the sum has been shifted (i.e. it's dependent on a_cnt)
    *       * If a_cnt is positive, the leading one has to be within the first three bits of the original
    *             decimal points for the product (product can only have 1's in three places when we set
    *             this system up).
    *       > sm is set to be the sum of the product and z mantissas, since they're being added. A special
    *             case applies here, where if z is zero, then we have to check to make sure the product isn't
    *             subnormal; if it is, we have to subtract am (i.e. remove 1 from the product).
    ***/
    
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
            if (a_cnt[6] & (a_cnt != -6'd2) & (a_cnt != -6'd1)) begin // a_cnt = -3 to all other negatives

                // m_shift lies somewhere around the first three bits in front of or the bit behind the a_cnt shift
                if      (diff_sum[END_BITS + 20 + a_cnt_pos + 1'b1])       m_shift = { {2{1'b1}}, a_cnt - 1'b1 };
                else if (diff_sum[END_BITS + 20 + a_cnt_pos + 0])          m_shift = { {2{1'b1}}, a_cnt };
                else if (diff_sum[END_BITS + 20 + a_cnt_pos - 1'b1])       m_shift = { {2{1'b1}}, (a_cnt + 1'b1) };
                else if (diff_sum[END_BITS + 20 + a_cnt_pos - 6'b000010])  m_shift = { {2{1'b1}}, (a_cnt + 6'b000010) };

                // the sum is the difference between the product and z mantissas
                sm = diff_sum;
        

            end else begin  
                
                // a_cnt is -2 or above, we need to look through every bit in the sum's mantissa (which is 
                //          24 bits total, including the ENDING_BITS) **priority encoder
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
                else                                               m_shift = 24;

                // the sum is the difference between the product and z mantissas; if z_zero, we only set it to the product
                sm = (z_zero) ? (pm) : diff_sum;
            end

        end

        // This is the case where the product and the adder are the same sign
        else begin

            // in this case, the sm is the same for either am scenario:
            //    * if z is zero, then we need to check to see if the product is subnormal
            //         * if the product is subnormal/non existent, sm is the difference of the two (subtract 1 from the product)
            //         * if the product is normal, then we can just use the product (pm)
            //    * if z is not zero, then we can just add the two mantissas together
            sm = (z_zero) ? (no_product) ? (pm - am) : pm : (am + pm);

            // if a_cnt is negative, then the only locations that the leading one can be is one of two bits of/in front of a_cnt
            //     or one bit behind it.
            if (a_cnt[6]) begin // should be a_cnt > 16

                // in the case that pm and am are identical, m_shift doesn't need to change
                if (sm==0)                                     m_shift = 0;

                // check the three bits about the top of am
                else if (sm[END_BITS + 20 + a_cnt_pos + 1])    m_shift = (a_cnt == 7'b1000000) ?  8'b1111_1111 : { {2{1'b1}}, (a_cnt - 1'b1) };
                else if (sm[END_BITS + 20 + a_cnt_pos])        m_shift = { 2'b11, a_cnt };
                else if (sm[END_BITS + 20 + a_cnt_pos - 1])    m_shift = (a_cnt == -6'd1) ? 0 : {  {2{1'b1}}, (a_cnt + 1'b1) };
                
            end 
        
            // if a_cnt is positive, the leading one has to be within the first two bits of the product or the bit after the first bit
            else begin

                // in the case that pm and am are identical, m_shift doesn't need to change
                if (sm==0)                                     m_shift = 0;

                // check the three bits about the decimal point
                else if (sm[END_BITS + 22])                    m_shift = -2;
                else if (sm[END_BITS + 21])                    m_shift = -1;
                else if (sm[END_BITS + 20])                    m_shift =  0;
            end

        end
    end


endmodule