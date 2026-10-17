extends Node3D

## The people in the pub, the bistro and the Jednota while you are in there (built by
## scripts/service_interior.gd for those rooms). Whoever the guest simulation has visiting
## this building right now is here, in their own sprites:
##   pub      at the tables and on the bar stools, a mug in front of each, raising it now
##            and then (a table drinks together: the glasses clink); the room murmurs;
##   bistro   at the gingham tables, a plate each, eating (the food on it goes down over
##            the visit); cutlery and low voices;
##   shop     standing at the racks, a step this way and that, one at the counter.
## Seated people are the *_sit / *_drink / *_eat poses (scripts/attractions/poses.gd).
## Stepped like the rest of the game (8 frames a second).

const POSES = preload("res://scripts/attractions/poses.gd")
const STEP := 0.125
const SFX := {"pub": "res://assets/sfx/pub/pub_room.mp3", "rest": "res://assets/sfx/bistro/dining_room.mp3"}
const SFX_CLINK := "res://assets/sfx/pub/glass_clink.mp3"
const SFX_DOWN := "res://assets/sfx/pub/glass_down.mp3"

var profile := ""
var key := ""
## [{pos: Vector3 (room), face: Vector3, table: int (-1 none), stand: bool}]
var seats: Array = []
## Where a mug or plate goes for a seat: seat index -> Vector3 (room).
var setting: Dictionary = {}

var _people: Dictionary = {}     # "id:member" -> {node, sprite, seat, base, prop, food, t0, next, pose}
var _poll := 0.0
var _acc := 0.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _room_sound: AudioStreamPlayer
var _one: AudioStreamPlayer
var _mug_mat: StandardMaterial3D
var _foam_mat: StandardMaterial3D
var _plate_mat: StandardMaterial3D
var _food_mat: StandardMaterial3D


func setup(p: String, building_key: String, seat_list: Array, settings: Dictionary) -> void:
	profile = p
	key = building_key
	seats = seat_list
	setting = settings
	_rng.randomize()
	_room_sound = AudioStreamPlayer.new()
	_room_sound.volume_db = -60.0
	add_child(_room_sound)
	var path := str(SFX.get(p, ""))
	if path != "" and ResourceLoader.exists(path):
		var st = load(path)
		if st is AudioStreamMP3:
			(st as AudioStreamMP3).loop = true
		_room_sound.stream = st
		_room_sound.play()
	_one = AudioStreamPlayer.new()
	_one.volume_db = -10.0
	add_child(_one)
	_mug_mat = _mat(Color(0.86, 0.6, 0.16, 0.86), true)
	_foam_mat = _mat(Color(0.98, 0.96, 0.9), false)
	_plate_mat = _mat(Color(0.95, 0.95, 0.92), false)
	_food_mat = _mat(Color(0.5, 0.2, 0.1), false)
	_refresh()


func _mat(c: Color, glassy: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.3 if glassy else 0.9
	if glassy:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func headcount() -> int:
	return _people.size()


func _process(delta: float) -> void:
	_t += delta
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.5
		_refresh()
	_acc += delta
	if _acc < STEP:
		return
	_acc = 0.0
	_animate()
	var want := -60.0 if _people.is_empty() else lerpf(-16.0, -5.0, clampf(float(_people.size()) / 6.0, 0.0, 1.0))
	_room_sound.volume_db = move_toward(_room_sound.volume_db, want, 3.0)


## Who the simulation has in this building now (arrived, not queuing outside).
func _visitors() -> Array:
	var out: Array = []
	if GuestManager == null:
		return out
	var now: int = GuestManager._absolute_minutes(maxi(1, GuestManager._last_known_day), GuestManager._last_known_hour, GuestManager._last_known_minute)
	for g in GuestManager.get_guest_life_snapshot():
		var act: Dictionary = g.get("activity", {}) if g.get("activity", {}) is Dictionary else {}
		if str(act.get("kind", "")) != "visit" or str(act.get("target_key", "")) != key or bool(act.get("queued", false)):
			continue
		if int(act.get("arrive", now)) > now:
			continue
		out.append(g)
	return out


func _refresh() -> void:
	var seen := {}
	for g in _visitors():
		var n: int = POSES.figure_count(str(g.get("archetype", "")), int(g.get("party_size", 1)))
		for i in n:
			var k := "%d:%d" % [int(g.get("id", 0)), i]
			seen[k] = true
			if not _people.has(k):
				var seat := _free_seat()
				if seat < 0:
					continue
				_people[k] = _spawn(g, seat)
	for k in _people.keys():
		if not seen.has(k):
			var p: Dictionary = _people[k]
			for n in [p["node"], p.get("prop", null)]:
				if n != null and is_instance_valid(n):
					(n as Node).queue_free()
			_people.erase(k)


func _free_seat() -> int:
	var taken := {}
	for p in _people.values():
		taken[int(p["seat"])] = true
	var order: Array = range(seats.size())
	order.shuffle()
	for i in order:
		if not taken.has(i):
			return i
	return -1


func _spawn(g: Dictionary, seat: int) -> Dictionary:
	var s: Dictionary = seats[seat]
	var node := Node3D.new()
	node.name = "Guest"
	add_child(node)
	node.position = s["pos"]
	var sprite := Sprite3D.new()
	sprite.name = "Sprite"
	var base := str(g.get("sprite_path", ""))
	if ResourceLoader.exists(base):
		sprite.texture = load(base)
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = true
	sprite.double_sided = true
	if sprite.texture != null:
		sprite.pixel_size = 1.72 / float(sprite.texture.get_height())
		sprite.offset = Vector2(0, sprite.texture.get_height() * 0.5)
	node.add_child(sprite)
	var standing := bool(s.get("stand", false))
	POSES.set_pose(sprite, base, "" if standing else "sit")
	var p := {"node": node, "sprite": sprite, "seat": seat, "base": base, "t0": _t, "next": _t + _rng.randf_range(1.0, 6.0), "pose": "sit", "stand": standing, "arch": str(g.get("archetype", ""))}
	if setting.has(seat) and not standing:
		var prop := Node3D.new()
		prop.name = "Setting"
		add_child(prop)
		prop.position = setting[seat]
		if profile == "pub":
			var glass := _cyl(prop, 0.045, 0.16, _mug_mat)
			glass.position.y = 0.08
			var foam := _cyl(prop, 0.046, 0.03, _foam_mat)
			foam.position.y = 0.17
		else:
			var plate := _cyl(prop, 0.13, 0.015, _plate_mat)
			plate.position.y = 0.008
			var food := _cyl(prop, 0.085, 0.03, _food_mat)
			food.position.y = 0.025
			p["food"] = food
		p["prop"] = prop
	return p


func _cyl(parent: Node3D, r: float, h: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 8
	mi.mesh = c
	mi.material_override = m
	parent.add_child(mi)
	return mi


func _animate() -> void:
	var tables_drinking := {}
	for k in _people.keys():
		var p: Dictionary = _people[k]
		var s: Dictionary = seats[int(p["seat"])]
		var node: Node3D = p["node"]
		var sprite: Sprite3D = p["sprite"]
		if bool(p["stand"]):
			# Browsing: a small step along the rack now and then, a turn of the head.
			if _t >= float(p["next"]):
				p["next"] = _t + _rng.randf_range(2.0, 5.0)
				var face: Vector3 = s.get("face", Vector3.FORWARD)
				var along := face.cross(Vector3.UP).normalized()
				node.position = (s["pos"] as Vector3) + along * _rng.randf_range(-0.3, 0.3)
				sprite.flip_h = _rng.randf() < 0.5
			continue
		var pose := str(p["pose"])
		if _t >= float(p["next"]):
			if pose == "sit":
				pose = "drink" if profile == "pub" else "eat"
				p["next"] = _t + (_rng.randf_range(1.2, 2.0) if profile == "pub" else _rng.randf_range(0.8, 1.4))
				if profile == "pub" and int(s.get("table", -1)) >= 0:
					tables_drinking[int(s["table"])] = int(tables_drinking.get(int(s["table"]), 0)) + 1
			else:
				pose = "sit"
				p["next"] = _t + (_rng.randf_range(5.0, 11.0) if profile == "pub" else _rng.randf_range(2.0, 4.5))
				if profile == "pub":
					_play(SFX_DOWN, -16.0)
			p["pose"] = pose
		POSES.set_pose(sprite, str(p["base"]), pose)
		# A word to the one opposite: a hair of a bob while sitting.
		sprite.position.y = 0.008 if (pose == "sit" and int(_t * 4.0 + float(p["seat"])) % 6 == 0) else 0.0
		# The mug is in their hand while they drink; the plate empties as they eat.
		var prop: Node3D = p.get("prop", null)
		if prop != null and profile == "pub":
			prop.visible = pose != "drink"
		var food: MeshInstance3D = p.get("food", null)
		if food != null:
			var eaten := clampf((_t - float(p["t0"])) / 90.0, 0.0, 0.9)
			food.scale = Vector3(1.0 - eaten, 1.0, 1.0 - eaten)
	# Two at a table lift their mugs at once: na zdraví.
	for t in tables_drinking.keys():
		if int(tables_drinking[t]) >= 1 and _rng.randf() < 0.5:
			_cheers(int(t))


func _cheers(table: int) -> void:
	var at_table: Array = []
	for p in _people.values():
		if int((seats[int(p["seat"])] as Dictionary).get("table", -2)) == table and not bool(p["stand"]):
			at_table.append(p)
	if at_table.size() < 2:
		return
	for p in at_table:
		p["pose"] = "drink"
		p["next"] = _t + 1.6
	_play(SFX_CLINK, -6.0)


func _play(path: String, db: float) -> void:
	if ResourceLoader.exists(path):
		_one.stream = load(path)
		_one.volume_db = db
		_one.play()
