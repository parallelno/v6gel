; ---------------------------------------------------------------------------
; This demo shows how to use engine-provided services:
;    * play music track
;
; Notes:
;  - for ROM executibles export the music track compressed (--compress) to save
;    RAM
;  - for COM executibles keep the track uncompressed to let the engine move it
;    to RAM disk while loading from FDD
;  - the exporter packs music data and produces a symbol (e.g. `_song01`)
;  - for COM executibles the metadata must be included because it provides the
;    the filename and the size
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Source format:
;   The exporter requires input in YM format (AY-3-8910 register dump).
;   To generate YM files, use the included `tools\ay_emul` utility to
;   convert tracker music, or use the `audio2ay3` project
;   (`github.com/parallelno/audio2ay3`) to convert MP3 files (in this sample).
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
;     <name>_meta.asm  — provides file size / filename (for COM apps only)
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
;   ROM executables do not need it.
;   COM executables use FILENAME_PTR to locate the file on the disk.
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

; ---------------------------------------------------------------------------
; Player API
;  v6_gc_start - starts a new song / repeat finished song.
;   call from interruption CALL_RAM_DISK_FUNC_NO_RESTORE(v6_gc_start, RAM_DISK_MUSIC)
;   call from main program CALL_RAM_DISK_FUNC(v6_gc_start, RAM_DISK_MUSIC)
;  v6_gc_pause - pause the player
;  v6_gc_unpause - unpause the player
;  v6_gc_flip_pause - flip pause/unpause
;  v6_gc_unpack_init_play_song - unpacks the data to the RAM disk and starts
;    the built-in music player. Usable only for ROMs, COMs loads uncompressed
;    track BIN to be able to move them to the RAM disk.
; ---------------------------------------------------------------------------

; Import engine constants, control codes, and helper macros, and utility functions.
.include "../../engine/common/v6_consts.asm"
.include "../../engine/common/v6_macros.asm"
.include "../../engine/controls/v6_controls_consts.asm"
.include "../common/utils.asm"

.global main

main:
            ; Unpack and start the packed song included with this sample.
            lxi h, _song01
            call v6_gc_unpack_init_play_song

@loop:
            call wait_until_any_key_pressed
            ani CONTROL_CODE_KEY_SPACE
            jnz @flip_pause
@start:
            call v6_gc_pause
            CALL_RAM_DISK_FUNC(v6_gc_start, RAM_DISK_MUSIC)
            jmp @loop

@flip_pause:
			call v6_gc_flip_pause
            jmp @loop
