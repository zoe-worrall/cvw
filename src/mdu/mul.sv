///////////////////////////////////////////
// mul.sv
//
// Written: David_Harris@hmc.edu 16 February 2021
// Modified: 
//
// Purpose: Integer multiplication
// 
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
// 
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file 
// except in compliance with the License, or, at your option, the Apache License version 2.0. You 
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the 
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, 
// either express or implied. See the License for the specific language governing permissions 
// and limitations under the License.
////////////////////////////////////////////////////////////////////////////////////////////////

module mul #(parameter XLEN) (
  input  logic                clk, reset,
  input  logic                StallM, FlushM,
  input  logic [XLEN-1:0]     ForwardedSrcAE, ForwardedSrcBE, // source A and B from after Forwarding mux
  input  logic [2:0]          Funct3E,                        // type of multiply
  output logic [XLEN*2-1:0]   ProdM                           // double-widthproduct
);

    logic [XLEN*2-1:0]  PP1M, PP2M, PP3M, PP4M;               // registered partial proudcts

    logic [XLEN*2-1:0]  PP1E, PP2E, PP3E, PP4E;               // registered partial proudcts

    logic Am, Bm, Pm;
    logic [XLEN-2:0] A_prime, B_prime, PA, PB;
    logic [XLEN*2-1:0] P_prime;

    logic MUL, MULH, MULHU, MULHSU;

 
  //////////////////////////////
  // Execute Stage: Compute partial products
  //////////////////////////////

  assign MUL     = (Funct3E == 3'b000);
  assign MULH    = (Funct3E == 3'b001);
  assign MULHU   = (Funct3E == 3'b011);
  assign MULHSU  = (Funct3E == 3'b010);

  assign Am = ForwardedSrcAE[XLEN-1];
  assign Bm = ForwardedSrcBE[XLEN-1];
  assign Pm = Am * Bm;

  assign A_prime = ForwardedSrcAE[XLEN-2:0];
  assign B_prime = ForwardedSrcBE[XLEN-2:0];
  assign PP1E = {1'b0, A_prime} * {1'b0, B_prime};


  assign PA =  Am * B_prime;
  assign PP2E = {2'b00, (MUL | MULHU) ? PA : ~PA, {(XLEN-1){1'b0}}};  // if youonly look for MULHU, it breaks - 

  assign PB = Bm * A_prime;
  assign PP3E = {2'b00, (MULH) ? ~PB : PB, {(XLEN-1){1'b0}}};

  assign PP4E = MULH ? {1'b1, Pm, {(XLEN-3){1'b0}}, 1'b1, {(XLEN){1'b0}}} : (MULHU) ? {1'b0, Pm, {(XLEN*2-2){1'b0}}} : (MULHSU) ? {1'b1, ~Pm, {(XLEN-2){1'b0}}, 1'b1, {(XLEN-1){1'b0}}} : 0;

  // Memory Stage: Sum partial proudcts
  //////////////////////////////

  flopenrc #(XLEN*2) PP1Reg(clk, reset, FlushM, ~StallM, PP1E, PP1M); 
  flopenrc #(XLEN*2) PP2Reg(clk, reset, FlushM, ~StallM, PP2E, PP2M); 
  flopenrc #(XLEN*2) PP3Reg(clk, reset, FlushM, ~StallM, PP3E, PP3M); 
  flopenrc #(XLEN*2) PP4Reg(clk, reset, FlushM, ~StallM, PP4E, PP4M); 

  // add up partial products; this multi-input add implies CSAs and a final CPA
  assign ProdM = PP1M + PP2M + PP3M + PP4M; //ForwardedSrcAE * ForwardedSrcBE;
endmodule
