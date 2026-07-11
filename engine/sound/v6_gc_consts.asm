	; This line is for proper formatting in VSCode

.global RAM_DISK_MUSIC

GC_TASKS		= 14 ; 14 individual threads for each AY register
GC_STACK_SIZE	= 16
GC_BUFFER_SIZE	= $100

GC_RUNTIME_DATA_RD = 0x8000

; Ram-disk access commands:
RAM_DISK_MUSIC = RAM_DISK_M2 | RAM_DISK_M_8F