@memusage_room_tiledata_spawn:
;=======================================================
; to init each tiledata in a room during a room initialization.
; check room.asm room_handle_room_tiledata func
room_tiledata_funcs:
			JMP_4(room_tiledata_decal_walkable_spawn)	; func_id = 0
			JMP_4(room_tiledata_char_spawn)			; func_id = 1 ; chars
			JMP_4(room_tiledata_copy)					; func_id = 2 ; teleports
			JMP_4(room_tiledata_char2_spawn)			; func_id = 3 ; npcs
			JMP_4(room_tiledata_copy)					; func_id = 4 ; not used
			JMP_4(room_tiledata_copy)					; func_id = 5 ; not used
			JMP_4(room_tiledata_item_spawn)				; func_id = 6 ; global items
			JMP_4(room_tiledata_resource_spawn)			; func_id = 7 ; resources
			JMP_4(room_tiledata_copy)					; func_id = 8 ; not used
			JMP_4(room_tiledata_switch_spawn)			; func_id = 9 ; switches
			JMP_4(room_tiledata_copy)					; func_id = 10 ; triggers
			JMP_4(room_tiledata_container_spawn)		; func_id = 11 ; collidable containers
			JMP_4(room_tiledata_door_spawn)				; func_id = 12 ; doors
			JMP_4(room_tiledata_breakable_spawn)		; func_id = 13 ; breakable items
			JMP_4(room_tiledata_decal_collidable_spawn)	; func_id = 14 ; decals collidable
			JMP_4(room_tiledata_back_spawn)				; func_id = 15 ; collision + animated background tiles


; a tiledata handler. it just copies the tiledata.
; it copies the tiledata byte into the room_tiledata as it is
; input:
; b - tiledata
; out:
; a - tiledata that will be saved back into room_tiledata
room_tiledata_copy:
            ; just return the same tiledata
			mov a, b
			ret

; a tiledata handler. it returns tiledata = TILEDATA_NO_COLLISION.
; it copies the tiledata byte into the room_tiledata as it is
; input:
; b - tiledata
; out:
; a - tiledata that will be saved back into room_tiledata
room_tiledata_erase:
			A_TO_ZERO(TILEDATA_NO_COLLISION)
			ret

; a tiledata handler. spawn a char.
; input:
; b - tiledata
; c - tile_idx in the room_tiledata array.
; a - char_id
; out:
; a - tiledata that will be saved back into room_tiledata
room_tiledata_char_spawn:
			; get a char init func addr ptr
			lxi h, chars_inits
room_tiledata_char_spawn_:
			ADD_A(2) ; to make a JMP_4 ptr
			mov e, a
			mvi d, 0
			dad d
			; call a char init func
			pchl

; a tiledata handler. spawn a char.
; input:
; b - tiledata
; c - tile_idx in the room_tiledata array.
; a - char2_id
; out:
; a - tiledata that will be saved back into room_tiledata
room_tiledata_char2_spawn:
			; get a char init func addr ptr
			lxi h, chars2_inits
			jmp room_tiledata_char_spawn_

; a tiledata handler. spawn an animated back + collision.
; if id == TILEDATA_FUNC_ID_COLLISION, it does not spawn an animated back
; input:
; b - tiledata
; c - tile_idx in the room_tiledata array.
; a - back_id
; out:
; a - tiledata that will be saved back into room_tiledata
room_tiledata_back_spawn:
			cpi TILEDATA_FUNC_ID_COLLISION
			jnz backs_spawn
			mvi a, TILEDATA_COLLISION
			ret

; a tiledata handler. spawn a walkable decal.
; input:
; b - tiledata
; c - tile_idx in the room_tiledata array.
; a - decal_walkable_id
; out:
; a - tiledata that will be saved back into room_tiledata
room_tiledata_decal_walkable_spawn:
			; if decal_id < 2, then just copy tiledata
			cpi TILEDATA_RESTORE_TILE + 1
			jc room_tiledata_copy

			ADD_A(1) ; to make a WORD ptr
			sta room_decal_draw_ptr_offset + 1
			ROOM_DECAL_DRAW(decals_walkable_gfx_ptrs - WORD_LEN * 2)
			mvi a, TILEDATA_RESTORE_TILE
			ret

; a tiledata handler. spawn a collidable decals.
; input:
; b - tiledata
; c - tile_idx in the room_tiledata array.
; a - decal_collidable_id
; out:
; a - tiledata that will be saved back into room_tiledata
room_tiledata_decal_collidable_spawn:
			ADD_A(1) ; to make a WORD ptr
			sta room_decal_draw_ptr_offset + 1
			ROOM_DECAL_DRAW(decals_collidable_gfx_ptrs)
			mvi a, TILEDATA_COLLISION
			ret


; a tiledata handler. spawn breakables.
; input:
; b - tiledata
; c - tile_idx in the room_tiledata array.
; a - breakable_id
; out:
; a - tiledata that will be saved back into room_tiledata
room_tiledata_breakable_spawn:
			lxi h, @restore_tiledata + 1
			mov m, b

			ADD_A(1) ; to make a WORD ptr
			sta room_decal_draw_ptr_offset + 1

			;ROOM_SPAWN_RATE_CHECK(rooms_spawn_rate_breakables, @no_spawn)
			ROOM_DECAL_DRAW(breakable_gfx_ptrs)
@restore_tiledata:
			mvi a, TEMP_BYTE
			ret
@no_spawn:
			mvi a, TILEDATA_RESTORE_TILE
			ret

; a tiledata handler. spawn items.
; input:
; b - tiledata
; c - tile_idx in the room_tiledata array.
; a - item_id
; out:
; a - tiledata that will be saved back into room_tiledata
room_tiledata_item_spawn:
			lxi h, @restore_tiledata + 1
			mov m, b
			; check if it's storytelling dialog tiledata
			CPI_ZERO(ITEM_ID_STORYTELLING)
			jz @restore_tiledata

			ADD_A(1) ; to make a WORD ptr
			sta room_decal_draw_ptr_offset + 1

			; check global item status
			mvi h, >global_items
			RRC_(1)
			adi <global_items - 1 ; because the first item_id = 1
			mov l, a
			mov a, m
			CPI_ZERO(ITEM_STATUS_NOT_ACQUIRED)
			mvi a, TILEDATA_RESTORE_TILE
			rnz ; status != 0 means this item was picked up

			ROOM_DECAL_DRAW(items_gfx_ptrs - WORD_LEN) ;  subtraction of 2*WORD_LEN needs because there is no gfx for item_id=0. check _items_gfx_ptrs:
@restore_tiledata:
			mvi a, TEMP_BYTE
			ret

; a tiledata handler. spawn resources.
; input:
; b - tiledata
; c - tile_idx in the room_tiledata array.
; a - resource_id
; out:
; a - tiledata that will be saved back into room_tiledata
room_tiledata_resource_spawn:
			lxi h, @restore_tiledata + 1
			mov m, b

			lxi h, room_id
			mov d, m

			mov l, a
			ADD_A(1) ; resource_id to WORD ptr
			sta room_decal_draw_ptr_offset + 1

			; find a resource
			; d - room_id
			; l - resource_id
			; c - tile_idx
			FIND_INSTANCE(@picked_up, resources_inst_data_ptrs)
			; resource is found, means it is not picked up
			; c = tile_idx
			ROOM_DECAL_DRAW(resources_gfx_ptrs)
@restore_tiledata:
			mvi a, TEMP_BYTE
			ret
@picked_up:
			; no need to draw a resource
			mvi a, TILEDATA_RESTORE_TILE
			ret

; a tiledata handler. spawn container.
; input:
; b - tiledata
; c - tile_idx in the room_tiledata array.
; a - container_id
; out:
; a - tiledata that will be saved back into room_tiledata
room_tiledata_container_spawn:
			lxi h, @tiledata + 1
			mov m, b

			lxi h, room_id
			mov d, m

			mov l, a
			ADD_A(1) ; container_id to WORD ptr
			sta room_decal_draw_ptr_offset + 1

			; find a container
			FIND_INSTANCE(@opened, containers_inst_data_ptrs)

			; c - tile_idx in the room_tiledata array
			ROOM_DECAL_DRAW(containers_gfx_ptrs)
@tiledata:	mvi a, TEMP_BYTE
			ret
@opened:
			; draw an opened container
			; c - tile_idx in the room_tiledata array
			ROOM_DECAL_DRAW(containers_opened_gfx_ptrs)
			mvi a, TILEDATA_RESTORE_TILE
			ret

; a tiledata handler. spawn doors.
; input:
; b - tiledata
; c - tile_idx in the room_tiledata array.
; a - door_id
; out:
; a - tiledata that will be saved back into room_tiledata
room_tiledata_door_spawn:
			lxi h, @tiledata + 1
			mov m, b

			; requirement for ROOM_DECAL_DRAW
			ADD_A(1) ; to make a WORD ptr
			sta room_decal_draw_ptr_offset + 1

			; check the global item status
			rrc ; divide a WORD ptr by 2 to make it back door_id
			rar ; divide door_id by 2 to get the key_id because two doors (L and R) share the same key_id
			adi <global_items ; because the first door_id = 0
			mov l, a
			mvi h, >global_items
			mov a, m
			cpi <ITEM_STATUS_USED
			jz @opened	; status == ITEM_STATUS_USED means a door is opened

			; c - tile_idx in the room_tiledata array
			ROOM_DECAL_DRAW(doors_gfx_ptrs)
@tiledata:
			mvi a, TEMP_BYTE
			ret
@opened:
			; draw an opened door
			; c - tile_idx in the room_tiledata array
			push b
			ROOM_DECAL_DRAW(doors_opened_gfx_ptrs)
			pop b
			call draw_tile_16x16_buffs
			mvi a, TILEDATA_RESTORE_TILE
			ret

; a tiledata handler. spawn switches.
; input:
; b - tiledata
; c - tile_idx in the room_tiledata array.
; a - switch_id
; out:
; a - tiledata that will be saved back into room_tiledata
room_tiledata_switch_spawn:
			lxi h, @tiledata + 1
			mov m, b

			; requirement for ROOM_DECAL_DRAW
			ADD_A(1) ; to make a WORD ptr
			sta room_decal_draw_ptr_offset + 1

			; restore switch_id
			rrc
			mov c, a

			; convert switch_id into the swith_status (1<<switch_id)
			lxi h, 1
@loop:		dcr c
			jm @stop
			dad h
			jmp @loop
@stop:
			; hl - switch_statuse
			lda switch_statuses
			ana l
			jnz @draw_switch
			; check hi switches
			lda switch_statuses
			ana h
			jz @not_activated

@draw_switch:
			; c - tile_idx in the room_tiledata array
			ROOM_DECAL_DRAW(switches_gfx_ptrs)
@tiledata:
			mvi a, TEMP_BYTE
			ret
@not_activated:
			; a switch wasn't activated, do not draw
			mvi a, TILEDATA_COLLISION
			ret