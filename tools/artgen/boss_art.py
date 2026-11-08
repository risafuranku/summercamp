#!/usr/bin/env python3
"""Boss 98's two pictures out of Grok's raw ones (tools/artgen/prompts_boss.tsv):
the leather of the program's frame, tiling; the armchair as a 32 and a 16 pixel icon."""
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
GODOT = os.path.join(HERE, "..", "..", "godot", "assets", "textury", "os98")


def leather():
    im = Image.open(os.path.join(OUT, "boss_leather", "raw.png")).convert("RGB").resize((256, 256), Image.LANCZOS)
    # Tiling: the edges faded into a copy moved by half a tile.
    moved = Image.new("RGB", im.size)
    moved.paste(im, (-128, -128))
    moved.paste(im, (128, -128))
    moved.paste(im, (-128, 128))
    moved.paste(im, (128, 128))
    mask = Image.new("L", im.size, 255)
    px = mask.load()
    fade = 48
    for y in range(256):
        for x in range(256):
            d = min(x, y, 255 - x, 255 - y)
            px[x, y] = min(255, int(255 * d / fade))
    out = Image.composite(im, moved, mask)
    # The grain as a 256-colour program's: few colours, no smooth ramps.
    out = out.quantize(colors=32, dither=Image.FLOYDSTEINBERG).convert("RGB")
    out.save(os.path.join(GODOT, "boss_leather.png"))


def icon():
    im = Image.open(os.path.join(OUT, "boss_icon", "raw.png")).convert("RGB")
    # The white paper round it goes.
    key = (254, 0, 254)
    w, h = im.size
    for corner in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        ImageDraw.floodfill(im, corner, key, thresh=40)
    rgba = Image.new("RGBA", im.size, (0, 0, 0, 0))
    src = im.load()
    dst = rgba.load()
    for y in range(h):
        for x in range(w):
            # (Also the white shut in between the chair's legs.)
            if src[x, y] != key and min(src[x, y]) < 215:
                dst[x, y] = src[x, y] + (255,)
    box = rgba.getbbox()
    art = rgba.crop(box)
    for size, name in [(32, "boss_app.png"), (16, "boss_app_16.png")]:
        room = size - (1 if size > 16 else 0)
        k = min(room / art.size[0], room / art.size[1])
        small = art.resize((max(1, round(art.size[0] * k)), max(1, round(art.size[1] * k))), Image.NEAREST if size > 16 else Image.BOX)
        # Hard edges, as the system's icons have.
        a = small.getchannel("A").point(lambda v: 255 if v > 110 else 0)
        small.putalpha(a)
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        canvas.paste(small, ((size - small.size[0]) // 2, (size - small.size[1]) // 2), small)
        canvas.save(os.path.join(GODOT, "icons", name))


if __name__ == "__main__":
    leather()
    icon()
    print("ok")
