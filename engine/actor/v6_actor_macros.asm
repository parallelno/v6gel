; checks the actor's position aginst the room boundary and the collidable tiles.
; in:
; hl ptr to actor_status_timer
; out:
; if no collision: CY=0, hl points to actor pos_y + 1
; if a collision: CY=1, hl points to actor pos_x
; uses: all
; rev 1 380cc
; rev 2 324cc (17.3% faster!)
; rev 3 (converted to func)
.macro ACTOR_UPDATE_MOVEMENT_CHECK_TILE_COLLISION(actor_collision_w, actor_collision_h, collision_handler)
			mvi a, ROOM_WIDTH * TILE_WIDTH - TILE_WIDTH - actor_collision_w
			mvi c, ROOM_HEIGHT * TILE_HEIGHT - TILE_HEIGHT - actor_collision_h
			lxi d, (actor_collision_w-1)<<8 | actor_collision_h-1
			call actor_move_check_tile_collision
			jc collision_handler
.endmacro


; replaces the actor runtime data with a marker
; indicating that there is no actor runtime data here and beyond
; used mostly for erasing all runtime data
.macro ACTOR_ERASE_RUNTIME_DATA(actor_update_ptr)
			lxi h, actor_update_ptr + 1
			mvi m, ACTOR_RUNTIME_DATA_LAST
.endmacro

; marks the actor's runtime data as it's going to be destroyed
; in:
; hl - update_ptr + 1 ptr
; TODO: optimize. fill up lastRemovedOverlayRuntimeDataPtr
.macro ACTOR_DESTROY()
			mvi m, ACTOR_RUNTIME_DATA_DESTR
.endmacro


; marks the actor runtime data as empty
; in:
; hl - update_ptr + 1 ptr
; TODO: optimize. fiil up lastRemovedOverlayRuntimeDataPtr
.macro ACTOR_EMPTY()
			mvi m, ACTOR_RUNTIME_DATA_EMPTY
.endmacro