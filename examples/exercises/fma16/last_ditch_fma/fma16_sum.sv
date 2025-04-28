/**
	A module that returns an mshift value that is used to further adjust
    a given sum with a given a_cnt value.

    Zoe Worrall - zworrall@g.hmc.edu
    E154 System on Chip
    April 22, 2025
*/

module fma16_sum #(parameter VEC_SIZE, parameter END_BITS) (
        input logic zs, negp, ps,
        input logic dont_leave_me, product_invisible,

        input logic  [4:0] ze,
        input logic  [6:0] pe,

        input  logic [21:0]   mid_pm, // centered product mantissa
        input  logic [VEC_SIZE-1:0]   am, // centered added mantissa
        input  logic [6:0]            a_cnt, // exponent difference between pe and ze for adjusting

        output logic                  ss,                
        output logic [6:0]            se,
        output logic [VEC_SIZE-1:0]   sm // the sum of the product and z mantissas
    );

    // flip
    logic inverse_addend;
    assign inverse_addend = zs ^ negp ^ ps;

    // two potential sums; one of them's negative, which means the other's the correct one
    logic [VEC_SIZE:0] sum_one, sum_two;

    // sum of pm and the opposite of am + (if not (dont_leave_me | product_invisible)(inverse_addend) )
    assign sum_one = { {(VEC_SIZE-21-1){1'b0}}, mid_pm, {(END_BITS){1'b0}} } + { inverse_addend, ~am } + { {(VEC_SIZE-1){1'b0}}, (dont_leave_me | product_invisible)&inverse_addend};
    assign sum_two = am + { {12{1'b1}}, ~mid_pm, {(END_BITS){1'b0}} } + { {(33)'(0)}, (~dont_leave_me|~product_invisible), {(END_BITS){1'b0}}};

    assign sm = (sum_one[VEC_SIZE]) ? sum_two : sum_one;
    assign ss = sum_one[VEC_SIZE]^ps;
    assign se = (product_invisible) ? {2'b00, ze} : pe;



endmodule



