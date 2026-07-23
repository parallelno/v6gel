@echo off

echo.
echo === samples/01_controls/build.bat: samples/01_controls ====================
echo Demonstrates reading input and sending debug output. Use arrow keys and
echo check the keycode response in stdout output.

set CURRENT_DIR=%~dp0

pushd .
rem Define V6_ASM, V6_LLVMC, EMU build paths
call samples/common/paths.bat
rem Define (OUT_DIR, OUT_ROM, PROJECT_NAME, v6_o) vars, compile main and v6 library
call samples/common/build_setup.bat --symbols
popd

echo.
echo === samples/01_controls/build.bat: Linking ================================
set target=-target i8080-unknown-v6c
set STACK_DEF=-Wl,--defsym=__stack_top=%STACK_MAIN_PROGRAM_ADDR%
%V6_LLVMC%/clang %target% %STACK_DEF% -nostdlib -O2 ^
    "%OUT_DIR%/main/main.o" ^
    %v6_o% ^
    -o "%OUT_ROM%"
if %errorlevel% neq 0 exit /b %errorlevel%
echo Linking output to: %OUT_ROM%


echo.
echo === samples/01_controls/build.bat: Run the ROM in the emulator ============
echo Running: %EMU% "%OUT_ROM%"
%EMU% "%OUT_ROM%"