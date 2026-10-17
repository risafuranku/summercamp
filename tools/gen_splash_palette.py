#!/usr/bin/env python3
"""The studio splash's 256-colour palette and LUT (scripts/ui/studio_splash.gd).

A palette swap in the Build sense: the game's palette (tools/gen_palette_lut.py) has no
pink, violet or cyan, so the neon would come out brown. This keeps the game's ramps the
splash needs (the planks, the night, the cable) and replaces the rest with ramps of the
UNDO mosaic's colours, built the same way (16 shades from black through the base colour
towards warm white). The splash's shader then walks every pixel through the LUT exactly
like materials/build_post.gdshader does for the world.

Run from the repo root:  python tools/gen_splash_palette.py
  -> godot/assets/boot/splash_palette.png      16x16 swatch (a ramp per column)
     godot/assets/boot/splash_palette_lut.png  1024x32 strip LUT (same layout as the game's)
"""
import os

import numpy as np
from PIL import Image

from gen_palette_lut import build_lut

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot", "assets")
GAME_PALETTE = os.path.join(ROOT, "textury", "palette", "build_palette.png")
OUT = os.path.join(ROOT, "boot")

# The game's ramps kept, by index in build_palette.png (column = ramp):
# grey, beige, wood, rust, amber, moss, night, violet, bone.
KEEP = [0, 1, 2, 3, 4, 7, 11, 12, 15]
# The mosaic (undocollective brand/mosaic.svg) and the pink of the UNDO tube's coat.
BRAND = [(0xFF, 0x16, 0x94), (0xDD, 0x16, 0xC8), (0x8D, 0x24, 0xFF), (0x31, 0x5C, 0xFF),
         (0x19, 0xBC, 0xEB), (0xFF, 0x4F, 0xB8), (0x5A, 0x40, 0xFF)]


def ramp(base):
    """16 shades like gen_palette_lut.build_palette: the base sits at 66 %."""
    base = np.array(base, dtype=np.float64)
    out = []
    for i in range(16):
        v = (i + 1) / 16.0
        if v <= 0.66:
            c = base * (v / 0.66) ** 1.15
        else:
            t = (v - 0.66) / 0.34
            c = base + (np.array([250.0, 246.0, 232.0]) - base) * (t * 0.62)
        out.append(np.clip(c, 0, 255))
    return out


def main():
    game = np.asarray(Image.open(GAME_PALETTE).convert("RGB")).astype(np.int32)
    ramps = [[game[y, x] for y in range(16)] for x in KEEP]
    ramps += [ramp(b) for b in BRAND]
    assert len(ramps) == 16
    pal = np.array([c for r in ramps for c in r], dtype=np.int32)
    pal[0] = (0, 0, 0)
    os.makedirs(OUT, exist_ok=True)
    sw = pal.astype(np.uint8).reshape(16, 16, 3).transpose(1, 0, 2)
    Image.fromarray(sw, "RGB").save(os.path.join(OUT, "splash_palette.png"))
    Image.fromarray(build_lut(pal), "RGB").save(os.path.join(OUT, "splash_palette_lut.png"))
    print("splash palette + LUT written to", OUT)


if __name__ == "__main__":
    main()
