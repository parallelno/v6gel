@echo off

echo.
echo === samples/05_text_ex: Build script ====================================
echo Purpose: Demonstrate how to export and draw text with non monospaced fonts.
echo Prerequisites: add `v6asm`, `clang`, and emulator to PATH
echo Note: update the TOOLS PATHS below if your tools are installed elsewhere.


echo.
echo === TOOLS PATHS (update if required) ======================================
set v6asm=C:/Work\Programming\v6asm\target\release\v6asm
set compiler=C:/Work/Programming/v6llvmc/llvm-build/bin/clang
set emu=C:/Work/Programming/devector/bin/devector
echo v6asm=%v6asm%
echo compiler=%compiler%
echo emu=%emu%

rem === Set the current directory to the location of this script. ==============
set CURRENT_DIR=%~dp0
for %%I in ("%CURRENT_DIR:~0,-1%") do set "PROJECT_NAME=%%~nxI"
set OUT_DIR=build/%PROJECT_NAME%


echo.
echo === Build the assets ======================================================

echo.
rem Export font: font
set font_json=%CURRENT_DIR%assets/fonts/eng/font.json
set font_o=%OUT_DIR%/fonts/bin/font.o
echo asset: %font_json%
python -m v6gel.cli.v6export ^
    %font_json% ^
    -o %OUT_DIR%/fonts/meta ^
    --bin-dir %OUT_DIR%/fonts/bin ^
    --emit-asm ^
    --emit-obj
if %errorlevel% neq 0 exit /b %errorlevel%

echo.
rem Export text: txt_menu.json
set txt_menu_json=%CURRENT_DIR%assets/text/txt_menu.json
set txt_menu_o=%OUT_DIR%/text/bin/txt_menu.o
echo asset: %txt_menu_json%
python -m v6gel.cli.v6export ^
    %txt_menu_json% ^
    -o %OUT_DIR%/text/meta ^
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
    -o %OUT_DIR%/palettes/meta ^
    --bin-dir %OUT_DIR%/palettes/bin ^
    --emit-asm ^
    --emit-obj
if %errorlevel% neq 0 exit /b %errorlevel%

echo.
echo === Build the v6 library ==================================================
set v6_o=build/v6/v6.o
rem Build the engine library and emit a symbol table for debugging.
pushd .
call engine/build.bat --symbols
popd
if %errorlevel% neq 0 exit /b %errorlevel%


echo.
echo === Assemble the main file ================================================
%v6asm% "%CURRENT_DIR%main.asm" -o "%OUT_DIR%/main/main.o" -f obj
if %errorlevel% neq 0 exit /b %errorlevel%


echo.
echo === Link the main program with the v6 library =============================
set target=-target i8080-unknown-v6c
set STACK_MAIN_PROGRAM_ADDR=0x100
set STACK_DEF=-Wl,--defsym=__stack_top=%STACK_MAIN_PROGRAM_ADDR%

%compiler% %target% %STACK_DEF% -nostdlib -O2 ^
    "%OUT_DIR%/main/main.o" ^
    %v6_o% ^
    %font_o% ^
    %txt_menu_o% ^
    %pal_lv1_o% ^
    -o "%OUT_DIR%/%PROJECT_NAME%.rom"
if %errorlevel% neq 0 exit /b %errorlevel%


echo.
echo === Run the ROM in the emulator ===========================================
echo Running: %emu% "%OUT_DIR%/%PROJECT_NAME%.rom"
%emu% "%OUT_DIR%/%PROJECT_NAME%.rom"