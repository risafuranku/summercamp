#!/usr/bin/env python3
"""The granny's torn tent canvas (godot/materials/tent_tear.gdshader) from a Grok render
of the canvas round a tear whose opening is flat magenta (rows carnage_tear_* in
prompts_babka.tsv, the reference camp/tarp_canvas.png).

    python tools/artgen/tear.py <id> [width_px] [--dest=assets/textury/mess/carnage_tear.png]

The picture the room draws: the opening magenta (opaque; the shader shows the camp there),
the torn edge of the canvas round it (a band, its outer line ragged so it does not read
as a patch sewn on), nothing elsewhere (the tent's own wall shows there). The band's
canvas is shifted to the colour of the back wall as the tent draws it
(camp/tarp_canvas.png times the wall's tint in tent_interior); blood, mould and
mushrooms keep most of their own colours. A magenta pocket touching the
picture's border is not the opening (a corner of background): nothing there.
"""
import os
import random
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from process import GODOT, is_key, snap  # noqa: E402

# The torn edge kept round the opening (texels), and how far out blood and the like still
# count as part of it.
BAND = 12
FAR = 22
# tent_interior: the back wall is tarp_canvas tinted Color(0.60, 0.50, 0.42) lerped 0.45
# to white.
WALL_TINT = np.array([0.6, 0.5, 0.42]) * 0.55 + 0.45
# The inside of the canvas where it tore (what the hole's own pixels blend toward).
RIM = (38, 30, 26)


def grow(mask, steps):
    """Distance (in steps of the eight neighbours) from `mask`, up to `steps`."""
    h, w = mask.shape
    dist = np.full((h, w), steps + 1, dtype=np.int32)
    cur = mask.copy()
    dist[cur] = 0
    for d in range(1, steps + 1):
        p = np.pad(cur, 1)
        nxt = np.zeros_like(cur)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                nxt |= p[1 + dy:1 + dy + h, 1 + dx:1 + dx + w]
        new = nxt & ~cur
        dist[new] = d
        cur = nxt
    return dist


def border_pockets(hole):
    """The magenta pockets that touch the picture's border."""
    h, w = hole.shape
    seen = np.zeros_like(hole)
    stack = [(y, x) for y in range(h) for x in (0, w - 1) if hole[y, x]]
    stack += [(y, x) for x in range(w) for y in (0, h - 1) if hole[y, x]]
    while stack:
        y, x = stack.pop()
        if seen[y, x] or not hole[y, x]:
            continue
        seen[y, x] = True
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            yy, xx = y + dy, x + dx
            if 0 <= yy < h and 0 <= xx < w and not seen[yy, xx]:
                stack.append((yy, xx))
    return seen


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    tid = args[0]
    width = int(args[1]) if len(args) > 1 else 88
    dest = os.path.join(GODOT, opts.get("dest", "assets/textury/mess/carnage_tear.png"))
    raw = Image.open(os.path.join(HERE, "out", tid, "raw.png")).convert("RGB")
    a = np.asarray(raw).copy()
    hole_full = np.zeros(a.shape[:2], dtype=bool)
    for y in range(a.shape[0]):
        for x in range(a.shape[1]):
            r, g, b = a[y, x]
            hole_full[y, x] = is_key(int(r), int(g), int(b))
    hole_full &= ~border_pockets(hole_full)
    # The opening's own pixels take the torn rim's colour before the picture is scaled, so
    # the edge pixels round it darken instead of turning pink.
    a[hole_full] = RIM
    height = round(width * raw.height / raw.width)
    small = Image.fromarray(a).resize((width, height), Image.BOX)
    small = snap(small, False)
    hole = np.asarray(Image.fromarray((hole_full * 255).astype(np.uint8)).resize((width, height), Image.BOX)) >= 128
    rgb = np.asarray(small).astype(np.float64)
    dist = grow(hole, FAR)
    # A ragged outer line: the band's reach wavers by a few texels along it.
    rnd = random.Random(tid)
    coarse = np.array([[rnd.uniform(-3.0, 3.0) for _ in range(width // 6 + 2)] for _ in range(height // 6 + 2)])
    jitter = np.asarray(Image.fromarray(coarse.astype(np.float32)).resize((width, height), Image.BILINEAR))
    reach = BAND + jitter
    # What is canvas in it (near the colour of the whole cloth at the picture's border, the
    # canvas fills it edge to edge) and what is not (blood, the mould, the mushrooms, the
    # dark of the rim).
    edge = np.zeros(hole.shape, dtype=bool)
    edge[:4, :] = edge[-4:, :] = edge[:, :4] = edge[:, -4:] = True
    edge &= ~hole
    mid = np.median(rgb[edge], axis=0)
    cloth = np.linalg.norm(rgb - mid, axis=2) < 60.0
    keep = (dist > 0) & ((dist <= reach) | (~cloth & (dist <= FAR)))
    tarp = np.asarray(Image.open(os.path.join(GODOT, "assets", "textury", "camp", "tarp_canvas.png")).convert("RGB")).reshape(-1, 3).mean(axis=0)
    target = tarp * WALL_TINT
    # The whole cloth shifted (its detail is a difference, kept), the rest a little.
    w = np.where(cloth, 1.0, 0.3)[..., None]
    rgb = np.clip(rgb + (target - mid) * w, 0, 255)
    out = np.zeros((height, width, 4), dtype=np.uint8)
    out[keep, :3] = rgb[keep].astype(np.uint8)
    out[keep, 3] = 255
    out[hole] = (255, 0, 255, 255)
    img = snap(Image.fromarray(out, "RGBA"), True)
    px = np.asarray(img).copy()
    px[hole] = (255, 0, 255, 255)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    Image.fromarray(px, "RGBA").save(dest)
    print("%s -> %s (%dx%d, opening %d texels, edge %d)" % (tid, dest, width, height, int(hole.sum()), int(keep.sum())))


if __name__ == "__main__":
    main()
