@echo off

rem Build v6 engine library.

rem required: set V6ASM to the path of the v6 assembler
rem required: set V6LLVMC to the path of the v6 llvm C compiler and tools

set v6_o=build/v6/v6.o
echo v6_o=%v6_o%

echo.
echo === engine/build.bat: Build the v6 library ================================
setlocal
set CURRENT_DIR=%~dp0
%V6ASM% %CURRENT_DIR%v6.asm ^
    -D V6_CONTROLS=%V6_CONTROLS% ^
    -D V6_MUSIC=%V6_MUSIC% ^
    -D V6_INTERRUPTIONS=%V6_INTERRUPTIONS% ^
    -D STACK_MAIN_PROGRAM_ADDR=%STACK_MAIN_PROGRAM_ADDR% ^
    -o %v6_o% ^
    -f obj
endlocal
if %errorlevel% neq 0 exit /b %errorlevel%

rem === Print symbols if --symbols flag is set =================================
if "%1"=="--symbols" (
    %V6LLVMC%/llvm-readelf -s %v6_o% > %v6_o%.symtab
)