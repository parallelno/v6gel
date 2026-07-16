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


; ---------------------------------------------------------------------------
; Entry point
; Steps performed here:
;  1.
; ---------------------------------------------------------------------------
main:
            ; ------------------------------------------------------------------
            ; Unpack the packed song data into the RAM disk and start the
            ; music player. The symbol `_song01_data` points to the packed
            ; data included with this sample.
            lxi h, _song01_data
            call v6_gc_unpack_init_play_song

@loop:
            jmp @loop
            ret
