"""Non-invasive function profiler for the sample ROM; reuses verify's IPC client."""
from collections import defaultdict
import hashlib
import json
import re
import time

from verify import Emulator, OUT


def symbols_from_map():
    symbols = {}
    for line in (OUT / '10_sprite_frame_onscr_ai.map').read_text().splitlines():
        match = re.match(r'\s*([0-9a-f]+)\s+[0-9a-f]+\s+[0-9a-f]+\s+\d+\s+(\w+)\s*$', line)
        if match:
            symbols[match[2]] = int(match[1], 16)
    return symbols


class Profiler:
    def __init__(self, emu, symbols):
        self.emu, self.symbols = emu, symbols
        self.installed = set()
        self.entries = {}
        for name in ('check_density', 'wait_band', 'scan_sprites', 'restore_span', 'draw_span'):
            self.entries[symbols[name]] = name
        for name in ('draw_full_sprite', 'restore_full_sprite'):
            self.entries[symbols[name]] = name
        for name, address in symbols.items():
            if re.fullmatch(r'compiled_\d+_\d+|restore_\d+', name):
                self.entries[address] = 'compiled_column' if name.startswith('compiled_') else 'restore_column_kernel'

    def sync_breakpoints(self, wanted):
        for address in self.installed - wanted:
            self.emu.call(61, addr=address)
        for address in wanted - self.installed:
            self.emu.call(60, addr=address, memPages=1, status='ACTIVE', autoDelete=False,
                          operand='A', condition='ANY', value=0, comment='function cost profiler')
        self.installed = set(wanted)

    def resume(self):
        # Advance off the current breakpoint, then run to any entry/return.
        self.emu.call(7)
        regs = self.emu.call(11)
        if regs['pc'] in self.installed:
            return regs
        self.emu.call(1)
        for _ in range(2000):
            if not self.emu.call(3)['isRunning']:
                return self.emu.call(11)
            time.sleep(.001)
        raise TimeoutError('No profiling breakpoint reached')

    def frame(self):
        emu, s = self.emu, self.symbols
        emu.call(62)
        self.installed.clear()
        start = emu.call(11)['cc']
        stats = defaultdict(list)
        stack = []
        band_start = None
        bands = []
        commit_start = None
        base = set(self.entries) | {s['frame_complete'], s['band_begin'], s['band_end'], s['commit_positions']}
        self.sync_breakpoints(base)
        while True:
            regs = self.resume()
            pc, cc = regs['pc'], regs['cc']
            # Tail jumps can give a wrapper and its kernel the same return PC.
            while stack and stack[-1]['exit'] == pc:
                item = stack.pop()
                inclusive = cc - item['start']
                stats[item['name']].append(dict(inclusive=inclusive, self=inclusive-item['children']))
                if stack:
                    stack[-1]['children'] += inclusive
            if pc == s['frame_complete']:
                assert not stack
                break
            if pc == s['band_begin']:
                band_start = cc
            if pc == s['band_end']:
                bands.append(cc-band_start)
            if pc == s['commit_positions'] and commit_start is None:
                commit_start = cc
            if pc in self.entries:
                name = self.entries[pc]
                # Row labels are also reached by fall-through inside a span;
                # only the first row entered from the wrapper is a kernel call.
                if name == 'compiled_column' and stack and stack[-1]['name'] == 'compiled_column':
                    continue
                if name in ('restore_span', 'draw_span'):
                    height = emu.memory(s['job_len'], 1)[0]
                    name += '/full' if height == 15 else '/clipped'
                if name == 'scan_sprites':
                    mode = emu.memory(s['draw_mode'], 1)[0]
                    name += '/draw' if mode else '/erase'
                if name == 'restore_full_sprite':
                    exit_pc = s['restore_full_done']
                elif name == 'restore_column_kernel':
                    exit_pc = s['restore_column_done']
                else:
                    exit_pc = emu.call(17, addr=regs['sp'])['data']
                stack.append(dict(name=name, start=cc, exit=exit_pc, children=0))
            self.sync_breakpoints(base | {item['exit'] for item in stack})
        self.sync_breakpoints(set())
        totals = {name: dict(calls=len(samples), inclusive=sum(x['inclusive'] for x in samples),
                             self=sum(x['self'] for x in samples),
                             min=min(x['inclusive'] for x in samples), max=max(x['inclusive'] for x in samples))
                  for name, samples in sorted(stats.items())}
        elapsed = cc-start
        top = sum(v['self'] for v in totals.values())
        assert len(bands) == 4, (bands, elapsed, totals)
        assert top <= elapsed
        # Every nested interval must reconcile with its wrapper. CALL cost is
        # outside a callee interval, so remains in its parent's self time.
        roots = sum(values['inclusive'] for name, values in totals.items()
                    if name in ('check_density', 'wait_band', 'scan_sprites/draw', 'scan_sprites/erase'))
        assert roots == top, (roots, top)
        return dict(elapsed=elapsed, active_bands=sum(bands), bands=bands,
                    renderer_glue=elapsed-top, commit_tail=cc-commit_start, functions=totals)


def main():
    s = symbols_from_map()
    emu = Emulator()
    try:
        emu.until(s['renderer'])
        background = emu.memory(0xa000, 0x6000)
        rows = json.loads((OUT / 'sprite_reference.json').read_text())
        profiler = Profiler(emu, s)
        results = []
        for frame in range(6):
            if frame:
                positions = bytearray(emu.memory(s['sprites'], 20))
                for i in range(0, 20, 2):
                    positions[i] = (positions[i] + frame*3) % 31
                    positions[i+1] = min(241, max(0, positions[i+1] + (frame if i % 4 else -frame)))
                emu.call(42, addr=s['sprites'], data=list(positions))
            result = profiler.frame()
            # Profiling must leave exactly the same pixels as the independent
            # compositor, including old-footprint erasure between updates.
            positions = emu.memory(s['sprites'], 20)
            expected = bytearray(background)
            for i in range(0, 20, 2):
                x, y = positions[i:i+2]
                for row, columns in enumerate(rows):
                    for column, (mask, *planes) in enumerate(columns):
                        for plane, value in enumerate(planes):
                            address = plane*8192 + (x+column)*256 + y+row
                            expected[address] = (expected[address] & mask) | value
            assert emu.memory(0xa000, 0x6000) == expected, f'Profiled frame {frame} differs'
            results.append(result)
            print(f'Frame {frame}: elapsed={result["elapsed"]}, active={result["active_bands"]}, '
                  f'glue={result["renderer_glue"]}')
            for name, values in result['functions'].items():
                print(f'  {name:25} {values}')
            emu.until(s['renderer'])
        report = dict(emulator=emu.call(-5)['emulatorVersion'],
                      rom_sha256=hashlib.sha256((OUT / '10_sprite_frame_onscr_ai.rom').read_bytes()).hexdigest(),
                      frames=results)
        path = OUT / 'function_profile.json'
        path.write_text(json.dumps(report, indent=2) + '\n')
        print(f'Wrote {path}')
    finally:
        emu.close()


if __name__ == '__main__':
    main()