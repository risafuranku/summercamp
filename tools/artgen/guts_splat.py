"""The raccoon thing's guts on a pipe's wall and floor: the camp's carnage blood
(mess/carnage_blood.png, Grok) without the granny's mushrooms in it, a little darker.

The pipes used the hanging column of blood (rac/rac_hblood.png) as their splat and
trail, so its pole and heap stood about the pipes at every angle (22. 11.).

    python tools/artgen/guts_splat.py
writes godot/assets/textury/pipes/rac/rac_splat.png
"""
import os
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "godot", "assets", "textury")
SRC = os.path.join(ROOT, "mess", "carnage_blood.png")
DST = os.path.join(ROOT, "pipes", "rac", "rac_splat.png")


def is_pale(p):
	r, g, b, a = p
	# The mushrooms: cream and grey caps (blood is red over green and blue by far).
	return a > 0 and (min(r, g, b) > 110 or (r - g < 40 and r > 90))


def main():
	im = Image.open(SRC).convert("RGBA")
	w, h = im.size
	px = im.load()
	todo = {(x, y) for y in range(h) for x in range(w) if is_pale(px[x, y])}
	# Filled from the blood round them, ring by ring.
	while todo:
		done = {}
		for (x, y) in todo:
			acc = [0, 0, 0]
			n = 0
			for dx in (-1, 0, 1):
				for dy in (-1, 0, 1):
					q = (x + dx, y + dy)
					if q in todo or not (0 <= q[0] < w and 0 <= q[1] < h):
						continue
					r, g, b, a = px[q]
					if a == 0:
						continue
					acc[0] += r
					acc[1] += g
					acc[2] += b
					n += 1
			if n >= 2:
				done[(x, y)] = (acc[0] // n, acc[1] // n, acc[2] // n, 255)
		if not done:
			break
		for q, c in done.items():
			px[q] = c
			todo.discard(q)
	# Older than the granny's work: darker, nearer brown.
	for y in range(h):
		for x in range(w):
			r, g, b, a = px[x, y]
			if a:
				px[x, y] = (int(r * 0.78), int(g * 0.72), int(b * 0.72), a)
	im.save(DST)
	print(DST, im.size)


if __name__ == "__main__":
	main()
