#!/usr/bin/env python3
"""The two flags on the WARDEN page (the warden's language): pixel flags, 24 x 16, drawn
from the flags' geometry sampled 8 x 8 per pixel, each pixel the colour most of it is
(no blends: they sit on the menu's nearest-scaled plates).

Run from the repo root:  python tools/gen_flags.py
"""
import math
import os
from collections import Counter

from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot", "assets", "textury", "ui")
W, H, SS = 24, 16, 8
WHITE = (236, 232, 222)
RED = (190, 30, 42)
BLUE = (22, 52, 118)
UK_BLUE = (24, 40, 104)


def czech(u, v):
    # the blue wedge from the hoist to the middle, white over red
    if u < 0.5 * (1.0 - abs(v - 0.5) * 2.0):
        return BLUE
    return WHITE if v < 0.5 else RED


def union_jack(u, v):
    # in the flag's own 60 x 30 units, squeezed to 3:2
    x, y = u * 60.0, v * 30.0
    if abs(x - 30) < 3 or abs(y - 15) < 3:
        return RED
    if abs(x - 30) < 5 or abs(y - 15) < 5:
        return WHITE
    # the saltires (at this size the red runs down their middle)
    d1 = abs(x * 30 - y * 60) / math.hypot(30, 60)
    d2 = abs(x * 30 + y * 60 - 1800) / math.hypot(30, 60)
    if d1 < 1.6 or d2 < 1.6:
        return RED
    if d1 < 4.2 or d2 < 4.2:
        return WHITE
    return UK_BLUE


def draw(fn, name):
    img = Image.new("RGB", (W, H))
    for py in range(H):
        for px in range(W):
            c = Counter()
            for sy in range(SS):
                for sx in range(SS):
                    c[fn((px + (sx + 0.5) / SS) / W, (py + (sy + 0.5) / SS) / H)] += 1
            img.putpixel((px, py), c.most_common(1)[0][0])
    path = os.path.join(OUT, name)
    img.save(path)
    print(path)


if __name__ == "__main__":
    draw(czech, "flag_cs.png")
    draw(union_jack, "flag_en.png")
