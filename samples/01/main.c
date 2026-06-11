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

extern uint8_t _v6_gc_buffer[];
extern uint8_t song01_ay_reg_data_ptrs[];

V6C_NOINLINE_ASM_EXTERN
extern void v6_gc_init_song(uint8_t* ay_reg_data_ptrs, uint8_t* song_data);
V6C_NOINLINE_ASM_EXTERN
extern void v6_gc_start();


void main() {
    // Set the palette
    memcpy(v6_palette, palette, sizeof(palette));
    v6_palette_update_request = PALETTE_UPD_REQ_YES;


    v6_gc_init_song(song01_ay_reg_data_ptrs, _v6_gc_buffer);
    v6_gc_start();

    while (true){
        v6c_hlt();
    }
}