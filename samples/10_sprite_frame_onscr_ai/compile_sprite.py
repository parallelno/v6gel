"""Compile the exported knight's first frame into clipped 8080 drawing spans."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'build/10_sprite_frame_onscr_ai'


def decode():
    data = (OUT / 'sprites/bin/KNIGHT.BIN').read_bytes()
    # The exporter stores alternating plane order, in screen-memory Y order.
    height, width = data[4:6]
    assert (height, width) == (15, 1)
    rows = []
    pos = 6
    for y in range(height):
        row = [None, None]
        for col in ([0, 1] if y % 2 == 0 else [1, 0]):
            mask, *planes = data[pos:pos + 4]
            pos += 4
            if col == 1:
                planes.reverse()
            row[col] = [mask, *planes]
        rows.append(row)
    return rows


def pixel_code(mask, value):
    """Specialize a masked store while preserving every transparent bit."""
    if mask == 255 and value == 0:
        return []
    if mask == 0:
        return [f'    mvi m, {value}']
    if value == (mask ^ 255):
        return ['    mov a, m', f'    ori {value}', '    mov m, a']
    return ['    mov a, m', f'    ani {mask}'] + ([f'    ori {value}'] if value else []) + ['    mov m, a']


def main():
    rows = decode()
    lines = ['; Generated straight-line prefix/suffix kernels; HL=screen, E=initial Y.',
             '; Slots 0..14: prefix lengths, slots 15..29: suffix start rows.',
             'draw_spans:', '    .word 0']
    lines += ['    .word ' + ', '.join(f'draw_prefix_{n}' for n in range(1, 15))]
    lines += ['    .word ' + ', '.join(f'draw_suffix_{n}' for n in range(15))]
    lines += ['restore_lengths:', '    .word 0',
              '    .word ' + ', '.join(f'restore_span_{n}' for n in range(1, 16))]
    spans = [(f'draw_prefix_{n}', 0, n) for n in range(1, 15)]
    spans += [(f'draw_suffix_{n}', n, 15-n) for n in range(15)]
    for label, first, length in spans:
        lines.append(f'{label}:')
        if first == 0 and length == 15:
            lines.append('draw_full_sprite:')
        for c in range(6):
            if c:
                # Adjacent byte columns use INR H; alternating vertical
                # direction removes the Y reset at every column transition.
                lines += ['    inr h'] if c % 2 else ['    mov a, h', '    adi 31', '    mov h, a']
            offsets = range(length) if c % 2 == 0 else range(length-1, -1, -1)
            for step, offset in enumerate(offsets):
                mask, *planes = rows[first+offset][c % 2]
                lines += pixel_code(mask, planes[c // 2])
                if step != length-1:
                    lines.append('    inr l' if c % 2 == 0 else '    dcr l')
        lines.append('    ret')
    for length in range(1, 16):
        lines.append(f'restore_span_{length}:')
        if length == 15:
            lines.append('restore_full_sprite:')
        for c in range(6):
            if c:
                lines += ['    mov l, e', '    mov a, h', f'    adi {1 if c % 2 else 31}', '    mov h, a']
            lines.append('    sphl')
            for offset in range(length // 2):
                lines += ['    pop b', '    mov m, c', '    inr l', '    mov m, b']
                if offset*2+2 < length:
                    lines.append('    inr l')
            if length % 2:
                lines += ['    pop b', '    mov m, c']
        lines.append('    jmp restore_full_done')
    (OUT / 'compiled.asm').write_text('\n'.join(lines) + '\n')
    (OUT / 'sprite_reference.json').write_text(json.dumps(rows))


if __name__ == '__main__':
    main()