; ---------------------------------------------------------------------------
; This demo shows how to use engine-provided services:
;    * play music track
;
; Notes:
;  - the music format contains 14 commpressed streams, ech for AY register
;    supplied runtime
;  - for ROM executibles export the music track compressed (--compress) to save
;    RAM
;  - for COM executibles keep the track uncompressed to let the engine move it
;    to RAM disk while loading from FDD
;  - the exporter packs music data and produces a symbol (e.g. `_song01_data`)
;  - `v6_gc_unpack_init_play_song` unpacks the data to the RAM disk and starts
;    the built-in music player
;  - for COM executibles the metadata must be included because it provides the
;    the filename and the size
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Music format:
;
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Music metadata format:
;
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Music data format:
;
; ---------------------------------------------------------------------------


.global main

main:
            ; Unpack and start the packed song included with this sample.
            lxi h, _song01_data
            call v6_gc_unpack_init_play_song

            ; An infinite loop to keep the program running for demonstrating
            ; purposes.
@loop:      jmp @loop
