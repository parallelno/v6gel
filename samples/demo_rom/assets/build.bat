REM Build the assets for the rom_asm_only sample.
python -m v6gel.cli.build_assets samples\rom_asm_only\assets\config.json -o build\rom_asm_only --fdd-template samples\rom_asm_only\assets\basefdd\rds308.fdd

REM Build the v6 library.
engine\build.bat
