"""The cloud layers' sprites (scripts/ambient/cloud_layers.gd), from Grok's renders of four
clouds on magenta (prompts_sky.tsv):

    python tools/artgen/cloud_sprites.py [high] [low] [cover] [bits] [dust]

  out/spr_clouds_high/raw.png (four long thin streaks, one above another)
      -> godot/assets/textury/skybox/cloud_hi_0..3.png, 256 wide
  out/spr_clouds_low/raw.png (four dark torn scud clouds in a row)
      -> skybox/cloud_lo_0..3.png, 128 wide
  out/tex_cloud_cover, tex_cloud_cover_b/raw.png (prompts_deck.tsv: a cloud cover seen
      from below, brightness = how thick)
      -> skybox/cloud_cover_a.png, cloud_cover_b.png, 1024 square, grey: made to tile
         (ground_tex.tileable), its values spread evenly over 0..1 by rank (the black
         between the clouds by how near them it is), so the deck's `coverage` 0.3 is
         three tenths of the sky under cloud, the clouds swelling as it grows
         (materials/cloud_deck.gdshader)
The magenta keyed out (process.py), each cloud cut out along whichever way they are laid
out, scaled by area (its colour weighed by how much of each cell is cloud, so no pink
fringe), the edge soft (cloud_layers.gd filters them); what pink the key left in thin
wisps made grey like the rest (as night_sky.py's clouds).
"""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
SKY = os.path.join(HERE, "..", "..", "godot", "assets", "textury", "skybox")
WORLD = os.path.join(HERE, "..", "..", "godot", "assets", "textury", "world")
# key -> (render, file pattern, width px, soft edge, folder)
SETS = {"high": ("spr_clouds_high", "cloud_hi_%d.png", 256, True, SKY),
        "low": ("spr_clouds_low", "cloud_lo_%d.png", 128, True, SKY),
        # What the wind carries (scripts/ambient/wind_things.gd): a twig, straw, newspaper,
        # a wrapper, hard-edged pixel sprites; the dust soft.
        "bits": ("spr_wind_bits", "wind_bit_%d.png", 40, False, WORLD),
        "dust": ("spr_dust_puff", "dust_puff_%d.png", 48, True, WORLD)}


def runs_of(mask_1d: np.ndarray, gap: int, least: int) -> list:
    idx = np.nonzero(mask_1d)[0]
    if idx.size == 0:
        return []
    runs, start = [], idx[0]
    for a, b in zip(idx[:-1], idx[1:]):
        if b - a > gap:
            runs.append((start, a + 1))
            start = b
    runs.append((start, idx[-1] + 1))
    return [r for r in runs if r[1] - r[0] >= least]


def build(key: str) -> None:
    sys.path.insert(0, HERE)
    import process
    art_id, pattern, w, soft, folder = SETS[key]
    img = process.key_out(Image.open(os.path.join(OUT, art_id, "raw.png")))
    a = np.asarray(img).astype(np.float32)
    alpha = a[..., 3] / 255.0
    solid = alpha > 0.5
    # Along x first (a row of clouds); a column of them splits along y.
    pieces = []
    cols = runs_of(solid.any(axis=0), 6, 40)
    if len(cols) >= 2:
        for x0, x1 in cols:
            rows = np.nonzero(solid[:, x0:x1].any(axis=1))[0]
            pieces.append((rows[0], rows[-1] + 1, x0, x1))
    else:
        for y0, y1 in runs_of(solid.any(axis=1), 6, 12):
            cs = np.nonzero(solid[y0:y1].any(axis=0))[0]
            pieces.append((y0, y1, cs[0], cs[-1] + 1))
    for i, (y0, y1, x0, x1) in enumerate(pieces[:4]):
        piece = a[y0:y1, x0:x1]
        h = max(1, round((y1 - y0) * w / (x1 - x0)))
        prem = piece[..., :3] * (piece[..., 3:4] / 255.0)
        pc = np.asarray(Image.fromarray(prem.clip(0, 255).astype(np.uint8)).resize((w, h), Image.BOX)).astype(np.float32)
        pa = np.asarray(Image.fromarray(piece[..., 3].astype(np.uint8), "L").resize((w, h), Image.BOX)).astype(np.float32) / 255.0
        out = np.zeros((h, w, 4), np.uint8)
        col = (pc / np.maximum(pa[..., None], 1e-3)).clip(0, 255)
        pink = (col[..., 0] + col[..., 2]) * 0.5 - col[..., 1] > 18.0
        lum = col.mean(axis=2, keepdims=True)
        col = np.where(pink[..., None], lum * np.array([0.98, 1.0, 1.04]), col)
        # Soft edges (the layers draw them filtered, not as hard pixels): the cell's share
        # of cloud, its colour where there is any.
        if soft:
            some = pa > 0.04
            out[some, :3] = col[some].clip(0, 255)
            out[..., 3] = (np.clip((pa - 0.04) / 0.7, 0.0, 1.0) * 255).astype(np.uint8)
        else:
            m = pa >= 0.5
            out[m, :3] = col[m].clip(0, 255)
            out[m, 3] = 255
        dst = os.path.join(folder, pattern % i)
        Image.fromarray(out, "RGBA").save(dst)
        print("->", dst, (w, h))
    if len(pieces) < 4:
        print("only", len(pieces), "clouds found in", art_id)


def blur_wrap(a: np.ndarray, k: int) -> np.ndarray:
    """A box blur that wraps round the edges (the cover tiles)."""
    pad = np.pad(a, k, mode="wrap")
    cs = np.pad(pad.cumsum(0).cumsum(1), ((1, 0), (1, 0)))
    n = 2 * k + 1
    out = (cs[n:, n:] - cs[:-n, n:] - cs[n:, :-n] + cs[:-n, :-n]) / (n * n)
    return out[: a.shape[0], : a.shape[1]]


def build_cover() -> None:
    sys.path.insert(0, HERE)
    import ground_tex
    for art_id, name in (("tex_cloud_cover", "cloud_cover_a.png"), ("tex_cloud_cover_b", "cloud_cover_b.png")):
        src = os.path.join(OUT, art_id, "raw.png")
        if not os.path.exists(src):
            print("missing", src)
            continue
        im = Image.open(src).convert("RGB")
        side = min(im.size)
        im = im.crop(((im.width - side) // 2, (im.height - side) // 2, (im.width + side) // 2, (im.height + side) // 2))
        im = ground_tex.tileable(im.resize((1024, 1024), Image.LANCZOS))
        lum = blur_wrap(np.asarray(im).astype(np.float32).mean(axis=2) / 255.0, 2)
        # The black between the clouds ranked by how near the clouds it is (a wide blur of
        # them), under every cloud: as the cover grows the clouds swell out from their
        # middles, instead of the sea's noise coming up as clouds of its own.
        pre = lum + 0.18 * blur_wrap(lum, 14) + 0.12 * blur_wrap(lum, 40)
        order = pre.ravel().argsort(kind="stable")
        rank = np.empty(order.size, np.float32)
        rank[order] = np.arange(order.size, dtype=np.float32) / (order.size - 1)
        out = (rank.reshape(pre.shape) * 255).astype(np.uint8)
        dst = os.path.join(SKY, name)
        Image.fromarray(out, "L").save(dst)
        print("->", dst, out.shape)


if __name__ == "__main__":
    for k in sys.argv[1:] or list(SETS) + ["cover"]:
        if k == "cover":
            build_cover()
        else:
            build(k)
