#!/usr/bin/env python3
"""The cabins' door: door_wood.png's own boards in old green paint, worn back to the wood at the
foot and the edges, with door_interior.png's handle on it. The bare boards were the wall's
boards, the door could not be told from the wall (the user 7. 11.: "invisible door").

    python tools/artgen/cabin_door.py
"""
import os
import random

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CAMP = os.path.join(ROOT, "godot", "assets", "textury", "camp")

DARK = (38, 56, 46)
LIGHT = (126, 154, 118)


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def main():
    src = Image.open(os.path.join(CAMP, "door_wood.png")).convert("RGB")
    w, h = src.size
    lum = sorted(sum(src.getpixel((x, y))) / 3.0 for x in range(w) for y in range(h))
    lo, hi = lum[len(lum) // 50], lum[-len(lum) // 50]
    rnd = random.Random(7)
    out = Image.new("RGB", (w, h))
    for y in range(h):
        for x in range(w):
            p = src.getpixel((x, y))
            t = min(1.0, max(0.0, (sum(p) / 3.0 - lo) / (hi - lo)))
            c = lerp(DARK, LIGHT, t ** 0.85)
            # Worn back to the wood: at the foot and along the edges, in the boards' grain.
            edge = min(x, w - 1 - x) / 5.0
            foot = (y - h * 0.8) / (h * 0.2)
            wear = max(0.0, 1.0 - edge) * 0.34 + max(0.0, foot) * 0.5
            if rnd.random() < wear * (0.45 + t):
                c = lerp(p, (150, 128, 96), 0.3)
            out.putpixel((x, y), c)
    # The little plate up on it stays metal.
    for y in range(20, 31):
        for x in range(23, 41):
            p = src.getpixel((x, y))
            if max(p) - min(p) < 26 and sum(p) / 3.0 > 92:
                out.putpixel((x, y), lerp(p, (178, 176, 164), 0.5))
    # The handle.
    inner = Image.open(os.path.join(CAMP, "door_interior.png")).convert("RGB")
    box = (53, 49, 69, 78)
    handle = inner.crop(box)
    handle = handle.resize((int(handle.width * 0.89), int(handle.height * 0.89)), Image.NEAREST)
    ax, ay = w - handle.width - 3, 51
    for y in range(handle.height):
        for x in range(handle.width):
            p = handle.getpixel((x, y))
            # Only the grey metal, not the yellow leaf round it.
            if max(p) - min(p) < 34:
                out.putpixel((ax + x, ay + y), p)
    out.save(os.path.join(CAMP, "cabin_door.png"))
    print("cabin_door.png", out.size)


if __name__ == "__main__":
    main()
