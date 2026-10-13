#!/usr/bin/env python3
"""Remove the magenta key's leftovers from processed sprites: edge pixels (next to a
transparent one) with a pink/purple cast are made transparent; one pass, then a second
for the next ring in.

    python tools/artgen/defringe.py godot/assets/textury/hands/*.png
"""
import sys

from PIL import Image


def pinkish(r, g, b):
    return r > g + 28 and b > g + 18


def defringe(path):
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    removed = 0
    for _pass in range(2):
        px = img.load()
        kill = []
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a == 0 or not pinkish(r, g, b):
                    continue
                edge = False
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if nx < 0 or ny < 0 or nx >= w or ny >= h or px[nx, ny][3] == 0:
                        edge = True
                        break
                if edge:
                    kill.append((x, y))
        for x, y in kill:
            px[x, y] = (0, 0, 0, 0)
        removed += len(kill)
    img.save(path)
    return removed


for p in sys.argv[1:]:
    print(p, defringe(p))
