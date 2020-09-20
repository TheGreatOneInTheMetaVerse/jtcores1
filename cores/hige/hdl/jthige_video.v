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
    Date: 20-9-2020 */

module jthige_video(
    input               rst,
    input               clk,
    input               pxl_cen,
    input               cen3,
    input               cpu_cen,
    input       [10:0]  cpu_AB,
    input       [ 7:0]  V,
    input       [ 8:0]  H,
    input               rd_n,
    input               wr_n,
    input               flip,
    input       [ 7:0]  cpu_dout,
    // CHAR
    input               char_cs,
    output      [ 7:0]  chram_dout,
    output      [11:0]  char_addr,
    input       [15:0]  char_data,
    output              char_busy,
    input               char_ok,
    // OBJ
    input               obj_cs,
    input               HINIT,
    output      [14:0]  obj_addr,
    input       [15:0]  obj_data,
    input               obj_ok,
    // Color Mix
    input               LVBL,
    input               LHBL,
    output              LHBL_dly,
    output              LVBL_dly,
    input               LHBL_obj,
    output      [2:0]   red,
    output      [2:0]   green,
    output      [2:0]   blue,
    // PROM access
    input       [7:0]   prog_addr,
    input       [7:0]   prom_addr, // corrected by subtractinc 0x20
    input       [7:0]   prog_din,
    input               prom_char_we,
    input               prom_obj_we,
    input               prom_pal_we,
    // Debug
    input       [3:0]   gfx_en
);

localparam COFFSET = 9'd5,
           OBJ_DLY = 4;

wire [3:0] char_pxl, obj_pxl;

`ifndef NOCHAR
jtgng_char #(
    .HOFFSET ( COFFSET ),
    .ROM_AW  ( 12      ),
    .IDMSB1  (  7      ),
    .IDMSB0  (  7      ),
    .PALW    (  5      ),
    .HFLIP_EN(  0      ),   // Higemaru does not have character H flip
    .VFLIP_EN(  0      ),   // Higemaru does not have character V flip
    .PALETTE (  1      ),
    .PALETTE_SIMFILE( "../../../rom/hige/hgb5.m4" )
) u_char (
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .cpu_cen    ( cpu_cen       ),
    .AB         ( cpu_AB        ),
    .V          ( V             ),
    .H          ( H[7:0]        ),
    .flip       ( flip          ),
    .din        ( cpu_dout      ),
    .dout       ( chram_dout    ),
    // Bus arbitrion
    .char_cs    ( char_cs       ),
    .wr_n       ( wr_n          ),
    .busy       ( char_busy     ),
    .dseln      (               ),
    // Pause screen
    .pause      ( 1'b0          ),
    .scan       (               ),
    .msg_low    (               ),
    .msg_high   (               ),
    // PROM access
    .prog_addr  ( prom_addr     ), // corrected address
    .prog_din   ( prog_din[3:0] ),
    .prom_we    ( prom_char_we  ),
    // ROM
    .char_addr  ( char_addr     ),
    .rom_data   ( char_data     ),
    .rom_ok     ( char_ok       ),
    // Pixel output
    .char_on    ( 1'b1          ),
    .char_pxl   ( char_pxl      )
);
`else
assign char_addr = 12'd0;
assign char_pxl  = 4'hf;
assign char_wait_n = 1'b1;
assign char_pxl = 4'hf;
`endif

jt1942_obj #(.PXL_DLY(OBJ_DLY), .KEEP_ORDER(1)) u_obj(
    .rst            ( rst       ),
    .clk            ( clk       ),
    .cen6           ( pxl_cen   ),
    .cen3           ( cen3      ),
    .cpu_cen        ( cpu_cen   ),
    // screen
    .HINIT          ( HINIT     ),
    .LHBL           ( LHBL_obj  ),
    .LVBL           ( LVBL      ),
    .V              ( V         ),
    .H              ( H         ),
    .flip           ( flip      ),
    // CPU bus
    .AB             ( cpu_AB[6:0] ),
    .DB             ( cpu_dout    ),
    .obj_cs         ( obj_cs      ),
    .wr_n           ( wr_n        ),
    // SDRAM interface
    .obj_addr       ( obj_addr    ),
    .obj_data       ( obj_data    ),
    .obj_ok         ( obj_ok      ),
    // PROMs
    .prog_addr      ( prom_addr   ), // corrected address
    .prom_m11_we    ( 1'b0        ), // unused
    .prom_pal_we    ( prom_obj_we ),
    .prog_din       ( prog_din[3:0] ),
    // pixel output
    .obj_pxl        ( obj_pxl   )
);


jthige_colmix u_colmix (
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .LVBL       ( LVBL          ),
    .LHBL       ( LHBL          ),
    .LHBL_dly   ( LHBL_dly      ),
    .LVBL_dly   ( LVBL_dly      ),
    // pixel input from generator modules
    .char_pxl   ( char_pxl      ),
    .obj_pxl    ( obj_pxl       ),
    // Palette PROMs E8, E9, E10
    .prog_addr  ( prog_addr     ), // uncorrected address
    .prom_pal_we( prom_pal_we   ),
    .prom_din   ( prog_din      ),

    // DEBUG
    .gfx_en     ( gfx_en        ),

    // output
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

endmodule