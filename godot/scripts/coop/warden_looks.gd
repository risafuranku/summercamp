extends RefCounted

## The wardens' looks (the WARDENS page in the menu: the figure and the colour of the
## jacket, kept with the warden in scripts/profiles.gd; the other warden sees it in co-op).
## Four wardens (Grok, assets/textury/npc/warden_a..d.png), each drawn in thirteen poses:
## standing, rowing (the lake boat), sweeping and down on one knee scrubbing (the rooms'
## jobs), lying on their belly (in a tent), at the PC from behind (over the shoulder;
## also on a bus seat seen from behind), sitting from the front (the bus, the benches),
## and at the attractions (scripts/attractions/warden_play.gd): the guitar and a sausage
## by the fire, a kick at the net, the bat at the table, up the slide's ladder from
## behind, on the swing holding the chains; flat in a pipe crawling (the sewer, for two:
## scripts/pipes/pipe_mate.gd) from behind, from in front and from the side. A jacket colour is the jacket's own pixels moved to another hue, with their
## shading kept (each warden has the hue band and the part of the picture its jacket is
## in); the original jacket is one of the colours. Textures are made once and kept.

const DIR := "res://assets/textury/npc/"
const DOOM = preload("res://scripts/figures/doom_figure.gd")
const LETTERS := ["a", "b", "c", "d"]
## The figures' own names: what the other warden is called when their machine sends no
## warden's name (the warden's name is the player's, scripts/profiles.gd).
const NAMES := ["Pepa", "Ondra", "Jana", "Bara"]
## The figures as the WARDENS page lists them.
const FIGURES := ["Windbreaker", "Red anorak", "Ponytail", "Glasses"]
const POSES := ["stand", "row", "sweep", "crouch", "prone", "desk", "sit", "guitar", "eat", "kick", "bat", "climb", "swing", "write", "bed", "bedfoot", "fix", "fish", "saw", "bag", "tap", "pour", "wash", "cook", "till", "crawl_back", "crawl_front", "crawl_side"]

## Where each warden's jacket is: hue band (degrees, may wrap past 360), the least
## saturation and brightness that count (Ondra's red: the outline round the whole
## figure is drawn in its darkest shade), the band of the picture (0 top .. 1 bottom)
## per pose, and boxes of it to leave alone ([x0, y0, x1, y1], 0..1; boots in the air).
## (Above the boots: Pepa's rubber boots are green too, Ondra's brown ones nearly red.)
const JACKETS := [
	{"hue": [62.0, 165.0], "sat": 0.16, "band": {"stand": [0.14, 0.6], "row": [0.0, 0.68], "sweep": [0.0, 0.72], "crouch": [0.0, 0.72], "prone": [0.0, 1.0], "desk": [0.0, 0.7], "sit": [0.0, 0.68], "guitar": [0.0, 0.68], "eat": [0.0, 0.68], "kick": [0.0, 0.6], "bat": [0.0, 0.6], "climb": [0.0, 0.55], "swing": [0.0, 0.55], "fix": [0.0, 0.6], "fish": [0.0, 0.6], "saw": [0.0, 0.75], "bag": [0.0, 0.75], "tap": [0.0, 0.6], "pour": [0.0, 0.6], "wash": [0.0, 0.6], "cook": [0.0, 0.6], "till": [0.0, 0.6], "crawl_back": [0.0, 0.58], "crawl_front": [0.0, 1.0], "crawl_side": [0.0, 1.0]},
		"out": {"crawl_front": [[0.28, 0.0, 0.72, 0.3]], "crawl_side": [[0.0, 0.0, 0.24, 1.0]], "prone": [[0.55, 0.0, 1.0, 0.37]], "kick": [[0.78, 0.2, 1.0, 0.55]], "bed": [[0.8, 0.0, 1.0, 1.0]], "saw": [[0.0, 0.5, 0.4, 1.0], [0.45, 0.55, 0.72, 1.0]], "bag": [[0.2, 0.62, 0.62, 1.0]]}},
	{"hue": [338.0, 10.0], "sat": 0.42, "vmin": 0.16, "band": {"stand": [0.12, 0.6], "row": [0.0, 0.66], "sweep": [0.0, 0.62], "crouch": [0.0, 0.8], "prone": [0.3, 1.0], "desk": [0.0, 0.82], "sit": [0.2, 0.66], "guitar": [0.2, 0.66], "eat": [0.2, 0.66], "kick": [0.16, 0.62], "bat": [0.16, 0.62], "climb": [0.0, 0.62], "swing": [0.2, 0.66], "fix": [0.16, 0.62], "fish": [0.16, 0.62], "saw": [0.04, 0.8], "bag": [0.04, 0.8], "tap": [0.04, 0.8], "pour": [0.04, 0.8], "wash": [0.04, 0.8], "cook": [0.04, 0.8], "till": [0.04, 0.8], "crawl_back": [0.1, 0.62], "crawl_front": [0.0, 1.0], "crawl_side": [0.0, 1.0]},
		"out": {"crawl_front": [[0.8, 0.3, 1.0, 0.62]], "crawl_side": [[0.0, 0.0, 0.22, 1.0]], "eat": [[0.24, 0.12, 0.62, 0.32]], "guitar": [[0.0, 0.42, 0.44, 0.72]], "bat": [[0.0, 0.22, 0.2, 0.42]]}},
	{"hue": [62.0, 165.0], "sat": 0.16, "band": {"stand": [0.14, 0.6], "row": [0.0, 0.7], "sweep": [0.0, 0.7], "crouch": [0.0, 0.86], "prone": [0.0, 1.0], "desk": [0.0, 1.0], "sit": [0.0, 1.0], "kick": [0.0, 0.62], "bat": [0.0, 0.62], "climb": [0.0, 0.72], "fix": [0.0, 0.72], "fish": [0.0, 0.72], "saw": [0.0, 0.72], "bag": [0.0, 0.72], "tap": [0.0, 0.72], "pour": [0.0, 0.72], "wash": [0.0, 0.72], "cook": [0.0, 0.72], "till": [0.0, 0.72], "crawl_back": [0.0, 0.55], "crawl_front": [0.0, 1.0], "crawl_side": [0.0, 1.0]},
		"out": {"crawl_front": [[0.2, 0.0, 0.8, 0.22]], "crawl_side": [[0.0, 0.0, 0.2, 1.0]], "prone": [[0.6, 0.0, 1.0, 0.36]], "bed": [[0.82, 0.0, 1.0, 1.0]]}},
	{"hue": [62.0, 165.0], "sat": 0.16, "band": {"stand": [0.1, 0.62], "row": [0.0, 0.78], "sweep": [0.0, 0.7], "crouch": [0.0, 0.84], "prone": [0.0, 1.0], "desk": [0.0, 1.0], "sit": [0.0, 1.0], "kick": [0.0, 0.62], "bat": [0.0, 0.62], "climb": [0.0, 0.72], "fix": [0.0, 0.72], "fish": [0.0, 0.72], "saw": [0.0, 0.72], "bag": [0.0, 0.72], "tap": [0.0, 0.72], "pour": [0.0, 0.72], "wash": [0.0, 0.72], "cook": [0.0, 0.72], "till": [0.0, 0.72], "crawl_back": [0.0, 0.66], "crawl_front": [0.0, 1.0], "crawl_side": [0.0, 1.0]}},
]
## Jacket colours: name, and the colour of the jacket's middle tone (hue, sat, value);
## hue -1 for a warden's own (the colour they were drawn in).
const COLORS := [
	["Own", -1.0, 0.0, 0.0],
	["Forest", 115.0, 0.36, 0.32],
	["Rust", 8.0, 0.58, 0.46],
	["Navy", 222.0, 0.48, 0.34],
	["Mustard", 42.0, 0.6, 0.52],
	["Orange", 22.0, 0.72, 0.6],
	["Slate", 210.0, 0.12, 0.4],
	["Plum", 295.0, 0.3, 0.32],
	["Sky", 196.0, 0.38, 0.52],
]

static var _cache: Dictionary = {}
static var _atlas_cache: Dictionary = {}


static func count() -> int:
	return LETTERS.size()


static func color_count() -> int:
	return COLORS.size()


static func color_name(color: int) -> String:
	return str(COLORS[posmod(color, COLORS.size())][0])


static func has_pose(model: int, pose: String) -> bool:
	return ResourceLoader.exists(DIR + "warden_%s%s.png" % [LETTERS[posmod(model, LETTERS.size())], "" if pose == "stand" else "_" + pose])


## The picture of warden `model` in jacket `color` in `pose` (POSES; a pose not drawn
## falls back to standing).
static func texture(model: int, color: int, pose: String = "stand") -> Texture2D:
	model = posmod(model, LETTERS.size())
	color = posmod(color, COLORS.size())
	var key := "%d|%d|%s" % [model, color, pose]
	if _cache.has(key):
		return _cache[key]
	var path := DIR + "warden_%s%s.png" % [LETTERS[model], "" if pose == "stand" else "_" + pose]
	if not ResourceLoader.exists(path):
		if pose != "stand":
			return texture(model, color, "stand")
		return null
	var base: Texture2D = load(path)
	var tex: Texture2D = base
	if float(COLORS[color][1]) >= 0.0:
		# A copy: the texture's own image is shared, and would come out recoloured.
		var src := base.get_image()
		var img: Image = src.duplicate() as Image if src != null else null
		if img != null:
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			_recolor(img, JACKETS[model], pose, COLORS[color])
			tex = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## Warden `model` seen from eight sides (scripts/figures/doom_figure.gd), {} until drawn.
static func figure_set(model: int) -> Dictionary:
	return DOOM.set_of("warden_" + str(LETTERS[posmod(model, LETTERS.size())]))


## That set's atlas with the jacket in `color`: the jacket is where the mask beside the
## atlas says (sets/warden_<x>_mask.png, made with it by tools/artgen/figures.py from the
## jacket's hue in its rows, the folds closed in), the same on every frame and side.
static func atlas(model: int, color: int) -> Texture2D:
	model = posmod(model, LETTERS.size())
	color = posmod(color, COLORS.size())
	var set := figure_set(model)
	if set.is_empty():
		return null
	var key := "%d|%d" % [model, color]
	if _atlas_cache.has(key):
		return _atlas_cache[key]
	var base: Texture2D = set["tex"]
	var tex: Texture2D = base
	var mpath := DOOM.SETS_DIR + "warden_%s_mask.png" % LETTERS[model]
	if float(COLORS[color][1]) >= 0.0 and ResourceLoader.exists(mpath):
		var src := base.get_image()
		var msrc := (load(mpath) as Texture2D).get_image()
		if src != null and msrc != null:
			var img := src.duplicate() as Image
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			var m := msrc.duplicate() as Image
			if m.is_compressed():
				m.decompress()
			m.convert(Image.FORMAT_L8)
			if m.get_size() == img.get_size():
				_recolor_masked(img, m.get_data(), COLORS[color])
			tex = ImageTexture.create_from_image(img)
	_atlas_cache[key] = tex
	return tex


## The masked pixels to the colour, as _recolor does it (mean tone to the colour's, each
## pixel keeping how much lighter or darker it was).
static func _recolor_masked(img: Image, mask: PackedByteArray, color: Array) -> void:
	var w := img.get_width()
	var at := PackedInt32Array()
	for i in mask.size():
		if mask[i] > 127:
			at.append(i)
	if at.is_empty():
		return
	var s_sum := 0.0
	var v_sum := 0.0
	for i in at:
		var c := img.get_pixel(i % w, floori(float(i) / float(w)))
		s_sum += c.s
		v_sum += c.v
	var s_mean := s_sum / float(at.size())
	var v_mean := v_sum / float(at.size())
	var th := float(color[1]) / 360.0
	var ts := float(color[2])
	var tv := float(color[3])
	for i in at:
		var x := i % w
		var y := floori(float(i) / float(w))
		var c4 := img.get_pixel(x, y)
		var ns := clampf(ts * clampf(c4.s / maxf(s_mean, 0.01), 0.65, 1.3), 0.0, 1.0)
		var nv := clampf(tv * pow(clampf(c4.v / maxf(v_mean, 0.01), 0.42, 1.8), 0.8), 0.0, 1.0)
		img.set_pixel(x, y, Color.from_hsv(th, ns, nv, c4.a))


static func _in_boxes(boxes: Array, x: int, y: int, w: int, h: int) -> bool:
	var fx := float(x) / float(w)
	var fy := float(y) / float(h)
	for bx in boxes:
		if fx >= float(bx[0]) and fx < float(bx[2]) and fy >= float(bx[1]) and fy < float(bx[3]):
			return true
	return false


static func _in_hue(h_deg: float, band: Array) -> bool:
	var a := float(band[0])
	var b := float(band[1])
	return (h_deg >= a and h_deg <= b) if a <= b else (h_deg >= a or h_deg <= b)


## The jacket's pixels to the new colour: their mean tone goes to the colour's, each
## pixel keeping how much lighter or darker it was (evened out, the darkest no darker
## than a fold: near-black flecks would show on a light jacket). The jacket is the
## pixels of its hue, the dark, greyed folds between them (taken in from their
## neighbours, skin left out) and the flecks it closes round (mud).
static func _recolor(img: Image, jacket: Dictionary, pose: String, color: Array) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var band: Array = (jacket["band"] as Dictionary).get(pose, (jacket["band"] as Dictionary).get("stand", [0.0, 1.0]))
	var y0 := int(float(band[0]) * h)
	var y1 := int(float(band[1]) * h)
	var out: Array = (jacket.get("out", {}) as Dictionary).get(pose, [])
	var hues: Array = jacket["hue"]
	var sat_min := float(jacket["sat"])
	var v_min := float(jacket.get("vmin", 0.08))
	var mask := PackedByteArray()
	mask.resize(w * h)
	for y in range(y0, y1):
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a >= 0.5 and c.s >= sat_min and c.v >= v_min and _in_hue(c.h * 360.0, hues) and not _in_boxes(out, x, y, w, h):
				mask[y * w + x] = 1
	# The folds: dark or greyed pixels mostly surrounded by jacket; then any pixel
	# the jacket closes round.
	for _pass in 4:
		var add: Array[int] = []
		for y in range(maxi(y0, 1), mini(y1, h - 1)):
			for x in range(1, w - 1):
				if mask[y * w + x] == 1:
					continue
				var c2 := img.get_pixel(x, y)
				if c2.a < 0.5 or _in_boxes(out, x, y, w, h):
					continue
				var n := 0
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						if (dx != 0 or dy != 0) and mask[(y + dy) * w + x + dx] == 1:
							n += 1
				# Closed round by the jacket (a fleck of mud on it): its own.
				if n >= 6:
					add.append(y * w + x)
					continue
				var hd := c2.h * 360.0
				var skin := c2.s > 0.3 and hd > 12.0 and hd < 48.0
				if n >= 4 and not skin and (c2.v < 0.42 or c2.s < sat_min):
					add.append(y * w + x)
		for i in add:
			mask[i] = 1
	var s_sum := 0.0
	var v_sum := 0.0
	var count := 0
	for i in mask.size():
		if mask[i] == 1:
			var c3 := img.get_pixel(i % w, floori(float(i) / float(w)))
			s_sum += c3.s
			v_sum += c3.v
			count += 1
	if count == 0:
		return
	var s_mean := s_sum / float(count)
	var v_mean := v_sum / float(count)
	var th := float(color[1]) / 360.0
	var ts := float(color[2])
	var tv := float(color[3])
	for i2 in mask.size():
		if mask[i2] != 1:
			continue
		var x2 := i2 % w
		var y2 := floori(float(i2) / float(w))
		var c4 := img.get_pixel(x2, y2)
		var ns := clampf(ts * clampf(c4.s / maxf(s_mean, 0.01), 0.65, 1.3), 0.0, 1.0)
		var nv := clampf(tv * pow(clampf(c4.v / maxf(v_mean, 0.01), 0.42, 1.8), 0.8), 0.0, 1.0)
		img.set_pixel(x2, y2, Color.from_hsv(th, ns, nv, c4.a))
