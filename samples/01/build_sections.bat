@echo off

REM Update the path to emulator devector.exe if needed.
set s=samples\04_game
set out=%s%\out
set app=%s%\app\music
set v6asm=tools\v6asm\v6asm.exe
set e=C:\Work\Programming\devector\bin\devector.exe

REM Set the compiler and emulator paths.
set compiler=llvm-build\bin\clang
set emulator=tools\v6emul\v6emul

set target=-target i8080-unknown-v6c
set stack_addr=0x8000
set stack_def=-Wl,--defsym=__stack_top=%stack_addr%

REM Assemble the v6 library.
@echo on

%v6asm% %s%\asm\v6\v6_interruption.asm -o %out%\v6_interruption.o -f obj -I %s%

@echo off
REM Check for build errors.
if %errorlevel% neq 0 exit /b %errorlevel%
@echo on

REM Print the sections in v6_interruption.o into file out\v6_interruption_sections.txt.
llvm-build\bin\llvm-readelf -S %out%\v6_interruption.o > %out%\v6_interruption_sections.txt

REM Print the symbols in v6_interruption.o into file out\v6_interruption_symbols.txt.
llvm-build\bin\llvm-readelf -s %out%\v6_interruption.o > %out%\v6_interruption_symbols.txt

REM Assemble the song01.
%v6asm% %app%\song01.asm -o %out%\song01.o -f obj -I %s%
REM Check for build errors.
if %errorlevel% neq 0 exit /b %errorlevel%

@echo off
REM Build the ROM. --print-gc-sections makes lld report every section it
REM garbage-collected (removed) during the link. -Map writes a link map that
REM lists every input section (per-function) that SURVIVED the garbage collection.
@echo on
%compiler% %target% -O2 %stack_def% %s%\main.c %out%\v6_interruption.o %out%\song01.o -o %out%\main.rom
@echo off
REM Check for build errors.
if %errorlevel% neq 0 exit /b %errorlevel%
@echo on

REM Compile asm
%compiler% %target% -O2 %s%\main.c -S -o %out%\main.s

REM Link an ELF (the .elf extension keeps an ELF instead of a flat ROM) so the
REM full symbol table - including externals resolved at link time such as
REM _v6_gc_task_stack_end - can be dumped.
%compiler% %target% -O2 %stack_def% %s%\main.c %out%\v6_interruption.o %out%\song01.o -o %out%\main.elf

REM Print all symbols of the linked file into out\main_symbols.txt.
llvm-build\bin\llvm-readelf -s %out%\main.elf > %out%\main_symbols.txt

REM Print the link map: surviving input sections (per function) and their
REM addresses/sizes after garbage collection.
type %out%\main.map
