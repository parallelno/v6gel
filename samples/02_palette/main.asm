; ------------------------------------------------------------------------------
; This demo shows how to use engine-provided services:
;    * palette update
;    * palette fade
;    * use of macros for safe zero comparison and zeroing A register
; ------------------------------------------------------------------------------

; Expose `main` symbol so the linker and engine can call into this demo.
.global main

; Import engine constants, control codes, and helper macros.
.include "../../engine/common/v6_consts.asm"
.include "../../engine/common/v6_macros.asm"
.include "../../engine/controls/v6_controls_consts.asm"

; Include generated metadata for palette.
; Each asset is exported into two files:
; 1. *_meta.asm: contains relative labels to the data file and usefull constants.
;    It is usually included in the program.
; 2. *_data.asm: contains the actual bytes to be loaded into the RAM disk. It
;    can be included, linked or loaded from FDD at runtime.
; The palette asset json file fields are:
; 	"path_png" : path to the source PNG file
;	"colors_pos" : array of color positions in the PNG file to extract colors from
;       "x" : x position of the color in the PNG file
;       "y" : y position of the color in the PNG file
;	"asset_type" : "palette"
;   "fades" : array of fade animation definitions, each with:
;		"name" : name of the fade animation
;		"color" : color to fade to/from, with r,g,b values (r and g: 3 bits, b: 2 bits)
;       "iterations" : number of iterations for the fade animation, each iteration is 1/25th of a second
;       "comment" : optional comment for the fade animation
.include "build/demo_sprites/palettes/meta/pal_lv0_meta.asm"


; ---------------------------------------------------------------------------
; Entry point
; Steps performed here:
;  1. Request the engine to apply the palette stored in `v6_palette`.
;  2. Start a fade-in animation from a constant color to our exported palette.
; ---------------------------------------------------------------------------
main:
            ; By default the engine uses a black palette.
            ; Request the engine to refresh hardware palette from `v6_palette`.
            ; The engine watches `v6_palette_update_request` and applies
            ; palette data when the request value is set to `PALETTE_UPD_REQ_YES`.
            lxi d, v6_palette_update_request   ; DE = palette update request addr
            mvi a, PALETTE_UPD_REQ_YES         ; A = request value
            hlt                                 ; yield; engine will process request
@fade_in:
            ; Fade-in the palette from black to our exported palette.
            ; The meta file defines the fade animation offset
            ; label `_pal_lv0_palette_fade_to_black_relative`.
            ; The object file contains the actual data and the label that points
            ; to it in a format `_<asset_json_file_name>_data`.
            lxi d, _pal_lv0_data + _pal_lv0_palette_fade_to_black_relative
            call palette_fade_reverse

            call wait_until_any_key_pressed

@fade_out:
            ; Fade-out the palette from our exported palette to black.
            lxi d, _pal_lv0_data + _pal_lv0_palette_fade_to_black_relative
            call palette_fade

            call wait_until_any_key_pressed
            jmp @fade_in


wait_until_any_key_pressed:
            ; Delat 1/50th of a second (1 frame).
            hlt

            ; Read action code and the previous frame action code.
            lda v6_action_code
            CPI_ZERO(CONTROL_CODE_NO)
            jz wait_until_any_key_pressed
            ret
