extends RefCounted

## More than one in the pipes (co-op, scripts/sewer_pipe_minigame.gd): the other wardens
## crawling the same network (the same seed and the same raccoon as whoever climbed down
## first), each seen where they are, lying flat:
##   - from behind (the soles of their boots in your torchlight) when they crawl away
##     from you, from the front (their torch in your eyes, their face) when they come
##     at you, from the side across a junction;
##   - their body fills the pipe: you cannot crawl into the pipe one of them is in, nor
##     onto the junction they lie at. Head to head, one of you backs up (tap S: feet
##     first, slowly, back the way you came); with four down there, a jam;
##   - close, the pipe shrinks: your breath and heart go up, the dark closes in round the
##     view; crawling into one knocks their boots or their head (they jump at their end:
##     Coop.send_play "pipe_bump", to them);
##   - a hole clamped by one is clamped for all ("pipe_fixed").
## Each machine keeps its own raccoon (one may see it, the others not).

const LOOKS = preload("res://scripts/coop/warden_looks.gd")
## The wardens' pixel in the world (a standing one: 128 px for 1.74 m): the pictures of
## them lying are drawn to it, as everything is (the same Build-engine pixel throughout).
const PIXEL := 1.74 / 128.0
const SQUEEZE_FAR := 2.4

var host                 # the minigame
var key := ""            # the sewer, "x:y"
var squeeze := 0.0       # 0 nobody near .. 1 face to boots
## Who you last crawled into (peer id), for the line and the knock.
var blocker := 0
var _sprites: Dictionary = {}   # peer id -> Sprite3D
var _poses: Dictionary = {}     # peer id -> the pose shown
var _bump_cd := 0.0


## Mine, for the other machines (main.coop_local_warden "pipe").
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


## Every other warden down the same sewer: peer id -> their pipe state.
func mates() -> Dictionary:
	var out := {}
	if key == "":
		return out
	for id in Coop.others():
		var s = Coop.state_of(id).get("pipe", {})
		if s is Dictionary and str(s.get("k", "")) == key:
			out[int(id)] = s
	return out


## One of them ({} none): the one you crawled into last, else the first down there.
func mate() -> Dictionary:
	var all := mates()
	if all.has(blocker):
		return all[blocker]
	for id in all.keys():
		return all[id]
	return {}


static func _cell(a) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1])) if a is Array and a.size() >= 2 else Vector2i(-99, -99)


## Would crawling from `a` to `b` run into one of them? A body fills the pipe it is in
## (either way along it) and the junction it lies at. Who it is goes to `blocker`.
func blocks(a: Vector2i, b: Vector2i) -> bool:
	var all := mates()
	for id in all.keys():
		var m: Dictionary = all[id]
		var n := _cell(m.get("n"))
		var to := _cell(m.get("to"))
		var hit := false
		if n == to:
			hit = n == b
		elif (n == a and to == b) or (n == b and to == a):
			hit = true
		else:
			hit = to == b
		if hit:
			blocker = int(id)
			return true
	return false


## Where they are in the pipes (the floor of the pipe under them).
func _pos(m: Dictionary) -> Vector3:
	var a: Vector3 = host._world_pos(_cell(m.get("n")))
	var b: Vector3 = host._world_pos(_cell(m.get("to")))
	var p := a.lerp(b, clampf(float(m.get("t", 0.0)), 0.0, 1.0))
	p.y = 0.0
	return p


func update(delta: float) -> void:
	_bump_cd = maxf(0.0, _bump_cd - delta)
	var all := mates()
	for id in _sprites.keys():
		if not all.has(id):
			_drop(id)
	squeeze = 0.0
	for id in all.keys():
		squeeze = maxf(squeeze, _show(int(id), all[id]))


## One of them in the pipe; how close they are (the squeeze, 0..1).
func _show(id: int, m: Dictionary) -> float:
	var sp: Sprite3D = _sprites.get(id)
	if sp == null or not is_instance_valid(sp) or sp.get_parent() != host._world:
		sp = Sprite3D.new()
		sp.name = "OtherWarden_%d" % id
		sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sp.shaded = true
		sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sp.pixel_size = PIXEL
		host._world.add_child(sp)
		_sprites[id] = sp
		_poses.erase(id)
	var pos := _pos(m)
	var me: Vector3 = host._rig.position
	var to_them := Vector3(pos.x - me.x, 0.0, pos.z - me.z)
	var dist := to_them.length()
	var d: Vector2i = host.DIRS[clampi(int(m.get("f", 0)), 0, 3)]
	var their_dir := Vector3(d.x, 0.0, d.y)
	var c := their_dir.dot(to_them.normalized()) if dist > 0.05 else 1.0
	var pose := "crawl_back" if c > 0.5 else ("crawl_front" if c < -0.5 else "crawl_side")
	var look: Dictionary = Coop.look_of(id)
	var model := int(look.get("m", 1))
	if not LOOKS.has_pose(model, pose):
		pose = "prone"
	if pose != str(_poses.get(id, "")):
		_poses[id] = pose
		var tex: Texture2D = LOOKS.texture(model, int(look.get("c", 0)), pose)
		sp.texture = tex
		if tex != null:
			sp.offset = Vector2(0.0, tex.get_height() * 0.5)
	if pose in ["crawl_side", "prone"]:
		# Facing the way they crawl, across your view.
		var right: Vector3 = host._camera.global_basis.x
		sp.flip_h = their_dir.dot(right) < 0.0
	# A pull in steps as they go.
	var going := _cell(m.get("n")) != _cell(m.get("to"))
	sp.position = pos + Vector3(0.0, 0.02 if going and int(Time.get_ticks_msec() / 220) % 2 == 0 else 0.0, 0.0)
	sp.visible = true
	return clampf(1.0 - dist / SQUEEZE_FAR, 0.0, 1.0)


## You crawled into one of them: their boots in your face (or yours in theirs). Once in a
## while it is told at their end.
func bumped_into() -> void:
	if _bump_cd > 0.0:
		return
	_bump_cd = 2.5
	Coop.send_play("pipe_bump", [key, blocker])


func _drop(id: int) -> void:
	var sp = _sprites.get(id)
	if sp != null and is_instance_valid(sp):
		sp.queue_free()
	_sprites.erase(id)
	_poses.erase(id)


func clear() -> void:
	for id in _sprites.keys():
		_drop(id)
	squeeze = 0.0
	blocker = 0
