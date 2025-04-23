/**
	A module that returns an mshift value that is used to further adjust
    a given sum with a given a_cnt value.

    Zoe Worrall - zworrall@g.hmc.edu
    E154 System on Chip
    April 22, 2025
*/

module fma16_mshifter #(parameter VEC_SIZE, parameter END_BITS) (
        input  logic [VEC_SIZE:0] pm, am,
        input  logic [5:0]        a_cnt,

        input  logic              no_product,
        input  logic              diff_sign,
        input  logic              z_zero,
        
        output logic [7:0]        m_shift,
        output logic [VEC_SIZE:0] sm
    );

    logic [VEC_SIZE:0] check;
    logic [5:0] a_cnt_pos;
    assign a_cnt_pos = (~a_cnt + 1'b1);

    always_comb begin
        m_shift = -40;
        check = (pm > am) ? (pm - am) : (am - pm);
        if (diff_sign) begin // if z is negative
            // if a_cnt is too big, then we can see am - pe to check sm, before computing its actual location. If a_cnt is big enough, we don't need to worry about the "middle zone"
            if (a_cnt[5] & (a_cnt != -6'd2) & (a_cnt != -6'd1)) begin // a_cnt = -3 to all other negatives
                if (check[END_BITS + 20 + a_cnt_pos + 1'b1])            m_shift = { {2{1'b1}}, a_cnt - 1'b1 };
                else if (check[END_BITS + 20 + a_cnt_pos + 0])          m_shift = { {2{1'b1}}, a_cnt };
                else if (check[END_BITS + 20 + a_cnt_pos - 1'b1])       m_shift = { {2{1'b1}}, (a_cnt + 1'b1) };
                else if (check[END_BITS + 20 + a_cnt_pos - 6'b000010])  m_shift = { {2{1'b1}}, (a_cnt + 6'b000010) };

                sm = check;
            end else begin  // a_cnt is -2 or above, we need to check that 74 or 73 doesn't have any bits
                if      (check[END_BITS + 22])                  m_shift = -2;
                else if (check[END_BITS + 21])                  m_shift = -1;
                else if (check[END_BITS + 20])                  m_shift =  0;
                else if (check[END_BITS + 19])                  m_shift =  1;
                else if (check[END_BITS + 18])                  m_shift =  2;
                else if (check[END_BITS + 17])                  m_shift =  3;
                else if (check[END_BITS + 16])                  m_shift =  4;
                else if (check[END_BITS + 15])                  m_shift =  5;
                else if (check[END_BITS + 14])                  m_shift =  6;
                else if (check[END_BITS + 13])                  m_shift =  7;
                else if (check[END_BITS + 12])                  m_shift =  8;
                else if (check[END_BITS + 11])                  m_shift =  9;
                else if (check[END_BITS + 10])                  m_shift = 10;
                else if (check[END_BITS +  9])                  m_shift = 11;
                else if (check[END_BITS +  8])                  m_shift = 12;
                else if (check[END_BITS +  7])                  m_shift = 13;
                else if (check[END_BITS +  6])                  m_shift = 14;
                else if (check[END_BITS +  5])                  m_shift = 15;
                else if (check[END_BITS +  4])                  m_shift = 16;
                else if (check[END_BITS +  3])                  m_shift = 18;
                else if (check[END_BITS +  2])                  m_shift = 19;
                else if (check[END_BITS +  1])                  m_shift = 20;
                else if (check[END_BITS +  0])                  m_shift = 21;
                else if (check[END_BITS -  1])                  m_shift = 22;
                else if (check[END_BITS -  2])                  m_shift = 23;
                else                                            m_shift = 24;

                sm = (z_zero) ? (pm) : check;
            end
        end else begin          // if z is positive
            sm = (z_zero) ? (no_product) ? (pm - am) : pm : (am + pm);
            if (a_cnt[5]) begin
                if      (sm[END_BITS + 20 + a_cnt_pos + 1])    m_shift = (a_cnt == 6'b100000) ?  8'b1111_1111 : { {2{1'b1}}, (a_cnt - 1'b1) };
                else if (sm[END_BITS + 20 + a_cnt_pos])        m_shift = { {2{1'b1}}, a_cnt };
                else if (sm[END_BITS + 20 + a_cnt_pos - 1])    m_shift = (a_cnt == -6'd1) ? 0 : {  {2{1'b1}}, (a_cnt + 1'b1) };
            end else begin
                if      (sm[END_BITS + 22])                    m_shift = -2;
                else if (sm[END_BITS + 21])                    m_shift = -1;
                else if (sm[END_BITS + 20])                    m_shift =  0;
            end
        end
    end


endmodule