echo off
set CURRENT_DIR=%~dp0

for %%I in ("%CURRENT_DIR:~0,-1%") do set "PROJECT_NAME=%%~nxI"
echo %PROJECT_NAME%


rem Build the assets.
python -m v6gel.cli.build_assets %CURRENT_DIR%assets\config.json -o build\%PROJECT_NAME% --fdd-template %CURRENT_DIR%assets\basefdd\rds308.fdd

rem Build the v6 library.
engine\build.bat
