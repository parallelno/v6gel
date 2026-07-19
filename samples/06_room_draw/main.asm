; ---------------------------------------------------------------------------
; Demonstrates the engine's 16x16 room-tile blitter.
; ---------------------------------------------------------------------------

; Level consists of two objects: level data and level graphics.
; Level data split into rooms. Each room contains tilemap and datamap. Each
; Datamap's entity contains game mechanic info used by the engine.
; Each room data is compressed.
;

.global main

; Import engine constants, and helper macros constants.
.include "../../engine/common/v6_consts.asm"
.include "../../engine/common/v6_macros.asm"

; Include generated metadata for the font, text, and palette assets.
.include "build/06_tile_draw/palettes/asm/pal_lv0_meta.asm"


main:
            ; Fade-in the palette from black to our exported palette.
            lxi d, _pal_lv0 + _pal_lv0_palette_fade_to_black_relative
            call palette_fade_reverse

            // lxi h,
            // shld lv_rooms_pptr


			// call room_unpack
			// call room_init_tiles_gfx
			// call room_draw_tiles
            ret