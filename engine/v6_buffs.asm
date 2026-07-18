; V6 runtime buffers

;===============================================================================
; Temporary Buffer
;===============================================================================
; Usage:
; - unpacking tiled image index data
; - unpacking text data

TEMP_BUFF_LEN	= $200
temp_buff: 		.storage TEMP_BUFF_LEN
