#!/usr/bin/env python3
"""The camp's bowling alley (rows in prompts_kuzelna.tsv) from tools/artgen/out/<id>/raw.png
into the game's files.

    python tools/artgen/bowling_art.py [id ...]     (all when none are given)

- bow_front_a, bow_side_a, bow_side_b, bow_back: the faces of its Build model
  (building_models._bowling), the pavement under the wall cut off, at about 36 pixels a
  metre like the Jednota's, snapped to the game palette;
- the front's painted string of coloured bulbs also as a glow map (bowling_front_glow.png:
  the bulbs' own colours on black), so they light up at night with the neon
  (scripts/bowling/bowling_sign.gd);
- bows_desk, bows_bufet, bows_pit, bows_cellar, bows_jams, bows_brnoswick: the stations'
  sprite sheets cut into their things
  (assets/textury/bowling/: the rental shoes in two colours, the shoe spray standing and
  lying; the snack bar's hot dog, pickled sausages, crisps, wafer, cola and beer; the pit's
  pin, ball, bell and gloves);
- tex_bowl_stripes: the band painted round the hall's walls (camp/bowl_stripes.png, a
  repeat of 1.7 m by 0.48 m at the room's pixel, its ends blended so it runs on);
  tex_bowl_shoeshelf: the pigeonholes behind the counter (camp/bowl_shoeshelf.png);
  tex_bowl_screen: the score monitors' glass (camp/bowl_screen.png).
  The chalkboard (tex_bowl_slate), the cellar's walls and floor, the machines' panels
  (tex_bowl_cellar_wall, tex_bowl_cellar_floor, tex_bowl_machine, tex_bowl_brnoswick) are
  tileables, each:
  python tools/artgen/ground_tex.py tex_bowl_slate assets/textury/camp/bowl_slate.png 128 --own
A missing render is skipped with a note.
"""
import colorsys
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import process  # noqa: E402
import pub_art  # noqa: E402
import split_sheet  # noqa: E402

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
B = "assets/textury/bowling/"
# The stations' sheets: (render id, [(file under godot/, longest side px), ...] left to right).
SHEETS = [
    ("bows_desk", [(B + "shoes_red.png", 56), (B + "shoes_blue.png", 56), (B + "spray.png", 40), (B + "spray_lying.png", 40)]),
    ("bows_bufet", [(B + "hotdog.png", 44), (B + "pickled.png", 40), (B + "crisps.png", 40), (B + "wafer.png", 40),
                    (B + "kofola.png", 36), (B + "beer.png", 40)]),
    ("bows_pit", [(B + "pin.png", 40), (B + "ball.png", 30), (B + "bell.png", 32), (B + "gloves.png", 44)]),
    # The cellar's machine (cellar_station.gd): its gears turn, the crank and the lever move.
    ("bows_cellar", [(B + "gear_big.png", 160), (B + "gear_small.png", 72), (B + "sprocket.png", 64), (B + "crank.png", 80),
                     (B + "lever.png", 90), (B + "motor.png", 110)]),
    # What gets caught in its gears.
    ("bows_jams", [(B + "jam_pin.png", 48), (B + "jam_shoe.png", 48), (B + "jam_rag.png", 48), (B + "jam_hair.png", 56),
                   (B + "jam_rat.png", 52)]),
    # The Brnoswick's parts in place of the Stavomat's.
    ("bows_brnoswick", [(B + "brn_gear_big.png", 160), (B + "brn_gear_small.png", 72), (B + "brn_motor.png", 110),
                        (B + "brn_lever.png", 90)]),
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


def sheet(art_id, items, gap=5):
    """jednota_art.sheet: the things cut apart on the key and shrunk, each to its own size."""
    src = os.path.join(OUT, art_id, "raw.png")
    if not os.path.exists(src):
        print("skip (no render)", art_id)
        return
    img = process.key_out(pub_art.despilled(src))
    boxes, labels, w = split_sheet.items(img, gap)
    parts = [split_sheet.own(img, b, labels[b], w) for b in boxes]
    if len(parts) != len(items):
        print("WARN", art_id, "found", len(parts), "items for", len(items))
    for (dest, longest), part in zip(items, parts):
        small = split_sheet.shrink(part, longest / float(max(part.width, part.height)))
        save(small, dest)


def stripes(art_id, dest):
    """All three bands kept, the room's pixel, the left and right ends blended into each
    other (a copy moved half its width shows at the ends) so the band runs on."""
    img = raw(art_id)
    if img is None:
        return
    w, h = img.size
    img = img.crop((0, int(h * 0.1), w, int(h * 0.92)))
    a = np.asarray(img.resize((320, 88), Image.Resampling.BOX)).astype(np.float32)
    moved = np.roll(a, a.shape[1] // 2, axis=1)
    x = np.linspace(0.0, 1.0, a.shape[1])
    k = np.clip((1.0 - np.abs(x - 0.5) * 2.0) * 2.5, 0.0, 1.0)[None, :, None]
    band = Image.fromarray((a * k + moved * (1.0 - k)).clip(0, 255).astype(np.uint8))
    save(process.snap(band.resize((156, 44), Image.Resampling.BOX), False), dest)


def picture(art_id, dest, size):
    img = raw(art_id)
    if img is not None:
        save(process.snap(img.resize(size, Image.Resampling.BOX), False), dest)


def squared(dests):
    """The cellar's wheels turn about their middle: each on a square canvas, centred."""
    for dest in dests:
        path = os.path.join(GODOT, dest)
        if not os.path.exists(path):
            continue
        im = Image.open(path).convert("RGBA")
        side = max(im.size)
        sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        sq.alpha_composite(im, ((side - im.width) // 2, (side - im.height) // 2))
        sq.save(path)


def screen(art_id, dest):
    """The score monitor's glass (the slate's 1.3 m by 0.62 m at the room's pixel), its own
    greens (the game palette has few: snapped they came out brown)."""
    img = raw(art_id)
    if img is None:
        return
    w, h = img.size
    ch = round(w * 0.62 / 1.3)
    img = img.crop((0, (h - ch) // 2, w, (h - ch) // 2 + ch)).resize((128, 61), Image.Resampling.BOX)
    save(img.quantize(colors=32, dither=Image.Dither.NONE).convert("RGB"), dest)


def main():
    want = set(sys.argv[1:])
    if not want or "tex_bowl_screen" in want:
        screen("tex_bowl_screen", CAMP + "bowl_screen.png")
    if not want or "tex_bowl_stripes" in want:
        stripes("tex_bowl_stripes", CAMP + "bowl_stripes.png")
    if not want or "tex_bowl_shoeshelf" in want:
        picture("tex_bowl_shoeshelf", CAMP + "bowl_shoeshelf.png", (282, 173))
    for art_id, items in SHEETS:
        if not want or art_id in want:
            # The two shoes of a pair stand close: one thing.
            sheet(art_id, items, {"bows_desk": 41, "bows_pit": 31, "bows_jams": 11}.get(art_id, 5))
            if art_id == "bows_cellar":
                squared([B + "gear_big.png", B + "gear_small.png", B + "sprocket.png"])
            if art_id == "bows_brnoswick":
                squared([B + "brn_gear_big.png", B + "brn_gear_small.png"])
    for art_id, dest, width, rows in FACES:
        if want and art_id not in want:
            continue
        out = face(art_id, dest, width, rows)
        if out is not None and art_id == "bow_front_a":
            bulbs_glow(art_id, out, rows, CAMP + "bowling_front_glow.png")


if __name__ == "__main__":
    main()
