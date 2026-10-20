#!/usr/bin/env python3
"""Pixel art drawn in code: the green stink over filthy toilet and shower blocks, and the
plates over guests' heads that say what they need.

Run from the repo root: python tools/gen_stink_sprites.py
Writes
  godot/assets/textury/npc/stink_fumes.png   6 frames of 32x64 side by side (rising fumes)
  godot/assets/textury/npc/need_<need>.png   16x16 plates upscaled x2 (bladder, hunger,
                                             hygiene, fun, energy, safety, any)

The need plates replaced the yellow "?" bubble (playtest 20. 10.: at night the round yellow
bubbles over the guests read as the eyes of the things in the dark). A square blue enamel
plate with a white pictogram, like the camp's own signs, says which need it is too.
"""
import math
import os

from PIL import Image

NPC = os.path.join(os.path.dirname(__file__), "..", "godot", "assets", "textury", "npc")

# ── the stink ────────────────────────────────────────────────────────────────

FRAMES = 6
FW, FH = 32, 64
CORE = (168, 222, 74)
EDGE = (62, 118, 28)
PUFF = (126, 186, 52)


def _put(px, x, y, col, a):
    if 0 <= x < FW and 0 <= y < FH:
        old = px[x, y]
        if old[3] >= a and old[:3] == CORE:
            return
        px[x, y] = col + (a,)


def fumes_frame(f):
    im = Image.new("RGBA", (FW, FH), (0, 0, 0, 0))
    px = im.load()
    phase = f / FRAMES * math.tau
    # Three strands: a wavy line each, the wave running up, wider towards the top.
    # Side by side and nearly in step, like the stink lines of a comic.
    for i, (x0, ph0, top) in enumerate([(8, 0.0, 10), (16, 0.7, 4), (24, 1.4, 12)]):
        lam = 24.0
        for y in range(FH - 4, top, -1):
            up = (FH - 4 - y) / (FH - 10)
            amp = 0.8 + 2.0 * up
            x = int(round(x0 + amp * math.sin(y / lam * math.tau + phase + ph0)))
            # Thinner and see-through at both ends: the fume comes out of nothing and goes.
            a = 255 if 0.12 < up < 0.78 else 150
            if up > 0.92 and (y + f) % 2:
                continue
            _put(px, x - 1, y, EDGE, a)
            _put(px, x + 2, y, EDGE, a)
            _put(px, x, y, CORE, a)
            _put(px, x + 1, y, CORE, a)
    # Little puffs drifting up between the strands.
    for k, (bx, by) in enumerate([(12, 50), (20, 36), (11, 22), (21, 12)]):
        y = (by - f * 3 - k * 2) % (FH - 8) + 4
        x = bx + int(round(2 * math.sin((y + k * 7) / 9.0)))
        for dx, dy in [(0, 0), (1, 0), (0, 1), (1, 1)]:
            _put(px, x + dx, y + dy, PUFF, 170)
    return im


def stink():
    sheet = Image.new("RGBA", (FW * FRAMES, FH), (0, 0, 0, 0))
    for f in range(FRAMES):
        sheet.paste(fumes_frame(f), (f * FW, 0))
    sheet.save(os.path.join(NPC, "stink_fumes.png"))


# ── the need plates ──────────────────────────────────────────────────────────

RIM = (14, 20, 40, 255)
BLUE = (38, 78, 168, 255)
LIGHT = (92, 132, 212, 255)
SHADE = (24, 50, 112, 255)
INK = (246, 244, 232, 255)

ICONS = {
    "bladder": [
        "X...X.XXX",
        "X...X.X..",
        "X.X.X.X..",
        "X.X.X.X..",
        ".X.X..XXX",
    ],
    "hunger": [
        "X.X.X...X",
        "X.X.X..XX",
        "X.X.X..XX",
        "XXXXX..XX",
        ".XXX...XX",
        "..X.....X",
        "..X.....X",
        "..X.....X",
        "..X.....X",
    ],
    "hygiene": [
        "XXXX.....",
        "...X.....",
        "..XXX....",
        ".XXXXX...",
        ".........",
        ".X.X.X...",
        ".........",
        "X.X.X.X..",
        ".........",
        ".X.X.X...",
    ],
    "fun": [
        "..XXXXXX",
        "..XXXXXX",
        "..X....X",
        "..X....X",
        "..X....X",
        "..X....X",
        "XXX..XXX",
        "XXX..XXX",
        "XX...XX.",
    ],
    "energy": [
        "XXXX.....",
        "...X.....",
        "..X......",
        ".X..XXXX.",
        "XXXX...X.",
        ".......X.",
        "......X..",
        ".....X...",
        "....XXXX.",
    ],
    "safety": [
        "...XXX...",
        "..X...X..",
        ".X.....X.",
        ".X.....X.",
        ".X.....X.",
        "..X...X..",
        "...XXX...",
        "...XXX...",
        "....X....",
    ],
    "any": [
        ".XXX.",
        "X...X",
        "....X",
        "...X.",
        "..X..",
        "..X..",
        ".....",
        "..X..",
    ],
}


def plate(rows):
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = im.load()
    for y in range(1, 15):
        for x in range(1, 15):
            edge = x in (1, 14) or y in (1, 14)
            px[x, y] = RIM if edge else BLUE
    # A bevel like the HUD's plates: light along the top and left, dark along the others.
    for i in range(2, 14):
        px[i, 2] = LIGHT
        px[2, i] = LIGHT
        px[i, 13] = SHADE
        px[13, i] = SHADE
    h = len(rows)
    w = len(rows[0])
    ox = 3 + (10 - w + 1) // 2
    oy = 3 + (10 - h + 1) // 2
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            if c == "X":
                px[ox + x, oy + y] = INK
    return im


def plates():
    for name, rows in ICONS.items():
        plate(rows).resize((32, 32), Image.NEAREST).save(os.path.join(NPC, "need_%s.png" % name))


if __name__ == "__main__":
    stink()
    plates()
    print("written to", os.path.normpath(NPC))
