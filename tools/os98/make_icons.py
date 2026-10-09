#!/usr/bin/env python3
"""Make the camp computer's desktop icons: 32x32 and 16x16 with hard alpha.

    python tools/os98/make_icons.py

Sources: the existing icon art (godot/assets/textury/crt/icons, computer-icon.png) and
the Grok renders in tools/artgen/out/ico_*/raw.png (magenta background, keyed out).
Output: godot/assets/textury/os98/icons/<name>.png and <name>_16.png
"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.join(HERE, "..", "..", "godot")
ART = os.path.join(HERE, "..", "artgen", "out")
OUT = os.path.join(GODOT, "assets", "textury", "os98", "icons")

EXISTING = {
    "browser": "assets/textury/crt/icons/beeternet.png",
    "bin": "assets/textury/crt/icons/bin.png",
    "bin_full": "assets/textury/crt/icons/binfull.png",
    "builder": "assets/textury/crt/icons/builder.png",
    "campstat": "assets/textury/crt/icons/campstat.png",
    "mail": "assets/textury/crt/icons/email.png",
    "money": "assets/textury/crt/icons/finance.png",
    "folder": "assets/textury/crt/icons/folder.png",
    "guestrack": "assets/textury/crt/icons/guestrack.png",
    "mines": "assets/textury/crt/icons/minesweeper.png",
    "computer": "assets/computer-icon.png",
}
GENERATED = ["txt", "setup", "html", "image", "drive", "floppy", "help", "run", "shutdown", "documents", "notepad"]


def key_magenta(img):
    img = img.convert("RGBA")
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if r > 180 and b > 180 and g < 110:
                px[x, y] = (0, 0, 0, 0)
    return img


def crop_to_content(img):
    bbox = img.getbbox()
    if bbox is None:
        return img
    x0, y0, x1, y1 = bbox
    side = max(x1 - x0, y1 - y0)
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    half = side // 2 + side // 16
    return img.crop((cx - half, cy - half, cx + half, cy + half))


def shrink(img, size):
    # Premultiply so transparent fringe colours do not bleed into the edge.
    img = img.convert("RGBA")
    r, g, b, a = img.split()
    pre = Image.merge("RGBA", (
        Image.composite(r, Image.new("L", img.size, 0), a),
        Image.composite(g, Image.new("L", img.size, 0), a),
        Image.composite(b, Image.new("L", img.size, 0), a), a))
    small = pre.resize((size, size), Image.Resampling.BOX)
    px = small.load()
    for y in range(size):
        for x in range(size):
            pr, pg, pb, pa = px[x, y]
            if pa < 110:
                px[x, y] = (0, 0, 0, 0)
            else:
                k = 255.0 / pa
                px[x, y] = (min(255, int(pr * k)), min(255, int(pg * k)), min(255, int(pb * k)), 255)
    return small


def main():
    os.makedirs(OUT, exist_ok=True)
    sources = {}
    for name, rel in EXISTING.items():
        sources[name] = Image.open(os.path.join(GODOT, rel)).convert("RGBA")
    for name in GENERATED:
        raw = os.path.join(ART, "ico_" + name, "raw.png")
        if os.path.exists(raw):
            sources[name] = crop_to_content(key_magenta(Image.open(raw)))
    for name, img in sources.items():
        shrink(img, 32).save(os.path.join(OUT, name + ".png"))
        shrink(img, 16).save(os.path.join(OUT, name + "_16.png"))
        print(name)


if __name__ == "__main__":
    main()
