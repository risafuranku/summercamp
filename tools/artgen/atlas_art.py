#!/usr/bin/env python3
"""Atlas's icon (the PC's fifth tab, scripts/os98/apps/atlas_app.gd): a red desk globe
with its grid and a black stand, drawn pixel by pixel in four reds as a 1998 icon was
(no render: at 16 and 32 px a drawing reads better than a shrunk picture).

    python tools/artgen/atlas_art.py
-> godot/assets/textury/os98/icons/atlas.png (32 px), atlas_16.png
"""
import math
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ICONS = os.path.normpath(os.path.join(HERE, "..", "..", "godot", "assets", "textury", "os98", "icons"))

BLACK = (16, 16, 16, 255)
GRID = (96, 0, 0, 255)
# Lit to dark, as the light from the upper left falls on the ball.
REDS = [(255, 132, 120, 255), (236, 36, 30, 255), (196, 0, 0, 255), (128, 0, 0, 255)]
STAND = (64, 64, 64, 255)
STAND_LIT = (150, 150, 150, 255)


def globe(size):
    s = size
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    px = img.load()
    big = s >= 32
    cx = (s - 1) / 2.0 - (0.5 if big else 0.0)
    r = s * (0.36 if big else 0.4)
    cy = r + (1.5 if big else 0.6)
    light = (-0.55, -0.6, 0.58)
    ln = math.sqrt(sum(v * v for v in light))
    light = tuple(v / ln for v in light)
    for y in range(s):
        for x in range(s):
            dx = (x + 0.5 - cx - 0.5) / r
            dy = (y + 0.5 - cy - 0.5) / r
            d2 = dx * dx + dy * dy
            if d2 > 1.0:
                continue
            dz = math.sqrt(1.0 - d2)
            lit = dx * light[0] + dy * light[1] + dz * light[2]
            shade = 0 if lit > 0.86 else 1 if lit > 0.5 else 2 if lit > 0.1 else 3
            col = REDS[shade]
            # The grid: the equator and two parallels, the middle meridian and one each
            # side (seen from the front a meridian is an ellipse: x = sin(lon) * the
            # width of the ball at that height); on the small icon the equator and one
            # meridian each side.
            half = math.sqrt(max(0.0, 1.0 - dy * dy))
            line = 0.6 / r if big else 0.55 / r
            on = abs(dy - (0.0 if big else 0.08)) < line
            for lon in ((0.0, 0.82) if big else (0.0,)):
                on = on or abs(abs(dx) - math.sin(lon) * half) < line
            if big:
                on = on or abs(abs(dy) - 0.55) < 0.55 / r
            if on and d2 < 0.9:
                col = GRID if shade < 3 else (70, 0, 0, 255)
            px[x, y] = col
    # The outline.
    for y in range(s):
        for x in range(s):
            if px[x, y][3] == 0:
                continue
            for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + ox, y + oy
                if not (0 <= nx < s and 0 <= ny < s) or px[nx, ny][3] == 0:
                    px[x, y] = BLACK
                    break
    # The meridian ring of a desk globe: a grey half circle round the ball's right side,
    # a pixel off it, from the top pin to the bottom one.
    if big:
        rr = r + 2.2
        for i in range(200):
            a = -math.pi / 2 + math.pi * i / 199.0
            x = int(round(cx + 0.5 + math.cos(a) * rr))
            y = int(round(cy + 0.5 + math.sin(a) * rr))
            if 0 <= x < s and 0 <= y < s and px[x, y][3] == 0:
                px[x, y] = STAND_LIT if a < 0.2 else STAND
    # The stand: a stem under the ball and a base, black with a lit top edge.
    bottom = int(cy + r + 0.5) + (1 if big else 0)
    stem_x = int(round(cx))
    if big:
        for y in range(bottom, bottom + 2):
            for x in (stem_x - 1, stem_x, stem_x + 1):
                px[x, y] = BLACK
        base_y = bottom + 2
        for x in range(stem_x - 7, stem_x + 8):
            px[x, base_y] = STAND_LIT
            px[x, base_y + 1] = STAND
            px[x, base_y + 2] = BLACK
        px[stem_x - 7, base_y] = BLACK
        px[stem_x + 7, base_y] = BLACK
    else:
        px[stem_x, bottom] = BLACK
        for x in range(stem_x - 3, stem_x + 4):
            px[x, bottom + 1] = STAND_LIT if 0 < x - (stem_x - 3) < 6 else BLACK
            if bottom + 2 < s:
                px[x, bottom + 2] = BLACK
    return img


def main():
    os.makedirs(ICONS, exist_ok=True)
    globe(32).save(os.path.join(ICONS, "atlas.png"))
    globe(16).save(os.path.join(ICONS, "atlas_16.png"))
    print("icon atlas")


if __name__ == "__main__":
    main()
