"""AppIcon ASM://PROTOCOL: 1024x1024 RGB без альфы, pixel-art «>_» и «ASM» на чёрном.

Источник иконки — этот скрипт (только стандартная библиотека):
    python3 tools/make_app_icon.py asm-protocol-ios/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
"""
import struct, sys, zlib

N = 1024
BG = (0, 0, 0)
GREEN = (74, 222, 130)      # Term.green
DIM = (140, 140, 140)       # Term.dim
img = [[BG] * N for _ in range(N)]

def block(x0, y0, w, h, c):
    for y in range(max(0, y0), min(N, y0 + h)):
        row = img[y]
        for x in range(max(0, x0), min(N, x0 + w)):
            row[x] = c

# «>_»: ступенчатый шеврон (ячейка 32 px, штрих 2 ячейки) и курсор-блок
C = 32
ox, oy = 256, 214
for i in range(7):
    block(ox + i * C, oy + i * C, 2 * C, C, GREEN)           # верхняя ветвь
    block(ox + i * C, oy + (12 - i) * C, 2 * C, C, GREEN)    # нижняя ветвь
block(ox + 10 * C, oy + 11 * C, 6 * C, 2 * C, GREEN)         # курсор

# «ASM» шрифтом 5x7, пиксель 16 px
FONT = {
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
}
P = 14
text = "ASM"
tw = len(text) * 6 * P - P
tx, ty = (N - tw) // 2, 724
for k, ch in enumerate(text):
    for r, bits in enumerate(FONT[ch]):
        for c, b in enumerate(bits):
            if b == "1":
                block(tx + (k * 6 + c) * P, ty + r * P, P, P, DIM)

raw = b"".join(b"\x00" + bytes(v for px in row for v in px) for row in img)
def chunk(t, d):
    return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", N, N, 8, 2, 0, 0, 0))
       + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
open(sys.argv[1], "wb").write(png)
