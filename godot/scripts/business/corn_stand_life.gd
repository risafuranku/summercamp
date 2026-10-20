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
## Where those who come for a cob stand, in front of the counter (the stand's space; the
## first at the counter, the rest a loose queue behind), facing it.
const QUEUE := [Vector3(-0.45, 0, 1.15), Vector3(0.5, 0, 1.25), Vector3(0.0, 0, 1.85), Vector3(-0.95, 0, 2.05),
	Vector3(0.95, 0, 2.15), Vector3(-0.35, 0, 2.7), Vector3(0.6, 0, 2.85), Vector3(0.0, 0, 3.4)]

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
	_spot_seen[key] = _t
	member.global_position = r.global_transform * (QUEUE[int(_spot_of[key])] as Vector3)
	member.set_meta("marker_drop", 0.0)
	# Standing (the eating pictures are sat at a table).
	POSES.set_pose(sprite, str(info.get("sprite_path", "")), "")
	return true


## The stand's stations on its counter, made the first time (scripts/corn/stand_layout.gd):
## id -> station.
func make_stations(key: String) -> Dictionary:
	var r := get_parent() as Node3D
	if r == null or key == "":
		return stations
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
	# The steam off the painted pot (the counter's).
	var c: Node3D = stations.get("counter", null)
	if c != null:
		_steam_at = c.transform * (c.call("local_at", Vector2(95, 172), 0.08) as Vector3)
	return stations


func _process(delta: float) -> void:
	_acc += delta
	if _acc < 1.0 / FPS:
		return
	_t += _acc
	_acc = 0.0
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
