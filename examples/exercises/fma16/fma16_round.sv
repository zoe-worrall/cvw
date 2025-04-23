/**
	A module that calculates how to round the final mantissa of the result

    Zoe Worrall - zworrall@g.hmc.edu
    E154 System on Chip
    April 23, 2025
*/


module fma16_round #(parameter VEC_SIZE, parameter END_BITS) (
    input  logic              ms, // sign of the product
    input  logic [VEC_SIZE:0] mm, // the sum of the product and z mantissas

    input  logic [1:0] roundmode,  // the rounding mode
    input  logic       subtract_1, // whether to subtract 1 from the mantissa

    output  logic [VEC_SIZE:0] fin_mm  // the final mantissa
    );

    // Internal Logic: The Least Significant, Guarding, Rounding, and Truncation bits
    logic LSb, G, R, T, round_val;
    logic [VEC_SIZE:0] trunc, round;

    // Assigns the LSb, G, R, and T values based on the mantissa (mm)
    assign LSb = mm[END_BITS+10]; // LSB of the output's mantissa
    assign G =   mm[END_BITS+9];  // The guard bit
    assign R =   mm[END_BITS+8];  // The rounding bit
    assign T =  |mm[END_BITS+7:0]; // The truncation bits (all bits to the right of the rounding bit)
    assign round_val = G; // G&(R | T); // if G > 1 (0.5) and R|T > 1 (> 0.5), then trunc should be 1. otherwise, 0

    // Calculate both the truncation and rounding values before assigning them
    assign trunc = { mm[(VEC_SIZE-1):(END_BITS+11)], round_val, mm[(END_BITS+10):0] } ; // the adjusted sum of the product and z mantissas
    assign round = trunc - { {(VEC_SIZE-END_BITS-10-1){1'b0}}, 1'b1, (END_BITS+10)'(1'b0) }; // the adjusted sum of the product and z mantissas

    // Short Combination block to check all cases of round mode
    always_comb begin
        case(roundmode)

            // round to zero (simplified) - my code already does this, so we don't need to calculate trunct/round
            2'b00: fin_mm = mm;
            
            // round to even - if the LSB is 1, then we need to round to the nearest 0 (either up or down)
            2'b01: fin_mm = (LSb) ? mm + { {(VEC_SIZE-END_BITS-10-1){1'b0}}, 1'b1, (END_BITS+10)'(1'b0) } : round;
            
            // round down (toward negative infinity) - we need to round down in every case
            2'b10: fin_mm = (~ms & (G|R))    ? round : trunc; // round down (toward negative infinity)

            // round up (toward positive infinity) - we need to round up in every case
            2'b11: fin_mm = ( ms & (G|R))    ? round : trunc; // round up (toward positive infinity)
            
            // Should never be reached; it will be wrong
            default: fin_mm = trunc; // default to truncation
        endcase
    end

endmodule