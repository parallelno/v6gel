;=======================================================
; RDS (based on CP/M 2.2) Consts
;=======================================================

; CP/M BDOS functions
CPM_SUB_PRINT			= 09 ; 0x09 Print a string terminated by '$'
CPM_SUB_F_DMAOFF		= 26 ; 0x1A Set the address of a custom I/O file buffer 128 byte long
CPM_SUB_F_OPEN			= 15 ; 0x0F Open file
CPM_SUB_F_READ			= 20 ; 0x14 Read file sequentially
CPM_SUB_F_WRITE			= 21 ; 0x15 Save file sequentially
CPM_SUB_F_CLOSE			= 16 ; 0x10 Close file
CPM_SUB_F_MAKE			= 22 ; 0x16 Make File
CPM_SUB_F_DELETE		= 19 ; 0x13 Delete file
;CPM_SUB_DRV_ALLRESET	= 13 ; 0x0D Reset all drives
CPM_SUB_F_SFIRST		= 17 ; 0x11 Search for first file
CPM_SUB_DRV_GET			= 25 ; 0x19 Get current drive
CPM_SUB_DRV_SET			= 14 ; 0x0E Set current drive

; CPM_BDOS entry point
CPM_BDOS    	= 0x0005 ; system call
CPM_EXIT		= 0x0000 ; exit to the system

; CP/M system constants
CPM_FCB				= 0x005C
FILE_NAME_ADDR		= CPM_FCB + 1
CMP_DMA_BUFFER		= 0x0080
CMP_DMA_BUFFER_LEN	= 128
CPM_FCB_LEN			= CMP_DMA_BUFFER - CPM_FCB
BASENAME_LEN		= 8
EXT_LEN				= 3
FILENAME_LEN		= BASENAME_LEN + EXT_LEN
; errors
CPM_MSG_ERROR			= 0xFF
CPM_MSG_SUCCESS			= 0x00
CPM_MSG_EOF				= 0x01 ; the end of file
CPM_MSG_INVALID_FCB		= 0x09

; RDS system addresses
RDS_DISK			= 0x0004 ; Contains the disk number. 0=currently used, 1=A:, 2=B:, etc.

RDS_SCR_MODE		= 0x003C ; normally contains 0x23. to set the screen buffer mode, set it to RDS_SCR_MODE_ON
RDS_SCR_MODE_ON 	= 0 ; 0x0A000-0xDFFF range is mapped to the Screen buffer

RDS_MODE			= 0x003E ; set it to RDS_MODE_0 or RDS_MODE_1 to enable the RDS mode
RDS_MODE_0			= 0x80 ; 0x100-0xF400 ram available to the user program. The console is enabled.
RDS_MODE_1			= 0x81 ; 0x100-0xFFFF ram available. The console is disabled.


; RDS BDOS functions
RDS_SUB_SCR_MODE	= 0x0 ; Call to set the RDS mode

; program consts
DISK_CURRENT	= 0 ; 0=currently used, 1=A:, 2=B:, etc.
DISK_A			= 1
DISK_B			= 2

V6_OS_LOAD_STORE_META = 0

/*
;=======================================================
; File Control Block (CPM_FCB)
;=======================================================

A 36-byte structure used by CP/M as an input and output
parameter for file and disk operations. It is located at
0x005C in system memory but can be modified by the user.

CPM_FCB:
			.byte 0				; Drive (0 = default, 1 = A:, 2 = B:, etc.)
			.byte "FILENAME"	; 8-character file name. Upper case only.
			.byte "EXT"			; 3-character file type Upper case only.
@EX:		.byte 0				; Current extent. Set this to 0 before opening a file.
@S1:		.byte 0				; Reserved.
@S2:		.byte 0				; Reserved. Extent high byte. RDS increments it by 1
								; after loading next 16k bytes (RECORD_COUNT * DMA_BUFFER_LEN = 128*128=16384).
								; I assume RECORD_COUNT * DMA_BUFFER_LEN is an extent size. Not sure.
@RC:		.byte 0				; FILE'S RECORD COUNT (0 TO 128). Set this to 0 when opening a file.
								; when file's opened, CP/M will set it to the number of records (128*RC) in the file.
@AL:		.storage 0x10		; Reserved.
@CR:		.byte 0				; Current record within extent. Set this to 0 before opening or making a file.
@Rn:		.byte 0, 0, 0		; Random access record number. A 16-bit value in CP/M 2 (with R2 used for overflow)


.align 16
CMP_DMA_BUFFER:
	.storage 128          ; DMA buffer for reading data (128 bytes)
*/