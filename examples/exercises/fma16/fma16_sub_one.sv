/**
	A module that defines whether or not to subtract 1 from the exponent in the
        solution.

    Zoe Worrall - zworrall@g.hmc.edu
    E154 System on Chip
    April 26, 2025
*/

module fma16_sub_one #(parameter VEC_SIZE, parameter END_BITS) (
    input  logic        ps, zs,  // the signs of the product and z
    input  logic [4:0]  ze, // the exponent of the product and z
    input  logic [5:0]  pe, // the exponent of the product
    input  logic [5:0]  diff_pe_ze,  // the difference between pe and ze
    input  logic [9:0]  zm, // the mantissa of z

    input  logic        x_zero, y_zero, z_zero,  // whether z is zero

    input  logic [VEC_SIZE:0] am, sm, pm, // aligned zm for sum

    input  logic big_z, z_is_solution, // shouldve_been_zero,
    
    output logic         subtract_1  // whether or not to subtract 1
    );

    always_comb begin
        // Assigning subtract_1
            //    This is used to determine if 1'b1 should be subtracted from sm
            //
            if (ps ^ zs)
            begin
                // between -24 and 24, don't subtract anything
                if ((($signed(diff_pe_ze) > $signed(-7'd12)) & ($signed(diff_pe_ze) < 7'd12))) // changed from 24
                    if (big_z) subtract_1 = (z_is_solution) ? (~(x_zero|y_zero)) : 1'b0;
                    else subtract_1 = 0;

                // subtract 1 if: 
                    // z is small enough and the product is big (i.e. am is 0, and z is not zero or exponent of 1 (smallest))
                    // product is small enough (but not zero) and z is big enough
                else
                begin
                    // z is either really small or really big
                    if ( (am[VEC_SIZE:END_BITS]=='0) & (~(z_zero))) begin

                        if (pe==-6'd13)     subtract_1 = (ze==5'd1) ? |zm : 1'b1;

                        // if either the sm's final bits are zero, or the product was composed of two small mantissas
                        // this works every time except for a very small scenario that I don't understand
                        else if (ze==5'd1)  subtract_1 = (~(|sm[END_BITS+9:0]));

                        // if pm is 0 at the end, then when the end bits are subtracted, we know that it's already
                        //      close to the value
                        else if (pm[END_BITS+19:END_BITS]=='0 & am[END_BITS:0]) subtract_1 = 1'b0;

                        // cases when it shouldn't subtract 1:
                        else                 subtract_1 = 1'b1;

                    end


                    // there's an additional case to check, where am is small, but it cancels out
                    //   with the product, resulting in an sm being 0
                    else if ((|am[END_BITS+1:0]) & (~(|sm[9:0])) & (|zm) & (am[END_BITS+1:0]==pm[END_BITS+1:0]) ) begin
                        subtract_1 = 1'b1;
                    end

                    // This case exists assuming that the difference between numbers is big enough. been getting weird answers:
                    else if (pm=='0 & (~(x_zero|y_zero))) begin
                        subtract_1 = 1'b1;
                    end 
                    
                    
                    else begin
                        if (big_z)          subtract_1 = (z_is_solution) ? ~(x_zero|y_zero) : 1'b0;
                        else subtract_1 = 1'b0;
                    end
                end

            end else begin  
                subtract_1 = 0;
            end
    end

endmodule