#!/usr/bin/env python3
"""The Photographer's poses brought to life (scripts/enemies/tourist_brain.gd ANIM): a few
frames each, cut and moved from the pose's own sprite, so it stays him pixel for pixel.

    python tools/artgen/photographer_frames.py [--preview OUT.png]

Writes godot/assets/textury/npc/ph_anim/<pose>_<n>.png (the pose's canvas; frame 0 is the
pose as it is):
  breathe   the upper body sinks a pixel and rises (idle, back, the glass)
  tremble   head, camera and hands shake by a pixel (aim)
  wave      the raised hand rocks on the elbow (wave)
  flash     the glare swells, holds, dies (flash)
  stride    the legs mirrored, the other step (run)
  sway      the broken neck rocks the head on it; the last frame a spasm (neck)
  swing     the head hanging at his belly swings on the limp neck; the last a spasm (neck2)
"""
import math
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
NPC = os.path.join(HERE, "..", "..", "godot", "assets", "textury", "npc")
OUT = os.path.join(NPC, "ph_anim")


def load(name):
    return Image.open(os.path.join(NPC, name + ".png")).convert("RGBA")


def opaque(img, box, inside=None):
    """The opaque pixels in `box` (x0, y0, x1, y1; x1/y1 exclusive), and in the polygon
    `inside` if given."""
    w, h = img.size
    px = img.load()
    out = set()
    for y in range(max(0, box[1]), min(h, box[3])):
        for x in range(max(0, box[0]), min(w, box[2])):
            if px[x, y][3] > 0 and (inside is None or in_poly(x + 0.5, y + 0.5, inside)):
                out.add((x, y))
    return out


def in_poly(x, y, poly):
    hit = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            hit = not hit
        j = i
    return hit


def nearest_outside(src, mask, x, y, w):
    """What was behind the part at (x, y): the row beyond the part's nearer edge, mirrored
    back across it (the shirt's own weave goes on, no streak of one pixel); the nearest
    pixel beside it where the mirror finds nothing."""
    xl = x
    while xl >= 0 and (xl, y) in mask:
        xl -= 1
    xr = x
    while xr < w and (xr, y) in mask:
        xr += 1
    for edge, sign in sorted(((xl, -1), (xr, 1)), key=lambda e: abs(e[0] - x)):
        if not (0 <= edge < w):
            continue
        m = edge + sign * (abs(x - edge) - 1)
        if 0 <= m < w and (m, y) not in mask and src[m, y][3] > 0:
            return src[m, y]
        if src[edge, y][3] > 0:
            return src[edge, y]
    return (0, 0, 0, 0)


def move(img, mask, inv, fill="clear", keep_near=None, margin=10):
    """`mask` moved: each pixel of the result takes the mask pixel `inv(x, y)` points back
    to (pixel centres). Where the part was and is no more: see-through ("clear") or the
    row's nearest pixel beside it ("smear"); `keep_near` (x, y, r) leaves the part where
    it was round a pivot (no seam where a neck turns on it)."""
    if not mask:
        return img.copy()
    w, h = img.size
    src = img.load()
    out = img.copy()
    dst = out.load()
    for (x, y) in mask:
        if keep_near and (x - keep_near[0]) ** 2 + (y - keep_near[1]) ** 2 <= keep_near[2] ** 2:
            continue
        dst[x, y] = (0, 0, 0, 0) if fill == "clear" else nearest_outside(src, mask, x, y, w)
    xs = [p[0] for p in mask]
    ys = [p[1] for p in mask]
    for y in range(max(0, min(ys) - margin), min(h, max(ys) + margin + 1)):
        for x in range(max(0, min(xs) - margin), min(w, max(xs) + margin + 1)):
            sx, sy = inv(x + 0.5, y + 0.5)
            s = (int(math.floor(sx)), int(math.floor(sy)))
            if s in mask:
                dst[x, y] = src[s]
    return out


def shift(dx, dy):
    return lambda x, y: (x - dx, y - dy)


def rotate(px, py, deg, dx=0.0, dy=0.0):
    a = math.radians(-deg)
    c, s = math.cos(a), math.sin(a)

    def inv(x, y):
        x -= dx
        y -= dy
        return (px + (x - px) * c - (y - py) * s, py + (x - px) * s + (y - py) * c)
    return inv


def breathe(img, waist):
    upper = opaque(img, (0, 0, img.width, waist))
    return [img.copy(), move(img, upper, shift(0, 1), "clear")]


def tremble(img, box):
    part = opaque(img, box)
    return [img.copy()] + [move(img, part, shift(dx, dy), "smear") for dx, dy in ((1, 0), (0, 1), (-1, 0))]


def wave(img, box, pivot, angles):
    part = opaque(img, box)
    return [move(img, part, rotate(pivot[0], pivot[1], a), "clear") if a else img.copy() for a in angles]


def flash(img, centre, radius):
    w, h = img.size
    px = img.load()
    glare = set()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a and (x - centre[0]) ** 2 + (y - centre[1]) ** 2 <= radius ** 2 and (r + g + b) / 3 > 170:
                glare.add((x, y))
    k = 1.35
    big = move(img, glare, lambda x, y: (centre[0] + (x - centre[0]) / k, centre[1] + (y - centre[1]) / k), "smear")
    dim = img.copy()
    d = dim.load()
    for (x, y) in glare:
        r, g, b, a = px[x, y]
        d[x, y] = (int(r * 0.62), int(g * 0.6), int(b * 0.55), a)
    return [img.copy(), big, dim]


def stride(img, from_y):
    w, h = img.size
    legs = img.crop((0, from_y, w, h)).transpose(Image.FLIP_LEFT_RIGHT)
    out = img.copy()
    out.paste((0, 0, 0, 0), (0, from_y, w, h))
    out.alpha_composite(legs, (0, from_y))
    return [img.copy(), out]


def pad(img, side):
    """The same picture `side` pixels wider each way (room for a head swinging out)."""
    out = Image.new("RGBA", (img.width + side * 2, img.height), (0, 0, 0, 0))
    out.alpha_composite(img, (side, 0))
    return out


def sway(img, pivot, top_box, angles, spasm, side=8):
    img = pad(img, side)
    px, py = pivot[0] + side, pivot[1]
    part = opaque(img, (top_box[0] + side, top_box[1], top_box[2] + side, top_box[3]))
    frames = [move(img, part, rotate(px, py, a), "clear", (px, py, 5)) if a else img.copy() for a in angles]
    frames.append(move(img, part, rotate(px, py, spasm[0], spasm[1], spasm[2]), "clear", (px, py, 5)))
    return frames


def swing(img, poly, y0, y1, amps, spasm):
    xs = [p[0] for p in poly]
    ys = [p[1] for p in poly]
    part = opaque(img, (min(xs), min(ys), max(xs) + 1, max(ys) + 1), poly)

    def bend(a, lift=0.0):
        # The limp neck bends from where it leaves the hands: nothing at y0, all of it
        # from y1 down (the head, the cap swinging past it).
        return lambda x, y: (x - a * min(1.25, max(0.0, (y - y0) / (y1 - y0))), y + lift)
    frames = [move(img, part, bend(a), "smear") if a else img.copy() for a in amps]
    frames.append(move(img, part, bend(spasm[0], spasm[1]), "smear"))
    return frames


# The neck2 head, neck, photos and cap as they hang (the shirt and shorts round them stay).
NECK2_HEAD = [(30, 38), (41, 38), (42, 44), (47, 46), (48, 60), (47, 66), (50, 68), (56, 72), (58, 80), (57, 92),
              (44, 92), (42, 80), (45, 77), (40, 78), (27, 78), (23, 70), (23, 60), (26, 48), (30, 44)]


def make():
    os.makedirs(OUT, exist_ok=True)
    out = {
        "idle": breathe(load("tourist_idle"), 62),
        "back": breathe(load("tourist_back"), 60),
        "glass": breathe(load("tourist_glass"), 45),
        "aim": tremble(load("tourist_aim"), (12, 0, 56, 40)),
        "wave": wave(load("tourist_wave"), (0, 8, 17, 42), (10, 42), [0, -6, -11, -6, 0, 6]),
        "flash": flash(load("tourist_flash"), (30, 24), 13),
        "run": stride(load("ph_run"), 96),
        "neck": sway(load("ph_neck"), (33, 46), (18, 0, 70, 46), [0, -2, -4, -5, -4, -2, 0, 2, 3, 2], (7, 1, -1)),
        "neck2": swing(load("ph_neck2"), NECK2_HEAD, 40, 66, [0, 1.5, 3, 3.5, 3, 1.5, 0, -1.5, -3, -3.5, -3, -1.5], (5, -2)),
    }
    for pose, frames in out.items():
        for old in os.listdir(OUT):
            if old.startswith(pose + "_") and old.endswith(".png") and old[len(pose) + 1:-4].isdigit():
                os.remove(os.path.join(OUT, old))
        for i, f in enumerate(frames):
            f.save(os.path.join(OUT, "%s_%d.png" % (pose, i)))
        print("%s: %d frames" % (pose, len(frames)))
    return out


def preview(out, path, s=3):
    rows = []
    for pose, frames in out.items():
        w, h = frames[0].size
        row = Image.new("RGBA", ((w * s + 6) * len(frames), h * s), (40, 40, 60, 255))
        for i, f in enumerate(frames):
            big = f.resize((w * s, h * s), Image.NEAREST)
            row.alpha_composite(big, (i * (w * s + 6), 0))
        rows.append(row)
    W = max(r.width for r in rows)
    H = sum(r.height + 6 for r in rows)
    sheet = Image.new("RGBA", (W, H), (20, 20, 30, 255))
    y = 0
    for r in rows:
        sheet.alpha_composite(r, (0, y))
        y += r.height + 6
    sheet.save(path)


if __name__ == "__main__":
    frames = make()
    if "--preview" in sys.argv:
        preview(frames, sys.argv[sys.argv.index("--preview") + 1])
