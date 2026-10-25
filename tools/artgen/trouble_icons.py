"""The HUD's trouble plates' pictures (scripts/ui/trouble_strip.gd), from Grok's renders
(tools/artgen/prompts_trouble.tsv, spr_hud_tr_<kind>): each keyed out and boxed down into
12 x 10 pixels (the tallest that fits both ways), snapped to the palette, and ringed with
one pixel of bone (a black bag or a dark van was lost on the dark plate): 14 x 12 at most.

    python tools/artgen/trouble_icons.py

Writes godot/assets/textury/ui/trouble_<kind>.png. A render not there yet is skipped.
"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import process  # noqa: E402

BOX = (12, 10)
KINDS = ["litter", "raccoons", "delivery", "lost_kid", "noise", "tree", "someone", "breaker", "lamp",
         "sewer", "toilet", "corn", "frozen", "pub", "rest", "vecerka", "stand",
         # The housework (playtest 25. 10.): the showers, a lodging to clean, one to make up.
         "shower", "clean", "bed"]
DEST = os.path.join(process.GODOT, "assets", "textury", "ui")


RING = (214, 202, 168, 255)


def ring(img):
    img = img.convert("RGBA")
    w, h = img.size
    out = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    out.paste(img, (1, 1))
    src = out.load()
    solid = [[src[x, y][3] > 0 for x in range(w + 2)] for y in range(h + 2)]
    for y in range(h + 2):
        for x in range(w + 2):
            if solid[y][x]:
                continue
            if any(0 <= x + dx < w + 2 and 0 <= y + dy < h + 2 and solid[y + dy][x + dx] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                src[x, y] = RING
    return out


def main():
    for k in KINDS:
        src = os.path.join(HERE, "out", "spr_hud_tr_" + k, "raw.png")
        if not os.path.exists(src):
            print("skip", k)
            continue
        h = BOX[1]
        out = process.sprite(src, h)
        while out.width > BOX[0] and h > 4:
            h -= 1
            out = process.sprite(src, h)
        out = ring(out)
        path = os.path.join(DEST, "trouble_%s.png" % k)
        out.save(path)
        print(k, "->", os.path.relpath(path, process.GODOT), out.size)


if __name__ == "__main__":
    main()
