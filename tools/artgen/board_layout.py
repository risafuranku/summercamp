#!/usr/bin/env python3
"""Lay the office's cork noticeboard out again from its own pieces (playtest 4. 11.: "the
timetable overlaps what is under it, rework the board").

    python tools/artgen/board_layout.py

Takes tools/artgen/board_original.png (the Grok picture as it was), fills
the cork where every paper was with the board's own cork, and puts the papers back a little
smaller on a plan that has room for all of them: the three notes and the lake keeper's tag
along the top; the photo, the bus note, the printed timetable, the maze sheet over the camp's
card and the key along the bottom. Nothing lies on anything else. Writes board.png; the rects
are in scripts/closeup/board_closeup.gd (NOTES, TIMETABLE_RECT, MAZE_RECT, KEY_RECT).
"""
import os
import random

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
DIR = os.path.join(HERE, "..", "..", "godot", "assets", "textury", "closeup")
SRC = os.path.join(HERE, "board_original.png")
OUT = os.path.join(DIR, "board.png")

# id: (source rect x, y, w, h with its pin and shadow), (where it goes x, y, w, h)
ITEMS = {
    "phones": ((22, 13, 96, 90), (14, 12, 86, 81)),
    "novotny": ((128, 18, 75, 82), (106, 13, 67, 74)),
    "private": ((220, 17, 76, 80), (181, 13, 68, 72)),
    "hruby": ((186, 86, 40, 118), (262, 10, 33, 96)),
    "photo": ((20, 106, 86, 92), (14, 110, 73, 78)),
    "bus": ((107, 122, 76, 88), (96, 113, 64, 74)),
    "card": ((251, 154, 54, 62), (229, 165, 45, 52)),
    "key": ((231, 102, 22, 96), (282, 118, 19, 83)),
}
# Bare cork to take patches from (x, y, w, h).
CORK = [(20, 204, 280, 20), (118, 20, 8, 80), (206, 20, 12, 80), (106, 100, 80, 20)]
PATCH = 6


def main():
    if not os.path.exists(SRC):
        Image.open(OUT).convert("RGB").save(SRC)
    src = Image.open(SRC).convert("RGB")
    rng = random.Random(4)
    out = src.copy()
    # Bare cork all over the inside of the frame.
    patches = []
    for x, y, w, h in CORK:
        for py in range(y, y + h - PATCH + 1, 2):
            for px in range(x, x + w - PATCH + 1, 2):
                p = src.crop((px, py, px + PATCH, py + PATCH))
                # Cork only: no paper's edge, no pin, no shadow in it.
                lum = [0.3 * r + 0.59 * g + 0.11 * b for r, g, b in p.get_flattened_data()] if hasattr(p, "get_flattened_data") else [0.3 * r + 0.59 * g + 0.11 * b for r, g, b in p.getdata()]
                if 62.0 < sum(lum) / len(lum) < 112.0 and max(lum) < 150.0 and min(lum) > 26.0:
                    patches.append(p)
    for y in range(11, 230, PATCH):
        for x in range(11, 310, PATCH):
            p = rng.choice(patches)
            box = (min(PATCH, 310 - x), min(PATCH, 230 - y))
            out.paste(p.crop((0, 0, box[0], box[1])), (x, y))
    # Each paper in its place, its own edge of cork going into the bare cork.
    for name, (s, d) in ITEMS.items():
        piece = src.crop((s[0], s[1], s[0] + s[2], s[1] + s[3])).resize((d[2], d[3]), Image.Resampling.BOX)
        out.paste(piece, (d[0], d[1]))
    # (A corner of the yellow note came in with the tag's string.)
    for y in range(10, 24, PATCH):
        for x in range(262, 272, PATCH):
            out.paste(rng.choice(patches), (x, y))
    # The two sheets the close-up draws itself (they show on the wall as well).
    draw = ImageDraw.Draw(out)
    t = (172, 106, 46, 66)
    draw.rectangle((t[0] + 2, t[1] + 3, t[0] + t[2] + 1, t[1] + t[3] + 2), fill=(62, 44, 22))
    draw.rectangle((t[0], t[1], t[0] + t[2] - 1, t[1] + t[3] - 1), fill=(232, 228, 214))
    draw.rectangle((t[0] + 3, t[1] + 4, t[0] + 12, t[1] + 8), fill=(30, 30, 44))
    for i in range(11):
        draw.line((t[0] + 3, t[1] + 13 + i * 4, t[0] + 3 + (26 + (i * 7) % 14), t[1] + 13 + i * 4), fill=(96, 96, 110))
    m = (229, 96, 42, 62)
    draw.rectangle((m[0] + 2, m[1] + 3, m[0] + m[2] + 1, m[1] + m[3] + 2), fill=(62, 44, 22))
    draw.rectangle((m[0], m[1], m[0] + m[2] - 1, m[1] + m[3] - 1), fill=(226, 224, 208))
    for i in range(0, m[3], 5):
        draw.line((m[0] + 1, m[1] + i, m[0] + m[2] - 2, m[1] + i), fill=(186, 198, 210))
    for i in range(0, m[2], 5):
        draw.line((m[0] + i, m[1] + 1, m[0] + i, m[1] + m[3] - 2), fill=(186, 198, 210))
    # The grain of the Grok paper on the two sheets.
    for box in (t, m):
        for y in range(box[1], box[1] + box[3]):
            for x in range(box[0], box[0] + box[2]):
                r, g, b = out.getpixel((x, y))
                k = rng.randint(-14, 8)
                out.putpixel((x, y), (max(0, r + k), max(0, g + k), max(0, b + k)))
    out.save(OUT)
    print("board.png laid out, %d cork patches" % len(patches))


if __name__ == "__main__":
    main()
