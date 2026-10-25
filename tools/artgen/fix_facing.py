#!/usr/bin/env python3
"""Turn round the frames of a packed figure set that face the wrong way.

Views 1-3 of godot/assets/textury/npc/sets/<fig>.png are drawn turned to the right of the
picture (scripts/figures/doom_figure.gd: views 5-7 are those mirrored). A Grok sheet that
came out facing left makes the person walk or run backwards from those sides (playtest
25. 10.: "I saw the quiet guy running backwards"). The sources are not always kept, so
this mends the packed atlas itself: each frame's rectangle mirrored in place, its anchor
(the feet under the torso) with it, the jacket mask too where there is one.

    python tools/artgen/fix_facing.py <fig> <anim>:<view>[:<frame>] ...
    python tools/artgen/fix_facing.py host1 stand:1 stand:2 run:1 run:2

View numbers are the json's (0 front .. 4 back); without a frame every frame of it.
Run it once per mistake: a second run turns them back.
"""
import json
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SETS = os.path.join(HERE, "..", "..", "godot", "assets", "textury", "npc", "sets")


def main():
	if len(sys.argv) < 3:
		print(__doc__)
		sys.exit(1)
	fig = sys.argv[1]
	base = os.path.join(SETS, fig)
	data = json.load(open(base + ".json", encoding="utf-8"))
	atlas = Image.open(base + ".png").convert("RGBA")
	mask_path = base + "_mask.png"
	mask = Image.open(mask_path).convert("RGBA") if os.path.exists(mask_path) else None
	rects = set()
	for spec in sys.argv[2:]:
		parts = spec.split(":")
		anim, view = parts[0], int(parts[1])
		frames = data["anims"][anim][view]
		picks = [int(parts[2])] if len(parts) > 2 else range(len(frames))
		for n in picks:
			f = frames[n]
			rects.add((int(f[0]), int(f[1]), int(f[2]), int(f[3])))
			print("%s %s view %d frame %d turned round" % (fig, anim, view, n))
	for x, y, w, h in rects:
		for img in [atlas] + ([mask] if mask is not None else []):
			region = img.crop((x, y, x + w, y + h)).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
			img.paste(region, (x, y))
	# The anchor of every frame on a turned rectangle (a picture two views share, too).
	for views in data["anims"].values():
		for frames in views:
			for f in frames:
				if (int(f[0]), int(f[1]), int(f[2]), int(f[3])) in rects:
					f[4] = round(float(f[2]) - float(f[4]), 2)
	atlas.save(base + ".png")
	if mask is not None:
		mask.save(mask_path)
	with open(base + ".json", "w", encoding="utf-8") as fh:
		json.dump(data, fh, separators=(",", ":"))


if __name__ == "__main__":
	main()
