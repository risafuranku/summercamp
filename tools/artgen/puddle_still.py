#!/usr/bin/env python3
"""The rain's puddle calmed down (playtest 25. 10.: the puddles "look more like oil"):
assets/textury/world/puddle.png (Grok) -> world/puddle_still.png. Its muddy rim stays;
inside it the marbled light and dark (a sheen of oil, or foam) is smoothed and flattened
toward one grey, the water a little darker toward the rim, the sky's light in it given by
the game (scripts/ambient/ground_life.gd).

    python tools/artgen/puddle_still.py
"""
import os

from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
WORLD = os.path.join(HERE, "..", "..", "godot", "assets", "textury", "world")
RIM = 2          # px of the mud edge kept as it is
CALM = 0.8       # how much of the marbling goes


def main():
    src = Image.open(os.path.join(WORLD, "puddle.png")).convert("RGBA")
    w, h = src.size
    alpha = src.getchannel("A")
    # Distance from the edge in px (a few erosions of the opaque mask).
    inner = []
    m = alpha.point(lambda a: 255 if a >= 128 else 0)
    for _ in range(RIM + 3):
        m = m.filter(ImageFilter.MinFilter(3))
        inner.append(m)
    smooth = src.convert("RGB").filter(ImageFilter.GaussianBlur(3))
    px = src.load()
    sm = smooth.load()
    # The water's own grey: the mean of the inside.
    tot = [0, 0, 0]
    n = 0
    core = inner[RIM].load()
    for y in range(h):
        for x in range(w):
            if core[x, y]:
                r, g, b, _ = px[x, y]
                tot[0] += r
                tot[1] += g
                tot[2] += b
                n += 1
    mean = [t / max(1, n) for t in tot]
    out = src.copy()
    op = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 128:
                continue
            depth = sum(1 for k in inner if k.load()[x, y])
            if depth <= RIM:
                continue
            k = CALM * min(1.0, (depth - RIM) / 3.0)
            s = sm[x, y]
            # Toward the smoothed picture, then toward the one grey; a little darker near
            # the rim (the water deepens to the middle less than the sheen did).
            c = [px[x, y][i] * (1 - k) + (s[i] * 0.4 + mean[i] * 0.6) * k for i in range(3)]
            shade = 0.86 + 0.14 * min(1.0, (depth - RIM) / 4.0)
            op[x, y] = (int(c[0] * shade), int(c[1] * shade), int(c[2] * shade), a)
    dest = os.path.join(WORLD, "puddle_still.png")
    out.save(dest)
    print(dest, out.size)


if __name__ == "__main__":
    main()
