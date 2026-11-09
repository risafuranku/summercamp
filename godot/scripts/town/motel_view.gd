extends RefCounted

## Inside the Liblice motel (town_room.gd's places "motel", the reception, and "motel_room",
## the rooms he lets), built from its plan (motel_plan.gd, motel_rooms.gd) so its windows look
## out of the block where it stands in the village (window_portal.gd).
##
## One star, and a night in it like a clicking horror adventure (the user, 4. 11.): you walk to
## what you click (room_walk.gd) and it is done there; like in some RPG the keys hang on
## the board and every room is its own (motel_two.gd, motel_nine.gd, motel_eleven.gd; number
## four is this file's).
##   the reception  Simek behind the counter: the key off the board, once to hear what it
##                  is, again to take it (from seven); the bell, the guest book, the drinks
##                  machine, the television, the fan, the zapper, the flypaper; the door past
##                  the counter's end to the corridor (motel_hall.gd);
##   every room     the key turns twice in the lock, the chain, the peephole (the corridor
##                  through its lens); the light by the door, the curtains, the telephone, a
##                  radio (motel_radio.gd); the bathroom off the little hall: its light and
##                  the fan with it, the tap that drips, the toilet, the shower's curtain,
##                  the mirror (a real one: the room behind you, and you in it);
##   number four    two beds, the TV (late at night one more channel: the car park from the
##                  pole), the wardrobe, the radiator (knock and now and then it knocks
##                  back), the print over the beds, the clock radio with the time in red;
##   the night      lie down and sleep; town_trip passes the night and motel_night.gd
##                  weighs what wakes you: a knock, the phone, the set on by itself, the
##                  light under the bathroom door, headlights, steps upstairs, the wall,
##                  the pipes. You lie in the dark and go and see, or lie down again. In the
##                  morning something is not as it was.
## Nobody narrates: things answer with their sounds and their light. In co-op what is
## switched in a room is switched for both (_state, take_state), and you see the other
## warden walk (room_mates.gd).

const PLAN = preload("res://scripts/town/motel_plan.gd")
const ROOMS = preload("res://scripts/town/motel_rooms.gd")
const K = preload("res://scripts/interior_kit.gd")
const WINDOW_PORTAL = preload("res://scripts/ui/window_portal.gd")
const WALK = preload("res://scripts/town/room_walk.gd")
const SEVEN_SEG = preload("res://scripts/ui/seven_seg.gd")
const RADIO = preload("res://scripts/town/motel_radio.gd")
const MATES = preload("res://scripts/town/room_mates.gd")
const TWO = preload("res://scripts/town/motel_two.gd")
const NINE = preload("res://scripts/town/motel_nine.gd")
const ELEVEN = preload("res://scripts/town/motel_eleven.gd")
const LOOKS = preload("res://scripts/coop/warden_looks.gd")
const SFX := "res://assets/sfx/"
const CAMP := "res://assets/textury/camp/"
## The TV's channels at night and by day (camp pictures); "cam" the car park from the pole.
const TV_NIGHT := ["tv_testcard", "tvshow_forest", "tvshow_weather", "cam"]
const TV_DAY := ["tvshow_weather", "tvshow_forest", "tv_testcard"]
const SIMEK_LINES := [
	"Rooms from seven in the evening. Keys are on the board.",
	"The camp people used to come down for the shower. Then they stopped coming down at all.",
	"Number four has the best mattress. Number six I do not let.",
	"Eleven is ten dollars. Mr Hora paid to the end of the year.",
	"Breakfast is a promise, not a guarantee.",
	"Do not open the window in number six. It does not open, but do not.",
]
## The ways every room has (door, little hall, bathroom), number four's; the reception's.
const WAYS := [["door", "entry"], ["entry", "bathdoor"], ["bathdoor", "bathin"], ["bathin", "bath"], ["entry", "room"]]
const WAYS_FOUR := [["room", "aisle"], ["aisle", "window"], ["aisle", "tv"], ["window", "tv"], ["aisle", "bedfoot"],
	["aisle", "wardrobe"], ["wardrobe", "bedfoot"]]
const WAYS_LOBBY := [["door", "desk"], ["desk", "end"], ["door", "end"], ["end", "hall"]]
## Things you reach from the bed (the rest: you get up and go).
const FROM_BED := ["phone", "clock", "lamps", "wall", "stain"]
## What the nights leave in a room (the print by the river, the stain), n -> marks: the
## game's, not one visit's. How a room was left tonight, n -> {"night", "s"}.
static var marks := {}
static var kept := {}

var room                         # town_room.gd
var n := 0                       # 0 the reception, else the room's number
## The motel in the village (motel_block.gd): its transform maps this room out.
var block: Node3D
var parts: Dictionary = {}
## The room's own (motel_two.gd ...; null: number four), its radio.
var quirk
var radio
var windows: Array = []          # window_portal.gd
var lights: Dictionary = {}      # "ceiling", "lamp_a", "lamp_b", "tv", "day", "clock", "desk"
var lamps_on := false
var ceiling_on := false
var tv_on := false
var tv_channel := 0
var turns := 0                   # the key's turns in the lock (0 open .. 2 locked twice)
var chain_on := false
var lying := false
var asleep := false
var bath_on := false
var bath_open := false
var tap_on := false
var shower_drawn := false
var wardrobe_open := false
var phone_up := false
## What woke you ("" nothing), how long ago, what of it has happened (counts).
var event := ""
var _ev_t := 0.0
var _ev_n := 0
var _ghost := false
var _had_bath_night := false
var _went_in := false
var _woken_tonight := 0
var _t := 0.0
var _line := 0
var _tv_screen: MeshInstance3D
var _tv_mat: StandardMaterial3D
var _knock_back := -1.0
var _stand_rot := Vector3.ZERO
var _walker
var _rng := RandomNumberGenerator.new()
var _sanity := 100.0
var _looking := ""
var _look_back := {}
var _players: Array = []
var _amb: AudioStreamPlayer
var _amb2: AudioStreamPlayer
var _wall_snd: AudioStreamPlayer
var _tap_snd: AudioStreamPlayer
var _fan_snd: AudioStreamPlayer
var _fx: AudioStreamPlayer
var _ring_snd: AudioStreamPlayer
var _line_snd: AudioStreamPlayer
var _ringing := 0
var _ring_t := 0.0
var _call_t := -1.0
## The clock radio's digits (a little viewport drawn when the minute changes), its alarm.
var _clock_vp: SubViewport
var _clock_canvas: Control
var _clock_text := ""
var _alarm_t := -1.0
## The peephole: its own view of the village from outside the door, the one outside it.
var _peep_layer: CanvasLayer
var _peep_vp: SubViewport
var _peep_cam: Camera3D
var _peep_fig: Sprite3D
var _peeping := false
## The TV's car park channel: a view of the village from the pole, the one under your window.
var _cam_vp: SubViewport
var _cam_cam: Camera3D
var _cam_mat: ShaderMaterial
var _tv_fig: Sprite3D
## The mirror: its camera across the glass, you in it, the one behind you.
var _mir_vp: SubViewport
var _mir_cam: Camera3D
var _mir_me: Sprite3D
var _mir_ghost: Sprite3D
var _mir_ghost_on := false
## The leak over the bowl, the roach, the headlights.
var _drop: MeshInstance3D
var _drop_t := -1.0
var _drip_t := 2.0
var _roach: MeshInstance3D
var _roach_tex: Array = []
var _roach_path: Array = []
var _roach_t := -1.0
var _roach_wait := 30.0
var _headlight: SpotLight3D
var _head_t := -1.0
var _zap_t := 12.0
var _picked := 0
## The other wardens on foot here; what you last told them is switched.
var _crew
var _sent := ""
var _sync_t := 0.0
var _closed := false
var _taped := false


func _init(p_room, p_n: int, p_block: Node3D) -> void:
	room = p_room
	n = p_n
	block = p_block


func _origin() -> Vector3:
	return PLAN.lobby_origin() if n == 0 else PLAN.room_origin(n)


## room space -> the village (the block's own transform, the room where it stands in it).
func _xform() -> Transform3D:
	if block == null or not is_instance_valid(block) or not block.is_inside_tree():
		return Transform3D()
	return block.global_transform * Transform3D(Basis(), _origin())


func _night(hour: float) -> bool:
	return hour >= 19.5 or hour < 6.5


## The hour now (town_trip's clock: the room's own `hour` is the one you came in at).
func _now() -> float:
	var trip = room.get_parent()
	return float(trip.hour()) if trip != null and trip.has_method("hour") else float(room.hour)


func _main():
	var trip = room.get_parent()
	return trip._main() if trip != null and trip.has_method("_main") else null


## The hidden sanity of this machine's warden (coop_night.gd keeps it, 0..100).
func _read_sanity() -> float:
	var main = _main()
	var night = main.get("_coop_night") if main != null else null
	if night == null or not is_instance_valid(night):
		return 100.0
	var s = night.get("sanity")
	if not (s is Dictionary):
		return 100.0
	return float((s as Dictionary).get("own" if Coop.is_client() else "host", 100.0))


func _low() -> float:
	return clampf((100.0 - _sanity) / 100.0, 0.0, 1.0)


func _raining() -> bool:
	var main = _main()
	var ws = main.get("weather_system") if main != null else null
	var w := int(ws.get("current_weather")) if ws != null else 0
	return w >= 3 and w <= 5


# ── building ─────────────────────────────────────────────────────────────────

func build(hour: float, keys: Array) -> void:
	_rng.randomize()
	_sanity = _read_sanity()
	var root: Node3D = room._root
	if n == 0:
		parts = ROOMS.build_lobby(root, true, keys)
		_lobby_things(hour)
	else:
		var mk := _marks()
		parts = ROOMS.build_room(root, n, true, {"made": true, "painting": int(mk["painting"]), "stain": int(mk["stain"])})
		match n:
			2:
				quirk = TWO.new(self, room)
			9:
				quirk = NINE.new(self, room)
			11:
				quirk = ELEVEN.new(self, room)
		_room_things(hour)
		# Coming in after dark you flick the switch by the door.
		ceiling_on = _night(hour)
		radio = RADIO.new(self, room, quirk.radio_voice() if quirk != null else "clock")
	_make_windows()
	_set_light(hour)
	_sounds(hour)
	if n != 0:
		var k: Dictionary = kept.get(n, {})
		if not k.is_empty() and int(k.get("night", -1)) == _night_no():
			take_state(k.get("s", {}), true)
	_sent = _state_key()
	Coop.send_place("town", "motel", "walk", [str(_walker.here)])


func _marks() -> Dictionary:
	if not marks.has(n):
		marks[n] = {"painting": 0, "stain": 0}
	return marks[n]


func _night_no() -> int:
	var trip = room.get_parent()
	return int(trip._night_index(_now())) if trip != null and trip.has_method("_night_index") else 1


func _lobby_things(hour: float) -> void:
	var simek: Vector3 = parts.get("simek", Vector3.ZERO)
	room._npc_sprite("town_motel", 1.7, simek, "him")
	var c: Vector3 = parts.get("counter", Vector3(0, 1.1, 0.55))
	room._hot_box("desk", c + Vector3(0, -0.5, -0.2), Vector3(2.8, 1.1, 0.4), [])
	if parts.get("bell") != null:
		room._hot_box("bell", (parts["bell"] as Node3D).position + Vector3(0, 0.06, 0), Vector3(0.22, 0.16, 0.22), [parts["bell"]])
	if parts.get("book") != null:
		room._hot_box("book", (parts["book"] as Node3D).position, Vector3(0.45, 0.06, 0.32), [parts["book"]])
	if parts.get("vending") != null:
		var vm: Node3D = parts["vending"]
		room._hot_box("machine", vm.position + Vector3(0.2, 0.9, 0), Vector3(0.4, 1.8, 0.9), [vm])
	var tv: Dictionary = parts.get("tv", {})
	if not tv.is_empty():
		room._hot_box("tv", (tv["at"] as Vector3) + Vector3(0, 0.25, 0), Vector3(0.65, 0.5, 0.5), [tv["node"]])
		_make_tv_screen(tv["node"], Vector2(0.62, 0.465), Rect2(0.13, 0.17, 0.62, 0.6))
	var door := PLAN.room_door(0)
	room._hot_box("door", Vector3(door.x, 1.0, door.z + 0.05), Vector3(1.0, 2.1, 0.15), [])
	# The keys on the board behind him, the door to the corridor past the counter's end.
	var keys: Dictionary = parts.get("keys", {})
	for k in keys:
		var kn: Node3D = keys[k]
		room._hot_box("key%d" % int(k), kn.position + Vector3(0, 0.07, -0.04), Vector3(0.13, 0.2, 0.08), [kn])
	var hd = parts.get("hall_door")
	room._hot_box("hall", Vector3(PLAN.LOBBY_HALL_X, 1.0, PLAN.lobby_size().z * 0.5 - 0.06), Vector3(0.95, 2.05, 0.1), [hd] if hd != null else [])
	# You stand inside the door, the counter before you; or you came back from the corridor.
	var sp := _lobby_spots()
	_walker = WALK.new(room, sp, WAYS_LOBBY, "door", SFX + "rooms/steps_wood.mp3", -17.0)
	_walker.on_go = func(to: String): _went(to)
	var from_hall := str(room.arrive_spot) == "hall" and sp.has("hall")
	# Back through from the corridor you are still going the way you were going: into the
	# reception, the door behind you (the spot's own look is for walking up to that door).
	_walker.put("hall" if from_hall else "door", Vector3(deg_to_rad(-4.0), 0.0, 0.0) if from_hall else null)
	if from_hall:
		room.get_tree().create_timer(0.25).timeout.connect(func():
			if _alive() and str(_walker.here) == "hall":
				_walker.go("end", Callable(), Vector3(deg_to_rad(-4.0), deg_to_rad(82.0), 0.0)))
	# The counter lit on the floor; the doors take you through by their own click.
	_walker.floor_spots(["desk"], Vector2(0.8, 0.8))
	_crew = MATES.new(room, sp, WAYS_LOBBY, "door")
	room._look.yaw_limit_deg = 180.0
	if parts.get("zapper") != null:
		var zl := OmniLight3D.new()
		zl.light_color = Color(0.45, 0.6, 1.0)
		zl.light_energy = 0.35
		zl.omni_range = 1.6
		zl.position = (parts["zapper"] as Node3D).position + Vector3(-0.25, 0.15, 0)
		room._root.add_child(zl)
		lights["zapper"] = zl


## Where you stand in the reception: inside the street door, at the counter, past its end,
## at the door to the corridor.
func _lobby_spots() -> Dictionary:
	var r := func(p: float, y: float) -> Vector3: return Vector3(deg_to_rad(p), deg_to_rad(y), 0.0)
	var door := PLAN.room_door(0)
	var c: Vector3 = parts.get("counter", Vector3(0, 1.1, 0.55))
	var hx := PLAN.LOBBY_HALL_X
	return {
		"door": {"at": Vector3(door.x, 1.6, door.z + 0.7), "rot": Vector3(deg_to_rad(-5.0), PI - 0.31, 0.0)},
		"desk": {"at": Vector3(c.x + 0.1, 1.6, c.z - 0.82), "rot": r.call(-1.0, 180.0)},
		"end": {"at": Vector3(hx, 1.6, c.z - 0.82), "rot": r.call(-4.0, 180.0)},
		"hall": {"at": Vector3(hx, 1.6, PLAN.lobby_size().z * 0.5 - 0.62), "rot": r.call(-4.0, 180.0)},
	}


## Where you can stand in a room and how you look there: the door, the little hall, the
## bathroom, the way into the bedroom in all of them; the bedroom's are the room's own.
func _spots() -> Dictionary:
	var r := func(p: float, y: float) -> Vector3: return Vector3(deg_to_rad(p), deg_to_rad(y), 0.0)
	var out := _spots_common()
	if quirk != null:
		out.merge(quirk.spots(), true)
	else:
		out.merge({
			"wardrobe": {"at": Vector3(-0.5, 1.6, -0.45), "rot": r.call(-8.0, 90.0)},
			"aisle": {"at": Vector3(1.02, 1.6, -0.35), "rot": r.call(-8.0, 0.0)},
			"window": {"at": Vector3(0.68, 1.6, -1.4), "rot": r.call(-4.0, 0.0)},
			"tv": {"at": Vector3(0.5, 1.6, -0.75), "rot": r.call(-30.0, -42.0)},
			"bedfoot": {"at": Vector3(-0.72, 1.6, -0.05), "rot": r.call(-16.0, 180.0)},
		}, true)
	return out


func _ways() -> Array:
	return WAYS + (quirk.ways() if quirk != null else WAYS_FOUR)


func _spots_common() -> Dictionary:
	var r := func(p: float, y: float) -> Vector3: return Vector3(deg_to_rad(p), deg_to_rad(y), 0.0)
	return {
		"door": {"at": Vector3(1.06, 1.6, PLAN.BACK_Z + PLAN.BACK_D - 0.45), "rot": r.call(-6.0, 180.0)},
		"entry": {"at": PLAN.STAND, "rot": r.call(-6.0, 0.0)},
		"bathdoor": {"at": Vector3(1.05, 1.6, (PLAN.INNER_DOOR_Z.x + PLAN.INNER_DOOR_Z.y) * 0.5), "rot": r.call(-6.0, 90.0)},
		"bathin": {"at": Vector3(0.05, 1.6, (PLAN.INNER_DOOR_Z.x + PLAN.INNER_DOOR_Z.y) * 0.5), "rot": r.call(-6.0, 90.0)},
		"bath": {"at": Vector3(PLAN.BATH_X.x + 0.62, 1.6, PLAN.BACK_Z + ROOMS.MIRROR_Z_OFF), "rot": r.call(-6.0, 90.0)},
		"room": {"at": Vector3(1.05, 1.6, 1.7), "rot": r.call(-6.0, 0.0)},
	}


func _room_things(hour: float) -> void:
	var d := PLAN.room_door(n)
	var w := PLAN.ROOM_W
	var dd := PLAN.ROOM_D
	var z1 := PLAN.BACK_Z + PLAN.BACK_D
	room._hot_box("door", Vector3(d.x, 1.0, z1 + 0.02), Vector3(0.7, 2.05, 0.06), [])
	if parts.get("key") != null:
		room._hot_box("lock", (parts["key"] as Node3D).position + Vector3(0, 0.1, -0.04), Vector3(0.22, 0.26, 0.08), [parts["key"]])
	if parts.get("chain") != null:
		room._hot_box("chain", (parts["chain"] as Node3D).position + Vector3(0, 0.1, -0.04), Vector3(0.2, 0.22, 0.08), [parts["chain"]])
	room._hot_box("peephole", Vector3(d.x, 1.55, z1 - 0.02), Vector3(0.14, 0.14, 0.08), [parts.get("peephole")] if parts.get("peephole") != null else [])
	if parts.get("switch") != null:
		room._hot_box("switch", (parts["switch"] as Node3D).position + Vector3(-0.04, 0, 0), Vector3(0.1, 0.2, 0.16), [parts["switch"]])
	if quirk == null:
		for u in [0.155, 0.845]:
			var at := PLAN.headwall_at(float(u), 0.54)
			room._hot_box("lamps", Vector3(at.x, at.y, dd * 0.5 - 0.08), Vector3(0.3, 0.25, 0.12), [])
		room._hot_box("wall", Vector3(PLAN.headwall_rect().x, 0.82, dd * 0.5 - 0.04), Vector3(PLAN.headwall_rect().y, 0.24, 0.06), [])
		for i in PLAN.BED_X.size():
			room._hot_box("bed", Vector3(PLAN.BED_X[i], 0.35, PLAN.BED_Z), Vector3(PLAN.BED_SIZE.x, 0.4, PLAN.BED_SIZE.z), [])
		room._hot_box("wardrobe", Vector3(-w * 0.5 + 0.21, 0.95, PLAN.WARDROBE_Z), Vector3(0.44, 1.9, 1.0), [parts.get("wardrobe")] if parts.get("wardrobe") != null else [])
		var win: Vector3 = PLAN.room_windows(n)[0]
		room._hot_box("radiator", Vector3(win.x, 0.4, -dd * 0.5 + 0.12), Vector3(1.0, 0.55, 0.2), [])
		room._hot_box("stain", Vector3(0.95, PLAN.ROOM_H - 0.05, 0.45), Vector3(1.0, 0.06, 0.9), [])
	else:
		for b in parts.get("beds", []):
			room._hot_box("bed", b["at"], b["size"], [])
		for lp in parts.get("lamp_points", []):
			room._hot_box("lamps", lp, Vector3(0.22, 0.34, 0.22), [])
	if parts.get("print") != null:
		var pr: Node3D = parts["print"]
		room._hot_box("print", pr.position + Vector3(0, 0, -0.03), Vector3(0.72, 0.52, 0.06), [pr])
	if parts.get("phone") != null:
		room._hot_box("phone", (parts["phone"] as Node3D).position + Vector3(0, 0.06, 0), Vector3(0.22, 0.14, 0.18), [parts["phone"]])
	if bool(parts.get("digits", false)):
		room._hot_box("clock", (parts["clock"] as Node3D).position + Vector3(0, 0.05, 0), Vector3(0.16, 0.12, 0.12), [parts["clock"]])
		_make_clock()
	var tv: Dictionary = parts.get("tv", {})
	if not tv.is_empty():
		room._hot_box("tv", (tv["at"] as Vector3) + Vector3(0, 0.3, 0), Vector3(0.5, 0.6, 0.5), [tv["node"]])
		_make_tv_screen(tv["node"], ROOMS.TV_SIZE, ROOMS.TV_SCREEN)
	# The bathroom: its door, the switch outside it, the basin, the mirror, the toilet, the shower.
	var dz := (PLAN.INNER_DOOR_Z.x + PLAN.INNER_DOOR_Z.y) * 0.5
	room._hot_box("bathdoor", Vector3(PLAN.HALL_X.x + 0.02, 1.0, dz), Vector3(0.08, 2.0, PLAN.INNER_DOOR_Z.y - PLAN.INNER_DOOR_Z.x), [])
	if parts.get("bath_switch") != null:
		room._hot_box("bathswitch", (parts["bath_switch"] as Node3D).position + Vector3(0.04, 0, 0), Vector3(0.1, 0.2, 0.16), [parts["bath_switch"]])
	var x0 := PLAN.BATH_X.x
	var bz := PLAN.BACK_Z + ROOMS.MIRROR_Z_OFF
	room._hot_box("tap", Vector3(x0 + 0.12, 0.82, bz), Vector3(0.24, 0.3, 0.5), [])
	room._hot_box("mirror", Vector3(x0 + 0.05, ROOMS.MIRROR_Y, bz), Vector3(0.08, 0.5, 0.46), [])
	room._hot_box("toilet", Vector3(-0.4, 0.5, z1 - 0.25), Vector3(0.45, 1.0, 0.45), [])
	if parts.get("shower_curtain") != null:
		var span: Vector2 = parts["shower_span"]
		room._hot_box("shower", Vector3((span.x + span.y) * 0.5, 1.0, PLAN.BACK_Z + 0.72), Vector3(span.y - span.x, 1.9, 0.12), [parts["shower_curtain"]])
	var sp := _spots()
	_walker = WALK.new(room, sp, _ways(), "door", SFX + "rooms/steps_wood.mp3", -17.0)
	_walker.on_go = func(to: String): _went(to)
	_walker.put("door")
	# Through the door you face the room: the door spot's own look is for going back to it, and
	# you stood with your back to the room and spun round (the user 7. 11.).
	room._base_rot = _walker.at_rot("entry")
	# Two places lit on the floor, the room and the view from its window; everything else takes
	# you to it by its own click (the user 7. 11.: "far too many places to stand").
	_walker.floor_spots(["room", "window"], Vector2(0.8, 0.8))
	_crew = MATES.new(room, sp, _ways(), "door")
	if quirk != null:
		quirk.things(hour)
	_stand_rot = room._base_rot
	room._look.yaw_limit_deg = 180.0
	room._look.pitch_up_deg = 40.0
	room._look.pitch_down_deg = 45.0
	room._cam.cull_mask = 0xFFFFF & ~ROOMS.ONLY_MIRROR
	if parts.has("drip_at"):
		_make_leak()
	_make_roach()
	# Through the little hall and into the room as you come in.
	room.get_tree().create_timer(0.35).timeout.connect(func():
		if _alive() and str(_walker.here) == "door":
			_walker.go("room"))


## A picture for the TV's screen, laid over the screen of its sprite (which turns to you):
## a quad turned with it each frame, a hair in front.
func _make_tv_screen(tv_node: Node3D, size: Vector2, screen: Rect2) -> void:
	_tv_mat = StandardMaterial3D.new()
	_tv_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tv_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_tv_screen = MeshInstance3D.new()
	_tv_screen.name = "TvScreen"
	var q := QuadMesh.new()
	q.size = Vector2(size.x * screen.size.x, size.y * screen.size.y)
	_tv_screen.mesh = q
	_tv_screen.material_override = _tv_mat
	_tv_screen.visible = false
	_tv_screen.set_meta("retro_skip", true)
	_tv_screen.set_meta("screen_rect", screen)
	_tv_screen.set_meta("tv_size", size)
	_tv_screen.set_meta("tv", tv_node)
	room._root.add_child(_tv_screen)


func _make_windows() -> void:
	var root: Node3D = room._root
	var i := 0
	for wc in PLAN.room_windows(n):
		var w = WINDOW_PORTAL.make(room, root, (wc as Vector3) + Vector3(0, 0, 0.02), Vector3(0, 0, -1), PLAN.window_size(), "motel_curtain" if ResourceLoader.exists("res://assets/textury/camp/motel_curtain.png") else "curtain_floral")
		if w.body != null:
			w.body.set_meta("room_hot", "curtain%d" % i)
			room._hot["curtain%d" % i] = {"body": w.body, "meshes": []}
		windows.append(w)
		i += 1


## The drop from the stain into the bowl.
func _make_leak() -> void:
	_drop = MeshInstance3D.new()
	_drop.name = "Drop"
	var q := QuadMesh.new()
	q.size = Vector2(0.012, 0.045)
	_drop.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.62, 0.58, 0.48)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	_drop.material_override = m
	_drop.visible = false
	_drop.set_meta("retro_skip", true)
	room._root.add_child(_drop)
	room._hot_box("bowl", Vector3(0.95, 0.1, 0.45), Vector3(0.3, 0.2, 0.3), [])


## The roach: two frames from above, flat on the wall or the floor as it runs.
func _make_roach() -> void:
	for t in ["roach_0", "roach_1"]:
		if ResourceLoader.exists(CAMP + t + ".png"):
			_roach_tex.append(load(CAMP + t + ".png"))
	if _roach_tex.size() < 2:
		return
	_roach = MeshInstance3D.new()
	_roach.name = "Roach"
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	_roach.mesh = q
	var m := K._base(Color(1, 1, 1))
	m.albedo_texture = _roach_tex[0]
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	_roach.material_override = m
	_roach.visible = false
	room._root.add_child(_roach)
	_roach_wait = _rng.randf_range(18.0, 45.0)


# ── light ────────────────────────────────────────────────────────────────────

func _set_light(hour: float) -> void:
	var env: Environment = room._env
	var day := hour >= 7.0 and hour < 18.5
	var dusk := not day and (hour >= 18.5 and hour < 20.0 or hour >= 5.5 and hour < 7.0)
	env.ambient_light_color = Color(0.84, 0.8, 0.7) if day else Color(0.48, 0.52, 0.64)
	env.ambient_light_energy = 0.36 if day else (0.16 if dusk else 0.075)
	for k in lights.keys():
		if k == "zapper":
			continue
		if is_instance_valid(lights[k]):
			(lights[k] as Node).queue_free()
		lights.erase(k)
	var root: Node3D = room._root
	# Daylight through the window(s); at night the car park's lamp and the sign.
	for wc in PLAN.room_windows(n):
		var l: OmniLight3D
		if day or dusk:
			l = _omni(root, (wc as Vector3) + Vector3(0, 0.1, 0.9), Color(0.9, 0.92, 0.9) if day else Color(0.9, 0.62, 0.5), 0.85 if day else 0.42, 5.0)
		else:
			l = _omni(root, (wc as Vector3) + Vector3(0, 0.2, 0.5), Color(0.95, 0.55, 0.42), 0.16, 3.4)
		lights["day%d" % lights.size()] = l
	if n == 0:
		# Simek's desk lamp, always on after dark; the room's light by day.
		var c: Vector3 = parts.get("counter", Vector3(0, 1.1, 0.55))
		lights["desk"] = _omni(root, c + Vector3(-1.05, 0.45, 0.15), Color(1.0, 0.78, 0.5), 0.9, 4.0, true)
		lights["ceiling"] = _omni(root, Vector3(0, PLAN.ROOM_H - 0.3, 0), Color(1.0, 0.86, 0.66), 0.62 if not day else 0.36, 6.0)
		return
	var pts: Array = parts.get("lamp_points", [])
	if pts.size() > 0:
		lights["lamp_a"] = _omni(root, pts[0], Color(1.0, 0.72, 0.42), 0.5, 2.5, true)
	if pts.size() > 1:
		lights["lamp_b"] = _omni(root, pts[1], Color(1.0, 0.72, 0.42), 0.5, 2.5)
	lights["ceiling"] = _omni(root, parts.get("ceiling_at", Vector3(0, PLAN.ROOM_H - 0.55, 0.2)), Color(1.0, 0.84, 0.6), 0.95, 5.5, true)
	if parts.has("hall_at"):
		lights["hall"] = _omni(root, parts["hall_at"], Color(1.0, 0.8, 0.56), 0.6, 3.0)
	var tv: Dictionary = parts.get("tv", {})
	if not tv.is_empty():
		lights["tv"] = _omni(root, (tv["at"] as Vector3) + Vector3(-0.3, 0.4, 0.3), Color(0.6, 0.72, 1.0), 0.5, 3.0)
	if bool(parts.get("digits", false)):
		lights["clock"] = _omni(root, (parts["clock"] as Node3D).position + Vector3(0.04, 0.07, -0.1), Color(1.0, 0.24, 0.14), 0.025 if not day else 0.0, 0.3)
	_apply_switches()


func _omni(root: Node3D, pos: Vector3, col: Color, energy: float, rng: float, shadow := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.1
	l.shadow_enabled = shadow
	root.add_child(l)
	return l


func _apply_switches() -> void:
	for k in ["lamp_a", "lamp_b"]:
		if lights.has(k):
			(lights[k] as OmniLight3D).visible = lamps_on
	for g in parts.get("lamps", []):
		(g as Node3D).visible = lamps_on
	if lights.has("ceiling"):
		(lights["ceiling"] as OmniLight3D).visible = ceiling_on
	if lights.has("hall"):
		(lights["hall"] as OmniLight3D).visible = ceiling_on
	if lights.has("tv"):
		(lights["tv"] as OmniLight3D).visible = tv_on
	if _tv_screen != null:
		_tv_screen.visible = tv_on
	_apply_bath()


## The bathroom's light (and the fan on it), its door, the line of light under it.
func _apply_bath() -> void:
	if parts.get("bath_light") != null:
		(parts["bath_light"] as OmniLight3D).visible = bath_on
	if parts.get("gap") != null:
		(parts["gap"] as Node3D).visible = bath_on and not bath_open
		(parts["gap_light"] as Node3D).visible = bath_on and not bath_open
	if parts.get("bath_door") != null:
		var tw: Tween = room.create_tween()
		tw.tween_property(parts["bath_door"], "rotation:y", deg_to_rad(95.0) if bath_open else 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if parts.get("shower_curtain") != null:
		var sc: Node3D = parts["shower_curtain"]
		var span: Vector2 = parts["shower_span"]
		var w := span.y - span.x
		sc.scale.x = 1.0 if shower_drawn else 0.28
		sc.position.x = (span.x + span.y) * 0.5 if shower_drawn else span.y - w * 0.14
	_tap_mix()


## Is anybody's light on in here (the room lit from the car park).
func lit() -> bool:
	return lamps_on or ceiling_on or tv_on


# ── sound ────────────────────────────────────────────────────────────────────

func _player(db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = db
	room.add_child(p)
	_players.append(p)
	return p


func _loop_on(p: AudioStreamPlayer, path: String, db: float) -> void:
	if not ResourceLoader.exists(SFX + path):
		return
	if p.stream == null or p.stream.resource_path != SFX + path:
		var s = load(SFX + path)
		if s is AudioStreamMP3:
			s = (s as AudioStreamMP3).duplicate()
			s.loop = true
		elif s is AudioStreamOggVorbis:
			s = (s as AudioStreamOggVorbis).duplicate()
			s.loop = true
		p.stream = s
	p.volume_db = db
	if not p.playing:
		p.play()


func _sounds(hour: float) -> void:
	_amb = _player(-22.0)
	_amb2 = _player(-30.0)
	_tap_snd = _player(-30.0)
	_fan_snd = _player(-30.0)
	_fx = _player(-8.0)
	_ring_snd = _player(-6.0)
	_line_snd = _player(-14.0)
	if n == 0:
		_loop_on(_amb, "motel/lobby_fan.ogg", -21.0)
		_loop_on(_amb2, "motel/flies.ogg", -27.0)
		return
	if _night(hour):
		_loop_on(_amb, "motel/room_night.ogg", -21.0)
		_loop_on(_amb2, "motel/neon_buzz.ogg", -31.0)
		# Somebody's music through the wall (the user, 4. 11.): next door when next door is
		# taken tonight, else from further along the floor.
		_wall_snd = _player(-40.0)
		_loop_on(_wall_snd, "motel/wall_music.ogg", -19.0 if _neighbours() else -27.0)
	else:
		_loop_on(_amb, "motel/flies.ogg", -26.0)
	_tap_mix()


## The tap and the fan as loud as the bathroom's door lets them be.
func _tap_mix() -> void:
	if _tap_snd == null or n == 0:
		return
	var near := _walker != null and (str(_walker.here) == "bath" or str(_walker.here) == "bathin")
	var muffle := 0.0 if (bath_open or near) else -12.0
	if tap_on:
		_loop_on(_tap_snd, "motel/tap_run.ogg", -14.0 + muffle)
	else:
		_loop_on(_tap_snd, "motel/tap_drip.ogg", -24.0 + muffle)
	if bath_on:
		_loop_on(_fan_snd, "motel/fan_rattle.ogg", -18.0 + muffle)
	elif _fan_snd.playing:
		_fan_snd.stop()


func _fx_play(path: String, db: float) -> void:
	if not ResourceLoader.exists(SFX + path):
		return
	_fx.stream = load(SFX + path)
	_fx.volume_db = db
	_fx.pitch_scale = 1.0
	_fx.play()


func _play(path: String, db: float) -> void:
	room._play(SFX + path, db)


# ── each frame ───────────────────────────────────────────────────────────────

func tick(delta: float) -> void:
	_t += delta
	var world: World3D = block.get_world_3d() if block != null and is_instance_valid(block) and block.is_inside_tree() else null
	var xf := _xform()
	var shell: Node3D = block.shell(n) if block != null and is_instance_valid(block) and block.has_method("shell") else null
	for w in windows:
		w.update(room._root, room._cam, xf, world != null and not asleep and not _peeping, world, delta, shell)
	_tick_tv()
	if _knock_back > 0.0:
		_knock_back -= delta
		if _knock_back <= 0.0:
			# Two knocks in the pipe, from somewhere in the building.
			_play("motel/radiator_knock.mp3", -9.0)
	if _crew != null:
		_crew.tick(delta)
	if n == 0:
		_tick_zapper(delta)
		return
	_tick_sync(delta)
	radio.tick(delta)
	if quirk != null:
		quirk.tick(delta)
	_tick_clock()
	_tick_event(delta)
	_tick_phone(delta)
	_tick_drip(delta)
	_tick_roach(delta)
	_tick_headlights(delta)
	_tick_mirror()
	if _alarm_t > 0.0:
		_alarm_t -= delta
		if _alarm_t <= 0.0:
			_line_snd.stop()


func _tick_tv() -> void:
	if _tv_screen == null or not tv_on:
		return
	var tv: Node3D = _tv_screen.get_meta("tv")
	if tv == null or not is_instance_valid(tv):
		return
	# The sprite turns with the eye's view about Y (a billboard faces the camera's plane,
	# not its position): the screen the same, a hair towards the eye.
	var base: Vector3 = tv.global_position
	var cam: Camera3D = room._cam
	var fwd: Vector3 = -cam.global_basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		return
	var to_eye: Vector3 = -fwd.normalized()
	var size: Vector2 = _tv_screen.get_meta("tv_size")
	var sr: Rect2 = _tv_screen.get_meta("screen_rect")
	var right := Vector3.UP.cross(to_eye).normalized()
	var cx := (sr.position.x + sr.size.x * 0.5 - 0.5) * size.x
	var cy := (1.0 - (sr.position.y + sr.size.y * 0.5)) * size.y
	_tv_screen.global_position = base + right * -cx + Vector3(0, cy, 0) + to_eye * 0.012
	_tv_screen.global_basis = Basis.looking_at(-to_eye, Vector3.UP)
	if _cam_mat != null and _tv_screen.material_override == _cam_mat:
		_cam_mat.set_shader_parameter("t", _t)
	# The picture's light flickers with it, in steps.
	if lights.has("tv"):
		var k := floorf(_t * 8.0)
		(lights["tv"] as OmniLight3D).light_energy = 0.32 + 0.22 * absf(sin(k * 1.7))


## The zapper on the reception's wall: now and then a fly, a crackle, the blue flicks.
func _tick_zapper(delta: float) -> void:
	if not lights.has("zapper"):
		return
	_zap_t -= delta
	var zl: OmniLight3D = lights["zapper"]
	if _zap_t <= 0.0:
		_zap_t = _rng.randf_range(14.0, 40.0)
		_fx_play("motel/fly_zapper.mp3", -16.0)
		zl.light_energy = 1.4
	zl.light_energy = maxf(0.35, zl.light_energy - delta * 6.0)


# ── the clock radio ──────────────────────────────────────────────────────────

func _make_clock() -> void:
	var clock: MeshInstance3D = parts.get("clock")
	if clock == null:
		return
	var rect := _clock_window()
	var s := ((clock.mesh as QuadMesh).size)
	_clock_vp = SubViewport.new()
	_clock_vp.size = Vector2i(48, 18)
	_clock_vp.transparent_bg = true
	_clock_vp.disable_3d = true
	_clock_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	room.add_child(_clock_vp)
	_clock_canvas = Control.new()
	_clock_canvas.size = Vector2(48, 18)
	_clock_canvas.draw.connect(_draw_clock)
	_clock_vp.add_child(_clock_canvas)
	var q := MeshInstance3D.new()
	q.name = "ClockDigits"
	var qm := QuadMesh.new()
	qm.size = Vector2(rect.size.x * s.x, rect.size.y * s.y)
	q.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.3
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.albedo_texture = _clock_vp.get_texture()
	q.material_override = m
	q.position = Vector3((rect.position.x + rect.size.x * 0.5 - 0.5) * s.x, (1.0 - rect.position.y - rect.size.y * 0.5) * s.y, 0.003)
	q.set_meta("retro_skip", true)
	clock.add_child(q)


## The clock's black digit window in its picture (its darkest block), as fractions.
func _clock_window() -> Rect2:
	var path := CAMP + "clock_radio.png"
	var fallback := Rect2(0.45, 0.3, 0.42, 0.3)
	if not ResourceLoader.exists(path):
		return fallback
	var img: Image = (load(path) as Texture2D).get_image()
	if img == null:
		return fallback
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var x0 := w
	var y0 := h
	var x1 := -1
	var y1 := -1
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a > 0.5 and c.get_luminance() < 0.1:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	if x1 - x0 < 3 or y1 - y0 < 2:
		return fallback
	return Rect2(float(x0) / w, float(y0) / h, float(x1 - x0 + 1) / w, float(y1 - y0 + 1) / h)


func _tick_clock() -> void:
	if _clock_vp == null:
		return
	var h := _now()
	var text := "%02d:%02d" % [int(h) % 24, int(fmod(h, 1.0) * 60.0)]
	if text == _clock_text:
		return
	_clock_text = text
	_clock_canvas.queue_redraw()
	_clock_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _draw_clock() -> void:
	var hgt := 14.0
	var w := SEVEN_SEG.text_width(_clock_text, hgt)
	var pos := Vector2(floorf((48.0 - w) * 0.5), 2.0)
	SEVEN_SEG.draw_text(_clock_canvas, pos, hgt, _clock_text, Color(1.0, 0.16, 0.08), Color(0.3, 0.03, 0.02, 0.5), true, false)


## The alarm in the morning: the radio on the clock, until you knock it off.
func _alarm() -> void:
	var jingle := SFX + "radio/signalplus_jingle.mp3"
	if ResourceLoader.exists(jingle):
		_line_snd.stream = load(jingle)
		_line_snd.volume_db = -13.0
		_line_snd.play()
		_alarm_t = 26.0


# ── the night ────────────────────────────────────────────────────────────────

## Woken in the night by `kind` (motel_night.gd; "" nothing: the other warden got up). The
## eyes open in the dark room, the clock in red, and it begins.
func woken(kind: String) -> void:
	asleep = false
	_sanity = _read_sanity()
	if lamps_on or ceiling_on:
		lamps_on = false
		ceiling_on = false
		_apply_switches()
	if _night(_now()):
		_loop_on(_amb, "motel/room_night.ogg", -21.0)
		_loop_on(_amb2, "motel/neon_buzz.ogg", -31.0)
	if kind == "" or kind == event:
		return
	event = kind
	_ev_t = 0.0
	_ev_n = 0
	_woken_tonight += 1
	_ghost = _rng.randf() < 0.22 + 0.6 * _low()
	if quirk != null:
		quirk.woken(kind)
	# Eyes open on the clock first (the red digits, 02:47), then back to the dark room.
	var clock: Node3D = parts.get("clock")
	if lying and clock != null:
		var d: Vector3 = clock.position + Vector3(0, 0.05, 0) - room._cam.position
		var back: Vector3 = room._base_rot
		var tw: Tween = room.create_tween()
		tw.tween_property(room, "_base_rot", Vector3(atan2(d.y, Vector2(d.x, d.z).length()), atan2(-d.x, -d.z), 0.0), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_interval(1.4)
		tw.tween_property(room, "_base_rot", back, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	match kind:
		"bath":
			_had_bath_night = true
			bath_on = true
			bath_open = false
			tap_on = true
			shower_drawn = true
			_apply_bath()
		"phone":
			_ringing = 8
			_ring_t = 1.0
		"car":
			_head_t = 0.0


func _tick_event(delta: float) -> void:
	if event == "" or asleep:
		return
	_ev_t += delta
	match event:
		"knock":
			# Three knocks, again while nobody looks through the peephole.
			var due := 1.2 + 8.0 * float(_ev_n)
			if _ev_n < 3 and _ev_t >= due and not _peeping:
				_fx_play("motel/knock_door.mp3", -4.0 + 2.0 * float(_ev_n))
				_ev_n += 1
		"tv":
			if _ev_n == 0 and _ev_t >= 1.6:
				_ev_n = 1
				if quirk != null:
					quirk.set_by_itself()
				else:
					tv_on = true
					tv_channel = TV_NIGHT.size() - 1 if (_ghost and block != null) else 0
					_set_channel()
					_play("backroom/tv_on.mp3", -6.0)
					_loop_on(_amb2, "backroom/tv_hiss.mp3", -16.0)
					_apply_switches()
		"upstairs":
			if _ev_n == 0 and _ev_t >= 1.0:
				_ev_n = 1
				_fx_play("motel/steps_above.mp3", -6.0)
			elif _ev_n == 1 and _ev_t >= 9.0:
				_ev_n = 2
				_fx_play("god/thud_b.mp3", -14.0)
		"wall":
			var side := _neighbours()
			if _ev_n == 0 and _ev_t >= 1.0:
				_ev_n = 1
				if side:
					_loop_on(_amb2, "motel/neighbour_tv.ogg", -20.0)
				else:
					_fx_play("motel/wall_scratch.mp3", -6.0)
			elif _ev_n == 1 and _ev_t >= 6.5:
				_ev_n = 2
				_fx_play("motel/neighbour_cough.mp3" if side else "motel/wall_scratch.mp3", -10.0 if side else -4.0)
			elif _ev_n == 2 and _ev_t >= 14.0 and side and _rng.randf() < 0.5:
				_ev_n = 3
				_fx_play("motel/neighbours_argue.mp3", -12.0)
			elif _ev_t >= 26.0 and side:
				_loop_on(_amb2, "motel/neon_buzz.ogg", -31.0)
		"radiator":
			for k in 3:
				if _ev_n == k and _ev_t >= 1.0 + 1.1 * float(k):
					_ev_n = k + 1
					_play("motel/radiator_knock.mp3", -4.0)
		"car":
			if _ev_n == 0 and _ev_t >= 0.6:
				_ev_n = 1
				_fx_play("motel/car_arrive.mp3", -6.0)
		"bath":
			if _ev_n == 0 and _ev_t >= 2.5:
				_ev_n = 1
				_fx_play("motel/toilet_gurgle.mp3", -12.0)


## Somebody either side of you tonight.
func _neighbours() -> bool:
	var taken: Array = PLAN.taken(_night_no())
	for k in PLAN.beside(n):
		if taken.has(int(k)):
			return true
	return false


## The phone: ringing (once every four seconds, eight times), the call when you pick up.
func _tick_phone(delta: float) -> void:
	if _ringing > 0 and not phone_up:
		_ring_t -= delta
		if _ring_t <= 0.0:
			_ring_t = 4.2
			_ringing -= 1
			if ResourceLoader.exists(SFX + "phone/bell.mp3"):
				_ring_snd.stream = load(SFX + "phone/bell.mp3")
				_ring_snd.play()
	if _call_t >= 0.0 and phone_up:
		_call_t += delta
		if _call_t >= 1.6 and _call_t - delta < 1.6:
			_fx_play(_on_the_line(), -10.0)
		if _call_t >= 9.0:
			_call_t = -1.0
			_line_on("phone/dead.mp3", -16.0)


## What is on the line: never a voice. Breathing, the bell from the village, water, the
## snow of a set, as the night is.
func _on_the_line() -> String:
	var trip = room.get_parent()
	var night := int(trip._night_index(_now())) if trip != null and trip.has_method("_night_index") else 1
	var picks: Array = ["motel/phone_breath.mp3", "pipes/drip.mp3", "backroom/tv_hiss.mp3"]
	if PLAN.six_lit(night, _now()):
		picks = ["motel/phone_breath.mp3", "motel/phone_breath.mp3", "pipes/breath.mp3"]
	elif PLAN.bell_at_three(night):
		picks.append("town/chapel_bell.mp3")
	return str(picks[_rng.randi_range(0, picks.size() - 1)])


func _line_on(path: String, db: float) -> void:
	_loop_on(_line_snd, path, db)


func _tick_drip(delta: float) -> void:
	if _drop == null:
		return
	var top: Vector3 = parts.get("drip_at", Vector3(0.95, PLAN.ROOM_H - 0.05, 0.45))
	if _drop_t >= 0.0:
		_drop_t += delta
		var fall := 0.5 * 9.8 * _drop_t * _drop_t
		_drop.position = Vector3(top.x, top.y - floorf(fall * 5.0) / 5.0, top.z)
		if top.y - fall <= 0.12:
			_drop_t = -1.0
			_drop.visible = false
			if ResourceLoader.exists(SFX + "pipes/wetdrop.mp3"):
				if not _fx.playing:
					_fx.stream = load(SFX + "pipes/wetdrop.mp3")
					_fx.volume_db = -22.0 if not asleep else -60.0
					_fx.pitch_scale = _rng.randf_range(0.9, 1.1)
					_fx.play()
		return
	_drip_t -= delta
	if _drip_t <= 0.0:
		_drip_t = _rng.randf_range(1.2, 2.2) if _raining() else _rng.randf_range(3.5, 7.0)
		_drop_t = 0.0
		_drop.visible = true


## Now and then a roach runs along the skirting or up the wall behind the TV, and is gone.
func _tick_roach(delta: float) -> void:
	if _roach == null or asleep:
		return
	if _roach_t < 0.0:
		_roach_wait -= delta
		if _roach_wait > 0.0:
			return
		_roach_wait = _rng.randf_range(30.0, 75.0) * (0.6 if _night(_now()) else 1.0)
		var w := PLAN.ROOM_W
		var d := PLAN.ROOM_D
		var paths := [
			[Vector3(w * 0.5 - 0.02, 0.05, -0.2), Vector3(w * 0.5 - 0.02, 0.05, 1.6), Vector3(1.0, 0.0, 2.1)],
			[Vector3(-w * 0.5 + 0.43, 0.004, 0.2), Vector3(-0.3, 0.004, 0.05), Vector3(0.3, 0.004, 0.25)],
			[Vector3(w * 0.5 - 0.02, 0.3, -1.6), Vector3(w * 0.5 - 0.02, 1.2, -1.2), Vector3(w * 0.5 - 0.02, 1.9, -0.9)],
			[Vector3(-0.1, 0.004, d * 0.5 - 0.3), Vector3(0.6, 0.004, d * 0.5 - 0.6), Vector3(1.4, 0.004, d * 0.5 - 0.1)],
		]
		_roach_path = paths[_rng.randi_range(0, paths.size() - 1)]
		_roach_t = 0.0
		_roach.visible = true
		if not _fx.playing:
			_fx_play("motel/cockroach.mp3", -16.0)
	_roach_t += delta
	var k := _roach_t / 2.2
	if k >= 1.0:
		_roach_t = -1.0
		_roach.visible = false
		return
	var seg := mini(int(k * 2.0), 1)
	var a: Vector3 = _roach_path[seg]
	var b: Vector3 = _roach_path[seg + 1]
	var f := clampf(k * 2.0 - float(seg), 0.0, 1.0)
	var at := a.lerp(b, floorf(f * 14.0) / 14.0)
	var along := (b - a).normalized()
	# Flat on what it runs on: the floor (up) or the east wall (facing west).
	var nrm := Vector3.UP if a.y < 0.02 and b.y < 0.02 else Vector3(-1, 0, 0)
	var x := along.cross(nrm).normalized()
	_roach.transform = Transform3D(Basis(x, along, nrm), at + nrm * 0.006)
	(_roach.material_override as StandardMaterial3D).albedo_texture = _roach_tex[int(_t * 14.0) % 2]


## Headlights through the curtains: in round the car park, across the room, gone.
func _tick_headlights(delta: float) -> void:
	if _head_t < 0.0:
		return
	if _headlight == null:
		_headlight = SpotLight3D.new()
		_headlight.light_color = Color(1.0, 0.95, 0.82)
		_headlight.spot_angle = 24.0
		_headlight.spot_range = 14.0
		_headlight.shadow_enabled = false
		room._root.add_child(_headlight)
	_head_t += delta
	var win: Vector3 = PLAN.room_windows(n)[0]
	var k := clampf(_head_t / 5.0, 0.0, 1.0)
	var x := lerpf(win.x + 4.0, win.x - 3.5, floorf(k * 20.0) / 20.0)
	var at := Vector3(x, 1.0, -PLAN.ROOM_D * 0.5 - 4.5)
	var aim := Vector3(win.x - (x - win.x) * 0.4, 1.3, 0.5)
	_headlight.global_transform = Transform3D(Basis.looking_at((aim - at).normalized(), Vector3.UP), at)
	_headlight.light_energy = floorf(sin(k * PI) * 6.0) / 6.0 * 4.0
	if k >= 1.0:
		_head_t = -1.0
		_headlight.light_energy = 0.0


# ── clicks ───────────────────────────────────────────────────────────────────

## A click on `id`; true when it was the motel's.
func click(id: String, hour: float) -> bool:
	if n == 0:
		return _lobby_click(id, hour)
	return _room_click(id, hour)


func _lobby_click(id: String, hour: float) -> bool:
	if _walker != null and _walker.busy:
		return true
	match id:
		"him":
			_walker.go("desk", func():
				_line += 1
				room._npc_nod = 0.5
				room.say("Mr Simek", SIMEK_LINES[_line % SIMEK_LINES.size()]))
		"desk":
			_walker.go("desk", func():
				room._npc_nod = 0.5
				room.wants_closeup.emit("motel_room"))
		"bell":
			_walker.go("desk", func():
				_play("bistro/bell_ding.mp3", -6.0)
				room._npc_nod = 0.6)
		"book":
			_walker.go("desk", func(): _play("motel/newspaper.mp3", -13.0))
		"machine":
			if CoreRoot.get_money() < 1 or not CoreRoot.actions.spend_money(1):
				_play("director/knock_wrong.mp3", -14.0)
				return true
			_play("jednota/coin.mp3", -8.0)
			room.get_tree().create_timer(0.5).timeout.connect(func(): _play("motel/can_drop.mp3", -4.0))
		"tv":
			_toggle_tv(hour)
		"hall":
			_walker.go("hall", func():
				_play("backroom/room_door_open.mp3", -9.0)
				room.go_to("motel_hall", 0, "lobby"))
		_:
			if id.begins_with("key"):
				var k := int(id.substr(3))
				_walker.go("desk", func(): _key_click(k))
			elif id.begins_with("curtain"):
				_curtain(int(id.substr(7)))
			else:
				return false
	return true


## A key on the board: he says what it is and what it costs; again, and it is yours.
func _key_click(k: int) -> void:
	var trip = room.get_parent()
	if trip == null or not trip.has_method("rent"):
		return
	room._npc_nod = 0.5
	if _picked != k:
		_picked = k
		trip.key_line(k)
		_play("desk/keys.mp3", -16.0)
		return
	_picked = 0
	trip.rent(k)


func _room_click(id: String, _hour: float) -> bool:
	if _walker == null:
		return false
	if _walker.busy:
		return true
	if _peeping:
		_close_peephole()
		return true
	if _looking != "":
		_unlook()
		return true
	if _alarm_t > 0.0 and id == "clock":
		_alarm_t = -1.0
		_line_snd.stop()
		_play("backroom/lamp_click.mp3", -8.0)
		return true
	if lying:
		if id == "bed":
			if _night(_now()):
				_sleep_again()
			else:
				get_up()
			return true
		if (quirk.from_bed() if quirk != null else FROM_BED).has(id):
			_do(id)
			return true
		# Anything else: up off the bed and over to it.
		get_up(func(): _room_click(id, _hour))
		return true
	_do(id)
	return true


## What a click does, from where it is done (walking there first).
func _do(id: String) -> void:
	if quirk != null and quirk.click(id):
		return
	match id:
		"lock":
			_walker.go("door", func():
				if turns < 2:
					turns += 1
					_play("motel/lock_turn.mp3", -4.0)
					_turn_key()
				else:
					_unlock())
		"chain":
			_walker.go("door", func():
				_set_chain(not chain_on)
				_fx_play("motel/door_chain.mp3", -6.0))
		"peephole":
			_walker.go("door", func(): _open_peephole())
		"switch":
			_walker.go("entry", func():
				ceiling_on = not ceiling_on
				_play("bistro/switch.mp3", -8.0)
				_apply_switches())
		"lamps":
			var flip := func():
				lamps_on = not lamps_on
				_play("backroom/lamp_click.mp3", -6.0)
				_apply_switches()
			if lying:
				flip.call()
			else:
				_walker.go("bedfoot", flip)
		"tv":
			_walker.go("tv", func(): _toggle_tv(_now()))
		"bed":
			lie_down(_now())
		"wardrobe":
			_walker.go("wardrobe", func(): _wardrobe())
		"radiator":
			_walker.go("window", func():
				_play("motel/radiator_knock.mp3", -2.0)
				var h := _now()
				# Late at night, now and then, it answers (more if it woke you).
				var p := 0.75 if event == "radiator" else 0.18
				if _night(h) and (h >= 23.0 or h < 4.0) and _rng.randf() < p and _knock_back <= 0.0:
					_knock_back = 2.2)
		"bathdoor":
			_walker.go("bathdoor", func():
				bath_open = not bath_open
				_play("backroom/room_door_open.mp3" if bath_open else "backroom/room_door_close.mp3", -9.0)
				if bath_open:
					_went_in = true
				_apply_bath())
		"bathswitch":
			_walker.go("bathdoor", func():
				bath_on = not bath_on
				_play("bistro/switch.mp3", -8.0)
				if bath_on:
					_fx_play("motel/tube_flicker.mp3", -14.0)
				_apply_bath())
		"tap":
			_to_bath(func():
				tap_on = not tap_on
				_play("caravan/tap.mp3", -8.0)
				_tap_mix())
		"toilet":
			_to_bath(func(): _play("rooms/toilet_flush.mp3", -8.0))
		"shower":
			_to_bath(func():
				shower_drawn = not shower_drawn
				_fx_play("motel/shower_curtain.mp3", -8.0)
				_apply_bath())
		"mirror":
			_to_bath(func(): _look_at("mirror"))
		"phone":
			var pick := func(): _phone()
			if lying:
				pick.call()
			else:
				_walker.go(str(parts.get("phone_spot", "bedfoot")), pick)
		"clock":
			if quirk != null:
				_look_at("clock")
			else:
				# The clock radio's knob (it stops the alarm before it gets here).
				var flip := func(): radio.toggle()
				if lying:
					flip.call()
				else:
					_walker.go("bedfoot", flip)
		"print", "stain", "bowl":
			_look_at(id)
		"wall":
			# Knock on it: the scratching stops; the neighbour's set goes quieter.
			_play("motel/radiator_knock.mp3", -12.0)
			if _wall_snd != null and _neighbours():
				_wall_snd.volume_db = -25.0
			if event == "wall":
				_ev_n = 9
				if _neighbours():
					_loop_on(_amb2, "motel/neighbour_tv.ogg", -28.0)
		_:
			if id.begins_with("curtain"):
				var i := int(id.substr(7))
				_walker.go("window", func(): _curtain(i))


## Into the bathroom: its door opened first if it is shut, the light as it is.
func _to_bath(then: Callable) -> void:
	if not bath_open:
		_walker.go("bathdoor", func():
			bath_open = true
			_went_in = true
			_play("backroom/room_door_open.mp3", -9.0)
			_apply_bath()
			room.get_tree().create_timer(0.5).timeout.connect(func():
				if _alive():
					_walker.go("bath", then)))
		return
	_went_in = true
	_walker.go("bath", then)


func _set_chain(on: bool) -> void:
	chain_on = on
	var c: MeshInstance3D = parts.get("chain")
	var tex := "chain_hooked" if chain_on else "chain_loose"
	if c != null and ResourceLoader.exists(CAMP + tex + ".png"):
		(c.material_override as StandardMaterial3D).albedo_texture = load(CAMP + tex + ".png")


## Where you set off to: the room's own knows, the other wardens see you go.
func _went(to: String) -> void:
	if quirk != null:
		quirk.walked(to)
	Coop.send_place("town", "motel", "walk", [to])


func _wardrobe(quiet := false) -> void:
	wardrobe_open = not wardrobe_open
	if not quiet:
		_fx_play("motel/wardrobe_creak.mp3" if wardrobe_open else "caravan/locker_shut.mp3", -8.0)
	var wf: MeshInstance3D = parts.get("wardrobe")
	var tex := "motel_wardrobe_open" if wardrobe_open else "motel_wardrobe"
	if wf != null and ResourceLoader.exists(CAMP + tex + ".png"):
		(wf.material_override as StandardMaterial3D).albedo_texture = load(CAMP + tex + ".png")


func _curtain(i: int) -> void:
	if i < 0 or i >= windows.size():
		return
	var w = windows[i]
	var opening: bool = w.curtain_open() < 0.5
	w.toggle_curtain()
	_play("backroom/curtain_open.mp3" if opening else "backroom/curtain_shut.mp3", -8.0)
	# Whoever stood under the window on the set is not there when you look.
	if opening and _tv_fig != null and is_instance_valid(_tv_fig):
		_tv_fig.queue_free()
		_tv_fig = null


func _toggle_tv(hour: float) -> void:
	if _taped and quirk != null:
		# The set shows the tape: its button stops the tape.
		quirk.click("eject")
		return
	if n != 0 and tv_on:
		# On: the next channel, after the last one off.
		var chans: Array = TV_NIGHT if _night(hour) else TV_DAY
		tv_channel += 1
		if tv_channel >= chans.size() or event == "tv":
			tv_on = false
			if event == "tv":
				event = ""
			_play("backroom/tv_off.mp3", -8.0)
			_loop_on(_amb2, "motel/neon_buzz.ogg", -31.0)
			_apply_switches()
			return
		_play("bistro/switch.mp3", -12.0)
		_set_channel()
		return
	tv_on = not tv_on
	_play("backroom/tv_on.mp3" if tv_on else "backroom/tv_off.mp3", -8.0)
	tv_channel = 0
	if tv_on:
		_set_channel()
	_apply_switches()


func _set_channel() -> void:
	if _tv_mat == null or _tv_screen == null:
		return
	var chans: Array = TV_NIGHT if _night(_now()) else TV_DAY
	var ch := str(chans[tv_channel % chans.size()])
	if ch == "cam" and n != 0 and block != null and is_instance_valid(block):
		_tv_cam_on()
		return
	_tv_cam_off()
	var tex := "res://assets/textury/camp/%s.png" % ch
	if ResourceLoader.exists(tex):
		_tv_mat.albedo_texture = load(tex)
	_tv_screen.material_override = _tv_mat


## The key turned once in the lock: it goes edge on and comes round flat again.
func _turn_key() -> void:
	var key = parts.get("key")
	if key == null or not is_instance_valid(key):
		return
	var tw: Tween = room.create_tween()
	tw.tween_property(key, "scale:x", 0.15, 0.12)
	tw.tween_property(key, "scale:x", 1.0, 0.12)


## Both turns back, as you go out.
func _unlock() -> void:
	if turns <= 0:
		return
	turns = 0
	_play("motel/lock_turn.mp3", -4.0)
	_turn_key()
	room.get_tree().create_timer(0.3).timeout.connect(func():
		_play("motel/lock_turn.mp3", -5.0)
		_turn_key())


## Esc: off the bed first; the key turned back before you go out into the corridor.
func wants_out() -> bool:
	if n == 0:
		return true
	if _peeping:
		_close_peephole()
		return false
	if _looking != "":
		_unlook()
		return false
	if lying:
		get_up()
		return false
	if _walker != null:
		_walker.stop()
	_into_hall()
	return false


func _out_sounds() -> void:
	if turns > 0:
		_unlock()
	if chain_on:
		_set_chain(false)
		_fx_play("motel/door_chain.mp3", -8.0)
	_play("backroom/room_door_open.mp3", -8.0)


func _into_hall() -> void:
	_out_sounds()
	var trip = room.get_parent()
	if trip != null and trip.has_method("left_motel_room"):
		trip.left_motel_room()
	room.go_to("motel_hall", 0, "r%d" % n)


## The door clicked: to it on foot (off the bed first), then out.
func walk_out() -> void:
	if _walker == null or _walker.busy:
		return
	if n == 0:
		# Facing the door you are going out of (the spot's own look is into the room).
		_walker.go("door", func():
			_play("dvereotevrit.mp3", -8.0)
			room.close(), Vector3(deg_to_rad(-5.0), 0.0, 0.0))
		return
	if _peeping:
		_close_peephole()
		return
	if _looking != "":
		_unlook()
		return
	if lying:
		get_up(func(): walk_out())
		return
	_walker.go("door", func():
		var wait := 0.7 if turns > 0 else 0.3
		room.get_tree().create_timer(wait).timeout.connect(func():
			if _alive():
				_into_hall()))


## The eye goes to the thing (narrower, turned to it); any click lets it go.
func _look_at(id: String) -> void:
	var body = room._hot.get(id, {}).get("body")
	if body == null:
		return
	var target: Vector3 = (body as Node3D).position
	var eye: Vector3 = room._cam.position
	var d := target - eye
	_looking = id
	_look_back = {"rot": room._base_rot, "fov": room._cam.fov}
	var tw: Tween = room.create_tween().set_parallel(true)
	tw.tween_property(room, "_base_rot", Vector3(atan2(d.y, Vector2(d.x, d.z).length()), atan2(-d.x, -d.z), 0.0), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(room._cam, "fov", clampf(66.0 * 1.2 / maxf(1.2, d.length()), 24.0, 58.0), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if id == "mirror":
		# Somebody behind you in it, the worse you are (and gone when you turn).
		if (event == "bath" and _ghost) or (_night(_now()) and _rng.randf() < 0.06 + 0.3 * _low()):
			room.get_tree().create_timer(1.3).timeout.connect(func():
				if _looking == "mirror":
					_mirror_ghost(true))


func _unlook() -> void:
	if _looking == "mirror":
		_mirror_ghost(false)
	_looking = ""
	var tw: Tween = room.create_tween().set_parallel(true)
	tw.tween_property(room, "_base_rot", _look_back.get("rot", Vector3.ZERO), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(room._cam, "fov", float(_look_back.get("fov", 66.0)), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ── the bed ──────────────────────────────────────────────────────────────────

func lie_down(hour: float) -> void:
	if lying:
		return
	if _walker != null and _walker.here != "bedfoot":
		_walker.go("bedfoot", func(): lie_down(hour))
		return
	lying = true
	_fx_play("motel/bed_springs.mp3", -6.0)
	if _night(_now()) and (lamps_on or ceiling_on or tv_on):
		# The lights off to sleep (the set too): only the clock's red in the dark.
		lamps_on = false
		ceiling_on = false
		if _taped and quirk != null:
			quirk.click("eject")
		if tv_on:
			tv_on = false
			_tv_cam_off()
			_play("backroom/tv_off.mp3", -10.0)
		room.get_tree().create_timer(0.7).timeout.connect(func(): _play("backroom/lamp_click.mp3", -8.0))
		_apply_switches()
	var lie: Dictionary = parts.get("lie", {"at": PLAN.LIE, "rot": Vector3(deg_to_rad(6.0), deg_to_rad(-25.0), 0.0)})
	var tw: Tween = room.create_tween().set_parallel(true)
	tw.tween_property(room._cam, "position", lie["at"], 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(room, "_base_rot", lie["rot"], 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	room._look.yaw_limit_deg = 180.0
	room._look.pitch_down_deg = 30.0
	room._look.pitch_up_deg = 50.0
	if _night(_now()):
		room.get_tree().create_timer(1.2).timeout.connect(func():
			if lying and _alive():
				_sleep_again())


## Eyes shut again in the night (the rest of it passes, or the next thing wakes you).
func _sleep_again() -> void:
	if not lying:
		return
	if event != "":
		_end_event()
	room.wants_closeup.emit("sleep")


func get_up(then := Callable()) -> void:
	if not lying:
		if then.is_valid():
			then.call()
		return
	lying = false
	asleep = false
	_fx_play("motel/bed_springs.mp3", -10.0)
	var spot: Dictionary = _spots()["bedfoot"]
	var tw: Tween = room.create_tween().set_parallel(true)
	tw.tween_property(room._cam, "position", spot["at"], 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(room, "_base_rot", spot["rot"], 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	room._look.yaw_limit_deg = 180.0
	room._look.pitch_down_deg = 45.0
	room._look.pitch_up_deg = 40.0
	if _walker != null:
		_walker.here = "bedfoot"
		_walker.busy = true
	room.get_tree().create_timer(0.85).timeout.connect(func():
		if not _alive():
			return
		_walker.busy = false
		if then.is_valid():
			then.call())


## What woke you is over (you lay down again): its sounds stop, the set's snow, the bell.
func _end_event() -> void:
	match event:
		"tv":
			if tv_on:
				tv_on = false
				_apply_switches()
		"wall":
			_loop_on(_amb2, "motel/neon_buzz.ogg", -31.0)
		"phone":
			_ringing = 0
	if _peep_fig != null and is_instance_valid(_peep_fig):
		_peep_fig.queue_free()
		_peep_fig = null
	event = ""


## The night passed with you in the bed: the morning in the room. The lights you left on
## are off (as everybody does in their sleep); what the night left is not.
func morning(hour: float) -> void:
	asleep = false
	_end_event()
	lamps_on = false
	ceiling_on = false
	tv_on = false
	_tv_cam_off()
	_sanity = _read_sanity()
	# The print over the beds: whoever is by the river comes nearer, some mornings.
	var mk := _marks()
	if parts.get("print") != null and (_woken_tonight > 0 or _low() > 0.35) and _rng.randf() < 0.4 + 0.4 * _low():
		mk["painting"] = mini(2, int(mk["painting"]) + 1)
		var pr: MeshInstance3D = parts.get("print")
		var tex := CAMP + "motel_painting_%d.png" % int(mk["painting"])
		if ResourceLoader.exists(tex):
			(pr.material_override as StandardMaterial3D).albedo_texture = load(tex)
	if _raining():
		mk["stain"] = 1
	# Wet feet from the bathroom to your bed, if its light woke you and you never went in.
	if _had_bath_night and not _went_in:
		# Round the foot of the second bed, as somebody would walk it.
		var way := [[1.1, 1.75, 0.0], [1.08, 1.15, 0.0], [1.05, 0.5, 0.2], [0.7, -0.05, 1.3], [0.1, -0.14, 1.6], [-0.5, -0.02, 1.8]]
		if quirk != null:
			# From the hall's mouth straight to where you lay.
			var to: Vector3 = _spots()["bedfoot"]["at"]
			way = []
			for i in 6:
				var at := Vector3(1.1, 0.0, 1.75).lerp(to, float(i) / 5.0)
				way.append([at.x, at.z, atan2(to.x - 1.1, to.z - 1.75)])
		for wv in way:
			ROOMS.decal(room._root, "wet_footprints", Vector2(0.3, 0.22), Vector3(float(wv[0]), 0.0, float(wv[1])), Vector3.UP, float(wv[2]), "WetPrints")
	if parts.get("wardrobe") != null and not wardrobe_open and _rng.randf() < 0.15 + 0.35 * _low():
		_wardrobe()
	if chain_on and _rng.randf() < 0.1 + 0.4 * _low():
		_set_chain(false)
	if quirk != null:
		quirk.morning(hour)
	kept.erase(n)
	_woken_tonight = 0
	_had_bath_night = false
	_went_in = false
	if block != null and is_instance_valid(block) and block.get("marks") != null:
		var bm: Dictionary = block.get("marks")
		bm[n] = {"painting": int(mk["painting"]), "stain": int(mk["stain"])}
	_loop_on(_amb, "motel/flies.ogg", -26.0)
	if _amb2 != null:
		_amb2.stop()
	_set_light(hour)
	if bool(parts.get("digits", false)):
		_alarm()


# ── the peephole ─────────────────────────────────────────────────────────────

const PEEP_SHADER := "shader_type canvas_item;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec2 q = p * (0.45 + 0.55 * r * r);
		vec3 c = texture(TEXTURE, q * 0.5 + 0.5).rgb;
		float v = floor(clamp(1.35 - r * 1.1, 0.0, 1.0) * 5.0) / 5.0;
		COLOR = vec4(c * v * vec3(0.96, 1.0, 0.88), 1.0);
	}
}"


## Your eye to the peephole: the gallery and the car park out there, bent round its lens.
func _open_peephole() -> void:
	if _peep_layer == null:
		_peep_layer = CanvasLayer.new()
		_peep_layer.layer = 57
		room.add_child(_peep_layer)
		var bg := ColorRect.new()
		bg.color = Color(0, 0, 0, 1)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_peep_layer.add_child(bg)
		_peep_vp = SubViewport.new()
		_peep_vp.size = Vector2i(220, 220)
		_peep_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_peep_layer.add_child(_peep_vp)
		_peep_cam = Camera3D.new()
		_peep_cam.fov = 118.0
		_peep_cam.near = 0.05
		_peep_cam.far = 120.0
		_peep_vp.add_child(_peep_cam)
		var tr := TextureRect.new()
		tr.name = "Lens"
		tr.texture = _peep_vp.get_texture()
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sh := Shader.new()
		sh.code = PEEP_SHADER
		var sm := ShaderMaterial.new()
		sm.shader = sh
		tr.material = sm
		_peep_layer.add_child(tr)
	_peep_vp.world_3d = room._vp.find_world_3d()
	var dm := PLAN.room_door(n)
	_peep_cam.global_transform = Transform3D(Basis(Vector3.UP, PI), dm + Vector3(0, 1.55, 0.1))
	_peep_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_peep_layer.visible = true
	_peeping = true
	_fx_play("motel/peephole.mp3", -8.0)
	# Who knocked, standing right outside (the worse you are, the likelier), under the bulb
	# over your door.
	if event == "knock" and _ghost and _peep_fig == null:
		_peep_fig = _figure(room._root, dm + Vector3(0.12, 0.0, 0.8))
		if _peep_fig != null:
			var bulb := OmniLight3D.new()
			bulb.name = "DoorBulb"
			bulb.light_color = Color(1.0, 0.8, 0.52)
			bulb.light_energy = 0.9
			bulb.omni_range = 2.6
			bulb.position = Vector3(-0.1, 2.3, -0.55)
			_peep_fig.add_child(bulb)
	if event == "knock":
		_ev_n = 3


func _close_peephole() -> void:
	_peeping = false
	if _peep_layer != null:
		_peep_layer.visible = false
		_peep_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if _peep_fig != null and is_instance_valid(_peep_fig):
		_peep_fig.queue_free()
		_peep_fig = null
	_fx_play("motel/peephole.mp3", -12.0)


## The one who comes to the motel at night: the last guest to leave your camp, as they
## looked (else one of its guests), standing at `at` in `parent`'s space, facing the motel.
func _figure(parent: Node3D, at: Vector3) -> Sprite3D:
	var trip = room.get_parent()
	var path := str(trip._last_departed_sprite()) if trip != null and trip.has_method("_last_departed_sprite") else ""
	if path == "" or not ResourceLoader.exists(path):
		path = "res://assets/textury/npc/host%d.png" % _rng.randi_range(1, 3)
	if not ResourceLoader.exists(path):
		return null
	var t: Texture2D = load(path)
	var sp := Sprite3D.new()
	sp.name = "MotelVisitor"
	sp.texture = t
	sp.pixel_size = 1.72 / float(t.get_height())
	sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sp.shaded = true
	sp.modulate = Color(0.7, 0.7, 0.74)
	sp.offset = Vector2(0, t.get_height() * 0.5)
	sp.position = at
	parent.add_child(sp)
	return sp


# ── the TV's car park channel ────────────────────────────────────────────────

const CAM_SHADER := "shader_type spatial;
render_mode unshaded;
uniform sampler2D view : filter_nearest;
uniform float t = 0.0;
void fragment() {
	vec2 uv = UV;
	vec3 c = texture(view, uv).rgb;
	float g = dot(c, vec3(0.3, 0.59, 0.11)) * 1.7;
	vec2 cell = floor(uv * vec2(72.0, 54.0));
	float n = fract(sin(dot(cell + floor(t * 12.0), vec2(12.9898, 78.233))) * 43758.5453);
	g = g + (n - 0.5) * 0.16;
	g *= 0.82 + 0.18 * step(0.5, fract(uv.y * 54.0));
	ALBEDO = vec3(g * 0.92, g, g * 0.94);
}"


func _cam_make() -> void:
	if _cam_vp == null:
		_cam_vp = SubViewport.new()
		_cam_vp.size = Vector2i(96, 72)
		_cam_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		room.add_child(_cam_vp)
		_cam_cam = Camera3D.new()
		_cam_cam.fov = 58.0
		_cam_cam.far = 90.0
		_cam_vp.add_child(_cam_cam)
		var sh := Shader.new()
		sh.code = CAM_SHADER
		_cam_mat = ShaderMaterial.new()
		_cam_mat.shader = sh
		_cam_mat.set_shader_parameter("view", _cam_vp.get_texture())


## The tape in the recorder (motel_nine.gd): the set shows this room from `eye`.
func tape_on(eye: Transform3D) -> void:
	_cam_make()
	_cam_vp.world_3d = room._vp.find_world_3d()
	_cam_cam.fov = 78.0
	_cam_cam.global_transform = eye
	_cam_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_taped = true
	tv_on = true
	_tv_screen.material_override = _cam_mat
	_apply_switches()


func tape_off() -> void:
	_taped = false
	tv_on = false
	_tv_cam_off()
	_apply_switches()


func _tv_cam_on() -> void:
	_cam_make()
	_cam_cam.fov = 58.0
	_cam_vp.world_3d = block.get_world_3d()
	var bay := int(PLAN.ROOMS[n]["bay"])
	var wm := PLAN.window_at(bay, bool(PLAN.ROOMS[n]["up"]))
	var pos := Vector3(wm.x + 2.0, 4.8, PLAN.FRONT_Z - 8.0)
	var target := Vector3(wm.x, 1.0, PLAN.FRONT_Z)
	_cam_cam.global_transform = block.global_transform * Transform3D(Basis.looking_at((target - pos).normalized(), Vector3.UP), pos)
	_cam_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_tv_screen.material_override = _cam_mat
	# Somebody under your window, looking up at it, on the set (and not there when you look).
	if event == "tv" and _ghost and _tv_fig == null:
		_tv_fig = _figure(block, wm + Vector3(0.35, -wm.y, -1.3))


func _tv_cam_off() -> void:
	if _cam_vp != null:
		_cam_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if _tv_screen != null and _tv_mat != null:
		_tv_screen.material_override = _tv_mat
	if _tv_fig != null and is_instance_valid(_tv_fig):
		_tv_fig.queue_free()
		_tv_fig = null


# ── the mirror ───────────────────────────────────────────────────────────────

const MIRROR_SHADER := "shader_type spatial;
render_mode unshaded;
uniform sampler2D view : filter_nearest;
void fragment() {
	vec3 c = texture(view, vec2(1.0 - SCREEN_UV.x, SCREEN_UV.y)).rgb;
	ALBEDO = c * vec3(0.84, 0.88, 0.86);
}"


## While you are in the bathroom the mirror shows it, from across its glass: the room
## behind you, the door, you (and, some nights, somebody else).
func _tick_mirror() -> void:
	var mirror: MeshInstance3D = parts.get("mirror")
	if mirror == null:
		return
	var inside: bool = room._cam.position.z > PLAN.BACK_Z and room._cam.position.x < PLAN.HALL_X.x + 0.5
	if not inside:
		if _mir_vp != null:
			_mir_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	if _mir_vp == null:
		_mir_vp = SubViewport.new()
		_mir_vp.size = Vector2i(480, 270)
		_mir_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		room._vp.add_child(_mir_vp)
		_mir_vp.world_3d = room._vp.find_world_3d()
		_mir_cam = Camera3D.new()
		_mir_cam.cull_mask = 0xFFFFF & ~ROOMS.BEHIND_MIRROR
		_mir_cam.near = 0.05
		_mir_cam.far = 20.0
		_mir_vp.add_child(_mir_cam)
		var sh := Shader.new()
		sh.code = MIRROR_SHADER
		var sm := ShaderMaterial.new()
		sm.shader = sh
		sm.set_shader_parameter("view", _mir_vp.get_texture())
		mirror.material_override = sm
		_make_reflection()
	var mx: float = mirror.position.x
	var t: Transform3D = room._cam.global_transform
	var p := t.origin
	var r := func(v: Vector3) -> Vector3: return Vector3(-v.x, v.y, v.z)
	_mir_cam.global_transform = Transform3D(Basis(-r.call(t.basis.x), r.call(t.basis.y), r.call(t.basis.z)), Vector3(2.0 * mx - p.x, p.y, p.z))
	_mir_cam.fov = room._cam.fov
	if _mir_vp.size != room._vp.size / 2:
		_mir_vp.size = room._vp.size / 2
	_mir_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if _mir_me != null:
		_mir_me.position = Vector3(p.x, p.y - 1.6, p.z)


## You in the mirror (your own warden, from the front), the one behind you, both seen only
## by the mirror's camera.
func _make_reflection() -> void:
	var look: Dictionary = Coop.my_look() if Coop.has_method("my_look") else {}
	var tex: Texture2D = LOOKS.texture(int(look.get("m", 1)), int(look.get("c", 0)), "stand")
	if tex != null:
		_mir_me = Sprite3D.new()
		_mir_me.name = "Reflection"
		_mir_me.texture = tex
		_mir_me.pixel_size = 1.72 / float(tex.get_height())
		_mir_me.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_mir_me.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		_mir_me.shaded = true
		_mir_me.offset = Vector2(0, tex.get_height() * 0.5)
		_mir_me.rotation.y = -PI * 0.5
		_mir_me.layers = ROOMS.ONLY_MIRROR
		room._root.add_child(_mir_me)


## In the mirror, where you should be, somebody else (right behind where you stand); you
## are back in it once you look away.
func _mirror_ghost(on: bool) -> void:
	if on:
		var p: Vector3 = room._cam.position
		if _mir_ghost == null:
			_mir_ghost = _figure(room._root, Vector3(p.x + 0.22, 0.0, p.z - 0.03))
			if _mir_ghost == null:
				return
			_mir_ghost.layers = ROOMS.ONLY_MIRROR
			_mir_ghost.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			_mir_ghost.rotation.y = -PI * 0.5
		_mir_ghost.position = Vector3(p.x + 0.22, 0.0, p.z - 0.03)
		_mir_ghost.visible = true
		if _mir_me != null:
			_mir_me.visible = false
		_mir_ghost_on = true
	elif _mir_ghost != null:
		_mir_ghost.visible = false
		if _mir_me != null:
			_mir_me.visible = true
		if _mir_ghost_on:
			_mir_ghost_on = false
			_ghost = false


# ── the phone ────────────────────────────────────────────────────────────────

func _phone() -> void:
	var ph: MeshInstance3D = parts.get("phone")
	phone_up = not phone_up
	var tex := "phone_off" if phone_up else "phone_on"
	if ph != null and ResourceLoader.exists(CAMP + tex + ".png"):
		(ph.material_override as StandardMaterial3D).albedo_texture = load(CAMP + tex + ".png")
	if phone_up:
		_play("phone/lift.mp3", -6.0)
		_ring_snd.stop()
		if _ringing > 0 or event == "phone":
			_ringing = 0
			_call_t = 0.0
			_line_on("phone/line_hiss.mp3", -18.0)
		else:
			_line_on("phone/dialtone.mp3", -18.0)
	else:
		_play("phone/hangup.mp3", -6.0)
		_line_snd.stop()
		_call_t = -1.0
		if event == "phone":
			event = ""


# ── co-op ────────────────────────────────────────────────────────────────────

## The other wardens in here: asleep in the other bed (lying on it the way the cabins
## show them, interior_manager._coop_lay_sleeper), else standing by the TV; in the
## reception at the counter beside you.
const SLEEPER_TILT := 28.0
const SLEEPER_LENGTH := 0.72
var _sleepers: Dictionary = {}


func place_mates(mates: Dictionary, ids: Array) -> void:
	for id in _sleepers.keys():
		if not ids.has(id) or not bool(Coop.state_of(int(id)).get("z", false)):
			if is_instance_valid(_sleepers[id]):
				(_sleepers[id] as Node).queue_free()
			_sleepers.erase(id)
	var trip = room.get_parent()
	for id in ids:
		var i := int(id)
		var fig = mates.get(i)
		if fig == null:
			continue
		if n != 0 and bool(Coop.state_of(i).get("z", false)):
			fig.visible = false
			_lay(i)
			continue
		fig.visible = true
		if not _crew.mates.has(i):
			_crew.put(i, fig, str(trip.mate_spot(i)) if trip != null and trip.has_method("mate_spot") else "door")
			# Somebody came in: the door, and the room as it is, for them.
			_play("backroom/room_door_open.mp3" if n != 0 or str(trip.mate_spot(i)) == "hall" else "dvereotevrit.mp3", -13.0)
			_sent = ""


## Warden `id` has set off to `spot` in here.
func mate_walk(id: int, spot: String) -> void:
	if _crew != null:
		_crew.walk(id, spot)


## A warden leaving: they walk to the door they went by, then they are gone.
func mate_leaves(id: int, fig: Node, where: String) -> bool:
	if _crew == null or not _crew.mates.has(id):
		return false
	var out := "door"
	if n == 0 and where == "motel_hall":
		out = "hall"
	var path: Array = []
	for sp in WALK.route(_crew.spots, _crew.ways, _crew._nearest(_crew.mates[id]["at"]), out):
		path.append(_crew.feet(str(sp)))
	if n == 0 and where == "motel_hall":
		path.append(Vector3(PLAN.LOBBY_HALL_X, 0.0, PLAN.lobby_size().z * 0.5 - 0.05))
	elif n == 0:
		var d := PLAN.room_door(0)
		path.append(Vector3(d.x, 0.0, d.z + 0.05))
	var through := "backroom/room_door_open.mp3" if where == "motel_hall" or n != 0 else "dvereotevrit.mp3"
	_crew.leave(id, path, func():
		_play(through, -12.0)
		if is_instance_valid(fig):
			fig.queue_free())
	return true


## What is switched in here, as it is now (for the other warden, and for when you come back
## to it tonight).
func _state() -> Dictionary:
	var cur: Array = []
	for w in windows:
		cur.append(float(w.curtain_open()) >= 0.5)
	return {"l": lamps_on, "c": ceiling_on, "t": tv_on and not _taped, "h": tv_channel, "b": bath_on, "d": bath_open,
		"p": tap_on, "s": shower_drawn, "w": wardrobe_open, "k": turns, "n": chain_on, "u": cur,
		"q": quirk.state() if quirk != null else [], "r": radio.state() if radio != null else []}


func _state_key() -> String:
	if n == 0:
		return ""
	var st := _state()
	var r: Array = st["r"]
	st["r"] = r.slice(0, 2)
	return str(st)


func _tick_sync(delta: float) -> void:
	_sync_t -= delta
	if _sync_t > 0.0:
		return
	_sync_t = 0.25
	if not Coop.has_partner():
		return
	var key := _state_key()
	if key != _sent:
		_sent = key
		Coop.send_place("town", "motel", "room", [n, _state()])


## What the other warden switched (or how you left it: `quiet`, nothing heard).
func take_state(d: Dictionary, quiet := false) -> void:
	if d.is_empty():
		return
	var snd := func(path: String, db: float):
		if not quiet:
			_play(path, db)
	if bool(d.get("l", lamps_on)) != lamps_on:
		lamps_on = not lamps_on
		snd.call("backroom/lamp_click.mp3", -8.0)
	if bool(d.get("c", ceiling_on)) != ceiling_on:
		ceiling_on = not ceiling_on
		snd.call("bistro/switch.mp3", -9.0)
	if bool(d.get("b", bath_on)) != bath_on:
		bath_on = not bath_on
		snd.call("bistro/switch.mp3", -10.0)
	if bool(d.get("d", bath_open)) != bath_open:
		bath_open = not bath_open
		snd.call("backroom/room_door_open.mp3" if bath_open else "backroom/room_door_close.mp3", -10.0)
	if bool(d.get("p", tap_on)) != tap_on:
		tap_on = not tap_on
		snd.call("caravan/tap.mp3", -10.0)
	if bool(d.get("s", shower_drawn)) != shower_drawn:
		shower_drawn = not shower_drawn
		snd.call("motel/shower_curtain.mp3", -10.0)
	if bool(d.get("w", wardrobe_open)) != wardrobe_open and parts.get("wardrobe") != null:
		_wardrobe(quiet)
	if int(d.get("k", turns)) != turns:
		turns = int(d.get("k", turns))
		snd.call("motel/lock_turn.mp3", -6.0)
		_turn_key()
	if bool(d.get("n", chain_on)) != chain_on:
		_set_chain(not chain_on)
		snd.call("motel/door_chain.mp3", -8.0)
	var tv_want := bool(d.get("t", tv_on and not _taped))
	var ch := int(d.get("h", tv_channel))
	if (tv_want != (tv_on and not _taped) or ch != tv_channel) and not parts.get("tv", {}).is_empty():
		tv_on = tv_want
		tv_channel = ch
		snd.call("backroom/tv_on.mp3" if tv_on else "backroom/tv_off.mp3", -9.0)
		if tv_on:
			_set_channel()
		else:
			_tv_cam_off()
	var cur: Array = d.get("u", [])
	for i in mini(cur.size(), windows.size()):
		var w = windows[i]
		if bool(cur[i]) != (float(w.curtain_open()) >= 0.5):
			w.set_curtain(bool(cur[i]), quiet)
			snd.call("backroom/curtain_open.mp3" if bool(cur[i]) else "backroom/curtain_shut.mp3", -9.0)
	if quirk != null:
		quirk.take(d.get("q", []), quiet)
	if radio != null:
		radio.take(d.get("r", []), quiet)
	_apply_switches()
	_sent = _state_key()


## Warden `id` on their back in the second bed, the head at the pillow.
func _lay(id: int) -> void:
	var sl: Sprite3D = _sleepers.get(id)
	if sl == null or not is_instance_valid(sl):
		var look: Dictionary = Coop.look_of(id)
		var tex: Texture2D = LOOKS.texture(int(look.get("m", 1)), int(look.get("c", 0)), "bedfoot")
		if tex == null:
			return
		sl = Sprite3D.new()
		sl.name = "Sleeper"
		sl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		sl.double_sided = true
		sl.shaded = true
		sl.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sl.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sl.texture = tex
		sl.pixel_size = SLEEPER_LENGTH / float(tex.get_height())
		sl.offset = Vector2(0.0, tex.get_height() * 0.5)
		room._root.add_child(sl)
		_sleepers[id] = sl
	var where: Dictionary = parts.get("sleeper", {})
	var head: Vector3 = where.get("head", Vector3(PLAN.BED_X[1], 0.55, PLAN.ROOM_D * 0.5 - 0.35))
	var along: Vector3 = where.get("along", Vector3(0, 0, 1))
	var tilt := deg_to_rad(SLEEPER_TILT)
	var up := (along * cos(tilt) + Vector3.UP * sin(tilt)).normalized()
	var nrm := (Vector3.UP * cos(tilt) - along * sin(tilt)).normalized()
	sl.transform = Transform3D(Basis(up.cross(nrm), up, nrm), head - along * (SLEEPER_LENGTH * cos(tilt)) + Vector3(0, 0.04, 0))


## Is this view still the one on (a timer started in it may outlive it).
func _alive() -> bool:
	return not _closed and _walker != null and room.is_open()


func close() -> void:
	_closed = true
	if n != 0:
		kept[n] = {"night": _night_no(), "s": _state()}
	if quirk != null:
		quirk.close()
	if radio != null:
		radio.free_all()
	for w in windows:
		w.free_all()
	windows.clear()
	for id in _sleepers.keys():
		if is_instance_valid(_sleepers[id]):
			(_sleepers[id] as Node).queue_free()
	_sleepers.clear()
	if _looking != "":
		room._cam.fov = float(_look_back.get("fov", 66.0))
	_looking = ""
	if _walker != null:
		_walker.stop()
		_walker.free_all()
	for p in _players:
		if is_instance_valid(p):
			(p as Node).queue_free()
	_players.clear()
	for nd in [_peep_layer, _cam_vp, _mir_vp, _clock_vp, _peep_fig, _tv_fig]:
		if nd != null and is_instance_valid(nd):
			(nd as Node).queue_free()
	_peep_layer = null
	_peeping = false
	room._cam.cull_mask = 0xFFFFF


## Debug (tools/shot_driver.gd): woken now by `kind`, as if the night had done it.
func debug_wake(kind: String, ghost := true) -> void:
	woken(kind)
	_ghost = ghost
