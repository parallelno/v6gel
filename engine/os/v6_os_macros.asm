.macro SYS_CALL_D(func_id, d_addr)
	    mvi c, func_id
		lxi d, d_addr
		di
		call CPM_BDOS
		di
.endmacro

.macro SYS_CALL(func_id)
	    mvi c, func_id
		di
		call CPM_BDOS
		di
.endmacro
