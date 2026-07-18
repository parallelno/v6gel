; Demo: Initialize palette and play demo music
; This module prepares the system palette, unpacks and starts a
; packed song, and continuously requests palette updates so the
; engine can animate colors on each interrupt.


; Expose the `main` label to make it reachable by linker.
; Engine calls it after initialization.
.global main

; -- full 16 byte palette data (supplied to the engine color update routine)
palette:
    .db 0x00, 0x11, 0x22, 0x33
    .db 0x44, 0x55, 0x66, 0x77
    .db 0x88, 0x99, 0xAA, 0xBB
    .db 0xCC, 0xDD, 0xEE, 0xFF

main:
            ; ------------------------------------------------------------------
            ; Copy the sample palette into the engine palette area
            ; - (HL) -> source data (this file's `palette`)
            ; - (DE) -> destination `v6_palette` in engine RAM
            ; - BC      -> number of bytes to copy (PALETTE_LEN)
            ; mem_copy will copy BC bytes from (HL) to (DE).
            lxi h, palette
            lxi d, v6_palette
            lxi b, PALETTE_LEN
            call mem_copy

            ; ------------------------------------------------------------------
            ; Unpack the packed song data into the RAM disk and start the
            ; music player. The symbol `_little_mermaid` points to the packed
            ; data included with this sample.
            lxi h, _little_mermaid
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