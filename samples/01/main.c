#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <stdlib.h>
#include <v6c.h>
#include <v6c_rt_macros.h>
#include <v6c_consts.h>

uint8_t palette[16] = {
    0x00, 0x11, 0x22, 0x33,
    0x44, 0x55, 0x66, 0x77,
    0x88, 0x99, 0xAA, 0xBB,
    0xCC, 0xDD, 0xEE, 0xFF
};

extern uint8_t v6_palette[16];
extern uint8_t v6_scr_offset_y;
extern uint8_t v6_palette_update_request;
extern uint16_t v6_action_code;

extern uint8_t _song01_data[];
extern uint8_t GC_STREAM_BUFFERS[];
extern uint8_t RAM_DISK_MUSIC;

V6C_NOINLINE_ASM_EXTERN
extern void v6_gc_init_song();
V6C_NOINLINE_ASM_EXTERN
extern void v6_gc_start();


V6C_INLINE
void dzx0_rd_wrapper(
    const uint8_t* source, uint8_t* target, uint8_t ramdisk_cmd)
{
    register uint16_t _comp asm("DE") = (uint16_t)source;
    register uint16_t _uncomp asm("BC") = (uint16_t)target;
    register uint8_t _cmd asm("A") = ramdisk_cmd;
    asm (
        // de - compressed data addr
        // bc - uncompressed data addr
        // a - RAM Disk activation command
        "CALL dzx0_rd      \n"
         : /* no output */
         : /* no input constraints */
         : "A", "BC", "DE", "HL", "FLAGS"  /* clobbered registers */
    );
}


void main() {
    // Set the palette
    memcpy(v6_palette, palette, sizeof(palette));
    v6_palette_update_request = PALETTE_UPD_REQ_YES;

    // unpack the song data to the ram-disk and start the music player
    dzx0_rd_wrapper(_song01_data, GC_STREAM_BUFFERS, RAM_DISK_MUSIC);
    v6_gc_init_song();
    v6_gc_start();

    while (true){
        v6c_hlt();
    }
}