; ---------------------------------------------------------------------------
; This demo shows how to use engine-provided services:
;    * draw text with a non-monospaced font
; Notes:
;   - The font and text source files are JSON assets exported by v6gel.
;   - The font asset contains the glyph graphics and metadata needed by the
;     text drawing routines. The text asset contains encoded text and layout
;     data that can be referenced by local labels.
;   - Text can be drawn using the default screen address and spacing, or those
;     settings can be changed with the text_ex API before drawing.
;   - This demo uses the `RAM_DISK_OFF_CMD` RAM-disk access command because
;     the data doesn't require copying from the RAM disk.
;   - For ROM executables: to reduce memory footprint, you would want to compress
;     the data, link it to the ROM, uncompress it to the RAM disk at runtime,
;     and then draw it with a proper RAM disk access command.
;   - For COM executables: to reduce memory footprint, consider loading assets
;     from the FDD at runtime instead of keeping everything included to ROM file.
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Font asset format:
;   The source asset (``assets/fonts/sys_font/font.json``) contains font
;   metadata, including the source graphics path, palette path, and asset type.
;   The exported font metadata provides `font_gfx_ptrs` and
;   `font_global_gfx_addr` labels used to initialize the text drawing routines.
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Text asset format:
;   The source asset (``assets/text/txt_menu.json``) contains text data. The
;   exporter generates text metadata and data files. Labels such as
;   `_demo_test_text` point to text entries inside the data blob.
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Font metadata format:
;   The generated `*_meta.asm` file TODO
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Text metadata format:
;   The generated `*_meta.asm` file TODO
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Font data format:
;   The generated font data contains TODO
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Text data format:
;   The generated text data contains TODO
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Text Ex API
;  `text_ex_reset_spacing` - reset line and paragraph spacing to default values.
;  `text_ex_set_spacing`   - set line and paragraph spacing
;                            (C = line spacing, B = paragraph spacing).
;  `text_ex_set_scr_addr`  - set the high byte of screen buffer address (A =
;                            >SCR_BUFF3_ADD, >SCR_BUFF2_ADDR, >SCR_BUFF1_ADDR,
;                            default >SCR_BUFF1_ADDR).
;  `text_ex_init_font`     - initialize the font graphics data (A = RAM disk
;                            access command, HL = font_gfx_ptrs, BC = font global
;                            gfx addr, points to where gfx was loaded or linked).
;  `text_ex_init_text`     - initialize the text data (A = RAM disk access
;                            command, HL = text data addr, points to the addr
;                            where it was loaded or linked).
;  `text_ex_draw`          - draw the text (DE = local text addr within the text
;                            data blob).
;  `text_ex_draw_pos_offset_set` - drawing the text with a position offset (DE =
;                            local text addr within the text data blob, HL =
;                            scr_pos offset).
; ---------------------------------------------------------------------------

; Import engine constants, helper macros, and text drawing constants.
.include "../../engine/common/v6_consts.asm"
.include "../../engine/common/v6_macros.asm"
.include "../../engine/gfx/v6_text_ex_consts.asm"

; Include generated metadata for the font, text, and palette assets.
.include "build/05_text_ex/fonts/asm/font_meta.asm"
.include "build/05_text_ex/text/asm/txt_menu_meta.asm"
.include "build/04_tiled_img/palettes/asm/pal_lv1_meta.asm"

.global main

main:
            ; Fade in animation from the constant color to the exported palette.
            lxi d, _pal_lv1 + _pal_lv1_palette_fade_to_black_relative
            call palette_fade_reverse

            ; Register the font graphics and its glyph pointer table.
            A_TO_ZERO(RAM_DISK_OFF_CMD)
            lxi h, font_gfx_ptrs
            lxi b, _font
            call text_ex_init_font

            ; Register the encoded text data used by the demo.
            A_TO_ZERO(RAM_DISK_OFF_CMD)
            lxi h, _txt_menu
            call text_ex_init_text

            ; Draw to screen buffer 2 instead of the default screen buffer 1.
            mvi a, >SCR_BUFF2_ADDR
            call text_ex_set_scr_addr

            ; Draw the text entry referenced by its local data label.
            lxi d, _demo_test_text
            call text_ex_draw

            ret
