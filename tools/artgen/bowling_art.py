#!/usr/bin/env python3
"""The camp's bowling alley (rows in prompts_kuzelna.tsv) from tools/artgen/out/<id>/raw.png
into the game's files.

    python tools/artgen/bowling_art.py [id ...]     (all when none are given)

- bow_front_a, bow_side_a, bow_side_b, bow_back: the faces of its Build model
  (building_models._bowling), the pavement under the wall cut off, at about 36 pixels a
  metre like the Jednota's, snapped to the game palette;
- the front's painted string of coloured bulbs also as a glow map (bowling_front_glow.png:
  the bulbs' own colours on black), so they light up at night with the neon
  (scripts/bowling/bowling_sign.gd).
A missing render is skipped with a note.
"""
import colorsys
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import process  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
GODOT = os.path.join(HERE, "..", "..", "godot")
CAMP = "assets/textury/camp/"

# (render id, file under godot/, width px, rows kept (0..1 of the height)): the model's
# walls are 10.4 m (front, back) and 8.8 m (each half of a side) wide.
FACES = [
    ("bow_front_a", CAMP + "bowling_front.png", 374, (0.0, 0.955)),
    ("bow_side_a", CAMP + "bowling_side_a.png", 317, (0.0, 0.955)),
    ("bow_side_b", CAMP + "bowling_side_b.png", 317, (0.0, 0.955)),
    ("bow_back", CAMP + "bowling_back.png", 374, (0.0, 0.955)),
]
# The band of the front where the bulbs hang (shares of the face's height, from the top).
BULB_BAND = 0.2


def raw(art_id):
    p = os.path.join(OUT, art_id, "raw.png")
    if not os.path.exists(p):
        print("skip (no render)", art_id)
        return None
    return Image.open(p).convert("RGB")


def save(img, dest):
    path = os.path.join(GODOT, dest)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print(dest, img.size)


def face(art_id, dest, width, rows):
    img = raw(art_id)
    if img is None:
        return None
    w, h = img.size
    img = img.crop((0, int(h * rows[0]), w, int(h * rows[1])))
    small = img.resize((width, round(img.height * width / img.width)), Image.Resampling.BOX)
    out = process.snap(small, False)
    save(out, dest)
    return out


def bulbs_glow(art_id, small, rows, dest):
    """The bulbs, found in the render itself (each a blob of a dozen pixels there, two or
    three on the face): red and yellow ones bright and strong, the teal ones darker but
    greener than the blue stripes, the white ones near white; their share of each face
    pixel decides, in the face's own colour a little brighter; everything else black."""
    img = raw(art_id)
    w, h = img.size
    img = img.crop((0, int(h * rows[0]), w, int(h * rows[1])))
    src = img.load()
    mask = Image.new("L", img.size, 0)
    m = mask.load()
    for y in range(int(img.height * BULB_BAND)):
        for x in range(img.width):
            r, g, b = src[x, y]
            hh, sat, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            warm = v > 0.65 and sat > 0.5
            teal = 0.44 < hh < 0.56 and v > 0.5 and sat > 0.33
            white = v > 0.82 and sat < 0.2
            if warm or teal or white:
                m[x, y] = 255
    share = mask.resize(small.size, Image.Resampling.BOX).load()
    face = small.convert("RGB").load()
    glow = Image.new("RGB", small.size, (0, 0, 0))
    dst = glow.load()
    n = 0
    for y in range(small.height):
        for x in range(small.width):
            if share[x, y] > 22:
                dst[x, y] = tuple(min(255, int(c * 1.35) + 20) for c in face[x, y])
                n += 1
    save(glow, dest)
    print("  bulb pixels", n)


def main():
    want = set(sys.argv[1:])
    for art_id, dest, width, rows in FACES:
        if want and art_id not in want:
            continue
        out = face(art_id, dest, width, rows)
        if out is not None and art_id == "bow_front_a":
            bulbs_glow(art_id, out, rows, CAMP + "bowling_front_glow.png")


if __name__ == "__main__":
    main()
