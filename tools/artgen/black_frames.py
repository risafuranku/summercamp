#!/usr/bin/env python3
"""Frames of one animation on a near-black background, brought in with ONE framing.

    python tools/artgen/black_frames.py <body_px> <dest_dir> <name>=<src> [<name>=<src> ...]

Each source (relative to godot/) is keyed like process.py `blacksprite` (flood fill of the
near-black from the borders, the generator's sparkle mark in the bottom-right corner
erased), then ALL frames are cropped to the union of their figures and scaled by the same
factor, so they stand on the same spot and do not jump when played one after another.
The factor makes the FIRST frame's figure <body_px> tall. Written to <dest_dir>/<name>.png
(relative to godot/), snapped to the game palette.
"""

import os
import sys
from collections import deque

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import process  # noqa: E402

GODOT = process.GODOT


def key_black(img):
	img = img.convert("RGBA")
	w, h = img.size
	px = img.load()
	for y in range(int(h * 0.9), h):
		for x in range(int(w * 0.9), w):
			px[x, y] = (5, 4, 4, 255)
	seen = bytearray(w * h)
	q = deque([(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)])
	while q:
		x, y = q.popleft()
		i = y * w + x
		if seen[i]:
			continue
		seen[i] = 1
		r, g, b, a = px[x, y]
		if max(r, g, b) >= 26:
			continue
		px[x, y] = (0, 0, 0, 0)
		if x > 0:
			q.append((x - 1, y))
		if x < w - 1:
			q.append((x + 1, y))
		if y > 0:
			q.append((x, y - 1))
		if y < h - 1:
			q.append((x, y + 1))
	return img


def main():
	body_px = int(sys.argv[1])
	dest = sys.argv[2]
	pairs = [a.split("=", 1) for a in sys.argv[3:]]
	frames = [(n, key_black(Image.open(os.path.join(GODOT, s)))) for n, s in pairs]
	boxes = [f.getchannel("A").point(lambda a: 255 if a > 40 else 0).getbbox() for _, f in frames]
	union = (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))
	k = body_px / float(boxes[0][3] - boxes[0][1])
	size = (max(1, round((union[2] - union[0]) * k)), max(1, round((union[3] - union[1]) * k)))
	os.makedirs(os.path.join(GODOT, dest), exist_ok=True)
	for n, f in frames:
		small = f.crop(union).resize(size, Image.Resampling.BOX)
		out = process.snap(small, True)
		path = os.path.join(GODOT, dest, n + ".png")
		out.save(path)
		print(n, "->", os.path.relpath(path, GODOT), out.size)


if __name__ == "__main__":
	main()
