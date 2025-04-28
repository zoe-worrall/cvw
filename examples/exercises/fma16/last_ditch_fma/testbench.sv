/* verilator lint_off STMTDLY */
module testbench_fma16;
  logic        clk, reset;
  logic [15:0] x, y, z, rexpected, result;
  logic [7:0]  ctrl;
  logic        mul, add, negp, negz;
  logic [1:0]  roundmode;
  logic [31:0] vectornum, errors;
  logic [75:0] testvectors[1000000:0];
  logic [3:0]  flags, flagsexpected; // Invalid, Overflow, Underflow, Inexact
  

  logic rs;
  logic [4:0]  re;
  logic [9:0]  rm;

  logic no_prod;

  // instantiate device under test
  fma16 dut(x, y, z, mul, add, negp, negz, roundmode, result, flags);
  logic eval;

  // generate clock
  always 
    begin
      clk = 1; #5; clk = 0; #5;
    end

  // at start of test, load vectors and pulse reset   
  // 1. all_adds
  // 2. harris_fma_1
  // 3. harris_comp_fma_1_v_2
  initial
    begin
      $readmemh("C:\\Mac\\Home\\Documents\\GitHub\\cvw\\examples\\exercises\\fma16\\work\\fadd_0.tv", testvectors);
      vectornum = 0; errors = 0;
      reset = 1; #22; reset = 0;
    end

  // apply test vectors on rising edge of clk
  always @(posedge clk)
    begin
      #1; {x, y, z, ctrl, rexpected, flagsexpected} = testvectors[vectornum];
      {rs, re, rm} = rexpected;
      {roundmode, mul, add, negp, negz} = ctrl[5:0];
    end

  logic error;
  // check results on falling edge of clk
  always @(negedge clk)
    if (~reset) begin // skip during reset
      // $display("Test #%h", vectornum);
      eval = ((result != rexpected) & no_prod);
      if (result != rexpected | flags !== flagsexpected) begin
        $display("Error: inputs %h * %h + %h", x, y, z);
        $display("  result = %h (%h expected) flags = %b (%b expected)", result, rexpected, flags, flagsexpected);
        error = 1;
        errors = errors + 1;
      end else error = 0;
      vectornum = vectornum + 1;
      if (testvectors[vectornum] === 'x) begin 
        $display("%d tests completed with %d errors",  vectornum, errors);
        $stop;
      end
    end
endmodule
