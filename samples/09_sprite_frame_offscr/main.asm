; ------------------------------------------------------------------------------
; This demo shows how to use engine-provided services:
; TODO: update this header to reflect the sample's purpose and features.
; ------------------------------------------------------------------------------

.global main

; Import engine constants and control codes
.include "../../engine/common/v6_consts.asm"
.include "../../engine/controls/v6_controls_consts.asm"
.include "../../engine/common/v6_macros.asm"

; Include generated metadata for palette and sprite assets.
; Each asset is exported into two files:
; 1. *_meta.asm: contains relative labels to the data file and usefull constants.
;    It is usually included in the program.
; 2. *_data.asm: contains the actual bytes to be loaded into the RAM disk. It
;    can be included, linked or loaded from FDD at runtime.
.include "build/09_sprite_frame_offscr/palettes/asm/pal_lv0_meta.asm"
.include "build/09_sprite_frame_offscr/sprites/asm/knight_meta.asm"
.include "build/09_sprite_frame_offscr/levels/asm/lv0_data_meta.asm"
.include "build/09_sprite_frame_offscr/levels/asm/lv0_gfx_meta.asm"

.include "sprites.asm"

.include "frame_sync.asm"
.include "renderer_offscr.asm"
.include "misc.asm"


main:
            call set_frame_timer

            call room_init
            call room_copy_scr_to_backbuffs
            call set_palette_fadein


main_loop:
            call renderer_offscr
@cont:
            jmp main_loop