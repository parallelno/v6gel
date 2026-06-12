	; This line is for proper formatting in VSCode

.global RAM_DISK_MUSIC
.global GC_STREAM_BUFFERS

GC_TASKS		= 14 ; 14 individual threads for each AY register
GC_STACK_SIZE	= 16
GC_BUFFER_SIZE	= $100

; Ram-disk access commands:
RAM_DISK_MUSIC = RAM_DISK_M2 | RAM_DISK_M_8F

; music data layout on ram-disk (RAM_DISK_MUSIC)
; runtime buffers:
GC_STREAM_BUFFERS 		= 0x8000
GC_TASKS_STACKS			= GC_STREAM_BUFFERS + GC_BUFFER_SIZE * GC_TASKS
; loaded music data:
GC_MUSIC_DATA 			= GC_TASKS_STACKS + GC_STACK_SIZE * GC_TASKS
GC_MUSIC_REG_PTRS	 	= GC_MUSIC_DATA
GC_MUSIC_REG_DATA  		= GC_MUSIC_REG_PTRS + GC_TASKS * ADDR_LEN