#!/usr/bin/env python3
"""The plastic card on a business's door (building_models._door_sign): Grok's blank card
(prompts_signs.tsv door_sign_blank, no letters: it cannot spell Czech) lettered here in
red, OTEVŘENO and ZAVŘENO, then brought into the game's look like any sprite.

    python tools/artgen/door_sign.py

-> godot/assets/textury/camp/door_sign_open.png, door_sign_closed.png
"""
import os

from PIL import Image, ImageDraw, ImageFont

import process

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "out", "door_sign_blank", "raw.png")
OUT = os.path.join(process.GODOT, "assets", "textury", "camp")
FONT = "C:/Windows/Fonts/ariblk.ttf"
HEIGHT = 40
WORDS = {"open": "OTEVŘENO", "closed": "ZAVŘENO"}


def plate_box(img):
    """The card itself, without its chain: the rows at least 80% as wide as the widest."""
    a = img.getchannel("A").point(lambda v: 255 if v > 40 else 0)
    rows = []
    for y in range(img.height):
        box = a.crop((0, y, img.width, y + 1)).getbbox()
        rows.append((box[2] - box[0]) if box else 0)
    widest = max(rows)
    ys = [y for y, w in enumerate(rows) if w >= widest * 0.8]
    xbox = a.crop((0, ys[0], img.width, ys[-1] + 1)).getbbox()
    return xbox[0], ys[0], xbox[2], ys[-1]


def main():
    base = process.key_out(Image.open(RAW))
    x0, y0, x1, y1 = plate_box(base)
    for name, word in WORDS.items():
        img = base.copy()
        d = ImageDraw.Draw(img)
        size = 10
        while True:
            f = ImageFont.truetype(FONT, size + 2)
            b = d.textbbox((0, 0), word, font=f)
            if b[2] - b[0] > (x1 - x0) * 0.74 or b[3] - b[1] > (y1 - y0) * 0.42:
                break
            size += 2
        f = ImageFont.truetype(FONT, size)
        b = d.textbbox((0, 0), word, font=f)
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        d.text((cx - (b[0] + b[2]) / 2, cy - (b[1] + b[3]) / 2), word, font=f, fill=(176, 28, 22, 255))
        tmp = os.path.join(HERE, "out", "door_sign_blank", name + ".png")
        img.save(tmp)
        out = process.sprite(tmp, HEIGHT)
        out.save(os.path.join(OUT, "door_sign_%s.png" % name))
        print(name, out.size)


if __name__ == "__main__":
    main()
