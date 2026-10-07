#!/usr/bin/env python3
"""Bring a Grok Imagine render into the game's Build-engine look.

    python tools/artgen/process.py <id> sprite <height_px> <dest relative to godot/>
    python tools/artgen/process.py <id> texture <size_px> <dest relative to godot/>

sprite:  keys out the flat magenta background (and its anti-aliased fringe), crops
         to the figure, scales to <height_px> tall with a box filter (so 1 output
         pixel = the average of a block, like a hand-downsampled sprite), hard alpha,
         then snaps every opaque pixel to the game's 256-colour palette.
texture: centre-crops square, scales to <size_px>, snaps to the palette (opaque).

Source renders stay in tools/artgen/out/<id>/raw.png for regeneration.
"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.join(HERE, "..", "..", "godot")
PALETTE = os.path.join(GODOT, "assets", "textury", "palette", "build_palette.png")


def palette_image():
    pal = Image.open(PALETTE).convert("RGB")
    colours = list(pal.getdata())[:256]
    flat = []
    for c in colours:
        flat.extend(c)
    flat.extend([0, 0, 0] * (256 - len(colours)))
    img = Image.new("P", (1, 1))
    img.putpalette(flat)
    return img


def is_key(r, g, b):
    # Magenta and its anti-aliased blends: strong red + blue, weak green.
    return r > 150 and b > 150 and g < 110 and abs(r - b) < 90


def key_out(img):
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if is_key(r, g, b):
                px[x, y] = (0, 0, 0, 0)
            elif r > 120 and b > 120 and g < 140 and abs(r - b) < 70:
                # fringe: magenta bleeding into the edge -> pull toward neutral dark
                px[x, y] = (int(g * 0.9), g, int(g * 0.9), a)
    return img


def snap(img, keep_alpha):
    pal = palette_image()
    rgb = img.convert("RGB").quantize(palette=pal, dither=Image.Dither.NONE).convert("RGB")
    if not keep_alpha:
        return rgb
    out = rgb.convert("RGBA")
    alpha = img.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
    out.putalpha(alpha)
    return out


def sprite(src, height):
    img = key_out(Image.open(src))
    bbox = img.getchannel("A").point(lambda a: 255 if a > 40 else 0).getbbox()
    img = img.crop(bbox)
    w = max(1, round(img.width * height / img.height))
    # Premultiply so transparent pixels do not bleed colour into the edge.
    r, g, b, a = img.split()
    pre = Image.merge("RGBA", [Image.composite(ch, Image.new("L", img.size, 0), a) for ch in (r, g, b)] + [a])
    small = pre.resize((w, height), Image.Resampling.BOX)
    sr, sg, sb, sa = small.split()
    def unpremul(ch):
        return Image.merge("L", [ch]).point(lambda v: v)
    px = small.load()
    for y in range(small.height):
        for x in range(small.width):
            pr, pg, pb, pa = px[x, y]
            if pa > 0:
                k = 255.0 / pa
                px[x, y] = (min(255, int(pr * k)), min(255, int(pg * k)), min(255, int(pb * k)), pa)
    return snap(small, True)


def texture(src, size):
    img = Image.open(src).convert("RGB")
    s = min(img.size)
    left = (img.width - s) // 2
    top = (img.height - s) // 2
    img = img.crop((left, top, left + s, top + s)).resize((size, size), Image.Resampling.BOX)
    return snap(img, False)


def main():
    if len(sys.argv) < 5:
        print(__doc__)
        sys.exit(1)
    art_id, kind, size, dest = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
    src = os.path.join(HERE, "out", art_id, "raw.png")
    out = sprite(src, size) if kind == "sprite" else texture(src, size)
    path = os.path.join(GODOT, dest)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out.save(path)
    print("%s -> %s %s" % (art_id, dest, out.size))


if __name__ == "__main__":
    main()
