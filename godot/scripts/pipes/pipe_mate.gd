extends RefCounted

## Two in the pipes (co-op, scripts/sewer_pipe_minigame.gd): the other warden crawling
## the same network (the same seed and the same raccoon as whoever climbed down first),
## seen where they are, lying flat:
##   - from behind (the soles of their boots in your torchlight) when they crawl away
##     from you, from the front (their torch in your eyes, their face) when they come
##     at you, from the side across a junction;
##   - their body fills the pipe: you cannot crawl into the pipe they are in, nor onto
##     the junction they lie at. Head to head, one of you backs up (tap S: feet first,
##     slowly, back the way you came);
##   - close, the pipe shrinks: your breath and heart go up, the dark closes in round the
##     view; crawling into them knocks their boots or their head (they jump at their end:
##     Coop.send_play "pipe_bump");
##   - a hole clamped by one is clamped for both ("pipe_fixed").
## Each machine keeps its own raccoon (one may see it, the other not).

const LOOKS = preload("res://scripts/coop/warden_looks.gd")
## How tall they are lying in the pipe, seen from in front or behind (m), how long seen
## from the side.
const LYING_H := 0.6
const LYING_LEN := 1.7
const LYING_W := 0.8
const SQUEEZE_FAR := 2.4

var host                 # the minigame
var key := ""            # the sewer, "x:y"
var squeeze := 0.0       # 0 nobody near .. 1 face to boots
var _sprite: Sprite3D
var _pose := ""
var _bump_cd := 0.0


## Mine, for the other machine (main.coop_local_warden "pipe").
func state() -> Dictionary:
	if host == null or not bool(host._active):
		return {}
	var moving: bool = host._moving or host._at_leak
	var to: Vector2i = host._move_target_node if moving else host._node
	var t: float = host._crawl_progress(host._move_t) if moving else 0.0
	if bool(host.get("_backing")):
		t = 1.0 - t
	return {"k": key, "n": [host._node.x, host._node.y], "to": [to.x, to.y], "t": snappedf(t, 0.02), "f": int(host._facing),
		"lv": int(host.raccoon_level), "sd": int(host.get("_since_day"))}


## Theirs, if they are down the same sewer ({} not).
func mate() -> Dictionary:
	if not Coop.has_partner():
		return {}
	var s = Coop.partner_state.get("pipe", {})
	return s if s is Dictionary and str(s.get("k", "")) == key and key != "" else {}


static func _cell(a) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1])) if a is Array and a.size() >= 2 else Vector2i(-99, -99)


## Would crawling from `a` to `b` run into them? Their body fills the pipe they are in
## (either way along it) and the junction they lie at.
func blocks(a: Vector2i, b: Vector2i) -> bool:
	var m := mate()
	if m.is_empty():
		return false
	var n := _cell(m.get("n"))
	var to := _cell(m.get("to"))
	if n == to:
		return n == b
	if (n == a and to == b) or (n == b and to == a):
		return true
	return to == b


## Where they are in the pipes (the floor of the pipe under them).
func _pos(m: Dictionary) -> Vector3:
	var a: Vector3 = host._world_pos(_cell(m.get("n")))
	var b: Vector3 = host._world_pos(_cell(m.get("to")))
	var p := a.lerp(b, clampf(float(m.get("t", 0.0)), 0.0, 1.0))
	p.y = 0.0
	return p


func update(delta: float) -> void:
	_bump_cd = maxf(0.0, _bump_cd - delta)
	var m := mate()
	if m.is_empty():
		if _sprite != null and is_instance_valid(_sprite):
			_sprite.visible = false
		squeeze = 0.0
		return
	if _sprite == null or not is_instance_valid(_sprite) or _sprite.get_parent() != host._world:
		_sprite = Sprite3D.new()
		_sprite.name = "OtherWarden"
		_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		_sprite.shaded = true
		_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		host._world.add_child(_sprite)
	var pos := _pos(m)
	var me: Vector3 = host._rig.position
	var to_them := Vector3(pos.x - me.x, 0.0, pos.z - me.z)
	var dist := to_them.length()
	var d: Vector2i = host.DIRS[clampi(int(m.get("f", 0)), 0, 3)]
	var their_dir := Vector3(d.x, 0.0, d.y)
	var c := their_dir.dot(to_them.normalized()) if dist > 0.05 else 1.0
	var pose := "crawl_back" if c > 0.5 else ("crawl_front" if c < -0.5 else "crawl_side")
	var look: Dictionary = Coop.partner_look
	var model := int(look.get("m", 1))
	if not LOOKS.has_pose(model, pose):
		pose = "prone"
	if pose != _pose:
		_pose = pose
		var tex: Texture2D = LOOKS.texture(model, int(look.get("c", 0)), pose)
		_sprite.texture = tex
		if tex != null:
			var side := pose in ["crawl_side", "prone"]
			# From in front or behind no wider than the pipe (an arm flung out).
			_sprite.pixel_size = (LYING_LEN / float(tex.get_width())) if side else minf(LYING_H / float(tex.get_height()), LYING_W / float(tex.get_width()))
			_sprite.offset = Vector2(0.0, tex.get_height() * 0.5)
	if _pose in ["crawl_side", "prone"]:
		# Facing the way they crawl, across your view.
		var right: Vector3 = host._camera.global_basis.x
		_sprite.flip_h = their_dir.dot(right) < 0.0
	# A pull in steps as they go.
	var going := _cell(m.get("n")) != _cell(m.get("to"))
	_sprite.position = pos + Vector3(0.0, 0.02 if going and int(Time.get_ticks_msec() / 220) % 2 == 0 else 0.0, 0.0)
	_sprite.visible = true
	squeeze = clampf(1.0 - dist / SQUEEZE_FAR, 0.0, 1.0)


## You crawled into them: their boots in your face (or yours in theirs). Once in a while
## it is told at their end.
func bumped_into() -> void:
	if _bump_cd > 0.0:
		return
	_bump_cd = 2.5
	Coop.send_play("pipe_bump", [key])


func clear() -> void:
	if _sprite != null and is_instance_valid(_sprite):
		_sprite.queue_free()
	_sprite = null
	_pose = ""
	squeeze = 0.0
