.include "char/v6_char_data.asm"
; .include "asm/app/chars/entities/skeleton.asm"
; .include "asm/app/chars/entities/skeleton_quest.asm"
; .include "asm/app/chars/entities/vampire.asm"
; .include "asm/app/chars/entities/burner.asm"
; .include "asm/app/chars/entities/burner_quest.asm"
; .include "asm/app/chars/entities/knight.asm"
; .include "asm/app/chars/entities/knight_heavy.asm"
; .include "asm/app/chars/entities/goose.asm"
; .include "asm/app/chars/entities/cat.asm"
; .include "asm/app/chars/entities/firepool.asm"
; .include "asm/app/chars/entities/npc.asm"
; .include "asm/app/chars/entities/mom.asm"
; .include "asm/app/chars/entities/friends_mom.asm"
; .include "asm/app/chars/entities/friends_sis.asm"
; .include "asm/app/chars/entities/dotty.asm"
; .include "asm/app/chars/entities/bob.asm"
; .include "asm/app/chars/entities/npc4.asm"
; .include "asm/app/chars/entities/caterpillar.asm"
; .include "asm/app/chars/entities/scarecrow.asm"
; .include "asm/app/chars/entities/crow.asm"

@memusage_chars:

chars_init:
			; actor_data_head_ptr got inited in level_init with NULL
			; set the last marker byte of runtime_data
			mvi a, ACTOR_RUNTIME_DATA_END
			sta chars_runtime_data_end_marker + 1
			; erase runtime_data
			ACTOR_ERASE_RUNTIME_DATA(char_update_ptr)

			; init runtime_data list
			lxi h, hero_data_next_ptr
			shld actor_data_head_ptr
			lxi h, NULL
			shld hero_data_next_ptr
			ret


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

; char initialization
; in:
; c - tile_idx in the room_tiledata array.
; a - char_id * 4
; b - spawn_rate_check
;		1 - yes
;		0 - no
; out:
; a - TILEDATA_RESTORE_TILE to make the tile (where a char spawned) walkable and restorable
; rev1: 1416 cc (spawn_rate_check = True + macro)
; rev2: 1348 cc (spawn_rate_check = True + macro, ROOM_SPAWN_RATE_CHECK optimized )
char_init:
			RRC_(2) ; to get char_id
			sta @char_id + 1

			shld @char_data_ptr + 1

			; store tile_idx
			push b

			lxi h, 0
			dad	sp
			shld @restore_sp + 1

			dcr b
			jnz @no_spawn_rate_check
			ROOM_SPAWN_RATE_CHECK(rooms_spawn_rate, @exit)
@no_spawn_rate_check:

			lxi h, char_update_ptr + 1
			mvi e, CHAR_RUNTIME_DATA_LEN
			call actor_get_empty_data_ptr
			; hl - ptr to char_update_ptr + 1
			jnz @exit ; return when it's too many objects


			CHAR_DATA_INSERT_AT_HEAD()
			; hl - points to char_data_next_ptr

@char_data_ptr:
			lxi sp, TEMP_ADDR

			pop b
			; BC - CHAR_IMPACTED_PTR
			HL_ADVANCE(char_data_next_ptr, char_impacted_ptr)
			mov m, c
			HL_ADVANCE(char_impacted_ptr, char_impacted_ptr + 1)
			mov m, b

			HL_ADVANCE(char_impacted_ptr + 1, char_id)
@char_id:	mvi m, TEMP_BYTE

			pop b
			; B - CHAR_TYPE
			HL_ADVANCE(char_id, char_type)
			mov m, b

			pop b
			; C - CHAR_HEALTH
			HL_ADVANCE(char_type, char_health)
			mov m, c
			mov a, b
			; A - CHAR_STATUS

			pop b
			; BC - CHAR_UPDATE_PTR
			HL_ADVANCE(char_health, char_update_ptr, BY_DE)
			mov m, c
			HL_ADVANCE(char_update_ptr, char_update_ptr + 1)
			mov m, b

			pop b
			; BC - CHAR_DRAW_PTR
			HL_ADVANCE(char_update_ptr + 1, char_draw_ptr)
			mov m, c
			HL_ADVANCE(char_draw_ptr, char_draw_ptr + 1)
			mov m, b

			; A - CHAR_STATUS
			HL_ADVANCE(char_draw_ptr + 1, char_status)
			mov m, a

			pop b
			; BC - CHAR_ANIM_PTR
			HL_ADVANCE(char_status, char_anim_ptr)
			mov m, c
			HL_ADVANCE(char_anim_ptr, char_anim_ptr + 1)
			mov m, b

@restore_sp:
			lxi sp, TEMP_ADDR
			RAM_DISK_OFF()

			; restore tile_idx
			pop d
			; e - tile_idx
			; pos_x = tile_idx % ROOM_WIDTH * TILE_WIDTH
			mvi a, %00001111
			ana e
			RLC_(4)
			mov c, a
			; scr_x = pos_x/8 + $a0
			RRC_(3)
			adi SPRITE_X_SCR_ADDR
			mov b, a
			; pos_y = (tile_idx % ROOM_WIDTH) * TILE_WIDTH
			mvi a, %11110000
			ana e
			lxi d, SPRITE_H_MIN
			; b = scr_x
			; c = pos_x
			; a = pos_y
			; d = 0 or SPRITE_W_PACKED_MIN
			; e = SPRITE_H_MIN
			; hl - ptr to char_anim_ptr + 1

			; CHAR_ERASE_SCCR_ADDR
			HL_ADVANCE(char_anim_ptr + 1, char_erase_scr_addr)
			mov m, a
			HL_ADVANCE(char_erase_scr_addr, char_erase_scr_addr + 1)
			mov m, b

			; CHAR_ERASE_SCCR_ADDR_OLD
			HL_ADVANCE(char_erase_scr_addr + 1, char_erase_scr_addr_old)
			mov m, a
			HL_ADVANCE(char_erase_scr_addr_old, char_erase_scr_addr_old + 1)
			mov m, b

			; CHAR_ERASE_WH
			HL_ADVANCE(char_erase_scr_addr_old + 1, char_erase_wh)
			mov m, e
			HL_ADVANCE(char_erase_wh, char_erase_wh + 1)
			mov m, d

			; CHAR_ERASE_WH_OLD
			HL_ADVANCE(char_erase_wh + 1, char_erase_wh_old)
			mov m, e
			HL_ADVANCE(char_erase_wh_old, char_erase_wh_old + 1)
			mov m, d

			; CHAR_POS_X
			HL_ADVANCE(char_erase_wh_old + 1, char_pos_x)
			mov m, d
			HL_ADVANCE(char_pos_x, char_pos_x + 1)
			mov m, c

			; CHAR_POS_Y
			HL_ADVANCE(char_pos_x + 1, char_pos_y)
			mov m, d
			HL_ADVANCE(char_pos_y, char_pos_y + 1)
			mov m, a
@restore_tile:
			mvi a, TILEDATA_RESTORE_TILE
			ret
@exit:
			pop h ; release
			jmp @restore_tile

; in:
; h - pos_x
; l - pos_y
; a - collider width
; c - collider height
; b - char type mask to look up. (CHAR_TYPE_ALLY | CHAR_TYPE_ENEMY) will check for both types
; out:
; no collision 	- (hl) >= ACTOR_RUNTIME_DATA_DESTR
; collision 	- hl points to a collided char_update_ptr + 1, (hl) < ACTOR_RUNTIME_DATA_DESTR
; use:
; b
chars_get_first_collided:
			sta @collider_width + 1
			mov a, c
			sta @collider_height + 1
			mov a, h
			sta @collider_pos_x + 1
			mov a, l
			sta @collider_pos_y + 1
			mov a, b
			sta @char_type + 1
			lxi h, char_update_ptr + 1

@loop:
			mov a, m
			cpi ACTOR_RUNTIME_DATA_DESTR
			jc @check_collision
			cpi ACTOR_RUNTIME_DATA_LAST
			jc @next_data
			; no collision against all alive chars
			ret
@check_collision:
			push h
			HL_ADVANCE(char_update_ptr + 1, char_type, BY_BC)
			mov a, m
@char_type:
			ani TEMP_BYTE
			jz @no_collision

			HL_ADVANCE(char_type, char_pos_x + 1, BY_BC)
			; horizontal check
			mov c, m 	; char pos_x
@collider_pos_x:
			mvi a, TEMP_BYTE
			mov b, a	; tmp
@collider_width:
			adi TEMP_BYTE
			cmp c
			jc @no_collision
			mvi a, SKELETON_COLLISION_WIDTH-1
			add c
			cmp b
			jc @no_collision
			; vertical check
			HL_ADVANCE(char_pos_x + 1, char_pos_y + 1)
			mov c, m ; char pos_y
@collider_pos_y:
			mvi a, TEMP_BYTE
			mov b, a
@collider_height:
			adi TEMP_BYTE
			cmp c
			jc @no_collision
			mvi a, SKELETON_COLLISION_HEIGHT-1
			add c
			cmp b
			jc @no_collision

			; collides
			pop h
			ret
@no_collision:
			pop h
@next_data:
			lxi b, CHAR_RUNTIME_DATA_LEN
			dad b
			jmp @loop

chars_update:
			ACTORS_INVOKE_IF_ALIVE(char_update_ptr, char_update_ptr, CHAR_RUNTIME_DATA_LEN, true)

; call draw func of every alive char and hero
; intro: 12cc
; loop: 37*4+24=172cc
chars_draw:
			; iterate over the list of the char data
			lxi h, actor_data_head_ptr
@loop:
			; hl - current element
			; get the next element
			mov c, m
			inx h
			mov b, m

			; check if current element is the last one (next element is NULL)
			A_TO_ZERO(NULL)
			cmp b
			rz ; return if it's the last element

			push b ; store the addr of the next element
			lxi d, @return
			push d

			HL_ADVANCE(char_data_next_ptr, char_draw_ptr + 1, BY_HL_FROM_BC)
			mov d, m
			dcx h
			mov e, m
			xchg
			; hl - addr of char_draw_ptr
			; de - ptr to char_draw_ptr
			pchl
@return:
			pop h ; current element = next element
			jmp @loop

chars_copy_to_scr:
			ACTORS_CALL_IF_ALIVE(char_copy_to_scr, char_update_ptr, CHAR_RUNTIME_DATA_LEN, true)

chars_erase:
			ACTORS_CALL_IF_ALIVE(char_erase, char_update_ptr, CHAR_RUNTIME_DATA_LEN, true)

; copy a sprite from a backbuffer to a scr
; in:
; hl - ptr to char_update_ptr + 1
char_copy_to_scr:
			HL_ADVANCE(char_update_ptr + 1, char_status)
			jmp actor_copy_to_scr

; erase a sprite or restore the background behind a sprite
; in:
; hl - ptr to char_update_ptr + 1
; a - CHAR_RUNTIME_DATA_* status
; ~3480cc if it mostly restores a background
char_erase:
			LXI_D_TO_DIFF(char_update_ptr + 1, char_status)
			jmp actor_erase

; a common routine to handle a char impacted by a hero weapon
; it decrease the health of the char. if the healf is below 0,
; the char does, score adds, if the weapon is a snowflake,
; the char freeses.
; in:
; de - ptr to char_impacted_ptr + 1
; c - hero_weapon_id
char_impacted:
			; check the weapon_id
			mvi a, HERO_WEAPON_ID_SNOWFLAKE
			cmp c
			jz @set_state_freeze
			ROOM_SPAWN_RATE_UPDATE(rooms_spawn_rate, CHAR_SPAWN_RATE_DELTA, CHAR_SPAWN_RATE_MAX)

			; play a hit vfx
			; de - ptr to char_impacted_ptr + 1
			HL_ADVANCE(char_impacted_ptr + 1, char_pos_x + 1, BY_HL_FROM_DE)
			mov b, m
			HL_ADVANCE(char_pos_x + 1, char_pos_y + 1)
			mov c, m
			lxi d, vfx4_hit_anim
			push h
			call vfx_init4
			pop h

			; decrease char's health
			HL_ADVANCE(char_pos_y + 1, char_health, BY_DE)
			dcr m
			rnz

			; add score points
			push h
			HL_ADVANCE(char_health, char_id)
			mov e, m
			mvi d, TILEDATA_FUNC_ID_CHARS
			call game_score_add
			call game_ui_draw_score_text
			pop h

			; mark this char dead
			HL_ADVANCE(char_health, char_update_ptr + 1, BY_DE)
			jmp char_destroy

@set_state_freeze:
			; de - ptr to char_impacted_ptr + 1
			HL_ADVANCE(char_impacted_ptr + 1, char_status, BY_HL_FROM_DE)
			mvi m,ACTOR_STATUS_FREEZE
			HL_ADVANCE(char_status, char_status_timer)
			mvi m, ACTOR_STATUS_FREEZE_TIME

			; check if a hero uses a snowflake the first time
			lda game_status_first_freeze
			CPI_ZERO()
			rnz
			inr a
			sta game_status_first_freeze
			; init a dialog
			mvi a, GAME_REQ_PAUSE
			lxi h, dialog_callback_room_redraw
			lxi d, _storytelling_hero_freeze_char
			jmp dialog_init


; common freeze update func.
; it does nothing except counting down the status time
; in:
; hl = char_status
char_update_freeze:
			HL_ADVANCE(char_status, char_status_timer)
			dcr m
			rnz
			HL_ADVANCE(char_status_timer, char_status)
			dcx h
			mvi m, ACTOR_STATUS_INIT
			ret

; marks the actor runtime data as destroyed,
; and removes it from the actors list
; in:
; hl - ptr to char_update_ptr + 1
char_destroy:
			ACTOR_DESTROY()
			; remove from the list
			CHAR_DATA_REMOVE()
			ret

; sorts the chars list by char_pos_y
; executes only one iteration of the bubble sort algorithm
chars_sort_pos_y:
			; get the current element
			lhld actor_data_head_ptr
			; check if the list is empty
			A_TO_ZERO(NULL)
			cmp h
			rz ; return if the list is empty

			xchg
			; de - current element

			lxi h, actor_data_head_ptr
			push h
@loop:
			; stack - prev element, or current element from previous loop iteration
			; de - current element, or next element from previous loop iteration
			xchg

			; stack - prev element
			; hl - current element

			; get the next element
			mov e, m
			inx h
			mov d, m
			; de - next element
			; check if current element is the last one (next element is NULL)
			A_TO_ZERO(NULL)
			cmp d
			jz @exit

			dcx h
			; stack - prev element
			; hl - current element
			; de - next element

			LXI_B_TO_DIFF(char_data_next_ptr, char_pos_y + 1)
			dad b
			; get >pos_y of the current element
			mov a, m

			xchg
			; hl - next element
			dad b
			; a - pos_y of the current element
			; m - pos_y of the next element
			; compare >pos_y of the current element with the next one
			cmp m
			; bc - prev element
			jnc @advance

@swap:
			; swap the current and next elements
			; stack - the prev element
			; de - char_pos_y + 1 of the current element
			; hl - char_pos_y + 1 of the next element

			LXI_B_TO_DIFF(char_pos_y + 1, char_data_next_ptr)
			dad b
			xchg
			dad b
			; stack - the prev element
			; hl - current element
			; de - next element


			; current.next = next_element.next
			ldax d
			mov m, a
			inx h
			inx d
			ldax d
			mov m, a
			; hl - current element + 1
			; de - next element + 1

			; next_element.next = current_element
			xchg
			dcx d
			mov m, d
			dcx h
			mov m, e
			; stack - the prev element
			; de - current element
			; hl - next element

			xchg
			XTHL
			; hl - the prev element
			; stack - current element
			; de - next element

			; prev_element.next = next_element
			mov m, e
			inx h
			mov m, d
			; hl - the prev element + 1
			; stack - current element
			; de - next element
			jmp @loop

@advance:
			; stack - the prev element
			; de - char_pos_y + 1 of the current element
			; hl - char_pos_y + 1 of the next element

			LXI_B_TO_DIFF(char_pos_y + 1, char_data_next_ptr)
			dad b
			xchg
			dad b
			; hl - current element
			; de - next element

			XTHL
			; stack - current element
			; de - next element
			jmp @loop

@exit:
			pop h ; release prev element
			ret
