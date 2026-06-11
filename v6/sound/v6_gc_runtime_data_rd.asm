; GC runtime buffers layout in the ram-disk
; must aligned by GC_BUFFER_SIZE (256)
GC_RUNTIME_DATA_RD = 0x8000

GC_BUFFER_SIZE	= 256
GC_TASKS		= 14
GC_STACK_SIZE	= 16

; these are GC_TASKS buffers GC_BUFFER_SIZE bytes long
; MUST BE ALIGNED by 0x100
_v6_gc_buffer = GC_RUNTIME_DATA_RD
			;.storage GC_BUFFER_SIZE * GC_TASKS, $00


_v6_gc_task_stack = _v6_gc_buffer + GC_BUFFER_SIZE * GC_TASKS
			;.storage GC_STACK_SIZE * GC_TASKS, $00

_song_data = _v6_gc_task_stack + GC_STACK_SIZE * GC_TASKS
;			...