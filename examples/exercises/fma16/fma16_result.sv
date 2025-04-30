/**
	A module that calculates the result of an fma16 calculation.

    Zoe Worrall - zworrall@g.hmc.edu
    E154 System on Chip
    April 23, 2025
*/
module fma16_result #(parameter VEC_SIZE, parameter END_BITS) (
    
    input  logic              zs, // sign of z
    input  logic [4:0]        ze, // exponent of z
    input  logic [9:0]        zm, // mantissa of z
    input  logic              ps, // sign of the product
    input  logic [5:0]        pe, // exponent of the product

    input  logic [VEC_SIZE:0] sm,   // the sum of the product and z mantissas

    input  logic              ms,   // the sign of the result
    input  logic [21:0]       mid_pm, // mantissa of the product

    input  logic [7:0]        m_shift,  // an additional shift value to correctly set up the final result's me
    input  logic              subtract_1, // used to adjust if we have to subtract a small number from a bigger one


    // inputs that correct the pe being too small
    input  logic              big_z, z_is_solution, // if z is so big that it dwarfs the product, and also a check to make sure that -pe != ze (wrong size for pe)
    input  logic              one_less_mshift, // adjustments for the mshift
    input  logic [1:0]        which_nx,  // used to determine if subnormal
    input  logic              z_visible,
    input  logic              prod_visible,

    input  logic [1:0]        roundmode, // the rounding mode of the system

    output logic [4:0]        me, // the exponent of the result
    output logic [15:0]       fma_result, // the final result of the fma16 calculation
    output logic              fma_nx
    );

    // Variables used for calculations
    logic [7:0]        pos_m_shift;
    logic [9:0]        mm_rounded;
    logic [VEC_SIZE:0] mm;
    logic [7:0]        sum_pe, prior_sum_pe;
    logic [7:0]        dif_pe, prior_diff_pe;
    logic [VEC_SIZE:0] sm_shifted, sm_shift_back;
    logic [VEC_SIZE:0] zm_shifted;
    logic fix_z_vis;
    logic nx_bits;


    ///////////////////////////////////////////////////////////////////////////////
    // Calculates Values for Result
    ///////////////////////////////////////////////////////////////////////////////

    // To help with faster calculations later, find the 2's complement of m_shift
    assign pos_m_shift = ~m_shift + 1'b1;

    // Calculates what could potentially be the mantissa of the multiplicand:
    //
    //      *  currently in the process of reworking this section; this was initially the if statement
    //            indicated below, that caught that when specific cases applied, the answer was 0.
    //            Making this expand to broader regions, as I have a fear that this was case specific.
    //     
    // Used to find either the sum or the difference of the product and z mantissas; we want to add a positive shift
    assign prior_sum_pe  = { {2{pe[5]}}, pe} + pos_m_shift; 
    assign prior_diff_pe = { {2{pe[5]}}, pe} - m_shift;
    assign sum_pe        = (|prior_sum_pe) ? prior_sum_pe : 5'b00001; // adding the additional conversions based off of however big of a shift we have
    assign dif_pe        = (|prior_diff_pe) ? prior_sum_pe : 5'b00001;


    // Shifted by mshifta
    assign sm_shifted    = (m_shift[7]) ?  (sm >>> (pos_m_shift)) : sm <<< (m_shift);
    assign sm_shift_back = (m_shift[7]) ? (sm_shifted <<< (pos_m_shift)) : (sm_shifted >>> m_shift);
    assign zm_shifted    = { {(VEC_SIZE-END_BITS-10-10){1'b0}}, (ze!=0), zm, {(END_BITS+10)'(1'b0)} };

    ///////////////////////////////////////////////////////////////////////////////
    // Calculates Result Components
    ///////////////////////////////////////////////////////////////////////////////

    // Calculating the exponent and full value of the result; the output of the round mode is used to determine flags
    // m_shift is 0 when:
        // 1. the product is zero
        // 2. the product is subnormal
        // 3. the product is normal, but am was 0
    always_comb begin

        // if the product and z are equivalent (i.e. solution is zero)
        if (pe == {1'b0, ze} & (sm == 0)) 
        begin
            me = 0;
            mm = '0;
            fix_z_vis = 0;
        end

        // this occurs when xe and ye are both really, really small. That means that, normally, some value is lost; this is due to the odd bit shifting behavior
        else if (pe == -6'd13)
        begin
            me = (ze!=5'd1) ? ze - (~|zm & subtract_1) : ze;
            mm = zm_shifted;
            fix_z_vis = (ze==-5'd2) ? 1'b0 : 1'b1;
        end

        // This is called if the z is way bigger than the product, meaning that me and mm should be set to either ze/zm
        //    or the difference between pe and ze vs pm and zm
        else if (big_z) begin

            // z is the only value that is visible in the sum
            if (z_is_solution) begin
                me = ze - ((ps ^ zs) & subtract_1 & ~|zm);
                mm = zm_shifted;
                fix_z_vis = 1'b1;
            end 
            
            // z and the product overlap
            else begin
                me = sum_pe - (sm_shifted==sm_shift_back); 
                mm = sm_shifted;
                fix_z_vis = 1'b0;
            end

        end

        else if (subtract_1) begin

             // if which_nx is 0, the product is much greater than the z, meaning subnormal things ensue
                if (which_nx == 0) 
                begin
                    me = sum_pe - (~|sm[END_BITS+19:END_BITS]); // *not every time that z=1 do you need to subtract(ze!=5'd1) ? sum_pe - subtract_1 : sum_pe; // (~|(sm[19+END_BITS:0])); // subtract one bit if z was much smaller, sm is big
                    mm = sm_shifted;
                    fix_z_vis = 0;
                    // mm_part = fin_mm; //[(END_BITS+19):(END_BITS+10)] - 1'b1;
                end
                
                // this means that product was smaller than z (and inexact)
                else if (which_nx == 1)
                begin
                    me = ze - 1'b1;
                    mm = zm_shifted;
                    fix_z_vis = 0;
                    // mm_part = zm;
                end

                // this means that z is potentially inexact, and will be further configured in round
                else
                begin
                    me = sum_pe;
                    mm = sm_shifted;
                    fix_z_vis = 0;
                end

        end

        // If the shift was negative, sm_shift and the se apply as below
        else if (m_shift[7])
        begin
                me = sum_pe[4:0] - subtract_1;
                mm = sm_shifted;
                fix_z_vis = 0;
        end

        // If the shift was positive, then sm_shift and se as apply below
        else
        begin
                me = (one_less_mshift) ? pe : dif_pe[4:0]; // 2's complement of m_cnt : (pe - m_shift);
                mm = sm_shifted;
                fix_z_vis = 0;
        end
    end


    ///////////////////////////////////////////////////////////////////////////////
    // Calculates Rounding
    ///////////////////////////////////////////////////////////////////////////////

    assign fma_result = {ms, me, mm_rounded}; 
    assign fma_nx =   nx_bits | prod_visible | (z_visible ^ fix_z_vis) | (big_z & z_is_solution & |mid_pm[19:0]);


    fma16_round #(VEC_SIZE, END_BITS) rounder(.ms, .mm, .roundmode, .subtract_1, .mm_rounded, .nx_bits);

endmodule