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

    output  logic [9:0] mm_rounded,  // the rounded mantissa
    output  logic       nx_bits // nx is true if the mantissa is not exact
    );

    // Internal Logic: The Least Significant, Guarding, Rounding, and Truncation bits
    logic LSb, G, R, T, round_val;
    logic [9:0] round,  trunc;

    // Assigns the LSb, G, R, and T values based on the mantissa (mm)
    assign LSb = mm[END_BITS+10]; // LSB of the output's mantissa
    assign G =   mm[END_BITS+9];  // The guard bit
    assign R =   mm[END_BITS+8];  // The rounding bit
    assign T =  |mm[END_BITS+7:0]; // The truncation bits (all bits to the right of the rounding bit)

    logic up_the_octave_go_for_it;
    
    // Calculate both the truncation and rounding values before assigning them ** mm is truncated already
    assign trunc = mm[19+END_BITS:10+END_BITS] ; // the adjusted sum of the product and z mantissas
    assign {up_the_octave_go_for_it, round} = trunc + 1'b1;

    // Short Combination block to check all cases of round mode
    always_comb begin
        case(roundmode)

            // round to zero (simplified) - my code already does this, so we don't need to calculate trunct/round
            2'b00: 
            begin
                round_val = 0;
            end
            
            // round to even - if the LSB is 1, then we need to round to the nearest 0 (either up or down)
            2'b01: 
            begin
                round_val = (G & (LSb | R | T));
            end
            
            // round down (toward negative infinity) - we need to round down in every case
            2'b10:
            begin
                round_val = (~ms & (G|R|T));
            end

            // round up (toward positive infinity) - we need to round up in every case
            2'b11: 
            begin
                round_val = (ms & (G|R|T));
            end
            
            // Should never be reached; it will be wrong
            default: 
            begin 
                round_val = 0; // default to truncation 
            end
        endcase
    end

    assign mm_rounded = (round_val) ? round-subtract_1 :  trunc-subtract_1;
    assign nx_bits = R | G | T; // nx is true if the mantissa is not exact

endmodule
