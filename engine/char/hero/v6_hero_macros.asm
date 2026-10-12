; checks collision between a char and a hero, apply damage to the hero health
; ex CHAR_CHECK_COLLISION_HERO(VAMPIRE_COLLISION_WIDTH, VAMPIRE_COLLISION_HEIGHT, VAMPIRE_DAMAGE)
; in:
; hl points to char_anim_ptr
; uses:
; bc, de, hl, a
; think of converting this macro into a func. it'll save 168 bytes.
.macro CHAR_CHECK_COLLISION_HERO(CHAR_COLLISION_WIDTH, CHAR_COLLISION_HEIGHT, CHAR_DAMAGE)
			; hl points to char_anim_ptr
			; advance hl to char_pos_x
			HL_ADVANCE(char_anim_ptr, char_pos_x + 1, BY_BC)
			; horizontal check
			mov c, m ; pos_x
			lda hero_pos_x + 1
			mov b, a ; tmp
			adi HERO_COLLISION_WIDTH-1
			cmp c
			rc
			mvi a, CHAR_COLLISION_WIDTH-1
			add c
			cmp b
			rc
			; vertical check
			; advance hl to char_pos_y + 1
			INX_H(2)
			mov c, m ; pos_y
			lda hero_pos_y + 1
			mov b, a
			adi HERO_COLLISION_HEIGHT-1
			cmp c
			rc
			mvi a, CHAR_COLLISION_HEIGHT-1
			add c
			cmp b
			rc
@collides_hero:
			; hero collides
			; send him a damage
			mvi c, CHAR_DAMAGE
			jmp hero_impacted
.endmacro


; in:
; hl - ptr to char_status
; TODO: 45 bytes per instance
.macro CHAR_UPDATE_DETECT_HERO(distance, hero_detected_status, hero_detected_status_time, hero_detected_anim, detect_anim_speed, anim_check_collision_hero, next_status, next_status_time)
			; hl - ptr to char_status
			; advance hl to char_status_timer
			inx h
			dcr m
			jz @set_move_init

			; check a hero-to-char distance
			; advance hl to char_pos_x + 1
			HL_ADVANCE(char_status_timer, char_pos_x + 1, BY_DE)
			mvi c, distance
			call actor_to_hero_distance
			jnc @anim_check_collision_hero

			; hero detected
			; hl - ptr to char_pos_x + 1
			; advance hl to char_status
			HL_ADVANCE(char_pos_x + 1, char_status, BY_BC)
			mvi m, hero_detected_status

		.if hero_detected_status_time != NULL
			inx h
			mvi m, hero_detected_status_time
			; advance hl to char_anim_ptr
			HL_ADVANCE(char_status_timer, char_anim_ptr)
			mvi m, <hero_detected_anim
			inx h
			mvi m, >hero_detected_anim
		.endif
			ret

@anim_check_collision_hero:
			HL_ADVANCE(char_pos_x + 1, char_anim_timer, BY_DE)
			mvi a, detect_anim_speed
			jmp anim_check_collision_hero


@set_move_init:
 			; hl - ptr to char_status_timer
			mvi m, next_status_time ; TODO: use a rnd number instead of a const
			; advance hl to char_status
			dcx h
			mvi m, next_status
			ret
.endmacro