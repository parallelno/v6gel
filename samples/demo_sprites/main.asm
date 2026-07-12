; Demo: Initialize palette and play demo music
; This module prepares the system palette, unpacks and starts a
; packed song, and continuously requests palette updates so the
; engine can animate colors on each interrupt.


; Expose the `main` label to make it reachable by linker.
; Engine calls it after initialization.
.global main

; -- include palette meta data (supplied to the engine color update routine)
; It contains relative labels to the sub-data (palette, fade animation)
.include "build/demo_sprites/palettes/meta/pal_lv0_meta.asm"

main:
            ; ------------------------------------------------------------------
            ; Copy the sample palette into the engine palette area
            ; - (HL) -> source data (this file's `palette`)
            ; - (DE) -> destination `v6_palette` in engine RAM
            ; - BC      -> number of bytes to copy (PALETTE_LEN)
            ; mem_copy will copy BC bytes from (HL) to (DE).
            lxi h, _pal_lv0_data
            lxi d, v6_palette
            lxi b, PALETTE_LEN
            call mem_copy

            ; ------------------------------------------------------------------
            ; Unpack the packed song data into the RAM disk and start the
            ; music player. The symbol `_little_mermaid_data` points to the packed
            ; data included with this sample.
            lxi h, _song01_data
            call v6_gc_unpack_init_play_song

            ; ------------------------------------------------------------------
            ; Main loop: perform a small palette tweak each frame and
            ; request the engine re-apply the palette. This loop keeps the
            ; demo running while the CPU mostly idles via `hlt`.
            lxi h, v6_palette                ; HL = palette table (source)
            lxi d, v6_palette_update_request ; DE = palette update request addr
            mvi a, PALETTE_UPD_REQ_YES       ; A = request value

main_loop:
            ; increment a palette byte to animate colors
            inr m
            ; notify engine to apply the palette change
            stax d

            ; this macros expands to a ten hlt instructions.
        .loop 10
            hlt
        .endloop

            jmp main_loop
            ret