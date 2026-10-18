extends Node3D

## The people in the pub, the bistro and the Jednota while you are in there (built by
## scripts/service_interior.gd for those rooms). Whoever the guest simulation has visiting
## this building right now is here, in their own sprites:
##   pub      at the tables and on the bar stools, raising the mug now and then (a table
##            drinks together: the glasses clink); the room murmurs;
##   bistro   at the gingham tables, eating (the food on the plate goes down); cutlery
##            and low voices;
##   shop     standing at the racks, a step this way and that, one at the counter.
## A visit goes: in through the door (from beside you, `entry`), across to a free seat,
## sit down and wait with nothing on the table, looking about for somebody; served (by
## you in the counter's game, or by a hand) the mug or the plate comes; when the visit
## ends they get up, pay (the till) and walk out the way they came. Nobody served: they
## get up and go all the same (business_runtime has them grumble). A building without
## books (an old save) serves itself, as before.
## Seated people are the *_sit / *_drink / *_eat poses (scripts/attractions/poses.gd).
## Stepped like the rest of the game (8 frames a second).

const POSES = preload("res://scripts/attractions/poses.gd")
const ORDERS = preload("res://scripts/food/orders.gd")
const STEP := 0.125
const WALK_SPEED := 1.1
const SFX := {"pub": "res://assets/sfx/pub/pub_room.mp3", "rest": "res://assets/sfx/bistro/dining_room.mp3"}
const SFX_CLINK := "res://assets/sfx/pub/glass_clink.mp3"
const SFX_DOWN := "res://assets/sfx/pub/glass_down.mp3"
const SFX_SERVED := {"pub": "res://assets/sfx/pub/glass_down.mp3", "rest": "res://assets/sfx/bistro/plate_down.mp3"}
const SFX_PAY := {"pub": "res://assets/sfx/pub/coins_bar.mp3", "rest": "res://assets/sfx/bistro/till.mp3", "vecerka": "res://assets/sfx/bistro/till.mp3"}
const SFX_DOOR := "res://assets/sfx/town/shop_bell.mp3"

var profile := ""
var key := ""
## [{pos: Vector3 (room), face: Vector3, table: int (-1 none), stand: bool}]
var seats: Array = []
## Where a mug or plate goes for a seat: seat index -> Vector3 (room).
var setting: Dictionary = {}
## Where you stand (room, on the floor): they come in and go out just beside it.
var entry := Vector3.INF

## "id:member" -> {node, sprite, seat, base, prop, food, t0, next, pose, state (in, seat,
## out), visit, served, member, from, to, walk_t0, walk_dur}
var _people: Dictionary = {}
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


func setup(p: String, building_key: String, seat_list: Array, settings: Dictionary, door := Vector3.INF) -> void:
	profile = p
	key = building_key
	seats = seat_list
	setting = settings
	entry = door
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
	# Whoever is in already when you come in is in their seat.
	_refresh(true)


func _mat(c: Color, glassy: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.3 if glassy else 0.9
	if glassy:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func headcount() -> int:
	var n := 0
	for p in _people.values():
		if str(p["state"]) != "out":
			n += 1
	return n


## Visitors sitting with nothing in front of them yet.
func waiting_count() -> int:
	var n := 0
	for p in _people.values():
		if str(p["state"]) == "seat" and not bool(p["served"]) and not bool(p["stand"]):
			n += 1
	return n


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
	var heads := headcount()
	var want := -60.0 if heads == 0 else lerpf(-16.0, -5.0, clampf(float(heads) / 6.0, 0.0, 1.0))
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


func _refresh(first := false) -> void:
	var seen := {}
	for g in _visitors():
		var act: Dictionary = g.get("activity", {})
		var visit := "%d@%d" % [int(g.get("id", 0)), int(act.get("start", 0))]
		var n: int = POSES.figure_count(str(g.get("archetype", "")), int(g.get("party_size", 1)))
		for i in n:
			var k := "%d:%d" % [int(g.get("id", 0)), i]
			seen[k] = true
			if _people.has(k):
				continue
			var seat := _free_seat()
			if seat < 0:
				continue
			_people[k] = _spawn(g, seat, visit, i, first or entry == Vector3.INF)
	for k in _people.keys():
		var p: Dictionary = _people[k]
		if not seen.has(k) and str(p["state"]) != "out":
			_leave(k, p)


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


## Just inside the door, on the side of the room the seat is on (out of the lens: they
## walk into the picture).
func _door_for(at: Vector3) -> Vector3:
	var side := 1.0 if at.x >= entry.x else -1.0
	return Vector3(entry.x + side * 1.15, entry.y, entry.z - 0.8)


func _spawn(g: Dictionary, seat: int, visit: String, member: int, seated: bool) -> Dictionary:
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
	var served := ORDERS.served(key, visit)
	var p := {"node": node, "sprite": sprite, "seat": seat, "base": base, "t0": _t, "next": _t + _rng.randf_range(1.0, 6.0),
		"pose": "sit", "stand": standing, "arch": str(g.get("archetype", "")), "state": "seat", "visit": visit,
		"served": served, "member": member}
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
		prop.visible = served
		p["prop"] = prop
	if seated:
		POSES.set_pose(sprite, base, "" if standing else "sit")
	else:
		POSES.set_pose(sprite, base, "")
		_walk(p, _door_for(s["pos"]), s["pos"], "in")
		if member == 0 and _rng.randf() < 0.7:
			_play(SFX_DOOR, -18.0)
	return p


## Off they go: the till for what they had, then out the way they came.
func _leave(k: String, p: Dictionary) -> void:
	var prop: Node3D = p.get("prop", null)
	if prop != null and is_instance_valid(prop):
		prop.queue_free()
	p.erase("prop")
	p.erase("food")
	if entry == Vector3.INF:
		_free(k)
		return
	if bool(p["served"]) and int(p["member"]) == 0:
		_play(str(SFX_PAY.get(profile, "")), -12.0)
	var node: Node3D = p["node"]
	POSES.set_pose(p["sprite"], str(p["base"]), "")
	_walk(p, node.position, _door_for(node.position), "out")
	p["seat"] = -1


func _walk(p: Dictionary, from: Vector3, to: Vector3, state: String) -> void:
	p["state"] = state
	p["from"] = Vector3(from.x, 0.05, from.z)
	p["to"] = to
	p["walk_t0"] = _t
	p["walk_dur"] = maxf(0.5, Vector2(to.x - from.x, to.z - from.z).length() / WALK_SPEED)
	(p["node"] as Node3D).position = p["from"]


func _free(k: String) -> void:
	var p: Dictionary = _people[k]
	for n in [p["node"], p.get("prop", null)]:
		if n != null and is_instance_valid(n):
			(n as Node).queue_free()
	_people.erase(k)


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
		var node: Node3D = p["node"]
		var sprite: Sprite3D = p["sprite"]
		var state := str(p["state"])
		if state == "in" or state == "out":
			var f := clampf((_t - float(p["walk_t0"])) / float(p["walk_dur"]), 0.0, 1.0)
			var from: Vector3 = p["from"]
			var to: Vector3 = p["to"]
			node.position = from.lerp(Vector3(to.x, from.y, to.z), f)
			sprite.position.y = 0.03 if int(_t / STEP) % 2 == 0 else 0.0
			sprite.flip_h = to.x < from.x
			if f < 1.0:
				continue
			sprite.position.y = 0.0
			if state == "out":
				_free(k)
				continue
			p["state"] = "seat"
			node.position = to
			p["next"] = _t + _rng.randf_range(1.5, 4.0)
			POSES.set_pose(sprite, str(p["base"]), "" if bool(p["stand"]) else "sit")
			continue
		var s: Dictionary = seats[int(p["seat"])]
		if bool(p["stand"]):
			# Browsing: a small step along the rack now and then, a turn of the head.
			if _t >= float(p["next"]):
				p["next"] = _t + _rng.randf_range(2.0, 5.0)
				var face: Vector3 = s.get("face", Vector3.FORWARD)
				var along := face.cross(Vector3.UP).normalized()
				node.position = (s["pos"] as Vector3) + along * _rng.randf_range(-0.3, 0.3)
				sprite.flip_h = _rng.randf() < 0.5
			continue
		if not bool(p["served"]) and ORDERS.served(key, str(p["visit"])):
			# Here it comes: the mug or the plate on the table.
			p["served"] = true
			p["t0"] = _t
			p["next"] = _t + _rng.randf_range(0.8, 2.0)
			var prop_now: Node3D = p.get("prop", null)
			if prop_now != null:
				prop_now.visible = true
			if int(p["member"]) == 0:
				_play(str(SFX_SERVED.get(profile, "")), -12.0)
		if not bool(p["served"]):
			# Waiting: sat, nothing in front of them, a look round for somebody now and then.
			if _t >= float(p["next"]):
				p["next"] = _t + _rng.randf_range(1.5, 3.5)
				sprite.flip_h = not sprite.flip_h
			POSES.set_pose(sprite, str(p["base"]), "sit")
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
	# Two at a table lift their mugs at once: na zdravi.
	for t in tables_drinking.keys():
		if int(tables_drinking[t]) >= 1 and _rng.randf() < 0.5:
			_cheers(int(t))


func _cheers(table: int) -> void:
	var at_table: Array = []
	for p in _people.values():
		if str(p["state"]) != "seat" or int(p["seat"]) < 0 or bool(p["stand"]) or not bool(p["served"]):
			continue
		if int((seats[int(p["seat"])] as Dictionary).get("table", -2)) == table:
			at_table.append(p)
	if at_table.size() < 2:
		return
	for p in at_table:
		p["pose"] = "drink"
		p["next"] = _t + 1.6
	_play(SFX_CLINK, -6.0)


func _play(path: String, db: float) -> void:
	if path != "" and ResourceLoader.exists(path):
		_one.stream = load(path)
		_one.volume_db = db
		_one.play()
