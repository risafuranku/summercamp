#!/usr/bin/env python3
"""Shop goods: Grok tends to put one row of goods at the bottom of a dark canvas. Crop
each tools/artgen/out/tex_goods_*/raw.png to the band that has goods in it, then process
it as a 128 px wide panel into godot/assets/textury/camp/goods_*.png.

    python tools/artgen/crop_goods.py tex_goods_cans [tex_goods_jars ...]
"""
import os
import subprocess
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))


def content_band(img):
    """Rows whose brightness is clearly above the dark background."""
    g = img.convert("L")
    w, h = g.size
    px = g.load()
    rows = []
    for y in range(h):
        bright = sum(1 for x in range(0, w, 4) if px[x, y] > 70)
        rows.append(bright / (w / 4))
    ys = [y for y, f in enumerate(rows) if f > 0.25]
    if not ys:
        return 0, h
    return max(0, ys[0] - 4), min(h, ys[-1] + 2)


for rid in sys.argv[1:]:
    raw = os.path.join(HERE, "out", rid, "raw.png")
    img = Image.open(raw).convert("RGB")
    top, bottom = content_band(img)
    band = img.crop((0, top, img.size[0], bottom))
    cropped = os.path.join(HERE, "out", rid, "cropped.png")
    band.save(cropped)
    # process.py reads raw.png: hand it the band, keep the original next to it.
    os.replace(raw, os.path.join(HERE, "out", rid, "raw_full.png"))
    band.save(raw)
    dest = "assets/textury/camp/%s.png" % rid[len("tex_"):]
    subprocess.check_call([sys.executable, os.path.join(HERE, "process.py"), rid, "panel", "128", dest])
    print("%s band %d-%d -> %s" % (rid, top, bottom, dest))
