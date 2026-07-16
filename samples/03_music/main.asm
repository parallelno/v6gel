; ---------------------------------------------------------------------------
; This demo shows how to use engine-provided services:
;    * play music track
;
; Key concepts demonstrated:
;  - the exporter packs music data and produces a symbol (e.g. `_song01_data`)
;  - `v6_gc_unpack_init_play_song` unpacks the data to the RAM disk and starts
;    the built-in music player
; ---------------------------------------------------------------------------

.global main

; NOTE: the exporter produces meta/object files in `build\03_music\music\...`.
; The packed data symbol `_song01_data` is available after linking the
; exported object produced by the build script.

main:
            ; Unpack and start the packed song included with this sample.
            lxi h, _song01_data
            call v6_gc_unpack_init_play_song

            ; An infinite loop to keep the program running for demonstrating
            ; purposes.
@loop:      jmp @loop
