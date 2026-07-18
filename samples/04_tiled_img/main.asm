; ---------------------------------------------------------------------------
; This demo shows how to use engine-provided services:
;    * draw tiled images
; Notes:
;   - Tiled editor is used to produce the tiled image source data.
;   - Tiled editor exports the tmj (Tiled Map JSON) file.
;   - The exporter parses the tmj file and generates index and graphical data
;     for use in the engine.
;   - The exporter requires two json source files to describe the tiled image
;     asset, `tiled_img_data` type is for tile indexes and `tiled_img_gfx` type is
;     for tile graphics.
;   - Both JSON source files reference one json source file with type
;     `tiled_img`. This file contains the general metadata for the tiled image
;     asset as well as the path to the Tiled map JSON (tmj) file.
;   - The core idea of separating one tiled image asset into index and graphics
;     data is to allow efficient memory usage (less asset, more effective asset
;     layout in the RAM disk).
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Tiled Image source format:
;   The source asset is a JSON file that contains fields:
;	  "path_png"     - path to the PNG file containing the tiled image graphics
;	  "palette_path" - path to the JSON file containing the palette data
;	  "asset_type"   - type of the asset
;	  "path"         - path to tmj (Tiled format output) file.
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Tiled Image index data source format:
;   The source asset is a JSON file that contains fields:
;     "asset_type"     - type of the asset
;     "path_tiled_img" - path to the Tiled image data (json), in this case "tim.json"
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Tiled Image tile graphics source format:
;   The source asset is a JSON file that contains fields:
;     "asset_type"     - type of the asset
;     "path_tiled_img" - path to the Tiled image data (json), in this case "tim.json"
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Tiled Image index data metadata format:
;   The *_meta.asm file is always linked into the main program and exposes:
;
;     <NAME>_FILE_LEN        .filesize of the .bin blob (resolved at link time)
;     <NAME>_LAST_RECORD_LEN FILE_LEN & 0x7F  (size of the last CP/M record)
;     <NAME>_FILENAME_PTR    CP/M 8.3 filename string (only present when the
;                            asset was exported with --emit-filename; required
;                            for COM executables that load the blob from FDD)
;
;   ROM executables do not need it.
;   COM executables use FILENAME_PTR to locate the file on the disk.
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Tiled Image index data format:
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Tiled Image tile graphics format:
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Tiled Image API
;  `tiled_img_init_idxs`  - initialize index tables for tiled images
;  `tiled_img_init_gfx`   - initialize graphics blob for drawing
;  `tiled_img_draw`       - draw a tiled image given a local pointer in DE
; ---------------------------------------------------------------------------

; Import engine constants and helper macros.
.include "../../engine/common/v6_consts.asm"
.include "../../engine/common/v6_macros.asm"

; Include generated metadata for tiled image data and palette.
.include "build/04_tiled_img/tiled_imgs/meta/tim_data_meta.asm"
.include "build/04_tiled_img/palettes/meta/pal_lv1_meta.asm"

.global main

main:
            ; Apply palette fade metadata (prepares palette state)
            lxi d, _pal_lv1 + _pal_lv1_palette_fade_to_black_relative
            call palette_fade_reverse

            ; Initialize and draw the background layer
            A_TO_ZERO(RAM_DISK_OFF_CMD)
            lxi h, _tim_data
            call tiled_img_init_idxs
            A_TO_ZERO(RAM_DISK_OFF_CMD)
            lxi h, _tim_gfx
            call tiled_img_init_gfx
            lxi d, _tim_main_menu_back
            call tiled_img_draw

            ; Initialize and draw the foreground layer
            A_TO_ZERO(RAM_DISK_OFF_CMD)
            lxi h, _tim_data
            call tiled_img_init_idxs
            A_TO_ZERO(RAM_DISK_OFF_CMD)
            lxi h, _tim_gfx
            call tiled_img_init_gfx
            lxi d, _tim_main_menu_front
            call tiled_img_draw

            ret
