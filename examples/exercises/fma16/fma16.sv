/**
	A module that runs fma16

    Zoe Worrall - zworrall@g.hmc.edu
    E154 System on Chip
    February 12, 2025
*/

module fma16(
    input logic [15:0]  x, 
    input logic [15:0]  y, 
    input logic [15:0]  z, 
    input logic         mul, 
    input logic         add, 
    input logic         negp, 
    input logic         negz, 
    input logic  [1:0]  roundmode, 
    output logic [15:0] result,
    output logic        no_product,
    output logic [3:0]  flags); 


     //  OpCtrl:
  //    Fma: {not multiply-add?, negate prod?, negate Z?}
  //        000 - fmadd
  //        001 - fmsub
  //        010 - fnmsub
  //        011 - fnmadd
  //        100 - mul
  //        110 - add
  //        111 - sub

logic         xs, ys, zs;
logic [4:0]   xe, ye, ze;
logic [9:0]   xm, ym, zm;

logic [2:0]   op_ctrl = { mul|add, negp, negz };

logic x_zero, x_inf, x_nan;
logic y_zero, y_inf, y_nan;
logic z_zero, z_inf, z_nan;


parameter nan_val = 16'b0_111_11_1000000000;
logic subtract, can_add, can_multiply;

fma16_assignCons constant_assigner(.x, .y, .z, .op_ctrl,
                                .xs, .ys, .zs, 
                                .xe, .ye, .ze, 
                                .xm, .ym, .zm, 
                                .subtract, .can_add, .can_multiply,
                                .x_zero, .y_zero, .z_zero, 
                                .x_inf, .y_inf, .z_inf, 
                                .x_nan, .y_nan, .z_nan);


// decreasing from 136 to 85 to 36, 53 to 2

parameter BIG_VEC = 53; // absolute minimum after testing
parameter LESSER_VEC = 2;

logic [21:0] mid_pm;
logic        ps;
logic [5:0]  pe;

// calculate the products Ps, Pe, and Pm
fma16_multiply multiplier(.x_zero, .y_zero, .op_ctrl, .xs, .ys, .xe, .ye, .xm, .ym, .ps, .pe, .mid_pm);


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Step #1 - Product Mantissa
logic [5:0] a_cnt;
logic [BIG_VEC:0] am;
logic [BIG_VEC:0] pm;

fma16_shift #(BIG_VEC, LESSER_VEC) shifter(.pe, .xe, .ye, .ze, .zm, .x_zero, .y_zero, .z_zero, .mid_pm, .a_cnt, .no_product, .am, .pm);

logic [5:0] a_cnt_pos;
assign a_cnt_pos = { ~a_cnt[5], ~a_cnt[4], ~a_cnt[3], ~a_cnt[2], ~a_cnt[1], ~a_cnt[0]} + 1; // 2's complement of a_cnt


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Step #5 - Sum Mantissa
logic [BIG_VEC:0] sm;
logic [7:0]   m_shift;
// logic         no_product;

fma16_align_add #(BIG_VEC, LESSER_VEC) adder(.pm, .am, .a_cnt, .ps, .zs, .xe, .ye, .z_zero, .no_product, .m_shift, .sm);


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Testing Logic from Harris Code

logic  no_z;
assign no_z        = $signed(a_cnt)>$signed((7)'(3)*(7)'(10)+(7)'(5));

logic asticky;
assign asticky = (no_product) ? (~(x_zero|y_zero)) : (no_z) ? (~z_zero) : |(am[9:0]);

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Step #7 - Normalization Mantissa and Exponent
logic [BIG_VEC:0] mm;
logic [9:0]   mm_part;
logic [4:0]   me;
logic [7:0]   index;
logic [7:0]   pos_m_shift;
logic [7:0]   sum_pe;
logic [7:0]   dif_pe;

assign      pos_m_shift = (~m_shift + 1); // 2's complement of m_cnt  104-53 = 51, 95-53 = 42 Original solution to long if statement -> mm[(BIG_VEC + 51):(BIG_VEC + 42)]
assign      mm_part = ((pe != 16) & pe[5] & ze[4] & (pe[4:0] < ze)) ? '0 : mm[(LESSER_VEC+19):(LESSER_VEC+10)];

assign      sum_pe = { {2{pe[5]}}, pe} + pos_m_shift; // adding the additional conversions based off of however big of a shift we have
assign      dif_pe = { {2{pe[5]}}, pe} - m_shift;

assign      me = (pe == {1'b0, ze} & (mm == 0)) ? 0 : ( m_shift == 8'b0) ? (pe[4:0]) : (m_shift[7]) ?  sum_pe[4:0] : dif_pe[4:0]; // 2's complement of m_cnt : (pe - m_shift);
assign      mm = m_shift[7] ? (sm >>> (pos_m_shift)) : sm <<< (m_shift); // (m_shift[7]) ? sm >> m_shift : sm >> m_shift;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Not a Step - Assign First Bit
assign      ms = (pm > am) ? ((xs & ~ys) | (~xs & ys)) : zs; //(pe > ze) ? (pe[4:0] == ze) ? () ? ((xs & ~ys) | (~xs & ys)) : zs : ((~xs & ys) | (xs & ~ys)) : zs;//~(xs ^ ys) : zs;

// Combine together (no rounding yet)
// I'll need to account for the possibility that z is negative in the future, since that'll change the sign bit

logic [15:0] mult;
assign      mult = (x_nan | y_nan | z_nan) ? nan_val : {ms, me, mm_part};


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////
//               Flags                  //
//////////////////////////////////////////

// Check to see (if inexact) how rounding might need to work
logic [15:0] mult_nx;
logic [1:0] which_nx;
logic [5:0] diff_count;
logic error;
logic raise_flag;
logic nv, of, uf, nx; // invalid, overflow, underflow, inexact

assign diff_count = ({1'b0, pe} > {2'b00, ze}) ? ({1'b0, pe} - {2'b00, ze}) : ({2'b00, ze} - {1'b0, pe});

assign which_nx = ((zs ^ ps) & (diff_count > 30)) ? ((zm == 0) ? 0 : 3) : ((mid_pm[21:20] == 2'b10) ? ((mid_pm[20:11] == 0) ? 1 : 3) : ((mid_pm[19:10] == 0) ? 2 : 3));
assign mult_nx = (which_nx == 0) ? {ms, ze-1'b1, zm-1'b1} : {ms, me, mm_part};

assign error = ((x_zero & y_inf) | (y_zero & x_inf) | ((mult == nan_val) & (x!=16'h7fff) & (y!=16'h7fff))); 

assign raise_flag = (x_nan | y_nan | z_nan | (x_zero & y_inf) | (y_zero & x_inf));

// Flag Logic (based on Rounding)
// Overflow
assign of = 1'b0; // me[5] ? 1'b1 : 1'b0;

// inexact if the result is not exact to the actual value
assign nx = (mm == 0) ? 1'b0 : ((mm - {{BIG_VEC{1'b0}}, 1'b1, mult_nx[9:0], {(LESSER_VEC)'(1'b0)}}) != 0) ? 1'b1 : 1'b0; // if data is left out of mm_part, this isn't an accurate solution

// Invalid if any input is NaN
assign nv = ((x_zero & y_inf) | (y_zero & x_inf) | ((mult == nan_val) & (x!=16'h7fff) & (y!=16'h7fff)));


assign uf = 0;



// assign error = (zs ^ ps) ? ((zm == 0) ? 0 : 3) : ((mid_pm[21:20] == 2'b10) ? ((mid_pm[20:11] == 0) ? 1 : 3) : ((mid_pm[19:10] == 0) ? 2 : 3));

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// {((xs^ys) & zs), 15'b0}

assign result = (x_nan | y_nan | z_nan) ? nan_val : ((x_zero & (y_inf | x_nan)) | (y_zero & (x_inf | x_nan))) ? nan_val : (x_zero | y_zero) ? (z[14:0]==0) ? {((xs^ys) & zs), 15'b0} : z : (mult[14:0]==0) ? {((xs^ys) & zs), 15'b0}  : mult_nx; // (zs & ~z_zero & (mult == 16'b0100_0000_0000_0000)) ? 16'b0011_1111_1111_1111 : mult;
assign flags = {nv, of, uf, nx}; // { invalid, overflow, underflow, inexact }


endmodule
