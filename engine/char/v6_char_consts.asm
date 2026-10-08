	; This line is for proper formatting in VSCode

; char types
CHAR_TYPE_ENEMY	= 0b0000_0001
CHAR_TYPE_ALLY	= 0b0000_0010
CHAR_TYPE_ALL	= $FF


; Char runtime data struct.
char_update_ptr:	  	 = actor_update_ptr
char_draw_ptr:			 = actor_draw_ptr
char_status:			 = actor_status
char_status_timer:		 = actor_status_timer
char_anim_timer:		 = actor_anim_timer
char_anim_ptr:			 = actor_anim_ptr
char_erase_scr_addr:	 = actor_erase_scr_addr
char_erase_scr_addr_old: = actor_erase_scr_addr_old
char_erase_wh:			 = actor_erase_wh
char_erase_wh_old:		 = actor_erase_wh_old
char_pos_x:				 = actor_pos_x
char_pos_y:				 = actor_pos_y
char_speed_x:			 = actor_speed_x
char_speed_y:			 = actor_speed_y
char_data_next_ptr:		 = 25 ; .word ; NULL if it's the last actor in the list
char_impacted_ptr:		 = 27 ; .word ; called by a hero, overlay, npc, etc. to affect this char
char_id:				 = 29 ; .byte
char_type:				 = 30 ; .byte
char_health:			 = 31 ; .byte ; Remaining health points

CHAR_RUNTIME_DATA_LEN = char_health + BYTE_LEN

.if CHAR_RUNTIME_DATA_LEN > $100
	.error "ERROR: CHAR_RUNTIME_DATA_LEN (", CHAR_RUNTIME_DATA_LEN, ") > $100"
.endif