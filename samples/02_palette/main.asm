; ------------------------------------------------------------------------------
; This demo shows how to use engine-provided services:
;    * Palette update
;    * Palette fade
;    * Use of macros for safe zero comparison and zeroing A register
; Key concepts demonstrated:
;  - using the `v6_palette_update_request` handshake to ask the engine to apply
;    the current palette stored in `v6_palette`
;  - calling `palette_fade` and `palette_fade_reverse` with offsets from the
;    exporter-provided meta file
;  - a simple frame-sync wait loop using `hlt`
; ------------------------------------------------------------------------------

; Expose `main` symbol so the linker and engine can call into this demo.
.global main

; Import engine constants, control codes, and helper macros.
.include "../../engine/common/v6_consts.asm"
.include "../../engine/common/v6_macros.asm"
.include "../../engine/controls/v6_controls_consts.asm"

; Note: Each asset in the assets folder is exported into two files:
; 1. *_meta.asm: contains relative labels to the data file and usefull constants.
;    It is usually included in the program.
; 2. *_data.asm: contains the actual bytes to be loaded into the RAM disk. It
;    can be included, linked or loaded from FDD at runtime. Each object file
;    contains a label that points to the data in a format `_<asset_json_file_name>_data`.

; The palette asset json includes the following fields:
; 	"path_png" : path to the source PNG file
;	"colors_pos" : array of color positions in the PNG file to extract colors from
;       "x" : x position of the color in the PNG file
;       "y" : y position of the color in the PNG file
;	"asset_type" : "palette"
;   "fades" : array of fade animation definitions, each with:
;		"name" : name of the fade animation
;		"color" : color to fade to/from, with r,g,b values (r and g: 3 bits, b: 2 bits)
;       "iterations" : number of iterations for the fade animation, each
;           iteration is 1/25th of a second.
;       "comment" : optional comment for the fade animation
; Check the `pal_lv0.json` file in the `assets/palettes` folder for examples.

; Include generated metadata for palette.
.include "build/demo_sprites/palettes/meta/pal_lv0_meta.asm"


; ---------------------------------------------------------------------------
; Entry point
; Steps performed here:
;  1. request palette application
;  2. run fade-in animation
;  3. wait for any key
;  4. run fade-out animation
;  5. loop
; ---------------------------------------------------------------------------
main:
            ; By default the engine uses a black palette.
            ; Request engine to refresh the hardware palette from `v6_palette`.
            lxi d, v6_palette_update_request   ; DE = palette update request addr
            mvi a, PALETTE_UPD_REQ_YES         ; A = request value
            hlt                                 ; yield; engine will process request
; `@` prefix defines a local label that can be used multiple types across the program.
; Details are in the `v6asm` documentation.
@fade_in:
            ; Fade-in the palette from black to our exported palette.
            ; The meta contains the `_pal_lv0_palette_fade_to_black_relative`
            ; relative label that points to the fade animation data in the
            ; object file. The global address where the actual data is linked
            ; provided by the linked object file in a format
            ; `_<asset_json_file_name>_data`.
            lxi d, _pal_lv0_data + _pal_lv0_palette_fade_to_black_relative
            call palette_fade_reverse

            call wait_until_any_key_pressed

@fade_out:
            ; Fade-out the palette from our exported palette to black.
            lxi d, _pal_lv0_data + _pal_lv0_palette_fade_to_black_relative
            call palette_fade

            call wait_until_any_key_pressed
            jmp @fade_in


; ---------------------------------------------------------------------------
; Utility: wait for any key press (frame-synced)
; This routine demonstrates a safe zero-check idiom using `CPI_ZERO` macro,
; details in `samples/01_controls` and `v6_macros.asm`.
; ---------------------------------------------------------------------------
wait_until_any_key_pressed:
            hlt                      ; delay 1/50th of a second (1 frame).
            lda v6_action_code       ; read current action code
            CPI_ZERO(CONTROL_CODE_NO)
            jz wait_until_any_key_pressed
            ret
