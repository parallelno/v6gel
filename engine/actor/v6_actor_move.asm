; updates the actor's position based on its speed
; pos_xy += speed_xy

; in:
; hl - ptr to actor_status_timer
; out:
; hl - ptr to actor_pos_x + 1
; rev 1 268cc
; rev 2 212cc (20.9% faster!)
; rev 3 204cc (23.9% faster!)
; rev 4 192cc (28.4% faster!)
; 27 bytes
actor_move:
			HL_ADVANCE(actor_status_timer, actor_speed_y + 1, BY_BC)
			mov d, m
			dcx h
			mov a, m
			dcx h
			; d - speed_y_h
			; a - speed_y_l
			; hl - ptr to speed_x + 1
			mov b, m
			dcx h
			mov c, m
			dcx h
			; bc - speed_x
			; hl - ptr to pos_y + 1
			dcx h
			; hl - ptr to pos_y
			add m
			mov m, a
			inx h
			; hl = ptr to pos_y + 1
			mov a, m
			adc d
			mov m, a

			HL_ADVANCE(actor_pos_y + 1, actor_pos_x)
			mov a, m
			add c
			mov m, a
			inx h
			; hl - ptr to pos_x + 1
			mov a, m
			adc b
			mov m, a
			; cc = 212

/*
			; TODO: if the pos_xy data layout is like below
			; this procedure can be faster
		; actor_speed_x_l:
			; .byte speed_x_l
			; .byte pos_x_l
			; .byte speed_x_h
			; .byte pos_x_h

			; .byte pos_y_h
			; .byte speed_y_h
			; .byte pos_y_l
		; actor_speed_y_l:
			; .byte speed_y_l

			HL_ADVANCE(actor_status_timer, actor_speed_x_l, BY_BC) ; 24 cc
			; new_pos_x = pos_x + speed_x
			mov a, m
			inx h
			add m
			mov m, a ; store pos_x_l

			inx h
			; cy flag
			mov a, m
			inx h
			adc m
			; a - new pos_x_h
			mov m, a ; store new pos_x_h

			HL_ADVANCE(actor_pos_x_h, actor_speed_y_l, BY_BC) ; 24 cc
			; new_pos_y = pos_y + speed_y
			mov a, m
			dcx h
			add m
			mov m, a ; store pos_y_l

			dcx h
			; cy flag
			mov a, m
			dcx h
			adc m
			; a - new pos_y_h
			mov m, a ; store new pos_y_h
			; cc = 48*4=192
			; 28.4% faster!
*/

/*
			; slightly new layout, much faster!
			; hero_speed_x:	.storage WORD_LEN ; = hero_runtime_data + actor_speed_x
			; hero_speed_y:	.storage WORD_LEN ; = hero_runtime_data + actor_speed_y
			; hero_pos_x:	.storage WORD_LEN ; = hero_runtime_data + actor_pos_x
			; hero_pos_y:	.storage WORD_LEN ; = hero_runtime_data + actor_pos_y

			HL_ADVANCE(actor_status_timer, hero_speed_y, BY_BC) ; 6*4=24cc
			; read speed x
			mov a, m
			inx h
			mov b, m
			; read speed y
			inx h
			mov e, m
			inx h
			mov d, m
			; pos x += speed_x
			inx h
			add m
			mov m, a
			inx h
			mov a, m
			adc b
			mov m, a
			; pos y += speed_y
			inx h
			mov a, m
			add e
			mov m, a
			inx h
			mov a, m
			adc d
			mov m, a
			; (41+6)*4=188 cc
			; 29.9% faster!
*/

/*
			; TODO: same layout, slightly faster! different OUT!
			; read speed_y
			HL_ADVANCE(actor_status_timer, hero_speed_y+1, BY_BC) ; 6*4=24cc
			mov d, m
			dcx h
			mov e, m
			dcx h
			; de - speed_x
			mov b, m
			dcx h
			mov a, m
			; pos_x += speed_x
			HL_ADVANCE(actor_speed_x, hero_pos_x, BY_BC) ; 6*4=24cc
			add m
			mov m, a ; store pos_x_l
			inx h
			mov a, m
			adc b
			mov m, a ; store pos_x_h
			; pos_y += speed_y
			inx h
			mov a, m
			add e
			mov m, a
			inx h
			mov a, m
			adc d
			mov m, a
			; 51*4=204cc
			; 23.9% faster!
*/

/*
			; slightly new layout, faster!
			; hero_pos_x_h and hero_pos_y_h are placed next to each other for faster access.
			; hero_speed_x:	.storage WORD_LEN ; = hero_runtime_data + actor_speed_x
			; hero_speed_y:	.storage WORD_LEN ; = hero_runtime_data + actor_speed_y
			; hero_pos_x:   .storage WORD_LEN ;
			; hero_pos_y_h: .storage BYTE_LEN ;
			; hero_pos_y_l: .storage BYTE_LEN ;

			HL_ADVANCE(actor_status_timer, hero_speed_y, BY_BC) ; 6*4=24cc
			; read speed x
			mov a, m
			inx h
			mov b, m
			; read speed y
			inx h
			mov e, m
			inx h
			mov d, m
			; pos x += speed_x
			inx h
			add m
			mov m, a
			inx h
			mov a, m
			adc b
			mov m, a
			; pos y += speed_y
			inx h
			inx h
			mov a, m
			add e
			mov m, a
			dcx h
			adc d
			mov m, a
			; (42+6)*4=192 cc
			; 28.4% faster!
*/

/*
			HL_ADVANCE(actor_status_timer, hero_speed_y, BY_BC) ; 6*4=24cc
			lhld speed_x
			xchg
			lhld pos_x
			dad d
			shld pos_x
			lhld speed_y
			xchg
			lhld pos_y
			dad d
			shld pos_y
			; (38+6)*4=176cc
*/
/*
			; STACK OPs
			; new layout. low and hi of the pos are swapped
			hero_pos_x_h:
			hero_pos_x_l:
			hero_pos_y_h:
			hero_pos_y_l:
			hero_speed_y:				     .storage WORD_LEN ; = hero_runtime_data + actor_speed_y
			hero_speed_x:				     .storage WORD_LEN ; = hero_runtime_data + actor_speed_x

			; store SP
			xchg
			lxi h, 0
			dad sp
			shls @restore_sp + 1

			HL_ADVANCE(actor_status_timer, hero_speed_y, BY_HL_FROM_DE) ; 6*4=24cc
			; set SP to hero_speed_y
			sphl
			; advance SP to hero_y_l
			dcx h

			; read speed_x
			pop b
			mov a, m
			add c
			mov m, a
			dcx h
			mov a, m
			adc b
			mov m, a
			; pos_y += speed_y
			dcx h
			pop b
			mov a, m
			add c
			mov m, a
			dcx h
			mov a, m
			adc b
			mov m, a
@restore_sp:
			lxi sp, TEMP_ADDR
			; 57+6=252cc
*/

			ret

; checks the actor's position aginst the room boundary and the collidable tiles.
; if no collision, updates the actor's position
; in:
; a - ROOM_WIDTH * TILE_WIDTH - TILE_WIDTH - actor_collision_w
; c - ROOM_HEIGHT * TILE_HEIGHT - TILE_HEIGHT - actor_collision_h
; de - (actor_collision_w-1)<<8 | actor_collision_h-1
; hl - ptr to actor_status_timer
; out:
; no_collision: Z=1, hl points to pos_y + 1
; collided: CY=1, hl points to pos_x
actor_check_tile_collision:
			sta @room_collision_width + 1
			mov a, c
			sta @room_collision_height + 1
			xchg
			shld actor_update_movement_check_tile_collision_xy + 1

			HL_ADVANCE(actor_status_timer, actor_speed_y + 1, BY_HL_FROM_DE)
			mov d, m
			dcx h
			mov e, m
			dcx h
			; de - speed_y
			; hl - ptr to speed_x + 1
			mov b, m
			dcx h
			mov c, m
			dcx h
			; bc - speed_x
			; hl - ptr to pos_y + 1
			push h
			dcx h
			; hl - ptr to pos_y
			mov a, m
			sta @old_pos_y_l + 1
			add e
			mov m, a
			inx h
			; hl = ptr to pos_y + 1
			mov a, m
			sta @old_pos_y_h + 1
			adc d
			mov m, a
			mov e, a

			HL_ADVANCE(actor_pos_y + 1, actor_pos_x)
			mov a, m
			sta @old_pos_x_l + 1
			add c
			mov m, a
			inx h
			; hl - ptr to pos_x + 1
			mov a, m
			sta @old_pos_x_h + 1
			adc b
			mov m, a
			mov d, a
			; cc = 312
			; cc = 312 + 12=324 with pop h
			; 17.3% faster!

/*
			; TODO: apply optimizations from actor_move here
*/

			; check the collision against a border of the screen
			; check the X coord
			cpi TILE_WIDTH
			jc @collided
@room_collision_width:
			cpi TEMP_BYTE
			jnc @collided
			; check if the Y coord
			mov a, e
			cpi TILE_HEIGHT
			jc @collided
@room_collision_height:
			cpi TEMP_BYTE
			jnc @collided
			; 88cc


@check_tile_collision:
			; check the collision against a collidable tiles
			lxi b, TEMP_ADDR
			; de - new_pos_xy
			; bc - width, height
.if V6_ROOMS
			call room_get_collision_tiledata
			ani TILEDATA_COLLIDABLE ; set CY=0, didn't collide
.endif
.if V6_ROOMS != 1
			; NULL is the empty (no collision) tile data
			A_TO_ZERO(NULL)
.endif

			pop h
			rz ; no_collision, hl points to pos_y + 1
			jmp @skip_pop_h


@collided:
			pop h
@skip_pop_h:
			; hl points to pos_y + 1
			; store a old pos_x
@old_pos_y_h:
			mvi m, TEMP_BYTE
			dcx h
@old_pos_y_l:
			mvi m, TEMP_BYTE
			dcx h
			; store a new pos_y
@old_pos_x_h:
			mvi m, TEMP_BYTE
			dcx h
@old_pos_x_l:
			mvi m, TEMP_BYTE
			; hl points to pos_x
			stc ; set CY=1, collided
			ret
actor_update_movement_check_tile_collision_xy = @check_tile_collision