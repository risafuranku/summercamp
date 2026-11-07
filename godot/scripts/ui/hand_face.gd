extends RefCounted

## The face of one of the hands, small enough for a plate on the right (the user 7. 11.: "mark
## the notifications somebody of the staff has as their job, so I can see in a heap of unswept
## lodgings which will be seen to and which I can go to"): the head out of their photo
## (os98/photos/<slug>.png, 48 x 64), brought down once and kept.

const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const PHOTOS := "res://assets/textury/os98/photos/"
const SIDE := 12
const HEAD := Rect2i(6, 2, 36, 36)

static var _faces: Dictionary = {}


static func of(slug: String) -> Texture2D:
	if slug == "":
		return null
	var name := BUSINESS.photo_of(slug)
	if _faces.has(name):
		return _faces[name]
	var path := PHOTOS + name + ".png"
	var out: Texture2D = null
	if ResourceLoader.exists(path):
		var t := load(path) as Texture2D
		var img: Image = t.get_image() if t != null else null
		if img != null:
			if img.is_compressed():
				img.decompress()
			var head := img.get_region(HEAD)
			head.resize(SIDE, SIDE, Image.INTERPOLATE_LANCZOS)
			out = ImageTexture.create_from_image(head)
	_faces[name] = out
	return out
