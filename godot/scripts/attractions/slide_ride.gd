extends Node3D

## The lake slide in use (made by building_models._slide(); the guests visiting it are
## placed and posed here through pose_member(), like at the campfire). Everyone goes
## round the same loop, one at a time on the ladder and in the chute:
##   queue   at the foot of the ladder, shuffling
##   climb   up the ladder, rung by rung (it creaks)
##   top     a look round from the platform
##   slide   sat in the chute, feet first, faster and faster (whoosh)
##   splash  into the pool: spray and rings, in up to the waist
##   wade    out over the rim and back round to the ladder
## Stepped at 12 frames a second; sounds from assets/sfx/life (ladder_creak,
## slide_whoosh, pool_splash).

const POSES = preload("res://scripts/attractions/poses.gd")
const FPS := 12.0
const SFX_CREAK := "res://assets/sfx/life/ladder_creak.mp3"
const SFX_WHOOSH := "res://assets/sfx/life/slide_whoosh.mp3"
const SFX_SPLASH := "res://assets/sfx/life/pool_splash.mp3"
const T_CLIMB := 2.4
const T_TOP := 0.9
const T_SLIDE := 1.25
const T_SPLASH := 0.7
const T_WADE := 1.7
const T_WALK := 2.6

var guests_here := 0

## member key -> {state, t0}
var _riders: Dictionary = {}
var _seen: Dictionary = {}
var _clock := 0.0
var _acc := 0.0
var _rng := RandomNumberGenerator.new()
## Who has the ladder and the chute (one at a time), -1 = free.
var _busy := -1

## The ride, local to this node's parent (the slide model), from the model's metas.
var _ladder_foot := Vector3(-2.2, 0, 0)
var _ladder_top := Vector3(-2.2, 3.2, 0)
var _deck := Vector3(-2.0, 3.2, 0)
var _chute: PackedVector3Array = PackedVector3Array()
var _pool := Vector3(2.6, 0, 0)
var _pool_r := 1.1
var _water: StandardMaterial3D

var _drops: Array = []        # [{node, v}]
var _rings: Array = []        # [{node, t}]
var _audio: AudioStreamPlayer3D
var _drop_mat: StandardMaterial3D
var _ring_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("attraction")
	_rng.randomize()
	call_deferred("_setup")


func _setup() -> void:
	var r := get_parent()
	if r.has_meta("slide_chute"):
		_chute = r.get_meta("slide_chute")
	if r.has_meta("slide_ladder"):
		var l: Array = r.get_meta("slide_ladder")
		_ladder_foot = l[0]
		_ladder_top = l[1]
		_deck = l[2]
	if r.has_meta("slide_pool"):
		var pl: Array = r.get_meta("slide_pool")
		_pool = pl[0]
		_pool_r = float(pl[1])
	var water := r.get_node_or_null("PoolWater") as MeshInstance3D
	if water != null:
		_water = water.material_override as StandardMaterial3D
	_audio = AudioStreamPlayer3D.new()
	_audio.unit_size = 6.0
	_audio.max_distance = 40.0
	add_child(_audio)
	_drop_mat = StandardMaterial3D.new()
	_drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_drop_mat.albedo_color = Color(0.86, 0.94, 1.0, 0.9)
	_drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_drop_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.albedo_color = Color(0.9, 0.96, 1.0, 0.5)
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func covers_tile(tile: Vector2i) -> bool:
	var r: Node = get_parent()
	while r != null and not r.has_meta("grid_origin"):
		r = r.get_parent()
	if r == null:
		return false
	var o: Vector2i = r.get_meta("grid_origin")
	var fp_any = r.get_meta("grid_footprint", Vector2i.ONE)
	var fp: Vector2i = fp_any if fp_any is Vector2i else Vector2i.ONE
	return tile.x >= o.x and tile.y >= o.y and tile.x < o.x + fp.x and tile.y < o.y + fp.y


func pose_member(guest_id: int, i: int, _n: int, member: Node3D, sprite: Sprite3D, info: Dictionary, _t: float) -> bool:
	if _chute.size() < 2:
		return false
	var key := guest_id * 10 + i
	if not _riders.has(key):
		_riders[key] = {"state": "queue", "t0": _clock, "slot": _riders.size()}
	_seen[key] = _clock
	var rd: Dictionary = _riders[key]
	var k := clampf((_clock - float(rd["t0"])) / _dur(str(rd["state"])), 0.0, 1.0)
	var pos := Vector3.ZERO
	var pose := ""
	var ground := true
	var sink := 0.0
	var parent := get_parent() as Node3D
	match str(rd["state"]):
		"queue":
			var slot := _queue_slot(key)
			pos = _ladder_foot + Vector3(-0.55 - 0.5 * float(slot), 0, 0.25 * float(slot % 2) - 0.1)
			pos.x += sin(_clock * 1.3 + float(key)) * 0.04
		"climb":
			var rung := floorf(k * 7.0) / 7.0
			pos = _ladder_foot.lerp(_ladder_top, rung) + Vector3(-0.18, 0, 0)
			ground = false
		"top":
			pos = _ladder_top.lerp(_deck, clampf(k * 2.0, 0.0, 1.0))
			ground = false
		"slide":
			pos = _along_chute(k * k * 0.55 + k * 0.45)
			pose = "sit"
			ground = false
		"splash":
			pos = _pool + Vector3(-0.25, 0, 0)
			sink = 0.6 - k * 0.15
		"wade":
			var out := _pool + Vector3(0, 0, _pool_r + 0.45)
			pos = (_pool + Vector3(-0.25, 0, 0)).lerp(out, k)
			sink = maxf(0.0, 0.45 * (1.0 - k * 1.4))
		"out":
			# A warden off the ride: stood on the rim, done (warden_play gets them up).
			pos = _pool + Vector3(0, 0, _pool_r + 0.45)
		"walk":
			var from := _pool + Vector3(0, 0, _pool_r + 0.45)
			var to := _ladder_foot + Vector3(-0.55, 0, 0.6)
			pos = from.lerp(to, k)
			pos.y = absf(sin(_clock * 9.0)) * 0.05
	member.global_position = parent.to_global(pos - Vector3(0, sink, 0))
	member.set_meta("marker_drop", -0.42 if pose == "sit" else 0.0)
	POSES.set_pose(sprite, str(info.get("sprite_path", "")), pose)
	if sprite != null:
		sprite.flip_h = str(rd["state"]) == "walk"
		sprite.rotation.z = 0.0
	var sh := member.get_node_or_null("BlobShadow") as Node3D
	if sh != null:
		sh.visible = ground and sink <= 0.0
	return true


func _dur(state: String) -> float:
	match state:
		"climb": return T_CLIMB
		"top": return T_TOP
		"slide": return T_SLIDE
		"splash": return T_SPLASH
		"wade": return T_WADE
		"walk": return T_WALK
	return 9999.0


func _queue_slot(key: int) -> int:
	var waiting: Array = []
	for k in _riders.keys():
		if str(_riders[k]["state"]) == "queue":
			waiting.append(k)
	waiting.sort_custom(func(a, b) -> bool: return float(_riders[a]["t0"]) < float(_riders[b]["t0"]))
	return maxi(0, waiting.find(key))


## A point down the chute, `f` 0 (top) .. 1 (the lip over the pool), on its centre line.
func _along_chute(f: float) -> Vector3:
	var n := _chute.size() - 1
	var x := clampf(f, 0.0, 1.0) * float(n)
	var i := mini(int(floor(x)), n - 1)
	return _chute[i].lerp(_chute[i + 1], x - float(i)) + Vector3(0, 0.08, 0)


func _process(delta: float) -> void:
	_clock += delta
	_acc += delta
	_tick_spray(delta)
	if _water != null:
		_water.uv1_offset = Vector3(fmod(_clock * 0.03, 1.0), 0, fmod(_clock * 0.017, 1.0))
	if _acc < 1.0 / FPS:
		return
	_acc = 0.0
	for key in _seen.keys():
		if _clock - float(_seen[key]) > 1.0:
			_seen.erase(key)
			_riders.erase(key)
			if _busy == key:
				_busy = -1
	guests_here = _seen.keys().filter(func(k): return int(k) >= 0).size()
	_advance()


## Everyone a step on round the loop; the ladder and the chute take one at a time.
func _advance() -> void:
	for key in _riders.keys():
		var rd: Dictionary = _riders[key]
		var st := str(rd["state"])
		var done := _clock - float(rd["t0"]) >= _dur(st)
		match st:
			"queue":
				if _busy < 0 and _queue_slot(key) == 0:
					_busy = key
					_to_state(rd, "climb")
					_play(SFX_CREAK, -12.0, _rng.randf_range(0.9, 1.1), _ladder_foot + Vector3(0, 1.4, 0))
			"climb":
				if done:
					_to_state(rd, "top")
			"top":
				# A warden pushes off when they will (LMB), or soon anyway.
				if done and (int(key) >= 0 or bool(_push.get(key, false)) or _clock - float(rd["t0"]) > 6.0):
					_push.erase(key)
					_to_state(rd, "slide")
					_play(SFX_WHOOSH, -6.0, _rng.randf_range(0.92, 1.08), _chute[_chute.size() >> 1])
			"slide":
				if done:
					_to_state(rd, "splash")
					_busy = -1
					_splash()
			"splash":
				if done:
					_to_state(rd, "wade")
			"wade":
				if done:
					_to_state(rd, "out" if int(key) < 0 else "walk")
			"walk":
				if done:
					_to_state(rd, "queue")


func _to_state(rd: Dictionary, state: String) -> void:
	rd["state"] = state
	rd["t0"] = _clock


## Into the pool: a burst of spray and a ring going out across the water.
func _splash() -> void:
	_play(SFX_SPLASH, -4.0, _rng.randf_range(0.9, 1.1), _pool)
	var parent := get_parent() as Node3D
	for i in 16:
		var d := MeshInstance3D.new()
		var q := QuadMesh.new()
		var s := _rng.randf_range(0.05, 0.11)
		q.size = Vector2(s, s)
		d.mesh = q
		d.material_override = _drop_mat
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(d)
		d.position = _pool + Vector3(-0.25, 0.1, 0)
		var a := _rng.randf() * TAU
		var sp := _rng.randf_range(0.8, 2.2)
		_drops.append({"node": d, "v": Vector3(cos(a) * sp, _rng.randf_range(2.2, 4.2), sin(a) * sp)})
	for j in 2:
		var ring := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 0.18
		tor.outer_radius = 0.24
		tor.rings = 12
		tor.ring_segments = 3
		ring.mesh = tor
		ring.material_override = _ring_mat
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.scale = Vector3(1, 0.05, 1)
		parent.add_child(ring)
		ring.position = _pool + Vector3(-0.25, 0.08, 0)
		_rings.append({"node": ring, "t": -0.25 * float(j)})


func _tick_spray(delta: float) -> void:
	for d in _drops:
		var n := d["node"] as Node3D
		var v: Vector3 = d["v"]
		v.y -= 9.0 * delta
		d["v"] = v
		n.position += v * delta
	for d in _drops:
		if (d["node"] as Node3D).position.y < 0.05:
			(d["node"] as Node3D).queue_free()
	_drops = _drops.filter(func(d: Dictionary) -> bool: return is_instance_valid(d["node"]) and (d["node"] as Node3D).position.y >= 0.05)
	for r in _rings:
		r["t"] = float(r["t"]) + delta
		var n2 := r["node"] as Node3D
		var t := float(r["t"])
		n2.visible = t > 0.0
		var g := 1.0 + maxf(0.0, t) * 3.2
		n2.scale = Vector3(g, 0.05, g)
	for r in _rings:
		if float(r["t"]) > 1.1:
			(r["node"] as Node3D).queue_free()
	_rings = _rings.filter(func(r: Dictionary) -> bool: return float(r["t"]) <= 1.1)


func _play(path: String, db: float, pitch: float, at: Vector3) -> void:
	if _audio == null or not ResourceLoader.exists(path):
		return
	_audio.stream = load(path)
	_audio.volume_db = db
	_audio.pitch_scale = pitch
	_audio.global_position = (get_parent() as Node3D).to_global(at)
	_audio.play()


# ── a warden on the slide (scripts/attractions/warden_play.gd) ───────────────

## Warden key -> they pushed off from the top (LMB).
var _push: Dictionary = {}


func _g(local: Vector3) -> Vector3:
	return (get_parent() as Node3D).to_global(local)


func _state_of(key: int) -> String:
	return str(_riders[key]["state"]) if _riders.has(key) else ""


func warden_offer(at: Vector3) -> Dictionary:
	if _chute.size() < 2:
		return {}
	var foot := _g(_ladder_foot)
	var d := Vector2(at.x - foot.x, at.z - foot.z).length()
	return {"verb": "Go down the slide", "act": "join", "d": d} if d < 2.2 else {}


func warden_join(key: int, _at: Vector3) -> bool:
	_riders[key] = {"state": "queue", "t0": _clock, "slot": _riders.size()}
	_seen[key] = _clock
	return true


func warden_slot(_key: int) -> int:
	return 0


## The other machine's warden: where they are on the ride there.
func warden_force(key: int, _slot: int, x: Dictionary) -> void:
	var st := str(x.get("st", ""))
	if st == "" or _chute.size() < 2:
		return
	if not _riders.has(key):
		_riders[key] = {"state": st, "t0": _clock, "slot": 0}
	var rd: Dictionary = _riders[key]
	if str(rd["state"]) != st:
		rd["state"] = st
		rd["t0"] = _clock - clampf(float(x.get("k", 0.0)), 0.0, 1.0) * minf(_dur(st), 30.0)
		if st in ["climb", "top", "slide"]:
			_busy = key
		elif _busy == key:
			_busy = -1
		if st == "slide":
			_play(SFX_WHOOSH, -6.0, 1.0, _chute[_chute.size() >> 1])
		elif st == "splash":
			_splash()


func warden_extra(key: int) -> Dictionary:
	if not _riders.has(key):
		return {}
	var st := _state_of(key)
	return {"st": st, "k": clampf((_clock - float(_riders[key]["t0"])) / minf(_dur(st), 30.0), 0.0, 1.0)}


func warden_leave(key: int) -> void:
	_riders.erase(key)
	_seen.erase(key)
	_push.erase(key)
	if _busy == key:
		_busy = -1


func warden_done(key: int) -> bool:
	return _state_of(key) == "out"


## Halfway up or down there is no getting off.
func warden_hold(key: int) -> bool:
	return _state_of(key) in ["climb", "top", "slide", "splash"]


func warden_exit(key: int) -> Vector3:
	if _state_of(key) in ["queue", ""]:
		return _g(_ladder_foot + Vector3(-0.9, 0, 0.6))
	return _g(_pool + Vector3(0, 0, _pool_r + 0.6))


func warden_focus(key: int) -> Vector3:
	var rd: Dictionary = _riders.get(key, {})
	match str(rd.get("state", "")):
		"queue":
			return _g(_ladder_top)
		"climb":
			return _g(_ladder_top + Vector3(1.6, 0.4, 0))
		"top":
			return _g(_chute[_chute.size() - 1])
		"slide":
			var k := clampf((_clock - float(rd["t0"])) / T_SLIDE, 0.0, 1.0)
			return _g(_along_chute(minf(1.0, k + 0.35)) + Vector3(0, -0.2, 0)) if k < 0.7 else _g(_pool)
	return _g(_pool + Vector3(0, 0.4, _pool_r + 4.0))


func warden_press(key: int) -> String:
	if _state_of(key) == "top":
		_push[key] = true
		return "push"
	return ""


func warden_pose(key: int, base: String) -> String:
	return "climb" if _state_of(key) == "climb" else base


func warden_hint(key: int) -> String:
	return "[LMB] Go" if _state_of(key) == "top" else ""
