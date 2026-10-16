#!/usr/bin/env python3
"""Mouse cursors from Grok renders: the sprite pipeline (key out magenta, box-downsample,
palette snap) plus a one-pixel near-black outline so the pointer reads on any wall.

    python tools/artgen/cursor.py <id> <height_px> <dest relative to godot/>
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import process  # noqa: E402

OUTLINE = (14, 10, 8, 255)


def outline(img):
    w, h = img.size
    pad = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    pad.paste(img, (1, 1))
    src = pad.copy()
    sp = src.load()
    dp = pad.load()
    for y in range(h + 2):
        for x in range(w + 2):
            if sp[x, y][3] > 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w + 2 and 0 <= ny < h + 2 and sp[nx, ny][3] > 0:
                    dp[x, y] = OUTLINE
                    break
    return pad


def main():
    art_id, height, dest = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    src = os.path.join(process.HERE, "out", art_id, "raw.png")
    out = outline(process.sprite(src, height - 2))
    path = os.path.join(process.GODOT, dest)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out.save(path)
    print("%s -> %s %s" % (art_id, dest, out.size))


if __name__ == "__main__":
    main()
