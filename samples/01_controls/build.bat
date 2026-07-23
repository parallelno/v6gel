@echo off

echo.
echo === samples/01_controls: Build script ====================================
echo Purpose: build and run the controls sample that demonstrates reading input
echo and sending debug output.

rem === Set the current directory to the location of this script. ==============
set CURRENT_DIR=%~dp0

rem === Define (V6_ASM, V6_LLVMC, EMU) build paths =====
pushd .
call samples\common\paths.bat
rem === Define (OUT_DIR, PROJECT_NAME, v6_o) vars, compile main and v6 library =====
call samples\common\build_setup.bat --symbols
popd


echo.
echo === Link the main program with the v6 library =============================
set target=-target i8080-unknown-v6c
set STACK_DEF=-Wl,--defsym=__stack_top=%STACK_MAIN_PROGRAM_ADDR%
%V6_LLVMC% %target% %STACK_DEF% -nostdlib -O2 ^
    "%OUT_DIR%/main/main.o" ^
    %v6_o% ^
    -o "%OUT_DIR%/%PROJECT_NAME%.rom"
if %errorlevel% neq 0 exit /b %errorlevel%


echo.
echo === Run the ROM in the emulator ===========================================
echo Running: %EMU% "%OUT_DIR%/%PROJECT_NAME%.rom"
%EMU% "%OUT_DIR%/%PROJECT_NAME%.rom"