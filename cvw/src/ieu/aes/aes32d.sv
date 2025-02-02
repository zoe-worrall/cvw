///////////////////////////////////////////
// aes32d.sv
//
// Written: ryan.swann@okstate.edu, james.stine@okstate.edu
// Created: 20 February 2024
//
// Purpose: aes32dsmi and aes32dsi instruction: RV32 middle and final round AES decryption
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
// 
// Copyright (C) 2021-24 Harvey Mudd College & Oklahoma State University
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

module aes32d(
   input  logic [7:0]  SboxIn,
   input  logic        finalround,
   output logic [31:0] result
);

   logic [7:0] 			  SboxOut;
   logic [31:0] 		     so, mixed;
   
   aesinvsbox8 inv_sbox(SboxIn, SboxOut);          // Apply inverse sbox to si
   aesinvmixcolumns8 mix(SboxOut, mixed);          // Run so through the InvMixColumns AES function
   assign so = {24'h0, SboxOut};                   // Pad output of inverse substitution box
   mux2 #(32) rmux(mixed, so, finalround, result); // on final round, skip mixcolumns
endmodule
