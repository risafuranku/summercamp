extends Node

## The title screen's camera: a director cutting between slow, steady shots of the camp,
## each in its own light and weather. Out along the jetty past the rowing boat in the
## morning mist or a red sunset, the keeper's boathouse across the water, the camp seen
## back from his jetty, the corn and its pylons in a windy golden evening or a drizzle,
## the office in the low sun or the rain, the gate's bulb on a foggy night, the camp from
## above, and the campfire and the cabins once they are built. Between shots the picture
## dips to black and the next light is set in the dark.
##
## Shots are planned from what is really in the camp (rebuild(): the lake, the corn
## field, the gate, the buildings) and moved aside until no tree spoils them; one that
## cannot be framed is left out. The camera runs on rails like a dolly or a crane: no
## bob, no bank, eased only at the ends. The subject sits right of centre, clear of the
## menu on the left. Time and weather go through main's systems and the sky is snapped
## while the screen is black; Continue reloads the save, so none of it reaches the game.

const WEATHER := preload("res://core/systems/weather_system.gd")

## How long a shot runs, and the dip to black between shots.
const SHOT_SECONDS := 11.0
const FADE_OUT := 0.7
const BLACK_HOLD := 0.45
const FADE_IN := 1.0
## Turns the camera left of its subject so the subject sits right of centre.
const FRAME_YAW_DEG := 19.0
const FOV := 50.0
## Trees closer than this to the camera, or to the line of sight, spoil a shot. The
## spruces of the forest round the camp (world_generator._spawn_horizon) are bigger.
const TREE_CLEAR := 1.6
const SIGHT_CLEAR := 1.1
const FOREST_CLEAR := 3.6
const FOREST_SIGHT_CLEAR := 2.2

## [hours, weather] looks; each shot has two and alternates between them every round.
## Hours are for the autumn of the campaign: golden light ~17, red sky ~18.2, lamps on
## at 19:30, dark from ~20.
const MIST := [7.2, WEATHER.WEATHER_FOG]
const MORNING := [8.4, WEATHER.WEATHER_CLEAR]
const DRIZZLE := [14.2, WEATHER.WEATHER_LIGHT_RAIN]
const RAIN := [15.4, WEATHER.WEATHER_RAIN]
const AFTERNOON := [16.2, WEATHER.WEATHER_CLEAR]
const GOLDEN_WIND := [17.2, WEATHER.WEATHER_WINDY]
const GOLDEN := [17.6, WEATHER.WEATHER_CLEAR]
const SUNSET := [18.2, WEATHER.WEATHER_CLEAR]
const DUSK := [18.8, WEATHER.WEATHER_CLEAR]
const BLUE_FOG := [19.9, WEATHER.WEATHER_FOG]
const DUSK_RAIN := [19.3, WEATHER.WEATHER_RAIN]
const NIGHT := [21.0, WEATHER.WEATHER_CLEAR]

var fallback_camera: Camera3D
var grid_manager: Node3D
var building_manager: Node3D

var _shots: Array[Dictionary] = []
var _index := -1
var _round := 0
var _t := 0.0
## 0 fading in / running, 1 fading out, 2 black (the next shot is being set).
var _phase := 2
var _phase_t := 0.0
var _snap_frames := 0
var _fade: ColorRect
var _fade_layer: CanvasLayer


func setup(camera: Camera3D, grid: Node3D, buildings: Node3D) -> void:
	fallback_camera = camera
	grid_manager = grid
	building_manager = buildings


func _ready() -> void:
	# Under the menu (layer 120), over the world.
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 110
	add_child(_fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade)
	_fade_layer.visible = false


const STEP_FPS := 16.0
var _step_acc := 0.0


func _process(_delta: float) -> void:
	# The dip to black belongs to the title screen only: the moment the game takes the
	# camera, it goes.
	if _fade_layer != null and _fade_layer.visible and not bool(get_parent().get("_menu_mode")):
		_fade_layer.visible = false


## One frame of the title screen (main calls it only in menu mode).
func update(delta: float) -> void:
	if fallback_camera == null or grid_manager == null:
		return
	fallback_camera.current = true
	_fade_layer.visible = true
	if _shots.is_empty():
		_static_view()
		_fade.color.a = 0.0
		return
	if _snap_frames > 0:
		_snap_frames -= 1
		if _snap_frames == 0:
			var visuals = get_parent().get("_weather_visuals")
			if visuals != null and visuals.has_method("apply_time_from_clock"):
				visuals.apply_time_from_clock(true)
	_phase_t += maxf(delta, 0.0)
	# The camera and the fades move sixteen times a second, the fades through eight shades
	# (the Build palette's fade tables), not smoothly (playtest 18. 10.).
	_step_acc += delta
	var stepped := _step_acc >= 1.0 / STEP_FPS
	if stepped:
		_step_acc = 0.0
	match _phase:
		2:
			_fade.color.a = 1.0
			if _phase_t >= BLACK_HOLD:
				_phase = 0
				_phase_t = 0.0
		0:
			_t += delta
			_fade.color.a = 1.0 - clampf(_phase_t / FADE_IN, 0.0, 1.0)
			if _t >= float(_shots[_index].seconds) - FADE_OUT:
				_phase = 1
				_phase_t = 0.0
		1:
			_t += delta
			_fade.color.a = clampf(_phase_t / FADE_OUT, 0.0, 1.0)
			if _phase_t >= FADE_OUT:
				_next_shot()
	_fade.color.a = roundf(_fade.color.a * 8.0) / 8.0
	if _index >= 0 and stepped:
		_place_camera(_shots[_index], clampf(_t / float(_shots[_index].seconds), 0.0, 1.0))


## Re-plans the shots (the preview camp changed) and starts again from black.
func rebuild() -> void:
	_shots.clear()
	if grid_manager == null:
		return
	var w := _World.new(self)
	# Light and dark take turns: misty jetty, golden corn, the gate at blue hour, the
	# office in the sun, the far shore, the camp from above, back across the water...
	for build in [_shot_lake, _shot_corn, _shot_gate, _shot_reception, _shot_far_shore, _shot_crane, _shot_across, _shot_campfire, _shot_housing]:
		var shot: Dictionary = build.call(w)
		if shot.is_empty():
			continue
		shot = _clear_variant(shot, w)
		if not shot.is_empty():
			_shots.append(shot)
	_index = -1
	_round = 0
	_next_shot()
	if _fade != null:
		_fade.color.a = 1.0


func _next_shot() -> void:
	if _shots.is_empty():
		return
	_index += 1
	if _index >= _shots.size():
		_index = 0
		_round += 1
	_t = 0.0
	_phase = 2
	_phase_t = 0.0
	var look: Array = _shots[_index].looks[_round % 2]
	_set_light(float(look[0]), int(look[1]))
	_place_camera(_shots[_index], 0.0)


## The light for the next shot, set while the screen is black.
func _set_light(hours: float, weather: int) -> void:
	var main := get_parent()
	var time_system = main.get("time_system")
	var weather_system = main.get("weather_system")
	if time_system != null:
		time_system.set_time_hours(hours)
	if weather_system != null:
		weather_system.set_auto_cycle_enabled(false)
		weather_system.set_weather(weather)
	# main picks the new clock and weather up next frame and would crossfade the weather
	# over 40 s; snap it a frame after that.
	_snap_frames = 2


func _place_camera(shot: Dictionary, k: float) -> void:
	# A dolly: even speed, eased only at the ends.
	var s := lerpf(k, smoothstep(0.0, 1.0, k), 0.55)
	var pos: Vector3 = (shot.from as Vector3).lerp(shot.to, s)
	var look: Vector3 = (shot.look_from as Vector3).lerp(shot.look_to, s)
	fallback_camera.fov = float(shot.get("fov", FOV))
	fallback_camera.global_position = pos
	if pos.distance_squared_to(look) > 0.01:
		fallback_camera.look_at(look, Vector3.UP)
		fallback_camera.global_rotate(Vector3.UP, deg_to_rad(float(shot.get("yaw", FRAME_YAW_DEG))))


func _static_view() -> void:
	var center: Vector3 = grid_manager.get_map_center_world()
	fallback_camera.fov = FOV
	fallback_camera.global_position = center + Vector3(0.0, 3.3, -12.0)
	fallback_camera.look_at(center + Vector3(0.0, 2.8, 0.0), Vector3.UP)


# ── the shots ─────────────────────────────────────────────────────────────────
# Each returns {from, to, look_from, look_to, looks: [two looks], seconds, fov?, yaw?,
# keep_clear_of?} or {} when its subject is not in this camp.

func _shot(from: Vector3, to: Vector3, look_from: Vector3, look_to: Vector3, a: Array, b: Array, extra: Dictionary = {}) -> Dictionary:
	var shot := {"from": from, "to": to, "look_from": look_from, "look_to": look_to, "looks": [a, b], "seconds": SHOT_SECONDS}
	shot.merge(extra, true)
	return shot


## The camp from above: a crane drifting in over the road towards the office.
func _shot_crane(w: _World) -> Dictionary:
	var c := w.center
	var south := c.z - w.size.y * 0.5
	var subject := (w.reception.global_position if w.reception != null else c) + Vector3(0.0, 1.5, 6.0)
	return _shot(Vector3(c.x - 30.0, 19.0, south - 18.0), Vector3(c.x - 22.0, 15.5, south - 11.0),
		subject, subject + Vector3(1.0, 0.0, 4.0), AFTERNOON, GOLDEN,
		{"fov": 56.0, "yaw": 14.0, "high": true})


## Walking out on the jetty, the rowing boat tied up beside it, the lake opening beyond
## (camp_lake.gd: the boat lies 1.6 m off the jetty, halfway along it; no reeds there).
func _shot_lake(w: _World) -> Dictionary:
	if w.lake == null or w.boat == null:
		return {}
	# Where the boat is tied up (in a saved camp it may be across the lake).
	var b: Vector3 = (w.lake.boat_home as Transform3D).origin
	var jetty_x := b.x - 1.6
	var shore_z := b.z - 5.0
	return _shot(Vector3(jetty_x - 0.2, 1.7, shore_z - 3.5), Vector3(jetty_x - 0.2, 1.65, shore_z - 0.5),
		b + Vector3(0.0, 0.4, 0.0), b + Vector3(0.0, 0.4, 0.6), MIST, SUNSET)


## From the keeper's jetty back across the water at the camp: its jetty, the boat, the
## trees behind.
func _shot_across(w: _World) -> Dictionary:
	if w.lake == null or w.lake.far_view == Vector3.ZERO:
		return {}
	var start: Vector3 = w.lake.far_view
	var b: Vector3 = (w.lake.boat_home as Transform3D).origin
	var dir := Vector3(b.x - start.x, 0.0, b.z - start.z).normalized()
	var side := dir.cross(Vector3.UP)
	return _shot(start - side * 1.5, start + side * 1.5, b + Vector3(0.0, 2.0, -6.0), b + Vector3(0.0, 2.0, -6.0),
		SUNSET, MORNING, {"fov": 46.0, "yaw": 16.0})


## Across the water at Mr Hruby's boathouse, from the end of the camp's jetty.
func _shot_far_shore(w: _World) -> Dictionary:
	if w.lake == null or w.lake.far_jetty_end == Vector3.ZERO:
		return {}
	var b: Vector3 = (w.lake.boat_home as Transform3D).origin
	var target: Vector3 = w.lake.hut_window.global_position if w.lake.hut_window != null else w.lake.far_jetty_end
	var start := Vector3(b.x - 1.6, 1.0, b.z + 6.5)
	var dir := (target - start)
	dir.y = 0.0
	dir = dir.normalized()
	return _shot(start, start + dir * 2.2, target + Vector3(0.0, 0.3, 0.0), target + Vector3(0.0, 0.3, 0.0),
		MIST, GOLDEN, {"fov": 44.0})


## Over the corn in the camp and the west fence: the field, the scarecrow, the pylons.
func _shot_corn(w: _World) -> Dictionary:
	if w.corn_field == null or w.corn_field.scarecrow == null:
		return {}
	var s: Vector3 = w.corn_field.scarecrow.global_position
	var fx: float = w.corn_field.fence_x
	return _shot(Vector3(fx + 12.0, 7.0, s.z - 12.0), Vector3(fx + 12.0, 7.4, s.z - 6.0),
		s + Vector3(0.0, 2.0, 0.0), s + Vector3(0.0, 2.0, 2.0), GOLDEN_WIND, DRIZZLE,
		{"high": true})


## The office from its path, pushing in slowly as its lamps come on.
func _shot_reception(w: _World) -> Dictionary:
	if w.reception == null:
		return {}
	var r := w.reception.global_position
	return _shot(r + Vector3(10.0, 1.75, 14.0), r + Vector3(7.0, 1.75, 11.5),
		r + Vector3(0.5, 1.6, 0.0), r + Vector3(0.0, 1.6, 0.0), GOLDEN, RAIN)


## A slow turn round the campfire, low (only once one is built).
func _shot_campfire(w: _World) -> Dictionary:
	if w.campfire == null:
		return {}
	var f := w.campfire.global_position
	return _shot(f + Vector3(-5.5, 1.0, -2.5), f + Vector3(-4.5, 1.1, 3.5),
		f + Vector3(0.0, 0.7, 0.0), f + Vector3(0.0, 0.7, 0.0), NIGHT, DUSK,
		{"yaw": 15.0})


## The barrier from the road outside: the gatehouse bulb in the fog.
func _shot_gate(w: _World) -> Dictionary:
	if w.gate == null:
		return {}
	var g := Vector3(float(w.gate.gap_center_x), 0.0, float(w.gate.fence_z))
	return _shot(g + Vector3(-0.5, 1.6, -13.0), g + Vector3(0.0, 1.55, -9.0),
		g + Vector3(1.5, 1.3, 2.0), g + Vector3(1.5, 1.3, 3.0), BLUE_FOG, DUSK_RAIN)


## A dolly along the cabins and tents (only once there are some).
func _shot_housing(w: _World) -> Dictionary:
	if w.housing.size() < 2:
		return {}
	var a: Vector3 = w.housing[0]
	var b: Vector3 = w.housing[1]
	var along := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	var out := along.cross(Vector3.UP)
	if out.dot(w.center - a) > 0.0:
		out = -out
	var mid := (a + b) * 0.5
	return _shot(a + out * 9.0 - along * 4.0 + Vector3(0.0, 1.7, 0.0), b + out * 9.0 + along * 1.0 + Vector3(0.0, 1.7, 0.0),
		a + Vector3(0.0, 1.4, 0.0), mid + Vector3(0.0, 1.4, 0.0), MORNING, RAIN)


## The shot as planned, or moved a few metres (back along the view first, so a camera
## on the jetty stays in line with it, then aside) until no tree spoils it; {} if
## nothing nearby works. The trees are random, so every camp needs its own.
const NUDGES := [
	Vector2(0.0, 0.0), Vector2(0.0, -3.0), Vector2(0.0, 1.5), Vector2(2.5, 0.0), Vector2(-2.5, 0.0),
	Vector2(0.0, -6.0), Vector2(5.0, 0.0), Vector2(-5.0, 0.0),
	Vector2(5.0, -4.0), Vector2(-5.0, -4.0), Vector2(8.0, 0.0), Vector2(-8.0, 0.0),
]


func _clear_variant(shot: Dictionary, w: _World) -> Dictionary:
	var view := (shot.look_from as Vector3) - (shot.from as Vector3)
	view.y = 0.0
	view = view.normalized()
	var side := view.cross(Vector3.UP)
	for nudge: Vector2 in NUDGES:
		var offset: Vector3 = side * nudge.x + view * nudge.y
		var moved := shot.duplicate()
		moved.from = (shot.from as Vector3) + offset
		moved.to = (shot.to as Vector3) + offset
		if _framed(moved, w):
			return moved
	return {}


## Nothing in the way: no tree on the camera or in the line of sight, at the start, the
## middle and the end of the move.
func _framed(shot: Dictionary, w: _World) -> bool:
	var high := bool(shot.get("high", false))
	for k in [0.0, 0.5, 1.0]:
		var cam: Vector3 = (shot.from as Vector3).lerp(shot.to, k)
		var look: Vector3 = (shot.look_from as Vector3).lerp(shot.look_to, k)
		for t in w.trees:
			var flat := Vector2(t.x - cam.x, t.z - cam.z).length()
			if not high and flat < TREE_CLEAR:
				return false
			# Trees stand ~6 m: a high camera looks over the near ones.
			if _sight_blocked(cam, look, t, high, SIGHT_CLEAR):
				return false
		for t in w.forest:
			if Vector2(t.x - cam.x, t.z - cam.z).length() < FOREST_CLEAR and cam.y < 14.0:
				return false
			if _sight_blocked(cam, look, t, high, FOREST_SIGHT_CLEAR):
				return false
	return true


func _sight_blocked(cam: Vector3, look: Vector3, tree: Vector3, high: bool, clear: float) -> bool:
	var a := Vector2(cam.x, cam.z)
	var b := Vector2(look.x, look.z)
	var p := Vector2(tree.x, tree.z)
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 0.01:
		return false
	var u := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	# The last few metres are the subject itself; from up high, the camp round it is.
	if u * sqrt(len2) > sqrt(len2) - 3.0 or (high and u > 0.6):
		return false
	if p.distance_to(a + ab * u) > clear:
		return false
	if high:
		var y := lerpf(cam.y, look.y, u)
		return y < 6.5
	return true


## What a shot can be pointed at, found in the camp as it is now. Nodes are found by
## script and group, not by name: a regenerated camp gets names like CampLake2.
class _World:
	var center: Vector3
	var size: Vector2
	var lake: Node3D
	var boat: Node3D
	var corn_field: Node3D
	var gate: Node3D
	var reception: Node3D
	var campfire: Node3D
	var trees: Array[Vector3] = []
	## The spruces outside the fence (a MultiMesh, so by instance).
	var forest: Array[Vector3] = []
	var housing: Array[Vector3] = []

	func _init(director: Node) -> void:
		var grid = director.grid_manager
		center = grid.get_map_center_world()
		size = grid.get_map_size_world()
		var tree := director.get_tree()
		for n in tree.get_nodes_in_group("trees"):
			if n is Node3D and not n.is_in_group("corn") and n.is_inside_tree():
				trees.append((n as Node3D).global_position)
		gate = tree.get_first_node_in_group("camp_gate") as Node3D
		campfire = tree.get_first_node_in_group("campfire") as Node3D
		for n in tree.get_nodes_in_group("housing") + tree.get_nodes_in_group("cabins") + tree.get_nodes_in_group("tents"):
			if n is Node3D and housing.size() < 2:
				housing.append((n as Node3D).global_position)
		var bm = director.building_manager
		var structures: Node = bm.get_node_or_null("Structures") if bm != null else null
		if structures != null:
			for s in structures.get_children():
				if s.name == "MainBuilding":
					reception = s
		_find_scripted(director.get_parent())
		if lake != null:
			boat = lake.get("boat")

	func _find_scripted(n: Node) -> void:
		var sc: Script = n.get_script()
		if sc != null:
			var path := sc.resource_path
			if path.ends_with("camp_lake.gd") and n.is_inside_tree() and not n.is_queued_for_deletion():
				lake = n
			elif path.ends_with("cornfield.gd") and n.is_inside_tree() and not n.is_queued_for_deletion():
				corn_field = n
		if n is MultiMeshInstance3D and forest.is_empty() and str(n.get_parent().name).begins_with("Horizon") 				and not n.get_parent().is_queued_for_deletion():
			var mm: MultiMesh = (n as MultiMeshInstance3D).multimesh
			if mm != null:
				var xf := (n as Node3D).global_transform
				for i in mm.instance_count:
					forest.append(xf * mm.get_instance_transform(i).origin)
		for c in n.get_children():
			_find_scripted(c)
