#!/usr/bin/env python3
"""The building site's renders (rows in prompts_site.tsv) from tools/artgen/out/<id>/raw.png
into the game's files.

    python tools/artgen/site_art.py

- the workers' sheets (site_worker_<x>), cut apart and scaled alike (standing 128 px tall, the
  people's pixel), the rim defringed, into assets/textury/npc/site/worker_<x>_<frame>.png:
  a: standing, the hammer up, the hammer down (kneeling); b: standing, two steps carrying
  planks on the shoulder.
Then `godot --headless --path godot --import`.
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import defringe  # noqa: E402
import process  # noqa: E402
import split_sheet  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.join(HERE, "..", "..", "godot")
DEST = os.path.join(GODOT, "assets", "textury", "npc", "site")
STAND_PX = 128


FRAMES = {"a": ("stand", "up", "down"), "b": ("stand", "carry_a", "carry_b")}


def worker(x):
    src = os.path.join(HERE, "out", "site_worker_" + x, "raw.png")
    if not os.path.exists(src):
        print("skip (no render)", x)
        return
    img = process.key_out(Image.open(src))
    boxes, labels, w = split_sheet.items(img, 14)
    parts = [split_sheet.own(img, b, labels[b], w) for b in boxes]
    parts = [p for p in parts if max(p.width, p.height) > img.height * 0.25]
    if len(parts) != 3:
        print("FAIL", x, "found", len(parts), "figures")
        return
    scale = STAND_PX / float(parts[0].height)
    os.makedirs(DEST, exist_ok=True)
    for name, part in zip(FRAMES[x], parts):
        small = split_sheet.shrink(part, scale)
        path = os.path.join(DEST, "worker_%s_%s.png" % (x, name))
        small.save(path)
        print(x, name, small.size, defringe.figure(path, []))


if __name__ == "__main__":
    for x in (sys.argv[1:] or ["a", "b"]):
        worker(x)
