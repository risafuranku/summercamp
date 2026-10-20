#!/usr/bin/env python3
"""The map's tree in the wind: four frames from its own picture (builder/strom.png).

    python tools/artgen/tree_sway.py

Grok's row (bld_tree_a) came back three times upright and once with the tip bent over
like a gnome's cap, so the frames are the tree itself leaned: every row of the crown moved
sideways by whole pixels, more the higher it is, the trunk where it stands (no new
drawing, the same pixels). The map's order (crt_map_panel, "tree_sway_<n>"): 0 leaning a
little left, 1 upright, 2 leaning a little right, 3 upright with the top bent.
Writes godot/assets/textury/builder/life/tree_<0-3>.png.
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import process  # noqa: E402

SRC = os.path.join(process.GODOT, "assets", "textury", "builder", "strom.png")
DEST = os.path.join(process.GODOT, "assets", "textury", "builder", "life")
# How far the tip goes, in the picture's pixels (256 px; the map draws it about a third).
LEAN = 10
BEND = 9


def trunk_top(img):
	"""The lowest row of the crown: the widest row of the picture's top part, going down
	until the rows narrow to the trunk."""
	a = img.getchannel("A")
	box = a.getbbox()
	widths = []
	for y in range(box[1], box[3]):
		row = a.crop((0, y, img.width, y + 1)).getbbox()
		widths.append((y, (row[2] - row[0]) if row else 0))
	widest = max(w for _y, w in widths)
	last = box[1]
	for y, w in widths:
		if w >= widest * 0.55:
			last = y
	return box[1], last


def lean(img, top, bottom, shift_at):
	out = Image.new("RGBA", img.size, (0, 0, 0, 0))
	for y in range(img.height):
		row = img.crop((0, y, img.width, y + 1))
		k = 0.0 if y >= bottom else (bottom - y) / float(max(1, bottom - top))
		out.paste(row, (int(round(shift_at(k))), y))
	return out


def main():
	img = Image.open(SRC).convert("RGBA")
	top, bottom = trunk_top(img)
	os.makedirs(DEST, exist_ok=True)
	frames = [
		lean(img, top, bottom, lambda k: -LEAN * k),
		img,
		lean(img, top, bottom, lambda k: LEAN * k),
		lean(img, top, bottom, lambda k: BEND * max(0.0, (k - 0.6) / 0.4) ** 2),
	]
	for i, f in enumerate(frames):
		f.save(os.path.join(DEST, "tree_%d.png" % i))
		print("tree_%d %s" % (i, f.getchannel("A").getbbox()))


if __name__ == "__main__":
	main()
