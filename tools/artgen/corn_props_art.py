#!/usr/bin/env python3
"""The corn stand counter's things as sprites of their own (Richard 25. 11.: „všechny předměty
na pultu s kukuřicí převést z 2D textury na 3D sprites co tam stojí“): rows in
prompts_corn_props.tsv, from tools/artgen/out/<id>/raw.png into the game's files.

    python tools/artgen/corn_props_art.py

- corn_prop_<thing> -> assets/textury/corn/prop_<thing>.png (keyed, LONG_PX on its long side,
  on the palette; the station scales it to the room's pixel);
- corn_counter_bare -> assets/textury/corn/st_counter_bare.png (the counter top with nothing
  on it, the size of st_counter.png).
Then `godot --headless --path godot --import`.
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import process  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.join(HERE, "..", "..", "godot")
CORN = os.path.join(GODOT, "assets", "textury", "corn")
THINGS = ["butter", "pot", "board", "salt", "napkins", "cash"]
LONG_PX = 96


def main():
    for thing in THINGS:
        src = os.path.join(HERE, "out", "corn_prop_" + thing, "raw.png")
        if not os.path.exists(src):
            print("skip (no render)", thing)
            continue
        out = process.sprite(src, LONG_PX)
        if out.width > out.height:
            out = process.sprite(src, max(8, int(round(LONG_PX * out.height / float(out.width)))))
        out.save(os.path.join(CORN, "prop_%s.png" % thing))
        print(thing, out.size)
    src = os.path.join(HERE, "out", "corn_counter_bare", "raw.png")
    if os.path.exists(src):
        ref = Image.open(os.path.join(CORN, "st_counter.png"))
        img = Image.open(src).convert("RGB").resize(ref.size, Image.BOX)
        out = process.snap(img, False)
        out.save(os.path.join(CORN, "st_counter_bare.png"))
        print("counter", out.size)


if __name__ == "__main__":
    main()
