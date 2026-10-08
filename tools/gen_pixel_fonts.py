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
        atlas, placed = pack(glyphs)
        write_fnt(name, face, size, ascent, descent, spacing, glyphs, placed, atlas)
        print("%-10s %3d glyphs  atlas %dx%d" % (name, len(glyphs), atlas.width, atlas.height))


if __name__ == "__main__":
    main()
