#!/usr/bin/env python3
"""The hands at the coarse Build-engine resolution (scripts/ui/hands.gd VIRTUAL_LINES).

    python tools/artgen/hands_lo.py [name ...]

Every sprite in godot/assets/textury/hands/ goes to godot/assets/textury/hands_lo/ at
HALF its height: from its Grok render (tools/artgen/out/<id>/raw.png, keyed and box-
downsampled by process.py) where there is one, else box-downsampled from the sprite
itself; then snapped to the palette. The hands are drawn at twice the pixel size of
before, as coarse as the world.
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import process  # noqa: E402

SRC = os.path.join(process.GODOT, "assets", "textury", "hands")
DST = os.path.join(process.GODOT, "assets", "textury", "hands_lo")
# sprite -> artgen id of its render (when the name differs or a render exists)
RAW = {
    "clamp": "hand_clamp", "oars": "hand_oars", "cig": "hand_cig",
    "cig_mouth": "hand_cig_mouth", "beer": "hand_beer", "beer_drink": "hand_beer_drink",
    "nozzle": "hand_nozzle", "radio": "hand_radio", "megaphone": "hand_megaphone",
}
SCALE = 0.5


def from_sprite(path, h):
    img = Image.open(path).convert("RGBA")
    w = max(1, round(img.width * h / img.height))
    r, g, b, a = img.split()
    pre = Image.merge("RGBA", [Image.composite(ch, Image.new("L", img.size, 0), a) for ch in (r, g, b)] + [a])
    small = pre.resize((w, h), Image.Resampling.BOX)
    px = small.load()
    for y in range(h):
        for x in range(w):
            pr, pg, pb, pa = px[x, y]
            if pa > 0:
                k = 255.0 / pa
                px[x, y] = (min(255, int(pr * k)), min(255, int(pg * k)), min(255, int(pb * k)), pa)
    return process.snap(small, True)


def main():
    os.makedirs(DST, exist_ok=True)
    names = sys.argv[1:] or sorted(f[:-4] for f in os.listdir(SRC) if f.endswith(".png"))
    for n in names:
        src = os.path.join(SRC, n + ".png")
        if not os.path.exists(src):
            print("no", n)
            continue
        h = max(1, round(Image.open(src).height * SCALE))
        art = RAW.get(n, n if n.startswith("hand2_") else "")
        raw = os.path.join(process.HERE, "out", art, "raw.png") if art else ""
        if raw and os.path.exists(raw):
            out = process.sprite(raw, h)
            how = "render"
        else:
            out = from_sprite(src, h)
            how = "sprite"
        out.save(os.path.join(DST, n + ".png"))
        print("%s %s from %s" % (n, out.size, how))


if __name__ == "__main__":
    main()
