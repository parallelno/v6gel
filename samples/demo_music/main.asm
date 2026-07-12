//
.global main

main:
            lxi h, _song01_data
            call v6_gc_unpack_init_play_song

@inf_loop:
            hlt
            jmp @inf_loop
            ret