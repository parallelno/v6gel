@echo off

echo.
echo === samples/03_music: Build script ====================================
echo Purpose: Demonstrate how to export and play a music track.
echo Prerequisites: add `v6asm`, `clang`, and emulator to PATH
echo Note: update the TOOLS PATHS in ./samples/common/paths.bat if your tools
echo are installed elsewhere.


set CURRENT_DIR=%~dp0
set STACK_MAIN_PROGRAM_ADDR=0x100
set V6_INTERRUPTIONS=1
set V6_CONTROLS=1
set V6_MUSIC=1


pushd .
rem Define V6ASM, V6LLVMC, EMU build paths
call samples/common/paths.bat
rem Define OUT_DIR, OUT_ROM, PROJECT_NAME, v6_o vars
call samples/common/build_setup.bat


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


rem === Compile main and v6 library ============================================
call samples/common/build_v6_main.bat --symbols
if %errorlevel% neq 0 exit /b %errorlevel%
popd


echo.
echo === samples/03_music/build.bat: Linking =================================
set target=-target i8080-unknown-v6c
%V6LLVMC%/clang %target% -nostdlib -O2 ^
    "%OUT_DIR%/main/main.o" ^
    %v6_o% ^
    %song_o% ^
    -Wl,-Map,"%OUT_DIR%/%PROJECT_NAME%.map" ^
    -Wl,--v6c-constants-map,"%OUT_DIR%/%PROJECT_NAME%.constants.map" ^
    -o "%OUT_ROM%"
if %errorlevel% neq 0 exit /b %errorlevel%
echo Linking output to: %OUT_ROM%


echo.
echo === samples/03_music/build.bat: Run the ROM in the emulator ============
echo Running: %EMU% "%OUT_ROM%"
%EMU% "%OUT_ROM%"