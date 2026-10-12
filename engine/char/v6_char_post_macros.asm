; char initialization
; in:
; c - tile_idx in the room_tiledata array.
; a - char_id * 4
; out:
; a - TILEDATA_RESTORE_TILE
;ex. CHAR_INIT(knight_update, knight_draw, char_impacted, KNIGHT_HEALTH, ACTOR_STATUS_KNIGHT_DETECT_HERO_INIT, knight_idle_anim)
.macro CHAR_INIT(CHAR_UPDATE_PTR, CHAR_DRAW_PTR, CHAR_IMPACT_PTR, CHAR_HEALTH, CHAR_STATUS, CHAR_ANIM_PTR, spawn_rate_check = True, _char_type = CHAR_TYPE_ENEMY, jmp_ = True)
			lxi h, @char_init_data
		.if spawn_rate_check
			mvi b, 1
		.endif
		.if spawn_rate_check == false
			mvi b, 0
		.endif

		.if jmp_
			jmp char_init
		.endif
		.if jmp_ == false
			call char_init
		.endif

			.word TEMP_WORD  ; safety word because an interruption can call
@char_init_data:
			.word CHAR_IMPACT_PTR, _char_type, CHAR_STATUS<<8 | CHAR_HEALTH
			.word CHAR_UPDATE_PTR, CHAR_DRAW_PTR, CHAR_ANIM_PTR
.endmacro