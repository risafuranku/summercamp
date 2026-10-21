#!/usr/bin/env python3
"""The second monitor's delivery (godot/scripts/reception/post_delivery.gd): Grok renders
into the game. Rows in tools/artgen/prompts_post.tsv.

    python tools/artgen/post_art.py [id ...]

- post_van_side: the side of the Czech post's van. Grok puts it on a plain grey ground
  with a shadow; the ground is flooded away from the picture's edges (a low-saturation
  colour close to the edge's), the van cropped and shrunk to the faces' pixels
  (-> textury/post/van_*.png, keyed, on the palette).
- npc_postman: the man, 128 px to 1.74 m like every person (then defringe.py --figure).
- cu_post_sign, cu_post_parcel: the close-ups, 320x240.
- web_monitor2: PC Servis's photo, a JPEG of 1998 (web_image.py).
- tex_phonebooks: the phone books under the second monitor.
"""
import os
import subprocess
import sys
from collections import deque

from PIL import Image

import process

HERE = os.path.dirname(os.path.abspath(__file__))
TEX = os.path.join(HERE, "..", "..", "godot", "assets", "textury")


def raw(art_id):
    return os.path.join(HERE, "out", art_id, "raw.png")


def flood_ground(img, tol=40, floor_y=None, wheels=()):
    """The plain ground round a vehicle made see-through: flooded from the picture's
    edges through what is near the ground's own colour on that row (the left and right
    edge pixels of the row; the ground gets darker toward the bottom). The muddy blue
    band and the dusty side are near it in colour too, so nothing is chained from pixel
    to pixel. Below `floor_y` (the body's underside, in the render's pixels) everything
    but the wheel circles (x, y, r) goes: the shadow under the van is no part of it."""
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    rows = []
    for y in range(h):
        l, r = px[2, y], px[w - 3, y]
        rows.append(((l[0] + r[0]) / 2, (l[1] + r[1]) / 2, (l[2] + r[2]) / 2))

    def ground(x, y):
        r, g, b, a = px[x, y]
        m = rows[y]
        return abs(r - m[0]) + abs(g - m[1]) + abs(b - m[2]) <= tol

    seen = bytearray(w * h)
    q = deque([(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)])
    while q:
        x, y = q.popleft()
        i = y * w + x
        if seen[i] or not ground(x, y):
            continue
        seen[i] = 1
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx]:
                q.append((nx, ny))
    for y in range(h):
        for x in range(w):
            gone = seen[y * w + x]
            if floor_y is not None and y > floor_y:
                gone = not any((x - cx) ** 2 + (y - cy) ** 2 <= cr * cr for cx, cy, cr in wheels)
            if gone:
                px[x, y] = (0, 0, 0, 0)
    return img


## Where the side render's body ends and its wheels are (measured on the render).
SIDE_FLOOR = 590
SIDE_WHEELS = ((183, 583, 104), (1012, 583, 104))


def vehicle_face(art_id, width, dest, floor_y=None, wheels=()):
    img = flood_ground(Image.open(raw(art_id)), floor_y=floor_y, wheels=wheels)
    bbox = img.getchannel("A").point(lambda a: 255 if a > 40 else 0).getbbox()
    img = img.crop(bbox)
    h = max(1, round(img.height * width / img.width))
    small = img.resize((width, h), Image.Resampling.BOX)
    out = process.snap(small, True)
    path = os.path.join(TEX, dest)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out.save(path)
    print(art_id, "->", dest, out.size)


def close(art_id, dest):
    src = Image.open(raw(art_id)).convert("RGB")
    if src.width * 3 > src.height * 4:
        src = src.crop(((src.width - src.height * 4 // 3) // 2, 0, (src.width + src.height * 4 // 3) // 2, src.height))
    out = process.snap(src.resize((320, 240), Image.Resampling.BOX), False)
    path = os.path.join(TEX, dest)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out.save(path)
    print(art_id, "->", dest, out.size)


def main():
    want = sys.argv[1:]
    def go(i):
        return (not want or i in want) and os.path.exists(raw(i))
    if go("post_van_side"):
        vehicle_face("post_van_side", 224, "post/van_side.png", SIDE_FLOOR, SIDE_WHEELS)
    # The front and the back fill their canvas edge to edge: nothing to key.
    for i in ("post_van_front", "post_van_back"):
        if go(i):
            out = process.panel(raw(i), 96)
            out.save(os.path.join(TEX, "post", i.replace("post_", "") + ".png"))
            print(i, "->", out.size)
    if go("npc_postman"):
        out = process.sprite(raw("npc_postman"), 128)
        dest = os.path.join(TEX, "npc", "npc_postman.png")
        out.save(dest)
        subprocess.run([sys.executable, os.path.join(HERE, "defringe.py"), "--figure", dest], check=False)
        print("npc_postman ->", dest, out.size)
    if go("cu_post_sign"):
        close("cu_post_sign", "closeup/post_sign.png")
    if go("cu_post_parcel"):
        close("cu_post_parcel", "closeup/post_parcel.png")
    if go("web_monitor2"):
        subprocess.run([sys.executable, os.path.join(HERE, "web_image.py"), "web_monitor2", "photo", "256"], check=True)
    if go("tex_phonebooks"):
        out = process.panel(raw("tex_phonebooks"), 64)
        out.save(os.path.join(TEX, "camp", "phonebooks.png"))
        print("tex_phonebooks ->", out.size)


if __name__ == "__main__":
    main()
