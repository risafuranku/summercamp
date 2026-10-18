#!/usr/bin/env python3
"""After office_art.py: clean the counter games' parts (godot/assets/textury/closeup/parts/).

    python tools/artgen/parts_fix.py

- The magenta the renders stood on leaves a red or pink rim on the edge (the slices,
  the ticket) and shows pink through glass: rim pixels of that hue go, and on the glasses
  and mugs every pink pixel goes (you see through them).
- The pencilled box's lines are thinner than a pixel at its size: the render is keyed,
  its lines thickened, then scaled down.
"""
import colorsys
import os

from PIL import Image, ImageFilter

import process

HERE = os.path.dirname(os.path.abspath(__file__))
PARTS = os.path.join(HERE, "..", "..", "godot", "assets", "textury", "closeup", "parts")
SEE_THROUGH = ("glass_", "mug_", "tap_glass")
KEEP_RED = ("stamp_frame", "price_tag", "bottle_kofola", "cheese_burnt_keep")


def pinkish(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
    h *= 360.0
    return s > 0.28 and v > 0.25 and (h >= 285.0 or h <= 8.0) and r > g + 40


def clean(path, see_through):
    im = Image.open(path).convert("RGBA")
    px = im.load()
    w, h = im.size
    for _ in range(2):
        drop = []
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a == 0 or not pinkish(r, g, b):
                    continue
                edge = see_through or any(
                    not (0 <= x + dx < w and 0 <= y + dy < h) or px[x + dx, y + dy][3] == 0
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if edge:
                    drop.append((x, y))
        for x, y in drop:
            px[x, y] = (0, 0, 0, 0)
    im.save(path)
    return len(drop)


def pencil_box():
    raw = os.path.join(HERE, "out", "cu_pencil_box", "raw.png")
    if not os.path.exists(raw):
        return
    img = process.key_out(Image.open(raw))
    a = img.getchannel("A").filter(ImageFilter.MaxFilter(9))
    grey = Image.new("RGBA", img.size, (70, 66, 62, 255))
    grey.putalpha(a)
    bbox = a.getbbox()
    grey = grey.crop(bbox)
    small = grey.resize((round(grey.width * 40 / grey.height), 40), Image.Resampling.BOX)
    small.putalpha(small.getchannel("A").point(lambda v: 255 if v >= 70 else 0))
    small.save(os.path.join(PARTS, "pencil_box.png"))
    print("pencil_box.png", small.size)


def main():
    for f in sorted(os.listdir(PARTS)):
        if not f.endswith(".png") or f.startswith(KEEP_RED):
            continue
        n = clean(os.path.join(PARTS, f), f.startswith(SEE_THROUGH))
        if n:
            print(f, "-%d px" % n)
    pencil_box()
    tall_glass()


def tall_glass():
    """The empty kofola glass came out all reflection of the magenta (nothing left once
    keyed): the tap's empty glass stands in, at the kofola glass's height."""
    src = os.path.join(PARTS, "tap_glass.png")
    if not os.path.exists(src):
        return
    g = Image.open(src).convert("RGBA")
    g = g.resize((round(g.width * 76 / g.height), 76), Image.Resampling.BOX)
    g.putalpha(g.getchannel("A").point(lambda a: 255 if a >= 110 else 0))
    g.save(os.path.join(PARTS, "glass_tall.png"))


if __name__ == "__main__":
    main()
