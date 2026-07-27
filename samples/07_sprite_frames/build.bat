@echo off

echo.
echo === samples/07_sprite_frames: Build script ================================
echo Purpose: Demonstrate sprite frames.
echo Prerequisites: add v6asm, clang, and an emulator to PATH.
echo Note: update the TOOLS PATHS in ./samples/common/paths.bat if your tools
echo are installed elsewhere.


set CURRENT_DIR=%~dp0
set STACK_MAIN_PROGRAM_ADDR=0x100
set V6_INTERRUPTIONS=1
set V6_CONTROLS=1
set V6_MUSIC=0


pushd .
rem Define V6ASM, V6LLVMC, EMU build paths
call samples/common/paths.bat
rem Define OUT_DIR, OUT_ROM, PROJECT_NAME, v6_o vars
call samples/common/build_setup.bat


echo.
echo === Build the assets ======================================================

echo.
rem Export palette: pal_lv1 (contains 16-byte palette + fade animation metadata)
set pal_lv1_json=%CURRENT_DIR%assets\palettes\pal_lv1.json
set pal_lv1_o=%OUT_DIR%\palettes\bin\pal_lv1.o
echo asset: %pal_lv1_json%
python -m v6gel.cli.v6export ^
    %pal_lv1_json% ^
    -o %OUT_DIR%\palettes\asm ^
    --manifest-dir %OUT_DIR%\palettes\manifests ^
    --bin-dir %OUT_DIR%\palettes\bin ^
    --emit-asm ^
    --emit-obj
if %errorlevel% neq 0 exit /b %errorlevel%

echo.
rem Export sprite: knight (image + animation sequences)
set knight_json=%CURRENT_DIR%assets\sprites\knight.json
set knight_o=%OUT_DIR%\sprites\bin\knight.o
echo asset: %knight_json%
python -m v6gel.cli.v6export ^
    %knight_json% ^
    -o %OUT_DIR%\sprites\asm ^
    --manifest-dir %OUT_DIR%\sprites\manifests ^
    --bin-dir %OUT_DIR%\sprites\bin ^
    --emit-asm ^
    --emit-obj
if %errorlevel% neq 0 exit /b %errorlevel%


rem === Compile main and v6 library ============================================
call samples/common/build_v6_main.bat --symbols
if %errorlevel% neq 0 exit /b %errorlevel%
popd


echo.
echo === samples/07_sprite_frames/build.bat: Linking =================================
set target=-target i8080-unknown-v6c
%V6LLVMC%/clang %target% -nostdlib -O2 ^
    "%OUT_DIR%/main/main.o" ^
    %v6_o% ^
    %knight_o% ^
    %pal_lv1_o% ^
    -Wl,-Map,"%OUT_DIR%/%PROJECT_NAME%.map" ^
    -Wl,--v6c-constants-map,"%OUT_DIR%/%PROJECT_NAME%.constants.map" ^
    -o "%OUT_ROM%"
if %errorlevel% neq 0 exit /b %errorlevel%
echo Linking output to: %OUT_ROM%


echo.
echo === samples/07_sprite_frames/build.bat: Run the ROM in the emulator ============
echo Running: %EMU% "%OUT_ROM%"
%EMU% "%OUT_ROM%"