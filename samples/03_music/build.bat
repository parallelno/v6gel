@echo off

echo.
echo === samples/03_music: Build script ====================================
echo Purpose: Demonstrate how to export and play a music track.
echo Prerequisites: add `v6asm`, `clang`, and emulator to PATH
echo Note: update the TOOLS PATHS below if your tools are installed elsewhere.


echo.
echo === TOOLS PATHS (update if required) ======================================
set v6asm=C:/Work/Programming/v6asm/target/release/v6asm
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
rem Export music: song01 (v6gel exporter handles packing and optional compression)
set song01_json=%CURRENT_DIR%assets/music/song01.json
set song_o=%OUT_DIR%/music/bin/song01.o
echo asset: %song01_json%
python -m v6gel.cli.v6export ^
    %song01_json% ^
    -o %OUT_DIR%/music/asm ^
    --manifest-dir %OUT_DIR%/music/manifests ^
    --bin-dir %OUT_DIR%/music/bin ^
    --emit-asm ^
    --emit-obj ^
    --compress
if %errorlevel% neq 0 exit /b %errorlevel%


echo.
echo === Build the v6 library ==================================================
set v6_o=build/v6/v6.o
rem Build engine library (use --symbols to emit symbol table useful for debugging)
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
    %song_o% ^
    -o "%OUT_DIR%/%PROJECT_NAME%.rom"
if %errorlevel% neq 0 exit /b %errorlevel%


echo.
echo === Run the ROM in the emulator ===========================================
echo Running: %emu% "%OUT_DIR%/%PROJECT_NAME%.rom"
%emu% "%OUT_DIR%/%PROJECT_NAME%.rom"