; GC runtime buffers layout on the ram-disk (RAM_DISK_MUSIC)

.global _gc_song_data

; These GC_TASKS buffers are GC_BUFFER_SIZE bytes long.
; Each buffer is a runtime unpack stream for a particular AY register.
; IT MUST BE ALIGNED by GC_BUFFER_SIZE
_gc_reg_streams = GC_RUNTIME_DATA_RD
			;.storage GC_BUFFER_SIZE * GC_TASKS, $00

; each stream is unpacked by individual task. each task has its own stack in
; this buffer.
_gc_task_stacks = _gc_reg_streams + GC_BUFFER_SIZE * GC_TASKS
			;.storage GC_STACK_SIZE * GC_TASKS, $00

; loaded music data
_gc_song_data = _gc_task_stacks + GC_STACK_SIZE * GC_TASKS
; each element of this array points to particular compressed AY reg stream.
_gc_packed_reg_stream_ptrs = _gc_song_data
_gc_packed_reg_streams = _gc_packed_reg_stream_ptrs + GC_TASKS * ADDR_LEN