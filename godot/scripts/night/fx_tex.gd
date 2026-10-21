extends RefCounted

## Textures of the night as something that can go over the wire (co-op: the other
## machine draws the host's enemies and, for the warden they hunt, the scare on the
## screen). A texture with a file is its path; one made in code says how it was made
## (meta "fx_src": {proc, src, ...}) and the other machine makes it too; an AtlasTexture
## is its atlas and region. Made ones are kept (made once per machine).

static var _made := {}


## `tex` as a Variant that goes over the wire, or null if it cannot.
static func encode(tex: Texture2D) -> Variant:
	if tex == null:
		return null
	if tex.has_meta("fx_src"):
		return tex.get_meta("fx_src")
	if tex is AtlasTexture:
		var at := tex as AtlasTexture
		if at.atlas != null and at.atlas.resource_path != "":
			return {"proc": "atlas", "src": at.atlas.resource_path, "r": at.region}
		return null
	if tex.resource_path != "":
		return tex.resource_path
	return null


## The texture `v` stands for (null if it cannot be had here).
static func decode(v: Variant) -> Texture2D:
	if v is String:
		var path := str(v)
		return load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null
	if not (v is Dictionary):
		return null
	var d: Dictionary = v
	var key := str(d)
	if _made.has(key):
		return _made[key]
	var src: Texture2D = decode(str(d.get("src", "")))
	if src == null:
		return null
	var out: Texture2D = null
	match str(d.get("proc", "")):
		"atlas":
			var at := AtlasTexture.new()
			at.atlas = src
			at.region = d.get("r", Rect2(Vector2.ZERO, src.get_size()))
			out = at
		"flip_head":
			out = flip_head(src, float(d.get("frac", 0.17)))
		"dissolve":
			out = dissolve(src, int(d.get("f", 0)), int(d.get("n", 6)))
	if out != null:
		_made[key] = out
	return out


## `src` with its head (the top `frac` of the figure) cut out and turned upside down on
## the neck: the hair falling up, the face the wrong way up. Its "fx_src" says so.
static func flip_head(src: Texture2D, frac: float = 0.17) -> ImageTexture:
	var img := src.get_image()
	if img == null:
		return null
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var top := 0
	for y in h:
		var hit := false
		for x in w:
			if img.get_pixel(x, y).a > 0.5:
				hit = true
				break
		if hit:
			top = y
			break
	var hh := int(float(h) * frac)
	var head := img.get_region(Rect2i(0, top, w, hh))
	head.flip_y()
	img.fill_rect(Rect2i(0, top, w, hh), Color(0, 0, 0, 0))
	img.blit_rect(head, Rect2i(0, 0, w, hh), Vector2i(0, top))
	var t := ImageTexture.create_from_image(img)
	t.set_meta("fx_src", {"proc": "flip_head", "src": src.resource_path, "frac": frac})
	t.set_meta("flip_top", top)
	t.set_meta("flip_h", hh)
	return t


## `src` going to nothing in an ordered dither, step `f` of `n` (whole pixels gone, the
## rest darker as it goes): the Silent Man taken by the light. Its "fx_src" says so.
static func dissolve(src: Texture2D, f: int, n: int) -> ImageTexture:
	var img := src.get_image()
	if img == null:
		return null
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var bayer := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	var cut := float(f + 1) / float(n + 1)
	var dark := 1.0 - cut * 0.6
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			if (float(bayer[(x & 3) + (y & 3) * 4]) + 0.5) / 16.0 < cut:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				img.set_pixel(x, y, Color(c.r * dark, c.g * dark, c.b * dark, c.a))
	var t := ImageTexture.create_from_image(img)
	if src.resource_path != "":
		t.set_meta("fx_src", {"proc": "dissolve", "src": src.resource_path, "f": f, "n": n})
	return t
