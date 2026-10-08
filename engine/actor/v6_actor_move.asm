; updates the actor's position based on its speed
; pos_xy += speed_xy

; in:
; hl - ptr to actor_status_timer
; out:
; hl - ptr to actor_pos_x + 1
; rev 1 268cc
; rev 2 212cc (26.4% faster!)
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
			actor_speed_x_l:
			.byte speed_x_l
			.byte pos_x_l
			.byte speed_x_h
			.byte pos_x_h

			.byte pos_y_h
			.byte speed_y_h
			.byte pos_y_l
			actor_speed_y_l:
			.byte speed_y_l

			HL_ADVANCE(pos_??, actor_speed_x_l, BY_BC)
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

			HL_ADVANCE(actor_pos_x_h, actor_speed_y_l, BY_BC)
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
			; cc = 192
			; 39.6% faster!
*/
			ret

; checks the actor's position aginst the room boundary and the collidable tiles.
; if no collision, updates the actor's position
; in:
; a - ROOM_WIDTH * TILE_WIDTH - TILE_WIDTH - actor_collision_w
; c - ROOM_HEIGHT * TILE_HEIGHT - TILE_HEIGHT - actor_collision_h
; de - (actor_collision_w-1)<<8 | actor_collision_h-1
; hl - ptr to actor_status_timer
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
			; TODO: if the pos_xy data layout is like below
			; this procedure can be faster
			; and the access of reading/storing pos_xy is faster as well
			; to make it 100%, the @collided branch should restore the old pos,
			; the @no_collision branch should do only little, like pop h
			actor_speed_x_l:
			.byte speed_x_l
			.byte pos_x_l
			.byte speed_x_h
			.byte pos_x_h

			.byte pos_y_h
			.byte speed_y_h
			.byte pos_y_l
			actor_speed_y_l:
			.byte speed_y_l

			HL_ADVANCE(actor_???, actor_speed_y_l, BY_BC)
			; new_pos_y = pos_y + speed_y
			mov a, m
			dcx h
			add m
			sta @new_pos_y_l + 1
			dcx h
			; cy flag
			mov a, m
			dcx h
			adc m
			sta @new_pos_y_h + 1
			mov e, a ; new_pos_y_h

			HL_ADVANCE(actor_speed_y_h, actor_speed_x_l, BY_BC)
			; new_pos_x = pos_x + speed_x
			mov a, m
			inx h
			add m
			sta @new_pos_x_l + 1
			inx h
			; cy flag
			mov a, m
			inx h
			adc m
			sta @new_pos_x_h + 1
			mov d, a
			push h
			; de - new pos_xy
			; a - new pos_x_h
			; hl - ptr to actor_pos_x_h
			; cc = 256

			; store a new pos_x
			pop h
			mvi m, TEMP_BYTE
			inx h
			mvi m, TEMP_BYTE
			inx h
			; store a new pos_y
			mvi m, TEMP_BYTE
			inx h
			mvi m, TEMP_BYTE
			; cc = 256+84=340
			; 11.8% faster!
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
			call room_get_collision_tiledata
			ani TILEDATA_COLLIDABLE ; set CY=0, didn't collide
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