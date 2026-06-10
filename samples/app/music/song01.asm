; build_config.asm
OMMIT_ORG = true

.include "song01_data.asm"

.global song01_ay_reg_data_ptrs

_song01_ay_reg_data00_relative = 0x0ee0
_song01_ay_reg_data01_relative = 0x122f
_song01_ay_reg_data02_relative = 0x133a
_song01_ay_reg_data03_relative = 0x167d
_song01_ay_reg_data04_relative = 0x1847
_song01_ay_reg_data05_relative = 0x1e1e
_song01_ay_reg_data06_relative = 0x1e8f
_song01_ay_reg_data07_relative = 0x26c8
_song01_ay_reg_data08_relative = 0x28e0
_song01_ay_reg_data09_relative = 0x29a6
_song01_ay_reg_data10_relative = 0x2b7c
_song01_ay_reg_data11_relative = 0x2d7d
_song01_ay_reg_data12_relative = 0x3020
_song01_ay_reg_data13_relative = 0x3027


.opt
song01_ay_reg_data_ptrs:
			.word _song01_ay_reg_data00_relative, _song01_ay_reg_data01_relative, _song01_ay_reg_data02_relative, _song01_ay_reg_data03_relative, _song01_ay_reg_data04_relative, _song01_ay_reg_data05_relative, _song01_ay_reg_data06_relative, _song01_ay_reg_data07_relative, _song01_ay_reg_data08_relative, _song01_ay_reg_data09_relative, _song01_ay_reg_data10_relative, _song01_ay_reg_data11_relative, _song01_ay_reg_data12_relative, _song01_ay_reg_data13_relative,
.endopt