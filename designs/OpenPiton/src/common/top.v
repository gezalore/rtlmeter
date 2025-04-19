// Modified by Princeton University on June 9th, 2015
// ========== Copyright Header Begin ==========================================
//
// OpenSPARC T1 Processor File: cmp_top.v
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
////////////////////////////////////////////////////////

`include "sys.h"
`include "iop.h"
`include "cross_module.tmp.h"
`include "ifu.tmp.h"
`include "define.tmp.h"
`include "piton_system.vh"


// /home/gl/work/openpiton/piton/verif/env/manycore/devices_ariane.xml



`timescale 1ps/1ps
module cmp_top;

//////////////////////
// Type Declarations
//////////////////////

reg                             sys_rst_n = 1;
reg                             pll_rst_n = 1;
reg                             jtag_rst_l = 1;

reg                             core_ref_clk = 1;
reg                             io_clk = 1;
reg                             jtag_clk = 1;
//reg                             chipset_clk_osc_p = 1;
//reg                             chipset_clk_osc_n = 0;
//reg                             chipset_clk_osc = 1;
reg                             chipset_clk = 1;
//reg                             mem_clk = 1;
//reg                             spi_sys_clk = 1;
//reg                             chipset_passthru_clk_p = 1;
//reg                             chipset_passthru_clk_n = 0;
//reg                             passthru_clk_osc_p = 1;
//reg                             passthru_clk_osc_n = 0;
//reg                             passthru_chipset_clk_p = 1;
//reg                             passthru_chipset_clk_n = 0;

reg                             clk_en = 0;
reg [1:0]                       clk_mux_sel;
reg                             pll_bypass;
reg [4:0]                       pll_rangea;
wire                            pll_lock;
reg                             async_mux;

reg                             diag_done;

reg                             jtag_modesel = 1;
reg                             jtag_datain = 0;
wire                            jtag_dataout;


// For simulation only, monitor stuff.  Only cross-module referenced
// do not delete.
reg                             fail_flag;

////////////////////
// Simulated Clocks
////////////////////

`ifndef USE_FAKE_PLL_AND_CLKMUX
$error;
`endif

always #500 core_ref_clk = ~core_ref_clk;                       // 1000MHz
always #625 chipset_clk = ~chipset_clk;                         // 800MHz
always #50000 jtag_clk = ~jtag_clk;                             // 10MHz

always_comb io_clk = core_ref_clk;

//always #750 chipset_clk_osc_p = ~chipset_clk_osc_p;             // 666MHz
//always_comb chipset_clk_osc_n = ~chipset_clk_osc_p;

//always #1500 chipset_clk_osc = ~chipset_clk_osc;                // 333MHz

//always #3333 passthru_clk_osc_p = ~passthru_clk_osc_p;          // 150MHz
//always @ * passthru_clk_osc_n = ~passthru_clk_osc_p;
//
//always #1429 passthru_chipset_clk_p = ~passthru_chipset_clk_p;  // 350MHz
//always @ * passthru_chipset_clk_n = ~passthru_chipset_clk_p;

//always #750 mem_clk = ~mem_clk;                                 // 666MHz

//always #25000 spi_sys_clk = ~spi_sys_clk;                       // 20MHz

////////////////////////////////////////////////////////
// SIMULATED BOOT SEQUENCE
////////////////////////////////////////////////////////

initial
begin
    // These are not referenced elsewhere in this module,
    // but are cross referenced from monitor.v.pyv.  Do not
    // delete
    fail_flag = 1'b0;

    // Proper negedge at start of boot
    #1;
    sys_rst_n = 1'b0;
    jtag_rst_l = 1'b0;
    pll_rst_n = 1'b0;

    // Mostly DC signals set at start of boot
    if ($test$plusargs("pll_en")) $error;
    pll_bypass = 1'b1; // trin: pll_bypass is a switch in the pll; not reliable
    clk_mux_sel[1:0] = 2'b00; // selecting ref clock
    // rangeA = x10 ? 5'b1 : x5 ? 5'b11110 : x2 ? 5'b10100 : x1 ? 5'b10010 : x20 ? 5'b0 : 5'b1;
    pll_rangea = 5'b00001; // 10x ref clock
    // pll_rangea = 5'b11110; // 5x ref clock
    // pll_rangea = 5'b00000; // 20x ref clock

`ifndef SYNC_MUX
    async_mux = 1'b1;
`else
    async_mux = 1'b0;
`endif

    // Reset PLL for 100 cycles
    repeat(100)@(posedge core_ref_clk);
    pll_rst_n <= 1'b1;

    // Wait for PLL lock
    wait( pll_lock == 1'b1 );

    // After 10 cycles turn on chip-level clock enable
    repeat(10)@(posedge `CHIP_INT_CLK);
    clk_en <= 1'b1;

    // After 100 cycles release reset
    repeat(100)@(posedge `CHIP_INT_CLK);
    sys_rst_n <= 1'b1;
    jtag_rst_l <= 1'b1;

    // Wait for SRAM init
    // trin: 5000 cycles is about the lowest for 64KB L2
    // 128KB L2 requires at least 10000
    // This seems redundant actually, all the init state machines are commented out
    repeat(50)@(posedge `CHIP_INT_CLK); // trin: supports at least 512KB L2 per-tile

    diag_done <= 1'b1;
`ifndef PITONSYS_IOCTRL
    // Signal fake IOB to send wake up packet to first tile
    cmp_top.system.chipset.chipset_impl.ciop_fake_iob.ok_iob = 1'b1;
`endif // endif PITONSYS_IOCTRL
end

////////////////////////////////////////////////////////
// SYNTHESIZABLE SYSTEM
// INCLUDES CHIP + CHIPSET (AND OPTIONAL PASSTHRU)
///////////////////////////////////////////////////////

system system(
`ifndef PITON_FPGA_SYNTH
    // I/O settings, just set to
    // fastest for simulation
    .chip_io_slew(1'b1),
    .chip_io_impsel(2'b11),
`endif // endif PITON_FPGA_SYNTH

    // Clocks and resets
`ifdef PITON_CLKS_SIM
    .core_ref_clk(core_ref_clk),
    .io_clk(io_clk),
`endif // endif PITON_CLKS_SIM

`ifdef PITONSYS_INC_PASSTHRU
`ifdef PITON_PASSTHRU_CLKS_GEN
    .passthru_clk_osc_p(passthru_clk_osc_p),
    .passthru_clk_osc_n(passthru_clk_osc_n),
`else // ifndef PITON_PASSTHRU_CLKS_GEN
    .passthru_chipset_clk_p(passthru_chipset_clk_p),
    .passthru_chipset_clk_n(passthru_chipset_clk_n),
`endif // endif PITON_PASSTHRU_CLKS_GEN
`endif // endif PITON_SYS_INC_PASSTHRU

`ifdef PITON_CHIPSET_CLKS_GEN
`ifdef PITON_CHIPSET_DIFF_CLK
    .chipset_clk_osc_p(chipset_clk_osc_p),
    .chipset_clk_osc_n(chipset_clk_osc_n),
`else // ifndef PITON_CHIPSET_DIFF_CLK
    .chipset_clk_osc(chipset_clk_osc),
`endif // endif PITON_CHIPSET_DIFF_CLK
`else // ifndef PITON_CHIPSET_CLKS_GEN
    .chipset_clk(chipset_clk),
`ifndef PITONSYS_NO_MC
`ifdef PITON_FPGA_MC_DDR3
    .mc_clk(mem_clk),
`endif // endif PITON_FPGA_MC_DDR3
`endif // endif PITONSYS_NO_MC
`ifdef PITONSYS_SPI
    .spi_sys_clk(spi_sys_clk),
`endif // endif PITONSYS_SPI
`ifdef PITONSYS_INC_PASSTHRU
    .chipset_passthru_clk_p(chipset_passthru_clk_p),
    .chipset_passthru_clk_n(chipset_passthru_clk_n),
`endif // endif PITONSYS_INC_PASSTHRU
`endif // endif PITON_CHIPSET_CLKS_GEN

    .sys_rst_n(sys_rst_n),

    // Piton chip specific
`ifndef PITON_FPGA_SYNTH
    .pll_rst_n(pll_rst_n),
`endif // endif PITON_FPGA_SYNTH

`ifndef PITON_FPGA_SYNTH
    // Chip level clock enable
    .clk_en(clk_en),
`endif // endif PITON_FPGA_SYNTH

`ifndef PITON_FPGA_SYNTH
    // Chip PLL settings
    .pll_bypass(pll_bypass),
    .pll_rangea(pll_rangea),
    .pll_lock(pll_lock),
`endif // endif PITON_FPGA_SYNTH

`ifndef PITON_FPGA_SYNTH
    // Chip clock mux selection (bypass PLL or not)
    .clk_mux_sel(clk_mux_sel),
`endif // endif PITON_FPGA_SYNTH

`ifndef PITON_NO_JTAG
    // Chip JTAG
    .jtag_clk(jtag_clk),
    .jtag_rst_l(jtag_rst_l),
    .jtag_modesel(jtag_modesel),
    .jtag_datain(jtag_datain),
    .jtag_dataout(jtag_dataout),
`endif  // endif PITON_NO_JTAG

`ifndef PITON_NO_CHIP_BRIDGE
    // Chip async FIFOs enable for
    // bridign core<->io clk domain
    .async_mux(async_mux),
`endif // endif PITON_FPGA_SYNTH

    // DRAM and I/O interfaces
`ifndef PITONSYS_NO_MC
`ifdef PITON_FPGA_MC_DDR3
    // FPGA DDR MC interface, currently not supported in simulation
    .init_calib_complete(),
    .ddr_addr(),
    .ddr_ba(),
    .ddr_cas_n(),
    .ddr_ck_n(),
    .ddr_ck_p(),
    .ddr_cke(),
    .ddr_ras_n(),
    .ddr_reset_n(),
    .ddr_we_n(),
    .ddr_dq(),
    .ddr_dqs_n(),
    .ddr_dqs_p(),
    .ddr_cs_n(),
    .ddr_dm(),
    .ddr_odt(),
`endif // endif PITON_FPGA_MC_DDR3
`endif // endif PITONSYS_NO_MC

`ifdef PITONSYS_IOCTRL
`ifdef PITONSYS_UART
    // UART interface for bootloading and
    // serial port interface.  Currently
    // not supported in simulation
    .uart_tx(),
    .uart_rx(),
`endif // endif PITONSYS_UART

`ifdef PITONSYS_SPI
    // SPI interface for boot device and disk.
    // Currently not supported in simulation
    .spi_data_in(),
    .spi_data_out(),
    .spi_clk_out(),
    .spi_cs_n(),
`endif // endif PITONSYS_SPI
`endif // endif PITONSYS_IOCTRL

    // Switches
`ifdef PITON_NOC_POWER_CHIPSET_TEST
    .sw({4'bz, 4'd`PITON_NOC_POWER_CHIPSET_TEST_HOP_COUNT}),
`else // ifndef PITON_NOC_POWER_CHIPSET_TEST
    .sw(),
`endif // endif PITON_NOC_POWER_CHIPSET_TEST

    // Do not provide any functionality
    .leds()
);

////////////////////////////////////////////////////////
// MONITOR STUFF
////////////////////////////////////////////////////////


`ifndef DISABLE_ALL_MONITORS

    // this is the T1 sparc core monitor
    monitor   monitor(
        .clk    (`CHIP_INT_CLK),
        .cmp_gclk  (`CHIP_INT_CLK),
        .rst_l     (`CHIP.rst_n_inter_sync)
        );

`endif // DISABLE_ALL_MONITORS

`include  "__rtlmeter_top_include.vh"

endmodule // cmp_top

