#!/usr/bin/env python3
"""The camp computer's second set of art (Grok renders in tools/artgen/out/<id>/raw.png)
brought to the sizes the OS uses. Runs on whatever has been generated; missing ones
are skipped.

    python tools/artgen/os_art.py
-> godot/assets/textury/os98/icons/<name>.png (32 px) and <name>_16.png  (ico2_*)
   godot/assets/textury/os98/oem_splash.png   the maker's boot screen, 640x480, text set
   godot/assets/textury/os98/wall_autumn.png, wall_okna.png   wallpapers, 640x480
   godot/assets/textury/builder/splash.png    Builder 98's title picture
   godot/assets/textury/builder/tb2_*.png     Builder's toolbar, 32 px
   godot/assets/textury/builder/dust.png      the puff a building lands with
   godot/assets/textury/mail/spam_*.png       the pictures spam carries
The Okna splash is tools/artgen/okna_splash.py (it uses okna2_splash when present).
"""
import io
import os

from PIL import Image, ImageDraw, ImageFont

import process

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.join(HERE, "..", "..", "godot", "assets", "textury")
FONTS = "C:/Windows/Fonts/"


def raw(art_id):
    p = os.path.join(HERE, "out", art_id, "raw.png")
    return Image.open(p) if os.path.exists(p) else None


def corner_key(img):
    """Grok sometimes paints the backdrop a darker magenta than the key: take it from
    the corners and drop everything close to it."""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    cs = [px[2, 2], px[w - 3, 2], px[2, h - 3], px[w - 3, h - 3]]
    kr, kg, kb = (sum(c[i] for c in cs) // 4 for i in range(3))
    if not (kr > 120 and kb > 90 and kg < 80):
        return img
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if abs(r - kr) + abs(g - kg) + abs(b - kb) < 90:
                px[x, y] = (0, 0, 0, 0)
    return img


def keyed(art_id):
    img = raw(art_id)
    if img is None:
        return None
    img = process.key_out(corner_key(img))
    bbox = img.getchannel("A").point(lambda a: 255 if a > 40 else 0).getbbox()
    return img.crop(bbox) if bbox else img


def fit(img, size, pad=0):
    k = min((size - pad * 2) / img.width, (size - pad * 2) / img.height)
    small = img.resize((max(1, round(img.width * k)), max(1, round(img.height * k))), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(small, ((size - small.width) // 2, (size - small.height) // 2), small)
    # Hard alpha and a limited palette, like a real 1998 icon.
    a = canvas.getchannel("A").point(lambda v: 255 if v >= 110 else 0)
    rgb = canvas.convert("RGB").quantize(colors=48, dither=Image.Dither.NONE).convert("RGB")
    out = rgb.convert("RGBA")
    out.putalpha(a)
    return out


def icons():
    names = ["browser", "mail", "notepad", "mines", "builder", "campstat", "guestrack", "setup", "money", "computer", "bin", "bin_full", "folder", "documents"]
    for n in names:
        img = keyed("ico2_" + n)
        if img is None:
            continue
        d = os.path.join(GODOT, "os98", "icons")
        fit(img, 32, 1).save(os.path.join(d, n + ".png"))
        fit(img, 16).save(os.path.join(d, n + "_16.png"))
        print("icon", n)


def oem():
    img = raw("oem2_splash")
    if img is None:
        return
    img = img.convert("RGB").resize((640, 480), Image.LANCZOS)
    d = ImageDraw.Draw(img)
    big = ImageFont.truetype(FONTS + "arialbd.ttf", 30)
    mid = ImageFont.truetype(FONTS + "arialbd.ttf", 15)
    small = ImageFont.truetype(FONTS + "ariali.ttf", 13)
    tiny = ImageFont.truetype(FONTS + "arial.ttf", 10)

    def centred(y, s, font, fill, shadow=(10, 6, 2)):
        w = d.textlength(s, font=font)
        d.text(((640 - w) / 2 + 2, y + 2), s, font=font, fill=shadow)
        d.text(((640 - w) / 2, y), s, font=font, fill=fill)

    centred(318, "CAMPTRONICS", big, (255, 196, 90))
    centred(352, "F I E L D W A R E   I N C .", mid, (230, 200, 150))
    centred(374, "Proudly field assembled in Jihlava", small, (200, 170, 120))
    d.text((14, 462), "Camptronics FieldPC 133  -  BIOS v2.03  -  (C) 1994-97 Camptronics Fieldware Inc.", font=tiny, fill=(150, 130, 100))
    img.save(os.path.join(GODOT, "os98", "oem_splash.png"))
    print("oem splash")


def jpeg(img, q):
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=q)
    return Image.open(io.BytesIO(buf.getvalue())).convert("RGB")


def walls():
    for art, name, q in (("wall2_autumn", "wall_autumn.png", 72), ("wall2_okna", "wall_okna.png", 85)):
        img = raw(art)
        if img is None:
            continue
        img = img.convert("RGB").resize((640, 480), Image.LANCZOS)
        if name == "wall_okna.png":
            img = img.quantize(colors=64, dither=Image.Dither.NONE).convert("RGB")
        jpeg(img, q).save(os.path.join(GODOT, "os98", name))
        print("wall", name)


def builder():
    img = raw("bld_splash")
    if img is not None:
        img = img.convert("RGB").resize((512, 288), Image.LANCZOS)
        img.quantize(colors=128, dither=Image.Dither.NONE).convert("RGB").save(os.path.join(GODOT, "builder", "splash.png"))
        print("builder splash")
    for n in ["bulldoze", "path", "lamp", "housing", "services", "fun", "utilities", "rotate", "zoom"]:
        k = keyed("tb2_" + n)
        if k is None:
            continue
        fit(k, 32, 1).save(os.path.join(GODOT, "builder", "tb2_%s.png" % n))
        print("tb2", n)
    k = keyed("bld_dust")
    if k is not None:
        fit(k, 48).save(os.path.join(GODOT, "builder", "dust.png"))
        print("dust")


def spam():
    os.makedirs(os.path.join(GODOT, "mail"), exist_ok=True)
    for n in ["spam_lottery", "spam_pills", "spam_phone", "spam_chain", "spam_dating"]:
        img = raw(n)
        if img is None:
            continue
        img = img.convert("RGB").resize((240, 180), Image.LANCZOS)
        img.quantize(colors=32, dither=Image.Dither.FLOYDSTEINBERG).convert("RGB").save(os.path.join(GODOT, "mail", n + ".png"))
        print("spam", n)


if __name__ == "__main__":
    icons()
    oem()
    walls()
    builder()
    spam()
