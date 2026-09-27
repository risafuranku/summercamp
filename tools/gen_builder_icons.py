#!/usr/bin/env python3
"""Procedural 32x32 pixel-art builder icons (upscaled x2) for buildings that had no art.

Run from repo root: python3 tools/gen_builder_icons.py
Writes godot/assets/textury/builder/{bonfire,sports_field,lake_slide,caravan}.png
"""
import os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "godot", "assets", "textury", "builder")


def canvas(bg):
    im = Image.new("RGBA", (32, 32), bg)
    return im, ImageDraw.Draw(im)


def frame(d):
    d.rectangle([0, 0, 31, 31], outline=(24, 18, 12, 255))


def bonfire():
    im, d = canvas((40, 30, 26, 255))
    d.rectangle([0, 22, 31, 31], fill=(44, 60, 30, 255))
    # stones
    for x in range(5, 27, 4):
        d.rectangle([x, 24, x + 2, 26], fill=(110, 104, 96, 255))
    # logs
    d.line([7, 25, 25, 19], fill=(96, 60, 30, 255), width=3)
    d.line([7, 19, 25, 25], fill=(120, 76, 38, 255), width=3)
    # flames
    d.polygon([(10, 21), (16, 5), (22, 21)], fill=(226, 92, 24, 255))
    d.polygon([(12, 21), (16, 10), (20, 21)], fill=(250, 170, 40, 255))
    d.polygon([(14, 21), (16, 14), (18, 21)], fill=(255, 236, 140, 255))
    frame(d)
    return im


def sports_field():
    im, d = canvas((66, 118, 52, 255))
    for y in range(0, 32, 4):
        d.rectangle([0, y, 31, y + 1], fill=(74, 128, 58, 255))
    d.rectangle([3, 6, 28, 25], outline=(236, 236, 226, 255))
    d.line([16, 6, 16, 25], fill=(236, 236, 226, 255))
    d.ellipse([12, 12, 20, 19], outline=(236, 236, 226, 255))
    d.rectangle([0, 12, 3, 19], outline=(236, 236, 226, 255))
    d.rectangle([28, 12, 31, 19], outline=(236, 236, 226, 255))
    d.ellipse([20, 20, 23, 23], fill=(250, 250, 250, 255), outline=(20, 20, 20, 255))
    frame(d)
    return im


def lake_slide():
    im, d = canvas((140, 176, 214, 255))
    d.rectangle([0, 20, 31, 31], fill=(44, 102, 128, 255))
    for x in range(0, 32, 6):
        d.line([x, 23, x + 3, 23], fill=(120, 180, 196, 255))
    # tower
    d.rectangle([4, 6, 6, 22], fill=(90, 70, 50, 255))
    d.rectangle([10, 6, 12, 22], fill=(90, 70, 50, 255))
    d.rectangle([3, 5, 13, 7], fill=(120, 90, 60, 255))
    # slide curve
    pts = [(12, 7), (17, 11), (21, 15), (25, 19), (29, 21)]
    d.line(pts, fill=(232, 138, 44, 255), width=3)
    d.line([(12, 6), (17, 10), (21, 14), (25, 18), (29, 20)], fill=(255, 190, 90, 255), width=1)
    frame(d)
    return im


def caravan():
    im, d = canvas((150, 180, 206, 255))
    d.rectangle([0, 24, 31, 31], fill=(70, 96, 50, 255))
    d.rounded_rectangle([3, 9, 27, 23], radius=3, fill=(222, 208, 176, 255), outline=(60, 50, 40, 255))
    d.rectangle([3, 15, 27, 16], fill=(180, 74, 52, 255))
    d.rectangle([6, 11, 12, 14], fill=(90, 130, 160, 255), outline=(60, 50, 40, 255))
    d.rectangle([19, 11, 23, 22], fill=(170, 150, 120, 255), outline=(60, 50, 40, 255))
    d.ellipse([8, 20, 14, 26], fill=(30, 30, 30, 255))
    d.ellipse([10, 22, 12, 24], fill=(120, 120, 120, 255))
    d.line([27, 21, 31, 23], fill=(60, 50, 40, 255), width=2)
    frame(d)
    return im


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in [("bonfire", bonfire), ("sports_field", sports_field), ("lake_slide", lake_slide), ("caravan", caravan)]:
        fn().resize((64, 64), Image.NEAREST).save(os.path.join(OUT, name + ".png"))
    print("icons written to", OUT)


if __name__ == "__main__":
    main()


def mood_markers():
    """16x16 over-head mood markers for guest sprites (upscaled x2)."""
    out = os.path.join(os.path.dirname(__file__), "..", "godot", "assets", "textury", "npc")
    # angry: red exclamation on dark plate
    im, d = Image.new("RGBA", (16, 16), (0, 0, 0, 0)), None
    d = ImageDraw.Draw(im)
    d.polygon([(8, 0), (15, 14), (1, 14)], fill=(30, 8, 6, 255))
    d.polygon([(8, 2), (13, 13), (3, 13)], fill=(214, 40, 28, 255))
    d.rectangle([7, 5, 8, 9], fill=(255, 236, 200, 255))
    d.rectangle([7, 11, 8, 12], fill=(255, 236, 200, 255))
    im.resize((32, 32), Image.NEAREST).save(os.path.join(out, "mood_angry.png"))
    # delighted: green heart
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    heart = [(3, 2), (6, 2), (8, 4), (10, 2), (13, 2), (15, 5), (15, 7), (8, 14), (1, 7), (1, 5)]
    d.polygon(heart, fill=(20, 40, 12, 255))
    inner = [(4, 3), (6, 3), (8, 6), (10, 3), (12, 3), (14, 5), (14, 7), (8, 12), (2, 7), (2, 5)]
    d.polygon(inner, fill=(110, 214, 70, 255))
    d.rectangle([4, 4, 5, 5], fill=(220, 255, 200, 255))
    im.resize((32, 32), Image.NEAREST).save(os.path.join(out, "mood_happy.png"))
    # need: yellow question mark bubble
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([1, 1, 14, 13], fill=(40, 30, 6, 255))
    d.ellipse([2, 2, 13, 12], fill=(236, 196, 60, 255))
    d.polygon([(4, 11), (3, 15), (7, 12)], fill=(236, 196, 60, 255))
    for x, y in [(6, 4), (7, 4), (8, 4), (9, 5), (9, 6), (8, 7), (7, 8), (7, 10)]:
        d.point((x, y), fill=(40, 20, 4, 255))
    im.resize((32, 32), Image.NEAREST).save(os.path.join(out, "mood_need.png"))


if __name__ == "__main__":
    mood_markers()
