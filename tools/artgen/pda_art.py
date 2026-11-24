#!/usr/bin/env python3
"""The PDA's pictures (Richard 24. 11., docs/player.md "PDA se stylusem") out of Grok's renders:

    python tools/artgen/pda_art.py

hand_pda_b (approved 24. 11.: "2: velká obrazovka") -> assets/textury/hands/pda.png: the left
    glove holding the palmtop, the whole frame kept (so the screen sits where SCREEN says), the
    stylus taken out of its slot into assets/textury/hands/pda_stylus.png (the cursor).
pda_icons -> assets/textury/pda/icons.png: the five apps' icons, 1-bit, ICON px squares in a row
    (map, inbox, tasks, clock and weather, snake).
"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import process  # noqa: E402
import cursor  # noqa: E402

GODOT = os.path.join(HERE, "..", "..", "godot")
OUT = os.path.join(HERE, "out")
## The render's screen (flood-filled from its middle) and the stylus in its slot, in the
## 1024 px render.
RAW_SCREEN = (474, 274, 614, 599)
RAW_STYLUS = (582, 84, 628, 216)
## The sprite's pixels: the screen 69 px across, as the HUD's other hands are (x3 at 720p).
SCALE = 69.33 / (RAW_SCREEN[2] - RAW_SCREEN[0] + 1)
ICON = 32


def hand():
    src = Image.open(os.path.join(OUT, "hand_pda_b", "raw.png")).convert("RGBA")
    keyed = process.key_out(src)
    stylus = keyed.crop(RAW_STYLUS)
    px = keyed.load()
    # The slot without its stylus: the device's own grey round the hole stays, the stylus goes.
    for y in range(RAW_STYLUS[1], 182):
        for x in range(RAW_STYLUS[0], RAW_STYLUS[2]):
            px[x, y] = (0, 0, 0, 0)
    w, h = keyed.size
    out = keyed.resize((round(w * SCALE), round(h * SCALE)), Image.BOX)
    out = process.snap(out, True)
    dest = os.path.join(GODOT, "assets", "textury", "hands", "pda.png")
    out.save(dest)
    sw, sh = stylus.size
    st = process.snap(stylus.resize((max(1, round(sw * SCALE)), max(1, round(sh * SCALE))), Image.BOX), True)
    st.save(os.path.join(GODOT, "assets", "textury", "hands", "pda_stylus.png"))
    sx = RAW_SCREEN[0] * SCALE
    sy = RAW_SCREEN[1] * SCALE
    print("pda.png", out.size, "screen at", round(sx), round(sy), "size", round((RAW_SCREEN[2] - RAW_SCREEN[0] + 1) * SCALE), round((RAW_SCREEN[3] - RAW_SCREEN[1] + 1) * SCALE))
    print("pda_stylus.png", st.size)
    # The pointer while the PDA is up: the stylus leaning as a right hand holds it, its tip
    # top left (HandCursor.STYLUS's hot spot), outlined like the other pointers.
    k = 40.0 / stylus.size[1]
    small = stylus.resize((max(1, round(stylus.size[0] * k)), 40), Image.BOX)
    tilted = small.rotate(32, resample=Image.NEAREST, expand=True)
    tilted = tilted.crop(tilted.getbbox())
    cur = cursor.outline(process.snap(tilted, True))
    cur.save(os.path.join(GODOT, "assets", "textury", "ui", "cursor_stylus.png"))
    a = cur.split()[3]
    tip = next((x, y) for y in range(cur.size[1]) for x in range(cur.size[0]) if a.getpixel((x, y)) > 0)
    print("cursor_stylus.png", cur.size, "tip", tip, "hot", round(tip[0] / cur.size[0], 3), round(tip[1] / cur.size[1], 3))


def icons():
    src = process.key_out(Image.open(os.path.join(OUT, "pda_icons", "raw.png")).convert("RGBA"))
    w, h = src.size
    a = src.split()[3]
    cols = [any(a.getpixel((x, y)) > 0 for y in range(h)) for x in range(w)]
    spans = []
    x = 0
    while x < w:
        if cols[x]:
            x0 = x
            gap = 0
            while x < w and gap < 24:
                gap = 0 if cols[x] else gap + 1
                x += 1
            spans.append((x0, x - gap))
        else:
            x += 1
    sheet = Image.new("RGBA", (ICON * len(spans), ICON), (0, 0, 0, 0))
    for i, (x0, x1) in enumerate(spans):
        part = src.crop((x0, 0, x1, h))
        bbox = part.getbbox()
        part = part.crop(bbox)
        k = (ICON - 2) / max(part.size)
        part = part.resize((max(1, round(part.size[0] * k)), max(1, round(part.size[1] * k))), Image.BOX)
        # 1-bit: what is dark enough is ink.
        ink = Image.new("RGBA", part.size, (0, 0, 0, 0))
        pp = part.load()
        ip = ink.load()
        for yy in range(part.size[1]):
            for xx in range(part.size[0]):
                r, g, b, al = pp[xx, yy]
                if al > 90 and (r + g + b) / 3 < 120:
                    ip[xx, yy] = (0, 0, 0, 255)
        sheet.paste(ink, (i * ICON + (ICON - part.size[0]) // 2, (ICON - part.size[1]) // 2))
    os.makedirs(os.path.join(GODOT, "assets", "textury", "pda"), exist_ok=True)
    sheet.save(os.path.join(GODOT, "assets", "textury", "pda", "icons.png"))
    print("icons.png", len(spans), "icons")


def logo():
    """Okna's window for the task bar's start, 1-bit, 12 x 9: the office's logo (a window with
    four panes and its trail) as the LCD's dot matrix can hold it."""
    rows = [
        "..XXXXXXXXXX",
        "..X...XX...X",
        "X.X...XX...X",
        "..XXXXXXXXXX",
        "XXX...XX...X",
        "..X...XX...X",
        "X.X...XX...X",
        "..XXXXXXXXXX",
        "............",
    ]
    out = Image.new("RGBA", (12, 9), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "X":
                out.putpixel((x, y), (0, 0, 0, 255))
    out.save(os.path.join(GODOT, "assets", "textury", "pda", "logo.png"))
    print("logo.png", out.size)


if __name__ == "__main__":
    hand()
    icons()
    logo()
