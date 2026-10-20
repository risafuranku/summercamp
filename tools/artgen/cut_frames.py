#!/usr/bin/env python3
"""Cut a Grok row of animation frames into numbered sprites at one scale for all.

    python tools/artgen/cut_frames.py <id> <dest dir relative to godot/> <name> <count> <height of the first> [gap]

Like split_sheet.py (the same keying, the same items left to right), but the scale is
taken from the first frame: it comes out <height> pixels tall and every other frame by the
same factor (a sitting or stooping one lower, not stretched). Writes <name>_0.png ..
<name>_<count-1>.png and, for checking, tools/artgen/out/<id>/_cut.png.
Builder 98's map uses it for the little people (peeps/), the life (life/), the site and
the bulldozer (site/), the cursors (cursors/) and the news icons (news/).
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


def main():
	if len(sys.argv) < 6:
		print(__doc__)
		sys.exit(1)
	art_id, dest, name, count, first_h = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), int(sys.argv[5])
	gap = int(sys.argv[6]) if len(sys.argv) > 6 else 14
	img = process.key_out(to_magenta(Image.open(os.path.join(process.HERE, "out", art_id, "raw.png"))))
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
		out = split_sheet.shrink(split_sheet.own(img, b, labels[b], w), scale)
		out.save(os.path.join(out_dir, "%s_%d.png" % (name, i)))
		print("%s_%d %s" % (name, i, out.size))


if __name__ == "__main__":
	main()
