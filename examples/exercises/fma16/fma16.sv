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

reg [15:0] result_mul;
reg [3:0]  flags_mul;

assign result = (mul) ? result_mul : 0;
assign flags  = (mul) ? flags_mul : 0;


//  4*4
//        3c00_3c00_0000_   08_     3c00_        0         // 1.000000 * 1.000000 = 1.000000 NV: 0 OF: 0 UF: 0 NX: 0
//         x    y    z      ctrl  rexpected,  flagsexpected

// 3c00 = 0011 1100 0000 0000
//       0     1    0    0     0
// roundmode, mul, add, negp, negz

// fmultiply section
fma16_fmul fmul_i(
		.x (x),
        .y (y),
        .z (z),

        .result (result_mul),
        .flags  (flags_mul)
	);

endmodule