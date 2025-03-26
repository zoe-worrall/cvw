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

logic [9:0]   xm, ym, zm;
logic [21:0]  mid_pm;
logic [136:0] pm;
logic [4:0]   xe, ye, ze;
logic [5:0]   pe;
logic         xs, ys, zs, ms;

parameter inf_val = 16'b0_11111_0000000000;
parameter nan_val = 16'b0_11111_0000000001;

logic x_zero, y_zero, z_zero; assign x_zero = (x==0);                                 assign y_zero = (y==0);                                assign z_zero = (z==0);
logic x_inf, y_inf, z_inf;    assign x_inf  = (x==16'b0_11111_0000000000);            assign y_inf = (y==16'b0_11111_0000000000);            assign z_inf = (z==16'b0_11111_0000000000);
logic x_nan, y_nan, z_nan;    assign x_nan  = ((x[15:10]==6'b011_111) & (x[9:0]!=0)); assign y_nan = ((y[15:10]==6'b011_111) & (y[9:0]!=0)); assign z_nan = ((z[15:10]==6'b011_111) & (z[9:0]!=0));
logic x_one, y_one, z_one;    assign x_one  = (x==16'b0_01111_0000000000);            assign y_one = (y==16'b0_01111_0000000000);            assign z_one = (z==16'b0_01111_0000000000);

/////////////////
// Logic
/////////////////

assign {xs, xe, xm} = x;
assign {ys, ye, ym} = y;
assign {zs, ze, zm} = z;
assign mid_pm = {1'b1, xm} * {1'b1, ym};

logic product_carried; 
assign product_carried = mid_pm[21];

/////////////////
// FMA Steps
/////////////////

// Step #1 - Product Mantissa
assign pm = { 62'h0, mid_pm, 53'h0};

// Step #2 - Product Exponent
assign pe = xe + ye - 5'b01111;  // -15 for normalization

// Step #3 - Alignment Shift Count
logic [5:0] a_cnt;
logic       a_cnt_positive;
assign a_cnt_positive = (pe > {1'b0, ze});
assign a_cnt = a_cnt_positive ? pe - ze - 6'b001111 : ze - pe - 6'b001111 ;   // maximum is 32

// Step #4 - Alignment Mantissa
logic [136:0] zm_bf_shift;
logic [136:0] am;
assign zm_bf_shift = { 63'h0, 1'b1, zm, 63'h0 };
assign am = zm_bf_shift >> a_cnt;    // left shift

// Step #5 - Sum Mantissa
logic [136:0] sm;
assign sm = z_zero ? pm : (am + pm);

// Step #6 - Normalization Shift
logic [7:0] m_cnt;
always_comb begin // logic based off FMA Detailed Algorithm
    m_cnt = 0;
    if (a_cnt_positive & (a_cnt < 6'd21)) begin
        if       (sm[76]) m_cnt = -2;
        else if  (sm[75]) m_cnt = -1;
        else              m_cnt =  0;
    end
    else if (~a_cnt_positive & (a_cnt > 1) & (a_cnt < 4)) begin
        if       (sm[75 - a_cnt]) m_cnt = { 2'b00, a_cnt} - 8'b1;
        else                      m_cnt = { 2'b00, a_cnt};
    end
    else if (~a_cnt_positive & (a_cnt > 4)) begin
        if       (sm[75]) m_cnt = { 2'b00, a_cnt};
    end
    else if (a_cnt_positive & (a_cnt > 21)) begin
        if       (sm[76]) m_cnt = -1;
        else              m_cnt =  0;
    end
end

// Step #7 - Normalization Mantissa and Exponent
logic [136:0] mm;
logic [9:0] mm_part;
logic [7:0] me;
logic [7:0] index;

assign mm = (m_cnt > 1) ? sm << (m_cnt - {7'b0, product_carried}) : sm >> ({7'b0, product_carried} - m_cnt);
assign mm_part = mm[72:63];
assign me = product_carried ? ({2'b0, pe} - m_cnt + 8'b1) : ({2'b00, pe} - m_cnt);


// Not a Step - Assign First Bit
assign ms = (pe > {1'b0, ze}) ? ((~xs & ys) | (xs & ~ys)) : zs;//~(xs ^ ys) : zs;

// Combine together (no rounding yet)
// I'll need to account for the possibility that z is negative in the future, since that'll change the sign bit
assign result =  {ms, me[4:0], mm_part};
assign flags = 4'b0;


endmodule