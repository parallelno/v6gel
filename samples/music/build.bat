
REM Build v6 library.

REM Tools paths.
set v6asm=C:\Work\Programming\v6asm\target\release\v6asm
set zx0=C:\Work\Programming\v6\tools\zx0\zx0salvador.exe -classic


REM Set the current directory to the location of this script.
cd /d "%~dp0"

REM Assemble the song data
%v6asm% song01_data.asm -o out\song01_data.bin
if %errorlevel% neq 0 exit /b %errorlevel%

REM Compress the song data using the tools/zx0/ compressor.
%zx0% out\song01_data.bin out\song01_data.zx0
if %errorlevel% neq 0 exit /b %errorlevel%

echo Assemble the v6 library.
%v6asm% song01.asm -o out\song01.o -f obj
if %errorlevel% neq 0 exit /b %errorlevel%


echo.
echo Done.