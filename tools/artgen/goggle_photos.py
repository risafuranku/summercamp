#!/usr/bin/env python3
"""The guests' photos on the camp's Goggle page (the Reviews tab's Photos): screenshots
of the camp out of the shot driver, turned into last summer's snaps from a cheap
compact camera (a 1997 print scanned for the web: JPEG blocks, a warm cast, the orange
date in the corner). One has somebody at the edge of the trees who should not be there.

    python tools/artgen/goggle_photos.py <dir with the shots>
-> godot/assets/textury/os98/web/photo_<n>.png (360x270) and photo_<n>_t.png (120x90)

The shots are 1280x720 game frames (HUD at the bottom, the feed at the top-left): the
picture is cut from between them.
"""
import io
import os
import sys

from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.join(HERE, "..", "..", "godot")
OUT = os.path.join(GODOT, "assets", "textury", "os98", "web")

# [shot name, centre x of the 4:3 cut, the date on the print, odd]
PHOTOS = [
    ["clear_1200_jetty", 560, "97 7 26", False],
    ["clear_1200_tents", 700, "97 8  2", True],
    ["clear_1200_reception", 520, "97 7 19", False],
    ["clear_1815_jetty", 640, "97 8 11", False],
    ["clear_1700_cabins", 520, "97 8 15", False],
    ["clear_1200_corn", 700, "97 8 21", False],
]

# A 3x5 pixel font for the camera's date.
DIGITS = {
    "0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
    "2": ["111", "001", "111", "100", "111"], "3": ["111", "001", "111", "001", "111"],
    "4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"],
    "6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
    "8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "111"],
    " ": ["000", "000", "000", "000", "000"], "'": ["100", "100", "000", "000", "000"],
}


def date_stamp(img, text, scale=2):
    """The orange date a 90s compact burnt into the corner of the print."""
    px = img.load()
    w, h = img.size
    tw = len(text) * 4 * scale
    x0, y0 = w - tw - 6, h - 5 * scale - 6
    for i, ch in enumerate(text):
        rows = DIGITS.get(ch, DIGITS[" "])
        for ry, row in enumerate(rows):
            for rx, bit in enumerate(row):
                if bit != "1":
                    continue
                for sy in range(scale):
                    for sx in range(scale):
                        x = x0 + i * 4 * scale + rx * scale + sx
                        y = y0 + ry * scale + sy
                        if 0 <= x < w and 0 <= y < h:
                            px[x, y] = (255, 150, 52)


def jpeg(img, q):
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=q)
    buf.seek(0)
    return Image.open(buf).convert("RGB")


def warm(img):
    r, g, b = img.split()
    r = r.point(lambda v: min(255, int(v * 1.06 + 6)))
    b = b.point(lambda v: int(v * 0.90))
    return Image.merge("RGB", (r, g, b))


def figure():
    """A guest standing still, facing this way: the quiet guy, dimmed into the shade."""
    p = os.path.join(GODOT, "assets", "textury", "npc", "host1.png")
    f = Image.open(p).convert("RGBA")
    f = f.crop(f.getchannel("A").getbbox())
    a = f.getchannel("A")
    body = Image.merge("RGB", [c.point(lambda v: int(v * 0.42)) for c in f.convert("RGB").split()])
    face = Image.merge("RGB", [c.point(lambda v: int(v * 0.85)) for c in f.convert("RGB").split()])
    # The face left pale in the shade.
    body.paste(face.crop((0, 0, f.width, f.height * 22 // 100)), (0, 0))
    f = body.convert("RGBA")
    f.putalpha(a)
    return f


def main(src_dir):
    os.makedirs(OUT, exist_ok=True)
    for n, (name, cx, date, odd) in enumerate(PHOTOS, 1):
        shot = Image.open(os.path.join(src_dir, name + ".png")).convert("RGB")
        # Between the feed and the HUD: 4:3 around cx.
        top, bottom = 100, 590
        ch = bottom - top
        cw = ch * 4 // 3
        left = max(0, min(shot.width - cw, cx - cw // 2))
        pic = shot.crop((left, top, left + cw, bottom))
        if odd:
            # At the edge of the trees behind the tents, small, still.
            f = figure()
            fh = 30
            f = f.resize((max(1, f.width * fh // f.height), fh), Image.LANCZOS)
            # Feet where the trees meet the meadow (y 368 of the shot), between two trunks.
            feet = 368 - top
            pic.paste(f, (940 - left - f.width // 2, feet - fh), f)
        big = pic.resize((360, 270), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.45))
        big = warm(jpeg(big, 38))
        date_stamp(big, "'" + date, 2)
        big = jpeg(big, 55)
        big.save(os.path.join(OUT, "photo_%d.png" % n))
        thumb = big.resize((120, 90), Image.LANCZOS)
        thumb.save(os.path.join(OUT, "photo_%d_t.png" % n))
        print("photo", n, name, "odd" if odd else "")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")
