`default_nettype none
module servant_tb;

   parameter memfile = "";
   parameter memsize = 32768;
   parameter width = 1;
   parameter with_csr = 1;

   localparam baud_rate =
	      (width == 4) ? 180000 :
	      57600;

   reg wb_clk = 1'b0;
   reg wb_rst = 1'b1;

   wire q;

   always  #31 wb_clk <= !wb_clk;
   initial #62 wb_rst = 1'b0;

   uart_decoder #(baud_rate) uart_decoder (q);

   servant_sim
     #(.memfile  (memfile),
       .memsize  (memsize),
       .width    (width),
       .with_csr (with_csr))
   dut
     (.wb_clk (wb_clk),
      .wb_rst (wb_rst),
      .pc_adr (),
      .pc_vld (),
      .q      (q));

`include "__rtlmeter_top_include.vh"

endmodule
