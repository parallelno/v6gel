"""Exercise every clipping split, dense bands and randomized admitted updates."""
import json
import random

from profile_renderer import Profiler, symbols_from_map
from verify import Emulator, OUT


def reference(background, rows, positions):
    result = bytearray(background)
    for x, y in zip(positions[::2], positions[1::2]):
        for row, columns in enumerate(rows):
            for column, (mask, *planes) in enumerate(columns):
                for plane, value in enumerate(planes):
                    address = plane*8192 + (x+column)*256 + y+row
                    result[address] = (result[address] & mask) | value
    return result


def main():
    symbols = symbols_from_map()
    emu = Emulator()
    try:
        emu.until(symbols['renderer'])
        background = emu.memory(0xa000, 0x6000)
        plane0 = emu.memory(0x8000, 8192)
        rows = json.loads((OUT / 'sprite_reference.json').read_text())
        rng = random.Random(8080)
        scenes = []
        for split in range(1, 15):
            ys = [64-split]*2 + [128-split]*2 + [192-split]*2 + [17, 30, 220, 235]
            xs = [0, 1, 10, 11, 20, 21, 29, 30, 12, 12]
            scenes.append([v for pair in zip(xs, ys) for v in pair])
        # Four complete overlapping sprites maximize active work in one band.
        for y in (0, 64, 128, 192):
            other = [(y+64) % 256 + 16]*3 + [(y+128) % 256 + 24]*3
            ys = [y+16]*4 + other
            scenes.append([v for i, yy in enumerate(ys) for v in (min(30, i*3), yy)])
        while len(scenes) < 50:
            ys = [rng.randrange(242) for _ in range(10)]
            counts = [sum(y < base+64 and y+15 > base for y in ys) for base in range(0, 256, 64)]
            if max(counts) <= 4:
                scenes.append([v for y in ys for v in (rng.randrange(31), y)])
        driver = Profiler(emu, symbols)
        elapsed = []
        margins = []
        transactions = []
        for index, positions in enumerate(scenes):
            emu.call(42, addr=symbols['sprites'], data=positions)
            emu.call(62)
            driver.installed.clear()
            driver.sync_breakpoints({symbols[n] for n in ('band_begin', 'band_end', 'frame_complete')})
            start = emu.call(11)['cc']
            visited = set()
            while True:
                regs = driver.resume()
                if regs['pc'] == symbols['frame_complete']:
                    break
                if regs['pc'] == symbols['band_begin']:
                    y = emu.memory(symbols['band_y'], 1)[0]
                    assert y not in visited
                    visited.add(y)
                    raster = emu.call(19)
                    phase = raster['rasterLine']*192 + raster['rasterPixel']//4
                    # A valid start must be AFTER the whole band, not merely
                    # finish before the next top while starting inside it.
                    since_bottom = (phase-(296-y)*192) % 59904
                    assert since_bottom < (312-64)*192, (index, y, raster)
                    deadline = ((232-y)*192-phase) % 59904
                    band_start = regs['cc']
                else:
                    cycles = regs['cc']-band_start
                    assert cycles < deadline, (index, y, cycles, deadline)
                    margins.append(deadline-cycles)
                    transactions.append(cycles)
            assert visited == {0, 64, 128, 192}
            elapsed.append(regs['cc']-start)
            assert emu.memory(0xa000, 0x6000) == reference(background, rows, positions), index
            assert emu.memory(0x8000, 8192) == plane0, index
            driver.sync_breakpoints(set())
            emu.until(symbols['renderer'])
        print(f'Stress: {len(scenes)} updates, {len(transactions)} beam-safe bands; '
              f'all 14 splits and reference pixels passed')
        print(f'Maximum band cycles: {max(transactions)}; minimum deadline margin: {min(margins)}')
        print(f'Elapsed update range: {min(elapsed)}..{max(elapsed)}; '
              f'under 117488: {sum(x < 117488 for x in elapsed)}/{len(elapsed)}')
        (OUT / 'stress_results.json').write_text(json.dumps(dict(
            updates=len(scenes), bands=len(transactions), max_band=max(transactions),
            min_margin=min(margins), elapsed=elapsed), indent=2) + '\n')
    finally:
        emu.close()


if __name__ == '__main__':
    main()