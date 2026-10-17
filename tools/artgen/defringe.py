#!/usr/bin/env python3
"""Remove the magenta key's leftovers from processed sprites: edge pixels (next to a
transparent one) with a pink/purple cast are made transparent; one pass, then a second
for the next ring in.

    python tools/artgen/defringe.py godot/assets/textury/hands/*.png

--figure (people: the co-op wardens) does this instead (the plain pass would thin a red
jacket's edge): the dark-red rim the key leaves where the render blended it into dark
hair and outlines takes the colour of the pixels inside it. --rows=a-b,c-d keeps that to
those bands of the picture (0 top .. 1 bottom), for a figure whose clothes are red:

    python tools/artgen/defringe.py --figure godot/assets/textury/npc/warden_a.png
    python tools/artgen/defringe.py --figure --rows=0-0.22,0.62-1 godot/assets/textury/npc/warden_b.png
"""
import sys

from PIL import Image


def pinkish(r, g, b):
    return r > g + 28 and b > g + 18


def red(c):
    r, g, b, a = c
    return a > 0 and r > 60 and r > g * 1.7 and r > b * 1.25


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


def figure(path, rows):
    img = Image.open(path).convert("RGBA")
    px = img.load()
    w, h = img.size
    fixed = gone = 0
    for _pass in range(2):
        changes = []
        for y in range(h):
            if rows and not any(lo <= y / h < hi for lo, hi in rows):
                continue
            for x in range(w):
                if not red(px[x, y]):
                    continue
                nb = [(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if 0 <= x + dx < w and 0 <= y + dy < h]
                if len(nb) == 4 and not any(px[q][3] == 0 for q in nb):
                    continue
                around = nb + [(x + 1, y + 1), (x - 1, y - 1), (x + 1, y - 1), (x - 1, y + 1)]
                inner = [px[q] for q in around if 0 <= q[0] < w and 0 <= q[1] < h and px[q][3] > 0 and not red(px[q])]
                if inner:
                    changes.append(((x, y), tuple(int(sum(c[i] for c in inner) / len(inner)) for i in range(3)) + (255,)))
                else:
                    changes.append(((x, y), (0, 0, 0, 0)))
        for q, c in changes:
            px[q] = c
            if c[3] == 0:
                gone += 1
            else:
                fixed += 1
    img.save(path)
    return "rim fixed %d, gone %d" % (fixed, gone)


def main():
    rows = []
    as_figure = False
    files = []
    for a in sys.argv[1:]:
        if a == "--figure":
            as_figure = True
        elif a.startswith("--rows="):
            for band in a[len("--rows="):].split(","):
                lo, hi = band.split("-")
                rows.append((float(lo), float(hi)))
        else:
            files.append(a)
    for p in files:
        print(p, figure(p, rows) if as_figure else defringe(p))


if __name__ == "__main__":
    main()
