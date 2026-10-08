
; check a spawn_rate which addr is rate_ptr + room_id
; use:
; hl, e, a
; TODO: error: this macro does not check the level.
; rooms_spawn_rate array does not contain a proper data for all levels
; rev1: 100 cc
; rev2: 88 cc
.macro ROOM_SPAWN_RATE_CHECK(rate_addr, do_not_spawn)
			; check rooms_break_rate if it needs to spawn
			lda room_id
			adi <rate_addr
			mov e, a
			mvi d, >rate_addr

			call random
			xchg
			cmp m
			jc do_not_spawn
.endmacro

; rev1: 100 cc
; rev2: 88 cc
.macro ROOM_SPAWN_RATE_UPDATE(rate_addr, SPAWN_RATE_DELTA, SPAWN_RATE_MIN)
			; increase death_rate
			lda room_id
			adi <rate_addr
			mov l, a
			mvi h, >rate_addr

			mov a, m
			adi SPAWN_RATE_DELTA
			mov m, a
			jnc @next
			mvi m, SPAWN_RATE_MIN
@next:
.endmacro

; look up a resource by its room_id, tile_idx
; if no success, it jumps to no_container_found label
; in:
; d - room_id
; l - res_id
; c - tile_idx
; out:
; if success:
; c = tile_idx
; hl ptr to tile_idx in instances_ptrs
; uses:
; hl, de, a
; 30 bytes,
.macro FIND_INSTANCE(no_container_found, instances_ptrs)
			; find a resource
			mvi h, >instances_ptrs
			; hl - ptr to instances_ptrs, ex. resources_inst_data_ptrs
			mov a, m
			inx h
			mov l, m
			; hl - ptr to the next resource_inst_data
			; (h<<8 + a) - ptr to resource_inst_data.
			; make an instance counter
			; a - a low byte ptr to resources_inst_data for particular resource
			sub l
			cma
			cmc ; make C flag = 0
			rar ; div by 2 because every instance data contains of a pair of bytes
			mov e, a
			; e = inst_counter - 1
			; d = room_id
			; find a resource in resource_inst_data
			mov a, d
@search_loop:
			dcx h
			cmp m
			dcx h
			jz @room_match
@check_counter:
			dcr e
			jp @search_loop
			jmp no_container_found ; resource is not found, means it was already picked up
@room_match:
			; check tile_idx
			mov a, m
			cmp c
			mov a, d
			jnz @check_counter
.endmacro