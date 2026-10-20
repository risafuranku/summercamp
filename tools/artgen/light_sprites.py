"""Light drawn as Build drew it: a render of light on black made into a sprite whose colour
is the light in a few flat shade steps, for additive drawing (agent B, 20. 10.).

    python tools/artgen/light_sprites.py [id ...]

  spr_lamp_beam -> godot/assets/textury/camp/lamp_beam.png (48 x 112): the lamp's cone,
      drawn added to what is behind it (scripts/building_manager.gd, LAMP_BEAM_TEX).
  spr_mist_bank -> godot/assets/textury/world/mist_bank.png (96 wide): a bank of ground
      mist, white, see-through in four steps (scripts/ambient/ground_life.gd tints it).
  spr_sun -> godot/assets/textury/skybox/sun.png (40 x 40): the sun, its white-hot disc
      and its haze in four steps, drawn added to the sky (weather_visuals.gd).
  spr_fire_smoke -> godot/assets/textury/camp/fire_smoke.png (32 tall): a puff of the
      bonfire's smoke on magenta; the logs Grok drew under it cut off (below y 745), keyed
      (process.py), scaled by area, the cut bottom rounded, snapped to the palette
      (campfire.gd through materials/fire_smoke.gdshader).
  spr_embers -> godot/assets/textury/camp/embers.png (24 x 8): the bonfire's sparks young,
      older and nearly out, the render's first three embers side by side, 8 x 8 each
      (campfire.gd's three ages of spark, added to the scene).
  spr_water_drop -> godot/assets/textury/world/water_drop.png (6 x 16): a falling drop and
      its streak (ground_life.gd's drips after the rain); black see-through.
  spr_rain_rings -> godot/assets/textury/world/rain_ring.png (64 x 16): a raindrop's ripple
      on a puddle in four frames side by side, each cut out of the render round its own
      middle at one common size (ground_life.gd plays them).

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
# The sun, from its haze's edge to its disc.
SUN = [(110, 70, 40), (190, 130, 80), (250, 210, 150), (255, 250, 235)]
# White, from the thinnest step to the thickest (as see-through as a translucency table).
MIST = [(255, 255, 255, 36), (255, 255, 255, 72), (255, 255, 255, 108), (255, 255, 255, 144)]

ROWS = {
    # (dest, size, ramp, the light's threshold in the render, the steps' bounds 0..1)
    "spr_lamp_beam": ("assets/textury/camp/lamp_beam.png", (48, 112), WARM, 0.07, (0.3, 0.55, 0.8)),
    "spr_mist_bank": ("assets/textury/world/mist_bank.png", (96, 0), MIST, 0.06, (0.25, 0.5, 0.75)),
    "spr_sun": ("assets/textury/skybox/sun.png", (40, 40), SUN, 0.05, (0.22, 0.5, 0.82)),
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


def fire_smoke() -> None:
    sys.path.insert(0, HERE)
    import process
    img = Image.open(os.path.join(OUT, "spr_fire_smoke", "raw.png")).convert("RGB")
    img = img.crop((0, 0, img.width, 745))
    a = np.asarray(process.key_out(img)).astype(np.float32)
    ys, xs = np.nonzero(a[..., 3] > 127)
    piece = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h = 32
    w = max(1, round(piece.shape[1] * h / piece.shape[0]))
    prem = piece[..., :3] * (piece[..., 3:4] / 255.0)
    pc = np.asarray(Image.fromarray(prem.clip(0, 255).astype(np.uint8)).resize((w, h), Image.BOX)).astype(np.float32)
    pa = np.asarray(Image.fromarray(piece[..., 3].astype(np.uint8), "L").resize((w, h), Image.BOX)).astype(np.float32) / 255.0
    col = (pc / np.maximum(pa[..., None], 1e-3)).clip(0, 255)
    pink = (col[..., 0] + col[..., 2]) * 0.5 - col[..., 1] > 18.0
    col = np.where(pink[..., None], col.mean(axis=2, keepdims=True), col)
    yy, xx = np.mgrid[0:h, 0:w]
    inside = ((xx + 0.5 - w / 2) / (w * 0.52)) ** 2 + ((yy + 0.5 - h * 0.42) / (h * 0.6)) ** 2 <= 1.0
    keep = (pa >= 0.5) & ~((yy > h * 0.5) & ~inside)
    out = np.zeros((h, w, 4), np.uint8)
    out[keep, :3] = col[keep]
    out[keep, 3] = 255
    snapped = process.snap(Image.fromarray(out, "RGBA"), True)
    snapped.save(os.path.join(GODOT, "assets/textury/camp/fire_smoke.png"))
    print("spr_fire_smoke -> assets/textury/camp/fire_smoke.png", snapped.size)


def _runs(lum: np.ndarray, cut: float, gap: int) -> list:
    """Column runs of lit pixels, a gap of more than `gap` between them."""
    cols = np.nonzero((lum > cut).any(axis=0))[0]
    runs, start = [], cols[0]
    for c0, c1 in zip(cols[:-1], cols[1:]):
        if c1 - c0 > gap:
            runs.append((start, c0 + 1))
            start = c1
    runs.append((start, cols[-1] + 1))
    return runs


def embers() -> None:
    a = np.asarray(Image.open(os.path.join(OUT, "spr_embers", "raw.png")).convert("RGB")).astype(np.float32)
    lum = a.mean(axis=2) / 255.0
    # The first three (the render's last, a dying speck, is too dark to read).
    runs = [r for r in _runs(lum, 0.06, 20) if r[1] - r[0] >= 10][:3]
    # One common cell round each one's middle (the first is the biggest).
    side = max(x1 - x0 for x0, x1 in runs) + 6
    n = 8
    out = np.zeros((n, n * len(runs), 4), np.uint8)
    for i, (x0, x1) in enumerate(runs):
        rows = np.nonzero((lum[:, x0:x1] > 0.06).any(axis=1))[0]
        cx, cy = (x0 + x1) // 2, (rows[0] + rows[-1] + 1) // 2
        crop = a[cy - side // 2: cy - side // 2 + side, cx - side // 2: cx - side // 2 + side]
        small = np.asarray(Image.fromarray(crop.clip(0, 255).astype(np.uint8)).resize((n, n), Image.BOX)).astype(np.float32)
        m = small.mean(axis=2) > 20.0
        cell = out[:, i * n:(i + 1) * n]
        cell[m, :3] = small[m].clip(0, 255)
        cell[m, 3] = 255
    path = os.path.join(GODOT, "assets/textury/camp/embers.png")
    Image.fromarray(out, "RGBA").save(path)
    print("spr_embers -> assets/textury/camp/embers.png", (n * len(runs), n), len(runs), "frames")


def water_drop() -> None:
    a = np.asarray(Image.open(os.path.join(OUT, "spr_water_drop", "raw.png")).convert("RGB")).astype(np.float32)
    lum = a.mean(axis=2) / 255.0
    ys, xs = np.nonzero(lum > 0.08)
    crop = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    w, h = 6, 16
    small = np.asarray(Image.fromarray(crop.clip(0, 255).astype(np.uint8)).resize((w, h), Image.BOX)).astype(np.float32)
    out = np.zeros((h, w, 4), np.uint8)
    m = small.mean(axis=2) > 28.0
    out[m, :3] = small[m].clip(0, 255)
    out[m, 3] = 255
    path = os.path.join(GODOT, "assets/textury/world/water_drop.png")
    Image.fromarray(out, "RGBA").save(path)
    print("spr_water_drop -> assets/textury/world/water_drop.png", (w, h))


def rain_rings() -> None:
    a = np.asarray(Image.open(os.path.join(OUT, "spr_rain_rings", "raw.png")).convert("RGB")).astype(np.float32)
    lum = a.mean(axis=2) / 255.0
    cols = np.nonzero((lum > 0.25).any(axis=0))[0]
    # The frames: runs of lit columns with a gap between them.
    runs, start = [], cols[0]
    for c0, c1 in zip(cols[:-1], cols[1:]):
        if c1 - c0 > 20:
            runs.append((start, c0 + 1))
            start = c1
    runs.append((start, cols[-1] + 1))
    boxes = []
    for x0, x1 in runs:
        ys = np.nonzero((lum[:, x0:x1] > 0.25).any(axis=1))[0]
        boxes.append(((x0 + x1) // 2, (ys[0] + ys[-1] + 1) // 2))
    side = max(max(x1 - x0 for x0, x1 in runs), 1) + 8
    n = 16
    out = np.zeros((n, n * len(boxes), 4), np.uint8)
    for i, (cx, cy) in enumerate(boxes):
        crop = lum[cy - side // 2: cy - side // 2 + side, cx - side // 2: cx - side // 2 + side]
        small = np.asarray(Image.fromarray((crop * 255).astype(np.uint8), "L").resize((n, n), Image.BOX)) / 255.0
        m = small > 0.12
        out[:, i * n:(i + 1) * n][m] = (200, 212, 224, 255)
    path = os.path.join(GODOT, "assets/textury/world/rain_ring.png")
    Image.fromarray(out, "RGBA").save(path)
    print("spr_rain_rings -> assets/textury/world/rain_ring.png", (n * len(boxes), n), len(boxes), "frames")


if __name__ == "__main__":
    for i in sys.argv[1:] or list(ROWS) + ["spr_rain_rings", "spr_fire_smoke", "spr_embers", "spr_water_drop"]:
        if i == "spr_embers":
            embers()
        elif i == "spr_water_drop":
            water_drop()
        elif i == "spr_rain_rings":
            rain_rings()
        elif i == "spr_fire_smoke":
            fire_smoke()
        else:
            light_sprite(i)
