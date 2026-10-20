"""Light drawn as Build drew it: a render of light on black made into a sprite whose colour
is the light in a few flat shade steps, for additive drawing (agent B, 20. 10.).

    python tools/artgen/light_sprites.py [id ...]

  spr_lamp_beam -> godot/assets/textury/camp/lamp_beam.png (48 x 112): the lamp's cone,
      drawn added to what is behind it (scripts/building_manager.gd, LAMP_BEAM_TEX).
  spr_mist_bank -> godot/assets/textury/world/mist_bank.png (96 wide): a bank of ground
      mist, white, see-through in four steps (scripts/ambient/ground_life.gd tints it).

The render's brightness, from its dimmest to its brightest inside the light, becomes four
steps: of a warm lamplight ramp (black see-through), or of see-through white (`alpha`).
"""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
GODOT = os.path.join(HERE, "..", "..", "godot")

# Lamplight from the dimmest step to the brightest (a palette's ramp: its own hue).
WARM = [(70, 44, 20), (128, 84, 40), (196, 140, 72), (250, 214, 150)]
# White, from the thinnest step to the thickest (as see-through as a translucency table).
MIST = [(255, 255, 255, 36), (255, 255, 255, 72), (255, 255, 255, 108), (255, 255, 255, 144)]

ROWS = {
    # (dest, size, ramp, the light's threshold in the render, the steps' bounds 0..1)
    "spr_lamp_beam": ("assets/textury/camp/lamp_beam.png", (48, 112), WARM, 0.07, (0.3, 0.55, 0.8)),
    "spr_mist_bank": ("assets/textury/world/mist_bank.png", (96, 0), MIST, 0.06, (0.25, 0.5, 0.75)),
}


def light_sprite(art_id: str) -> None:
    dest, size, ramp, cut, steps = ROWS[art_id]
    a = np.asarray(Image.open(os.path.join(OUT, art_id, "raw.png")).convert("RGB")).astype(np.float32)
    lum = a.mean(axis=2) / 255.0
    # The light's own extent (the render leaves black round it).
    ys, xs = np.nonzero(lum > cut)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    crop = Image.fromarray((lum[y0:y1, x0:x1] * 255).astype(np.uint8), "L")
    if size[1] == 0:
        # Its own height for the width.
        size = (size[0], max(1, round(crop.height * size[0] / crop.width)))
    small = np.asarray(crop.resize(size, Image.BOX)).astype(np.float32) / 255.0
    inside = small >= cut
    lo, hi = np.percentile(small[inside], 3), np.percentile(small[inside], 99)
    norm = np.clip((small - lo) / max(hi - lo, 1e-3), 0.0, 1.0)
    band = np.searchsorted(np.array(steps), norm, side="right")
    out = np.zeros((size[1], size[0], 4), np.uint8)
    for i, col in enumerate(ramp):
        m = inside & (band == i)
        out[m, :3] = col[:3]
        out[m, 3] = col[3] if len(col) > 3 else 255
    path = os.path.join(GODOT, dest)
    Image.fromarray(out, "RGBA").save(path)
    print(art_id, "->", dest, size)


if __name__ == "__main__":
    for i in sys.argv[1:] or list(ROWS):
        light_sprite(i)
