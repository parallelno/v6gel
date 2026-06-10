@memusage_v6_sound:

.include "asm/v6/sound/v6_gc.asm"
.include "asm/v6/sound/v6_sfx.asm"


; init sound
v6_sound_init:
			call v6_sfx_player_init
			call v6_gc_init
			ret

; play music and sfx
; called by the unterruption routine
v6_sound_update:
			call v6_gc_update
			call v6_sfx_update
			ret