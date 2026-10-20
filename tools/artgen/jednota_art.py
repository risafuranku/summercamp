#!/usr/bin/env python3
"""The camp's Jednota (rows in prompts_jednota.tsv, written by jednota_prompts.py) from
tools/artgen/out/<id>/raw.png into the game's files.

    python tools/artgen/jednota_art.py [id ...]     (all when none are given)

- jd_iso, jd_isoback: the Builder's map sprites (builder/iso_jednota.png, back_jednota.png):
  the deep pink backdrop keyed, its tint off the edges, cropped to what is drawn, hard alpha,
  64 colours (crt_map_panel fits the drawn part to the building's span);
- jd_front, jd_side, jd_backwall: the faces of its Build model (building_models._jednota),
  the pavement under the wall cut off, the side's enamel plate (its letters came out as
  gibberish) plastered over;
- jd_till, jd_store, jd_rack: the stations' Build paintings (bistro_art.buildify: roughened,
  the palette), cut to what the station lies on (the till's counter strip, the packing
  table without the floor round it, the rack without the floor under it) and stretched to
  the station's own shape, into assets/textury/jednota/st_*.png;
- jds_goods, jds_store, jds_till: sheets cut apart into assets/textury/jednota/ (the
  stations shrink them further to the rooms' pixel as they lay them out).
A missing render is skipped with a note.
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import process  # noqa: E402
import pub_art  # noqa: E402
import split_sheet  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
GODOT = os.path.join(HERE, "..", "..", "godot")
J = "assets/textury/jednota/"
CAMP = "assets/textury/camp/"
B = "assets/textury/builder/"

# (render id, file under godot/, width px, rows kept (0..1 of the height): the pavement off)
FACES = [
    ("jd_front", CAMP + "jednota_front.png", 256, (0.0, 0.952)),
    ("jd_side", CAMP + "jednota_side.png", 224, (0.0, 0.958)),
    ("jd_backwall", CAMP + "jednota_back.png", 256, (0.0, 0.9)),
]
ISOS = [("jd_iso", B + "iso_jednota.png", 300), ("jd_isoback", B + "back_jednota.png", 300)]
# (render id, file, crop box in the 1280 x 720 render, size px): the shapes are the
# stations' (jednota_layout.SURFACES: the till 1.6 x 0.6 m, the table 1.6 x 0.525 m, the
# rack 2.2 x 1.24 m).
PANELS = [("jd_till", J + "st_till.png", (0, 100, 1280, 580), (320, 120)),
          ("jd_store", J + "st_store.png", (290, 235, 960, 455), (320, 105)),
          ("jd_rack", J + "st_rack.png", (0, 0, 1280, 668), (320, 180))]
GOODS = ["bread", "roll", "salami", "milk", "pickles", "beer", "icecream", "sweets", "veg", "soap"]
SHEETS = [
    ("jds_goods", [(J + "goods_%s.png" % g, 40) for g in GOODS]),
    ("jds_store", [(J + "box_closed.png", 48), (J + "box_open.png", 48), (J + "trolley.png", 96), (J + "pallet.png", 64)]),
    ("jds_till", [(J + "coin1.png", 14), (J + "coin2.png", 16), (J + "note5.png", 40), (J + "note10.png", 40),
                  (J + "note20.png", 40), (J + "basket.png", 44), (J + "bag.png", 40)]),
]


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


def plaster_over(img, box, src_box):
    """The enamel plate on the side (`box`) under plaster cut from the same wall (`src_box`)."""
    patch = img.crop(src_box).resize((box[2] - box[0], box[3] - box[1]), Image.Resampling.NEAREST)
    img.paste(patch, box[:2])


def face(art_id, dest, width, rows):
    img = raw(art_id)
    if img is None:
        return
    if art_id == "jd_side":
        # The plate at the right (its letters gibberish): the plaster from the left of it.
        w, h = img.size
        plaster_over(img, (int(w * 0.69), int(h * 0.21), int(w * 0.96), int(h * 0.49)),
                     (int(w * 0.17), int(h * 0.30), int(w * 0.44), int(h * 0.58)))
    w, h = img.size
    img = img.crop((0, int(h * rows[0]), w, int(h * rows[1])))
    small = img.resize((width, round(img.height * width / img.width)), Image.Resampling.BOX)
    save(process.snap(small, False), dest)


def keyed_pink(img):
    """The render's backdrop is a deep pink (about 227, 7, 130) or the key's magenta: it and
    its tint on the edges go; the red board and the freezer (no blue in them) stay."""
    out = img.convert("RGBA")
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, _a = px[x, y]
            if r > 150 and g < 90 and b > 80:
                px[x, y] = (0, 0, 0, 0)
            elif r > g + 60 and b > g + 50:
                v = (g * 2 + min(r, b)) // 3
                px[x, y] = (v, v, v, 255)
    return out


def iso(art_id, dest, width):
    img = raw(art_id)
    if img is None:
        return
    k = keyed_pink(img)
    box = k.getchannel("A").point(lambda v: 255 if v > 0 else 0).getbbox()
    if box:
        k = k.crop(box)
    h = max(1, round(k.height * width / k.width))
    small = k.resize((width, h), Image.Resampling.LANCZOS)
    a = small.getchannel("A").point(lambda v: 255 if v >= 110 else 0)
    rgb = small.convert("RGB").quantize(colors=64, dither=Image.Dither.NONE).convert("RGB")
    out = rgb.convert("RGBA")
    out.putalpha(a)
    save(out, dest)


def panel(art_id, dest, box, size):
    import bistro_art  # noqa: E402
    img = raw(art_id)
    if img is None:
        return
    w, h = img.size
    k = w / 1280.0
    img = img.crop(tuple(round(v * k) for v in box))
    small = img.resize(size, Image.Resampling.BOX)
    save(process.snap(bistro_art.buildify(small, 12), False), dest)


def sheet(art_id, items, gap=5):
    """pub_art.sheet with a narrower gap: the goods stand close together on their sheet."""
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


def fifty():
    """The fifty: the twenty's note in purple (the sheet has no fifty)."""
    src = os.path.join(GODOT, J, "note20.png")
    if not os.path.exists(src):
        return
    img = Image.open(src).convert("RGBA")
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            px[x, y] = (int(r * 0.62), int(g * 0.55), min(255, int(r * 0.95 + b * 0.3)), a)
    save(process.snap(img, True), J + "note50.png")


def main():
    want = set(sys.argv[1:])
    for art_id, dest, width, rows in FACES:
        if not want or art_id in want:
            face(art_id, dest, width, rows)
    for art_id, dest, width in ISOS:
        if not want or art_id in want:
            iso(art_id, dest, width)
    for art_id, dest, box, size in PANELS:
        if not want or art_id in want:
            panel(art_id, dest, box, size)
    for art_id, items in SHEETS:
        if not want or art_id in want:
            sheet(art_id, items)
    if not want or "jds_till" in want:
        fifty()


if __name__ == "__main__":
    main()
