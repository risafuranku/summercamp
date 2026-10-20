#!/usr/bin/env python3
"""Smoke frames from a Grok render on black: soft alpha from brightness, not keyed edges.

    python tools/artgen/smoke_from_black.py <id> <scale> <dest dir relative to godot/> <prefix>

The render has the frames in a row on pure black. Each frame is cut where the black
gaps between them are, its alpha is how bright it is (smoke is light on black, so the
thin edges come out thin, not as hard dotted pixels), its colour a pale grey that keeps
the render's shading, and it is box-downsampled by <scale> (the same for all frames, so
the puff grows as drawn). Written as <prefix>_0.png .. <prefix>_N.png.
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import process  # noqa: E402


def main():
    art_id, scale, dest, prefix = sys.argv[1], float(sys.argv[2]), sys.argv[3], sys.argv[4]
    img = Image.open(os.path.join(process.HERE, "out", art_id, "raw.png")).convert("RGB")
    w, h = img.size
    lum = img.convert("L")
    px = lum.load()
    # Columns with any smoke in them; frames are the runs between empty columns.
    cols = [max(px[x, y] for y in range(0, h, 2)) > 18 for x in range(w)]
    runs = []
    x = 0
    while x < w:
        if cols[x]:
            x0 = x
            while x < w and (cols[x] or any(cols[x:min(w, x + 6)])):
                x += 1
            if x - x0 > 8:
                runs.append((x0, x))
        x += 1
    out_dir = os.path.join(process.GODOT, dest)
    os.makedirs(out_dir, exist_ok=True)
    for i, (x0, x1) in enumerate(runs):
        crop = img.crop((x0, 0, x1, h))
        lc = crop.convert("L")
        bb = lc.point(lambda v: 255 if v > 18 else 0).getbbox()
        crop = crop.crop(bb)
        lc = lc.crop(bb)
        # Alpha from brightness, a little lifted so the body reads; colour stays pale.
        a = lc.point(lambda v: 0 if v < 14 else min(255, int((v - 14) * 1.35)))
        rgb = Image.merge("RGB", [lc.point(lambda v: min(255, 150 + v // 2))] * 3)
        rgba = rgb.copy()
        rgba.putalpha(a)
        nw = max(1, round(rgba.width * scale))
        nh = max(1, round(rgba.height * scale))
        small = rgba.resize((nw, nh), Image.Resampling.BOX)
        small.save(os.path.join(out_dir, "%s_%d.png" % (prefix, i)))
        print("%s_%d %s" % (prefix, i, small.size))


if __name__ == "__main__":
    main()
