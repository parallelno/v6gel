@echo off

echo.
echo === samples\04_tiled_img: Build script ====================================
echo Purpose: Demonstrate how to export and draw tiled images.
echo Prerequisites: add `v6asm`, `clang`, and emulator to PATH
echo Note: update the TOOLS PATHS below if your tools are installed elsewhere.


echo.
echo === TOOLS PATHS (update if required) ======================================
set v6asm=C:\Work\Programming\v6asm\target\release\v6asm
set compiler=C:\Work\Programming\v6llvmc\llvm-build\bin\clang
set emu=C:\Work\Programming\devector\bin\devector
echo v6asm=%v6asm%
echo compiler=%compiler%
echo emu=%emu%

rem === Set the current directory to the location of this script. ==============
set CURRENT_DIR=%~dp0
for %%I in ("%CURRENT_DIR:~0,-1%") do set "PROJECT_NAME=%%~nxI"
set OUT_DIR=build\%PROJECT_NAME%


echo.
echo === Build the assets ======================================================

echo.
rem Export tiled image index data. This blob contains the map layout and
rem per-image metadata consumed by tiled_img_draw.
set tim_data_json=%CURRENT_DIR%assets\tiled_imgs\tim_data.json
set tim_data_o=%OUT_DIR%\tiled_imgs\bin\tim_data.o
echo asset: %tim_data_json%
python -m v6gel.cli.v6export ^
    %tim_data_json% ^
    -o %OUT_DIR%\tiled_imgs\meta ^
    --bin-dir %OUT_DIR%\tiled_imgs\bin ^
    --emit-asm ^
    --emit-obj
if %errorlevel% neq 0 exit /b %errorlevel%

echo.
rem Export tiled image graphics. This blob contains the 8x8 tile graphics
rem shared by the tiled image maps.
set tim_gfx_json=%CURRENT_DIR%assets\tiled_imgs\tim_gfx.json
set tim_gfx_o=%OUT_DIR%\tiled_imgs\bin\tim_gfx.o
echo asset: %tim_gfx_json%
python -m v6gel.cli.v6export ^
    %tim_gfx_json% ^
    -o %OUT_DIR%\tiled_imgs\meta ^
    --bin-dir %OUT_DIR%\tiled_imgs\bin ^
    --emit-asm ^
    --emit-obj
if %errorlevel% neq 0 exit /b %errorlevel%

echo.
rem Export palette: pal_lv1 (16-byte palette plus fade animation metadata).
set pal_lv1_json=%CURRENT_DIR%assets\palettes\pal_lv1.json
set pal_lv1_o=%OUT_DIR%\palettes\bin\pal_lv1.o
echo asset: %pal_lv1_json%
python -m v6gel.cli.v6export ^
    %pal_lv1_json% ^
    -o %OUT_DIR%\palettes\meta ^
    --bin-dir %OUT_DIR%\palettes\bin ^
    --emit-asm ^
    --emit-obj
if %errorlevel% neq 0 exit /b %errorlevel%

echo.
echo === Build the v6 library ==================================================
set v6_o=build\v6\v6.o
rem Build the engine library and emit a symbol table for debugging.
pushd .
call engine\build.bat --symbols
popd
if %errorlevel% neq 0 exit /b %errorlevel%


echo.
echo === Assemble the main file ================================================
%v6asm% "%CURRENT_DIR%main.asm" -o "%OUT_DIR%\main\main.o" -f obj
if %errorlevel% neq 0 exit /b %errorlevel%


echo.
echo === Link the main program with the v6 library =============================
set target=-target i8080-unknown-v6c
set STACK_MAIN_PROGRAM_ADDR=0x100
set STACK_DEF=-Wl,--defsym=__stack_top=%STACK_MAIN_PROGRAM_ADDR%

%compiler% %target% %STACK_DEF% -nostdlib -O2 ^
    "%OUT_DIR%\main\main.o" ^
    %v6_o% ^
    %tim_data_o% ^
    %tim_gfx_o% ^
    %pal_lv1_o% ^
    -o "%OUT_DIR%\%PROJECT_NAME%.rom"
if %errorlevel% neq 0 exit /b %errorlevel%


echo.
echo === Run the ROM in the emulator ===========================================
echo Running: %emu% "%OUT_DIR%\%PROJECT_NAME%.rom"
%emu% "%OUT_DIR%\%PROJECT_NAME%.rom"