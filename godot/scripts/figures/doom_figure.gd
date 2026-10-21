extends RefCounted

## A person seen from eight sides, as in Doom (DESIGN.md "People as in Doom"): the
## person has a way they face (yaw), and which of their pictures you see depends on where
## you look at them from. Five views are drawn (1 front, 2 three-quarter front, 3 side,
## 4 three-quarter back, 5 back, all turned to the right of the picture); the other three
## are 4, 3 and 2 mirrored. The billboard still turns to you (FIXED_Y); only the picture
## changes. They walk and run in four frames a view, counted by the ground they cover
## (feet that do not slide), and stand in the frame of the view.
##
## The pictures of one person are one atlas, assets/textury/npc/sets/<name>.png, with its
## index <name>.json (tools/artgen/figures.py pack): {h: the standing sprite's height in
## pixels, anims: {anim: [views 1-5: [frames: [x, y, w, h, anchor x, anchor y]]]}}; the
## anchor is where they stand (their feet under the middle of their torso). A view an
## animation lacks shows the view standing; a person with no set yet keeps the old sprite
## from the front (set_of returns {}), so they go over one by one.
##
## Used by the guests (guest_agents.gd), the other wardens (coop/remote_player.gd), the
## hands in the businesses (business/crew_figures.gd) and the day's callers.

const SETS_DIR := "res://assets/textury/npc/sets/"
const SECTOR := PI / 4.0
## Past a sector's edge by this much before the view changes: walking along an edge (or a
## path's zigzag) does not flick between two views.
const HYSTERESIS := 0.12
## Ground covered per frame (metres): a walk's four frames are two steps.
const STRIDE := {"walk": 0.34, "run": 0.62}
## The idle's frames go at this many a second (the walk and run go by the ground).
const IDLE_FPS := 2.5

static var _sets: Dictionary = {}

var sprite: Sprite3D
var data: Dictionary
var tex: Texture2D
var height_m := 1.74
## Which way they face: forward is (-sin(yaw), 0, -cos(yaw)), like the player's body.
var yaw := 0.0
var anim := "stand"
var frame := 0
var _sector := 0
var _dist := 0.0
var _shown := ""
var _held := true
## An animation drawn at another size than standing (anim -> factor on the pixel size):
## the other warden stands a little small for their eyes to be at yours, but sits at full
## size to fit the furniture (remote_player.FIGURE_SCALE).
var anim_k: Dictionary = {}


## The set of the person whose sprite is `name` (host1, warden_a...), or {} without one.
static func set_of(name: String) -> Dictionary:
	if _sets.has(name):
		return _sets[name]
	var d := {}
	var jp := SETS_DIR + name + ".json"
	var tp := SETS_DIR + name + ".png"
	if ResourceLoader.exists(jp) and ResourceLoader.exists(tp):
		var j = load(jp)
		if j is JSON and (j as JSON).data is Dictionary:
			d = ((j as JSON).data as Dictionary).duplicate()
			d["tex"] = load(tp)
			d["name"] = name
	_sets[name] = d
	return d


## The set for a sprite's path (res://assets/textury/npc/host1.png -> host1).
static func set_for(path: String) -> Dictionary:
	return {} if path == "" else set_of(path.get_file().get_basename())


## The view (0 front .. 4 back) and whether it is mirrored, for someone facing `yaw` at
## `at`, seen from `eye`. `last` (a signed sector -3..4) is kept near its edges.
static func sector_for(at: Vector3, yaw_: float, eye: Vector3, last := 99) -> int:
	var to := Vector3(eye.x - at.x, 0.0, eye.z - at.z)
	if to.length_squared() < 0.0001:
		return last if last != 99 else 0
	to = to.normalized()
	# The camera's right as it looks at them: (-to) x up.
	var right := Vector3(to.z, 0.0, -to.x)
	var fwd := Vector3(-sin(yaw_), 0.0, -cos(yaw_))
	var ang := atan2(fwd.dot(right), fwd.dot(to))
	if last != 99:
		var off := wrapf(ang - float(last) * SECTOR, -PI, PI)
		if absf(off) < SECTOR * 0.5 + HYSTERESIS:
			return last
	var s := roundi(ang / SECTOR)
	return 4 if absi(s) >= 4 else s


func _init(p_sprite: Sprite3D, p_data: Dictionary, p_height_m := 1.74, p_tex: Texture2D = null) -> void:
	sprite = p_sprite
	data = p_data
	height_m = p_height_m
	tex = p_tex if p_tex != null else data.get("tex")
	sprite.set_meta("doom", self)
	restore()


## Back to this figure's pictures (after a pose of its own picture: sat at the fire).
func restore() -> void:
	_held = true
	sprite.texture = tex
	sprite.region_enabled = true
	sprite.centered = true
	sprite.pixel_size = height_m / float(data.get("h", 128))
	_shown = ""
	_apply()


## Someone else draws the sprite now (a pose with its own picture): hands off.
func release() -> void:
	if not _held:
		return
	_held = false
	sprite.region_enabled = false
	_shown = ""


func held() -> bool:
	return _held


## Another atlas for the same index (a warden's jacket in another colour).
func set_texture(t: Texture2D) -> void:
	tex = t
	if _held:
		sprite.texture = t


func has_anim(a: String) -> bool:
	return (data.get("anims", {}) as Dictionary).has(a)


## Facing along `dir` (only its flat part counts; a standstill keeps the last way).
func face(dir: Vector3) -> void:
	if Vector2(dir.x, dir.z).length_squared() > 0.000001:
		yaw = atan2(-dir.x, -dir.z)


## Turning toward `dir` by at most `max_rad` (a path's corners are walked round, not snapped).
func turn_toward(dir: Vector3, max_rad: float) -> void:
	if Vector2(dir.x, dir.z).length_squared() <= 0.000001:
		return
	var want := atan2(-dir.x, -dir.z)
	yaw += clampf(wrapf(want - yaw, -PI, PI), -max_rad, max_rad)


## Walk or run `metres` further (the frames go by the ground covered), or stand ("stand"),
## or another animation of the set at its own pace (`frame` set by the caller).
func set_anim(a: String) -> void:
	if a == anim:
		return
	if a != "stand" and not has_anim(a):
		a = "walk" if a == "run" and has_anim("walk") else "stand"
	anim = a
	frame = 0
	_dist = 0.0


func advance(metres: float) -> void:
	if not STRIDE.has(anim):
		return
	_dist += metres
	frame = int(_dist / float(STRIDE[anim])) % _frames_in(anim)


func _frames_in(a: String) -> int:
	var views: Array = (data.get("anims", {}) as Dictionary).get(a, [])
	var n := 1
	for v in views:
		n = maxi(n, (v as Array).size())
	return n


## The idle's frame from a clock (seconds into it); false when it has played through.
func idle_at(t: float) -> bool:
	var n := _frames_in(anim)
	var f := int(t * IDLE_FPS)
	frame = clampi(f, 0, n - 1)
	return f < n


## Picks the picture for where `eye` is (the camera), and puts it up.
func show(eye: Vector3) -> void:
	if not _held or not sprite.is_inside_tree():
		return
	_sector = sector_for(sprite.global_position, yaw, eye, _sector)
	_apply()


func _apply() -> void:
	var view := absi(_sector)
	var flip := _sector < 0
	var anims: Dictionary = data.get("anims", {})
	var fr = _frame_of(anims, anim, view, frame)
	if fr == null:
		fr = _frame_of(anims, "stand", view, 0)
	if fr == null:
		fr = _frame_of(anims, "stand", 0, 0)
	if fr == null:
		return
	var key := "%d|%d|%d|%d|%s|%s" % [fr[0], fr[1], fr[2], fr[3], flip, anim_k.get(anim, 1.0)]
	if key == _shown:
		return
	_shown = key
	sprite.pixel_size = height_m / float(data.get("h", 128)) * float(anim_k.get(anim, 1.0))
	var w := float(fr[2])
	var h := float(fr[3])
	sprite.region_rect = Rect2(float(fr[0]), float(fr[1]), w, h)
	sprite.flip_h = flip
	# The anchor (feet under the torso) on the node: the offset is not mirrored with the
	# picture, so it is turned round by hand.
	var ox := w * 0.5 - float(fr[4])
	sprite.offset = Vector2(-ox if flip else ox, float(fr[5]) - h * 0.5)


static func _frame_of(anims: Dictionary, a: String, view: int, n: int):
	var views: Array = anims.get(a, [])
	if view >= views.size():
		return null
	var frames: Array = views[view]
	if frames.is_empty():
		return null
	var fr = frames[n % frames.size()]
	return fr if fr is Array and (fr as Array).size() >= 6 else null


## Which view is up: 0 front .. 4 back, negative mirrored (tests and shots).
func sector() -> int:
	return _sector
