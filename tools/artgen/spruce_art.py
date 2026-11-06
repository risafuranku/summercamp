#!/usr/bin/env python3
"""A spruce's boughs for the trees' cards: process.py's sprite with the magenta's fringe off.

    python tools/artgen/spruce_art.py <artgen id>

Writes godot/assets/textury/world/spr_spruce_tier.png.
"""
import os
import subprocess
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
DEST = "assets/textury/world/spr_spruce_tier.png"


def main():
    art_id = sys.argv[1]
    subprocess.check_call([sys.executable, os.path.join(HERE, "process.py"), art_id, "sprite", "128", DEST])
    path = os.path.join(HERE, "..", "..", "godot", DEST)
    im = Image.open(path).convert("RGBA")
    px = im.load()
    w, h = im.size
    # Pink left along the edges: gone. (The stems' brown has less blue than green.)
    for _ in range(2):
        drop = []
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a == 0:
                    continue
                edge = any(not (0 <= x + dx < w and 0 <= y + dy < h) or px[x + dx, y + dy][3] == 0 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if edge and r > g and b > g * 0.75:
                    drop.append((x, y))
        for x, y in drop:
            px[x, y] = (0, 0, 0, 0)
    # Anything pink still in the picture: the green beside it.
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a and r > g * 1.05 and b > g * 0.9:
                px[x, y] = (int(g * 0.8), g, int(g * 0.6), 255)
    im.save(path)
    print("defringed", path)


main()
