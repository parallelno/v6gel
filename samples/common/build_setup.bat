
echo.
echo === samples/common/build_setup.bat ========================================
rem requires: set CURRENT_DIR to the location of the calling script.

rem === Set the project name to the name of the current directory ==============
for %%I in ("%CURRENT_DIR:~0,-1%") do set "PROJECT_NAME=%%~nxI"
set OUT_DIR=build/%PROJECT_NAME%
set OUT_ROM=%OUT_DIR%/%PROJECT_NAME%.rom

set main_o=%OUT_DIR%/main/main.o

echo main_o=%main_o%
echo OUT_DIR=%OUT_DIR%
echo OUT_ROM=%OUT_ROM%