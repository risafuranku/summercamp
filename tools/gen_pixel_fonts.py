#!/usr/bin/env python3
"""Bake the UI pixel fonts into BMFont bitmap fonts that Godot scales by integers only.

Pixel fonts shipped as TTF are outlines drawn on a pixel grid. Godot rasterises them at
whatever size a Label asks for, so unless that size lands exactly on the font's own grid
the glyphs come out uneven: doubled columns, merged strokes, a "C" that reads as "G".
PixelifySans (the previous body font) is not on a grid at all and was never crisp.

This script renders every glyph on its native grid (1 font pixel = 1 bitmap pixel) and
writes a BMFont (.fnt text + .png atlas). Imported with `scaling_mode = integer`, Godot
then draws each font pixel as exactly N x N screen pixels for font_size = size x N.

Fonts (sources under tools/font_src/, licences next to the outputs):
  Silkscreen   8 px em  caps-only labels, captions          -> silkscreen.fnt
  Tiny5        8 px em  mixed-case body text, feed, tracker -> tiny5.fnt
  Jersey 10   10 px cap big numbers, titles, banners        -> jersey10.fnt
  W95FA       12 px em  the camp computer (a Windows-95-era system font) -> w95.fnt
  W95FA bold  the same, emboldened by one pixel (title bars, buttons)   -> w95b.fnt
  Pixel Operator Mono  16 px em  the BIOS / text-mode screens (CC0)     -> pomono.fnt

Run from the repo root:  python tools/gen_pixel_fonts.py
Requires Pillow >= 10.1 (float font sizes) and fontTools.
"""
import os

from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "font_src")
OUT = os.path.join(HERE, "..", "godot", "assets", "fonts")
OVER = 8  # supersampling factor; glyphs are sampled at font-pixel centres

# name, source file, font units per pixel, nominal size (what Godot calls fixed_size),
# ascent and descent in font pixels (the line box), letter spacing in font pixels, and
# whether to embolden (smear one pixel to the right, advance + 1).
FONTS = [
    ("silkscreen", "Silkscreen-Regular.ttf", 125, 8, 8, 2, 0, False),
    ("tiny5", "Tiny5-Regular.ttf", 128, 8, 7, 2, 0, False),
    ("jersey10", "Jersey10-Regular.ttf", 75, 10, 15, 5, 0, False),
    ("w95", "W95FA-Regular.otf", 80, 12, 10, 3, 0, False),
    ("w95b", "W95FA-Regular.otf", 80, 12, 10, 3, 1, True),
    ("pomono", "PixelOperatorMono-Regular.ttf", 100, 16, 13, 3, 0, False),
]

CHARSET = [c for c in range(0x20, 0x7F)] + [c for c in range(0xA0, 0x180)] + [
    0x2013, 0x2014, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2026, 0x20AC, 0x2122,
]


def rasterise(font_path: str, unit: int, ascent: int, descent: int, bold: bool = False):
    tt = TTFont(font_path)
    upm = tt["head"].unitsPerEm
    cmap = tt.getBestCmap()
    hmtx = tt["hmtx"]
    em_px = upm / unit
    pil = ImageFont.truetype(font_path, em_px * OVER)
    line_h = ascent + descent
    glyphs = {}
    for cp in CHARSET:
        if cp not in cmap:
            continue
        adv = round(hmtx[cmap[cp]][0] / unit)
        ch = chr(cp)
        pad = 4
        w = (adv + pad * 2 + 4) * OVER
        h = (line_h + pad * 2) * OVER
        big = Image.new("L", (w, h), 0)
        d = ImageDraw.Draw(big)
        d.fontmode = "1"
        d.text((pad * OVER, (pad + ascent) * OVER), ch, font=pil, fill=255, anchor="ls")
        sw, sh = w // OVER, h // OVER
        small = Image.new("L", (sw, sh), 0)
        src, dst = big.load(), small.load()
        for y in range(sh):
            for x in range(sw):
                if src[x * OVER + OVER // 2, y * OVER + OVER // 2] > 127:
                    dst[x, y] = 255
        if bold:
            smeared = small.copy()
            sd = smeared.load()
            for y in range(sh):
                for x in range(1, sw):
                    if dst[x - 1, y]:
                        sd[x, y] = 255
            small = smeared
        bbox = small.getbbox()
        if bbox is None:
            glyphs[cp] = {"img": None, "xoff": 0, "yoff": 0, "adv": adv}
            continue
        x0, y0, x1, y1 = bbox
        glyphs[cp] = {
            "img": small.crop(bbox),
            "xoff": x0 - pad,
            "yoff": y0 - pad,
            "adv": adv,
        }
    return glyphs


# ── Czech letters a font lacks: the base letter and a mark ─────────────────────────
# (Silkscreen has no č ř ě ď ť ň ů, W95FA none of the carons, and its ý Ý have lost their
# acute.) A mark is taken from a letter the font does have (the acute from É/E, the caron
# from Š/S) or drawn here, centred over the base, as far above it as the font puts its own
# accents. ď and ť take the apostrophe at their right, unless the font's small letters are
# its capitals (Silkscreen): then they take the caron like Ď and Ť.

CZECH = {
    "Á": ("A", "acute"), "á": ("a", "acute"), "É": ("E", "acute"), "é": ("e", "acute"),
    "Í": ("I", "acute"), "í": ("i", "acute"), "Ó": ("O", "acute"), "ó": ("o", "acute"),
    "Ú": ("U", "acute"), "ú": ("u", "acute"), "Ý": ("Y", "acute"), "ý": ("y", "acute"),
    "Č": ("C", "caron"), "č": ("c", "caron"), "Ď": ("D", "caron"), "ď": ("d", "apos"),
    "Ě": ("E", "caron"), "ě": ("e", "caron"), "Ň": ("N", "caron"), "ň": ("n", "caron"),
    "Ř": ("R", "caron"), "ř": ("r", "caron"), "Š": ("S", "caron"), "š": ("s", "caron"),
    "Ť": ("T", "caron"), "ť": ("t", "apos"), "Ž": ("Z", "caron"), "ž": ("z", "caron"),
    "Ů": ("U", "ring"), "ů": ("u", "ring"),
}
MARKS = {
    "caron": ["#.#", ".#."],
    "ring": [".#.", "#.#", ".#."],
    "acute": [".#", "#."],
}
SOURCES = {"acute": [("É", "E"), ("é", "e"), ("Á", "A"), ("á", "a")], "caron": [("Š", "S"), ("š", "s"), ("Ž", "Z"), ("ž", "z")]}


def _pixels(g):
    out = set()
    if g is None or g["img"] is None:
        return out
    px = g["img"].load()
    w, h = g["img"].size
    for y in range(h):
        for x in range(w):
            if px[x, y]:
                out.add((x + g["xoff"], y + g["yoff"]))
    return out


def _box(pix):
    xs = [p[0] for p in pix]
    ys = [p[1] for p in pix]
    return min(xs), min(ys), max(xs), max(ys)


def _mark_from_font(glyphs, kind, upper):
    """(pixels relative to their own top left, gap rows between mark and base) or None."""
    for acc, base in SOURCES.get(kind, []):
        if acc.isupper() != upper:
            continue
        a, b = glyphs.get(ord(acc)), glyphs.get(ord(base))
        pa, pb = _pixels(a), _pixels(b)
        if not pa or not pb:
            continue
        top = _box(pb)[1]
        mark = {p for p in pa - pb if p[1] < top}
        if not mark or pa - mark != pb:
            continue
        x0, y0, x1, y1 = _box(mark)
        return {(x - x0, y - y0) for x, y in mark}, top - y1 - 1
    return None


def _drawn(kind):
    rows = MARKS[kind]
    return {(x, y) for y, r in enumerate(rows) for x, c in enumerate(r) if c == "#"}


def compose_czech(glyphs, bold=False):
    caps_only = _pixels(glyphs.get(ord("d"))) == _pixels(glyphs.get(ord("D")))
    made = []
    for ch, (base_ch, kind) in CZECH.items():
        cp = ord(ch)
        base = glyphs.get(ord(base_ch))
        pb = _pixels(base)
        if not pb:
            continue
        have = glyphs.get(cp)
        if have is not None and _pixels(have) != pb:
            continue  # the font's own, with its accent
        if kind == "apos" and caps_only:
            kind = "caron"
        upper = base_ch.isupper() or caps_only
        bx0, by0, bx1, by1 = _box(pb)
        adv = base["adv"]
        if kind == "apos":
            ap = _pixels(glyphs.get(ord("'")))
            if not ap:
                continue
            ax0, ay0, _, ay1 = _box(ap)
            # beside the stem, its top at the stem's top, a column clear of it
            h = min(ay1 - ay0 + 1, 2)
            mark = {(bx1 + 2, by0 + k) for k in range(h)}
            adv += 2
        else:
            found = _mark_from_font(glyphs, kind, upper)
            shape, gap = found if found else (_drawn(kind), 1)
            if not found and bold:
                shape = shape | {(x + 1, y) for x, y in shape}
            if kind == "ring" and not found:
                gap = 0 if upper else 1
            mx1 = max(p[0] for p in shape)
            my1 = max(p[1] for p in shape)
            ox = bx0 + (bx1 - bx0 + 1 - (mx1 + 1)) // 2
            oy = by0 - gap - 1 - my1
            mark = {(ox + x, oy + y) for x, y in shape}
        pix = pb | mark
        x0, y0, x1, y1 = _box(pix)
        img = Image.new("L", (x1 - x0 + 1, y1 - y0 + 1), 0)
        ip = img.load()
        for x, y in pix:
            ip[x - x0, y - y0] = 255
        glyphs[cp] = {"img": img, "xoff": x0, "yoff": y0, "adv": adv}
        made.append(ch)
    return made


def pack(glyphs, width: int = 256):
    x = y = 1
    row_h = 0
    placed = {}
    for cp in sorted(glyphs):
        img = glyphs[cp]["img"]
        if img is None:
            placed[cp] = (0, 0, 0, 0)
            continue
        gw, gh = img.size
        if x + gw + 1 > width:
            x = 1
            y += row_h + 1
            row_h = 0
        placed[cp] = (x, y, gw, gh)
        x += gw + 1
        row_h = max(row_h, gh)
    height = 1
    while height < y + row_h + 1:
        height *= 2
    atlas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    for cp, (px, py, gw, gh) in placed.items():
        img = glyphs[cp]["img"]
        if img is None:
            continue
        white = Image.new("RGBA", img.size, (255, 255, 255, 255))
        atlas.paste(white, (px, py), img)
    return atlas, placed


def write_fnt(name, face, size, ascent, descent, spacing, glyphs, placed, atlas):
    line_h = ascent + descent
    lines = [
        'info face="%s" size=%d bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1 outline=0'
        % (face, size),
        "common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0 alphaChnl=0 redChnl=4 greenChnl=4 blueChnl=4"
        % (line_h, ascent, atlas.width, atlas.height),
        'page id=0 file="%s.png"' % name,
        "chars count=%d" % len(glyphs),
    ]
    for cp in sorted(glyphs):
        g = glyphs[cp]
        px, py, gw, gh = placed[cp]
        lines.append(
            "char id=%d x=%d y=%d width=%d height=%d xoffset=%d yoffset=%d xadvance=%d page=0 chnl=15"
            % (cp, px, py, gw, gh, g["xoff"], g["yoff"], g["adv"] + spacing)
        )
    with open(os.path.join(OUT, name + ".fnt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    atlas.save(os.path.join(OUT, name + ".png"))


def main():
    for name, src, unit, size, ascent, descent, spacing, bold in FONTS:
        path = os.path.join(SRC, src)
        face = TTFont(path)["name"].getDebugName(1) or name
        glyphs = rasterise(path, unit, ascent, descent, bold)
        made = compose_czech(glyphs, bold)
        atlas, placed = pack(glyphs)
        write_fnt(name, face, size, ascent, descent, spacing, glyphs, placed, atlas)
        print("%-10s %3d glyphs  atlas %dx%d%s" % (name, len(glyphs), atlas.width, atlas.height, ("  composed " + "".join(made)) if made else ""))


if __name__ == "__main__":
    main()
