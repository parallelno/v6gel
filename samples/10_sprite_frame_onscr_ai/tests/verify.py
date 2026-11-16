"""End-to-end emulator test; Python standard library only (MessagePack subset)."""
import json
import os
from pathlib import Path
import re
import socket
import struct
import subprocess
import time

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'build/10_sprite_frame_onscr_ai'


def pack(v):
    if isinstance(v, bool):
        return bytes([0xc3 if v else 0xc2])
    if isinstance(v, int):
        return (b'\xd3' + struct.pack('>q', v)) if v < 0 else (b'\xcf' + struct.pack('>Q', v))
    if isinstance(v, str):
        b = v.encode()
        return b'\xdb' + struct.pack('>I', len(b)) + b
    if isinstance(v, list):
        return b'\xdd' + struct.pack('>I', len(v)) + b''.join(map(pack, v))
    return b'\xdf' + struct.pack('>I', len(v)) + b''.join(pack(k) + pack(x) for k, x in v.items())


def unpack(data):
    pos = 0

    def take(n):
        nonlocal pos
        value = data[pos:pos+n]
        pos += n
        return value

    def read():
        b = take(1)[0]
        if b < 128:
            return b
        if b >= 224:
            return b - 256
        if b in (0xc2, 0xc3):
            return b == 0xc3
        if b == 0xc0:
            return None
        formats = {0xcc: 'B', 0xcd: 'H', 0xce: 'I', 0xcf: 'Q',
                   0xd0: 'b', 0xd1: 'h', 0xd2: 'i', 0xd3: 'q', 0xca: 'f', 0xcb: 'd'}
        if b in formats:
            fmt = '>' + formats[b]
            return struct.unpack(fmt, take(struct.calcsize(fmt)))[0]
        if 0xa0 <= b <= 0xbf:
            return take(b & 31).decode()
        if 0x90 <= b <= 0x9f:
            return [read() for _ in range(b & 15)]
        if 0x80 <= b <= 0x8f:
            return {read(): read() for _ in range(b & 15)}
        sizes = {0xc4: 1, 0xc5: 2, 0xc6: 4, 0xd9: 1, 0xda: 2, 0xdb: 4,
                 0xdc: 2, 0xdd: 4, 0xde: 2, 0xdf: 4}
        n = int.from_bytes(take(sizes[b]), 'big')
        if b in (0xdc, 0xdd):
            return [read() for _ in range(n)]
        if b in (0xde, 0xdf):
            return {read(): read() for _ in range(n)}
        value = take(n)
        return value.decode() if b in (0xd9, 0xda, 0xdb) else value
    return read()


class Emulator:
    def __init__(self):
        with socket.socket() as s:
            s.bind(('127.0.0.1', 0))
            port = s.getsockname()[1]
        self.process = subprocess.Popen([os.environ['V6EMUL'], '--serve', '-tcp-port', str(port),
                                         '-speed', 'max', '-log-level', 'error'],
                                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(100):
            try:
                self.sock = socket.create_connection(('127.0.0.1', port), timeout=20)
                break
            except OSError:
                time.sleep(.1)
        else:
            raise RuntimeError('Emulator did not start')
        info = self.call(-5)
        assert info['protocolVersion'] == 2
        self.call(2)
        self.call(51, data=True)
        # RESTART starts at address zero. Install a stable jump rather than
        # depending on power-on RAM (which is not guaranteed to contain NOPs).
        self.call(42, addr=0, data=[0xc3, 0, 1])
        self.call(91, data=list((OUT / '10_sprite_frame_onscr_ai.rom').read_bytes()),
                  addr=256, autorun=False)

    def call(self, cmd, **data):
        payload = pack(dict(cmd=cmd, data=data))
        self.sock.sendall(struct.pack('<I', len(payload)) + payload)

        def recv(n):
            result = b''
            while len(result) < n:
                part = self.sock.recv(n-len(result))
                if not part:
                    raise ConnectionError('Emulator disconnected')
                result += part
            return result
        response = unpack(recv(struct.unpack('<I', recv(4))[0]))
        assert response['ok'], response
        return response.get('data')

    def memory(self, addr, length):
        return bytes(self.call(93, addr=addr, len=length)['data'])

    def breakpoint(self, addr):
        self.call(62)
        self.call(60, addr=addr, memPages=1, status='ACTIVE', autoDelete=False,
                  operand='A', condition='ANY', value=0, comment='sample 10 test')

    def until(self, addr):
        self.breakpoint(addr)
        self.call(7)
        self.call(1)
        for _ in range(1000):
            if not self.call(3)['isRunning']:
                break
            time.sleep(.01)
        result = self.call(11)
        assert result['pc'] == addr, result
        return self.call(11)['cc']

    def close(self):
        self.sock.close()
        self.process.terminate()
        self.process.wait(timeout=10)


def main():
    symbols = {}
    for line in (OUT / '10_sprite_frame_onscr_ai.map').read_text().splitlines():
        m = re.match(r'\s*([0-9a-f]+)\s+[0-9a-f]+\s+[0-9a-f]+\s+\d+\s+(\w+)\s*$', line)
        if m:
            symbols[m[2]] = int(m[1], 16)
    emu = Emulator()
    try:
        emu.until(symbols['renderer'])
        background = emu.memory(0xa000, 0x6000)
        rows = json.loads((OUT / 'sprite_reference.json').read_text())
        measurements = []
        for frame in range(6):
            if frame:
                # Exercise motion, byte-column wrapping, and band crossing.
                p = bytearray(emu.memory(symbols['sprites'], 20))
                for i in range(0, 20, 2):
                    p[i] = (p[i] + frame * 3) % 31
                    p[i+1] = min(241, max(0, p[i+1] + (frame if i % 4 else -frame)))
                emu.call(42, addr=symbols['sprites'], data=list(p))
            positions = emu.memory(symbols['sprites'], 20)
            expected = bytearray(background)
            for i in range(0, 20, 2):
                x, y = positions[i:i+2]
                for row, columns in enumerate(rows):
                    for col, (mask, *planes) in enumerate(columns):
                        for plane, value in enumerate(planes):
                            a = plane * 8192 + (x+col)*256 + y+row
                            expected[a] = (expected[a] & mask) | value
            start = emu.call(11)['cc']
            end = emu.until(symbols['frame_complete'])
            actual = emu.memory(0xa000, 0x6000)
            errors = [i for i, (a, b) in enumerate(zip(actual, expected)) if a != b]
            if errors:
                print('positions', list(positions), 'errors', [(hex(i+0xa000), actual[i], expected[i]) for i in errors[:25]])
            assert not errors, f'Frame {frame}: {len(errors)} wrong bytes, first {errors[:12]}'
            measurements.append(end-start)
            emu.until(symbols['renderer'])
        print('Reference compositor: 6 moving frames passed; elapsed cycles:', measurements)
        active = []
        for _ in range(12):
            a = emu.until(symbols['band_begin'])
            y = emu.memory(symbols['band_y'], 1)[0]
            raster = emu.call(19)
            b = emu.until(symbols['band_end'])
            active.append(b-a)
            phase = raster['rasterLine'] * 192 + raster['rasterPixel'] // 4
            next_top = (40 + 192-y) * 192
            deadline = (next_top-phase) % 59904
            assert b-a < deadline, (y, b-a, deadline)
            print('band', y, 'cycles', b-a, 'deadline in', deadline)
        totals = [sum(active[i:i+4]) for i in range(0, len(active), 4)]
        print('Active band cycles per update:', totals, 'maximum band:', max(active))
        assert max(totals) < 117488
        emu.until(symbols['renderer'])
        before = emu.memory(0xa000, 0x6000)
        old = emu.memory(symbols['old_sprites'], 20)
        emu.call(42, addr=symbols['sprites'], data=[12, 120] * 10)
        emu.until(symbols['frame_complete'])
        assert emu.memory(0xa000, 0x6000) == before
        assert emu.memory(symbols['old_sprites'], 20) == old
        assert int.from_bytes(emu.memory(symbols['deferred_frames'], 2), 'little') > 0
        print('Overloaded ten-sprite band: safely deferred without screen writes')
    finally:
        emu.close()


if __name__ == '__main__':
    main()