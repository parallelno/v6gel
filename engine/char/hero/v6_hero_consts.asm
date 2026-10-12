	;
HERO_RUN_SPEED		= $0200 ; low byte is a subpixel speed, high byte is a speed in pixels
HERO_RUN_SPEED_N	= $ffff - HERO_RUN_SPEED + 1
HERO_RUN_SPEED_D	= $016a ; for diagonal moves

HERO_RUN_SPEED_IMPACTED		= $0300 ; low byte is a subpixel speed, high byte is a speed in pixels
HERO_RUN_SPEED_IMPACTED_N	= $ffff - HERO_RUN_SPEED_IMPACTED + 1

HERO_DIR_HORIZ_MASK		= %0011
HERO_DIR_HORIZ_RESET	= %0100
HERO_DIR_RIGHT			= %0011
HERO_DIR_LEFT			= %0010
HERO_DIR_VERT_MASK		= %1100
HERO_DIR_VERT_RESET		= %0001
HERO_DIR_UP				= %1100
HERO_DIR_DOWN			= %1000


; hero statuses.
; statuses describe what set of animations and behavior is active
; for ex. ACTOR_STATUS_HERO_ATTACK plays hero_r_attk or hero_l_attk
; depending on the direction. It also spawns a weapon trail
; personal actor statuses must be in a range of 0 to ACTOR_STATUS_CUSTOM including.
; The more popular status is, the lower its id should be. For optimization purposes.
ACTOR_STATUS_HERO_IDLE			= 0 ;\  all these statuses have to
ACTOR_STATUS_HERO_MOVE			= 1 ; > have contigues ids to be
ACTOR_STATUS_HERO_INVINCIBLE	= 2 ;/  handled properly
ACTOR_STATUS_HERO_ATTACK		= 3
; statuses above this one are used for special effects and are not used in the game
ACTOR_STATUS_HERO_DEATH_FADE_INIT_GB	= 4							 ;\  all these statuses have to
ACTOR_STATUS_HERO_DEATH_FADE_GB			= 5 						 ; > have contigues ids to be
ACTOR_STATUS_HERO_DEATH_FADE_R			= 6 | ACTOR_STATUS_BIT_INVIS ; > handled properly
ACTOR_STATUS_HERO_DEATH_WAIT_SPARKER	= 7 | ACTOR_STATUS_BIT_INVIS ;/

; duration of statuses (in update_durations)
HERO_STATUS_ATTACK_DURATION		= 12
HERO_STATUS_INVINCIBLE_DURATION	= 20
HERO_STATUS_KICKOFF_DURATION	= 5 ; kickoff is also invincible
HERO_STATUS_DEATH_WAIT_SPARKER_DURATION	= 35

; animation speed (the less the slower, 0-255, 255 means next frame every update)
HERO_ANIM_SPEED_MOVE	= 100
HERO_ANIM_SPEED_IDLE	= 4
HERO_ANIM_SPEED_ATTACK	= 160

HERO_COLLISION_WIDTH	= 15
HERO_COLLISION_HEIGHT	= 11

HERO_WEAPON_ID_HANDS		= 0
HERO_WEAPON_ID_SWORD		= 1
HERO_WEAPON_ID_SNOWFLAKE	= 2

HERO_PROJECTILE_OFFSET_X	= 7
HERO_PROJECTILE_OFFSET_Y	= 5