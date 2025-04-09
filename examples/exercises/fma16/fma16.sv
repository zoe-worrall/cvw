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

logic [9:0]   xm, ym, zm;
logic [21:0]  mid_pm;
logic [146:0] pm;
logic [4:0]   xe, ye, ze;
logic [5:0]   pe;
logic [1]     xs, ys, zs, ms;

parameter inf_val = 16'b0_11111_0000000000;
parameter nan_val = 16'b0_11111_1000000000;

parameter neg_zero = 16'b1_00000_0000000000;

logic x_zero, y_zero, z_zero; assign x_zero = ((x==0) | (x==neg_zero));               assign y_zero = ((y==0) | (y==neg_zero));              assign z_zero = ((z==0) | (z==neg_zero));
logic x_inf, y_inf, z_inf;    assign x_inf  = (x==16'b0_11111_0000000000);            assign y_inf = (y==16'b0_11111_0000000000);            assign z_inf = (z==16'b0_11111_0000000000);
logic x_nan, y_nan, z_nan;    assign x_nan  = ((x[15:10]==6'b011_111) & (x[9:0]!=0)); assign y_nan = ((y[15:10]==6'b011_111) & (y[9:0]!=0)); assign z_nan = ((z[15:10]==6'b011_111) & (z[9:0]!=0));
logic x_one, y_one, z_one;    assign x_one  = (x==16'b0_01111_0000000000);            assign y_one = (y==16'b0_01111_0000000000);            assign z_one = (z==16'b0_01111_0000000000);

assign {xs, xe, xm} = x;
assign {ys, ye, ym} = y;
assign {zs, ze, zm} = z;
assign mid_pm = {1'b1, xm} * {1'b1, ym};

logic ps;
assign ps = (xs ^ ys) ? 1'b1 : 1'b0; // x * y is negative if one of them is negative

logic product_carried; 
assign product_carried = mid_pm[21];

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Step #1 - Product Mantissa
always_comb begin
    if (x_zero | y_zero) begin
        pm = 0;
    end else begin
        pm = { 62'h0, mid_pm, 53'h0};
    end
end

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Step #2 - Product Exponent
always_comb begin
    if (x_zero | y_zero) begin
        pe = 0;
    end else begin
        pe = (xe + ye - 5'b01111);  // -15 for normalization
    end
end

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Step #3 - Alignment Shift Count
logic [5:0] a_cnt;
assign a_cnt = ((pe != 16) & pe[5] & ze[4] & (pe[4:0] < ze)) ? ((pe - ze) == 5'b10000) ? (pe - ze) : (pe - ze - 32) : (pe - ze); //  - 6'b001111 - 6'b001111;   // maximum is 32

logic [5:0] a_cnt_pos;
assign a_cnt_pos = { ~a_cnt[5], ~a_cnt[4], ~a_cnt[3], ~a_cnt[2], ~a_cnt[1], ~a_cnt[0]} + 1; // 2's complement of a_cnt

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Step #4 - Alignment Mantissa
logic [146:0] zm_bf_shift;
logic [146:0] am;
assign zm_bf_shift = { 63'h0, 1'b1, zm, 63'h0 };
assign am = (a_cnt[5]) ? zm_bf_shift << a_cnt_pos : (zm_bf_shift >> a_cnt);    // left shift

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Step #5 - Sum Mantissa
logic [146:0] sm;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Step #6 - Normalization Shift
logic [7:0] m_cnt;
always_comb begin // logic based off FMA Detailed Algorithm
    if (pm[74])  m_cnt = -1;
    else         m_cnt =  0;
end

logic [7:0] m_cnt_2;
logic [146:0] check;
always_comb begin
    m_cnt_2 = -40;
    check = (pm > am) ? (pm - am) : (am - pm);
    if (zs & ~ps & ~z_zero) begin // if z is negative
        // if a_cnt is too big, then we can see am - pe to check sm, before computing its actual location. If a_cnt is big enough, we don't need to worry about the "middle zone"
        if (a_cnt[5] & (a_cnt != -6'd2) & (a_cnt != -6'd1)) begin // a_cnt = -3 to all other negatives
            if (check[73 + a_cnt_pos + 1])      m_cnt_2 = { {8{1'b1}}, a_cnt - 1'b1 };
            else if (check[73 + a_cnt_pos + 0]) m_cnt_2 = { {8{1'b1}}, a_cnt };
            else if (check[73 + a_cnt_pos - 1]) m_cnt_2 = { {8{1'b1}}, (a_cnt + 1'b1) };
            else if (check[73 + a_cnt_pos - 2]) m_cnt_2 = { {8{1'b1}}, (a_cnt + 2'b10) };

            sm = check;
        end else begin  // a_cnt is -2 or above, we need to check that 74 or 73 doesn't have any bits
            if      (check[75])                  m_cnt_2 = -2;
            else if (check[74])                  m_cnt_2 = -1;
            else if (check[73])                  m_cnt_2 =  0;
            else if (check[72])                  m_cnt_2 =  1;
            else if (check[71])                  m_cnt_2 =  2;
            else if (check[70])                  m_cnt_2 =  3;
            else if (check[69])                  m_cnt_2 =  4;
            else if (check[68])                  m_cnt_2 =  5;
            else if (check[67])                  m_cnt_2 =  6;
            else if (check[66])                  m_cnt_2 =  7;
            else if (check[65])                  m_cnt_2 =  8;
            else if (check[64])                  m_cnt_2 =  9;
            else if (check[63])                  m_cnt_2 = 10;
            else if (check[62])                  m_cnt_2 = 11;
            else if (check[61])                  m_cnt_2 = 12;
            else if (check[60])                  m_cnt_2 = 13;
            else if (check[59])                  m_cnt_2 = 14;
            else                                 m_cnt_2 = 15;

            sm = (z_zero) ? pm : (zs) ? check : (am + pm);
        end
    end else if (~zs & ps & ~z_zero) begin
        
        if (a_cnt[5] & (a_cnt != -6'd2) & (a_cnt != -6'd1)) begin // a_cnt = -3 to all other negatives
            if (check[73 + a_cnt_pos])          m_cnt_2 = { {8{1'b1}}, a_cnt};
            else if (check[73 + a_cnt_pos - 1]) m_cnt_2 = { {8{1'b1}}, (a_cnt+1'b1)};

            sm = check;
        end else begin  // a_cnt is -2 or above, we need to check that 74 or 73 doesn't have any bits
            sm = (z_zero) ? pm : (ps) ? check : (pm + am);

            if      (check[75])                  m_cnt_2 = -2;
            else if (check[74])                  m_cnt_2 = -1;
            else if (check[73])                  m_cnt_2 =  0;
            else if (check[72])                  m_cnt_2 =  1;
            else if (check[71])                  m_cnt_2 =  2;
            else if (check[70])                  m_cnt_2 =  3;
            else if (check[69])                  m_cnt_2 =  4;
            else if (check[68])                  m_cnt_2 =  5;
            else if (check[67])                  m_cnt_2 =  6;
            else if (check[66])                  m_cnt_2 =  7;
            else if (check[65])                  m_cnt_2 =  8;
            else if (check[64])                  m_cnt_2 =  9;
            else if (check[63])                  m_cnt_2 = 10;
            else if (check[62])                  m_cnt_2 = 11;
            else if (check[61])                  m_cnt_2 = 12;
            else if (check[60])                  m_cnt_2 = 13;
            else if (check[59])                  m_cnt_2 = 14;
            else if (check[58])                  m_cnt_2 = 15;
            else if (check[57])                  m_cnt_2 = 16;
            else if (check[56])                  m_cnt_2 = 17;
            else if (check[55])                  m_cnt_2 = 18;
            else if (check[54])                  m_cnt_2 = 19;
            else if (check[53])                  m_cnt_2 = 20;

        end
    end else begin          // if z is positive
        sm = (z_zero) ? pm : (am + pm); //(zs) ? (pm - am) : (am + pm);
        if (a_cnt[5]) begin
            if      (sm[73 + a_cnt_pos + 1])    m_cnt_2 = (a_cnt == 6'b100000) ?  8'b1111_1111 : { {8{1'b1}}, (a_cnt - 1'b1) };
            else if (sm[73 + a_cnt_pos])        m_cnt_2 = { {8{1'b1}}, a_cnt };
            else if (sm[73 + a_cnt_pos - 1])    m_cnt_2 = (a_cnt == -6'd1) ? 0 : {  {8{1'b1}}, (a_cnt + 1'b1) };
        end else begin
            if      (sm[75])                    m_cnt_2 = -2;
            else if (sm[74])                    m_cnt_2 = -1;
            else if (sm[73])                    m_cnt_2 =  0;
        end
    end
end

logic [7:0] m_shift;
always_comb begin
    if (z_zero) m_shift = m_cnt;
    else        m_shift = m_cnt_2;
end

logic [8:0] error;
assign error = ((pe != 16) & pe[5] & ze[4] & (pe[4:0] < ze)) ? pe - ze - 32 : pe - ze;

logic error_2;
assign error_2 = ((xs & ~ys) | (~xs & ys));
//  ((pe != 16) & pe[5] & ze[4] & (pe[4:0] < ze)) ? ((pe - ze) == 5'b10000) ? (pe - ze) : (pe - ze - 32) : (pe - ze)
// assign error_2 =   ((pe != { ze[4], ze }) & (pe-ze == 0)) ? pe - { ze[4], ze } : ((pe != 16) & pe[5] & ze[4] & (pe[4:0] < ze)) ? ((pe - ze) == 5'b10000) ? (pe - ze) : (pe - ze - 32) : (pe - ze); // 2's complement of ze

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Step #7 - Normalization Mantissa and Exponent
logic [146:0] mm;
logic [9:0] mm_part;
logic [4:0] me;
logic [7:0] index;

logic [7:0] pos_m_shift;
assign pos_m_shift = ({~m_shift[7], ~m_shift[6], ~m_shift[5], ~m_shift[4], ~m_shift[3], ~m_shift[2], ~m_shift[1], ~m_shift[0]} + 1); // 2's complement of m_cnt

assign mm_part = ((pe != 16) & pe[5] & ze[4] & (pe[4:0] < ze)) ? mm[104:93] : mm[72:63];
assign me = (m_shift == 0) ? pe : (m_shift[7]) ? (pe + pos_m_shift) : (pe - m_shift); // 2's complement of m_cnt : (pe - m_shift);

assign mm = m_shift[7] ? (sm >>> pos_m_shift) : sm <<< m_shift; // (m_shift[7]) ? sm >> m_shift : sm >> m_shift;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Not a Step - Assign First Bit
assign ms = (pm > am) ? ((xs & ~ys) | (~xs & ys)) : zs; //(pe > ze) ? (pe[4:0] == ze) ? () ? ((xs & ~ys) | (~xs & ys)) : zs : ((~xs & ys) | (xs & ~ys)) : zs;//~(xs ^ ys) : zs;

// Combine together (no rounding yet)
// I'll need to account for the possibility that z is negative in the future, since that'll change the sign bit

logic [15:0] mult;
assign mult = (x_nan | y_nan | z_nan) ? nan_val : {ms, me, mm_part};


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////
//               Flags                  //
//////////////////////////////////////////

logic raise_flag;
assign raise_flag = (x_nan | y_nan | z_nan | (x_zero & y_inf) | (y_zero & x_inf));

// Flag Logic (based on Rounding)
logic nv, of, uf, nx; // invalid, overflow, underflow, inexact
// Overflow
assign of = 1'b0; // me[5] ? 1'b1 : 1'b0;

// inexact if the result is not exact to the actual value
assign nx = ((mm - {63'b0, 1'b1, mm_part, 63'b0}) != 0) ? 1'b1 : 1'b0; // if data is left out of mm_part, this isn't an accurate solution

// Invalid if any input is NaN
assign nv = (x_nan | y_nan | z_nan);


assign uf = 0;



//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

assign result = (x_nan | y_nan | z_nan) ? nan_val : (x_zero | y_zero) ? z : mult; // (zs & ~z_zero & (mult == 16'b0100_0000_0000_0000)) ? 16'b0011_1111_1111_1111 : mult;
assign flags = {nv, of, uf, nx}; // { invalid, overflow, underflow, inexact }


endmodule
