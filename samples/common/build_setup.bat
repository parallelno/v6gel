
echo.
echo === samples/common/build_setup.bat: Build setup script ====================
echo Purpose: build main and v6 library


rem requires: set CURRENT_DIR to the location of the calling script

rem requires: update the TOOLS PATHS below if your tools are installed elsewhere.
rem v6asm (https://github.com/parallelno/v6asm)
rem clang (https://github.com/parallelno/v6llvmc)
rem devector emulator (https://github.com/parallelno/devector)

set V6_ASM=C:/Work/Programming/v6asm/target/release/v6asm
set V6_LLVMC=C:/Work/Programming/v6llvmc/llvm-build/bin/clang
set EMU=C:/Work/Programming/devector/bin/devector

set STACK_MAIN_PROGRAM_ADDR=0x100

echo CURRENT_DIR=%CURRENT_DIR%
echo OUT_DIR=%OUT_DIR%
echo PROJECT_NAME=%PROJECT_NAME%
echo v6 assembler: %V6_ASM%
echo v6 llvm C compiler/linker: %V6_LLVMC%
echo emulator: %EMU%
echo STACK_MAIN_PROGRAM_ADDR=%STACK_MAIN_PROGRAM_ADDR%

rem === Set the project name to the name of the current directory ==============
for %%I in ("%CURRENT_DIR:~0,-1%") do set "PROJECT_NAME=%%~nxI"
set OUT_DIR=build/%PROJECT_NAME%
echo OUT_DIR=%OUT_DIR%


echo.
echo === Build the v6 library ==================================================
set v6_o=build/v6/v6.o
rem Build engine library (use --symbols to emit symbol table useful for debugging)
pushd .
call engine/build.bat %1
popd
if %errorlevel% neq 0 exit /b %errorlevel%


echo.
echo === Assemble the main file ================================================
%V6_ASM% "%CURRENT_DIR%main.asm" -o "%OUT_DIR%/main/main.o" -f obj
if %errorlevel% neq 0 exit /b %errorlevel%
