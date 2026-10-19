#!/usr/bin/env python3
"""Frames of one animation at the same scale as its first picture.

    python tools/artgen/same_scale.py <base id> <base sprite height> <id> <dest> [<id> <dest> ...]

process.py sizes a sprite by its own height; the frames of a hand animation are drawn
at different heights (a hand raised, a fist), so each would come out a different size.
This takes the base render's scale (its keyed height -> <base sprite height>) and
processes every frame's render by that same scale, so the hand is the same size in all.
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import process  # noqa: E402


def keyed_height(art_id):
    img = process.key_out(Image.open(os.path.join(process.HERE, "out", art_id, "raw.png")))
    bb = img.getchannel("A").point(lambda a: 255 if a > 40 else 0).getbbox()
    return bb[3] - bb[1]


def main():
    base, base_h = sys.argv[1], int(sys.argv[2])
    scale = base_h / float(keyed_height(base))
    pairs = sys.argv[3:]
    for i in range(0, len(pairs), 2):
        art_id, dest = pairs[i], pairs[i + 1]
        h = max(1, round(keyed_height(art_id) * scale))
        out = process.sprite(os.path.join(process.HERE, "out", art_id, "raw.png"), h)
        path = os.path.join(process.GODOT, dest)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        out.save(path)
        print("%s -> %s %s" % (art_id, dest, out.size))


if __name__ == "__main__":
    main()
