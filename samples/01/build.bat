@echo off

set v6asm=C:\Work\Programming\v6asm\target\release\v6asm
set compiler=C:\Work\Programming\v6llvmc\llvm-build\bin\clang
set emu=C:\Work\Programming\devector\bin\devector
set v6=..\..\v6\out\v6.o
set song=..\music\out\song01.o



REM Set the current directory to the location of this script.
cd /d "%~dp0"


set target=-target i8080-unknown-v6c
REM V6 stack addr is defined by STACK_MAIN_PROGRAM_ADDR constant in v6\common\v6_consts.asm
set STACK_MAIN_PROGRAM_ADDR=0x7FFE
set stack_def=-Wl,--defsym=__stack_top=%STACK_MAIN_PROGRAM_ADDR%

echo === Assemble and link the main program with the v6 library and the song data. ===
%compiler% %target% -nostdlib -O2 %stack_def% main.c %v6% %song% -o out\main.rom
if %errorlevel% neq 0 exit /b %errorlevel%

REM Run the ROM in the emulator.
%emu% out\main.rom
