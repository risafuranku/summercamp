#!/usr/bin/env python3
"""People seen from eight sides, as in Doom (DESIGN.md "People as in Doom"): Grok sheets
(rows from figure_prompts.py) into the frames and the atlas the game draws
(scripts/figures/doom_figure.gd).

    python tools/artgen/figures.py ref <fig> front            the sprite x4 on magenta (Grok's reference)
    python tools/artgen/figures.py ref <fig> turn <id>        the sprite beside the picked turnaround
    python tools/artgen/figures.py stage <fig>                every sheet picked in figure_picks.json -> frames
    python tools/artgen/figures.py check <fig>                the automatic checks on the staged frames
    python tools/artgen/figures.py sheet <fig>                contact sheet + one GIF per view (out/fig_<fig>/)
    python tools/artgen/figures.py pack <fig>                 frames -> godot/assets/textury/npc/sets/<fig>.png/.json(+_mask)
    python tools/artgen/figures.py all <fig>                  stage, check, sheet, pack
    python tools/artgen/figures.py batch <fig> <key>...       Grok the sheets (turn, walk1..5, run1..5, idle1, pose_<p>)
    python tools/artgen/figures.py autopick <fig>             the first good variant of each sheet into figure_picks.json

A sheet is cut into its figures left to right (split_sheet's blobs); every figure of a
sheet is scaled by one factor (the turnaround: its front figure to the sprite's height;
an animation: its tallest frame to the sprite's height times HEIGHT_K), box-downsampled
with premultiplied alpha, hard alpha, and snapped to the colours of the person's sprite
from the front (so no colour can drift). Its anchor is where it stands: x the middle of
the torso (the band TORSO of its height; legs swinging do not move it), y its feet (an
animation's common baseline for the run, whose frames leave the ground).
The view drawn first (1) of the standing turnaround is never used: the sprite itself is.
"""
import json
import os
import sys

from PIL import Image, ImageChops, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import process  # noqa: E402
import split_sheet  # noqa: E402
import figure_prompts  # noqa: E402

GODOT = process.GODOT
OUT = os.path.join(HERE, "out")
REFS = os.path.join(OUT, "fig_refs")
PICKS = os.path.join(HERE, "figure_picks.json")
SETS = os.path.join(GODOT, "assets", "textury", "npc", "sets")
MAGENTA = (255, 0, 255, 255)
## An animation's tallest frame against the standing sprite (a stride is lower than standing).
HEIGHT_K = {"walk": 0.985, "run": 0.95, "idle": 1.0}
## The torso, from the top of the figure (shares of its height): its middle is the anchor.
TORSO = (0.16, 0.5)
## A run frame may leave the ground by this share of the height at most.
MAX_LIFT = 0.05


# ── references for Grok ──────────────────────────────────────────────────────

def sprite_path(fig):
	return os.path.join(GODOT, figure_prompts.FIGURES[fig][0])


def sprite_of(fig):
	return Image.open(sprite_path(fig)).convert("RGBA")


def on_magenta(img, pad):
	bg = Image.new("RGBA", (img.width + pad * 2, img.height + pad * 2), MAGENTA)
	bg.alpha_composite(img, (pad, pad))
	return bg


def ref_front(fig):
	s = sprite_of(fig)
	big = s.resize((s.width * 4, s.height * 4), Image.Resampling.NEAREST)
	os.makedirs(REFS, exist_ok=True)
	on_magenta(big, 48).convert("RGB").save(os.path.join(REFS, "%s_front.png" % fig))


def ref_pose(fig, pose):
	"""The pose's own sprite x4 at the left, the person's picked turnaround beside it at
	standing height: the pose to keep and the person from every side."""
	own = pose_sprite(fig, pose)
	big = own.resize((own.width * 4, own.height * 4), Image.Resampling.NEAREST)
	turn = Image.open(os.path.join(REFS, "%s_turn.png" % fig)).convert("RGBA")
	pad = 48
	canvas = Image.new("RGBA", (big.width + turn.width + pad, max(turn.height, big.height + pad * 2)), MAGENTA)
	canvas.alpha_composite(big, (pad, canvas.height - pad - big.height))
	canvas.alpha_composite(turn, (big.width + pad, 0))
	canvas.convert("RGB").save(os.path.join(REFS, "%s_pose_%s.png" % (fig, pose)))


def keyed(art_id):
	import cut_frames
	img = Image.open(os.path.join(OUT, art_id, "raw.png"))
	return process.key_out(cut_frames.to_magenta(img))


def ref_turn(fig, turn_id):
	"""The front sprite x4 at the left, the picked turnaround's figures beside it at the
	same height: Grok sees both the pixels and the five sides."""
	s = sprite_of(fig)
	big = s.resize((s.width * 4, s.height * 4), Image.Resampling.NEAREST)
	k = keyed(turn_id)
	k = k.crop(k.getchannel("A").point(lambda a: 255 if a > 40 else 0).getbbox())
	k = k.resize((max(1, round(k.width * big.height / k.height)), big.height), Image.Resampling.LANCZOS)
	pad = 48
	canvas = Image.new("RGBA", (big.width + k.width + pad * 3, big.height + pad * 2), MAGENTA)
	canvas.alpha_composite(big, (pad, pad))
	flat = Image.new("RGBA", k.size, MAGENTA)
	flat.alpha_composite(k)
	canvas.alpha_composite(flat, (big.width + pad * 2, pad))
	os.makedirs(REFS, exist_ok=True)
	canvas.convert("RGB").save(os.path.join(REFS, "%s_turn.png" % fig))


# ── cutting and bringing to the sprite's look ────────────────────────────────

def cut(art_id, count, gap=14):
	"""The sheet's figures, left to right, each alone on transparent at Grok's size, with
	their boxes in the sheet. None (and _cut.png to look at) when the count is wrong."""
	img = keyed(art_id)
	boxes, labels, w = split_sheet.items(img, gap)
	# Specks (a hair of the outline, a fleck of key) are not figures.
	keep = [b for b in boxes if (b[3] - b[1]) > img.height * 0.2]
	check = img.copy()
	d = ImageDraw.Draw(check)
	for i, b in enumerate(keep):
		d.rectangle(b, outline=(0, 255, 0, 255))
		d.text((b[0], max(0, b[1] - 12)), str(i), fill=(0, 255, 0, 255))
	check.save(os.path.join(OUT, art_id, "_cut.png"))
	if len(keep) != count:
		print("%s: found %d figures, wanted %d (see out/%s/_cut.png)" % (art_id, len(keep), count, art_id))
		return None
	return [(split_sheet.own(img, b, labels[b], w), b) for b in keep]


_pal_cache = {}


def palette_of(fig):
	"""The person's own colours (the sprite from the front) as a PIL palette image; an
	old sprite with thousands of colours is cut to 160."""
	if fig in _pal_cache:
		return _pal_cache[fig]
	s = sprite_of(fig)
	cols = []
	seen = set()
	for r, g, b, a in s.get_flattened_data() if hasattr(s, "get_flattened_data") else s.getdata():
		if a >= 128 and (r, g, b) not in seen:
			seen.add((r, g, b))
			cols.append((r, g, b))
	if len(cols) > 250:
		opaque = Image.new("RGB", (len(cols), 1))
		opaque.putdata(cols)
		q = opaque.quantize(160, method=Image.Quantize.MEDIANCUT)
		p = q.getpalette()[:160 * 3]
		cols = [tuple(p[i:i + 3]) for i in range(0, len(p), 3)]
	flat = []
	for c in cols:
		flat.extend(c)
	# Pad with the first colour: quantize would otherwise pick the padding's black.
	while len(flat) < 768:
		flat.extend(cols[0])
	img = Image.new("P", (1, 1))
	img.putpalette(flat)
	_pal_cache[fig] = img
	return img


def pinkish(r, g, b):
	"""The key's leftovers: magenta blended into the outline (dark red-violet), at Grok size."""
	import colorsys
	h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
	hd = h * 360.0
	return s > 0.25 and v > 0.18 and (hd >= 280.0 or hd <= 8.0) and b > g + 12 and r > g + 20


def defringe(img, depth=4):
	"""Pink rim pixels within `depth` of the background take the colour of the figure's own
	pixels next to them (or go, with none): the rim snapped to the palette came out as red
	flecks on the nose and the boots (warden_a's first side view)."""
	img = img.copy()
	px = img.load()
	w, h = img.size
	a = img.getchannel("A")
	from PIL import ImageFilter
	# Near the edge: the background grown by `depth`.
	bg = a.point(lambda v: 255 if v < 128 else 0).filter(ImageFilter.MaxFilter(depth * 2 + 1)).load()
	for y in range(h):
		for x in range(w):
			r, g, b, al = px[x, y]
			if al < 128 or not bg[x, y] or not pinkish(r, g, b):
				continue
			acc = [0, 0, 0, 0]
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					nx, ny = x + dx, y + dy
					if 0 <= nx < w and 0 <= ny < h:
						q = px[nx, ny]
						if q[3] >= 128 and not pinkish(q[0], q[1], q[2]):
							acc[0] += q[0]
							acc[1] += q[1]
							acc[2] += q[2]
							acc[3] += 1
			px[x, y] = (acc[0] // acc[3], acc[1] // acc[3], acc[2] // acc[3], 255) if acc[3] else (0, 0, 0, 0)
	return img


def shrink(img, scale, pal):
	img = defringe(img)
	w = max(1, round(img.width * scale))
	h = max(1, round(img.height * scale))
	r, g, b, a = img.split()
	pre = Image.merge("RGBA", [Image.composite(ch, Image.new("L", img.size, 0), a) for ch in (r, g, b)] + [a])
	small = pre.resize((w, h), Image.Resampling.BOX)
	px = small.load()
	for y in range(h):
		for x in range(w):
			pr, pg, pb, pa = px[x, y]
			if pa > 0:
				k = 255.0 / pa
				px[x, y] = (min(255, int(pr * k)), min(255, int(pg * k)), min(255, int(pb * k)), pa)
	rgb = small.convert("RGB").quantize(palette=pal, dither=Image.Dither.NONE).convert("RGBA")
	rgb.putalpha(small.getchannel("A").point(lambda v: 255 if v >= 128 else 0))
	return despeck(rgb)


def despeck(img):
	"""Only the figure's own body: opaque bits not joined to the biggest blob go."""
	a = img.getchannel("A")
	w, h = img.size
	ap = a.load()
	seen = bytearray(w * h)
	blobs = []
	for y0 in range(h):
		for x0 in range(w):
			if ap[x0, y0] == 0 or seen[y0 * w + x0]:
				continue
			stack = [(x0, y0)]
			seen[y0 * w + x0] = 1
			pts = []
			while stack:
				x, y = stack.pop()
				pts.append((x, y))
				for dx in (-1, 0, 1):
					for dy in (-1, 0, 1):
						nx, ny = x + dx, y + dy
						if 0 <= nx < w and 0 <= ny < h and ap[nx, ny] and not seen[ny * w + nx]:
							seen[ny * w + nx] = 1
							stack.append((nx, ny))
			blobs.append(pts)
	if len(blobs) <= 1:
		return img
	blobs.sort(key=len, reverse=True)
	px = img.load()
	for pts in blobs[1:]:
		# A loose thing the size of a hand is kept (a key ring off the belt by a pixel).
		if len(pts) >= 12:
			continue
		for x, y in pts:
			px[x, y] = (0, 0, 0, 0)
	return img.crop(img.getchannel("A").getbbox())


def pose_sprite(fig, pose):
	"""The pose's own picture from the front, beside the person's sprite (warden_a_sweep.png)."""
	return Image.open(sprite_path(fig).replace(".png", "_%s.png" % pose)).convert("RGBA")


def anchor_x(img):
	a = img.getchannel("A").load()
	w, h = img.size
	y0, y1 = int(h * TORSO[0]), int(h * TORSO[1])
	s = n = 0
	for y in range(y0, y1):
		for x in range(w):
			if a[x, y]:
				s += x
				n += 1
	return s / n if n else w / 2.0


def load_picks():
	with open(PICKS, encoding="utf-8") as f:
		return json.load(f)


def stage_dir(fig):
	return os.path.join(OUT, "fig_" + fig)


def stage(fig):
	"""Every sheet picked for `fig` into frames: out/fig_<fig>/<anim>_<view>_<n>.png and
	meta.json (anchor, size, the sheet it came from)."""
	picks = load_picks().get(fig, {})
	pal = palette_of(fig)
	# The figure's own height (an old sprite has transparent rows round it: host1 is 120 of 128).
	_ref = sprite_of(fig)
	ref_h = _ref.crop(_ref.getchannel("A").getbbox()).height
	sd = stage_dir(fig)
	os.makedirs(sd, exist_ok=True)
	for f in os.listdir(sd):
		if f.endswith(".png") and f[0] != "_":
			os.remove(os.path.join(sd, f))
	meta = {}

	def put(name, img, ax, ay, src):
		img.save(os.path.join(sd, name + ".png"))
		meta[name] = {"ax": round(ax, 2), "ay": round(ay, 2), "w": img.width, "h": img.height, "src": src}

	# The standing views: one sheet, scaled by its front figure.
	if "turn" in picks:
		t = picks["turn"]
		figs = cut(t["id"], 5)
		if figs is None:
			sys.exit(2)
		scale = ref_h / float(figs[0][1][3] - figs[0][1][1])
		for v, (pic, box) in enumerate(figs):
			if v == 0:
				s = sprite_of(fig)
				s = s.crop(s.getchannel("A").getbbox())
				put("stand_1_0", s, anchor_x(s), s.height, "sprite")
				continue
			if str(v + 1) in t.get("mirror", []):
				pic = pic.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
			small = shrink(pic, scale, pal)
			put("stand_%d_0" % (v + 1), small, anchor_x(small), small.height, t["id"])
	# Poses from five sides: one sheet of five, scaled by its front figure to the pose's own
	# sprite (warden_a_sweep.png), which is its view 1.
	for pose, t in (picks.get("poses", {}) or {}).items():
		figs = cut(t["id"], 5, int(t.get("gap", 14)))
		if figs is None:
			sys.exit(2)
		own = pose_sprite(fig, pose)
		scale = own.height / float(figs[0][1][3] - figs[0][1][1])
		base = max(b[3] for _pic, b in figs)
		for v, (pic, box) in enumerate(figs):
			if v == 0:
				o = own.crop(own.getchannel("A").getbbox())
				put("%s_1_0" % pose, o, anchor_x(o), o.height, "sprite")
				continue
			small = shrink(pic, scale, pal)
			# On the sheet's baseline (a seated figure's feet), not each one's own bottom.
			put("%s_%d_0" % (pose, v + 1), small, anchor_x(small), small.height + (base - box[3]) * scale, t["id"])
	# Animations: one sheet per view.
	for anim in ("walk", "run", "idle"):
		for view, p in (picks.get(anim, {}) or {}).items():
			p = p if isinstance(p, dict) else {"id": p}
			count = int(p.get("count", 4))
			figs = cut(p["id"], count, int(p.get("gap", 14)))
			if figs is None:
				sys.exit(2)
			tallest = max(b[3] - b[1] for _pic, b in figs)
			scale = ref_h * HEIGHT_K.get(anim, 1.0) * float(p.get("k", 1.0)) / float(tallest)
			base = max(b[3] for _pic, b in figs)
			for n, (pic, box) in enumerate(figs):
				if p.get("mirror"):
					pic = pic.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
				small = shrink(pic, scale, pal)
				ay = small.height
				if anim == "run":
					lift = min((base - box[3]) * scale, ref_h * MAX_LIFT)
					ay = small.height + lift
				order = p.get("order")
				idx = order[n] if order else n
				put("%s_%s_%d" % (anim, view, idx), small, anchor_x(small), ay, p["id"])
	with open(os.path.join(sd, "meta.json"), "w", encoding="utf-8") as f:
		json.dump(meta, f, indent=1, sort_keys=True)
	print("%s: %d frames staged" % (fig, len(meta)))
	return meta


# ── the checks ───────────────────────────────────────────────────────────────

def hue_hist(img):
	"""Share of the figure's pixels in 12 hue bins (saturated ones) + 3 grey bins."""
	import colorsys
	bins = [0.0] * 15
	n = 0
	for r, g, b, a in img.get_flattened_data() if hasattr(img, "get_flattened_data") else img.getdata():
		if a < 128:
			continue
		h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
		if s < 0.18 or v < 0.12:
			bins[12 + min(2, int(v * 3))] += 1
		else:
			bins[int(h * 12) % 12] += 1
		n += 1
	return [x / max(1, n) for x in bins]


def check(fig):
	"""Prints what fails: heights, colours against the sprite, stray pieces, widths, a
	walk that does not walk. Returns the number of failures."""
	sd = stage_dir(fig)
	with open(os.path.join(sd, "meta.json"), encoding="utf-8") as f:
		meta = json.load(f)
	ref = sprite_of(fig)
	ref = ref.crop(ref.getchannel("A").getbbox())
	ref_hist = hue_hist(ref)
	ref_h = ref.height
	fails = []
	frames = {k: Image.open(os.path.join(sd, k + ".png")).convert("RGBA") for k in meta}
	for k, img in frames.items():
		anim, view, n = k.split("_")
		h = img.height
		lo = ref_h * {"stand": 0.96, "walk": 0.92, "run": 0.76, "idle": 0.8}.get(anim, 0.6)
		hi = ref_h * {"stand": 1.04, "walk": 1.0, "run": 1.0, "idle": 1.04}.get(anim, 1.1)
		if not (lo - 1 <= h <= hi + 1):
			fails.append("%s height %d (want %d..%d)" % (k, h, lo, hi))
		ratio = img.width / float(h)
		if ratio > {"stand": 0.55, "walk": 0.78, "run": 0.95}.get(anim, 1.2) or ratio < 0.22:
			fails.append("%s width/height %.2f" % (k, ratio))
		d = sum(abs(a - b) for a, b in zip(hue_hist(img), ref_hist))
		if d > 0.7:
			fails.append("%s colours off the sprite by %.2f" % (k, d))
		# The head: something in the top tenth no wider than the shoulders' half.
		a = img.getchannel("A")
		top = a.crop((0, 0, img.width, max(1, h // 10))).getbbox()
		if top is None:
			fails.append("%s no head" % k)
	# Walks: four frames that differ, the legs apart in 1 and 3 and together in 2 and 4.
	for anim in ("walk", "run"):
		for view in "12345":
			fr = [frames.get("%s_%s_%d" % (anim, view, n)) for n in range(4)]
			if any(f is None for f in fr):
				continue
			for n in range(4):
				a, b = fr[n], fr[(n + 1) % 4]
				w, h = max(a.width, b.width), max(a.height, b.height)
				ca = Image.new("RGBA", (w, h))
				cb = Image.new("RGBA", (w, h))
				ca.alpha_composite(a, (0, h - a.height))
				cb.alpha_composite(b, (0, h - b.height))
				diff = ImageChops.difference(ca.getchannel("A"), cb.getchannel("A")).getbbox()
				if diff is None:
					fails.append("%s_%s frames %d and %d alike" % (anim, view, n, (n + 1) % 4))
			if view in "234":
				spread = [legs_width(f) for f in fr]
				if not (min(spread[0], spread[2]) > max(spread[1], spread[3]) * 1.08):
					fails.append("%s_%s legs not apart in 1/3 against 2/4: %s" % (anim, view, spread))
	for f in fails:
		print("FAIL " + fig + " " + f)
	print("%s: %d frames, %d failures" % (fig, len(frames), len(fails)))
	return len(fails)


def legs_width(img):
	a = img.getchannel("A")
	bb = a.crop((0, int(img.height * 0.78), img.width, img.height)).getbbox()
	return (bb[2] - bb[0]) if bb else 0


# ── contact sheet ────────────────────────────────────────────────────────────

def sheet(fig, scale=3):
	sd = stage_dir(fig)
	with open(os.path.join(sd, "meta.json"), encoding="utf-8") as f:
		meta = json.load(f)
	rows = []
	anims = sorted(set(k.split("_")[0] for k in meta), key=lambda a: (["stand", "walk", "run", "idle"] + [a]).index(a))
	for anim in anims:
		if anim in ("walk", "run", "idle"):
			for view in "12345":
				names = sorted(k for k in meta if k.startswith("%s_%s_" % (anim, view)))
				if names:
					rows.append(names)
		else:
			# One frame a view: the five views in a row.
			rows.append(sorted(k for k in meta if k.startswith(anim + "_")))
	cell_w = max(int(max(meta[k]["w"] for k in meta) * 1.2), 64)
	cell_h = max(int(meta[k]["ay"]) for k in meta) + 8
	cols = max(len(r) for r in rows)
	img = Image.new("RGBA", (cell_w * cols, cell_h * len(rows)), (96, 96, 112, 255))
	for ri, names in enumerate(rows):
		for ci, k in enumerate(names):
			fr = Image.open(os.path.join(sd, k + ".png")).convert("RGBA")
			m = meta[k]
			x = int(ci * cell_w + cell_w / 2 - m["ax"])
			y = int(ri * cell_h + cell_h - 4 - m["ay"])
			img.alpha_composite(fr, (x, y))
	img = img.resize((img.width * scale, img.height * scale), Image.Resampling.NEAREST)
	img.save(os.path.join(sd, "_contact.png"))
	# Walks and runs going round, one GIF per animation: the five views side by side.
	for anim in ("walk", "run"):
		names = [[k for k in sorted(meta) if k.startswith("%s_%s_" % (anim, v))] for v in "12345"]
		if not any(names):
			continue
		gif = []
		for n in range(4):
			fr = Image.new("RGBA", (cell_w * 5, cell_h), (96, 96, 112, 255))
			for vi, ns in enumerate(names):
				if n < len(ns):
					k = ns[n]
					m = meta[k]
					fr.alpha_composite(Image.open(os.path.join(sd, k + ".png")).convert("RGBA"),
						(int(vi * cell_w + cell_w / 2 - m["ax"]), int(cell_h - 4 - m["ay"])))
			gif.append(fr.resize((fr.width * scale, fr.height * scale), Image.Resampling.NEAREST).convert("RGB"))
		gif[0].save(os.path.join(sd, "_%s.gif" % anim), save_all=True, append_images=gif[1:],
			duration=1000 // (8 if anim == "walk" else 11), loop=0)
	print("contact sheet: " + os.path.join(sd, "_contact.png"))


# ── the atlas for the game ───────────────────────────────────────────────────

def pack(fig):
	"""The frames into one atlas, shelf-packed in rows, and its index:
	sets/<fig>.json {h: the sprite's height, anims: {anim: [[[x, y, w, h, ax, ay], ...frames] ...views 1-5]}}.
	A view an animation lacks is []. sets/<fig>_mask.png marks the jacket where the
	person has one (warden_looks.gd recolours it)."""
	sd = stage_dir(fig)
	with open(os.path.join(sd, "meta.json"), encoding="utf-8") as f:
		meta = json.load(f)
	names = sorted(meta, key=lambda k: (-meta[k]["h"], k))
	width = 512
	x = y = row_h = 0
	place = {}
	for k in names:
		w, h = meta[k]["w"], meta[k]["h"]
		if x + w > width:
			x = 0
			y += row_h + 1
			row_h = 0
		place[k] = (x, y)
		x += w + 1
		row_h = max(row_h, h)
	height = y + row_h
	atlas = Image.new("RGBA", (width, height))
	for k, (px, py) in place.items():
		atlas.alpha_composite(Image.open(os.path.join(sd, k + ".png")).convert("RGBA"), (px, py))
	index = {"h": sprite_of(fig).height, "anims": {}}
	for k in names:
		anim, view, n = k.split("_")
		views = index["anims"].setdefault(anim, [[] for _ in range(5)])
		frames = views[int(view) - 1]
		while len(frames) <= int(n):
			frames.append(None)
		m = meta[k]
		frames[int(n)] = [place[k][0], place[k][1], m["w"], m["h"], m["ax"], m["ay"]]
	os.makedirs(SETS, exist_ok=True)
	atlas.save(os.path.join(SETS, fig + ".png"))
	jacket = figure_prompts.JACKETS.get(fig)
	if jacket:
		jacket_mask(atlas, place, meta, jacket).save(os.path.join(SETS, fig + "_mask.png"))
	with open(os.path.join(SETS, fig + ".json"), "w", encoding="utf-8", newline="\n") as f:
		json.dump(index, f, separators=(",", ":"))
	print("%s: atlas %dx%d, %d frames" % (fig, width, height, len(meta)))


def jacket_mask(atlas, place, meta, jacket):
	"""White where the jacket is, per frame: its hue band within the rows of the frame
	the jacket can be in (jacket["band"], shares of the frame's height; boots of the same
	green below it), then the folds it closes round (as warden_looks._recolor did per pose)."""
	import colorsys
	mask = Image.new("L", atlas.size, 0)
	ap = atlas.load()
	mp = mask.load()
	h0, h1 = jacket["hue"]
	sat_min = jacket["sat"]
	v_min = jacket.get("vmin", 0.08)
	for k, (ox, oy) in place.items():
		m = meta[k]
		anim = k.split("_")[0]
		band = jacket["band"].get(anim, jacket["band"]["stand"])
		y0 = oy + int(band[0] * m["h"])
		y1 = oy + int(band[1] * m["h"])

		def hue_ok(hd):
			return (h0 <= hd <= h1) if h0 <= h1 else (hd >= h0 or hd <= h1)

		for y in range(y0, y1):
			for x in range(ox, ox + m["w"]):
				r, g, b, a = ap[x, y]
				if a < 128:
					continue
				hh, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
				if s >= sat_min and v >= v_min and hue_ok(hh * 360.0):
					mp[x, y] = 255
		for _pass in range(4):
			add = []
			for y in range(max(y0, oy + 1), min(y1, oy + m["h"] - 1)):
				for x in range(ox + 1, ox + m["w"] - 1):
					if mp[x, y]:
						continue
					r, g, b, a = ap[x, y]
					if a < 128:
						continue
					n = sum(1 for dy in (-1, 0, 1) for dx in (-1, 0, 1) if (dx or dy) and mp[x + dx, y + dy])
					if n >= 6:
						add.append((x, y))
						continue
					hh, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
					hd = hh * 360.0
					skin = s > 0.3 and 12.0 < hd < 48.0
					if n >= 4 and not skin and (v < 0.42 or s < sat_min):
						add.append((x, y))
			for q in add:
				mp[q] = 255
		_fill_holes(ap, mp, ox, y0, ox + m["w"], y1)
	return mask


def _fill_holes(ap, mp, x0, y0, x1, y1, most=40):
	"""Small pockets the jacket closes round (mud on the back: dark holes in a light
	colour) become jacket, but not a bright saturated one (the orange camp patch)."""
	import colorsys
	seen = set()
	for y in range(y0, y1):
		for x in range(x0, x1):
			if (x, y) in seen or mp[x, y] or ap[x, y][3] < 128:
				continue
			stack = [(x, y)]
			seen.add((x, y))
			blob = []
			closed = True
			while stack:
				cx, cy = stack.pop()
				blob.append((cx, cy))
				for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
					if not (x0 <= nx < x1 and y0 <= ny < y1) or ap[nx, ny][3] < 128:
						closed = False
						continue
					if mp[nx, ny] or (nx, ny) in seen:
						continue
					seen.add((nx, ny))
					stack.append((nx, ny))
			if not closed or len(blob) > most:
				continue
			bright = 0
			for bx, by in blob:
				r, g, b, _a = ap[bx, by]
				_h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
				if s > 0.45 and v > 0.45:
					bright += 1
			if bright * 3 < len(blob):
				for q in blob:
					mp[q] = 255


# ── choosing and generating ──────────────────────────────────────────────────

def variants(fig, key):
	out = []
	for n in range(1, 10):
		if os.path.exists(os.path.join(OUT, "fig_%s_%s_%d" % (fig, key, n), "raw.png")):
			out.append("fig_%s_%s_%d" % (fig, key, n))
	return out


def usable(art_id, count):
	return cut(art_id, count) is not None


def _save_picks(all_picks):
	with open(PICKS, "w", encoding="utf-8", newline="\n") as f:
		json.dump(all_picks, f, indent=1, sort_keys=True)
		f.write("\n")


def autopick(fig):
	"""Fills what figure_picks.json lacks for `fig` with the first variant of each sheet
	that cuts into the right number of figures (a pick already there is kept: the ones
	chosen by eye)."""
	all_picks = load_picks() if os.path.exists(PICKS) else {}
	p = all_picks.setdefault(fig, {})
	if "turn" not in p:
		for v in variants(fig, "turn"):
			if usable(v, 5):
				p["turn"] = {"id": v}
				break
	for anim in ("walk", "run"):
		for view in "12345":
			if view in p.get(anim, {}):
				continue
			for v in variants(fig, "%s%s" % (anim, view)):
				if usable(v, 4):
					p.setdefault(anim, {})[view] = {"id": v}
					break
	if "1" not in p.get("idle", {}):
		for v in variants(fig, "idle1"):
			if usable(v, 4):
				p.setdefault("idle", {})["1"] = {"id": v}
				break
	for pose in figure_prompts.POSES_OF.get(fig, []):
		if pose in p.get("poses", {}):
			continue
		for v in variants(fig, "pose_" + pose):
			if usable(v, 5):
				p.setdefault("poses", {})[pose] = {"id": v}
				break
	_save_picks(all_picks)
	return p


def batch(fig, keys, tries=3):
	"""Grok, one sheet after another (gen.sh queues behind other sessions' runs), each
	until one variant cuts right (at most `tries`); after the turnaround, the reference
	for the rest is made from it."""
	import subprocess
	if not os.path.exists(os.path.join(REFS, "%s_front.png" % fig)):
		ref_front(fig)
	for key in keys:
		count = 5 if key == "turn" or key.startswith("pose_") else 4
		if key.startswith("pose_"):
			ref_pose(fig, key[5:])
		ok = None
		for n in range(1, tries + 1):
			art_id = "fig_%s_%s_%d" % (fig, key, n)
			if not os.path.exists(os.path.join(OUT, art_id, "raw.png")):
				subprocess.run(["bash", os.path.join(HERE, "gen.sh"), art_id], cwd=HERE)
			if os.path.exists(os.path.join(OUT, art_id, "raw.png")) and usable(art_id, count):
				ok = art_id
				break
		print("BATCH %s %s -> %s" % (fig, key, ok), flush=True)
		if key == "turn" and ok:
			ref_turn(fig, ok)
	autopick(fig)


def base_poses(fig):
	"""The family's people's pictures from the front at the attractions (fig_base_<fig>_<pose>_<n>,
	the first variant there is unless figure_picks.json names one): processed to the
	pose's height (a child's by its own height against a grown man's 128), the pink rim
	taken off at Grok's size and the colours snapped to the person's own."""
	picks = (load_picks() if os.path.exists(PICKS) else {}).get(fig, {}).get("base", {})
	k = min(1.0, sprite_of(fig).height / 128.0)
	for pose, (h, _text) in figure_prompts.BASE_POSES.items():
		art_id = picks.get(pose)
		if art_id is None:
			for n in range(1, 4):
				if os.path.exists(os.path.join(OUT, "fig_base_%s_%s_%d" % (fig, pose, n), "raw.png")):
					art_id = "fig_base_%s_%s_%d" % (fig, pose, n)
					break
		if art_id is None:
			continue
		dest = os.path.join(GODOT, figure_prompts.FIGURES[fig][0].replace(".png", "_%s.png" % pose))
		img = keyed(art_id)
		img = img.crop(img.getchannel("A").point(lambda a: 255 if a > 40 else 0).getbbox())
		out = shrink(img, max(8, round(h * k)) / float(img.height), palette_of(fig))
		out.save(dest)
		print("%s -> %s %s" % (art_id, os.path.relpath(dest, GODOT), out.size))


def main():
	cmd = sys.argv[1] if len(sys.argv) > 1 else ""
	if cmd == "ref":
		fig, kind = sys.argv[2], sys.argv[3]
		if kind == "front":
			ref_front(fig)
		else:
			ref_turn(fig, sys.argv[4])
	elif cmd == "cut":
		cut(sys.argv[2], int(sys.argv[3]))
	elif cmd == "stage":
		stage(sys.argv[2])
	elif cmd == "check":
		sys.exit(1 if check(sys.argv[2]) else 0)
	elif cmd == "sheet":
		sheet(sys.argv[2])
	elif cmd == "pack":
		pack(sys.argv[2])
	elif cmd == "base_poses":
		base_poses(sys.argv[2])
	elif cmd == "autopick":
		autopick(sys.argv[2])
	elif cmd == "batch":
		batch(sys.argv[2], sys.argv[3:])
	elif cmd == "all":
		stage(sys.argv[2])
		check(sys.argv[2])
		sheet(sys.argv[2])
		pack(sys.argv[2])
	else:
		print(__doc__)


if __name__ == "__main__":
	main()
