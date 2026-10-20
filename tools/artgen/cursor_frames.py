#!/usr/bin/env python3
"""Builder 98's moving tool cursors from Grok's row (bld_cursors_a/_b).

    python tools/artgen/cursor_frames.py <id>

The row is eleven pictures left to right: the bulldozer (3), the spade (3), the lamp (2),
the blueprint (3). The OS draws the tool beside the arrow in a square (os_shell.gd
tool_cursor), so every frame goes on a 24 px square, the tool as big as fits; each tool
has one scale for all its frames (from the biggest of them), so a frame does not jump.
Writes godot/assets/textury/builder/cursors/<tool>_<n>.png.
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import process  # noqa: E402
import split_sheet  # noqa: E402

TOOLS = [("dozer", 3), ("path", 3), ("lamp", 2), ("bp", 3)]
SIDE = 24
FIT = 23
GAP = 8


def main():
	if len(sys.argv) < 2:
		print(__doc__)
		sys.exit(1)
	art_id = sys.argv[1]
	img = process.key_out(Image.open(os.path.join(process.HERE, "out", art_id, "raw.png")))
	boxes, labels, w = split_sheet.items(img, GAP)
	want = sum(n for _t, n in TOOLS)
	if len(boxes) != want:
		print("found %d items, wanted %d" % (len(boxes), want))
		for b in boxes:
			print("  ", b)
		sys.exit(2)
	out_dir = os.path.join(process.GODOT, "assets", "textury", "builder", "cursors")
	os.makedirs(out_dir, exist_ok=True)
	i = 0
	for tool, n in TOOLS:
		group = boxes[i:i + n]
		big = max(max(b[2] - b[0], b[3] - b[1]) for b in group)
		scale = FIT / float(big)
		for k, b in enumerate(group):
			pic = split_sheet.shrink(split_sheet.own(img, b, labels[b], w), scale)
			sq = Image.new("RGBA", (SIDE, SIDE), (0, 0, 0, 0))
			# Centred across, standing on the square's floor.
			sq.alpha_composite(pic, ((SIDE - pic.width) // 2, SIDE - 1 - pic.height))
			sq.save(os.path.join(out_dir, "%s_%d.png" % (tool, k)))
			print("%s_%d %s" % (tool, k, pic.size))
		i += n


if __name__ == "__main__":
	main()
