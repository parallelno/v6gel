# 4. v6gel Library Reference

The runtime library lives in `v6/` and is assembled by `v6/build.bat` into
`out/v6.o`. `v6.asm` `.include`s every subsystem and provides the crt0 startup
(`_start`) that sets the stack, clears `.bss`, installs the 50 Hz interrupt
vector, and calls your `main`.

Routines follow the V6C calling convention, so they are callable from C or
assembly. Register usage for each routine is noted where the source comments make
it clear; consult the corresponding `.asm` file for exact register contracts.

> Symbol names below are taken directly from the engine source. Internal helper
> macros are omitted; the focus is the API a game actually calls.

---

## Graphics — `gfx/`

### Sprites
| Routine | Purpose |
|---------|---------|
| `sprite_init_meta_data` | Initialize a list of sprite metadata (RAM-disk access + animation). `HL`=metadata list, `E`=count. |
| `sprite_uninit_meta_data` | Tear down sprite metadata. `HL`=list, `E`=count. |
| `sprite_draw_vm` | Draw a variable-height masked sprite. `BC`=sprite data, `DE`=screen addr. Returns width/height. |
| `sprite_erase` | Clear a sprite area. `DE`=screen addr, `HL`=width/height. |
| `sprite_copy_to_scr_v` | Copy a sprite from a back buffer to the screen. |
| `sprite_copy_to_back_buff_v` | Copy a sprite between back buffers. |
| `sprite_draw_invis_vm` | Compute sprite bounds without drawing. |
| `sprite_draw_hit_vm` | Draw a monochrome "hit" sprite *(deprecated format)*. |
| `sprite_get_addr` | Resolve a sprite data address from an animation pointer. |
| `sprite_get_scr_addr8` / `_addr4` / `_addr1` | Compute a screen address for 8-/4-pixel pre-shifted or aligned sprites. |
| `sprite_scr_addr_to_pos` | Convert a screen address back to a sprite position. |

### Tiles & backgrounds
| Routine | Purpose |
|---------|---------|
| `draw_tile_16x16` | Draw a 16×16 tile across the screen buffers. `BC`=tile gfx ptr, `DE`=screen addr. |
| `draw_back_v` | Draw a background sprite (16×N, no alpha). |
| `draw_decal_v` | Draw a decal sprite (16×N, with alpha). |

### Tiled images
| Routine | Purpose |
|---------|---------|
| `tiled_img_init_idxs` | Load a tiled image's index stream. `A`=RAM-disk cmd, `HL`=idx data. |
| `tiled_img_init_gfx` | Load a tiled image's gfx tiles. `A`=RAM-disk cmd, `HL`=gfx data. |
| `tiled_img_draw` | Draw a tiled image. `DE`=local idx data. |
| `tiled_img_draw_pos_offset_set` | Draw a tiled image at a position offset. |

### Text
| Routine | Purpose |
|---------|---------|
| `text_ex_init_font` | Initialize the proportional font. `A`=RAM-disk cmd, `HL`=font gfx ptrs, `BC`=font global addr. |
| `text_ex_init_text` | Initialize a text data block. `A`=RAM-disk cmd, `HL`=text data. |
| `text_ex_draw` | Draw proportional text with kerning. `DE`=text addr, `HL`=optional scr-pos offset. |
| `text_ex_draw_pos_offset_set` | Draw text at a position offset. |
| `text_ex_set_spacing` / `text_ex_reset_spacing` | Set / reset line & paragraph spacing. |
| `text_ex_set_scr_addr` | Choose the destination screen buffer. |
| `text_mono_draw` | Draw monospaced text. `HL`=text ptr, `BC`=screen addr. |
| `draw_fps` | Draw an FPS counter *(optional)*. `A`=fps value. |

Text control codes: `LINE_BREAK` (`0x6A`), `PARAG_BREAK` (`0xFF`), `EOD` (`0`).

---

## Sound — `sound/`

### Music — "GigaChad" AY player
| Routine | Purpose |
|---------|---------|
| `v6_gc_init` | Initialize the music system *(optional)*. |
| `v6_gc_init_song` | Prepare a new song (pauses, clears buffers) before playback. |
| `v6_gc_start` | Start / resume the prepared song. |
| `v6_gc_update` | Advance the player one frame (decompresses register data); call from the interrupt. |
| `v6_gc_pause` / `v6_gc_unpause` / `v6_gc_flip_pause` | Pause control. |
| `v6_gc_get_setting` | Query the music on/off setting. |

Global: `setting_music` (`SETTING_OFF` / `SETTING_ON`).

### Sound effects (8253 timer)
| Routine | Purpose |
|---------|---------|
| `v6_sfx_player_init` | Initialize the SFX player. |
| `v6_sfx_reg_mute` | Silence the sound chip. |

Predefined SFX patterns include `sfx_vampire_attack`, `sfx_bomb_attack`,
`sfx_hero_hit`, `sfx_song_hi_pitch`.

### Combined wrapper
| Routine | Purpose |
|---------|---------|
| `v6_sound_init` | Initialize both music and SFX. |
| `v6_sound_update` | Update both each frame (calls the music and SFX updates). |

---

## Controls — `controls/`

| Symbol | Purpose |
|--------|---------|
| `controls_check` | Read keyboard/joystick and update the action code (call from the interrupt). |
| `controls_keys_check` / `controls_joy_check` | Read the keyboard matrix / the joystick. |
| `v6_action_code` | Current input bitfield. |
| `action_code_old` | Previous frame's action code (edge detection). |

Action-code bits: `RIGHT`(0), `LEFT`(1), `UP`(2), `DOWN`(3), `RETURN`(4),
`KEY_SPACE`(5), `FIRE2`(6), `FIRE1`(7). Constant prefix: `CONTROL_CODE_*`.

---

## OS & files — `os/`

| Routine | Purpose |
|---------|---------|
| `v6_os_init` | Initialize the OS: RDS mode, screen mapping, interrupt vector. `HL`=interrupt routine. |
| `load_files_from_params` | Load several files described by a parameter list. `HL`=params, `E`=count. |
| `load_file` / `save_file` / `del_file` | Single-file load / save / delete via BDOS. |
| `set_file_name` / `copy_filebase` | Build / copy FCB filenames. |
| `v6_os_exit` | Clean exit back to the system. |
| `v6_os_error_*` | Standard error messages (file open, hardware, invalid FCB). |

Useful macros: `SYS_CALL` / `SYS_CALL_D` (BDOS calls),
`FILE_LOAD_PARAMS(...)` (build a file-load record).

---

## Misc — `misc/`

### Interrupt
| Symbol | Purpose |
|--------|---------|
| `v6_interruption` | The 50 Hz handler: reads input, updates the palette, drives sound, and sets up the main-program stack. |

### Memory
| Routine | Purpose |
|---------|---------|
| `mem_erase` / `mem_fill` | Zero / fill a buffer. |
| `mem_erase_sp` / `mem_fill_sp` | Fast stack-based erase / fill. |
| `mem_copy` | Copy a buffer. |
| `mem_copy_from_ram_disk` / `mem_copy_to_ram_disk` | Copy between RAM and the RAM disk. |
| `get_word_from_ram_disk` / `get_word_from_scr_ram_disk` | Read a 16-bit word from RAM-disk memory. |
| `restore_sp` | Restore the stack pointer and disable the RAM disk. |

### Palette
| Routine | Purpose |
|---------|---------|
| `set_palette` / `set_palette_int` | Apply a 16-color palette (main / from interrupt). |
| `copy_palette_request_update` | Request a palette update on the next interrupt. |
| `pallete_fade_init` / `pallete_fade_update` | Drive a palette fade; `pallete_fade_out` / `pallete_fade_in` for full fades. |

Globals: `v6_palette` (16 bytes), `v6_palette_update_request`, `v6_scr_offset_y`.

### Decompression & RNG
| Routine | Purpose |
|---------|---------|
| `dzx0` / `dzx0_rd` | ZX0 decompress to RAM / to RAM disk. |
| `random` | 16-bit XORshift PRNG. Returns `HL`=value; seed at `random+1`. |

### Address utilities
| Routine | Purpose |
|---------|---------|
| `add_offset_to_labels_eod` | Relocate an EOD-terminated label array by an offset. |
| `add_offset_to_labels_len` | Relocate a length-prefixed label array by an offset. |
| `empty_func` | No-op placeholder (immediate return). |

---

## Common — `common/`

`common/v6_consts.asm` and `common/v6_macros.asm` define the global constants and
utility macros used across the engine.

### Screen memory
| Constant | Value |
|----------|-------|
| `SCR_ADDR` / `SCR_BUFF0_ADDR` | `0x8000` |
| `SCR_BUFF1_ADDR` | `0xA000` |
| `SCR_BUFF2_ADDR` | `0xC000` |
| `SCR_BUFF3_ADDR` | `0xE000` |
| `SCR_BUFF_LEN` | `0x2000` (8 KB) |

### Hardware ports
| Constant | Value | Purpose |
|----------|-------|---------|
| `PORT_AY_REG` / `PORT_AY_DATA` | `0x15` / `0x14` | AY-3-8910 register / data. |
| `PORT_TIMER` | `0x08` | 8253 timer. |
| `PORT0_OUT_OUT` / `PORT0_OUT_IN` | `0x88` / `0x8A` | I/O port. |

### Repeat / address macros (selection)
`HLT_(n)`, `RRC_(n)`, `RAL_(n)`, `RLC_(n)`, `PUSH_B(n)`, `PUSH_H(n)`, `POP_H(n)`,
`INX_H(n)`, `DCX_H(n)`, `LXI_B/D/H(val)`, `HL_ADVANCE(...)`, `RAM_DISK_ON(...)`,
`RAM_DISK_OFF(...)`.

> v6asm macros are invoked with parentheses — `RRC_(3)`, `PUSH_B(8)`,
> `FILE_LOAD_PARAMS(...)` — and support default parameter values.
