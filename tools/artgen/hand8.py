#!/usr/bin/env python3
"""The two hands opening a bottle (hand8_beer_*), three frames on one canvas.

    python tools/artgen/hand8.py

Grok's renders (prompts_hands8.tsv) keyed and cut to the box they all fit in, so that the arms
stand still from frame to frame and only the lighter, the cap and the foam move; scaled to the
hands' pixel, snapped to the palette.
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import process  # noqa: E402

FRAMES = {"hand8_beer_two": "hand8_beer_opening", "hand8_beer_lever": "hand8_beer_lever", "hand8_beer_pop": "hand8_beer_pop"}
# The arms and the bottle at the pixel of the hand that holds the bottle shut.
HEIGHT_OF_OPENING = 88
CAP_BOX = (672, 120, 790, 212)
DST = os.path.join(process.GODOT, "assets", "textury", "hands_lo")


def main():
    keyed = {}
    boxes = {}
    for art in FRAMES:
        src = Image.open(os.path.join(process.HERE, "out", art, "raw.png")).convert("RGBA")
        img = process.key_out(src)
        if art == "hand8_beer_pop":
            # The cap flies by itself on the screen (pockets._cap_off_screen).
            img.paste((0, 0, 0, 0), CAP_BOX)
        keyed[art] = img
        boxes[art] = img.getbbox()
    k = HEIGHT_OF_OPENING / float(boxes["hand8_beer_two"][3] - boxes["hand8_beer_two"][1])
    left = min(b[0] for b in boxes.values())
    top = min(b[1] for b in boxes.values())
    right = max(b[2] for b in boxes.values())
    bottom = max(b[3] for b in boxes.values())
    size = (round((right - left) * k), round((bottom - top) * k))
    for art, name in FRAMES.items():
        crop = keyed[art].crop((left, top, right, bottom))
        r, g, b, a = crop.split()
        pre = Image.merge("RGBA", [Image.composite(ch, Image.new("L", crop.size, 0), a) for ch in (r, g, b)] + [a])
        small = pre.resize(size, Image.Resampling.BOX)
        px = small.load()
        for y in range(size[1]):
            for x in range(size[0]):
                pr, pg, pb, pa = px[x, y]
                if pa > 0:
                    px[x, y] = (min(255, pr * 255 // pa), min(255, pg * 255 // pa), min(255, pb * 255 // pa), pa)
        out = process.snap(small, True)
        out.save(os.path.join(DST, name + ".png"))
        print(name, out.size)


if __name__ == "__main__":
    main()
