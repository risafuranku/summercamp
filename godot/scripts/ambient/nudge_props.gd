extends Node3D

## Things you nudge with your foot: an empty beer bottle by the fire, a bench or the pub, a
## can by a tent, a caravan or the bistro's bins, a zinc bucket by the washrooms, spruce
## cones under the camp's trees (Grok, 1 cm a pixel: world/kick_*.png). Walk into one and
## it goes: the bottle and the can skitter off and roll on, a cone hops away, the bucket
## clangs and shifts a little; off a wall it bounces back. Every warden's feet do it (the
## other wardens' figures too, so each machine plays the same kicks without a word on the
## wire), in steps like everything else (twelve a second), with its sound (ElevenLabs
## world/kick_*). Where they lie comes from where the buildings and the trees stand, so
## every machine lays them alike; kicked, they stay where they stopped until the camp is
## loaded again.

const FPS := 12.0
const TEX := "res://assets/textury/world/"
const SFX := "res://assets/sfx/world/"
## A kind: its picture; its radius (m); how fast a kick sends it (per m/s of your walk);
## its hop (m/s); how fast it stops on the ground (m/s each second); whether it rolls
## (its picture turns over while it goes); its sounds; their volume (dB).
const KINDS := {
	"bottle": {"tex": "kick_bottle.png", "r": 0.13, "push": 0.55, "hop": 0.6, "drag": 3.2, "roll": true, "sfx": ["kick_bottle_a", "kick_bottle_b"], "db": -8.0},
	"can": {"tex": "kick_can.png", "r": 0.09, "push": 0.7, "hop": 1.1, "drag": 3.0, "roll": true, "sfx": ["kick_can_a", "kick_can_b"], "db": -8.0},
	"bucket": {"tex": "kick_bucket.png", "r": 0.17, "push": 0.3, "hop": 0.0, "drag": 6.0, "roll": false, "sfx": ["kick_bucket"], "db": -6.0},
	"cone": {"tex": "kick_cone.png", "r": 0.06, "push": 0.55, "hop": 0.9, "drag": 3.5, "roll": true, "sfx": ["kick_cone"], "db": -14.0},
	# Since 21. 10. (scripts/ambient/carry.gd): a stone and a log to pick up and throw, the
	# rubbish sack you bagged and set down (the day's litter, mess/litter_binbag.png).
	"stone": {"tex": "kick_stone.png", "r": 0.07, "push": 0.25, "hop": 0.3, "drag": 5.0, "roll": false, "sfx": ["kick_cone"], "db": -9.0, "pitch": 0.7},
	"log": {"tex": "kick_log.png", "r": 0.12, "push": 0.2, "hop": 0.2, "drag": 5.5, "roll": true, "sfx": ["kick_cone"], "db": -7.0, "pitch": 0.55},
	"sack": {"tex": "res://assets/textury/mess/litter_binbag.png", "r": 0.26, "push": 0.12, "hop": 0.0, "drag": 7.0, "roll": false, "sfx": ["kick_cone"], "db": -16.0, "pitch": 0.45, "px": 0.0117},
}
## What lies by a building, by the start of its type: [kind, chance] each.
const BY_TYPE := [
	["bonfire", [["bottle", 1.0], ["bottle", 0.7], ["can", 0.6], ["log", 0.9], ["log", 0.6], ["stone", 0.8]]],
	["bench", [["bottle", 0.4]]],
	["picnic_table", [["bottle", 0.5], ["can", 0.4]]],
	["pub", [["bottle", 0.9], ["bottle", 0.6], ["can", 0.5]]],
	["restaurant", [["can", 0.8]]],
	["toilet_block", [["bucket", 0.9]]],
	["shower_block", [["bucket", 0.7]]],
	["tent", [["can", 0.35]]],
	["cabin", [["bucket", 0.3], ["bottle", 0.25]]],
	["caravan", [["can", 0.4]]],
]
## A tree this near a building has a cone or two under it (the camp's trees, not the forest).
const CONE_TREE_NEAR := 9.0
const FOOT := 0.22               # how far past a thing's edge your foot reaches it

var player_getter: Callable

var _props: Array = []           # {node: Sprite3D, kind, pos, vel, cool, by (building id or -1)}
var _laid: Dictionary = {}       # building id -> true once its things are laid
var _trees_laid := false
var _feet: Dictionary = {}       # warden id -> last position
var _walls: Array = []           # Rect2 (x, z) of every building's footprint, outgrown 2 cm
var _tex: Dictionary = {}
var _snd: Array = []
var _snd_i := 0
var _acc := 0.0
var _scan := 0.0


func _ready() -> void:
	name = "NudgeProps"
	for i in 3:
		var p := AudioStreamPlayer3D.new()
		p.bus = "OutdoorAmbience" if AudioServer.get_bus_index("OutdoorAmbience") >= 0 else "Master"
		p.unit_size = 2.0
		p.max_distance = 20.0
		add_child(p)
		_snd.append(p)


func _process(delta: float) -> void:
	_acc += delta
	if _acc < 1.0 / FPS:
		return
	var dt := _acc
	_acc = 0.0
	_scan -= dt
	if _scan <= 0.0:
		_scan = 3.0
		_lay()
	_kicks(dt)
	_move(dt)


# ── laying them out ──────────────────────────────────────────────────────────

func _structures() -> Array:
	var main := get_tree().current_scene
	var bm = main.get("building_manager") if main != null else null
	var s: Node = bm.get_node_or_null("Structures") if bm != null else null
	return s.get_children() if s != null else []


## The things by each new building, the walls they bounce off; the cones under the camp's
## trees once there are buildings to tell which trees are the camp's.
func _lay() -> void:
	var live: Dictionary = {}
	_walls.clear()
	var spots: Array = []
	for c in _structures():
		if not (c is Node3D) or str(c.get_meta("building_type", "")) == "":
			continue
		var s := c as Node3D
		var box := _footprint(s)
		if box.size.y < 0.3:
			continue
		var g: AABB = s.global_transform * box
		_walls.append(Rect2(g.position.x - 0.02, g.position.z - 0.02, g.size.x + 0.04, g.size.z + 0.04))
		spots.append(s.global_position)
		live[s.get_instance_id()] = true
	for c in _structures():
		if c is Node3D and live.has(c.get_instance_id()) and not _laid.has(c.get_instance_id()):
			_laid[c.get_instance_id()] = true
			_lay_by(c as Node3D)
	# A building pulled down takes its things with it (those still where they lay).
	for id in _laid.keys():
		if not live.has(id):
			_laid.erase(id)
			for p in _props:
				if int(p["by"]) == id and (p["vel"] as Vector3).is_zero_approx() and not bool(p["kicked"]):
					(p["node"] as Node).queue_free()
			_props = _props.filter(func(p): return is_instance_valid(p["node"]) and not (p["node"] as Node).is_queued_for_deletion())
	if not _trees_laid and not spots.is_empty():
		_trees_laid = true
		for t in get_tree().get_nodes_in_group("trees"):
			if t is Node3D:
				_lay_cones(t as Node3D, spots)


func _rng_at(p: Vector3, salt: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%s %d %d" % [salt, roundi(p.x * 10.0), roundi(p.z * 10.0)])
	return r


func _lay_by(s: Node3D) -> void:
	var bt := str(s.get_meta("building_type", ""))
	var what: Array = []
	for row in BY_TYPE:
		if bt.begins_with(str(row[0])):
			what = row[1]
			break
	if what.is_empty():
		return
	var rng := _rng_at(s.global_position, bt)
	var box := _footprint(s)
	for w in what:
		if rng.randf() > float(w[1]):
			continue
		# Just outside one of its sides, somewhere along it.
		for attempt in 6:
			var side := rng.randi() % 4
			var out := rng.randf_range(0.25, 0.7)
			var along := rng.randf_range(0.1, 0.9)
			var lp := Vector3.ZERO
			match side:
				0: lp = Vector3(lerpf(box.position.x, box.end.x, along), 0, box.end.z + out)
				1: lp = Vector3(lerpf(box.position.x, box.end.x, along), 0, box.position.z - out)
				2: lp = Vector3(box.end.x + out, 0, lerpf(box.position.z, box.end.z, along))
				_: lp = Vector3(box.position.x - out, 0, lerpf(box.position.z, box.end.z, along))
			var gp := s.global_transform * lp
			gp.y = 0.0
			if not _in_wall(gp, 0.15):
				_add(str(w[0]), gp, s.get_instance_id(), rng)
				break


func _lay_cones(t: Node3D, spots: Array) -> void:
	var tp := t.global_position
	var near := false
	for sp in spots:
		if Vector2((sp as Vector3).x - tp.x, (sp as Vector3).z - tp.z).length() < CONE_TREE_NEAR:
			near = true
			break
	if not near:
		return
	var rng := _rng_at(tp, "cone")
	for i in rng.randi_range(0, 2):
		var a := rng.randf() * TAU
		var gp := tp + Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.5, 1.8)
		gp.y = tp.y
		if not _in_wall(gp, 0.1):
			_add("cone", gp, -1, rng)


func _add(kind: String, at: Vector3, by: int, rng: RandomNumberGenerator) -> void:
	var k: Dictionary = KINDS[kind]
	var tex := _texture(str(k["tex"]))
	if tex == null:
		return
	var sp := Sprite3D.new()
	sp.texture = tex
	sp.pixel_size = float(k.get("px", 0.01))
	sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Its foot on the ground.
	sp.offset = Vector2(0, tex.get_height() * 0.5)
	sp.flip_h = rng.randf() < 0.5
	add_child(sp)
	sp.global_position = at + Vector3(0, 0.01, 0)
	# Its name on every machine alike: what it is and where it was laid.
	var id := "%s@%d,%d" % [kind, roundi(at.x * 10.0), roundi(at.z * 10.0)]
	_props.append({"node": sp, "kind": kind, "pos": at, "vel": Vector3.ZERO, "cool": 0.0, "by": by, "kicked": false, "ground": at.y, "id": id, "held": false})


func _texture(file: String) -> Texture2D:
	if not _tex.has(file):
		var path := file if file.begins_with("res://") else TEX + file
		_tex[file] = load(path) if ResourceLoader.exists(path) else null
	return _tex[file]


## A building's box in its own frame, from its meshes (kept on it until it moves).
func _footprint(s: Node3D) -> AABB:
	if s.has_meta("nudge_box") and s.get_meta("nudge_xf") == s.global_transform:
		return s.get_meta("nudge_box")
	var inv := s.global_transform.affine_inverse()
	var box := AABB()
	var first := true
	for m in s.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var b: AABB = (inv * mi.global_transform) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	s.set_meta("nudge_box", box)
	s.set_meta("nudge_xf", s.global_transform)
	return box


func _in_wall(p: Vector3, pad: float) -> bool:
	for r in _walls:
		if (r as Rect2).grow(pad).has_point(Vector2(p.x, p.z)):
			return true
	return false


# ── kicks ───────────────────────────────────────────────────────────────────

## Where every warden's feet are now and how fast they go: you and the others' figures.
func _wardens(dt: float) -> Array:
	var out: Array = []
	var nodes: Array = []
	var me: Node3D = player_getter.call() if player_getter.is_valid() else null
	if me != null:
		nodes.append(me)
	for r in get_tree().get_nodes_in_group("coop_remote_player"):
		if r is Node3D and (r as Node3D).is_visible_in_tree():
			nodes.append(r)
	var seen: Dictionary = {}
	for n in nodes:
		var id := (n as Node).get_instance_id()
		var p := (n as Node3D).global_position
		var last: Vector3 = _feet.get(id, p)
		_feet[id] = p
		seen[id] = true
		var v := Vector3(p.x - last.x, 0, p.z - last.z) / maxf(dt, 0.001)
		# A jump in place (a teleport, a door) is no walk.
		if v.length() < 8.0:
			out.append([p, v])
	for id in _feet.keys():
		if not seen.has(id):
			_feet.erase(id)
	return out


func _kicks(dt: float) -> void:
	var feet := _wardens(dt)
	for p in _props:
		p["cool"] = maxf(0.0, float(p["cool"]) - dt)
	for f in feet:
		var at: Vector3 = f[0]
		var v: Vector3 = f[1]
		var speed := v.length()
		if speed < 0.35:
			continue
		for p in _props:
			if float(p["cool"]) > 0.0 or bool(p.get("held", false)):
				continue
			var k: Dictionary = KINDS[p["kind"]]
			var pos: Vector3 = p["pos"]
			var away := Vector3(pos.x - at.x, 0, pos.z - at.z)
			if away.length() > float(k["r"]) + FOOT or absf(pos.y - at.y) > 1.2:
				continue
			# Mostly the way you walk, a little away from your foot.
			var dir := (v.normalized() * 0.7 + (away.normalized() if away.length() > 0.01 else v.normalized()) * 0.3).normalized()
			var go := speed * float(k["push"]) * randf_range(0.8, 1.2) + 0.2
			p["vel"] = dir * go + Vector3.UP * float(k["hop"]) * randf_range(0.5, 1.0) * minf(1.0, speed / 3.0)
			p["cool"] = 0.5
			p["kicked"] = true
			var sp: Sprite3D = p["node"]
			if randf() < 0.5:
				sp.flip_h = not sp.flip_h
			_sound(pos, k)


func _sound(at: Vector3, k: Dictionary, db_add := 0.0) -> void:
	var names: Array = k["sfx"]
	if names.is_empty():
		return
	var path := SFX + str(names[randi() % names.size()]) + ".mp3"
	if not ResourceLoader.exists(path):
		return
	var pl: AudioStreamPlayer3D = _snd[_snd_i]
	_snd_i = (_snd_i + 1) % _snd.size()
	pl.stream = load(path)
	pl.global_position = at
	pl.volume_db = float(k["db"]) + db_add + randf_range(-2.0, 1.0)
	pl.pitch_scale = float(k.get("pitch", 1.0)) * randf_range(0.92, 1.08)
	pl.play()


# -- taken, set down, thrown (scripts/ambient/carry.gd) ---------------------------

## Down from a throw (or a fall): its sound, louder the harder; into the lake it sinks with
## a plop; at night the noise of it goes to whatever listens (group "night_ears").
func _landed(p: Dictionary, at: Vector3, speed: float) -> void:
	var k: Dictionary = KINDS[p["kind"]]
	var main := get_tree().current_scene
	var lake := main.find_child("CampLake", true, false) if main != null else null
	if lake != null and lake.has_method("in_water") and bool(lake.in_water(at)):
		var plop := SFX + "fish_plop.mp3"
		if ResourceLoader.exists(plop):
			var pl: AudioStreamPlayer3D = _snd[_snd_i]
			_snd_i = (_snd_i + 1) % _snd.size()
			pl.stream = load(plop)
			pl.global_position = at
			pl.volume_db = -4.0
			pl.pitch_scale = 1.0
			pl.play()
		p["held"] = true
		(p["node"] as Node3D).visible = false
	else:
		_sound(at, k, clampf((speed - 2.0) * 1.5, 0.0, 8.0))
	var loud := float(p.get("loud", 0.0))
	if loud > 0.0:
		p["loud"] = 0.0
		var h = main.get("_time_of_day_hours") if main != null else null
		if h != null and (float(h) >= 20.0 or float(h) < 6.0):
			get_tree().call_group("night_ears", "heard", at, loud)


func _prop(id: String) -> Dictionary:
	for p in _props:
		if str(p.get("id", "")) == id:
			return p
	return {}


func has_prop(id: String) -> bool:
	return not _prop(id).is_empty()


## What lies within `r` of `o` and can be picked up: [{id, kind, pos}].
func props_near(o: Vector3, r: float) -> Array:
	var out: Array = []
	for p in _props:
		if bool(p.get("held", false)) or not (p["vel"] as Vector3).is_zero_approx():
			continue
		if (p["pos"] as Vector3).distance_to(o) <= r:
			out.append({"id": p["id"], "kind": p["kind"], "pos": p["pos"], "ev": int(p.get("ev", -1))})
	return out


func take_prop(id: String) -> void:
	var p := _prop(id)
	if p.is_empty():
		return
	p["held"] = true
	p["vel"] = Vector3.ZERO
	p["kicked"] = true
	(p["node"] as Node3D).visible = false


func put_prop(id: String, at: Vector3) -> void:
	var p := _prop(id)
	if p.is_empty():
		return
	p["held"] = false
	p["pos"] = at
	p["ground"] = at.y
	p["vel"] = Vector3.ZERO
	var n := p["node"] as Node3D
	n.global_position = at + Vector3(0, 0.01, 0)
	n.visible = true


func throw_prop(id: String, from: Vector3, vel: Vector3, loud: float) -> void:
	var p := _prop(id)
	if p.is_empty():
		return
	p["held"] = false
	p["pos"] = from
	p["vel"] = vel
	p["loud"] = loud
	p["cool"] = 0.6
	p["ground"] = _ground_under(from)
	var n := p["node"] as Node3D
	n.global_position = from
	n.visible = true


## A thing that was not laid (the sack set down): made where it is put, named alike on
## every machine (the putter's id, or a new one).
func add_loose(kind: String, at: Vector3, meta: Dictionary = {}, id: String = "") -> String:
	if not KINDS.has(kind) or texture_of(kind) == null:
		return ""
	var r := RandomNumberGenerator.new()
	r.seed = hash(id)
	_add(kind, at, -1, r)
	var p: Dictionary = _props.back()
	p["id"] = id if id != "" else "%s#%d" % [kind, Time.get_ticks_msec()]
	p["kicked"] = true
	p.merge(meta)
	return str(p["id"])


## Gone for good (the sack in the dumpster).
func drop_prop(id: String) -> void:
	var p := _prop(id)
	if p.is_empty():
		return
	(p["node"] as Node).queue_free()
	_props.erase(p)


func texture_of(kind: String) -> Texture2D:
	if not KINDS.has(kind):
		return null
	return _texture(str((KINDS[kind] as Dictionary)["tex"]))


func play_kind(kind: String, at: Vector3, db: float) -> void:
	if KINDS.has(kind):
		_sound(at, KINDS[kind], db - float(KINDS[kind]["db"]))


func _ground_under(from: Vector3) -> float:
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null:
		return 0.0
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 8.0)
	q.collision_mask = 1
	var me = player_getter.call() if player_getter.is_valid() else null
	if me is CollisionObject3D:
		q.exclude = [(me as CollisionObject3D).get_rid()]
	var hit := space.intersect_ray(q)
	return float((hit["position"] as Vector3).y) if not hit.is_empty() else 0.0


## Off it goes: it flies, lands, bounces a little, slides and stops; off a wall it comes
## back; a roller turns over while it goes. Worked out in five slices of the step (one
## slice a step gave the hop no height and kept it bouncing), drawn once a step.
func _move(dt: float) -> void:
	var h_dt := dt / 5.0
	for p in _props:
		if bool(p.get("held", false)):
			continue
		var v: Vector3 = p["vel"]
		var pos: Vector3 = p["pos"]
		var ground := float(p["ground"])
		if v.is_zero_approx() and pos.y <= ground:
			continue
		var k: Dictionary = KINDS[p["kind"]]
		var np := pos
		for i in 5:
			v.y -= 9.8 * h_dt
			var nxt := np + v * h_dt
			if _in_wall(nxt, float(k["r"])):
				v.x *= -0.4
				v.z *= -0.4
				nxt = Vector3(np.x, nxt.y, np.z)
			if nxt.y <= ground:
				nxt.y = ground
				if v.y < -2.0:
					_landed(p, nxt, -v.y)
				v.y = -v.y * 0.3 if v.y < -1.2 else 0.0
				var h := Vector2(v.x, v.z)
				var s := maxf(0.0, h.length() - float(k["drag"]) * h_dt)
				h = h.normalized() * s if s > 0.0 else Vector2.ZERO
				v.x = h.x
				v.z = h.y
			np = nxt
		if Vector2(v.x, v.z).length() < 0.05 and np.y <= ground and absf(v.y) < 0.01:
			v = Vector3.ZERO
		p["vel"] = v
		p["pos"] = np
		var sp: Sprite3D = p["node"]
		sp.global_position = np + Vector3(0, 0.01, 0)
		if bool(k["roll"]):
			sp.flip_v = not sp.flip_v if Vector2(v.x, v.z).length() > 0.25 else false
