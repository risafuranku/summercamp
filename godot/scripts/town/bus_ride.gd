extends CanvasLayer

## Inside the line 380 bus, like the rooms: its own little world drawn small and scaled
## up, the restricted look, the cursor. You come in at the front door with the bus
## standing at the stop:
##   - the ticket the old way: bought before at the stop's machine (town_trip.gd) or
##     from the driver with the surcharge (click him), then punched in the orange box on
##     the pole by the door (click it: cvak); the driver will not let you sit without
##     one punched. The seats (click one to sit down), the door or the bottom of the
##     screen to get off again;
##   - sitting down: the doors hiss shut and the bus drives the real road (scripts/geo/:
##     up from the camp to road 12, east past Chouranice, north at Pristoupim, up to
##     Liblice) through the real land, the cabin riding in the bus model as it goes
##     (`path`, from town_trip.gd): it slows for the bends and the villages, keeps to
##     its lane, the land goes past the windows as from a car; mouse to look round, until
##     it pulls up at the other end and town_trip.gd puts you out there (`arrived`);
##   - the red STOP buttons on the poles: the request stop at Podlesi (the buzzer, the
##     STOJIME light over the driver), the bus pulls in there and you get off
##     (`arrived_where` "hamlet"); a ticket to Podlesi stops it there too. Now and then
##     somebody else gets off there and the bus goes on. Boarding at Podlesi
##     ("hamlet_town" / "hamlet_camp") the ride starts there.
## The sound of a rusty Karosa: the diesel at the back, the panes and panels rattling
## harder on the bumps, the draught at a window, the gears crunching as it picks up
## speed, potholes, a truck the other way, the driver's radio playing a polka, a cough,
## a newspaper (assets/sfx/bus/karosa_*, tools/audiogen; the old ride.mp3 when missing).
## The game's clock runs on: the ride is the hour and a half the timetable says.
## The people on board are villagers (npc_bus_*: from the front and, sat behind them,
## their backs), sitting the way the bus goes; now and then two of them talk, or one
## with the driver, in Czech (assets/sfx/bus/talk, tools/audiogen/bus_talk.py), and once
## in a while one turns round to you and says something.
## Co-op: the other warden rides the same bus. You see them on board (standing at the
## front till they sit, then in their seat: from the front or, sat behind them, their
## back), the people already on board are the same for both, and the bus does not go
## while they are on it and not yet sat down (buying a ticket), nor for a moment while
## they are near the stop outside.
## Outside is lit by the hour and the weather (set_time); at night the strip lights are
## on inside and the windows are black but for what passes.

signal arrived
signal left_bus

const INTERIOR_LOOK = preload("res://scripts/interior_look.gd")
const HOVER_GLINT = preload("res://scripts/ui/hover_glint.gd")
const RETRO_RENDER = preload("res://scripts/retro_render.gd")
const CAM_MOVE = preload("res://scripts/ui/cam_move.gd")
const INVENTORY = preload("res://scripts/ui/inventory.gd")
const TIMES_HM = preload("res://scripts/town/bus_timetable.gd")
const PUNCH_CLOSEUP = preload("res://scripts/town/punch_closeup.gd")
## Where the ticket from the stop's machine is for (town_trip.gd sets it as you get on):
## one to PODLESI asks for the request stop once punched.
var bought_to := ""
## The orange box close up while you put your ticket in (punch_closeup.gd).
var _punch_view
## A ticket from the driver costs this (with the surcharge; the stop's machine less).
const DRIVER_PRICE := 3
const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const TEX := "res://assets/textury/town/"
const KAROSA_CAB = preload("res://scripts/town/karosa_cab.gd")
const TEX_CAMP := "res://assets/textury/camp/"
const SFX := "res://assets/sfx/bus/"
const NPC := "res://assets/textury/npc/"
const CRUISE := 17.0
const ACCEL := 2.4
const BRAKE := 2.2
const HALF_W := 1.22
const FLOOR_Z := Vector2(-5.34, 5.34)
const STAND_POS := Vector3(0.62, 1.62, -3.45)
const STAND_LOOK := Vector3(-0.2, 1.1, -0.6)
## Seats (x, z): the right row skips the doors; the player's seat is one of these.
const SEATS := [Vector2(-0.68, -2.5), Vector2(-0.68, -1.6), Vector2(-0.68, -0.7), Vector2(-0.68, 0.2), Vector2(-0.68, 1.1), Vector2(-0.68, 2.0), Vector2(-0.68, 2.9), Vector2(-0.68, 3.8),
	Vector2(0.68, -2.5), Vector2(0.68, -1.6), Vector2(0.68, -0.7), Vector2(0.68, 2.0), Vector2(0.68, 0.2), Vector2(0.68, 1.1)]
## The Karosa SM 11 (bus_model.gd): its front door from the front jamb to the back one,
## the two treads in it (cabin height, how far in), the back door (shut), the poles.
const DOOR_Z := Vector2(-5.02, -4.0)
const STEPS := [Vector2(-0.38, 0.92), Vector2(-0.19, 0.62)]
const BACK_DOOR_Z := Vector2(3.15, 4.05)
const POLES := [Vector2(0.54, -3.9), Vector2(0.12, 0.65), Vector2(0.12, 2.3)]
## The driver's lines, by their keys in talk.json (tools/audiogen/bus_talk.tsv "d_*": the
## Czech he says, the English under it).
const DRIVER_LINES := {
	"camp": ["d_camp1", "d_camp2", "d_camp3"],
	"town": ["d_town1", "d_town2", "d_town3"],
}
const DRIVER_NIGHT := ["d_night1", "d_night2", "d_night3"]

enum { CLOSED, BOARDING, SITTING, RIDING, STOPPING, DONE, HELD, PAUSED }

## Where the ride ended: "" at the end of the line, "hamlet" at the Podlesi request stop.
var arrived_where := ""
## The request stop: how far along the route (-1 none) and for whom: "you" (you get off
## there), else it only stops: "rider" (a villager gets off), "board" (old Vacek waits
## there), "mate" (the other warden gets off).
var _stop_at := -1.0
var _stop_who := ""
var _stop_rider := false
## Old Vacek (VACEK) gets on at Pristoupim this run, which seat he will take of those
## round you (an index into them), which story he tells; and him once he is on:
## {node, path, i, seat, phase "walk"/"sat"}.
var _board_plan := false
var _board_pick := 0
var _board_story := ""
var _boarder: Dictionary = {}
## Changing seats: getting up and walking down the aisle to another (WALK_PATH).
var _walking := false
var _walk_tw: Tween
## The road's potholes and the lorries the other way come by the metre (the same for
## everyone on the bus in co-op): the last stretch of road each was looked at for.
var _bump_cell := -1
var _truck_cell := -1
var _driver_mouth: AudioStreamPlayer3D
var _pause_t := 0.0
var _stojime: StandardMaterial3D
var _rattle: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _radio: AudioStreamPlayer
var _two: AudioStreamPlayer
var _gear_at := 0
## The life on board, the same on both machines in co-op: its own dice, seeded like the
## passengers, and the clock since the doors shut (both buses go together).
var _life_rng := RandomNumberGenerator.new()
var _ride_t := 0.0
var _events: Array = []
## The conversation going on: its lines still to say ({at: Vector3, file, en, name}).
var _talk: Array = []
var _talk_gap := 0.0
var _mouth: AudioStreamPlayer3D
var _mouth2: AudioStreamPlayer3D
static var _scenes: Dictionary = {}
const TALK := "res://assets/sfx/bus/talk/"
const WALK_PATH = preload("res://scripts/ui/walk_path.gd")
const SFX_STEPS := "res://assets/sfx/rooms/steps_wood.mp3"
## Old Vacek from Pristoupim (Grok npc/bus_vacek_sit, _back, _turn, _walk): gets on
## there now and then by day, sits by you and tells you things (bus_talk.tsv v*).
const VACEK := {"id": "vacek", "voice": "soused", "g": "m", "name": "Old Vacek"}
const DRIVER_HEAD := Vector3(-0.62, 1.35, -4.35)
## The villagers on the 380 (Grok npc_bus_*: bus_<id>_sit.png from the front,
## bus_<id>_back.png from behind) and the voice each talks in (bus_talk.tsv).
const VILLAGERS := [
	{"id": "babka", "voice": "babka", "g": "f", "name": "Old woman"},
	{"id": "deda", "voice": "deda", "g": "m", "name": "Old man"},
	{"id": "zena", "voice": "zena", "g": "f", "name": "Woman"},
	{"id": "man", "voice": "muz", "g": "m", "name": "Man"},
]
## How far a seated figure turns from straight ahead towards your eye (radians), so the
## flat sprite keeps its width without looking at you.
const LOOK_SPREAD := 0.5
## Which engine loop is on: "cruise", or "climb" up through the forest out of the
## lake's valley going to town.
var _engine := ""
## The speeds where the gearbox crunches into the next gear (m/s).
const GEARS := [4.0, 8.5, 13.0]

const LOOKS = preload("res://scripts/coop/warden_looks.gd")
## How long a bus waits for the other warden near the stop outside (real seconds).
const MATE_WAIT := 15.0
## Where the stop is in the camp's world (town_trip sets it): "near the stop" is from here.
var stop_pos := Vector3.INF
## The other wardens on this bus: peer id -> their figure, and the picture it shows.
var _mates: Dictionary = {}
var _mate_poses: Dictionary = {}
var _mate_wait := 0.0
var _mate_said := false

## "camp": standing at the camp stop, going to Lesna; "town": in Lesna, going to the camp.
var stop := "camp"
var worldgen: Node
var _state := CLOSED
var _built := false
var _container: SubViewportContainer
var _vp: SubViewport
var _env: Environment
var _sky: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _cam: Camera3D
var _cam_base := Vector3.ZERO
var _look = INTERIOR_LOOK.new(115.0, 26.0, 34.0)
## The road this ride takes in the real land (town_trip.gd, scripts/geo/): points in
## the bus's lane from where it stands to where it stops, the request stop's distance
## along them (-1: none on the way), the speed the road allows at each point (m/s), and
## the bus model that carries the cabin.
var path := PackedVector3Array()
var path_hamlet := -1.0
var path_limits := PackedFloat32Array()
var ride_bus: Node3D
var _path_s := PackedFloat32Array()
var _travelled := 0.0
## The cabin's frame: it rides in ride_bus, its floor on the bus's (bus_model.FLOOR_Y).
var _rig: Node3D
const CABIN_Y := 0.78
## The clickable things in the cabin are on their own physics layer (the world's walls
## and floors are not in the way of the mouse).
const HOT_LAYER := 1 << 19
var _main_vp: SubViewport
var _truck_t := 18.0
## Kept 1: a hook for a ride that must catch up with the other warden's.
var clock_speed_fix := 1.0
var _speed := 0.0
var _speed_prev := 0.0
## What swings with the bus: curtains, the mascot ({node, base, k}), in steps.
var _swingers: Array = []
var _swing := 0.0
var _swing_v := 0.0
var _swing_acc := 0.0
var _hot: Array = []
var _hover := ""
var _glint = HOVER_GLINT.new()
var _ticket: Dictionary = {}
var _ticket_card: Control
var _exit_hint: Control
var _say_label: Label
var _say_t := 0.0
var _ride: AudioStreamPlayer
var _one: AudioStreamPlayer
var _strip_mat: StandardMaterial3D
var _strip_lights: Array[OmniLight3D] = []
var _passengers: Array[Sprite3D] = []
var _taken: Dictionary = {}
var _seat := -1
var _done_t := 0.0
var _bump_t := 0.0
var _bump := 0.0
var _night := false
var _rng := RandomNumberGenerator.new()
var _mats: Dictionary = {}
var _door_leaves: Array[MeshInstance3D] = []
## The front door from inside, folding like the real one (bus_model.gd): per leaf
## {hinge, joint, d}; how far open it is and where it is going.
var _door_hinges: Array = []
var _door_k := 0.0
var _door_want := 0.0
var _glass: ShaderMaterial
## The panes: a little dirt, and in the rain drops running down them, blown back as the
## bus picks up speed (moved in steps, twelve a second).
const GLASS_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float rain = 0.0;
uniform float t = 0.0;
uniform float speed = 0.0;
// At night the panes are all but gone: the dark outside shows, not a grey film.
uniform float night = 0.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = UV * vec2(110.0, 9.0);
	vec2 cell = floor(uv);
	vec2 f = fract(uv);
	float r = h(cell);
	float drop = 0.0;
	if (r < 0.45 * rain) {
		// One drop per cell: it slides down (and back with the speed), leaving a trail.
		float y = fract(h(cell + 3.1) + t * (0.25 + r * 0.6));
		float x = 0.5 + (h(cell + 7.7) - 0.5) * 0.5 - (y - 0.5) * speed * 0.6;
		float d = abs(f.x - x);
		if (d < 0.09 && abs(f.y - y) < 0.12) { drop = 1.0; }
		else if (d < 0.05 && f.y < y) { drop = 0.35; }
	}
	ALBEDO = mix(vec3(0.7, 0.75, 0.76), vec3(0.88, 0.92, 0.95), drop) * mix(1.0, 0.3, night);
	ALPHA = mix(0.08, 0.03, night) + drop * 0.45;
}
"""


func _glass_material() -> ShaderMaterial:
	if _glass == null:
		_glass = ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = GLASS_SHADER
		_glass.shader = sh
	return _glass


func _init() -> void:
	name = "BusRide"
	layer = 57
	visible = false


func _ready() -> void:
	_rng.randomize()


func is_open() -> bool:
	return _state != CLOSED


func is_riding() -> bool:
	return _state in [SITTING, RIDING, STOPPING, DONE, HELD, PAUSED]


## Co-op: where you are on this bus, for the other machine ({} off it): the stop, the
## seat (-1 standing) and whether it has gone.
func coop_state() -> Dictionary:
	if _state == CLOSED:
		return {}
	var out := {"st": stop, "s": _seat, "go": _state in [RIDING, STOPPING, DONE], "cs": clock_scale,
		"rt": snappedf(_ride_t, 0.01), "tr": snappedf(_travelled, 0.05), "sa": snappedf(_stop_at, 0.1), "sw": _stop_who,
		"bs": int(_boarder.get("seat", -1))}
	# Up and walking down the aisle to another seat: where along it.
	if _walking and _cam != null:
		out["wz"] = snappedf(_cam.position.z, 0.05)
	# Where the bus is on the road, for the other machine to show it going (town_trip's
	# mate bus): its place, heading, speed and board.
	if _state in [RIDING, STOPPING] and ride_bus != null and is_instance_valid(ride_bus):
		var t: Transform3D = ride_bus.global_transform
		var f := -t.basis.z
		out["bt"] = [snappedf(t.origin.x, 0.01), snappedf(t.origin.y, 0.01), snappedf(t.origin.z, 0.01), snappedf(atan2(-f.x, -f.z), 0.001)]
		out["v"] = snappedf(_speed, 0.1)
		out["d"] = str(ride_bus.get("destination"))
	return out


## How slow the game's clock runs while this ride is under way (town_trip.gd sets it;
## the other machine's host slows its clock for it too).
var clock_scale := 1.0


## The other wardens on a bus (their coop_state): peer id -> it.
func _mates_info() -> Dictionary:
	var out := {}
	for id in Coop.others():
		var b = Coop.state_of(id).get("bus", {})
		if b is Dictionary and not (b as Dictionary).is_empty():
			out[int(id)] = b
	return out


## Another warden aboard this bus at the stop, not gone yet (`seat`: in that seat).
func _mate_aboard(seat := -2) -> bool:
	var all := _mates_info()
	for id in all.keys():
		var m: Dictionary = all[id]
		if str(m.get("st", "")) == stop and not bool(m.get("go", false)) and (seat == -2 or int(m.get("s", -1)) == seat):
			return true
	return false


# ── in and out ───────────────────────────────────────────────────────────────

## Gets on the bus standing at `at_stop` ("camp", "town", or at Podlesi "hamlet_town" /
## "hamlet_camp") at `hour`.
var _hour_now := 0.0


func open_ride(at_stop: String, hour: float, fog: float, raining: bool) -> void:
	stop = at_stop
	_hour_now = hour
	if not _built:
		_build()
		_built = true
	RETRO_RENDER.apply_to(_container)
	_into_world()
	_prepare_path()
	_state = BOARDING
	visible = true
	_ticket = {}
	_ticket_card.visible = false
	_seat = -1
	_mate_wait = 0.0
	_mate_said = false
	_speed = 0.0
	set_time(hour, fog, raining)
	_travelled = 0.0
	_place_rig()
	arrived_where = ""
	_stop_at = -1.0
	_stop_who = ""
	_stop_rider = false
	_board_plan = false
	_drop_boarder()
	_walking = false
	_bump_cell = -1
	_truck_cell = -1
	_gear_at = 0
	_set_stojime(false)
	_seat_passengers()
	_set_door(true, true)
	_cam.position = STAND_POS
	_cam.rotation = Transform3D(Basis(), STAND_POS).looking_at(STAND_LOOK, Vector3.UP).basis.get_euler()
	_cam_base = _cam.rotation
	_look = INTERIOR_LOOK.new(115.0, 26.0, 34.0)
	_ride.stream = _loop(load(SFX + "idle.mp3"))
	_ride.volume_db = -14.0
	_ride.play()
	# Somebody on board wants Pristoupim now and then (by day, when it is still ahead);
	# old Vacek waits there for it now and then. The run's dice (_life_rng): the same in
	# co-op on every machine.
	if path_hamlet > 0.0 and not _passengers.is_empty() and not _night and _life_rng.randf() < 0.3:
		_stop_at = path_hamlet
		_stop_who = "rider"
		_stop_rider = true
	if path_hamlet > 0.0 and not _night and _vacek_ready() and _life_rng.randf() < 0.6:
		_board_plan = true
		_board_pick = _life_rng.randi()
		_board_story = "v2" if stop == "town" else ("v1" if _life_rng.randf() < 0.55 else "v3")
		_stop_at = path_hamlet
		if _stop_who == "":
			_stop_who = "board"
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_say("", 0.0)


## Off the bus before it goes (S, the door, the bottom of the screen, the pause menu).
func leave() -> void:
	if _state != BOARDING:
		return
	_shut()
	left_bus.emit()


## The pause menu's way out while riding: there at once.
func close_interior() -> void:
	match _state:
		BOARDING:
			leave()
		SITTING, RIDING, STOPPING, DONE, HELD, PAUSED:
			_shut()
			arrived.emit()


func _punching() -> bool:
	return _punch_view != null and _punch_view.visible


func _shut() -> void:
	if _punching():
		_punch_view.close_view()
	_state = CLOSED
	# The game's own view draws again.
	if _main_vp != null and is_instance_valid(_main_vp):
		_main_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	visible = false
	_glint.clear()
	_drop_boarder()
	if _walk_tw != null and _walk_tw.is_valid():
		_walk_tw.kill()
	_walking = false
	_ride.stop()
	for p in [_rattle, _wind, _radio, _mouth, _mouth2, _driver_mouth]:
		if p != null:
			p.stop()
	_talk.clear()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


## The cabin by the hour: the strip lights on after dark (the panes then all but
## gone, the dark outside showing), rain on the glass. The outside is the world's own
## sky, sun and fog: the cabin rides in it.
func set_time(hour: float, _fog: float, raining: bool) -> void:
	_night = hour >= 20.3 or hour < 5.8
	if _glass != null:
		_glass.set_shader_parameter("rain", 1.0 if raining else 0.0)
		_glass.set_shader_parameter("night", 1.0 if _night else 0.0)
	var fill := _rig.get_node_or_null("CabinFill") as DirectionalLight3D if _rig != null else null
	if fill != null:
		fill.light_energy = 0.08 if _night else 0.35
	if _strip_mat != null:
		_strip_mat.emission = Color(1.0, 0.9, 0.7) * (1.6 if _night else 0.15)
	for l in _strip_lights:
		l.visible = _night


## Into the game's world: this view shows it from the cabin's camera, and the game's own
## view (the player's eye, left at the stop) stops drawing while you ride.
func _into_world() -> void:
	var main := get_tree().current_scene
	_main_vp = main.get_node_or_null("SubViewportContainer/SubViewport") as SubViewport if main != null else null
	if _main_vp != null:
		_vp.world_3d = _main_vp.find_world_3d()
		_main_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED


## The distances along `path`, and the speed limits if none came with it.
func _prepare_path() -> void:
	_path_s.resize(path.size())
	var acc := 0.0
	for i in path.size():
		if i > 0:
			acc += path[i].distance_to(path[i - 1])
		_path_s[i] = acc
	if path_limits.size() != path.size():
		path_limits.resize(path.size())
		for i in path.size():
			path_limits[i] = 14.0


func _route_length() -> float:
	return _path_s[_path_s.size() - 1] if _path_s.size() > 0 else 0.0


## Where the bus is `d` metres along the path: its position and its heading, the
## heading eased over a few metres either way so it turns, not snaps.
func _pose_at(d: float) -> Transform3D:
	if path.size() < 2:
		return ride_bus.global_transform if ride_bus != null else Transform3D()
	var p := _point_at(d)
	var dir := (_point_at(d + 3.0) - _point_at(d - 3.0))
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = path[mini(1, path.size() - 1)] - path[0]
	return Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP), p)


func _point_at(d: float) -> Vector3:
	var total := _route_length()
	if d <= 0.0:
		var e := (path[1] - path[0]).normalized()
		return path[0] + e * d
	if d >= total:
		var e2 := (path[path.size() - 1] - path[path.size() - 2]).normalized()
		return path[path.size() - 1] + e2 * (d - total)
	var i := clampi(_path_s.bsearch(d) - 1, 0, path.size() - 2)
	var seg := maxf(0.001, _path_s[i + 1] - _path_s[i])
	return path[i].lerp(path[i + 1], (d - _path_s[i]) / seg)


func _limit_at(d: float) -> float:
	if path_limits.is_empty():
		return 14.0
	var i := clampi(_path_s.bsearch(d) - 1, 0, path_limits.size() - 1)
	return path_limits[i]


## How fast it may go here: what the road allows, and slower ahead in time to brake for
## a bend or a village.
func _cruise_now() -> float:
	var v := 22.0
	var look := _speed * _speed / (2.0 * BRAKE) + 12.0
	var k := 0.0
	while k <= look:
		v = minf(v, sqrt(pow(_limit_at(_travelled + k), 2.0) + 2.0 * BRAKE * k))
		k += 5.0
	return v


## The bus and the cabin in it where the ride is.
func _place_rig() -> void:
	var t := _pose_at(_travelled)
	if ride_bus != null and is_instance_valid(ride_bus):
		ride_bus.global_transform = t
		ride_bus.set_speed(_speed)
	if _rig != null:
		_rig.global_transform = t.translated_local(Vector3(0, CABIN_Y, 0))


## The real seconds the ride will take at the road's speeds, for town_trip.gd's clock.
func expected_seconds() -> float:
	var secs := 0.0
	for i in range(1, path.size()):
		secs += (_path_s[i] - _path_s[i - 1]) / maxf(4.0, path_limits[i] * 0.88)
	return secs + 12.0


# ── every frame ──────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _state == CLOSED:
		return
	_update_mate()
	if _state == HELD and (_mate_ready(delta) or _leader_went()):
		_depart()
	if _state in [RIDING, STOPPING, PAUSED]:
		_follow(delta)
		_merge_stops()
	_say_t -= delta
	if _say_label != null:
		_say_label.modulate.a = clampf(_say_t / 0.4, 0.0, 1.0)
	match _state:
		RIDING:
			var left: float = _target() - _travelled
			if left <= _speed * _speed / (2.0 * BRAKE) + 2.0:
				_state = STOPPING
				# Old Vacek's goodbye as it pulls in at the end of the line.
				if not _at_request() and str(_boarder.get("phase", "")) == "sat":
					_start_talk("vo")
				if _at_request():
					_play_two("karosa_gravel.mp3", -6.0)
					_play("karosa_indicator.mp3", -14.0)
				else:
					_play("brake_inside.mp3", -15.0)
			else:
				var was := _speed
				var want := _cruise_now()
				_speed = move_toward(_speed, want, (ACCEL if want > _speed else BRAKE) * delta)
				_shift(was)
		STOPPING:
			_speed = move_toward(_speed, 0.0, BRAKE * delta)
			if _speed <= 0.05:
				_speed = 0.0
				_set_door(true)
				_play("door_open.mp3", -2.0)
				_ride.stream = _loop(load(SFX + "idle.mp3"))
				_ride.volume_db = -14.0
				_ride.play()
				if _at_request() and _stop_who != "you":
					# It only stops at Pristoupim: somebody gets off (a villager, the
					# other warden), old Vacek gets on; then it goes on.
					_state = PAUSED
					_pause_t = 0.0
					_driver("d_pristoupim")
					if _stop_rider:
						_rider_off()
				else:
					if _at_request():
						arrived_where = "hamlet"
						_driver("d_pristoupim")
					_state = DONE
					_done_t = 0.0
		PAUSED:
			_pause_t += delta
			# Old Vacek gets on (in co-op where the leader's machine seats him, given a
			# moment to say so); the bus waits till he is up the steps.
			if _board_plan and _boarder.is_empty():
				var lead := _leader_state()
				if lead.is_empty() or int(lead.get("bs", -1)) >= 0 or _pause_t > 1.6:
					_board_start(int(lead.get("bs", -1)))
			var boarding := str(_boarder.get("phase", "")) == "walk" and int(_boarder.get("i", 99)) < 4
			if _pause_t > 3.2 and not boarding:
				_stop_at = -1.0
				_stop_who = ""
				_stop_rider = false
				_board_plan = false
				_set_stojime(false)
				_gear_at = 0
				_depart()
		DONE:
			_done_t += delta
			if _done_t > 1.1:
				_shut()
				arrived.emit()
				return
	if _speed > 0.0:
		_travelled += _speed * delta * clock_speed_fix
		_update_traffic(delta)
	if _state != CLOSED:
		_place_rig()
	if _state == RIDING or _state == STOPPING:
		var sp := clampf(_speed / CRUISE, 0.0, 1.0)
		_ride.volume_db = lerpf(-12.0, -4.0, sp)
		_ride.pitch_scale = lerpf(0.85, 1.05, sp)
		if _rattle != null and _rattle.playing:
			_rattle.volume_db = lerpf(-30.0, -11.0, sp) + _bump * 140.0
		if _wind != null and _wind.playing:
			_wind.volume_db = lerpf(-40.0, -17.0, sp)
			_wind.pitch_scale = lerpf(0.8, 1.1, sp)
		_update_engine()
	if _state in [RIDING, STOPPING, PAUSED]:
		_update_life(delta)
	_update_boarder(delta)
	_update_bumps(delta)
	_update_swing(delta)
	_face_passengers(delta)
	if _door_k != _door_want:
		_door_k = move_toward(_door_k, _door_want, delta * 1.7)
		_fold_door()
	if _glass != null:
		_glass.set_shader_parameter("t", floorf(Time.get_ticks_msec() / 83.0) * 0.083)
		_glass.set_shader_parameter("speed", clampf(_speed / CRUISE, 0.0, 1.0))
	if _state == SITTING or _punching():
		return
	if _walking:
		_glint.clear()
		return
	var offset: Vector3 = _look.update(delta, INTERIOR_LOOK.cursor_of(get_viewport()), INTERIOR_LOOK.turn_axis())
	_cam.rotation = _cam_base + offset
	_update_hover()
	if _exit_hint == null:
		_exit_hint = INTERIOR_LOOK.make_exit_hint(self, "Get off   [S]")
	INTERIOR_LOOK.update_exit_hint(_exit_hint, get_viewport(), delta, _state == BOARDING)


## The road under the wheels: now and then a pothole jolts the view, in steps.
func _update_bumps(delta: float) -> void:
	# Every few metres of road a bump or not, the same for everyone on this bus.
	var cell := int(_travelled / 7.0)
	if _speed > 2.0 and cell != _bump_cell:
		_bump_cell = cell
		if _hash01(cell, 17) < 0.45:
			_bump = lerpf(0.015, 0.042, _hash01(cell, 29))
			# A real pothole now and then: the thump and the whole body clattering.
			if _bump > 0.034:
				_play_two("karosa_pothole.mp3", -9.0)
	_bump = maxf(0.0, _bump - delta * 0.12)
	var tick := floorf(Time.get_ticks_msec() / 83.0)
	var sway := 0.0
	if _speed > 1.0:
		sway = sin(tick * 0.37) * 0.006 * (_speed / CRUISE)
	if _state in [RIDING, STOPPING, DONE, PAUSED] and _seat >= 0 and not _walking:
		_cam.position = _seat_pos() + Vector3(sway, (_bump if int(tick) % 2 == 0 else -_bump * 0.5), 0)


## A number 0..1 from a whole number: the same on every machine.
static func _hash01(n: int, salt: int) -> float:
	var x := (n * 73856093) ^ (salt * 19349663)
	x = (x ^ (x >> 13)) * 1274126177
	return float(posmod(x ^ (x >> 16), 10007)) / 10007.0


func _update_hover() -> void:
	_hover = ""
	var hit := _raycast(get_viewport().get_mouse_position())
	var n = hit.get("collider", null)
	if n != null and (n as Node).has_meta("hot"):
		var id := str((n as Node).get_meta("hot"))
		if _hot_allowed(id):
			_hover = id
	if _hover != "":
		HandCursor.want(HandCursor.POINT)
		for h in _hot:
			if str(h["id"]) == _hover:
				_glint.show_on(h["meshes"])
	else:
		_glint.clear()
		if _state == BOARDING and INTERIOR_LOOK.in_exit_zone(get_viewport()):
			HandCursor.want(HandCursor.WALK)


func _hot_allowed(id: String) -> bool:
	if _walking:
		return false
	if _state != BOARDING:
		if id.begins_with("stop:"):
			return _state == RIDING
		# Sat down: another free seat (get up and go and sit there).
		if id.begins_with("seat:") and _seat >= 0 and _state in [HELD, RIDING, STOPPING, PAUSED]:
			var k := int(id.get_slice(":", 1))
			return k != _seat and not _taken.has(k) and not _mate_in_seat(k)
		return id == "driver"
	if id.begins_with("seat:"):
		return not _taken.has(int(id.get_slice(":", 1)))
	return true


func _raycast(mouse_pos: Vector2) -> Dictionary:
	if _cam == null or _vp == null:
		return {}
	var world := _vp.find_world_3d()
	var screen := get_viewport().get_visible_rect().size
	if world == null or screen.x <= 0.0:
		return {}
	var local := Vector2(clampf(mouse_pos.x / screen.x, 0.0, 1.0) * float(_vp.size.x), clampf(mouse_pos.y / screen.y, 0.0, 1.0) * float(_vp.size.y))
	var o := _cam.project_ray_origin(local)
	var d := _cam.project_ray_normal(local)
	var q := PhysicsRayQueryParameters3D.create(o, o + d * 12.0, HOT_LAYER)
	return world.direct_space_state.intersect_ray(q)


func _input(event: InputEvent) -> void:
	if _state == CLOSED or get_tree().paused or _punching():
		return
	if _state == BOARDING and INTERIOR_LOOK.is_exit_event(event, get_viewport()) and _hover == "":
		leave()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _hover != "":
		_click(_hover)
		get_viewport().set_input_as_handled()


func _click(id: String) -> void:
	if id == "punch":
		_punch()
	elif id == "driver":
		if _state == BOARDING and _ticket.is_empty() and not _bag_has("ticket"):
			_buy_from_driver()
			return
		var lines: Array = (DRIVER_NIGHT if _night and _rng.randf() < 0.5 else DRIVER_LINES.get(stop, DRIVER_LINES["camp"]))
		_driver(str(lines[_rng.randi() % lines.size()]))
	elif id == "door":
		leave()
	elif id.begins_with("seat:"):
		if _seat >= 0 and _state != BOARDING:
			_move_seat(int(id.get_slice(":", 1)))
		else:
			_try_sit(int(id.get_slice(":", 1)))
	elif id.begins_with("stop:"):
		_press_stop()


# ── the ticket, the seat, the ride ───────────────────────────────────────────

func _bag():
	return INVENTORY.find(get_tree())


func _bag_has(id: String) -> bool:
	var bag = _bag()
	return bag != null and bag.has(id)


## A ticket from the driver, with the surcharge: into the bag, to be punched.
func _buy_from_driver() -> void:
	if CoreRoot.get_money() < DRIVER_PRICE or not CoreRoot.actions.spend_money(DRIVER_PRICE):
		_driver("d_no_money")
		return
	_play("coin.mp3", -6.0)
	var bag = _bag()
	if bag == null or not bag.add_item("ticket"):
		# No room in the bag: it stays in your hand.
		_ticket = {"punched": false}
	_driver("d_surcharge")


## The orange box on the pole: in goes the ticket, cvak, out it comes punched.
func _punch() -> void:
	if bool(_ticket.get("punched", false)):
		_say("Punched already. The holes say so.", 2.4)
		return
	var bag = _bag()
	var have: bool = not _ticket.is_empty() or (bag != null and bag.has("ticket"))
	if not have:
		_say("Nothing to punch. A ticket from the machine at the stop, or from the driver.", 3.0)
		return
	if _punch_view == null:
		_punch_view = PUNCH_CLOSEUP.new()
		add_child(_punch_view)
		_punch_view.punched.connect(_punched)
	_punch_view.stamp = TIMES_HM.hm(_hour_now)
	_glint.clear()
	_punch_view.open_view()


## The cvak (in the close-up): the ticket from the bag is now a punched one.
func _punched() -> void:
	var bag = _bag()
	if _ticket.is_empty() and bag != null:
		bag.remove_item("ticket")
	var to := "LIBLICE" if stop == "camp" or stop == "hamlet_town" else "KEMP"
	if bought_to != "" and not (stop.begins_with("hamlet") and bought_to == "PRISTOUPIM"):
		to = bought_to
	bought_to = ""
	_ticket = {"punched": true, "to": to, "kind": "adult", "price": 2, "at": TIMES_HM.hm(_hour_now)}
	_play_two("thump.mp3", -12.0)
	if bag != null:
		bag.add_item("ticket_used")
	_ticket_card.visible = true
	_ticket_card.queue_redraw()


## Where this bus goes, and whether `t` gets you there.
func _ticket_problem(t: Dictionary) -> String:
	if t.is_empty() or not bool(t.get("punched", true)):
		if _bag_has("ticket") or not t.is_empty():
			return "d_punch_first"
		return "d_no_ticket"
	if t.has("punched"):
		return ""
	var goes_to := "LIBLICE" if stop == "camp" or stop == "hamlet_town" else "KEMP"
	var to := str(t.get("to", ""))
	if str(t.get("kind", "")) == "half":
		return "d_half"
	if to in ["DOG", "BAG"]:
		return "d_dog"
	if to == goes_to or to == "LSTIBOR":
		return ""
	# Podlesi is on the way from either end; the bus stops there for it.
	if to == "PRISTOUPIM" and not stop.begins_with("hamlet"):
		return ""
	return "That's for the dam. This goes to %s." % ("Liblice" if goes_to == "LIBLICE" else "the camp")


## The first seat nobody sits on, from `from` on (for the screenshot tours).
func first_free_seat(from := 0) -> int:
	for k in SEATS.size():
		var i := (from + k) % SEATS.size()
		if not _taken.has(i) and not _mate_aboard(i):
			return i
	return -1


func _try_sit(i: int) -> void:
	var problem := _ticket_problem(_ticket)
	if problem != "":
		if problem.begins_with("d_"):
			_driver(problem)
		else:
			_say("Driver: \"%s\"" % problem, 3.5)
		return
	if _mate_aboard(i) or _taken.has(i):
		_driver("d_taken")
		return
	_seat = i
	_state = SITTING
	_glint.clear()
	var pos := _seat_pos()
	var face := pos + Vector3(1.3 if SEATS[i].x > 0.0 else -1.3, -0.1, -1.3)
	var rot := Transform3D(Basis(), pos).looking_at(face, Vector3.UP).basis.get_euler()
	CAM_MOVE.move(self, _cam, {"position": pos, "rotation": rot}, 0.7, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	_play("door_close.mp3", -2.0)
	get_tree().create_timer(0.75).timeout.connect(func():
		if _state != SITTING:
			return
		_cam_base = rot
		_look = INTERIOR_LOOK.new(120.0, 24.0, 30.0)
		# Co-op: sat down, the bus waits for the other warden (_mate_ready).
		_state = HELD
	)


## The doors shut and it goes: the Karosa's diesel, its rattle and the draught; the
## driver's radio by day. A ticket to Podlesi asks for the stop by itself.
func _depart() -> void:
	_set_door(false)
	_state = RIDING
	_play("start_inside.mp3", -2.0)
	_ride.stream = _loop(_sfx("karosa_cruise.mp3", "ride.mp3"))
	_ride.volume_db = -12.0
	_ride.play()
	# _update_engine picks the loop for the road it pulls away on.
	_engine = ""
	for pair in [[_rattle, "karosa_rattle.mp3"], [_wind, "karosa_wind.mp3"]]:
		var player: AudioStreamPlayer = pair[0]
		var st := _sfx(str(pair[1]))
		if player != null and st != null and not player.playing:
			player.stream = _loop(st)
			player.volume_db = -40.0
			player.play()
	if _radio != null and not _radio.playing and not _night:
		var polka := _sfx("radio_polka.mp3")
		if polka != null:
			_radio.stream = _loop(polka)
			_radio.volume_db = -21.0
			_radio.play()
	if str(_ticket.get("to", "")) == "PRISTOUPIM" and _stop_at < 0.0:
		var at: float = path_hamlet
		if at > _travelled + 10.0:
			_stop_at = at
			_stop_who = "you"


## Where the bus is braking for: the request stop when somebody asked for it, else the
## end of the line.
func _target() -> float:
	if _stop_who != "" and _stop_at > _travelled - 1.0:
		return _stop_at
	return _route_length()


func _at_request() -> bool:
	return _stop_who != "" and absf(_stop_at - _travelled) < 40.0


## A red STOP button: the buzzer, STOJIME lights up, the driver will pull in at
## Podlesi, if it is still ahead and far enough to stop for.
func _press_stop() -> void:
	_play_two("karosa_stop_bell.mp3", -4.0)
	var at: float = path_hamlet
	var room := _speed * _speed / (2.0 * BRAKE) + 6.0
	if at < 0.0 or at < _travelled:
		_driver("d_end")
		return
	if at - _travelled < room:
		_driver("d_too_late")
		return
	_stop_at = at
	_stop_who = "you"
	_set_stojime(true)
	_driver("d_request")


func _set_stojime(on: bool) -> void:
	if _stojime != null:
		_stojime.emission_energy_multiplier = 2.0 if on else 0.0


## Somebody off at Podlesi: the one nearest the door goes.
func _rider_off() -> void:
	_set_stojime(true)
	if _passengers.is_empty():
		return
	var best := 0
	for i in _passengers.size():
		if _passengers[i].position.z < _passengers[best].position.z:
			best = i
	_passengers[best].queue_free()
	_passengers.remove_at(best)


## The gearbox crunching into the next gear as it picks up speed.
func _shift(was: float) -> void:
	if _gear_at < GEARS.size() and was < float(GEARS[_gear_at]) and _speed >= float(GEARS[_gear_at]):
		_gear_at += 1
		_play_two("karosa_gear.mp3", -8.0)


## The engine loop by the road: labouring up through the forest above the camp on the
## way out (the old Karosa in a low gear), droning along the flat after; a gear crunch
## covers the change.
func _update_engine() -> void:
	if _state != RIDING:
		return
	# Labouring away from a stop and up to speed, droning once it is there.
	var want := "climb" if _speed < 9.0 and _travelled < 200.0 else "cruise"
	if want == _engine:
		return
	var st := _sfx("karosa_%s.mp3" % want, "ride.mp3")
	if st == null:
		return
	if _engine != "":
		_play_two("karosa_gear.mp3", -8.0)
	_engine = want
	_ride.stream = _loop(st)
	_ride.play()


## What happens on this ride and when (seconds since the doors shut): a cough, a
## newspaper; two people talking, or one with the driver; now and then one turning round
## to you. From _life_rng, so in co-op both wardens hear and see the same.
func _plan_life() -> void:
	_events.clear()
	_talk.clear()
	_ride_t = 0.0
	if _passengers.is_empty():
		return
	var t := _life_rng.randf_range(8.0, 16.0)
	while t < 400.0:
		_events.append({"at": t, "kind": "cough" if _life_rng.randf() < 0.5 else "paper", "who": _life_rng.randi()})
		t += _life_rng.randf_range(11.0, 24.0)
	var talks: Array = []
	var turns: Array = []
	for id in _talk_scenes().keys():
		(turns if str(id).begins_with("t") else talks).append(str(id))
	talks.sort()
	turns.sort()
	# The ride is a minute and a bit: somebody starts talking soon after it goes, often
	# again later; now and then one turns round.
	if not talks.is_empty() and _life_rng.randf() < (0.5 if _night else 0.95):
		_events.append({"at": _life_rng.randf_range(7.0, 16.0), "kind": "talk", "pick": _life_rng.randi()})
	if not talks.is_empty() and _life_rng.randf() < 0.6:
		_events.append({"at": _life_rng.randf_range(38.0, 52.0), "kind": "talk", "pick": _life_rng.randi()})
	if _life_rng.randf() < 0.4:
		_events.append({"at": _life_rng.randf_range(24.0, 34.0), "kind": "turn", "who": _life_rng.randi(), "pick": _life_rng.randi()})
	_events.sort_custom(func(a, b): return float(a["at"]) < float(b["at"]))


## Now and then a lorry the other way on the main road: its roar past the windows.
func _update_traffic(_delta: float) -> void:
	if _speed < 13.0:
		return
	# By the stretch of road (the same for everyone on this bus).
	var cell := int(_travelled / 260.0)
	if cell != _truck_cell:
		_truck_cell = cell
		if _hash01(cell, 5) < 0.45:
			_play_two("karosa_truck.mp3", -13.0)


## The life on board as the ride goes: what _plan_life put down, and the conversation's
## lines one after another.
func _update_life(delta: float) -> void:
	_ride_t += delta
	while not _events.is_empty() and _ride_t >= float(_events[0]["at"]):
		var e: Dictionary = _events.pop_front()
		if _passengers.is_empty():
			continue
		var who: Sprite3D = _passengers[int(e.get("who", 0)) % _passengers.size()]
		match str(e["kind"]):
			"cough":
				_sound_at(_mouth2, _head(who), SFX + "cough.mp3", -9.0)
			"paper":
				_sound_at(_mouth2, _head(who), SFX + "newspaper.mp3", -11.0)
			"talk":
				if _talk.is_empty():
					# The picked scene, or the next one the people on board can play.
					var ids: Array = _talk_scenes().keys().filter(func(k): return not str(k).begins_with("t"))
					ids.sort()
					for k in ids.size():
						if _start_talk(str(ids[(int(e["pick"]) + k) % ids.size()])):
							break
			"turn":
				_turn_round(who, int(e["pick"]))
			"vacek":
				# His story once he has sat down (later if somebody is still talking).
				if not _talk.is_empty():
					e["at"] = _ride_t + 4.0
					_events.append(e)
					_events.sort_custom(func(a, b): return float(a["at"]) < float(b["at"]))
				else:
					_start_talk(_board_story)
	if not _talk.is_empty() and not _mouth.playing:
		_talk_gap -= delta
		if _talk_gap <= 0.0:
			var line: Dictionary = _talk.pop_front()
			var path := _talk_path(str(line["file"]))
			# Without its voice a line still goes by under the picture, for as long as
			# it would take to say.
			var secs := 1.4 + 0.055 * str(line["en"]).length()
			if path != "":
				var st: AudioStream = load(path)
				secs = st.get_length() + 0.4
				_sound_at(_driver_mouth if str(line.get("role", "")) == "driver" else _mouth, line["at"], path, -5.0)
			# Old Vacek turns round to you while he talks.
			var who = line.get("who")
			if who is Sprite3D and is_instance_valid(who) and bool(line.get("face", false)):
				(who as Sprite3D).set_meta("turn", secs + 0.8)
			_say("%s: \"%s\"" % [line["name"], line["en"]], secs)
			_talk_gap = 0.5 if path != "" else secs + 0.4


## talk.json (tools/audiogen/bus_talk.py): the scenes, who says what.
func _talk_scenes() -> Dictionary:
	if _scenes.is_empty() and FileAccess.file_exists(TALK + "talk.json"):
		var data = JSON.parse_string(FileAccess.get_file_as_string(TALK + "talk.json"))
		if data is Dictionary:
			_scenes = data.get("scenes", {})
	return _scenes


## A line's voice: ElevenLabs' <id>.mp3, else the stand-in <id>.wav (Windows' Czech
## voice, tools/audiogen/bus_talk_local.ps1); "" if neither.
func _talk_path(file: String) -> String:
	for f in [file, file.get_basename() + ".wav"]:
		if ResourceLoader.exists(TALK + f):
			return TALK + f
	return ""


## Who on board says a line in `voice`: the villager with that voice, else one of the same
## sex not talking yet in this scene. Null: nobody fits.
func _speaker(voice: String, gender: String, used: Array) -> Sprite3D:
	for p in _passengers:
		if str(p.get_meta("voice", "")) == voice:
			return p
	for p in _passengers:
		if str(p.get_meta("g", "")) == gender and not used.has(p):
			return p
	return null


## A conversation: everyone in it has to be on board (the driver always is). False if
## somebody in it is not.
func _start_talk(id: String) -> bool:
	var lines: Array = _talk_scenes().get(id, [])
	var cast := {}
	var used: Array = []
	for line in lines:
		var role := str(line["role"])
		if role == "driver" or cast.has(role):
			continue
		var who := _speaker(str(line["voice"]), str(line["gender"]), used)
		if who == null:
			return false
		cast[role] = who
		used.append(who)
	for line in lines:
		var role := str(line["role"])
		var who: Sprite3D = cast.get(role)
		_talk.append({"at": DRIVER_HEAD if role == "driver" else _head(who), "file": line["file"], "en": line["en"],
				"name": "Driver" if role == "driver" else str(who.get_meta("name", "Passenger")),
				"role": role, "who": who, "face": role == "vacek"})
	_talk_gap = 0.0
	return true


## One of them turns round to you and says something (their own line, if one is theirs).
func _turn_round(who: Sprite3D, pick: int) -> void:
	var mine: Array = []
	var any: Array = []
	var scenes := _talk_scenes()
	for id in scenes.keys():
		if not str(id).begins_with("t"):
			continue
		var line: Dictionary = scenes[id][0]
		any.append(line)
		if str(line["voice"]) == str(who.get_meta("voice", "")):
			mine.append(line)
	var from: Array = mine if not mine.is_empty() else any
	if from.is_empty() or not _talk.is_empty():
		return
	from.sort_custom(func(a, b): return str(a["file"]) < str(b["file"]))
	var line: Dictionary = from[pick % from.size()]
	who.set_meta("turn", 4.2)
	var path := _talk_path(str(line["file"]))
	if str(line["voice"]) == str(who.get_meta("voice", "")) and path != "":
		_sound_at(_mouth, _head(who), path, -4.0)
	_say("%s: \"%s\"" % [str(who.get_meta("name", "Passenger")), line["en"]], 3.8)


func _head(who: Sprite3D) -> Vector3:
	return who.position + Vector3(0, SIT_TALL * 0.85, 0)


func _sound_at(player: AudioStreamPlayer3D, at: Vector3, path: String, db: float) -> void:
	if player == null or not ResourceLoader.exists(path):
		return
	player.position = at
	player.stream = load(path)
	player.volume_db = db
	player.play()


## A back for a sprite drawn only from the front: mirrored, and in the head (the top
## fifth) every row's face, from its first skin pixel to its last, filled with the
## hair's colour, so from behind nobody looks at you.
static var _backs: Dictionary = {}


static func _back_of(front: Texture2D) -> Texture2D:
	var key := front.resource_path
	if _backs.has(key):
		return _backs[key]
	var img := front.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.flip_x()
	var w := img.get_width()
	var h := img.get_height()
	var top := 0
	while top < h - 1 and not _row_has(img, top):
		top += 1
	var head_to := top + int(float(h - top) * 0.2)
	# The hair (or the hat): the commonest colour up top that is not skin.
	var counts := {}
	for y in range(top, top + maxi(2, int(float(h - top) * 0.07))):
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a > 0.5 and not _skin(c) and c.get_luminance() > 0.06:
				var k := c.to_html(false)
				counts[k] = int(counts.get(k, 0)) + 1
	var hair := Color(0.22, 0.16, 0.1)
	var most := 0
	for k in counts.keys():
		if int(counts[k]) > most:
			most = int(counts[k])
			hair = Color.html(str(k))
	for y in range(top, head_to):
		var from := -1
		var to := -1
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a > 0.5 and _skin(c):
				if from < 0:
					from = x
				to = x
		for x in range(maxi(from, 0), to + 1):
			if img.get_pixel(x, y).a > 0.5:
				img.set_pixel(x, y, hair.darkened(0.12 if (x + y) % 3 == 0 else 0.0))
	var tex := ImageTexture.create_from_image(img)
	_backs[key] = tex
	return tex


static func _row_has(img: Image, y: int) -> bool:
	for x in img.get_width():
		if img.get_pixel(x, y).a > 0.5:
			return true
	return false


static func _skin(c: Color) -> bool:
	return c.r > c.g and c.g > c.b and c.r - c.b > 0.14 and c.r > 0.38 and c.r - c.g < 0.32


## The people on board look the way the bus goes, not at you: from ahead you see their
## fronts, from behind their backs, each turned at most LOOK_SPREAD towards your eye.
## The one who turned round to talk looks right at you for a moment.
func _face_passengers(delta: float) -> void:
	var eye := _cam.position
	for s in _passengers:
		if not is_instance_valid(s):
			continue
		var turned := float(s.get_meta("turn", 0.0))
		if turned > 0.0:
			s.set_meta("turn", turned - delta)
		if not s.has_meta("back"):
			continue
		var back: Texture2D = s.get_meta("back")
		var to := Vector2(eye.x - s.position.x, eye.z - s.position.z)
		var at_you := atan2(to.x, to.y)
		var from_behind := to.y > 0.0 and turned <= 0.0
		var tex: Texture2D = back if from_behind else s.get_meta("front")
		# Turned round to you from in front of you: over his shoulder (Vacek's own picture).
		if turned > 0.0 and to.y > 0.0 and s.has_meta("turnback"):
			tex = s.get_meta("turnback")
		if s.texture != tex:
			s.texture = tex
			_place_seated(s, int(s.get_meta("seat")))
		if turned > 0.0:
			s.rotation.y = at_you
			continue
		var ahead := 0.0 if from_behind else PI
		s.rotation.y = ahead + clampf(wrapf(at_you - ahead, -PI, PI), -LOOK_SPREAD, LOOK_SPREAD)


func _sfx(name: String, fallback := "") -> AudioStream:
	for f in [name, fallback]:
		if str(f) != "" and ResourceLoader.exists(SFX + str(f)):
			return load(SFX + str(f))
	return null


func _play_two(file: String, db: float) -> void:
	if _two != null and ResourceLoader.exists(SFX + file):
		_two.stream = load(SFX + file)
		_two.volume_db = db
		_two.play()


## Co-op: may it go? Wardens on board: once every one of them sits (or it went for
## them). One near the stop outside: a moment for them. Elsewhere, or alone: at once.
func _mate_ready(delta: float) -> bool:
	if not Coop.has_partner():
		return true
	var all := _mates_info()
	var someone_near := false
	for id in Coop.others():
		var m: Dictionary = all.get(id, {})
		if not m.is_empty() and str(m.get("st", "")) == stop:
			if int(m.get("s", -1)) < 0 and not bool(m.get("go", false)):
				_driver_waits()
				return false
			continue
		var st: Dictionary = Coop.state_of(id)
		var p: Vector3 = st.get("p", Vector3.INF)
		if stop_pos != Vector3.INF and p != Vector3.INF and not bool(st.get("in", false)) \
				and Vector2(p.x - stop_pos.x, p.z - stop_pos.z).length() < 30.0:
			someone_near = true
	if someone_near and _mate_wait < MATE_WAIT:
		_mate_wait += delta
		_driver_waits()
		return false
	return true


func _driver_waits() -> void:
	if _mate_said:
		return
	_mate_said = true
	_driver("d_mate")


## The other wardens on this bus: standing by the door till they sit (one behind another),
## then in their seats, seen from the front or (you behind them) from the back.
func _update_mate() -> void:
	var all := _mates_info()
	var standing := 0
	for id in Coop.others():
		var m: Dictionary = all.get(id, {})
		# On the same run: both still at the stop, or both gone.
		var here := not m.is_empty() and str(m.get("st", "")) == stop and bool(m.get("go", false)) == (_state in [RIDING, STOPPING, DONE])
		var fig: Sprite3D = _mates.get(id)
		if not here:
			if fig != null and is_instance_valid(fig):
				fig.visible = false
			continue
		if int(m.get("s", -1)) < 0:
			standing += 1
		_show_mate(int(id), m, standing)
	for id in _mates.keys():
		if not Coop.wardens.has(id) and is_instance_valid(_mates[id]):
			_mates[id].visible = false


func _show_mate(id: int, m: Dictionary, nth_standing: int) -> void:
	var fig: Sprite3D = _mates.get(id)
	if fig == null or not is_instance_valid(fig):
		fig = Sprite3D.new()
		fig.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		fig.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		fig.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		fig.shaded = true
		fig.layers = 2
		_rig.add_child(fig)
		_mates[id] = fig
		_mate_poses[id] = ""
	var seat := int(m.get("s", -1))
	# By the driver, the next one a step back down the aisle.
	var pos := Vector3(0.25, 0.0, -3.5 + 0.55 * float(maxi(0, nth_standing - 1)))
	var pose := "stand"
	if m.has("wz"):
		# Walking down the aisle to another seat.
		pos = Vector3(0.1, 0.0, float(m["wz"]))
		seat = -1
	elif seat >= 0 and seat < SEATS.size():
		var sv: Vector2 = SEATS[seat]
		pos = Vector3(sv.x, 0.0, sv.y)
		# The bus faces -z: sat behind them you see their back.
		pose = "desk" if _cam.position.z > sv.y + 0.2 else "sit"
	var look: Dictionary = Coop.look_of(id)
	var key := "%s|%d|%d" % [pose, int(look.get("m", 1)), int(look.get("c", 0))]
	if key != str(_mate_poses.get(id, "")):
		_mate_poses[id] = key
		var tex: Texture2D = LOOKS.texture(int(look.get("m", 1)), int(look.get("c", 0)), pose)
		fig.texture = tex
		if tex != null:
			fig.pixel_size = 1.62 / float(tex.get_height())
			fig.offset = Vector2(0.0, tex.get_height() * 0.5)
	fig.position = pos
	if pose != "stand" and fig.texture != null:
		_place_seated(fig, seat)
	fig.visible = true


func _seat_pos() -> Vector3:
	if _seat < 0:
		return STAND_POS
	var s: Vector2 = SEATS[_seat]
	return Vector3(s.x * 1.12, 1.3, s.y + 0.05)


func _say(text: String, seconds: float) -> void:
	if _say_label == null:
		return
	_say_label.text = text
	_say_t = seconds


func _play(file: String, db: float) -> void:
	if ResourceLoader.exists(SFX + file):
		_one.stream = load(SFX + file)
		_one.volume_db = db
		_one.play()


func _loop(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	return stream


## A few people already on board: sitting, facing the way the bus goes. The camp's own
## guests out for the day (gone "away") ride it too. The same people for both wardens:
## the dice are the run's (stop, day, hour).
func _seat_passengers() -> void:
	for p in _passengers:
		p.queue_free()
	_passengers.clear()
	_taken.clear()
	var day := int(CoreRoot.get_day()) if CoreRoot != null else 1
	var run := "%s|%d|%d" % [stop, day, int(floorf(_hour_now * 2.0))]
	_rng.seed = hash(run)
	_life_rng.seed = hash(run + "|life")
	var sprites := ["host1_sit.png", "host2_sit.png", "host3_sit.png", "host_family_sit.png"]
	var villagers: Array = []
	for v in VILLAGERS:
		if ResourceLoader.exists(NPC + "bus_%s_sit.png" % v["id"]) and ResourceLoader.exists(NPC + "bus_%s_back.png" % v["id"]):
			villagers.append(v)
	var riders: Array = []
	if GuestManager != null and GuestManager.has_method("get_guest_life_snapshot"):
		for g in GuestManager.get_guest_life_snapshot():
			var act: Dictionary = g.get("activity", {})
			if str(act.get("kind", "")) == "away":
				var sit := str(g.get("sprite_path", "")).replace(".png", "_sit.png")
				if ResourceLoader.exists(sit):
					riders.append(sit)
	var n := _rng.randi_range(0, 1) if _night else _rng.randi_range(1, 4)
	# The villagers, each once; the campers' sprites only if there are no villagers.
	var any_villager := not villagers.is_empty()
	for k in n + riders.size():
		var i := _rng.randi() % SEATS.size()
		if _taken.has(i) or (k >= riders.size() and any_villager and villagers.is_empty()):
			continue
		_taken[i] = true
		var path: String = str(riders[k]) if k < riders.size() else NPC + str(sprites[_rng.randi() % sprites.size()])
		var who: Dictionary = {}
		if k >= riders.size() and any_villager:
			who = villagers.pop_at(_rng.randi() % villagers.size())
			path = NPC + "bus_%s_sit.png" % who["id"]
		if not ResourceLoader.exists(path):
			continue
		var s := Sprite3D.new()
		s.texture = load(path)
		s.set_meta("seat", i)
		s.set_meta("front", s.texture)
		if not who.is_empty():
			# Facing the way the bus goes (_face_passengers), not turning after you.
			s.set_meta("back", load(NPC + "bus_%s_back.png" % who["id"]))
			s.set_meta("voice", who["voice"])
			s.set_meta("g", who["g"])
			s.set_meta("name", who["name"])
		else:
			# Drawn from the front only (the camp's guests): a back made from it.
			s.set_meta("back", _back_of(s.texture))
		s.rotation.y = PI
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.shaded = true
		s.layers = 2
		_place_seated(s, i)
		_rig.add_child(s)
		_passengers.append(s)
	_plan_life()


## The driver says `key` (talk.json's "d_*": his Czech, the English under it); a line
## with no voice yet goes by as text (`fallback`).
func _driver(key: String, fallback := "") -> void:
	var lines: Array = _talk_scenes().get(key, [])
	var en := fallback
	var path := ""
	if not lines.is_empty():
		en = str(lines[0]["en"])
		path = _talk_path(str(lines[0]["file"]))
	if en == "":
		return
	var secs := 1.4 + 0.055 * en.length()
	if path != "":
		var st: AudioStream = load(path)
		secs = st.get_length() + 0.5
		_sound_at(_driver_mouth, DRIVER_HEAD, path, -3.0)
	_say("Driver: \"%s\"" % en, secs)


# ── changing seats ───────────────────────────────────────────────────────────

## Somebody else (the other warden) sits in seat k on this bus.
func _mate_in_seat(k: int) -> bool:
	for m in _mates_info().values():
		if str((m as Dictionary).get("st", "")) == stop and int((m as Dictionary).get("s", -1)) == k:
			return true
	return false


## Up out of your seat, a few steps down the aisle and into another (the way the
## reception walks you out: WALK_PATH, the head turning with the walk). In co-op the
## others see you standing in the aisle on the way ("wz").
func _move_seat(i: int) -> void:
	if _walking or _seat < 0 or i == _seat or _taken.has(i) or _mate_in_seat(i):
		return
	var a: Vector2 = SEATS[_seat]
	var b: Vector2 = SEATS[i]
	var to := Vector3(b.x * 1.12, 1.3, b.y + 0.05)
	var face := to + Vector3(1.3 if b.x > 0.0 else -1.3, -0.1, -1.3)
	var to_rot := Transform3D(Basis(), to).looking_at(face, Vector3.UP).basis.get_euler()
	# Down the aisle facing the way you walk (the bus's front is -z).
	var yaw := 0.0 if b.y < a.y else PI
	var keys: Array = [{"pos": _cam.position, "rot": _cam.rotation},
		{"pos": Vector3(0.1, 1.6, a.y + 0.1), "rot": Vector3(-0.08, yaw if absf(b.y - a.y) > 0.3 else (-PI * 0.5 if b.x > 0.0 else PI * 0.5), 0.0)}]
	if absf(b.y - a.y) > 0.3:
		keys.append({"pos": Vector3(0.1, 1.6, b.y + 0.1), "rot": Vector3(-0.08, yaw, 0.0)})
	keys.append({"pos": to, "rot": to_rot})
	_walking = true
	_glint.clear()
	_play_steps()
	var dur := 1.1 + 0.55 * absf(b.y - a.y)
	_walk_tw = WALK_PATH.play(self, _cam, keys, dur)
	_walk_tw.tween_callback(func():
		_walking = false
		if _state == CLOSED:
			return
		_seat = i
		_cam_base = to_rot
		_look = INTERIOR_LOOK.new(120.0, 24.0, 30.0)
		_cam.rotation = to_rot
	)


func _play_steps() -> void:
	if ResourceLoader.exists(SFX_STEPS):
		_one.stream = load(SFX_STEPS)
		_one.volume_db = -12.0
		_one.play()


# ── old Vacek gets on at Pristoupim ─────────────────────────────────────────

func _vacek_ready() -> bool:
	for k in ["sit", "back", "walk"]:
		if not ResourceLoader.exists(NPC + "bus_vacek_%s.png" % k):
			return false
	return true


## The seat he takes: behind one of you, in front, or across the aisle (whichever is
## free, by the run's dice), else any free one. In co-op the leader's machine says which
## (`given`, its "bs"); -1 none.
func _boarder_seat(given := -1) -> int:
	if given >= 0 and given < SEATS.size() and not _taken.has(given):
		return given
	var players: Array = []
	if _seat >= 0:
		players.append(_seat)
	for m in _mates_info().values():
		var md: Dictionary = m
		if str(md.get("st", "")) == stop and int(md.get("s", -1)) >= 0:
			players.append(int(md["s"]))
	var near: Array = []
	for p in players:
		var pv: Vector2 = SEATS[p]
		for d in [Vector2(0, 0.9), Vector2(0, -0.9), Vector2(-pv.x * 2.0, 0)]:
			var want: Vector2 = pv + d
			for k in SEATS.size():
				if (SEATS[k] as Vector2).distance_to(want) < 0.05 and not _taken.has(k) and not players.has(k) and not near.has(k):
					near.append(k)
	if near.is_empty():
		for k in SEATS.size():
			if not _taken.has(k) and not players.has(k):
				near.append(k)
	near.sort()
	return -1 if near.is_empty() else int(near[_board_pick % near.size()])


## In at the door, his hello to the driver, up the steps and down the aisle to his seat.
func _board_start(given := -1) -> void:
	var seat := _boarder_seat(given)
	if seat < 0 or not _vacek_ready():
		_board_plan = false
		return
	var s := Sprite3D.new()
	s.name = "Vacek"
	s.texture = load(NPC + "bus_vacek_walk.png")
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = true
	s.layers = 2
	var h := float(s.texture.get_height())
	s.pixel_size = 1.66 / h
	s.offset = Vector2(0.0, h * 0.5)
	_rig.add_child(s)
	var sv: Vector2 = SEATS[seat]
	var path: Array = [Vector3(1.05, -0.38, -4.6), Vector3(0.8, -0.38, -4.45), Vector3(0.66, -0.19, -4.2),
		Vector3(0.42, 0.0, -3.85), Vector3(0.1, 0.0, -3.5), Vector3(0.1, 0.0, sv.y - 0.1), Vector3(sv.x * 0.55, 0.0, sv.y - 0.1)]
	s.position = path[0]
	_taken[seat] = true
	s.set_meta("voice", VACEK["voice"])
	s.set_meta("g", VACEK["g"])
	s.set_meta("name", VACEK["name"])
	_boarder = {"node": s, "path": path, "i": 1, "seat": seat, "phase": "walk", "t": 0.0}
	_play_steps()
	# His hello at the door, the driver's answer (they are not in _passengers yet:
	# the scene is cast by hand).
	var lines: Array = _talk_scenes().get("vb", [])
	if _talk.is_empty():
		for line in lines:
			var drv := str(line["role"]) == "driver"
			_talk.append({"at": DRIVER_HEAD if drv else Vector3(0.8, 1.2, -4.4), "file": line["file"], "en": line["en"],
				"name": "Driver" if drv else str(VACEK["name"]), "role": str(line["role"]), "who": null, "face": false})
		_talk_gap = 0.4


func _update_boarder(delta: float) -> void:
	if _boarder.is_empty() or str(_boarder.get("phase", "")) != "walk":
		return
	var s: Sprite3D = _boarder["node"]
	if not is_instance_valid(s):
		_boarder.clear()
		return
	var path: Array = _boarder["path"]
	var i := int(_boarder["i"])
	_boarder["t"] = float(_boarder["t"]) + delta
	if i >= path.size():
		_boarder_sits()
		return
	var to: Vector3 = (path[i] as Vector3) - s.position
	var step := 0.95 * delta
	if to.length() <= step:
		s.position = path[i]
		_boarder["i"] = i + 1
	else:
		s.position += to.normalized() * step
	# His walk: a bob of the steps, in steps.
	var h := float(s.texture.get_height())
	s.offset = Vector2(0.0, h * 0.5 + (2.0 if int(float(_boarder["t"]) * 4.0) % 2 == 0 else 0.0))


## Down in his seat: a passenger like the others (his front, his back, and over his
## shoulder when he turns round to you); "May I?" if he sits by one of you, his story a
## little after.
func _boarder_sits() -> void:
	var s: Sprite3D = _boarder["node"]
	var seat := int(_boarder["seat"])
	s.set_meta("seat", seat)
	s.set_meta("front", load(NPC + "bus_vacek_sit.png"))
	s.set_meta("back", load(NPC + "bus_vacek_back.png"))
	if ResourceLoader.exists(NPC + "bus_vacek_turn.png"):
		s.set_meta("turnback", load(NPC + "bus_vacek_turn.png"))
	s.texture = s.get_meta("front")
	s.rotation.y = PI
	_place_seated(s, seat)
	_passengers.append(s)
	_boarder["phase"] = "sat"
	if _talk.is_empty() and not _talk_scenes().get("vs", []).is_empty():
		_start_talk("vs")
	_events.append({"at": _ride_t + 7.0, "kind": "vacek"})
	_events.sort_custom(func(a, b): return float(a["at"]) < float(b["at"]))


func _drop_boarder() -> void:
	if not _boarder.is_empty():
		var s = _boarder.get("node")
		if s != null and is_instance_valid(s) and not _passengers.has(s):
			(s as Node).queue_free()
	_boarder.clear()


# ── co-op: one ride for everyone on the bus ─────────────────────────────────

## The machine that leads this ride: of the wardens on it, the lowest id. {} when it is
## this one (or you ride alone); else that warden's bus state.
func _leader_state() -> Dictionary:
	if not Coop.has_partner():
		return {}
	var me := multiplayer.get_unique_id()
	var best := me
	var out: Dictionary = {}
	var going := _state in [RIDING, STOPPING, DONE]
	var all := _mates_info()
	for id in all.keys():
		var m: Dictionary = all[id]
		if str(m.get("st", "")) == stop and bool(m.get("go", false)) == going and int(id) < best:
			best = int(id)
			out = m
	return out


## The leader's bus has gone while this one still holds at the stop: go with it.
func _leader_went() -> bool:
	if not Coop.has_partner() or _seat < 0:
		return false
	var me := multiplayer.get_unique_id()
	var all := _mates_info()
	for id in all.keys():
		var m: Dictionary = all[id]
		if int(id) < me and str(m.get("st", "")) == stop and bool(m.get("go", false)):
			return true
	return false


## Keep pace with the leader: the same distance along the road (eased in; a jump when far
## out) and the same clock for what happens on board, so the lines, the coughs, the
## potholes and the stop come at once on every machine.
func _follow(delta: float) -> void:
	var lead := _leader_state()
	if lead.is_empty():
		return
	if lead.has("tr"):
		var want := float(lead["tr"]) + float(lead.get("v", _speed)) * 0.08
		var d := want - _travelled
		if absf(d) > 12.0:
			_travelled = want
		else:
			_travelled += d * clampf(delta * 1.5, 0.0, 1.0)
	if lead.has("rt") and absf(float(lead["rt"]) - _ride_t) > 0.35:
		_ride_t = float(lead["rt"])


## STOP pressed on another machine on this bus: the bell, STOJIME, and it pulls in for them.
func _merge_stops() -> void:
	if not Coop.has_partner():
		return
	var going := _state in [RIDING, STOPPING, DONE]
	for m in _mates_info().values():
		var md: Dictionary = m
		if str(md.get("st", "")) != stop or bool(md.get("go", false)) != going:
			continue
		if str(md.get("sw", "")) == "you" and float(md.get("sa", -1.0)) >= 0.0 and _stop_who != "you" and _stop_who != "mate":
			if _stop_at < 0.0:
				_stop_at = float(md["sa"])
			_stop_who = "mate"
			_set_stojime(true)
			_play_two("karosa_stop_bell.mp3", -4.0)


## Someone sat in seat i: the seated sprite as tall as a sitting grown-up, its seat
## line (SIT_LINE of it up) on the cushion, a hand in front of the seat so the cushion
## does not cut the legs (playtest 18. 10.: "sitting too low", only heads over the
## seat backs; they were 1.2 m and stood in the middle of the seat, down in the cushion).
const SIT_TALL := 1.32
const SIT_LINE := 0.375
const SEAT_TOP := 0.51
const SIT_FORWARD := 0.17


func _place_seated(s: Sprite3D, i: int) -> void:
	var h := float(s.texture.get_height()) if s.texture != null else 96.0
	s.pixel_size = SIT_TALL / h
	s.offset = Vector2(0.0, h * 0.5)
	var seat: Vector2 = SEATS[i]
	s.position = Vector3(seat.x, SEAT_TOP - SIT_LINE * SIT_TALL, seat.y - SIT_FORWARD)


# ── the bus inside ───────────────────────────────────────────────────────────

func _mat(key: String, path: String, tint: Color, uv: Vector2 = Vector2.ONE) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.albedo_color = tint
	if path != "" and ResourceLoader.exists(path):
		m.albedo_texture = load(path)
		m.uv1_scale = Vector3(uv.x, uv.y, 1.0)
	_mats[key] = m
	return m


func _box(parent: Node, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _quad(parent: Node, pos: Vector3, size: Vector2, rot_y: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.position = pos
	mi.rotation.y = rot_y
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _hot_body(parent: Node, id: String, pos: Vector3, size: Vector3, meshes: Array) -> void:
	var body := StaticBody3D.new()
	body.set_meta("hot", id)
	body.collision_layer = HOT_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	parent.add_child(body)
	_hot.append({"id": id, "body": body, "meshes": meshes})


func _build() -> void:
	_container = SubViewportContainer.new()
	_container.name = "BusViewportContainer"
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.stretch = true
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)
	RETRO_RENDER.register(_container)
	_vp = SubViewport.new()
	_vp.own_world_3d = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.handle_input_locally = false
	_vp.audio_listener_enable_3d = true
	_container.add_child(_vp)
	# The cabin's frame, riding in the bus (_place_rig); everything inside it is its.
	_rig = Node3D.new()
	_rig.name = "Rig"
	_vp.add_child(_rig)
	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.near = 0.05
	_cam.far = 1000.0
	_rig.add_child(_cam)
	_cam.current = true
	_build_cabin()
	# Inside is lit by the bus as much as by the day: the cabin on layer 2 with a dim
	# fill of its own (the strip lights at night).
	for n in _rig.get_node("Cabin").find_children("*", "GeometryInstance3D", true, false):
		(n as GeometryInstance3D).layers = 2
	var fill := DirectionalLight3D.new()
	fill.name = "CabinFill"
	fill.light_cull_mask = 2
	fill.light_energy = 0.45
	fill.light_color = Color(0.92, 0.94, 1.0)
	fill.rotation = Vector3(deg_to_rad(-70.0), deg_to_rad(20.0), 0)
	_rig.add_child(fill)
	_ride = AudioStreamPlayer.new()
	add_child(_ride)
	_one = AudioStreamPlayer.new()
	add_child(_one)
	_two = AudioStreamPlayer.new()
	add_child(_two)
	_rattle = AudioStreamPlayer.new()
	add_child(_rattle)
	_wind = AudioStreamPlayer.new()
	add_child(_wind)
	_radio = AudioStreamPlayer.new()
	add_child(_radio)
	# The people on board, where they sit: quiet under the engine.
	for k in 2:
		var m := AudioStreamPlayer3D.new()
		m.unit_size = 2.5
		m.max_db = 0.0
		m.attenuation_filter_cutoff_hz = 9000.0
		_rig.add_child(m)
		if k == 0:
			_mouth = m
		else:
			_mouth2 = m
	_driver_mouth = AudioStreamPlayer3D.new()
	_driver_mouth.unit_size = 3.0
	_driver_mouth.max_db = 0.0
	_driver_mouth.position = DRIVER_HEAD
	_rig.add_child(_driver_mouth)
	# What is said (the driver), along the bottom.
	# A block in the middle, wrapped, clear of the ticket in your hand at the bottom left.
	_say_label = Label.new()
	_say_label.anchor_left = 0.5
	_say_label.anchor_right = 0.5
	_say_label.anchor_top = 1.0
	_say_label.anchor_bottom = 1.0
	_say_label.offset_left = -430.0
	_say_label.offset_right = 430.0
	_say_label.offset_top = -170.0
	_say_label.offset_bottom = -70.0
	_say_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_say_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_say_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_say_label.add_theme_font_override("font", RETRO_UI.FONT_TEXT)
	_say_label.add_theme_font_size_override("font_size", 24)
	_say_label.add_theme_color_override("font_color", RETRO_UI.C_BONE)
	_say_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_say_label.add_theme_constant_override("shadow_offset_x", 2)
	_say_label.add_theme_constant_override("shadow_offset_y", 2)
	_say_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_say_label)
	# The ticket in your hand, bottom left, once you have one.
	_ticket_card = Control.new()
	_ticket_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ticket_card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_ticket_card.size = Vector2(150, 70)
	_ticket_card.position = Vector2(40, -120)
	_ticket_card.rotation = deg_to_rad(-7.0)
	_ticket_card.visible = false
	_ticket_card.draw.connect(_draw_ticket_card)
	add_child(_ticket_card)


func _draw_ticket_card() -> void:
	var c := _ticket_card
	c.draw_rect(Rect2(4, 6, 140, 60), Color(0, 0, 0, 0.35))
	c.draw_rect(Rect2(0, 0, 140, 60), Color(0.9, 0.88, 0.8))
	c.draw_rect(Rect2(0, 0, 140, 3), Color(0.72, 0.7, 0.62))
	var f: Font = RETRO_UI.FONT_TEXT
	var ink := Color(0.2, 0.2, 0.5)
	c.draw_string(f, Vector2(8, 18), "ČSAD  380", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
	c.draw_string(f, Vector2(8, 36), "JÍZDENKA  NEPŘESTUPNÍ", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
	if bool(_ticket.get("punched", false)):
		# The punch's holes and the time it printed.
		for hole in [Vector2(112, 12), Vector2(122, 12), Vector2(132, 12), Vector2(117, 22), Vector2(127, 22)]:
			c.draw_rect(Rect2(hole, Vector2(4, 4)), Color(0.12, 0.1, 0.08))
		c.draw_string(f, Vector2(8, 52), str(_ticket.get("at", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 0.12, 0.1))


func _build_cabin() -> void:
	var cabin := Node3D.new()
	cabin.name = "Cabin"
	_rig.add_child(cabin)
	var wall := _mat("wall", TEX + "bus_wall.png", Color(0.86, 0.82, 0.7), Vector2(4.0, 1.0))
	var pillar := _mat("pillar", "", Color(0.78, 0.74, 0.62))
	var chrome := _mat("chrome", "", Color(0.72, 0.74, 0.76))
	var floor_m := _mat("floor", TEX + "bus_floor.png", Color(0.5, 0.5, 0.5), Vector2(2.0, 8.0))
	var length := FLOOR_Z.y - FLOOR_Z.x
	var mid := (FLOOR_Z.x + FLOOR_Z.y) * 0.5
	# The floor, with the stairwell at the front door: the treads down to the door's sill.
	var inner := HALF_W - 0.03
	var step_x: float = (STEPS[1] as Vector2).y
	_box(cabin, Vector3((-HALF_W + step_x) * 0.5, -0.04, mid), Vector3(HALF_W + step_x, 0.08, length), floor_m)
	for zr in [Vector2(FLOOR_Z.x, DOOR_Z.x - 0.03), Vector2(DOOR_Z.y + 0.03, FLOOR_Z.y)]:
		_box(cabin, Vector3((step_x + HALF_W) * 0.5, -0.04, (zr.x + zr.y) * 0.5), Vector3(HALF_W - step_x, 0.08, zr.y - zr.x), floor_m)
	var dz := (DOOR_Z.x + DOOR_Z.y) * 0.5
	var dw := DOOR_Z.y - DOOR_Z.x + 0.06
	var tread := _mat("tread", "", Color(0.2, 0.2, 0.19))
	var nosing := _mat("nosing", "", Color(0.7, 0.58, 0.2))
	var s1: Vector2 = STEPS[0]
	var s2: Vector2 = STEPS[1]
	_box(cabin, Vector3((s1.y + inner) * 0.5, (s1.x - 0.5) * 0.5, dz), Vector3(inner - s1.y, s1.x + 0.5, dw), tread)
	_box(cabin, Vector3((s2.y + s1.y) * 0.5, (s2.x - 0.5) * 0.5, dz), Vector3(s1.y - s2.y, s2.x + 0.5, dw), tread)
	for n in [[inner - 0.02, s1.x], [s1.y - 0.02, s2.x], [s2.y - 0.02, 0.0]]:
		_box(cabin, Vector3(n[0], float(n[1]) + 0.006, dz), Vector3(0.04, 0.012, dw - 0.06), nosing)
	_box(cabin, Vector3(0, 2.14, mid), Vector3(HALF_W * 2.0, 0.08, length), _mat("ceiling", TEX + "bus_ceiling.png", Color(0.9, 0.88, 0.8), Vector2(2.0, 8.0)))
	# The strip lights along the ceiling.
	_strip_mat = StandardMaterial3D.new()
	_strip_mat.albedo_color = Color(0.95, 0.92, 0.8)
	_strip_mat.emission_enabled = true
	for x in [-0.5, 0.5]:
		_box(cabin, Vector3(x, 2.08, mid), Vector3(0.12, 0.04, length - 1.0), _strip_mat)
	for z in [-3.6, 0.5, 3.6]:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.9, 0.72)
		l.light_energy = 1.1
		l.omni_range = 4.5
		l.position = Vector3(0, 1.9, z)
		l.visible = false
		cabin.add_child(l)
		_strip_lights.append(l)
	# The sides: a panel under the windows, pillars, a strip above; the windows open. On
	# the door side round the front door (its leaves are the bus's own, bus_model.gd:
	# one door, seen from both sides) and the shut back door.
	for side in [-1.0, 1.0]:
		var x: float = side * HALF_W
		var spans: Array = [Vector2(FLOOR_Z.x, FLOOR_Z.y)]
		if side > 0.0:
			spans = [Vector2(FLOOR_Z.x, DOOR_Z.x - 0.03), Vector2(DOOR_Z.y + 0.03, BACK_DOOR_Z.x), Vector2(BACK_DOOR_Z.y, FLOOR_Z.y)]
		for sp in spans:
			var span: Vector2 = sp
			var sl := span.y - span.x
			var sm := (span.x + span.y) * 0.5
			_box(cabin, Vector3(x, 0.42, sm), Vector3(0.06, 0.84, sl), wall)
			_quad(cabin, Vector3(x - side * 0.01, 1.35, sm), Vector2(sl, 1.02), side * PI * 0.5, _glass_material())
		_box(cabin, Vector3(x, 2.0, mid), Vector3(0.06, 0.28, length), wall)
		var z := FLOOR_Z.x + 0.32
		while z < FLOOR_Z.y:
			if side < 0.0 or (z < DOOR_Z.x - 0.05 or z > DOOR_Z.y + 0.05):
				_box(cabin, Vector3(x, 1.35, z), Vector3(0.07, 1.02, 0.09), pillar)
			z += 1.13
	# The back door from inside: its two leaves shut, glass over the yellow.
	var panel_t := _town_tex("karosa_door_panel")
	if panel_t != null:
		var pm := _tex_mat(panel_t, true)
		var bw := (BACK_DOOR_Z.y - BACK_DOOR_Z.x) * 0.5
		for k in 2:
			_quad(cabin, Vector3(HALF_W - 0.01, 0.92, BACK_DOOR_Z.x + bw * (k + 0.5)), Vector2(bw, 2.24), -PI * 0.5, pm)
		_quad(cabin, Vector3(HALF_W - 0.005, 1.32, (BACK_DOOR_Z.x + BACK_DOOR_Z.y) * 0.5), Vector2(BACK_DOOR_Z.y - BACK_DOOR_Z.x, 1.5), -PI * 0.5, _glass_material())
	# The front door: clicking it gets you off (the leaves are the bus's).
	_hot_body(cabin, "door", Vector3(HALF_W - 0.1, 1.0, dz), Vector3(0.4, 2.0, DOOR_Z.y - DOOR_Z.x), [])
	# The rear: a wall with a small window and the long bench.
	_box(cabin, Vector3(0, 0.6, FLOOR_Z.y), Vector3(HALF_W * 2.0, 1.2, 0.06), wall)
	_box(cabin, Vector3(0, 1.85, FLOOR_Z.y), Vector3(HALF_W * 2.0, 0.6, 0.06), wall)
	for x in [-0.9, 0.9]:
		_box(cabin, Vector3(x, 1.35, FLOOR_Z.y), Vector3(0.5, 0.5, 0.06), wall)
	# The front under the windscreen (the bus's glass is in it); the driver's place.
	_box(cabin, Vector3(0, 0.3, FLOOR_Z.x), Vector3(HALF_W * 2.0, 0.6, 0.08), _mat("front", "", Color(0.3, 0.3, 0.3)))
	var cab: Dictionary = KAROSA_CAB.build(cabin, 0.0, _mats)
	# Seats: a cushion, the back with its cloth and its cover, a chrome grip.
	var cloth := _mat("seat_cloth", TEX + "karosa_seat_cloth.png", Color(1, 1, 1), Vector2(4.0, 2.0))
	var edge := _mat("seat_edge", "", Color(0.36, 0.24, 0.16))
	var back_t := _town_tex("karosa_seat_back")
	for i in SEATS.size():
		var sv: Vector2 = SEATS[i]
		var seat := Node3D.new()
		seat.position = Vector3(sv.x, 0, sv.y)
		cabin.add_child(seat)
		var parts: Array = []
		parts.append(_box(seat, Vector3(0, 0.46, 0), Vector3(0.84, 0.1, 0.44), cloth))
		parts.append(_box(seat, Vector3(0, 0.78, 0.22), Vector3(0.84, 0.6, 0.06), edge))
		parts.append(_quad(seat, Vector3(0, 0.78, 0.262), Vector2(0.84, 0.62), 0.0, _tex_mat(back_t, true) if back_t != null else cloth))
		parts.append(_quad(seat, Vector3(0, 0.78, 0.178), Vector2(0.78, 0.56), PI, cloth))
		_box(seat, Vector3(0, 1.1, 0.22), Vector3(0.7, 0.035, 0.035), chrome)
		_box(seat, Vector3(-sv.x * 0.45, 0.2, 0), Vector3(0.06, 0.4, 0.06), chrome)
		_hot_body(seat, "seat:%d" % i, Vector3(0, 0.7, 0.05), Vector3(0.84, 0.8, 0.5), parts)
	# Poles (the first at the top of the steps), and the punch box on that one.
	for p in POLES:
		var pv: Vector2 = p
		var pole := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.025
		cyl.bottom_radius = 0.025
		cyl.height = 2.1
		cyl.radial_segments = 6
		pole.mesh = cyl
		pole.material_override = _mat("pole_yellow", "", Color(0.82, 0.64, 0.16)) if pv == POLES[0] else chrome
		pole.position = Vector3(pv.x, 1.05, pv.y)
		cabin.add_child(pole)
	# The orange punch box (označovač) clamped to the first pole, its slot to the door.
	var pp: Vector2 = POLES[0]
	var punch := Node3D.new()
	punch.position = Vector3(pp.x, 0.77, pp.y - 0.04)
	cabin.add_child(punch)
	var shell := _box(punch, Vector3(0.0, 0, 0), Vector3(0.1, 0.3, 0.13), _mat("punch_body", "", Color(0.86, 0.44, 0.1)))
	var face_tex := _town_tex("validator")
	var face := _quad(punch, Vector3(0.051, 0, 0), Vector2(0.15, 0.32), PI * 0.5, _tex_mat(face_tex, true) if face_tex != null else _mat("punch_face", "", Color(0.12, 0.12, 0.12)))
	_hot_body(punch, "punch", Vector3.ZERO, Vector3(0.24, 0.4, 0.3), [shell, face])
	# The driver in his seat (karosa_cab.gd's): Grok's man without a seat, from behind.
	var driver := Node3D.new()
	driver.position = Vector3(KAROSA_CAB.SEAT.x, 0, KAROSA_CAB.SEAT.y)
	cabin.add_child(driver)
	var parts_d: Array = (cab["parts"] as Array).duplicate()
	var drv := _town_tex("bus_driver_seated")
	if drv != null:
		var fig := Sprite3D.new()
		fig.name = "DriverBack"
		fig.texture = drv
		fig.pixel_size = 0.96 / float(drv.get_height())
		fig.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		fig.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		fig.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		fig.shaded = true
		fig.offset = Vector2(_body_middle(drv), 0)
		fig.position = Vector3(0, KAROSA_CAB.SEAT_TOP + 0.46, -0.04)
		driver.add_child(fig)
	_hot_body(driver, "driver", Vector3(0, 1.0, 0), Vector3(0.6, 1.0, 0.6), parts_d)
	_dress_cabin(cabin, driver, parts_d)


## The x offset that puts a seated sprite's body (not its outstretched arms) over its
## seat: the middle of the opaque columns in its lowest fifth.
func _body_middle(t: Texture2D) -> float:
	var img := t.get_image()
	if img == null:
		return 0.0
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var lo := w
	var hi := 0
	for y in range(int(h * 0.8), h):
		for x in w:
			if img.get_pixel(x, y).a > 0.5:
				lo = mini(lo, x)
				hi = maxi(hi, x)
	return w * 0.5 - (lo + hi) * 0.5 if hi > lo else 0.0


## The Karosa as it was on the 380 (playtest 17. 10.: "polish the inside of the bus"):
## the dashboard with its dials, the driver from behind at his wheel (a Grok sprite in
## place of the boxes), the doors' glass leaves, short pleated curtains at the windows
## and a little bear and a pine tree swinging under the mirror (both swing with the
## bus), luggage nets, red STOP buttons on the poles, no-smoking stickers, sunflower
## shells and old tickets on the floor.
func _dress_cabin(cabin: Node3D, driver: Node3D, driver_parts: Array) -> void:
	# Curtains bunched at the pillars, both sides.
	var cur := _town_tex("bus_curtain")
	if cur != null:
		var cm := _tex_mat(cur, false)
		cm.uv1_scale = Vector3(1.0, 1.0, 1.0)
		for side in [-1.0, 1.0]:
			var z := FLOOR_Z.x + 0.2
			while z < FLOOR_Z.y:
				if side < 0.0 or z < DOOR_Z.x - 0.3 or z > DOOR_Z.y + 0.3:
					var pivot := Node3D.new()
					pivot.position = Vector3(side * (HALF_W - 0.06), 1.74, z + 0.13)
					cabin.add_child(pivot)
					var c := _quad(pivot, Vector3(0, -0.3, 0), Vector2(0.2, 0.6), side * PI * 0.5, cm)
					c.name = "Curtain"
					_swingers.append({"node": pivot, "k": 0.35})
				z += 1.18
	# The bear and the tree under the mirror.
	var mascot := _town_tex("bus_mascot")
	if mascot != null:
		var pivot := Node3D.new()
		pivot.position = Vector3(-0.15, 1.92, FLOOR_Z.x + 0.32)
		cabin.add_child(pivot)
		_box(pivot, Vector3(0, -0.06, 0), Vector3(0.005, 0.12, 0.005), _mat("string", "", Color(0.2, 0.2, 0.2)))
		var m := _quad(pivot, Vector3(0, -0.24, 0), Vector2(0.2 * float(mascot.get_width()) / float(mascot.get_height()), 0.2), 0.0, _tex_mat(mascot, true))
		m.name = "Mascot"
		_swingers.append({"node": pivot, "k": 1.0})
	# Luggage nets over the seats.
	var rack := _town_tex("bus_rack")
	if rack != null:
		for side in [-1.0, 1.0]:
			var rq := _quad(cabin, Vector3(side * (HALF_W - 0.2), 1.86, (FLOOR_Z.x + FLOOR_Z.y) * 0.5 + 0.8), Vector2(7.6, 0.36), side * PI * 0.5, _tex_mat(rack, true))
			# A shelf along the wall, a little higher at the wall (tilted about its long
			# axis; turned in its own plane it was a long stripe slanting across the bus).
			rq.rotation.x = deg_to_rad(75.0)
			rq.name = "LuggageNet"
	# STOP buttons on the poles, the stickers.
	var red := _mat("stop_btn", "", Color(0.85, 0.12, 0.1))
	red.emission_enabled = true
	red.emission = Color(0.6, 0.05, 0.03)
	for k in 3:
		var z: float = (POLES[k] as Vector2).y
		var px: float = (POLES[k] as Vector2).x
		var btn := _box(cabin, Vector3(px, 1.42, z + 0.03), Vector3(0.07, 0.05, 0.07), red)
		_hot_body(cabin, "stop:%d" % k, Vector3(px, 1.42, z + 0.03), Vector3(0.22, 0.2, 0.22), [btn])
	# STOJIME over the driver: lit red once somebody has pressed STOP.
	var sj := _town_tex("sign_stojime")
	if sj != null:
		_stojime = _tex_mat(sj, true)
		_stojime.emission_enabled = true
		_stojime.emission = Color(0, 0, 0)
		_stojime.emission_texture = sj
		_stojime.emission_energy_multiplier = 0.0
		_box(cabin, Vector3(-0.35, 2.02, FLOOR_Z.x + 0.1), Vector3(0.62, 0.2, 0.06), _mat("stojime_box", "", Color(0.08, 0.08, 0.08)))
		_quad(cabin, Vector3(-0.35, 2.02, FLOOR_Z.x + 0.135), Vector2(sj.get_width(), sj.get_height()) / 120.0, 0.0, _stojime)
	var ns := _town_tex("no_smoking")
	if ns != null:
		_quad(cabin, Vector3(0.6, 1.98, FLOOR_Z.x + 0.12), Vector2(0.16, 0.16), 0.0, _tex_mat(ns, true))
		_quad(cabin, Vector3(0.0, 1.95, FLOOR_Z.y - 0.04), Vector2(0.16, 0.16), PI, _tex_mat(ns, true))
	var lit := _town_tex("bus_litter")
	if lit != null:
		for z in [-1.2, 1.5, 3.3]:
			var dq := _quad(cabin, Vector3(randf_range(-0.2, 0.25), 0.006, z), Vector2(0.45, 0.45), 0.0, _tex_mat(lit, true))
			dq.rotation.x = -PI * 0.5
			dq.rotation.z = randf() * TAU


func _town_tex(name: String) -> Texture2D:
	var p := TEX + name + ".png"
	return load(p) if ResourceLoader.exists(p) else null


func _tex_mat(t: Texture2D, cut: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = t
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	if cut:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Speeding up throws what hangs back, braking forward; it settles. Drawn in steps.
func _update_swing(delta: float) -> void:
	if _swingers.is_empty() or delta <= 0.0:
		return
	var accel := (_speed - _speed_prev) / delta
	_speed_prev = _speed
	_swing_v += (-_swing * 14.0 - _swing_v * 1.4 + accel * 0.05) * delta
	_swing += _swing_v * delta
	_swing_acc += delta
	if _swing_acc < 1.0 / 12.0:
		return
	_swing_acc = 0.0
	var wob := sin(Time.get_ticks_msec() * 0.004) * 0.02 * clampf(_speed / CRUISE, 0.0, 1.0)
	for sw in _swingers:
		var n: Node3D = sw["node"]
		if is_instance_valid(n):
			n.rotation.x = clampf((_swing + wob) * float(sw["k"]), -0.6, 0.6)


func _set_door(open: bool, at_once := false) -> void:
	_door_want = 1.0 if open else 0.0
	# The bus outside does the same (its own sound is the one inside).
	if ride_bus != null and is_instance_valid(ride_bus):
		ride_bus.open_door(open, true)
	if at_once:
		_door_k = _door_want
		_fold_door()


## The door is the bus's (bus_model.gd folds its leaves); the cabin lights them up under
## the mouse.
func _fold_door() -> void:
	if ride_bus == null or not is_instance_valid(ride_bus) or not ride_bus.has_method("door_meshes"):
		return
	for h in _hot:
		if str(h["id"]) == "door" and (h["meshes"] as Array).is_empty():
			h["meshes"] = ride_bus.door_meshes()
