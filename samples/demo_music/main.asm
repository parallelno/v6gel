;
.global main

palette:
    .db 0x00, 0x11, 0x22, 0x33,
    .db 0x44, 0x55, 0x66, 0x77,
    .db 0x88, 0x99, 0xAA, 0xBB,
    .db 0xCC, 0xDD, 0xEE, 0xFF


main:
            ; copy the new pallete
            lxi h, palette
            lxi d, v6_palette
            lxi b, PALETTE_LEN
            ; hl - source
            ; de - destination
            ; bc - len
            call mem_copy

            ; request the palette update
            lxi h, v6_palette_update_request
            mvi m, PALETTE_UPD_REQ_YES

            ; unpack the song data to the ram-disk and start the music player.
            lxi h, _song01_data
            call v6_gc_unpack_init_play_song

            ; update the screen color every interruption.
            lxi h, v6_palette
            lxi d, v6_palette_update_request
            mvi a, PALETTE_UPD_REQ_YES
@loop:
            ; update the screen color
            inr m
            stax d
.loop 10
            hlt
.endloop
            jmp @loop
            ret