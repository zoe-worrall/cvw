/**
	A module that multiplies the constants in FMA 16

    Zoe Worrall - zworrall@g.hmc.edu
    E154 System on Chip
    February 12, 2025
*/

module fma16_multiply(
    input  logic        x_zero, y_zero,
    input  logic [2:0]  op_ctrl,
    input  logic        xs, ys,
    input  logic [4:0]  xe, ye,
    input  logic [9:0]  xm, ym,
    output logic        ps,
    output logic [5:0]  pe,
    output logic [21:0] mid_pm
    );

    assign ps = (xs ^ ys) ? 1'b1 : 1'b0;
    assign pe = (x_zero | y_zero) ? '0 : (xe + ye - 5'b01111);

    // (xe==0) ? (xm[8]) ? {1'b1, xm-1'b1} : {1'b1, 10'b0} : {1'b1, xm};
    logic [10:0] x_ext, y_ext; //((xm==10'b11_1110_1100) ? {10'b01_1110_0010} : 
    assign x_ext = {1'b1, xm};
    assign y_ext = {1'b1, ym};
    
    assign mid_pm = x_ext * y_ext;

endmodule