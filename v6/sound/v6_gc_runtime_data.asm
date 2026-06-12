	; This line is for proper formatting in VSCode
@memusage_v6_gc_runtime_data:


V6_GC_BUFFER_LEN = GC_BUFFER_SIZE * GC_TASKS


/*
; ==--------------------------------------------------------------------------==
; v6_gc_buffer was moved over the RAM Disk
; ==--------------------------------------------------------------------------==
.align GC_BUFFER_SIZE
; these are GC_TASKS buffers GC_BUFFER_SIZE bytes long
; MUST BE ALIGNED by 0x100
v6_gc_buffer:
			.storage V6_GC_BUFFER_LEN
v6_gc_buffer_end:
*/

/*
; ==--------------------------------------------------------------------------==
; v6_gc_task_stack was moved over the RAM Disk
; task stacks. GC_STACK_SIZE bytes stack long for each tasks
; ==--------------------------------------------------------------------------==
V6_GC_TASK_STACK_LEN = GC_STACK_SIZE * GC_TASKS
v6_gc_task_stack:
			.storage V6_GC_TASK_STACK_LEN
v6_gc_task_stack_end:
*/

.opt
; array of task stack pointers. v6_gc_task_sps[i] = taskSP
V6_GC_TASK_SPS_LEN = GC_TASKS * WORD_LEN
v6_gc_task_sps:
			.storage V6_GC_TASK_SPS_LEN
v6_gc_task_sps_end:


; points to a current task sp.
; *v6_gc_current_task_spp = v6_gc_task_sps[current_task]
v6_gc_current_task_spp:
			.storage WORD_LEN


; bufferN[buffer_idx] data will be send to AY for each register accordingly
v6_gc_buffer_idx:
			.storage BYTE_LEN
v6_gc_task_id:
			.storage BYTE_LEN


v6_song_reg_data_ptrs_end: ; contains the end of the array of ptrs to the song reg data
			.storage WORD_LEN