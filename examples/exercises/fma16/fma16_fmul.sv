/**
	A module that runs a pvp plot generator using a Finite State Machine
*/

module fma16_fmul(
    x, 
    y, 
    z, 
    result, 
    flags	
);

input [15:0] x;
input [15:0] y;
input [15:0] z;

output [15:0] result;
output        flags;

/*** PARAMETERS ***/

// value calculation

reg [31:0] middle_step;
assign middle_step = x * y;
assign result = middle_step[31:16];

assign flags = 0;

endmodule