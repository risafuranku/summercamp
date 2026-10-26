extends Node3D

## The corn stand standing in the camp (building_models._corn_stand): its two stations on
## the counter (scripts/corn/stand_layout.gd, the husking and the counter: their Build
## pictures, the cobs in the pot and on the board, the bowl, seen by everyone going by,
## worked from scripts/corn/stand_view.gd), steam off the pot in puffs (a Grok sprite, in
## steps, twelve a second), the awning's flaps stirring in the wind.

const FPS := 12.0
const PUFFS := 3
const LAYOUT := preload("res://scripts/corn/stand_layout.gd")
const CORNSTAND := preload("res://scripts/corn/cornstand.gd")
const POSES := preload("res://scripts/attractions/poses.gd")
## The hands at their places behind the counter (scripts/business/crew_figures.gd): seen
## at work from the camp and from behind the counter; one whose station a warden is at
## steps back out of the way.
const CREW_FIGURES := preload("res://scripts/business/crew_figures.gd")
const CREW_AT := {"counter": Vector3(-0.62, 0, -0.98), "husk": Vector3(0.68, 0, -0.98), "drinks": Vector3(-1.8, 0, -0.95)}
const CREW_ASIDE := {"counter": Vector3(0.2, 0, -0.75), "husk": Vector3(-0.2, 0, -0.75), "drinks": Vector3(0.0, 0, -0.75)}
var _crew: Node3D
## Where those who come for a cob stand, in front of the counter (the stand's space),
## facing it: the first two at the counter, the rest in a line out into the camp, slanting
## off to the side so that from behind the counter you see every one of them (the brief
## of 20. 10.: "the queue out in the camp, seen from the counter"). They step up the line
## as those in front are served.
const QUEUE := [Vector3(-0.5, 0, 1.12), Vector3(0.35, 0, 1.18), Vector3(1.0, 0, 1.75), Vector3(1.45, 0, 2.35),
	Vector3(1.9, 0, 2.95), Vector3(2.35, 0, 3.55), Vector3(2.8, 0, 4.15), Vector3(3.25, 0, 4.75),
	Vector3(3.7, 0, 5.35), Vector3(4.15, 0, 5.95)]
## Walking up the line, metres a second.
const STEP_UP := 1.1
## Over their heads how their patience goes, their feet stamping (the brief of 21. 10.).
const GUEST_MOOD := preload("res://scripts/business/guest_mood.gd")
var _mood: Node3D
## Those in the line now: guest_id * 10 + member -> {node, seen}.
var _members: Dictionary = {}
var _key := ""

var guests_here := 0

var _puffs: Array = []            # {sprite, phase}
var _flaps: Array = []
var _acc := 0.0
var _t := 0.0
var _steam_at := Vector3.ZERO
## id -> the station (station3d), made once the stand's key is known.
var stations: Dictionary = {}
## A bare bulb on its cord under the awning, lit from dusk (camp/bulb_cord.png).
var _bulb: OmniLight3D
var _bulb_spr: Node3D


func _ready() -> void:
	add_to_group("attraction")
	call_deferred("_setup")


func _setup() -> void:
	var r := get_parent() as Node3D
	if r == null:
		return
	_steam_at = r.get_meta("steam_at", Vector3(0, 1.6, 0))
	_bulb = OmniLight3D.new()
	_bulb.name = "StandBulb"
	_bulb.position = Vector3(0.0, 1.95, -0.2)
	_bulb.light_color = Color(1.0, 0.8, 0.52)
	_bulb.light_energy = 1.2
	_bulb.omni_range = 3.4
	_bulb.visible = false
	r.add_child(_bulb)
	if ResourceLoader.exists("res://assets/textury/camp/bulb_cord.png"):
		_bulb_spr = load("res://scripts/interior_kit.gd").cutout(r, "bulb_cord", Vector2(0.08, 0.28), Vector3(0.0, 1.92, -0.2), 0.0, true, "StandBulbCord")
	var origin = r.get_meta("grid_origin", null)
	if origin is Vector2i:
		make_stations("%d:%d" % [origin.x, origin.y])
	for c in r.get_children():
		if str(c.name).begins_with("AwningFlap"):
			_flaps.append(c)
	# A puff of steam (Grok, camp/steam_puff.png).
	var path := "res://assets/textury/camp/steam_puff.png"
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	for i in PUFFS:
		var s := Sprite3D.new()
		s.texture = tex
		s.pixel_size = 0.1 / float(maxi(1, tex.get_height()))
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.shaded = false
		s.transparent = true
		r.add_child(s)
		_puffs.append({"sprite": s, "phase": float(i) / float(PUFFS)})


## The stand's place in the camp (guest_agents: an open-air place, its guests posed here).
func covers_tile(tile: Vector2i) -> bool:
	var r := get_parent()
	if r == null or not r.has_meta("grid_origin"):
		return false
	var o: Vector2i = r.get_meta("grid_origin")
	var fp_any = r.get_meta("grid_footprint", Vector2i.ONE)
	var fp: Vector2i = fp_any if fp_any is Vector2i else Vector2i.ONE
	return tile.x >= o.x and tile.y >= o.y and tile.x < o.x + fp.x and tile.y < o.y + fp.y


var _spot_of: Dictionary = {}
var _spot_seen: Dictionary = {}
## Where each one in the line is now (walking up to their place) and when they last moved.
var _at_of: Dictionary = {}
var _moved_t: Dictionary = {}


## Those further back step up into the places in front that came free, in the order they
## stand.
func _close_up() -> void:
	var keys: Array = _spot_of.keys()
	keys.sort_custom(func(a, b) -> bool: return int(_spot_of[a]) < int(_spot_of[b]))
	for idx in keys.size():
		_spot_of[keys[idx]] = idx


## A guest come for a cob: at a place in front of the counter (the first free one from
## the counter back), standing. False when every place is taken (they stand about as at
## the other places).
func pose_member(guest_id: int, i: int, _n: int, member: Node3D, sprite: Sprite3D, info: Dictionary, _t2: float) -> bool:
	var r := get_parent() as Node3D
	if r == null:
		return false
	var key := guest_id * 10 + i
	# Places of those long gone are free again.
	for k in _spot_seen.keys():
		if _t - float(_spot_seen[k]) > 3.0:
			_spot_seen.erase(k)
			_spot_of.erase(k)
			_at_of.erase(k)
	if not _spot_of.has(key):
		var taken: Array = _spot_of.values()
		var free := -1
		for idx in QUEUE.size():
			if not taken.has(idx):
				free = idx
				break
		if free < 0:
			return false
		_spot_of[key] = free
		_at_of[key] = QUEUE[mini(QUEUE.size() - 1, free + 1)]
	_spot_seen[key] = _t
	_close_up()
	var want: Vector3 = QUEUE[int(_spot_of[key])]
	var at: Vector3 = _at_of.get(key, want)
	at = at.move_toward(want, STEP_UP * maxf(0.0, _t - float(_moved_t.get(key, _t))))
	_moved_t[key] = _t
	_at_of[key] = at
	member.global_position = r.global_transform * at
	_members[key] = {"node": member, "seen": _t}
	if _mood != null and is_instance_valid(_mood):
		member.global_position.y += float(_mood.call("stomp", str(key)))
	member.set_meta("marker_drop", 0.0)
	# Standing (the eating pictures are sat at a table); the impatient ones in their
	# impatient picture, fidgeting (guest_mood.gd).
	var base := str(sprite.get_meta("own_path", info.get("sprite_path", "")))
	if not (_mood != null and is_instance_valid(_mood) and bool(_mood.call("impatient", str(key))) and GUEST_MOOD.show_wait(sprite, base)):
		POSES.set_pose(sprite, str(info.get("sprite_path", "")), "")
	return true


## Where guest `guest_id`'s member `i` stands in the line (their head, global): the stars
## and the tip fly up over them. INF when they are not in it.
func member_point(guest_id: int, i: int) -> Vector3:
	var m: Dictionary = _members.get(guest_id * 10 + i, {})
	var n = m.get("node", null)
	if n == null or not is_instance_valid(n) or _t - float(m.get("seen", -9.0)) > 2.0:
		return Vector3.INF
	return (n as Node3D).global_position + Vector3(0, 1.62, 0)


## The bubbles over the line: each one's patience from their slip.
func _moods() -> void:
	if _key == "" or _members.is_empty():
		return
	if _mood == null or not is_instance_valid(_mood):
		_mood = GUEST_MOOD.new()
		_mood.name = "GuestMood"
		add_child(_mood)
	var left := {}
	var names := {}
	var stand = CORNSTAND.of(get_tree())
	if stand != null:
		for t in stand.tickets(_key):
			var k := int(t["guest_id"]) * 10 + int(t["member"])
			var l := 1.0 - clampf(float(t.get("age", 0)) / float(load("res://core/systems/corn_rules.gd").PATIENCE_GONE), 0.0, 1.0)
			left[k] = minf(float(left.get(k, 1.0)), l)
			names[k] = str(t.get("name", ""))
	for k in _members.keys():
		var m: Dictionary = _members[k]
		var n = m.get("node", null)
		if n == null or not is_instance_valid(n) or _t - float(m.get("seen", -9.0)) > 2.0:
			_members.erase(k)
			continue
		_mood.call("show_for", str(k), (n as Node3D).global_position + Vector3(0, 1.62, 0), float(left.get(k, -1.0)), str(names.get(k, "")))
	_mood.call("sweep")


## The stand's stations on its counter, made the first time (scripts/corn/stand_layout.gd):
## id -> station.
func make_stations(key: String) -> Dictionary:
	var r := get_parent() as Node3D
	if r == null or key == "":
		return stations
	_key = key
	var fresh := stations.is_empty() or not is_instance_valid(stations.values()[0]) or str(stations.values()[0].get("building_key")) != key
	if not fresh:
		return stations
	for v in stations.values():
		if is_instance_valid(v):
			(v as Node).queue_free()
	stations.clear()
	LAYOUT.dress(r)
	var stand = CORNSTAND.of(get_tree())
	for id in LAYOUT.STATIONS:
		var path := str(LAYOUT.STATIONS[id]["script"])
		if not ResourceLoader.exists(path):
			continue
		var surf: Dictionary = LAYOUT.SURFACES[id]
		var v: Node3D = load(path).new()
		v.name = "Station3D_" + str(id)
		v.set("building_key", key)
		v.set("station", str(id))
		v.set("room", "stand")
		v.set("label", str(LAYOUT.STATIONS[id]["label"]))
		v.set("surf_at", surf["at"])
		v.set("surf_size", surf["size"])
		v.set("surf_yaw", float(surf["yaw"]))
		v.set("surf_flat", bool(surf["flat"]))
		v.set("cam_back", float(surf.get("cam_back", 0.0)))
		v.set("cam_up", float(surf.get("cam_up", 0.0)))
		v.set("cam_aim", float(surf.get("cam_aim", 0.0)))
		v.set("state", stand)
		r.add_child(v)
		stations[id] = v
	_start_crew(r, key)
	# The steam off the painted pot (the counter's).
	var c: Node3D = stations.get("counter", null)
	if c != null:
		_steam_at = c.transform * (c.call("local_at", Vector2(95, 172), 0.08) as Vector3)
	return stations


func _start_crew(r: Node3D, key: String) -> void:
	if _crew != null and is_instance_valid(_crew):
		_crew.call("clear")
		_crew.queue_free()
	_crew = CREW_FIGURES.new()
	_crew.name = "StandCrew"
	_crew.set("key", key)
	var spots := {}
	for role in CREW_AT:
		spots[role] = {"root": r, "pos": CREW_AT[role], "station": role, "aside": CREW_ASIDE[role], "note": (CREW_AT[role] as Vector3) + Vector3(0, 1.25, 0.5)}
	_crew.set("spots", spots)
	_crew.set("busy_of", _busy)
	_crew.set("place_of", func(p: Dictionary) -> String:
		var cs := get_tree().get_first_node_in_group("cornstands") if is_inside_tree() else null
		return str((cs.crew_places(key) as Dictionary).get(str(p.get("slug", "")), "")) if cs != null else str(p.get("role", "")))
	r.add_child(_crew)
	# Served over the counter (by a hand or by you): the hand's lean and the cob (or the
	# cup) going over to the first in the line, on every machine (cornstand.handed).
	var cs := get_tree().get_first_node_in_group("cornstands") if is_inside_tree() else null
	if cs != null and cs.has_signal("handed") and not cs.is_connected("handed", _on_handed):
		cs.connect("handed", _on_handed)


const SERVED_COB := "res://assets/textury/corn/cob_napkin.png"
const SERVED_CUP := "res://assets/textury/corn/cup_tea.png"


func _on_handed(key: String, tid: String, _rec: Dictionary) -> void:
	if key != _key or _crew == null or not is_instance_valid(_crew):
		return
	var drink := tid.ends_with(":d")
	var tex_path := SERVED_CUP if drink else SERVED_COB
	var thing: Texture2D = load(tex_path) if ResourceLoader.exists(tex_path) else null
	var h := 0.12 if drink else 0.22
	if drink and _crew.hand_over("drinks", thing, QUEUE[0], h):
		return
	_crew.hand_over("counter", thing, QUEUE[0], h)


## The stand's stations somebody is at: here, or another warden (their room's job).
func _busy() -> Array:
	var out: Array = []
	for id in stations:
		var st = stations[id]
		if is_instance_valid(st) and bool(st.call("is_open")):
			out.append(str(id))
	if Coop.is_active() and not stations.is_empty():
		var key := str(stations.values()[0].get("building_key"))
		for pid in Coop.others():
			var room: Dictionary = Coop.state_of(pid).get("room", {})
			if str(room.get("k", "")) == key and str(room.get("t", "")) == "corn":
				out.append(str(room.get("w", "")))
	return out


func _process(delta: float) -> void:
	_acc += delta
	if _acc < 1.0 / FPS:
		return
	_t += _acc
	_acc = 0.0
	_moods()
	if _bulb != null and int(_t * FPS) % 12 == 0:
		# From dusk to the morning the bulb is on.
		var h := int(GuestManager._last_known_hour) if GuestManager != null else 12
		_bulb.visible = h >= 19 or h < 6
	for p in _puffs:
		var age := fmod(_t * 0.35 + float(p["phase"]), 1.0)
		var s: Sprite3D = p["sprite"]
		s.position = _steam_at + Vector3(sin(_t * 1.3 + float(p["phase"]) * 6.0) * 0.08 * age, age * 0.7, age * 0.1)
		s.scale = Vector3.ONE * (0.6 + age * 1.0)
		s.modulate = Color(1, 1, 1, (1.0 - age) * 0.3)
	for i in _flaps.size():
		var f := _flaps[i] as Node3D
		if is_instance_valid(f):
			f.rotation.x = sin(_t * 2.2 + i * 0.9) * 0.12
