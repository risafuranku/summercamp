#!/usr/bin/env python3
"""Lesna's street fronts (Liblice-style, see prompts.tsv lib_*) from the Grok elevations:

    python tools/artgen/town_facades.py [id ...]

Each render is a building drawn straight on, on flat magenta. It is keyed, cropped to the
building, box-downsampled to PX_M pixels per metre of its real width and snapped to the
game palette, keeping a hard alpha (the gable's triangle, the hipped roof's slopes):
-> godot/assets/textury/town/<id>.png
-> godot/assets/textury/town/<id>_win.png   its windows only, warmed (the lit evening;
                                            town_lesna adds it as emission)
-> godot/assets/textury/town/lib_facades.json  per front: size in px and metres, where
   the walls stand at the bottom (wall_l, wall_r) and where the gable starts (eave), as
   fractions; town_lesna builds the house's walls and roof to fit the picture.

Window rectangles are measured on the raw renders (fractions of the raw canvas).
Missing renders are skipped.
"""
import json
import os
import sys

from PIL import Image

import process

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "godot", "assets", "textury", "town")
PX_M = 32

# id: real width of the whole picture (m), windows (x0, y0, x1, y1 on the raw canvas).
FRONTS = {
    "lib_gable_ochre": (8.4, [(0.21, 0.55, 0.386, 0.78), (0.61, 0.55, 0.786, 0.78),
                              (0.32, 0.296, 0.40, 0.38), (0.60, 0.296, 0.68, 0.38)]),
    "lib_gable_white": (8.6, [(0.20, 0.53, 0.36, 0.76), (0.63, 0.53, 0.79, 0.76),
                              (0.45, 0.216, 0.55, 0.336)]),
    "lib_gable_red": (8.2, [(0.20, 0.556, 0.38, 0.76), (0.616, 0.556, 0.80, 0.76),
                            (0.444, 0.22, 0.56, 0.33)]),
    "lib_gable_grey": (8.8, [(0.21, 0.556, 0.366, 0.76), (0.636, 0.556, 0.786, 0.76),
                             (0.454, 0.246, 0.546, 0.38)]),
    "lib_kostka": (9.0, [(0.136, 0.406, 0.30, 0.566), (0.416, 0.406, 0.58, 0.566), (0.696, 0.406, 0.86, 0.566)]),
    "lib_jednota_front": (12.0, []),
    "lib_pub_front": (11.5, [(0.058, 0.571, 0.159, 0.789), (0.251, 0.571, 0.352, 0.789),
                             (0.644, 0.571, 0.744, 0.789), (0.836, 0.571, 0.937, 0.789)]),
    "lib_chapel": (6.2, []),
    "lib_firehouse": (9.5, []),
    "lib_farm_gate": (8.0, []),
    "lib_barn": (14.0, []),
    # Podlesi (hamlet_podlesi.gd).
    "lib_ruin": (8.6, []),
    "lib_garage": (6.0, []),
    "lib_cottage": (7.2, [(0.333, 0.533, 0.611, 0.756), (0.408, 0.175, 0.547, 0.333)]),
    "lib_baroque": (8.4, [(0.27, 0.556, 0.39, 0.75), (0.616, 0.556, 0.736, 0.75)]),
}
WARM = (1.0, 1.0, 1.0)
# A patch of plain wall in each front (fractions of the output picture), mirrored into
# a seamless tile for the house's other walls: <id>_side.png.
SIDES = {
    "lib_gable_ochre": (0.41, 0.58, 0.59, 0.78), "lib_gable_white": (0.39, 0.58, 0.61, 0.76),
    "lib_gable_red": (0.40, 0.58, 0.60, 0.70), "lib_gable_grey": (0.39, 0.58, 0.61, 0.80),
    "lib_kostka": (0.31, 0.41, 0.41, 0.56), "lib_chapel": (0.62, 0.62, 0.70, 0.76),
    "lib_firehouse": (0.06, 0.62, 0.13, 0.80), "lib_barn": (0.08, 0.30, 0.30, 0.80),
    "lib_ruin": (0.03, 0.60, 0.14, 0.85), "lib_garage": (0.30, 0.22, 0.70, 0.32),
    "lib_cottage": (0.06, 0.60, 0.28, 0.80), "lib_baroque": (0.42, 0.60, 0.56, 0.80),
}


def box_down(img, w, h):
    r, g, b, a = img.split()
    zero = Image.new("L", img.size, 0)
    pre = Image.merge("RGBA", [Image.composite(ch, zero, a) for ch in (r, g, b)] + [a])
    small = pre.resize((w, h), Image.Resampling.BOX)
    px = small.load()
    for y in range(h):
        for x in range(w):
            pr, pg, pb, pa = px[x, y]
            if pa > 0:
                k = 255.0 / pa
                px[x, y] = (min(255, int(pr * k)), min(255, int(pg * k)), min(255, int(pb * k)), pa)
    return small


def extent(img, y):
    a = img.getchannel("A")
    row = [a.getpixel((x, y)) for x in range(img.width)]
    xs = [x for x, v in enumerate(row) if v >= 128]
    return (xs[0], xs[-1] + 1) if xs else (0, 0)


def make(fid, meta):
    src = os.path.join(HERE, "out", fid, "raw.png")
    if not os.path.exists(src):
        print("missing", fid)
        return
    width_m, windows = FRONTS[fid]
    raw = Image.open(src)
    rw, rh = raw.size
    keyed = process.key_out(raw)
    bbox = keyed.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()
    keyed = keyed.crop(bbox)
    w = round(width_m * PX_M)
    h = round(keyed.height * w / keyed.width)
    small = box_down(keyed, w, h)
    out = process.snap(small, True)
    out.save(os.path.join(OUT, fid + ".png"))
    # Where the walls stand and where the roof or gable begins.
    full = max(extent(out, y)[1] - extent(out, y)[0] for y in range(h))
    eave = next(y for y in range(h) if extent(out, y)[1] - extent(out, y)[0] >= full * 0.97)
    wl, wr = extent(out, h - 2)
    # The windows, lit: the picture's own pixels inside each (a pixel in from the frame),
    # black elsewhere; the game multiplies it by the lamp's colour.
    win = Image.new("RGB", (w, h), (0, 0, 0))
    cut = []
    for x0, y0, x1, y1 in windows:
        # Raw canvas -> cropped picture -> output pixels.
        fx0 = (x0 * rw - bbox[0]) / (bbox[2] - bbox[0])
        fx1 = (x1 * rw - bbox[0]) / (bbox[2] - bbox[0])
        fy0 = (y0 * rh - bbox[1]) / (bbox[3] - bbox[1])
        fy1 = (y1 * rh - bbox[1]) / (bbox[3] - bbox[1])
        cut.append([round(fx0, 4), round(fy0, 4), round(fx1, 4), round(fy1, 4)])
        px0, px1 = int(fx0 * w) + 1, int(fx1 * w) - 1
        py0, py1 = int(fy0 * h) + 1, int(fy1 * h) - 1
        for y in range(py0, py1):
            for x in range(px0, px1):
                r, g, b, a = out.getpixel((x, y))
                lum = (r + g + b) / 3.0
                v = 60 + lum * 0.75
                win.putpixel((x, y), (int(v * WARM[0]), int(v * WARM[1]), int(v * WARM[2])))
    if windows:
        win.save(os.path.join(OUT, fid + "_win.png"))
    if fid in SIDES:
        x0, y0, x1, y1 = SIDES[fid]
        patch = out.convert("RGB").crop((int(x0 * w), int(y0 * h), int(x1 * w), int(y1 * h)))
        tile = Image.new("RGB", (patch.width * 2, patch.height * 2))
        tile.paste(patch, (0, 0))
        tile.paste(patch.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (patch.width, 0))
        tile.paste(patch.transpose(Image.Transpose.FLIP_TOP_BOTTOM), (0, patch.height))
        tile.paste(patch.transpose(Image.Transpose.ROTATE_180), (patch.width, patch.height))
        tile.save(os.path.join(OUT, fid + "_side.png"))
    meta[fid] = {
        "px": [w, h], "m": [round(width_m, 3), round(h / PX_M, 3)],
        "eave": round(eave / h, 4), "wall_l": round(wl / w, 4), "wall_r": round(wr / w, 4),
        "windows": cut,
    }
    print(fid, (w, h), "eave %.2f walls %.2f-%.2f" % (eave / h, wl / w, wr / w))


def main():
    path = os.path.join(OUT, "lib_facades.json")
    meta = {}
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            meta = json.load(f)
    for fid in sys.argv[1:] or list(FRONTS.keys()):
        make(fid, meta)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(meta, f, indent=1, sort_keys=True)
        f.write("\n")


if __name__ == "__main__":
    main()
