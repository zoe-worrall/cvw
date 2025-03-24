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

logic [9:0]  xm, ym, zm;
logic [22:0] mid_pm;
logic [99:0] pm;
logic [4:0]  xe, ye, ze;
logic [5:0]  pe;
logic        xs, ys, zs, ps;

logic x_zero, y_zero, z_zero; assign x_zero = (x==0); assign y_zero = (y==0); assign z_zero = (z==0);
logic x_inf, y_inf, z_inf; assign x_inf = (x==16'b0_11111_0000000000); assign y_inf = (y==16'b0_11111_0000000000); assign z_inf = (z==16'b0_11111_0000000000);
logic x_nan, y_nan, z_nan; assign x_nan = ((x[15:10]==6'b011_111) & (x[9:0]!=0)); assign y_nan = ((y[15:10]==6'b011_111) & (y[9:0]!=0)); assign z_nan = ((z[15:10]==6'b011_111) & (z[9:0]!=0));
logic x_one, y_one, z_one; assign x_one = (x==16'b0_01111_0000000000); assign y_one = (y==16'b0_01111_0000000000); assign z_one = (z==16'b0_01111_0000000000);

assign {xs, xe, xm} = x;
assign {ys, ye, ym} = y;
assign {zs, ze, zm} = z;

parameter inf_val = 16'b0_11111_0000000000;
parameter nan_val = 16'b0_11111_0000000001;

assign mid_pm = {1'b1, xm} * {1'b1, ym};

logic product_carried; assign product_carried = mid_pm[21];

// assign pm = { 53'h0, mid_pm, 27'h0};
assign pm = { 53'h0, mid_pm, 25'h0};

assign pe = xe + ye - 5'b01111; // -15 for normalization

logic [5:0] a_cnt;
logic       a_cnt_sign;
assign a_cnt_sign = (pe > { 1'b0, ze}) ? 0 : 1;
assign a_cnt = (a_cnt_sign) ? (ze - pe) : (pe - ze);   // maximum is 32

// 10 + 32 = 42
logic [99:0] zm_bf_shift;
logic [99:0] am;
logic [99:0] sm;
assign zm_bf_shift = { 54'h0, 1'b1, zm, 35'h0 };
assign am = zm_bf_shift >> (a_cnt - 6'b001111);    // left shift

assign sm = z_zero ? pm : (am + pm);

logic [9:0] sm_part;
assign sm_part = sm[44:35];

logic positive;
assign positive = (mid_pm + zm) > 0;

// I'll need to account for the possibility that z is negative in the future, since that'll change the sign bit
assign result = product_carried ? {(xs ^ ys), (pe[4:0]+1'b1), sm[45:36]} : {(xs ^ ys), pe[4:0], sm[44:35]};
assign flags = 4'b0;



// logic [4:0]  m_cnt; // # of bits to shift: can range from 21 to -21
// logic [31:0] mm;
// logic [4:0]  me;
// always_comb begin
//     if (sm[41:21]) begin // first half of mantissa is where leading 1 is

//     end else begin
//     end
// end


// reg [15:0] result_mul;
// reg [3:0]  flags_mul;

// reg [15:0] val_y;
// reg [15:0] val_z;

// assign val_y = (mul) ? y : 1;
// assign val_z = (add) ? (negz) ? -z : z : 0;

// assign flags  = (mul) ? flags_mul : 0;

// assign result = (negp) ? (-1)*result_mul : result_mul;

//  4*4
//        3c00_3c00_0000_   08_     3c00_        0         // 1.000000 * 1.000000 = 1.000000 NV: 0 OF: 0 UF: 0 NX: 0
//         x    y    z      ctrl  rexpected,  flagsexpected

// 3c00 = 0011 1100 0000 0000
//       0     1    0    0     0
// roundmode, mul, add, negp, negz

// // fmultiply section
// fma16_fmul_remake fmul_i(
// 		.x (x),
//         .y (val_y),
//         .result (result_mul),
//         .flags  (flags_mul)
// 	);

endmodule