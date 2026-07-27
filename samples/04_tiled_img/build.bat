@echo off

echo.
echo === samples/04_tiled_img: Build script ====================================
echo Purpose: Demonstrate how to export and draw tiled images.
echo Prerequisites: add `v6asm`, `clang`, and emulator to PATH
echo Note: update the TOOLS PATHS in ./samples/common/paths.bat if your tools
echo are installed elsewhere.


set CURRENT_DIR=%~dp0
set STACK_MAIN_PROGRAM_ADDR=0x100
set V6_INTERRUPTIONS=1
set V6_CONTROLS=0
set V6_MUSIC=0


pushd .
rem Define V6ASM, V6LLVMC, EMU build paths
call samples/common/paths.bat
rem Define OUT_DIR, OUT_ROM, PROJECT_NAME, v6_o vars
call samples/common/build_setup.bat


echo.
echo === Build the assets ======================================================

echo.
rem Export tiled image index data. This blob contains the map layout and
rem per-image metadata consumed by tiled_img_draw.
set tim_data_json=%CURRENT_DIR%assets/tiled_imgs/tim_data.json
set tim_data_o=%OUT_DIR%/tiled_imgs/bin/tim_data.o
echo asset: %tim_data_json%
python -m v6gel.cli.v6export ^
    %tim_data_json% ^
    -o %OUT_DIR%/tiled_imgs/asm ^
    --manifest-dir %OUT_DIR%/tiled_imgs/manifests ^
    --bin-dir %OUT_DIR%/tiled_imgs/bin ^
    --emit-asm ^
    --emit-obj
if %errorlevel% neq 0 exit /b %errorlevel%

echo.
rem Export tiled image graphics. This blob contains the 8x8 tile graphics
rem shared by the tiled image maps.
set tim_gfx_json=%CURRENT_DIR%assets/tiled_imgs/tim_gfx.json
set tim_gfx_o=%OUT_DIR%/tiled_imgs/bin/tim_gfx.o
echo asset: %tim_gfx_json%
python -m v6gel.cli.v6export ^
    %tim_gfx_json% ^
    -o %OUT_DIR%/tiled_imgs/asm ^
    --manifest-dir %OUT_DIR%/tiled_imgs/manifests ^
    --bin-dir %OUT_DIR%/tiled_imgs/bin ^
    --emit-asm ^
    --emit-obj
if %errorlevel% neq 0 exit /b %errorlevel%

echo.
rem Export palette: pal_lv1 (16-byte palette plus fade animation metadata).
set pal_lv1_json=%CURRENT_DIR%assets/palettes/pal_lv1.json
set pal_lv1_o=%OUT_DIR%/palettes/bin/pal_lv1.o
echo asset: %pal_lv1_json%
python -m v6gel.cli.v6export ^
    %pal_lv1_json% ^
    -o %OUT_DIR%/palettes/asm ^
    --manifest-dir %OUT_DIR%/palettes/manifests ^
    --bin-dir %OUT_DIR%/palettes/bin ^
    --emit-asm ^
    --emit-obj
if %errorlevel% neq 0 exit /b %errorlevel%


rem === Compile main and v6 library ============================================
call samples/common/build_v6_main.bat --symbols
if %errorlevel% neq 0 exit /b %errorlevel%
popd


echo.
echo === samples/04_tiled_img/build.bat: Linking =================================
set target=-target i8080-unknown-v6c
%V6LLVMC%/clang %target% -nostdlib -O2 ^
    "%OUT_DIR%/main/main.o" ^
    %v6_o% ^
    %tim_data_o% ^
    %tim_gfx_o% ^
    %pal_lv1_o% ^
    -Wl,-Map,"%OUT_DIR%/%PROJECT_NAME%.map" ^
    -Wl,--v6c-constants-map,"%OUT_DIR%/%PROJECT_NAME%.constants.map" ^
    -o "%OUT_ROM%"
if %errorlevel% neq 0 exit /b %errorlevel%
echo Linking output to: %OUT_ROM%


echo.
echo === samples/04_tiled_img/build.bat: Run the ROM in the emulator ============
echo Running: %EMU% "%OUT_ROM%"
%EMU% "%OUT_ROM%"