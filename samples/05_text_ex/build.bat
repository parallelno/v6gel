@echo off

echo.
echo === samples/05_text_ex: Build script =====================================
echo Purpose: Demonstrate how to export and draw text with a proportional font.
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
rem Export font graphics and metadata used by text_ex_draw.
set font_json=%CURRENT_DIR%assets/fonts/sys_font/font.json
set font_o=%OUT_DIR%/fonts/bin/font.o
echo asset: %font_json%
python -m v6gel.cli.v6export ^
    %font_json% ^
    -o %OUT_DIR%/fonts/asm ^
    --manifest-dir %OUT_DIR%/fonts/manifests ^
    --bin-dir %OUT_DIR%/fonts/bin ^
    --emit-asm ^
    --emit-obj
if %errorlevel% neq 0 exit /b %errorlevel%

echo.
rem Export encoded text and layout data referenced by local text labels.
set txt_menu_json=%CURRENT_DIR%assets/text/txt_menu.json
set txt_menu_o=%OUT_DIR%/text/bin/txt_menu.o
echo asset: %txt_menu_json%
python -m v6gel.cli.v6export ^
    %txt_menu_json% ^
    -o %OUT_DIR%/text/asm ^
    --manifest-dir %OUT_DIR%/text/manifests ^
    --bin-dir %OUT_DIR%/text/bin ^
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
echo === samples/05_text_ex/build.bat: Linking =================================
set target=-target i8080-unknown-v6c
%V6LLVMC%/clang %target% -nostdlib -O2 ^
    "%OUT_DIR%/main/main.o" ^
    %v6_o% ^
    %font_o% ^
    %txt_menu_o% ^
    %pal_lv1_o% ^
    -Wl,-Map,"%OUT_DIR%/%PROJECT_NAME%.map" ^
    -Wl,--v6c-constants-map,"%OUT_DIR%/%PROJECT_NAME%.constants.map" ^
    -o "%OUT_ROM%"
if %errorlevel% neq 0 exit /b %errorlevel%
echo Linking output to: %OUT_ROM%


echo.
echo === samples/05_text_ex/build.bat: Run the ROM in the emulator ============
echo Running: %EMU% "%OUT_ROM%"
%EMU% "%OUT_ROM%"