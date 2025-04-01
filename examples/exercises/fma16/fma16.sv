/**
	A module that runs fma16

    Zoe Worrall - zworrall@g.hmc.edu
    E154 System on Chip
    February 12, 2025
*/

module fma16(
    x, 
    y, 
    z, 
    mul, 
    add, 
    negp, 
    negz, 
    roundmode, 
    result, 
    flags); 

    /////////////////
    // Parameters
    /////////////////

    input [15:0] x;
    input [15:0] y;
    input [15:0] z;

    // ctrl (6 bits total - [5:0])
    input        mul;
    input        add;
    input        negp;
    input        negz;
    input [1:0]  roundmode;

    output [15:0] result;
    output [3:0]  flags;

    // 136, 63, 62
    parameter ZEROS = 63'h0;
    parameter LENGTH = 63 * 2 + 11;
    parameter MAX = LENGTH - 1;
    parameter DEC = LENGTH - 63; // 137 - 63 = 74, so DEC = 74
    parameter ZERO1 = 62'h0;
    parameter ZERO2 = 53'h0;


    logic [9:0]   xm, ym, zm;
    logic [21:0]  mid_pm;
    logic [MAX:0] pm;
    logic [4:0]   xe, ye, ze_small;
    logic [5:0]   pe, ze;
    logic         xs, ys, zs, ms;


    parameter inf_val  = 16'b0_11111_0000000000;
    parameter ninf_val = 16'b1_11111_0000000000;
    parameter nan_val  = 16'b0_11111_0000000001;

    logic x_zero, y_zero, z_zero; assign x_zero = (x==0 | x==16'h8000);                   assign y_zero = (y==0 | y==16'h8000);                  assign z_zero = (z==0 | z==16'h8000);
    logic x_inf, y_inf, z_inf;    assign x_inf  = (x==16'b0_11111_0000000000);            assign y_inf = (y==16'b0_11111_0000000000);            assign z_inf = (z==16'b0_11111_0000000000);
    logic x_nan, y_nan, z_nan;    assign x_nan  = ((x[15:10]==6'b011_111) & (x[9:0]!=0)); assign y_nan = ((y[15:10]==6'b011_111) & (y[9:0]!=0)); assign z_nan = ((z[15:10]==6'b011_111) & (z[9:0]!=0));
    logic x_one, y_one, z_one;    assign x_one  = (x==16'b0_01111_0000000000);            assign y_one = (y==16'b0_01111_0000000000);            assign z_one = (z==16'b0_01111_0000000000);

    //////////////////////////////////////////
    //              Logic                   //
    //////////////////////////////////////////

    assign {xs, xe, xm} = x;
    assign {ys, ye, ym} = y;
    assign {zs, ze_small, zm} = z;
    assign ze = { 1'b0, ze_small }; // extend to 6 bits for consistency with pe (exponent of product)
    assign mid_pm = {1'b1, xm} * {1'b1, ym};

    logic product_carried_1; 
    logic product_carried_2; 
    assign product_carried_1 = mid_pm[21];
    assign product_carried_2 = mid_pm[20];

    //////////////////////////////////////////
    //              FMA Steps               //
    //////////////////////////////////////////

    ////////////// Step #1 - Product Mantissa //////////////
    assign pm = { ZERO1, mid_pm, ZERO2};


    ////////////// Step #2 - Product Exponent //////////////
    assign pe = (xe - 5'b01111) + (ye - 5'b01111) + 5'b01111;  // -15 for normalization


    ////////////// Step #3 - Alignment Shift Count //////////////
    logic [5:0] a_cnt;
    logic       a_cnt_positive;

    // if pe is negative and ze is positive, then a_cnt will be negative, so we need to check if pe is greater than ze to determine if we need to shift left or right
    assign a_cnt_positive = pe[4] ? ze[4] ? (pe[3:0] >= ze[3:0]) : 1'b1 : ze[4] ? 1'b0 : (pe[3:0] >= ze[3:0]); 
    assign a_cnt = a_cnt_positive ? pe - ze : ze - pe;   // maximum is 32


    ////////////// Step #4 - Alignment Mantissa //////////////
    logic [MAX:0] zm_bf_shift;
    logic [MAX:0] am;
    assign zm_bf_shift = { ZEROS, 1'b1, zm, ZEROS};

    assign am = a_cnt_positive ? zm_bf_shift >> a_cnt : zm_bf_shift << a_cnt;    // left shift


    ////////////// Step #5 - Sum Mantissa //////////////
    logic [MAX:0] sm;

    logic  mult_is_neg;
    assign mult_is_neg = (xs ^ ys) ? 1'b1 : 1'b0; // x * y is negative if one of them is negative
    logic  same_sign;
    assign same_sign = (z_zero | ~(mult_is_neg ^ zs)) ? 1'b1 : 1'b0; // same_sign is true if the product sign matches the z sign

    // assign sm = z_zero ? pm : (same_sign) ? (am + pm) : (pm > am) ?  (pm - am) : (am - pm); // : (zs & ((xs & ys) | (~xs & ~ys))) ? (pm - am) : (zs & ((~xs & ys) | (xs & ~ys))) ? (pm - am) : (pm + am);
    assign sm = z_zero ? pm : (same_sign) ? (am + pm) : (pm - am);

    ////////////// Step #6 - Normalization Shift //////////////
    logic [7:0] m_cnt;
        always_comb begin // logic based off FMA Detailed Algorithm
            if (same_sign) begin
                if (~a_cnt_positive & a_cnt >= 11)                              // [ -inf, -11] range
                begin
                    m_cnt = -a_cnt; //(a_cnt==11) ? -11 : (a_cnt==15) ? (same_sign) ? -15 : -14 : zs ? -a_cnt+1 : -a_cnt;
                    // m_cnt = same_sign ? -a_cnt : -a_cnt+1;
                end 
                else if ((~a_cnt_positive & ((a_cnt < 11)) & (a_cnt >= 2)))      // (-11, -2] range
                begin 
                        if      (sm[DEC+12]) m_cnt = (sm[DEC+11]) ? -14 : -13;
                        else if (sm[DEC+11]) m_cnt = (sm[DEC+10]) ? -13 : -12;
                        else if (sm[DEC+10]) m_cnt = (sm[DEC+9 ]) ? -12 : -11;
                        else if (sm[DEC+9 ]) m_cnt = (sm[DEC+8 ]) ? -11 : -10;
                        else if (sm[DEC+8 ]) m_cnt = (sm[DEC+7 ]) ? -10 : -9;
                        else if (sm[DEC+7 ]) m_cnt = (sm[DEC+6 ]) ? -9  : -8;
                        else if (sm[DEC+6 ]) m_cnt = (sm[DEC+5 ]) ? -8  : -7;
                        else if (sm[DEC+5 ]) m_cnt = (sm[DEC+4 ]) ? -7  : -6;
                        else if (sm[DEC+4 ]) m_cnt = (sm[DEC+3 ]) ? -6  : -5;
                        else if (sm[DEC+3 ]) m_cnt = (sm[DEC+2 ]) ? -5  : -4;
                        else if (sm[DEC+2 ]) m_cnt = (sm[DEC+1 ]) ? -4  : -3;
                        else if (sm[DEC+1 ]) m_cnt = (sm[DEC+0 ]) ? -3  : -2;
                        else if (sm[DEC+0 ]) m_cnt = (sm[DEC-1 ]) ? -2  : -1;
                        else if (sm[DEC-1 ]) m_cnt = (sm[DEC   ]) ? -1  :  0;
                    
                end 
                else if ((~a_cnt_positive & (a_cnt == 1)) | (a_cnt == 0) | (a_cnt_positive & (a_cnt <= 6'd20))) 
                begin
                    if      (sm == 0   )  m_cnt = -1;
                    else if (sm[DEC+2 ])  m_cnt = -3;
                    else if (sm[DEC+1 ])  m_cnt = -2;
                    else if (sm[DEC+0 ])  m_cnt = -1;
                    else                  m_cnt =  0;
                end 
                else 
                begin
                    if (sm[DEC])       m_cnt = -1;
                    else               m_cnt = (same_sign) ? 1'b0 : 1'b1;
                end
            end
            else // not same sign
            begin
                if (zs) // z is negative
                 begin
                        if (~a_cnt_positive & a_cnt >= 11) begin   // [-inf, -11] range
                            if ((pe != 0) & ((~a_cnt_positive) & (a_cnt >= 11) & (zs) & ((~mult_is_neg & zs & (zm[8:0] == 0))))) m_cnt = -a_cnt + 1;
                            else                                                                                                 m_cnt = -a_cnt; 
                            
                            // m_cnt = (a_cnt==11) ? -11 : (a_cnt==15) ? (same_sign) ? -15 : -14 : zs ? -a_cnt+1 : -a_cnt;
                        end
                        else if ((~a_cnt_positive & ((a_cnt < 11)) & (a_cnt >= 2)))   // (-11, -2] range
                        begin
                                if      (~sm[DEC+12]) m_cnt = -13;
                                else if (~sm[DEC+11]) m_cnt = -12;
                                else if (~sm[DEC+10]) m_cnt = -11;
                                else if (~sm[DEC+9 ]) m_cnt =  -10;
                                else if (~sm[DEC+8 ]) m_cnt =  -9;
                                else if (~sm[DEC+7 ]) m_cnt =  -8;
                                else if (~sm[DEC+6 ]) m_cnt = -7;
                                else if (~sm[DEC+5 ]) m_cnt = -6;
                                else if (~sm[DEC+4 ]) m_cnt = -5;
                                else if (~sm[DEC+3 ]) m_cnt = -4;
                                else if (~sm[DEC+2 ]) m_cnt = -3;
                                else if (~sm[DEC+1 ]) m_cnt = -2;
                                else if (~sm[DEC+0 ]) m_cnt = -1;
                                else if (~sm[DEC-1 ]) m_cnt = 0;
                                else                  m_cnt = 0;
                        end
                        else if ((~a_cnt_positive & (a_cnt == 1)) | (a_cnt == 0) | (a_cnt_positive & (a_cnt <= 6'd20)))  // [-1, 20] range
                        begin
                                if      (sm == 0)     m_cnt = -1;
                                else if (sm[DEC+2 ])  m_cnt = (a_cnt) ? a_cnt + 9 : 1;
                                else if (sm[DEC+1 ])  m_cnt = 50;
                                else if (sm[DEC+0:DEC-15])                        // 0 to 15
                                        if (sm[DEC+0:DEC-7])                            // 0 to 7
                                            if (sm[DEC-0:DEC-3])                            // 0 to 3
                                                if (sm[DEC-0:DEC-1])                            // 0 to 1
                                                    if (sm[DEC-0]) m_cnt = 1;
                                                    else           m_cnt = 0;
                                                else                                            // 1 to 2
                                                    if (sm[DEC-2]) m_cnt = 1;
                                                    else           m_cnt = 2;
                                            else                                            // 4 to 7
                                                if (sm[DEC-4:DEC-6])                            // 4 to 5
                                                    if (sm[DEC-4]) m_cnt = 3;
                                                    else           m_cnt = 4;
                                                else                                            // 6 to 7
                                                    if (sm[DEC-6]) m_cnt = 5;
                                                    else           m_cnt = 6;
                                        else                                            // 8 to 15
                                            if (sm[DEC-8:DEC-11])                               // 8 to 11
                                                if (sm[DEC-8:DEC-9])                                // 8 to 9
                                                    if (sm[DEC-8]) m_cnt = 7;
                                                    else           m_cnt = 8;
                                                else                                                // 10 to 11
                                                    if (sm[DEC-10]) m_cnt = 9;
                                                    else            m_cnt = 10;
                                            else                                               // 12 to 15
                                                if (sm[DEC-12:DEC-13])                              // 12 to 13
                                                    if (sm[DEC-12]) m_cnt = 11;
                                                    else            m_cnt = 12;
                                                else                                                // 14 to 15
                                                    if (sm[DEC-14]) m_cnt = 13;
                                                    else            m_cnt = 14;
                                else                                              // 16 to 33
                                    if (sm[DEC-16:DEC-23])                              // 16 to 23
                                        if (sm[DEC-16:DEC-19])                              // 16 to 19
                                            if (sm[DEC-16:DEC-17])                              // 16 to 17
                                                if (sm[DEC-16]) m_cnt = 15;
                                                else            m_cnt = 16;
                                            else                                                // 18 to 19
                                                if (sm[DEC-18]) m_cnt = 17;
                                                else            m_cnt = 18;
                                        else                                                // 20 to 23
                                            if (sm[DEC-20:DEC-21])                              // 20 to 21
                                                if (sm[DEC-20]) m_cnt = 19;
                                                else            m_cnt = 20;
                                            else                                                // 22 to 23
                                                if (sm[DEC-22]) m_cnt = 21;
                                                else            m_cnt = 22; 
                                    else if (sm[DEC-24:DEC-31])                             // 24 to 31
                                        if (sm[DEC-24:DEC-27])                                  // 24 to 27
                                            if (sm[DEC-24:DEC-25])                                  // 24 to 25
                                                if (sm[DEC-24]) m_cnt = 23;
                                                else            m_cnt = 24;
                                            else                                                    // 26 to 27
                                                if (sm[DEC-26]) m_cnt = 25;
                                                else            m_cnt = 26;
                                        else                                                     // 28 to 31
                                            if (sm[DEC-28:DEC-29])                                  // 28 to 29
                                                if (sm[DEC-28]) m_cnt = 27;
                                                else            m_cnt = 28;
                                            else                                                    // 30 to 31
                                                if (sm[DEC-30]) m_cnt = 29;
                                                else            m_cnt = 30;
                                    else                                                        // 32 to 33
                                            if (sm[DEC-32:DEC-33])                                  // 32 to 33
                                                if (sm[DEC-32]) m_cnt = 31;
                                                else            m_cnt = 32; // maximum shift count is 33
                                            else
                                                m_cnt = 33; // default case, should not happen
                        end
                        else 
                        begin
                            if (sm[DEC])       m_cnt = -1;
                            else               m_cnt = (same_sign) ? 1'b0 : 1'b1;
                        end
                end
                else // z is positive
                begin
                        if (~a_cnt_positive & a_cnt >= 11) begin   // [-inf, -11] range
                            m_cnt = -a_cnt; // m_cnt = (a_cnt==11) ? -11 : (a_cnt==15) ? (same_sign) ? -15 : -14 : zs ? -a_cnt+1 : -a_cnt;
                        end
                        else if ((~a_cnt_positive & ((a_cnt < 11)) & (a_cnt >= 2)))   // (-11, -2] range
                        begin
                                if      (~sm[DEC+12]) m_cnt = -13;
                                else if (~sm[DEC+11]) m_cnt = -12;
                                else if (~sm[DEC+10]) m_cnt = -11;
                                else if (~sm[DEC+9 ]) m_cnt =  -10;
                                else if (~sm[DEC+8 ]) m_cnt =  -9;
                                else if (~sm[DEC+7 ]) m_cnt =  -8;
                                else if (~sm[DEC+6 ]) m_cnt = -7;
                                else if (~sm[DEC+5 ]) m_cnt = -6;
                                else if (~sm[DEC+4 ]) m_cnt = -5;
                                else if (~sm[DEC+3 ]) m_cnt = -4;
                                else if (~sm[DEC+2 ]) m_cnt = -3;
                                else if (~sm[DEC+1 ]) m_cnt = -2;
                                else if (~sm[DEC+0 ]) m_cnt = -1;
                                else if (~sm[DEC-1 ]) m_cnt = 0;
                                else                  m_cnt = 0;
                        end
                        else if ((~a_cnt_positive & (a_cnt == 1)) | (a_cnt == 0) | (a_cnt_positive & (a_cnt <= 6'd20)))  // [-1, 20] range
                        begin
                                if      (sm == 0)     m_cnt = -1;
                                else if (sm[DEC+2 ])  m_cnt = (a_cnt) ? a_cnt + 9 : 1;
                                else if (sm[DEC+1 ])  m_cnt = 50;
                                else if (sm[DEC+0:DEC-15])                        // 0 to 15
                                        if (sm[DEC+0:DEC-7])                            // 0 to 7
                                            if (sm[DEC-0:DEC-3])                            // 0 to 3
                                                if (sm[DEC-0:DEC-1])                            // 0 to 1
                                                    if (sm[DEC-0]) m_cnt = 1;
                                                    else           m_cnt = 0;
                                                else                                            // 1 to 2
                                                    if (sm[DEC-2]) m_cnt = 1;
                                                    else           m_cnt = 2;
                                            else                                            // 4 to 7
                                                if (sm[DEC-4:DEC-6])                            // 4 to 5
                                                    if (sm[DEC-4]) m_cnt = 3;
                                                    else           m_cnt = 4;
                                                else                                            // 6 to 7
                                                    if (sm[DEC-6]) m_cnt = 5;
                                                    else           m_cnt = 6;
                                        else                                            // 8 to 15
                                            if (sm[DEC-8:DEC-11])                               // 8 to 11
                                                if (sm[DEC-8:DEC-9])                                // 8 to 9
                                                    if (sm[DEC-8]) m_cnt = 7;
                                                    else           m_cnt = 8;
                                                else                                                // 10 to 11
                                                    if (sm[DEC-10]) m_cnt = 9;
                                                    else            m_cnt = 10;
                                            else                                               // 12 to 15
                                                if (sm[DEC-12:DEC-13])                              // 12 to 13
                                                    if (sm[DEC-12]) m_cnt = 11;
                                                    else            m_cnt = 12;
                                                else                                                // 14 to 15
                                                    if (sm[DEC-14]) m_cnt = 13;
                                                    else            m_cnt = 14;
                                else                                              // 16 to 33
                                    if (sm[DEC-16:DEC-23])                              // 16 to 23
                                        if (sm[DEC-16:DEC-19])                              // 16 to 19
                                            if (sm[DEC-16:DEC-17])                              // 16 to 17
                                                if (sm[DEC-16]) m_cnt = 15;
                                                else            m_cnt = 16;
                                            else                                                // 18 to 19
                                                if (sm[DEC-18]) m_cnt = 17;
                                                else            m_cnt = 18;
                                        else                                                // 20 to 23
                                            if (sm[DEC-20:DEC-21])                              // 20 to 21
                                                if (sm[DEC-20]) m_cnt = 19;
                                                else            m_cnt = 20;
                                            else                                                // 22 to 23
                                                if (sm[DEC-22]) m_cnt = 21;
                                                else            m_cnt = 22; 
                                    else if (sm[DEC-24:DEC-31])                             // 24 to 31
                                        if (sm[DEC-24:DEC-27])                                  // 24 to 27
                                            if (sm[DEC-24:DEC-25])                                  // 24 to 25
                                                if (sm[DEC-24]) m_cnt = 23;
                                                else            m_cnt = 24;
                                            else                                                    // 26 to 27
                                                if (sm[DEC-26]) m_cnt = 25;
                                                else            m_cnt = 26;
                                        else                                                     // 28 to 31
                                            if (sm[DEC-28:DEC-29])                                  // 28 to 29
                                                if (sm[DEC-28]) m_cnt = 27;
                                                else            m_cnt = 28;
                                            else                                                    // 30 to 31
                                                if (sm[DEC-30]) m_cnt = 29;
                                                else            m_cnt = 30;
                                    else                                                        // 32 to 33
                                            if (sm[DEC-32:DEC-33])                                  // 32 to 33
                                                if (sm[DEC-32]) m_cnt = 31;
                                                else            m_cnt = 32; // maximum shift count is 33
                                            else
                                                m_cnt = 33; // default case, should not happen
                        end
                        else 
                        begin
                            if (sm[DEC])       m_cnt = -1;
                            else               m_cnt = (same_sign) ? 1'b0 : 1'b1;
                        end
                end
            end
        end

    logic check_error;
    assign check_error = ((pe != 0) & ((~a_cnt_positive) & (a_cnt >= 11) & (zs) & ((~mult_is_neg & zs & (zm[8:0] == 0))))) ? 1'b1 : 1'b0;

    ////////////// Step #7 - Normalization Mantissa and Exponent //////////////
    logic [136:0] mm;
    logic [9:0] mm_part;
    logic [7:0] me;
    logic [7:0] index;
    assign mm = a_cnt_positive ? (sm << m_cnt) : (sm >> m_cnt);//(z_zero) ? ((m_cnt > 1) ? sm << (m_cnt - {7'b0, product_carried}) : sm >> ({7'b0, product_carried} - m_cnt)) :  sm << m_cnt;
    assign mm_part = (x_zero | y_zero) ? zm : mm[DEC-2:DEC-11];
    assign me = (x_zero | y_zero) ? {3'b000, ze} : pe - m_cnt; //(z_zero) ? (product_carried ? ({2'b0, pe} - m_cnt + 8'b1) : ({2'b00, pe} - m_cnt)) : ({2'b0, pe} - m_cnt + 1'b1);

    // Not a Step - Assign First Bit
    assign ms = (pe > {1'b0, ze}) ? ((~xs & ys) | (xs & ~ys)) : zs;//~(xs ^ ys) : zs;

   
    //////////////////////////////////////////
    //               Flags                  //
    //////////////////////////////////////////

    logic raise_flag;
    assign raise_flag = (x_nan | y_nan | z_nan | (x_zero & y_inf) | (y_zero & x_inf));

    // Flag Logic (based on Rounding)
    logic nv, of, uf, nx; // invalid, overflow, underflow, inexact
    // Overflow
    assign of = me[5] ? 1'b1 : 1'b0;
    
    // inexact if the result is not exact to the actual value
    assign nx = (mm - mm_part) ? 1'b1 : 1'b0; // if data is left out of mm_part, this isn't an accurate solution

    // Invalid if any input is NaN
    assign nv = (x_nan | y_nan | z_nan);


    assign uf = 0;


    /**
    //////////////////////////////////////////
    //              Rounding                //
    //////////////////////////////////////////
    logic L, G, R, T; // L = last bit, G = guard bit, R = round bit, T = tie
    assign L = mm[DEC-11];
    assign G = mm[DEC-12];
    assign R = mm[DEC-13];
    assign T = (mm[DEC-14:0]) ? 1'b0 : 1'b1;

    logic [15:0] res_rounded;

    // Truncation
    logic [15:0] trunc;
    assign trunc = {ms, me[4:0], mm_part};

    // RND - set if there needed to be rounding in order for the algebra to work
    logic [11:0] rnd_0;
    logic [15:0] rnd_1;
    assign rnd_0 = {2'b01, mm_part+1'b1};
    assign rnd_1 = (zs) ? rnd_0[10] ? {ms, me[4:0]-5'b00001, mm_part} : {ms, me[4:0], mm_part} : {ms, me[4:0], mm_part};
    // assign rnd_1 = (zs) ? ((rnd_0[10]) ? {ms, me, rnd_0[9:0]} : {ms, me-5'b00001, {rnd_0[9:1], 1'b1}}) : ((rnd_0[11]) ? {ms, me+5'b00001, {rnd_0[9:1], 1'b0}} :  {ms, me, {rnd_0[10:2], 1'b1}});// {ms, me+5'b00001, {rnd_0[10:2], 1'b1}});
    // ((me[5]) ? -22 : (me[4]) ? {ms, me-5'b00001, {rnd_0[9:1], 1'b1}} : -21) : ((rnd_0[10]) ? -23 : (rnd_0[9]) ? -24 : {ms, me, {rnd_0[9:1], 1'b1}}); //{rnd_0[9:1], 1}} : -25;


    always_comb begin
        // will eventually have case roundmode once I know what roundmode is for each one
        // RNE
        if (~ms) begin
            if (of) res_rounded = inf_val;
            else    begin
                if        (     ~G & ~(R|T))  res_rounded = trunc;
                else if   (     ~G &  (R|T))  res_rounded = trunc;
                else if   (~L &  G & ~(R|T))  res_rounded = trunc;
                else if   ( L &  G & ~(R|T))  res_rounded = rnd_1;
                else if   (      G &  (R|T))  res_rounded = rnd_1;
            end
        end 
        else begin
            if (of) res_rounded = ninf_val;
            else   begin
                if        (     ~G & ~(R|T))  res_rounded = trunc;
                else if   (     ~G &  (R|T))  res_rounded = trunc;
                else if   (~L &  G & ~(R|T))  res_rounded = rnd_1;
                else if   ( L &  G & ~(R|T))  res_rounded = rnd_1;
                else if   (      G &  (R|T))  res_rounded = rnd_1;
            end
        end

        // RZ
        
        if (~ms) begin
            if (of) res_rounded = inf_val;
            else    begin
                if        (     ~G & ~(R|T))  res_rounded = trunc;
                else if   (     ~G &  (R|T))  res_rounded = trunc;
                else if   (~L &  G & ~(R|T))  res_rounded = trunc;
                else if   ( L &  G & ~(R|T))  res_rounded = trunc;
                else if   (      G &  (R|T))  res_rounded = trunc;
            end
        end 
        else begin
            if (of) res_rounded = ninf_val;
            else   begin
                if        (     ~G & ~(R|T))  res_rounded = trunc;
                else if   (     ~G &  (R|T))  res_rounded = trunc;
                else if   (~L &  G & ~(R|T))  res_rounded = trunc;
                else if   ( L &  G & ~(R|T))  res_rounded = trunc;
                else if   (      G &  (R|T))  res_rounded = trunc;
            end
        end
    end
    */


    //////////////////////////////////////////
    //               Outputs                //
    //////////////////////////////////////////



    // Combine together (no rounding yet)
    // I'll need to account for the possibility that z is negative in the future, since that'll change the sign bit
    assign result = (x_zero | y_zero) ? {zs, ze_small, zm} : {ms, me[4:0], mm_part};
    // assign result = (x_zero | y_zero) ? {zs, ze_small, zm} : zs ? {~mult_is_neg, pe, pm[DEC-2:DEC-11]} : trunc; //nx ? zs ? {ms, me[4:0]-1, 10'b11111_11111} : {ms, pe[4:0], 10'b00000_00001} : {ms, me[4:0], mm_part};

    assign flags = { nv, of, uf, nx }; // Invalid, Overflow, Underflow, Inexact


endmodule