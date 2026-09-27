#!/usr/bin/env python3
"""Generate the Build-engine style palette + colour LUT used by the retro renderer.

The palette is a 256-colour median-cut of the game's own Redneck Rampage (Build engine)
textures, NPC sprites and a few hand-picked ramps (sky, grass, flesh, UI amber), so the
whole frame is forced through the same kind of palette the textures were authored in.

Outputs (under godot/assets/textury/palette/):
  build_palette.png   16x16 swatch of the 256 colours (reference / UI use)
  build_palette_lut.png  1024x32 strip LUT: 32 blue slices of 32x32 (red = x, green = y)

Run from the repo root:  python3 tools/gen_palette_lut.py
Requires Pillow + numpy.
"""
import glob
import os
import random

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..", "godot", "assets")
OUT = os.path.join(ROOT, "textury", "palette")
LUT_SIZE = 32


def gather_pixels():
    random.seed(7)
    paths = sorted(glob.glob(os.path.join(ROOT, "textury", "redneck", "**", "*.png"), recursive=True))
    paths += sorted(glob.glob(os.path.join(ROOT, "textury", "npc", "host*.png")))
    chunks = []
    for p in paths:
        try:
            im = Image.open(p).convert("RGBA")
        except Exception:
            continue
        im.thumbnail((48, 48))
        a = np.asarray(im).reshape(-1, 4)
        a = a[a[:, 3] > 200][:, :3]
        if len(a):
            chunks.append(a)
    px = np.concatenate(chunks, axis=0)
    # Hand-picked ramps so sky, night, grass and UI colours always have a home.
    ramps = []
    def ramp(c0, c1, n=24, weight=60):
        for i in range(n):
            t = i / (n - 1)
            c = [int(c0[k] + (c1[k] - c0[k]) * t) for k in range(3)]
            ramps.extend([c] * weight)
    ramp((0, 0, 0), (255, 255, 255), 32, 80)          # grey ramp
    ramp((8, 12, 30), (150, 190, 235), 24, 90)         # night -> day sky
    ramp((10, 22, 8), (150, 175, 70), 24, 70)          # grass
    ramp((30, 4, 4), (230, 40, 30), 16, 60)            # blood
    ramp((40, 24, 4), (255, 190, 60), 16, 50)          # amber / lamp light
    ramp((60, 40, 30), (240, 200, 170), 16, 40)        # flesh
    ramp((5, 20, 25), (80, 160, 170), 12, 30)          # lake
    px = np.concatenate([px, np.array(ramps, dtype=np.uint8)], axis=0)
    return px


# Build engine palettes are organised as colour ramps that fade to black (the shade
# table walks down a ramp). We keep that structure: 16 ramps x 16 shades. Ramp base
# colours are the mean texture colour inside each hue family of the RR textures, with
# a few fixed families (sky, lake, blood, night) so the sky and horror beats survive.
RAMP_FAMILIES = [
    # name, hue range (deg) or None, fixed base colour (used when hue is None / no data)
    ("grey", None, (150, 150, 146)),
    ("beige", (30, 55), (176, 158, 124)),
    ("wood", (18, 32), (140, 96, 58)),
    ("rust", (5, 18), (150, 74, 44)),
    ("amber", (32, 46), (230, 168, 60)),
    ("yellow", (46, 62), (214, 196, 96)),
    ("moss", (62, 90), (124, 132, 70)),
    ("grass", (90, 140), (86, 132, 60)),
    ("lake", None, (54, 120, 118)),
    ("sky", None, (132, 170, 214)),
    ("night", None, (44, 56, 104)),
    ("violet", None, (110, 78, 132)),
    ("blood", None, (196, 30, 26)),
    ("flesh", None, (214, 140, 120)),
    ("skin", None, (200, 160, 118)),
    ("bone", None, (228, 218, 190)),
]


def _hue_deg(rgb):
    r, g, b = rgb[:, 0] / 255.0, rgb[:, 1] / 255.0, rgb[:, 2] / 255.0
    mx = np.max(rgb / 255.0, axis=1)
    mn = np.min(rgb / 255.0, axis=1)
    d = np.maximum(mx - mn, 1e-6)
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4))
    return h * 60.0, (mx - mn) / np.maximum(mx, 1e-6), mx


def build_palette(px):
    px = px.astype(np.float64)
    hue, sat, val = _hue_deg(px)
    pal = []
    for name, hrange, fixed in RAMP_FAMILIES:
        base = np.array(fixed, dtype=np.float64)
        if hrange is not None:
            m = (hue >= hrange[0]) & (hue < hrange[1]) & (sat > 0.18) & (val > 0.25)
            if m.sum() > 500:
                sample = px[m]
                mean = sample.mean(axis=0)
                # normalise brightness so the ramp's base sits around 65% value
                scale = (0.66 * 255.0) / max(mean.max(), 1.0)
                base = np.clip(mean * scale, 0, 255) * 0.6 + base * 0.4
        for i in range(16):
            v = (i + 1) / 16.0
            if v <= 0.66:
                c = base * (v / 0.66) ** 1.15
            else:
                t = (v - 0.66) / 0.34
                c = base + (np.array([250.0, 246.0, 232.0]) - base) * (t * 0.62)
            pal.append(np.clip(c, 0, 255))
    pal = np.array(pal, dtype=np.int32)
    pal[0] = (0, 0, 0)  # true black for fog / shade
    return pal


def build_lut(pal):
    lvl = np.linspace(0, 255, LUT_SIZE)
    r, g, b = np.meshgrid(lvl, lvl, lvl, indexing="ij")
    cols = np.stack([r, g, b], axis=-1).reshape(-1, 3)
    # Weighted RGB distance (cheap perceptual approximation)
    w = np.array([0.30, 0.59, 0.11]) * 3.0
    best = np.zeros(len(cols), dtype=np.int32)
    best_d = np.full(len(cols), np.inf)
    for i, c in enumerate(pal):
        d = (((cols - c) ** 2) * w).sum(axis=1)
        m = d < best_d
        best[m] = i
        best_d[m] = d[m]
    mapped = pal[best].reshape(LUT_SIZE, LUT_SIZE, LUT_SIZE, 3)  # [r][g][b]
    strip = np.zeros((LUT_SIZE, LUT_SIZE * LUT_SIZE, 3), dtype=np.uint8)
    for bi in range(LUT_SIZE):
        # x = red, y = green inside slice bi
        strip[:, bi * LUT_SIZE:(bi + 1) * LUT_SIZE, :] = mapped[:, :, bi, :].transpose(1, 0, 2)
    return strip


def main():
    os.makedirs(OUT, exist_ok=True)
    px = gather_pixels()
    pal = build_palette(px)
    sw = pal.astype(np.uint8).reshape(16, 16, 3).transpose(1, 0, 2)
    Image.fromarray(sw, "RGB").save(os.path.join(OUT, "build_palette.png"))
    Image.fromarray(build_lut(pal), "RGB").save(os.path.join(OUT, "build_palette_lut.png"))
    print("palette + LUT written to", OUT, "from", len(px), "pixels")


if __name__ == "__main__":
    main()
