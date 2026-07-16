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
; Source format:
;   The exporter requires input in YM format (AY-3-8910 register dump).
;   To generate YM files, use the included `tools\ay_emul` utility to
;   convert tracker music, or use the `audio2ay3` project
;   (`github.com/parallelno/audio2ay3`) to convert MP3 files.
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Music format:
;   Source file: a YM6 dump of AY-3-8910 register values, one value per frame
;   for each of the 14 AY registers (R0..R13).
;
;   The exporter splits the dump into 14 independent per-register byte streams
;   and ZX0-compresses each stream individually using a 256-byte sliding window.
;   This per-channel compression is part of the *runtime format*: the GigaChad
;   player decompresses one stream per frame through a 256-byte ring buffer, so
;   the player never needs the full uncompressed data in RAM at once.
;
;   The final asset consists of two files:
;     <name>_meta.asm  — linked into the program; provides file size / filename
;     <name>.bin       — the data blob; linked into ROM or loaded from FDD
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Music metadata format:
;   The *_meta.asm file is always linked into the main program and exposes:
;
;     <NAME>_FILE_LEN        .filesize of the .bin blob (resolved at link time)
;     <NAME>_LAST_RECORD_LEN FILE_LEN & 0x7F  (size of the last CP/M record)
;     <NAME>_FILENAME_PTR    CP/M 8.3 filename string (only present when the
;                            asset was exported with --emit-filename; required
;                            for COM executables that load the blob from FDD)
;
;   ROM executables link the blob directly and only need FILE_LEN/LAST_RECORD_LEN.
;   COM executables also use FILENAME_PTR to locate the file on the disk.
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Music data format:
;   The .bin blob is org'd at 0 and must be loaded to _gc_song_data on the
;   RAM Disk (base GC_RUNTIME_DATA_RD = 0x8000).  Full RAM Disk layout:
;
;     0x8000  14 × 256 B   Decompression ring buffers, one per AY register
;                          (zeroed by v6_gc_init_song before playback)
;     0x8E00  14 × 16 B    GC task stacks, one per channel
;                          (zeroed by v6_gc_init_song before playback)
;     0x8EE0  _gc_song_data — music blob starts here:
;       +0x00  14 × word    Pointer table: absolute RAM Disk addresses of each
;                           compressed stream (pre-computed by the exporter)
;       +0x1C  variable     14 ZX0-compressed AY register streams (R0..R13),
;                           stored back-to-back in register order
;
;   At runtime v6_gc_init_song uses the pointer table to hand each GC task the
;   address of its stream.  v6_gc_start then launches all 14 tasks; each frame
;   v6_gc_update advances one task, decompressing 16 bytes into its ring buffer
;   and writing the resulting register value to the AY chip.
; ---------------------------------------------------------------------------


.global main

main:
            ; Unpack and start the packed song included with this sample.
            lxi h, _song01_data
            call v6_gc_unpack_init_play_song

            ; An infinite loop to keep the program running for demonstrating
            ; purposes.
@loop:      jmp @loop
