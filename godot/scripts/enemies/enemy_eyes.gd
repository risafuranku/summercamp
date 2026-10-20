extends Node3D

## A night thing's eyes in the dark: each one its own, so you know what it is before you
## know where it is (DESIGN §5b). Two small unshaded billboards in the world (they show
## through a cabin's window, and the other wardens see them: coop_night mirrors sprites
## by their texture files), in whole game pixels: the shape near, a point far off, never
## smaller than two game pixels (one is lost in the dark: a dash, not eyes). They glow
## only in the dark; under a lamp you see the thing itself instead.
##
## The brain makes them (`enemy_base._make_eyes(style, height)`) and leaves them be: they
## follow `anchor` (its body; shown while it is) at `height` metres, and enemy_base sets
## `strength` from the dark round them and `flare` from your torch on them each tick.
## A brain can switch them off (`want = 0`), place them itself (`anchor = null`, `point`)
## or say where they are seen from (`view_from`, e.g. a window's camera).

const DIR := "res://assets/textury/npc/eyes/"
## Every enemy's eyes. near/mid/far: textures by distance (`near_m`, `mid_m`), `size` the
## real width of one in metres, `gap` from the middle to each, `color`, `blink` seconds
## between blinks (0: never; `both` together), `single` one eye only (`side_off` metres
## to the side), `glint` a light running over them now and then, `scan` metres of sway
## (looking for something), `flare_color` in your torch.
const STYLES := {
	# The Quiet Guy: his glasses. Two round lenses catching a dull yellow light that is
	# not there, no eye behind them, a little too far apart. They never blink.
	"silent_man": {"near": "eye_ring5", "mid": "eye_ring3", "far": "eye_dot2", "near_m": 9.0, "mid_m": 22.0,
		"size": 0.075, "gap": 0.072, "color": Color(0.96, 0.76, 0.22), "blink": 0.0, "glint": 4.0,
		"flare_color": Color(1.0, 0.97, 0.82)},
	# The Basket Man: two wet red points deep in the hood, close together, swinging slowly
	# side to side over the ground; it is looking for something that moves.
	"basket": {"near": "eye_dot2", "mid": "eye_dot2", "far": "eye_dot2", "near_m": 2.5, "mid_m": 99.0,
		"size": 0.03, "gap": 0.028, "color": Color(0.82, 0.16, 0.1), "blink": 9.0, "both": true, "scan": 0.05,
		"flare_color": Color(1.0, 0.35, 0.25)},
	# The Extra Child: nothing while its back is to you. When it turns: two white points,
	# small, wide open, that do not blink at all.
	"child": {"near": "eye_dot2", "mid": "eye_dot2", "far": "eye_dot2", "near_m": 2.0, "mid_m": 99.0,
		"size": 0.025, "gap": 0.03, "color": Color(0.96, 0.96, 1.0), "blink": 0.0,
		"flare_color": Color(1.0, 1.0, 1.0)},
	# The Antlered Man: deer eyeshine in the sockets of the skull, pale green, high up,
	# far apart; now and then both go out together, like something turning its head.
	"stalker": {"near": "eye_dot2", "mid": "eye_dot2", "far": "eye_dot2", "near_m": 4.0, "mid_m": 99.0,
		"size": 0.05, "gap": 0.07, "color": Color(0.55, 0.95, 0.62), "blink": 5.0, "both": true, "blink_len": 0.5,
		"flare_color": Color(0.85, 1.0, 0.85)},
	# The Photographer: one eye, and it is the lens: a cold ring with a light in it.
	"tourist": {"near": "eye_lens5", "mid": "eye_ring3", "far": "eye_dot2", "near_m": 9.0, "mid_m": 22.0,
		"size": 0.09, "gap": 0.0, "single": true, "color": Color(0.62, 0.78, 0.95), "blink": 0.0, "glint": 6.0,
		"flare_color": Color(0.92, 0.97, 1.0)},
	# The Whistler: two thin pale slits under a hat brim, high in the trees where the
	# tune was; they narrow and are gone.
	"whistler": {"near": "eye_slit5", "mid": "eye_slit5", "far": "eye_slit", "near_m": 9.0, "mid_m": 22.0,
		"size": 0.05, "gap": 0.05, "color": Color(0.72, 0.86, 0.9), "blink": 7.0, "both": true, "blink_len": 0.35,
		"flare_color": Color(0.95, 1.0, 1.0)},
}
## The game's picture is this many pixels high (nightmare_fx: cells of window/240).
const GAME_LINES := 240.0

var style: Dictionary = {}
var style_id := ""
var anchor: Node3D
var height := 1.6
## Where they are when there is no anchor.
var point := Vector3.INF
## 0..1: the dark round them (enemy_base), times `want` (the brain's own say).
var strength := 0.0
var want := 1.0
## Your torch on them: brighter, whiter.
var flare := 0.0
## Where on the head, as the art has it: metres to the right of the middle (seen from
## you), and the head's tilt (radians, + the right one lower).
var x_off := 0.0
var tilt := 0.0
## Seen from here instead of the camera (a window's camera); INF: the camera.
var view_from := Vector3.INF

var _eye: Array[Sprite3D] = []
var _tex := {}
var _rng := RandomNumberGenerator.new()
var _blink_next := [3.0, 3.0]
var _blink_t := [0.0, 0.0]
var _glint_next := 2.0
var _glint_t := -1.0
var _t := 0.0


func setup(id: String, h: float, follow: Node3D) -> void:
	style_id = id
	style = STYLES.get(id, STYLES["silent_man"])
	height = h
	anchor = follow
	name = "Eyes"
	_rng.randomize()
	for k in ["near", "mid", "far"]:
		var path: String = DIR + str(style[k]) + ".png"
		if ResourceLoader.exists(path):
			_tex[k] = load(path)
	var n := 1 if bool(style.get("single", false)) else 2
	for i in n:
		var s := Sprite3D.new()
		s.name = "Eye%d" % i
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.shaded = false
		s.double_sided = true
		s.render_priority = 2
		s.texture = _tex.get("far")
		s.visible = false
		s.set_meta("coop_tag", "eyes")
		add_child(s)
		_eye.append(s)
	for i in 2:
		_blink_next[i] = _rng.randf_range(1.0, maxf(1.5, float(style["blink"])))


## Each tick, after the brain's: place them for `cam` and show them or not.
func update(dt: float, cam: Camera3D) -> void:
	_t += dt
	var at := point
	if anchor != null:
		if not is_instance_valid(anchor) or not anchor.is_visible_in_tree():
			_hide()
			return
		at = anchor.global_position + Vector3(0, height, 0)
	var s := clampf(strength * want, 0.0, 1.0)
	if at == Vector3.INF or cam == null or s <= 0.02:
		_hide()
		return
	var from := cam.global_position if view_from == Vector3.INF else view_from
	var to := from - at
	var d := maxf(to.length(), 0.3)
	var flat := Vector3(to.x, 0.0, to.z)
	if flat.length() < 0.01:
		flat = Vector3(0, 0, 1)
	var toward := flat.normalized()
	var right := Vector3.UP.cross(toward).normalized()
	# One game pixel, there.
	var px := 2.0 * d * tan(deg_to_rad(cam.fov) * 0.5) / GAME_LINES
	var key := "near" if d <= float(style["near_m"]) else ("mid" if d <= float(style["mid_m"]) else "far")
	# Catching your light they swell, and keep their shape however far (a flash back at you).
	var fl := clampf(flare, 0.0, 1.0)
	if fl > 0.5 and key == "far":
		key = "mid"
	var tex: Texture2D = _tex.get(key, _tex.get("far"))
	if tex == null:
		_hide()
		return
	var tw := float(tex.get_width())
	# A texel a little over a game pixel: the screen's pixelation samples cell middles,
	# and a texel of exactly one cell can fall between them (a ring loses a side).
	var pix := maxf(float(style["size"]) / tw, px * 1.3)
	pix *= 1.0 + 0.45 * fl
	var w := tw * pix
	# Never closer than two dark game pixels between them, so two read as two.
	var gap := maxf(float(style["gap"]), w * 0.5 + px)
	var sway := sin(_t * 0.9) * float(style.get("scan", 0.0))
	# Well in front of its own sprite (the billboards turn differently; no clipping).
	var base := at + toward * minf(0.3, d * 0.08) + right * sway
	_update_blinks(dt)
	var glint := _glint(dt)
	var col: Color = (style["color"] as Color).lerp(style["flare_color"] as Color, fl)
	for i in _eye.size():
		var e := _eye[i]
		var side := 0.0 if _eye.size() == 1 else (-1.0 if i == 0 else 1.0)
		var open := float(_blink_t[0 if bool(style.get("both", false)) else i]) <= 0.0
		if not open:
			e.visible = false
			continue
		e.texture = tex
		e.pixel_size = pix
		e.global_position = base + right * (gap * side * cos(tilt) + x_off + float(style.get("side_off", 0.0))) - Vector3.UP * gap * side * sin(tilt)
		var c := col
		# The light running over the glass: one lens, then the other.
		if glint >= 0.0:
			var k := clampf(1.0 - absf(glint * 2.0 - (0.5 if i == 0 else 1.5)) * 1.6, 0.0, 1.0)
			c = c.lerp(Color(1.0, 0.98, 0.9), k * 0.8)
		c.a = s
		e.modulate = c
		e.visible = true


func _update_blinks(dt: float) -> void:
	var every := float(style["blink"])
	if every <= 0.0:
		return
	for i in 2:
		if _blink_t[i] > 0.0:
			_blink_t[i] -= dt
			continue
		_blink_next[i] -= dt
		if _blink_next[i] <= 0.0:
			_blink_t[i] = float(style.get("blink_len", 0.18))
			_blink_next[i] = _rng.randf_range(every * 0.5, every * 1.5)


## -1 none, else 0..1 through a glint.
func _glint(dt: float) -> float:
	var every := float(style.get("glint", 0.0))
	if every <= 0.0:
		return -1.0
	if _glint_t >= 0.0:
		_glint_t += dt / 0.6
		if _glint_t >= 1.0:
			_glint_t = -1.0
		return _glint_t
	_glint_next -= dt
	if _glint_next <= 0.0:
		_glint_next = _rng.randf_range(every * 0.6, every * 1.6)
		_glint_t = 0.0
	return -1.0


func _hide() -> void:
	for e in _eye:
		e.visible = false


## Are they showing now (any eye)? For the checks.
func shown() -> bool:
	for e in _eye:
		if e.visible:
			return true
	return false
