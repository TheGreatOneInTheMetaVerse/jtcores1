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
    Date: 6-8-2021 */

module jtexed_game(
    input           rst,
    input           clk,
    output          pxl2_cen,   // 12   MHz
    output          pxl_cen,    //  6   MHz
    output   [3:0]  red,
    output   [3:0]  green,
    output   [3:0]  blue,
    output          LHBL,
    output          LVBL,
    output          LHBL_dly,
    output          LVBL_dly,
    output          HS,
    output          VS,
    // cabinet I/O
    input   [ 1:0]  start_button,
    input   [ 1:0]  coin_input,
    input   [ 5:0]  joystick1,
    input   [ 5:0]  joystick2,
    // SDRAM interface
    input           downloading,
    output          dwnld_busy,
    output          sdram_req,
    output  [21:0]  sdram_addr,
    input   [15:0]  data_read,
    input           data_dst,
    input           data_rdy,
    input           sdram_ack,
    // ROM LOAD
    input   [24:0]  ioctl_addr,
    input   [ 7:0]  ioctl_dout,
    input           ioctl_wr,
    output  [21:0]  prog_addr,
    output  [ 7:0]  prog_data,
    output  [ 1:0]  prog_mask,
    output          prog_we,
    output          prog_rd,
    // DIP switches
    input   [31:0]  status,     // only bits 31:16 are looked at
    input           service,
    input           dip_pause,
    inout           dip_flip,
    input           dip_test,
    input   [ 1:0]  dip_fxlevel, // Not a DIP on the original PCB
    input   [31:0]  dipsw,
    // Sound output
    output  signed [15:0] snd,
    output          sample,
    output          game_led,
    input           enable_psg,
    input           enable_fm,
    // Debug
    input   [3:0]   gfx_en
);

// These signals are used by games which need
// to read back from SDRAM during the ROM download process
assign prog_rd    = 1'b0;
assign dwnld_busy = downloading;

wire [8:0] V;
wire [8:0] H;
wire HINIT;

wire [12:0] cpu_AB;
wire snd_cs, map1_cs, map2_cs;
wire char_cs, blue_cs, redgreen_cs;
wire flip;
wire [7:0] cpu_dout, char_dout, scr_dout;
wire [15:0] scr2_hpos;
wire rd, cpu_cen;
wire char_busy, scr_busy;

localparam SCRW=18, SCR2W=15, OBJW=18;

// ROM data
wire [15:0] char_data, scr_data, scr2_data, map1_data, map2_data;
wire [15:0] obj_data;
wire [ 7:0] main_data;
wire [ 7:0] snd_data;

// ROM address
wire [16:0] main_addr;
wire [14:0] snd_addr;

wire [12:0] map1_addr;
wire [11:0] map2_addr;

wire [12:0] char_addr;
wire [SCRW-1:0] scr_addr;
wire [SCR2W-1:0] scr2_addr;
wire [OBJW-1:0] obj_addr;
wire [ 7:0] dipsw_a, dipsw_b;

wire main_ok, snd_ok, obj_ok, obj_ok0;
wire cen12, cen8, cen6, cen3, cen1p5;

wire char_on, scr1_on, scr2_on, obj_on;

// PROMs
reg  [8:0] prom_we; // 7-0 = video, 8=interrupt vectors
wire       prom_sel_we;

assign pxl2_cen = cen12;
assign pxl_cen  = cen6;

assign sample=1'b1;

assign {dipsw_b, dipsw_a} = dipsw[15:0];
assign dip_flip = ~flip;

always @(*) begin
    prom_we = 0;
    if( prom_sel_we ) prom_we[ ioctl_addr[10:7] ] = 1;
end

jtframe_cen48 u_cen(
    .clk    ( clk       ),
    .cen12  ( cen12     ),
    .cen6   ( cen6      ),
    .cen3   ( cen3      ),
    .cen1p5 ( cen1p5    ),
    // unused:
    .cen16  (           ),
    .cen8   ( cen8      ),
    .cen4   (           ),
    .cen4_12(           ),
    .cen3q  (           ),
    .cen12b (           ),
    .cen6b  (           ),
    .cen3b  (           ),
    .cen3qb (           ),
    .cen1p5b(           )
);

wire LHBL_obj, LVBL_obj;

jtgng_timer #(.LAYOUT(6)) u_timer(
    .clk       ( clk      ),
    .cen6      ( cen6     ),
    .V         ( V        ),
    .H         ( H        ),
    .Hinit     ( HINIT    ),
    .LHBL      ( LHBL     ),
    .LHBL_obj  ( LHBL_obj ),
    .LVBL      ( LVBL     ),
    .LVBL_obj  ( LVBL_obj ),
    .HS        ( HS       ),
    .VS        ( VS       ),
    .Vinit     (          )
);

wire RnW;
// sound
wire sres_b, snd_int;
wire [7:0] snd_latch;

wire        main_cs;
// OBJ
wire OKOUT, blcnten, bus_req, bus_ack;
wire [ 8:0] obj_AB;
wire [ 7:0] main_ram, game_cfg;

localparam [21:0] CPU_OFFSET  = 22'h0;
localparam [21:0] SND_OFFSET  = 22'h1_8000 >> 1;
localparam [21:0] MAP1_OFFSET = 22'h2_4000 >> 1;
localparam [21:0] MAP2_OFFSET = 22'h2_4000 >> 1;
localparam [21:0] CHAR_OFFSET = 22'h4_0000 >> 1;
localparam [21:0] SCR1_OFFSET = 22'h4_4000 >> 1;
localparam [21:0] SCR2_OFFSET = 22'h2_C000 >> 1;
localparam [21:0] OBJ_OFFSET  = 22'h8_4000 >> 1;
localparam [21:0] PROM_OFFSET = 22'h8_4000;

jtframe_dwnld #(.PROM_START(PROM_OFFSET)) u_dwnld(
    .clk          ( clk          ),
    .downloading  ( downloading  ),
    .ioctl_addr   ( ioctl_addr   ),
    .ioctl_dout   ( ioctl_dout   ),
    .ioctl_wr     ( ioctl_wr     ),
    .prog_addr    ( prog_addr    ),
    .prog_data    ( prog_data    ),
    .prog_mask    ( prog_mask    ), // active low
    .prog_we      ( prog_we      ),
    .prom_we      ( promsel_we   ),
    .header       ( header       ),
    .sdram_ack    ( sdram_ack    )
);

wire scr_cs;
wire [8:0] scr_hpos, scr_vpos;


`ifndef NOMAIN

jtcommando_main #(.GAME(3)) u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cpu_cen    ( cpu_cen       ),
    .cen_sel    ( 1'b0          ), // 3MHz CPU
    // Timing
    .flip       ( flip          ),
    .V          ( V             ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .H1         ( H[0]          ),
    // sound
    .sres_b     ( sres_b        ),
    .snd_latch  ( snd_latch     ),
    .snd_int    ( snd_int       ),
    // Palette - unused
    .redgreen_cs(               ),
    .blue_cs    (               ),
    // Layer enable bits
    .char_on    ( char_on       ),
    .scr1_on    ( scr1_on       ),
    .scr2_on    ( scr2_on       ),
    .obj_on     ( obj_on        ),
    // CHAR
    .char_dout  ( char_dout     ),
    .cpu_dout   ( cpu_dout      ),
    .char_cs    ( char_cs       ),
    .char_busy  ( char_busy     ),
    // SCROLL
    .scr_dout   ( scr_dout      ),
    .scr_cs     ( scr_cs        ),
    .scr_busy   ( scr_busy      ),
    .scr_hpos   ( scr_hpos      ),
    .scr_vpos   ( scr_vpos      ),
    // SCROLL 2
    .scr2_hpos  ( scr2_hpos     ),
    // OBJ - bus sharing
    .obj_AB     ( obj_AB        ),
    .cpu_AB     ( cpu_AB        ),
    .ram_dout   ( main_ram      ),
    .OKOUT      ( OKOUT         ),
    .blcnten    ( blcnten       ),
    .bus_req    ( bus_req       ),
    .bus_ack    ( bus_ack       ),
    // ROM
    .rom_cs     ( main_cs       ),
    .rom_addr   ( main_addr     ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),
    // Cabinet input
    .start_button( start_button ),
    .coin_input  ( coin_input   ),
    .service     ( service      ),
    .joystick1   ( joystick1[5:0] ),
    .joystick2   ( joystick2[5:0] ),

    .RnW        ( RnW           ),
    // PROM 6L (interrupts)
    .prog_addr  ( 8'd0          ),
    .prom_6l_we ( 1'b0          ),
    .prog_din   ( 4'd0          ),
    // DIP switches
    .dip_pause  ( dip_pause     ),
    .dipsw_a    ( dipsw_a       ),
    .dipsw_b    ( dipsw_b       )
);
`else
assign main_addr   = 17'd0;
assign char_cs     = 1'b0;
assign scr_cs      = 1'b0;
assign bus_ack     = 1'b0;
assign flip        = 1'b0;
assign RnW         = 1'b1;
assign scr_hpos    = 9'd0;
assign scr_vpos    = 9'd0;
assign cpu_cen     = cen3;
`endif

`ifndef NOSOUND
jt1942_sound u_sound (
    .rst            ( rst            ),
    .clk            ( clk            ),
    .cen3           ( cen3           ),
    .cen1p5         ( cen1p5         ),
    .sres_b         ( 1'b1           ),
    .main_dout      ( cpu_dout       ),
    .main_latch0_cs (                ),
    .main_latch1_cs (                ),
    .snd_latch      ( snd_latch      ),
    .snd_int        ( snd_int        ),
    .rom_cs         ( snd_cs         ),
    .rom_addr       ( snd_addr       ),
    .rom_data       ( snd_data       ),
    .rom_ok         ( snd_ok         ),
    .snd            ( snd            )
);
`else
assign snd_addr = 15'd0;
assign snd      = 16'd0;
assign snd_cs   = 1'b0;
`endif

wire scr_ok, scr2_ok, map1_ok, map2_ok, char_ok;

reg pause;
always @(posedge clk) pause <= ~dip_pause;

jtexed_video #(
    .SCRW   ( SCRW      ),
    .OBJW   ( OBJW      )
)
u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen12      ( cen12         ),
    .cen8       ( cen8          ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cpu_cen    ( cpu_cen       ),
    .cpu_AB     ( cpu_AB[11:0]  ),
    .game_sel   ( game_cfg[0]   ),
    .V          ( V             ),
    .H          ( H             ),
    .RnW        ( RnW           ),
    .flip       ( flip          ),
    .cpu_dout   ( cpu_dout      ),
    // Layer enable
    .char_on    ( char_on       ),
    .scr1_on    ( scr1_on       ),
    .scr2_on    ( scr2_on       ),
    .obj_on     ( obj_on        ),
    // CHAR
    .char_cs    ( char_cs       ),
    .char_dout  ( char_dout     ),
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .char_busy  ( char_busy     ),
    .char_ok    ( char_ok       ),
    // SCROLL 1 - ROM
    .scr_cs     ( scr_cs        ),
    .scr_dout   ( scr_dout      ),
    .scr_addr   ( scr_addr      ),
    .scr_data   ( scr_data      ),
    .scr_busy   ( scr_busy      ),
    .scr_hpos   ( scr_hpos      ),
    .scr_vpos   ( scr_vpos      ),
    .scr_ok     ( scr_ok        ),
    .map1_addr  ( map1_addr     ), // 16kB in 8 bits or 8kW in 16 bits
    .map1_data  ( map1_data     ),
    .map1_cs    ( map1_cs       ),
    .map1_ok    ( map1_ok       ),
    // SCROLL 2
    .scr2_hpos  ( scr2_hpos     ),
    .scr2_addr  ( scr2_addr     ),
    .scr2_data  ( scr2_data     ),
    .map2_addr  ( map2_addr     ), // 8kB in 8 bits or 4kW in 16 bits
    .map2_data  ( map2_data     ),
    .map2_cs    ( map2_cs       ),
    .map2_ok    ( map2_ok       ),
    // OBJ
    .HINIT      ( HINIT         ),
    .obj_AB     ( obj_AB        ),
    .main_ram   ( main_ram      ),
    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),
    .obj_ok     ( obj_ok        ),
    .OKOUT      ( OKOUT         ),
    .bus_req    ( bus_req       ), // Request bus
    .bus_ack    ( bus_ack       ), // bus acknowledge
    .blcnten    ( blcnten       ), // bus line counter enable
    // PROMs
    .prog_addr    ( prog_addr[7:0] ),
    .prom_we      ( prom_we[8:0]   ),
    .prom_din     ( prog_data      ),
    // Color Mix
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .LHBL_obj   ( LHBL_obj      ),
    .LVBL_obj   ( LVBL_obj      ),
    .LHBL_dly   ( LHBL_dly      ),
    .LVBL_dly   ( LVBL_dly      ),
    .gfx_en     ( gfx_en        ),
    // Pixel Output
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

// Scroll data: Z, Y, X
jtframe_rom #(
    .SLOT0_AW    ( 13              ), // Char
    .SLOT1_AW    ( SCRW            ), // Scroll
    .SLOT2_AW    ( 12              ), // Scroll 2 Map
    .SLOT3_AW    ( SCR2W           ), // Scroll 2
    .SLOT4_AW    ( 13              ), // Scroll 1 Map
    .SLOT6_AW    ( 15              ), // Sound
    .SLOT7_AW    ( 17              ), // Main
    .SLOT8_AW    ( OBJW            ), // OBJ

    .SLOT0_DW    ( 16              ), // Char
    .SLOT1_DW    ( 16              ), // Scroll
    .SLOT2_DW    ( 16              ), // Scroll Map
    .SLOT3_DW    ( 16              ), // Scroll 2
    .SLOT4_DW    ( 16              ), // Scroll 1 Map
    .SLOT6_DW    (  8              ), // Sound
    .SLOT7_DW    (  8              ), // Main
    .SLOT8_DW    ( 16              ), // OBJ

    .SLOT0_OFFSET( CHAR_OFFSET ),
    .SLOT1_OFFSET( SCR1_OFFSET ),
    .SLOT2_OFFSET( MAP2_OFFSET ),
    .SLOT3_OFFSET( SCR2_OFFSET ),
    .SLOT4_OFFSET( MAP1_OFFSET ),
    .SLOT6_OFFSET( SND_OFFSET  ),
    .SLOT7_OFFSET( CPU_OFFSET  ),
    .SLOT8_OFFSET( OBJ_OFFSET  )
) u_rom (
    .rst         ( rst           ),
    .clk         ( clk           ),

    .slot0_cs    ( LVBL          ), // Char
    .slot1_cs    ( LVBL          ), // Scroll
    .slot2_cs    ( map2_cs       ), // Map 2
    .slot3_cs    ( LVBL          ), // Map 1
    .slot4_cs    ( map1_cs       ),
    .slot5_cs    ( 1'b0          ),
    .slot6_cs    ( snd_cs        ),
    .slot7_cs    ( main_cs       ),
    .slot8_cs    ( 1'b1          ), // OBJ

    .slot0_ok    ( char_ok       ),
    .slot1_ok    ( scr_ok        ),
    .slot2_ok    ( map2_ok       ),
    .slot3_ok    ( scr2_ok       ),
    .slot4_ok    ( map1_ok       ),
    .slot5_ok    (               ),
    .slot6_ok    ( snd_ok        ),
    .slot7_ok    ( main_ok       ),
    .slot8_ok    ( obj_ok        ),

    .slot0_addr  ( char_addr     ),
    .slot1_addr  ( scr_addr      ),
    .slot2_addr  ( map2_addr     ),
    .slot3_addr  ( scr2_addr     ),
    .slot4_addr  ( map1_addr     ),
    .slot5_addr  (               ),
    .slot6_addr  ( snd_addr      ),
    .slot7_addr  ( main_addr     ),
    .slot8_addr  ( obj_addr      ),

    .slot0_dout  ( char_data     ),
    .slot1_dout  ( scr_data      ),
    .slot2_dout  ( map2_data     ),
    .slot3_dout  ( scr2_data     ),
    .slot4_dout  ( map1_data     ),
    .slot5_dout  (               ),
    .slot6_dout  ( snd_data      ),
    .slot7_dout  ( main_data     ),
    .slot8_dout  ( obj_data      ),

    // SDRAM interface
    .sdram_req   ( sdram_req     ),
    .sdram_ack   ( sdram_ack     ),
    .data_dst    ( data_dst      ),
    .data_rdy    ( data_rdy      ),
    .downloading ( downloading   ),
    .sdram_addr  ( sdram_addr    ),
    .data_read   ( data_read     )
);

endmodule