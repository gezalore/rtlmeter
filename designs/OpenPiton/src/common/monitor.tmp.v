// Modified by Princeton University on June 9th, 2015
// ========== Copyright Header Begin ==========================================
//
// OpenSPARC T1 Processor File: monitor.v
// Copyright (c) 2006 Sun Microsystems, Inc.  All Rights Reserved.
// DO NOT ALTER OR REMOVE COPYRIGHT NOTICES.
//
// The above named program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License version 2 as published by the Free Software Foundation.
//
// The above named program is distributed in the hope that it will be
// useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this work; if not, write to the Free Software
// Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA.
//
// ========== Copyright Header End ============================================
`include "cross_module.tmp.h"
`include "iop.h"
`include "ifu.tmp.h"
//define and will move all the define to cross.h later
`define PLI_QUIT  1    /* None */

// /home/gl/work/openpiton/piton/verif/env/manycore/devices_ariane.xml


module monitor(/*AUTOARG*/
   // Inputs
   clk, cmp_gclk, rst_l
   );

   input clk;
   input cmp_gclk;
   input rst_l;

   wire  reset = ~rst_l;
   integer number, num, f_time, cycle;
   reg [1023:0] err;
   reg 		err_f;
   reg 		bad;
   reg          dum;

   initial
     begin
	number = 2;
	num    = 0;
	err_f  = 1;
	bad    = 0;
	cycle  = 0;
	//if($value$plusargs("wait_cycle_to_kill=%d", number))$display("wait cycles = %d", number);
     end // initial begin

// central fail task. all the monitor should call this task to finish simulation.
   task fail;
      input [1023:0] comment;
      begin
	 if(bad)begin
	    $display("%0d : Simulation -> FAIL(%0s)", $time, comment);
	    $finish;
	 end
	 if(err_f)begin
	    err = comment;
	    f_time = $time;
	 end // if (err_f)
	 err_f = 0;
	 `TOP_MOD.fail_flag = 1'b1;
      end
   endtask // fail
   always @(posedge clk)begin
      if(`TOP_MOD.fail_flag)begin
	 num = num+1;
	 if(num == number)begin
	    $display("%0d : Simulation -> FAIL(%0s)", f_time, err);
	    $finish;
	 end
      end // if (`TOP_MOD.fail_flag)
   end

`ifdef RTL_TILE0
   //monitor good trap and bad trap.
   pc_cmp pc_cmp(clk, rst_l); // Sumti - Shifting it back to clk, sas race with +fast_boot.
`endif // ifdef RTL_TILE0

endmodule
// Local Variables:
// verilog-library-directories:("." "../../../design/sparc/rtl")
// verilog-library-extensions:(".v" ".h")
// End:












