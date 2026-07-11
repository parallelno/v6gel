.include "sound/v6_gc.asm"

.global v6_gc_unpack_init_play_song

.opt
; Combined funhc for convenient call from C++. Unpacks to ram-disk.
; in:
; hl - compressed source
v6_gc_unpack_init_play_song:
			RAM_DISK_ON(RAM_DISK_MUSIC)
			xchg
			lxi b, _gc_song_data
			; de - compressed data
			; bc - decompressed data
			call dzx0
			call v6_gc_init_song
			call v6_gc_start
			RAM_DISK_OFF()
			ret
.endopt