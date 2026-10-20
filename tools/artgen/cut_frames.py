#!/usr/bin/env python3
"""Cut a Grok row of animation frames into numbered sprites at one scale for all.

    python tools/artgen/cut_frames.py <id> <dest dir relative to godot/> <name> <count> <height of the first> [gap|cols]

Like split_sheet.py (the same keying, the same items left to right), but the scale is
taken from the first frame: it comes out <height> pixels tall and every other frame by the
same factor (a sitting or stooping one lower, not stretched). Writes <name>_0.png ..
<name>_<count-1>.png and, for checking, tools/artgen/out/<id>/_cut.png.
Builder 98's map uses it for the little people (peeps/), the life (life/), the site and
the bulldozer (site/), the cursors (cursors/) and the news icons (news/).
"cols" for a row whose frames are not one blob each (a flock of three birds, spread as far
apart as the flocks): the drawing's width in <count> equal columns, each trimmed.
"""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import process  # noqa: E402
import split_sheet  # noqa: E402


def to_magenta(img, near=90):
	"""Grok's background is not always pure magenta (bld_dozer_a came on #E8008A, which
	key_out leaves as a pink rim): what is near the corner's colour becomes #FF00FF first."""
	img = img.convert("RGBA")
	px = img.load()
	br, bg, bb, _a = px[0, 0]
	if (br, bg, bb) == (255, 0, 255):
		return img
	for y in range(img.height):
		for x in range(img.width):
			r, g, b, a = px[x, y]
			d = abs(r - br) + abs(g - bg) + abs(b - bb)
			if d < near:
				px[x, y] = (255, 0, 255, a)
			elif d < near * 2 and r > g + 60 and b > g + 30:
				# The rim between the pink and the outline: pulled to the dark it borders.
				px[x, y] = (int(g * 0.9), g, int(g * 0.9), a)
	return img


def columns(img, count):
	"""The drawing's box cut in `count` equal columns, each trimmed to what is in it."""
	a = img.getchannel("A").point(lambda v: 255 if v > 40 else 0)
	x0, y0, x1, y1 = a.getbbox()
	step = (x1 - x0) / float(count)
	boxes = []
	for i in range(count):
		c = (int(round(x0 + i * step)), y0, int(round(x0 + (i + 1) * step)), y1)
		t = a.crop(c).getbbox()
		boxes.append((c[0] + t[0], c[1] + t[1], c[0] + t[2], c[1] + t[3]))
	return boxes


def main():
	if len(sys.argv) < 6:
		print(__doc__)
		sys.exit(1)
	art_id, dest, name, count, first_h = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), int(sys.argv[5])
	cols = len(sys.argv) > 6 and sys.argv[6] == "cols"
	gap = int(sys.argv[6]) if len(sys.argv) > 6 and not cols else 14
	img = process.key_out(to_magenta(Image.open(os.path.join(process.HERE, "out", art_id, "raw.png"))))
	if cols:
		boxes = columns(img, count)
		labels, w = None, None
	else:
		boxes, labels, w = split_sheet.items(img, gap)
	check = img.copy()
	d = ImageDraw.Draw(check)
	for i, b in enumerate(boxes):
		d.rectangle(b, outline=(0, 255, 0, 255))
		d.text((b[0], max(0, b[1] - 12)), str(i), fill=(0, 255, 0, 255))
	check.save(os.path.join(process.HERE, "out", art_id, "_cut.png"))
	if len(boxes) != count:
		print("found %d items, wanted %d: see tools/artgen/out/%s/_cut.png" % (len(boxes), count, art_id))
		for b in boxes:
			print("  ", b)
		sys.exit(2)
	scale = first_h / float(boxes[0][3] - boxes[0][1])
	out_dir = os.path.join(process.GODOT, dest)
	os.makedirs(out_dir, exist_ok=True)
	for i, b in enumerate(boxes):
		pic = img.crop(b) if cols else split_sheet.own(img, b, labels[b], w)
		out = split_sheet.shrink(pic, scale)
		out.save(os.path.join(out_dir, "%s_%d.png" % (name, i)))
		print("%s_%d %s" % (name, i, out.size))


if __name__ == "__main__":
	main()
