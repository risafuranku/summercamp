#!/usr/bin/env python3
"""The pub's and the corn stand's art (rows in prompts_pubcorn.tsv, written by
pub_corn_prompts.py) from tools/artgen/out/<id>/raw.png into the game's files.

    python tools/artgen/pub_art.py [id ...]     (all when none are given)

Every sheet is a row of things on magenta: keyed, the magenta-tinted rim taken off, cut
apart left to right, each one box-shrunk to its own size (the longer side, px) and
snapped to the palette:
- the pub's things at the stations (mugs, glasses, bottles, streams, kegs, the coupler)
  into assets/textury/pub/ (scripts/business/station3d.gd shrinks them further to the
  rooms' pixel as it lays them on the bar);
- the corn's things into assets/textury/corn/;
- the marks over the rooms into assets/textury/ui/mark_*.png;
- the pub's room props into assets/textury/camp/pub_*.png (interior_kit cutouts, at the
  rooms' pixel: 91 px to a metre).
A missing render is skipped with a note.
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import process  # noqa: E402
import split_sheet  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
GODOT = os.path.join(HERE, "..", "..", "godot")
P = "assets/textury/pub/"
C = "assets/textury/corn/"
UI = "assets/textury/ui/"
CAMP = "assets/textury/camp/"
# (render id, [(file under godot/, longer side px), ...] left to right)
SHEETS = [
    # The glassware drawn plain for the rooms' pixel (a mug is 16 px there): pts_glass2,
    # not the first dimpled sheet (pts_glass), which went to noise that small.
    ("pts_glass2", [(P + "mug_clean.png", 48), (P + "mug_beer.png", 48), (P + "foam.png", 34), (P + "mug_dirty.png", 48),
                    (P + "glass_tall.png", 40), (P + "glass_kofola.png", 40), (P + "shot_empty.png", 16), (P + "shot_full.png", 16)]),
    ("pts_tap", [(P + "tap_tower.png", 64), (P + "tap_handle.png", 40), (P + "drip_tray.png", 48)]),
    ("pts_bottles", [(P + "bottle_rum.png", 56), (P + "bottle_zelena.png", 56), (P + "bottle_slivovice.png", 56),
                     (P + "bottle_kofola.png", 48), (P + "jigger.png", 14)]),
    ("pts_bar", [(P + "stream_beer.png", 50), (P + "stream_foam.png", 50), (P + "puddle.png", 26), (P + "mat.png", 20),
                 (P + "towel.png", 22), (P + "knife.png", 22), (P + "drip.png", 5)]),
    ("pts_keg", [(P + "keg.png", 64), (P + "keg_empty.png", 64), (P + "coupler.png", 26), (P + "valve.png", 18),
                 (P + "chalk_tally.png", 14)]),
    ("cts_corn", [(C + "cob_husk.png", 40), (C + "husk_leaf.png", 36), (C + "silk.png", 16), (C + "cob_raw.png", 36),
                  (C + "cob_boiled.png", 36), (C + "cob_mushy.png", 36), (C + "cob_buttered.png", 36), (C + "cob_napkin.png", 38)]),
    ("psh_marks", [(UI + "mark_mug.png", 16), (UI + "mark_foam.png", 16), (UI + "mark_shot.png", 14), (UI + "mark_kofola.png", 16),
                   (UI + "mark_keg.png", 16), (UI + "mark_dirty.png", 16), (UI + "mark_corn.png", 16)]),
    ("psh_room", [(CAMP + "pub_boar.png", 50), (CAMP + "pub_pennant.png", 33), (CAMP + "pub_hockey.png", 46),
                  (CAMP + "pub_calendar.png", 42), (CAMP + "pub_board.png", 46), (CAMP + "pub_stove.png", 118),
                  (CAMP + "pub_coal.png", 27), (CAMP + "pub_mats.png", 12)]),
    ("psh_room2", [(CAMP + "pub_geranium.png", 29), (CAMP + "pub_plaque.png", 14), (CAMP + "pub_coatstand.png", 120),
                   (CAMP + "pub_flypaper.png", 46), (CAMP + "pub_radio.png", 30), (CAMP + "pub_print.png", 46),
                   (CAMP + "pub_crate.png", 40)]),
    ("psh_cellar", [(CAMP + "pub_cooler.png", 50), (CAMP + "pub_barrel.png", 64), (CAMP + "pub_trap.png", 14),
                    (CAMP + "pub_broom.png", 109), (CAMP + "pub_bucket.png", 27), (CAMP + "pub_cobweb.png", 46)]),
]


def despilled(src):
    """Every magenta-tinted pixel to the key (no pink rim once keyed and shrunk)."""
    img = Image.open(src).convert("RGB")
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b = px[x, y]
            if r - g > 50 and b - g > 35:
                px[x, y] = (255, 0, 255)
    return img


def sheet(art_id, items):
    src = os.path.join(OUT, art_id, "raw.png")
    if not os.path.exists(src):
        print("skip (no render)", art_id)
        return
    img = process.key_out(despilled(src))
    boxes, labels, w = split_sheet.items(img, 14)
    parts = [split_sheet.own(img, b, labels[b], w) for b in boxes]
    if len(parts) != len(items):
        print("WARN", art_id, "found", len(parts), "items for", len(items))
    for (dest, longest), part in zip(items, parts):
        scale = longest / float(max(part.width, part.height))
        small = split_sheet.shrink(part, scale)
        path = os.path.join(GODOT, dest)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        small.save(path)
        print(dest, small.size)


def main():
    want = set(sys.argv[1:])
    for art_id, items in SHEETS:
        if not want or art_id in want:
            sheet(art_id, items)


if __name__ == "__main__":
    main()
