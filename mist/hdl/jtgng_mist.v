/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 27-10-2017 */

`timescale 1ns/1ps

module jtgng_mist(
    input   [1:0]   CLOCK_27,
    output  [5:0]   VGA_R,
    output  [5:0]   VGA_G,
    output  [5:0]   VGA_B,
    output          VGA_HS,
    output          VGA_VS,
    // SDRAM interface
    inout [15:0]    SDRAM_DQ,       // SDRAM Data bus 16 Bits
    output [12:0]   SDRAM_A,        // SDRAM Address bus 13 Bits
    output          SDRAM_DQML,     // SDRAM Low-byte Data Mask
    output          SDRAM_DQMH,     // SDRAM High-byte Data Mask
    output          SDRAM_nWE,      // SDRAM Write Enable
    output          SDRAM_nCAS,     // SDRAM Column Address Strobe
    output          SDRAM_nRAS,     // SDRAM Row Address Strobe
    output          SDRAM_nCS,      // SDRAM Chip Select
    output [1:0]    SDRAM_BA,       // SDRAM Bank Address
    output          SDRAM_CLK,      // SDRAM Clock
    output          SDRAM_CKE,      // SDRAM Clock Enable   
   // SPI interface to arm io controller
    output          SPI_DO,
    input           SPI_DI,
    input           SPI_SCK,
    input           SPI_SS2,
    input           SPI_SS3,
    input           SPI_SS4,
    input           CONF_DATA0,
    // sound
    output          AUDIO_L,
    output          AUDIO_R
);

wire clk_rgb; // 36
wire clk_vga; // 25
wire locked;


parameter CONF_STR = {
    //   000000000111111111122222222223
    //   123456789012345678901234567890
        "JTGNG;;",
        "O1,Test mode,OFF,ON;",
        "O2,Cabinet mode,OFF,ON;",
        "O3,PSG ,ON,OFF;",
        "O4,FM  ,ON,OFF;",
        "O5,Screen filter,ON,OFF;",
        "T6,Reset;",
        "V,http://patreon.com/topapate;"
};

parameter CONF_STR_LEN = 7+20+23+15+15+24+9+30;

reg rst = 1'b1;

wire downloading;
// wire [4:0] index;
wire clk_rom;
wire [24:0] romload_addr;
wire [15:0] romload_data;

data_io datain (
    .sck                ( SPI_SCK      ),
    .ss                 ( SPI_SS2      ),
    .sdi                ( SPI_DI       ),
    // .index      (index        ),
    .rst                ( rst          ),
    .clk_sdram          ( clk_rom      ),
    .downloading_sdram  ( downloading  ),
    .addr_sdram         ( romload_addr ),
    .data_sdram         ( romload_data )
);

wire [7:0] status, joystick1, joystick2; //, joystick;
reg [7:0] joy1_sync, joy2_sync;
always @(posedge clk_rgb) begin
    joy1_sync <= ~joystick1;
    joy2_sync <= ~joystick2;
end

// assign joystick = joystick_0; // | joystick_1;

user_io #(.STRLEN(CONF_STR_LEN)) userio(
    .conf_str       ( CONF_STR  ),
    .SPI_SCK        ( SPI_SCK   ),
    .CONF_DATA0     ( CONF_DATA0),
    .SPI_DO         ( SPI_DO    ),
    .SPI_DI         ( SPI_DI    ),
    .joystick_0     ( joystick2 ),
    .joystick_1     ( joystick1 ),
    .status         ( status    ),
    // unused ports:
    .ps2_clk        ( 1'b0      ),
    .serial_strobe  ( 1'b0      ),
    .serial_data    ( 8'd0      ),
    .sd_lba         ( 32'd0     ),
    .sd_rd          ( 1'b0      ),
    .sd_wr          ( 1'b0      ),
    .sd_conf        ( 1'b0      ),
    .sd_sdhc        ( 1'b0      ),
    .sd_din         ( 8'd0      )
);


jtgng_pll0 clk_gen (
    .inclk0 ( CLOCK_27[0] ),
    .c1     ( clk_rgb     ), // 24
    .c2     ( clk_rom     ), // 96
    .c3     (    ), // 96 (shifted by -2.5ns)
    .locked ( locked      )
);

assign SDRAM_CLK = clk_rom;

jtgng_pll1 clk_gen2 (
    .inclk0 ( clk_rgb   ),
    .c0     ( clk_vga   ) // 25
);

reg [7:0] rst_cnt=8'd0;

always @(posedge clk_rgb) // if(cen6)
    if( rst_cnt != ~8'b0 ) begin
        rst <= 1'b1;
        rst_cnt <= rst_cnt + 8'd1;
    end else rst <= 1'b0;

wire cen6, cen3, cen1p5;

jtgng_cen u_cen(
    .clk    ( clk_rgb   ),    // 24 MHz
    .cen6   ( cen6      ),
    .cen3   ( cen3      ),
    .cen1p5 ( cen1p5    )
);

    wire [3:0] red;
    wire [3:0] green;
    wire [3:0] blue;
    wire LHBL;
    wire LVBL;
    wire signed [15:0] ym_snd;
    wire ym_mux_sample;
jtgng_game game(
    .rst         ( rst           ),
    .soft_rst    ( status[6]     ),
    .SDRAM_CLK   ( clk_rom       ),  // 96   MHz
    .clk         ( clk_rgb       ),  //  6   MHz
    .cen6        ( cen6          ),
    .cen3        ( cen3          ),
    .cen1p5      ( cen1p5        ),
    .red         ( red           ),
    .green       ( green         ),
    .blue        ( blue          ),
    .LHBL        ( LHBL          ),
    .LVBL        ( LVBL          ),

    .joystick1   ( joy1_sync     ),
    .joystick2   ( joy2_sync     ),

    .SDRAM_DQ    ( SDRAM_DQ      ),
    .SDRAM_A     ( SDRAM_A       ),
    .SDRAM_DQML  ( SDRAM_DQML    ),
    .SDRAM_DQMH  ( SDRAM_DQMH    ),
    .SDRAM_nWE   ( SDRAM_nWE     ),
    .SDRAM_nCAS  ( SDRAM_nCAS    ),
    .SDRAM_nRAS  ( SDRAM_nRAS    ),
    .SDRAM_nCS   ( SDRAM_nCS     ),
    .SDRAM_BA    ( SDRAM_BA      ),
    .SDRAM_CKE   ( SDRAM_CKE     ),
    // ROM load
    .downloading ( downloading   ),
    .romload_addr( romload_addr  ),
    .romload_data( romload_data  ),
    // DEBUG
    .enable_char ( 1'b1          ),
    .enable_scr  ( 1'b1          ),
    .enable_obj  ( 1'b1          ),
    // DIP switches
    .dip_game_mode  ( ~status[1] ),
    .dip_upright    ( status[2]  ),
    //.dip_flip     ( ~status[3] ),
    .dip_attract_snd( 1'b1       ), // 0 for sound
    // sound
    .enable_psg  ( ~status[3]    ),
    .enable_fm   ( ~status[4]    ),
    .ym_snd      ( ym_snd        ),
    .sample      (               )
);

// more resolution for sound when screen is filtered too
// not really important...
wire clk_dac = status[2] ? clk_rom : clk_rgb;
assign AUDIO_R = AUDIO_L;

// jt12_dac #(.width(16)) dac2_left (.clk(clk_dac), .rst(rst), .din(ym_snd), .dout(AUDIO_L));
//jt12_dac2 #(.width(16)) dac2_left (.clk(clk_dac), .rst(rst), .din(ym_snd), .dout(AUDIO_L));
hybrid_pwm_sd u_dac
(
    .clk    ( clk_dac   ),
    .n_reset( ~rst      ),
    .din    ( {~ym_snd[15], ym_snd[14:0]}    ),
    .dout   ( AUDIO_L   )
);

wire [5:0] GNG_R, GNG_G, GNG_B;

// convert 5-bit colour to 6-bit colour
assign GNG_R[0] = GNG_R[5];
assign GNG_G[0] = GNG_G[5];
assign GNG_B[0] = GNG_B[5];

wire vga_hsync, vga_vsync;

jtgng_vga vga_conv (
    .clk_rgb    ( clk_rgb       ), // 24 MHz
    .cen6       ( cen6          ), //  6 MHz
    .clk_vga    ( clk_vga       ), // 25 MHz
    .rst        ( rst           ),
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .en_mixing  ( ~status[5]    ),
    .vga_red    ( GNG_R[5:1]    ),
    .vga_green  ( GNG_G[5:1]    ),
    .vga_blue   ( GNG_B[5:1]    ),
    .vga_hsync  ( vga_hsync     ),
    .vga_vsync  ( vga_vsync     )
);

// include the on screen display
osd #(0,0,4) osd (
   .pclk       ( clk_vga      ),

   // spi for OSD
   .sdi        ( SPI_DI       ),
   .sck        ( SPI_SCK      ),
   .ss         ( SPI_SS3      ),

   .red_in     ( GNG_R        ),
   .green_in   ( GNG_G        ),
   .blue_in    ( GNG_B        ),
   .hs_in      ( vga_hsync    ),
   .vs_in      ( vga_vsync    ),

   .red_out    ( VGA_R        ),
   .green_out  ( VGA_G        ),
   .blue_out   ( VGA_B        ),
   .hs_out     ( VGA_HS       ),
   .vs_out     ( VGA_VS       )
);

endmodule // jtgng_mist