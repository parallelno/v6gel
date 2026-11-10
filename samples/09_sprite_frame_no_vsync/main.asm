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
.include "build/09_sprite_frame_no_vsync/palettes/asm/pal_lv0_meta.asm"
.include "build/09_sprite_frame_no_vsync/sprites/asm/knight_meta.asm"
.include "build/09_sprite_frame_no_vsync/levels/asm/lv0_data_meta.asm"
.include "build/09_sprite_frame_no_vsync/levels/asm/lv0_gfx_meta.asm"

.include "sprites.asm"

.include "frame_sync.asm"
.include "backbuf_renderer.asm"
.include "direct_renderer.asm"
.include "misc.asm"


main:
            call set_frame_timer

            call room_init
            call room_copy_scr_to_backbuffs
            call set_palette_fadein


main_loop:
            ; if UP pressed, render directly to the screen,
            ; otherwise render to the back buffer, then copy to the screen.
            ; lda v6_action_code
            ; ani CONTROL_CODE_UP
            ; jnz @render_to_scr
            ;call backbuf_renderer
            ;jmp @cont
@render_to_scr:
            call direct_renderer
@cont:
            jmp main_loop