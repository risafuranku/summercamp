#!/usr/bin/env python3
"""The businesses' people and things (rows in prompts_biz.tsv, written by biz_prompts.py)
from tools/artgen/out/<id>/raw.png into the game's files.

    python tools/artgen/biz_art.py [id ...]     (all when none are given)

- the hands (bzh_<slug>): a sheet of the same person standing and at work; both cut out
  at one scale, the standing one 128 px tall (people are 73.6 px to a metre), into
  assets/textury/npc/staff/<slug>.png and <slug>_work.png, the rim defringed;
- the ID photos (ph_<slug>): 48x64 into assets/textury/os98/photos/<slug>.png;
- the goods gone off and the chalk (bzs_*): a row of things cut apart, each to its height
  at the rooms' pixel (91 px to a metre), into assets/textury/camp/.
A missing render is skipped with a note.
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import defringe  # noqa: E402
import process  # noqa: E402
import split_sheet  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
GODOT = os.path.join(HERE, "..", "..", "godot")
STAFF = "assets/textury/npc/staff/"
PHOTOS = "assets/textury/os98/photos/"
CAMP = "assets/textury/camp/"
PEOPLE = ["dvorakova", "pepa", "hanka", "lojza", "franta", "mirek", "novakova", "zdenka", "ivan", "pepicek",
          "klara", "novak_boy", "jaromir", "marta"]
PERSON_H = 128
# Red-faced people: the rim pass would take their skin for magenta fringe.
NO_DEFRINGE = {"pepa", "lojza"}
# (render id, [(name, height px), ...] left to right)
SHEETS = [
    ("bzs_off1", [("off_potatoes", 46), ("off_cheese", 16), ("off_bread", 20), ("off_milk", 24), ("off_cob", 18)]),
    ("bzs_off2", [("off_rolls", 18), ("off_salami", 24), ("off_pickles", 18), ("off_dumplings", 16), ("off_keg", 52)]),
    ("bzs_chalk", [("chalk_strike", 10), ("chalk_x", 16), ("chalk_under", 6), ("chalk_tick", 12)]),
]


def raw(art_id):
    p = os.path.join(OUT, art_id, "raw.png")
    return p if os.path.exists(p) else None


def keyed_items(src):
    img = process.key_out(Image.open(src))
    boxes, labels, w = split_sheet.items(img, 14)
    return img, [split_sheet.own(img, b, labels[b], w) for b in boxes]


def person(slug):
    src = raw("bzh_" + slug)
    if src is None:
        print("skip (no render)", slug)
        return
    img, parts = keyed_items(src)
    parts = [p for p in parts if p.height > img.height * 0.4]
    if len(parts) < 2:
        print("FAIL", slug, "found", len(parts), "figures")
        return
    stand, work = parts[0], parts[1]
    scale = PERSON_H / float(stand.height)
    os.makedirs(os.path.join(GODOT, STAFF), exist_ok=True)
    for name, part in ((slug, stand), (slug + "_work", work)):
        small = split_sheet.shrink(part, scale)
        path = os.path.join(GODOT, STAFF, name + ".png")
        small.save(path)
        print(name, small.size, "" if slug in NO_DEFRINGE else defringe.figure(path, []))


def photo(pid):
    src = raw(pid)
    if src is None:
        print("skip (no render)", pid)
        return
    img = Image.open(src).convert("RGB")
    # 3:4 to the 48x64 of the other photos.
    w, h = img.size
    want = w * 4 / 3
    if h > want:
        top = (h - want) / 2
        img = img.crop((0, int(top), w, int(top + want)))
    img = img.resize((48, 64), Image.Resampling.BOX)
    out = process.snap(img, False)
    name = pid[3:]
    path = os.path.join(GODOT, PHOTOS, name + ".png")
    out.save(path)
    print(name, out.size)


def sheet(art_id, names):
    src = raw(art_id)
    if src is None:
        print("skip (no render)", art_id)
        return
    img, parts = keyed_items(src)
    if len(parts) != len(names):
        print("WARN", art_id, "found", len(parts), "items for", len(names))
    for (name, height), part in zip(names, parts):
        scale = height / float(max(part.width, part.height))
        small = split_sheet.shrink(part, scale)
        path = os.path.join(GODOT, CAMP, name + ".png")
        small.save(path)
        print(name, small.size)


def main():
    want = set(sys.argv[1:])
    for slug in PEOPLE:
        if not want or ("bzh_" + slug) in want or slug in want:
            person(slug)
    for pid in ["ph_jaromir", "ph_marta", "ph_marta2", "ph_marta3"]:
        if not want or pid in want:
            photo(pid)
    for art_id, names in SHEETS:
        if not want or art_id in want:
            sheet(art_id, names)


if __name__ == "__main__":
    main()
