extends RefCounted

## The picture of a hand's job over their head in the camp (12. 11., Richard picked "an icon
## of the work over the staff's heads": what they see to for you, seen from the camp): the
## trouble strip's own picture of that job (assets/textury/ui/trouble_<kind>.png, so the
## hand under a picture and the plate on the right are one thing), ringed in black so it
## reads against the sky and the grass. It shows while they walk out to a job and while
## they are at it; on the way back, at rest or out of sight (inside a lodging, at the desk)
## there is none. A child of the hand's own sprite (staff_runtime._draw): it follows their
## step and goes with them. Nothing of its own moves.

const TEX := "res://assets/textury/ui/trouble_%s.png"
## A job (the staff act's "what", core/systems/staff_rules.gd JOBS and the day's events) ->
## its picture.
const KIND := {"litter": "litter", "raccoons": "raccoons", "delivery": "delivery", "tree": "tree",
	"rooms": "clean", "blocks": "toilet", "lost_kid": "lost_kid", "noise": "noise"}
## A repair by what is broken (state.failures' "type"); a lamp only worn has no failure.
const MEND_KIND := {"lamp_post": "lamp", "toilet_block": "toilet", "shower_block": "shower", "water_pump": "shower"}
## Its size in the world (the picture's 12 px and its ring), and how far over the head.
const SIZE_M := 0.3
const OVER_HEAD_M := 0.16
const RING := Color(0.04, 0.035, 0.03, 1.0)
const NAME := "JobBadge"

static var _tex: Dictionary = {}


## The picture's kind for what a hand is at now ("" none): at a job, or walking out to one.
## `failures`: the camp's state.failures (a repair's picture is what is broken).
static func kind_of(act: Dictionary, failures: Dictionary) -> String:
	var job := act
	if str(act.get("do", "")) == "walk":
		job = act.get("next", {}) as Dictionary
	if str(job.get("do", "")) != "work":
		return ""
	var what := str(job.get("what", ""))
	if what != "repairs":
		return str(KIND.get(what, ""))
	var room := str(job.get("room", ""))
	if room == "fix:breaker":
		return "breaker"
	var f = failures.get(room.trim_prefix("fix:"), null)
	return str(MEND_KIND.get(str((f as Dictionary).get("type", "")), "")) if f is Dictionary else "lamp"


## Over `hand` (a Sprite3D standing, centred, as staffroom._place leaves it) the picture
## of `kind`; "" takes it away.
static func set_over(hand: Sprite3D, kind: String) -> void:
	var b := hand.get_node_or_null(NAME) as Sprite3D
	var tex := _ringed(kind) if kind != "" else null
	if tex == null:
		if b != null:
			b.visible = false
		return
	if b == null:
		b = Sprite3D.new()
		b.name = NAME
		b.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		b.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		b.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		b.shaded = false
		hand.add_child(b)
	b.texture = tex
	b.pixel_size = SIZE_M / float(tex.get_height())
	var h := float(hand.texture.get_height()) * hand.pixel_size if hand.texture != null else 1.74
	b.position = Vector3(0.0, h * 0.5 + OVER_HEAD_M + SIZE_M * 0.5, 0.0)
	b.visible = true


## The picture with a one-pixel black ring round its own shape (made once a kind).
static func _ringed(kind: String) -> Texture2D:
	if _tex.has(kind):
		return _tex[kind]
	var path := TEX % kind
	var src: Texture2D = load(path) if ResourceLoader.exists(path) else null
	if src == null:
		_tex[kind] = null
		return null
	var img := src.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var out := Image.create(w + 2, h + 2, false, Image.FORMAT_RGBA8)
	for y in h + 2:
		for x in w + 2:
			var sx := x - 1
			var sy := y - 1
			if sx >= 0 and sy >= 0 and sx < w and sy < h and img.get_pixel(sx, sy).a > 0.5:
				out.set_pixel(x, y, img.get_pixel(sx, sy))
				continue
			for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
				var nx := sx + d.x
				var ny := sy + d.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and img.get_pixel(nx, ny).a > 0.5:
					out.set_pixel(x, y, RING)
					break
	var t := ImageTexture.create_from_image(out)
	_tex[kind] = t
	return t
