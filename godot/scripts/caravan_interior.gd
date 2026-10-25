extends CanvasLayer

## Inside the camp's caravan (building_models.caravan(): the old Czechoslovak tourer).
## You stand just inside the side door looking down its length: at the far end the
## dinette under the end window (two benches and a table, made up into the double bed),
## across from the door the kitchenette (sink, two rings, the fridge, the window over
## them), the wardrobe by the door, and at the near end the bunks once it is done up.
## Wood-grain laminate walls, the quilted vinyl ceiling, check vinyl on the floor, the
## dome lamp (L). The upgrade brochure lies on the counter (a click: request_upgrade).
##   Lv1  2 beds: the dinette; worn, a gas bottle and a crate at the end
##   Lv2  3 beds: + the lower bunk at the end, a teddy on it, a rug in the aisle
##   Lv3  4 beds: + the upper bunk and its ladder, the little TV, flowers, fairy lights
## Room preparation like the tent and the cabin (scripts/interior_prep.gd): make up the
## dinette bed, then the mess (core/systems/mess_rules.gd ROOM_SPOTS "caravan").

signal room_task_completed(task_id: String)
signal request_close
signal request_upgrade

const RETRO_RENDER = preload("res://scripts/retro_render.gd")
const INTERIOR_LOOK = preload("res://scripts/interior_look.gd")
const INTERIOR_TORCH = preload("res://scripts/ui/interior_torch.gd")
const INTERIOR_PREP = preload("res://scripts/interior_prep.gd")
const INTERIOR_KIT = preload("res://scripts/interior_kit.gd")
const ROOM_WEATHER = preload("res://scripts/ambient/room_weather.gd")

const TIME_DAY: int = 0
const TIME_EVENING: int = 1
const TIME_NIGHT: int = 2
const INTERIOR_RENDER_MIN_SIZE := Vector2i(960, 540)

## The room: length along x, width along z (the door wall is +z), height. The van's own
## body (building_models.caravan: lx = 0.62 of its 8 m footprint, 2 m deep), so its
## windows from outside and in are the same windows (_update_inview).
const L := 4.96
const W := 2.0
const H := 1.95
const DOOR_X := -1.24
const EYE := Vector3(DOOR_X + 0.1, 1.52, 0.22)
## The van's windows where the model has them: the big one over the dinette at the
## towing end, the little one at the back end, three on the door side, three on the
## kitchen side, all at its window height. [glass size, centre, yaw].
const WINDOWS := [
	[Vector2(0.9, 0.5), Vector3(L * 0.5 - 0.004, 1.25, 0.0), -90.0],
	[Vector2(0.62, 0.44), Vector3(-L * 0.5 + 0.004, 1.25, 0.0), 90.0],
	[Vector2(0.78, 0.56), Vector3(0.69, 1.25, W * 0.5 - 0.004), 180.0],
	[Vector2(0.78, 0.56), Vector3(1.84, 1.25, W * 0.5 - 0.004), 180.0],
	[Vector2(0.62, 0.5), Vector3(-1.98, 1.25, W * 0.5 - 0.004), 180.0],
	[Vector2(0.7, 0.5), Vector3(-1.49, 1.25, -W * 0.5 + 0.004), 0.0],
	[Vector2(0.7, 0.5), Vector3(0.25, 1.25, -W * 0.5 + 0.004), 0.0],
	[Vector2(0.7, 0.5), Vector3(1.64, 1.25, -W * 0.5 + 0.004), 0.0],
]
## The model's floor is this high over the ground (building_models.caravan y0).
const VAN_FLOOR := 0.42
## The door: its leaf on the hinge, how far it opens, the camp's eye on the doorstep
## (the room's coordinates: the ground is VAN_FLOOR below its floor).
const DOOR_W := 0.62
const DOOR_H := 1.55
const DOOR_OPEN_DEG := -104.0
## In the doorway, in the wall's thickness: the walk in starts here, the walk out ends here
## looking out through the doorway's view of the camp.
const STEP_EYE := Vector3(DOOR_X + 0.04, 1.18, W * 0.5 + 0.06)
const WALL_T := 0.1
## The camp's own camera (main FIRST_PERSON fov): the walk out narrows to it.
const CAMP_FOV := 56.0
const ROOM_FOV := 70.0
const WALK_PATH = preload("res://scripts/ui/walk_path.gd")
const SFX_DOOR_OPEN := "res://assets/sfx/caravan/door_open.mp3"
const SFX_DOOR_SHUT := "res://assets/sfx/caravan/door_shut.mp3"
const SFX_STEP := "res://assets/sfx/caravan/step_creak.mp3"
## What lies over its own windows inside (the camp in the glass, the rain on it, the
## doorway's view): the camera looking in from the camp skips it (as the office's).
const INVIEW_HIDE_LAYER := 1 << 17
## Facing down the length to the dinette (+x).
const EYE_YAW_DEG := -90.0
const EYE_PITCH_DEG := -9.0

var _is_open := false
var _level := 1
var _time_state: int = TIME_DAY
var _daylight := 0.0
var _sun_color := Color(1.0, 0.95, 0.84)
var _grid_power_available := true
var _lights_on := true

var _viewport_container: SubViewportContainer
var _viewport: SubViewport
var _interior_camera: Camera3D
var _root: Node3D
var _env: Environment
var _lamp: OmniLight3D
var _lamp_shade: StandardMaterial3D
var _window_mats: Array[StandardMaterial3D] = []
var _fairy_mat: StandardMaterial3D
var _cam_base_rot := Vector3.ZERO
## A caravan is small and closed all round: turn right round, look up and down a little.
var _look = INTERIOR_LOOK.new(180.0, 26.0, 34.0)
## Lying in this room's bed (scripts/lodge_bed.gd has the camera): no looking round,
## no leaving, no clicks till you are up.
var lodge_sleeping := false
var _exit_hint: Control
var _prep = INTERIOR_PREP.new()
var _brochure: MeshInstance3D
var _brochure_cover: MeshInstance3D
var _torch: Node
var _guest_occupants: Array = []

## Shown from a level up (node names under the room root).
var _lv2_nodes: Array[String] = ["BunkLower", "Rug"]
var _lv3_nodes: Array[String] = ["BunkUpper", "BunkLadder", "FairyLights"]
var _lv1_nodes: Array[String] = ["EndGas"]
const CARAVAN_LIFE = preload("res://scripts/caravan_life.gd")
var _life


func _ready() -> void:
	# Under the HUD (65), whose messages show over a room.
	layer = 56
	visible = false
	_build_viewport()
	_build_room()


func is_open() -> bool:
	return _is_open


var _weather


## The weather in here (scripts/ambient/room_weather.gd): rain on the windows, lightning
## through them, the shell creaking in the gusts.
func _room_weather():
	if _weather == null or not is_instance_valid(_weather) or _weather.get_parent() != _root:
		_weather = ROOM_WEATHER.new()
		_weather.is_open = func(): return _is_open
		_root.add_child(_weather)
	return _weather


func set_is_day(is_day: bool) -> void:
	set_time_state(TIME_DAY if is_day else TIME_NIGHT)


func set_time_state(new_state: int) -> void:
	_time_state = clampi(new_state, TIME_DAY, TIME_NIGHT)
	_apply_light()


func set_daylight_profile(daylight_factor: float, sun_color: Color, _ambient_color: Color, _ambient_energy: float) -> void:
	_daylight = clampf(daylight_factor, 0.0, 1.0)
	_sun_color = sun_color
	_apply_light()


func set_grid_power_available(power_available: bool) -> void:
	_grid_power_available = power_available
	_apply_light()


func set_guest_occupants(entries: Array) -> void:
	_guest_occupants = entries.duplicate(true)


## `walked`: you came up to its door on foot (the camp walked you there): the room takes
## the walk on from the doorstep (_walk_in).
func open_caravan(level: int = 1, walked := false) -> void:
	if _viewport_container != null:
		RETRO_RENDER.apply_to(_viewport_container)
	_level = clampi(level, 1, 3)
	_apply_level()
	_apply_light()
	if _is_open:
		return
	_is_open = true
	visible = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_release_inview()
	call_deferred("_life_enter")
	if walked:
		_walk_in()
	else:
		_interior_camera.fov = ROOM_FOV
		_interior_camera.position = EYE
		_interior_camera.rotation_degrees = Vector3(EYE_PITCH_DEG, EYE_YAW_DEG, 0.0)
		_cam_base_rot = _interior_camera.rotation
		_look.reset()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func close_caravan() -> void:
	if not _is_open:
		return
	_kill_walk()
	_walking = false
	_leaving = false
	_is_open = false
	visible = false
	# Shut, the room is drawn only for the camp looking in (_update_inview).
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_door_pivot.rotation_degrees.y = 0.0
	if _life != null:
		_life.on_leave()
	_interior_camera.fov = ROOM_FOV
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	request_close.emit()


func _process(delta: float) -> void:
	if _interior_camera == null:
		return
	if not _is_open:
		_update_inview(delta)
		return
	_tick_windows(delta)
	if _life != null:
		_life.tick(delta, _interior_camera)
	if _walking:
		return
	if not lodge_sleeping:
		var offset: Vector3 = _look.update(delta, INTERIOR_LOOK.cursor_of(get_viewport()), INTERIOR_LOOK.turn_axis())
		_interior_camera.rotation = _cam_base_rot + offset
	_update_torch(delta)
	if _exit_hint == null:
		_exit_hint = INTERIOR_LOOK.make_exit_hint(self)
	INTERIOR_LOOK.update_exit_hint(_exit_hint, get_viewport(), delta)
	if _brochure_hover() or (_life != null and _life.is_thing(_collider_under(get_viewport().get_mouse_position()))):
		HandCursor.want(HandCursor.POINT)
	elif INTERIOR_LOOK.in_exit_zone(get_viewport()):
		HandCursor.want(HandCursor.WALK)
	if _fairy_mat != null:
		_fairy_mat.emission_energy_multiplier = (0.0 if _time_state == TIME_DAY or not _grid_power_available else 1.4) * (0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.003))


func _input(event: InputEvent) -> void:
	if not _is_open or lodge_sleeping:
		return
	if _prep != null and _prep.is_scrubbing():
		return
	# Esc is the pause menu's (main): S or the way out behind you leaves (but not a
	# click on something to tidy, however low on the screen it is).
	if _walking:
		get_viewport().set_input_as_handled()
		return
	if INTERIOR_LOOK.is_exit_event(event, get_viewport()) and not (_prep.is_busy() and event is InputEventMouseButton):
		walk_out()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_interior_light"):
		_lights_on = not _lights_on
		_apply_light()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _prep.is_busy():
			get_viewport().set_input_as_handled()
			return
		if _brochure_hover():
			request_upgrade.emit()
			get_viewport().set_input_as_handled()
			return
		var hit := _collider_under(event.position)
		if _life != null and _life.is_thing(hit):
			_life.click(hit)
			get_viewport().set_input_as_handled()
			return
		var wp = _curtain_under(event.position)
		if wp != null:
			wp.toggle_curtain()
			var im := get_parent()
			if im != null and im.has_method("coop_send_curtains"):
				im.coop_send_curtains(curtains_state())
			get_viewport().set_input_as_handled()


# ── the windows (scripts/ui/window_portal.gd) ───────────────────────────────

const WINDOW_PORTAL = preload("res://scripts/ui/window_portal.gd")
var _windows: Array = []
## The caravan's floor stands on its axles, this much over the ground (a negative floor).
const FLOOR_UP := -0.45


func _anchor() -> Node3D:
	var im := get_parent()
	var n = im.get("_active_caravan_node") if im != null else null
	return n as Node3D if n != null and is_instance_valid(n) and (n as Node3D).is_inside_tree() else null


func _tick_windows(delta: float) -> void:
	var a := _anchor()
	var world: World3D = a.get_world_3d() if a != null else null
	# Each a whole view of the camp: drawn only while it is in sight (eight of them).
	for w in _windows:
		w.update(_root, _interior_camera, WINDOW_PORTAL.room_to_world(a, w, FLOOR_UP) if a != null else Transform3D(), a != null and _in_sight(w), world, delta)
	if _door_view != null:
		# (Drawn from the start of the walk out: it is ready when the door swings open.)
		_door_view.update(_root, _interior_camera, WINDOW_PORTAL.room_to_world(a, _door_view, FLOOR_UP) if a != null else Transform3D(), a != null and (_door_open() > 0.02 or _leaving), world, delta)


## Is the window's glass on the screen (any corner in front of the eye and inside it)?
func _in_sight(w) -> bool:
	# (A good way past the edges: it is drawn before it turns into view, not a frame late.)
	var vp_rect := Rect2(Vector2.ZERO, Vector2(_viewport.size))
	var margin := float(_viewport.size.x) * 0.35
	for i in 4:
		var c := Vector3((float(i % 2) - 0.5) * w.size.x, (float(i / 2) - 0.5) * w.size.y, 0.0)
		var p: Vector3 = _root.global_transform * (w.frame * c)
		if not _interior_camera.is_position_behind(p) and vp_rect.grow(margin).has_point(_interior_camera.unproject_position(p)):
			return true
	return false


## What is under the pointer (a ray from the room's camera), null nothing.
func _collider_under(screen: Vector2) -> Node:
	if _viewport == null or _interior_camera == null:
		return null
	var size := get_viewport().get_visible_rect().size
	var local := Vector2(screen.x / size.x * float(_viewport.size.x), screen.y / size.y * float(_viewport.size.y))
	var from := _interior_camera.project_ray_origin(local)
	var q := PhysicsRayQueryParameters3D.create(from, from + _interior_camera.project_ray_normal(local) * 8.0)
	var hit := _viewport.find_world_3d().direct_space_state.intersect_ray(q)
	return hit.get("collider", null)


## The curtain under the pointer, null none.
func _curtain_under(screen: Vector2):
	var n: Node = _collider_under(screen)
	while n != null:
		if n.has_meta("window_portal"):
			return n.get_meta("window_portal")
		n = n.get_parent()
	return null


func photo_windows() -> Array:
	var out: Array = []
	var a := _anchor()
	if a == null:
		return out
	for w in _windows:
		var o: Dictionary = w.outside(WINDOW_PORTAL.room_to_world(a, w, FLOOR_UP))
		o["facing"] = w.facing(_root, _interior_camera)
		o["open"] = w.curtain_open()
		o["flash"] = w.flash
		o["room_world"] = _viewport.find_world_3d() if _viewport != null else null
		o["glass"] = _root.global_transform * w.frame.origin
		o["eye"] = _interior_camera.global_position
		# Your eye out in the camp (the window's camera).
		o["view"] = w.cam.global_position
		out.append(o)
	return out


func curtains_state() -> Array:
	var out: Array = []
	for w in _windows:
		out.append(w.curtain_open() > 0.5)
	return out


func take_curtains(state: Array) -> void:
	for i in mini(state.size(), _windows.size()):
		_windows[i].set_curtain(bool(state[i]))


# ── the camp looking in ──────────────────────────────────────────────────────
#
# From the camp the nearest caravan's windows show this room (the user 21. 10.: "3D
# windows from outside and inside, like the other buildings"): a camera in the room's
# own world at the camp's eye (camp -> the van's model -> the room: its floor VAN_FLOOR
# over the ground, the same length and width), the panes reading its picture at their
# own screen pixels (materials/window_into.gdshader), as the reception's do. One room for
# every caravan: it is made up as the one looked into is (its level, its bed, its
# curtains), its lamp lit when window_lights has that van lit (guests in, awake), the
# curtains drawn half over a lit one with guests in. Farther than INVIEW_RANGE, or with
# no pane turned to you, the panes are window_lights' again.

const INVIEW_RANGE := 30.0
var _inview_vp: SubViewport
var _inview_cam: Camera3D
var _inview_mat: ShaderMaterial
var _inview_van: Node3D
var _inview_panes: Array = []
var _inview_scan_t := 0.0
var _inview_light_t := 0.0
var _vans: Array = []


func _camp_camera() -> Camera3D:
	var scene := get_tree().current_scene if is_inside_tree() else null
	var w3d = scene.get("_world_3d") if scene != null else null
	if w3d is Node3D and (w3d as Node3D).is_inside_tree():
		return (w3d as Node3D).get_viewport().get_camera_3d()
	return null


func _find_vans() -> Array:
	var out: Array = []
	var scene := get_tree().current_scene if is_inside_tree() else null
	var bm = scene.get("building_manager") if scene != null else null
	var structures: Node = bm.get_node_or_null("Structures") if bm != null else null
	if structures == null:
		return out
	for c in structures.get_children():
		if str(c.get_meta("building_type", "")).begins_with("caravan") and c is Node3D:
			out.append(c)
	return out


## The van's panes (building_models.caravan: its "lit_window" quads).
static func _panes_of(van: Node3D) -> Array:
	var out: Array = []
	for m in van.find_children("*", "MeshInstance3D", true, false):
		if (m as Node).has_meta("lit_window"):
			out.append(m)
	return out


static func _pane_turned_to(p: MeshInstance3D, eye: Vector3) -> bool:
	var to := eye - p.global_position
	return to.length() > 0.05 and p.global_basis.z.normalized().dot(to.normalized()) > 0.1


func _update_inview(delta: float) -> void:
	var cam := _camp_camera()
	var van: Node3D = null
	if cam != null:
		_inview_scan_t -= delta
		if _inview_scan_t <= 0.0:
			_inview_scan_t = 1.0
			_vans = _find_vans()
		var best := INVIEW_RANGE
		for v in _vans:
			if not is_instance_valid(v) or not (v as Node3D).is_inside_tree():
				continue
			var d := (v as Node3D).global_position.distance_to(cam.global_position)
			if d >= best:
				continue
			for p in _panes_of(v):
				if _pane_turned_to(p, cam.global_position):
					best = d
					van = v
					break
	if van != _inview_van:
		_release_inview()
		if van != null:
			_take_inview(van)
	if _inview_van == null or _inview_panes.is_empty():
		return
	# The camp's eye in the room: the world -> the van's model (the panes' parent) -> the
	# room, whose floor lies VAN_FLOOR up in it.
	var model := (_inview_panes[0] as Node3D).get_parent() as Node3D
	var to_room: Transform3D = _root.global_transform * Transform3D(Basis(), Vector3(0.0, VAN_FLOOR, 0.0)).affine_inverse() * model.global_transform.affine_inverse()
	var t := to_room * cam.global_transform
	_inview_cam.global_transform = Transform3D(t.basis.orthonormalized(), t.origin)
	_inview_cam.fov = cam.fov
	_inview_cam.keep_aspect = cam.keep_aspect
	var px := Vector2i(cam.get_viewport().get_visible_rect().size)
	if _inview_vp.size != px and px.x > 0:
		_inview_vp.size = px
	_inview_light_t -= delta
	if _inview_light_t <= 0.0:
		_inview_light_t = 0.5
		_inview_room_light()


## The room made up as `van` is, and its panes given the room's picture.
func _take_inview(van: Node3D) -> void:
	_ensure_inview()
	_inview_van = van
	_inview_panes = _panes_of(van)
	var t := str(van.get_meta("building_type", "caravan_1"))
	_level = clampi(int(t.right(1)), 1, 3)
	_apply_level()
	var im := get_parent()
	if im != null and im.has_method("_push_room_state"):
		im.call("_push_room_state", self, van)
	var key: String = im.call("_room_key_for", van) if im != null and im.has_method("_room_key_for") else ""
	var by_room = im.get("_curtains_by_room") if im != null else null
	if key != "" and by_room is Dictionary and (by_room as Dictionary).has(key):
		take_curtains((by_room as Dictionary)[key])
	for p in _inview_panes:
		var mi := p as MeshInstance3D
		mi.set_meta("inview_was", mi.material_override)
		mi.set_meta("inview_live", true)
		mi.material_override = _inview_mat
	_inview_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_inview_light_t = 0.0


func _release_inview() -> void:
	for p in _inview_panes:
		# (A caravan bulldozed while looked into: its panes are gone, a cast of them errs.)
		if not is_instance_valid(p):
			continue
		var mi := p as MeshInstance3D
		if mi == null:
			continue
		if mi.has_meta("inview_was"):
			mi.material_override = mi.get_meta("inview_was")
			mi.remove_meta("inview_was")
		mi.remove_meta("inview_live")
	_inview_panes.clear()
	_inview_van = null
	if _inview_vp != null:
		_inview_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED


## The room's light as the camp's hour has it, its lamp as window_lights has the van
## (guests in and up: lit; a candle in a power cut), its curtains half drawn over it then.
func _inview_room_light() -> void:
	var scene := get_tree().current_scene
	var hour := float(scene.get("_time_of_day_hours")) if scene != null and scene.get("_time_of_day_hours") != null else 12.0
	var state := TIME_DAY if hour >= 6.5 and hour < 19.5 else (TIME_EVENING if hour >= 19.5 and hour < 21.0 else TIME_NIGHT)
	var im := get_parent()
	var ll = im.get("_last_light") if im != null else null
	if ll is Array and (ll as Array).size() >= 4:
		set_daylight_profile(ll[0], ll[1], ll[2], ll[3])
	var lit := 0.0
	for p in _inview_panes:
		lit = maxf(lit, float((p as Node).get_meta("wl_lit", 0.0)))
	_inview_lit = lit > 0.05
	set_time_state(state)
	_inview_mat.set_shader_parameter("bright", 1.0 if state == TIME_NIGHT else (0.8 if state == TIME_EVENING else 0.62))
	_inview_mat.set_shader_parameter("glow", 0.0)


func _ensure_inview() -> void:
	if _inview_vp != null:
		return
	_inview_vp = SubViewport.new()
	_inview_vp.name = "CaravanFromCamp"
	_inview_vp.size = Vector2i(426, 240)
	_inview_vp.world_3d = _viewport.find_world_3d()
	_inview_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_inview_vp)
	_inview_cam = Camera3D.new()
	_inview_cam.near = 0.05
	_inview_cam.far = 40.0
	_inview_cam.cull_mask = 0xFFFFF & ~INVIEW_HIDE_LAYER
	_inview_vp.add_child(_inview_cam)
	if _weather != null and is_instance_valid(_weather):
		_hide_from_camp(_weather)
	_inview_mat = ShaderMaterial.new()
	_inview_mat.shader = load("res://materials/window_into.gdshader")
	_inview_mat.set_shader_parameter("room_tex", _inview_vp.get_texture())
	_inview_mat.set_shader_parameter("live", 1.0)
	# Pulled toward the eye as the van's small quads are (retro_materials PULL_SMALL), else
	# its skin, pulled further, is drawn over the glass.
	_inview_mat.set_shader_parameter("depth_pull", 0.009)


# ── the door: in and out on foot ─────────────────────────────────────────────
#
# The user 21. 10.: "smooth coming in and going out". In: the camp walks you up to the
# door and it opens (interior_manager), the room takes the walk on from the doorstep: up
# the step through the doorway, turning down the van to the dinette, the door swinging
# shut behind you. Out: turning to the door, it swings open on the camp (the doorway's
# view, a window_portal like the windows), down the step to the camp's eye, and the camp
# takes it on from there (interior_manager._step_out_of).

var _door_pivot: Node3D
var _door_view
var _walk: Tween
var _walking := false
var _leaving := false


func _build_door() -> void:
	# The doorway's view of the camp (no frame: the door's is the van's), behind the leaf.
	# (On the wall's outer face: the walk out ends in the doorway looking out through it.)
	_door_view = WINDOW_PORTAL.make(self, _root, Vector3(DOOR_X, 0.04 + DOOR_H * 0.5, W * 0.5 + WALL_T + 0.004), Vector3(0, 0, 1), Vector2(DOOR_W, DOOR_H), "", 320, false)
	_door_view.fixed_px = true
	_hide_from_camp(_door_view.quad)
	_door_pivot = Node3D.new()
	_door_pivot.name = "DoorHinge"
	_door_pivot.position = Vector3(DOOR_X - DOOR_W * 0.5, 0.04, W * 0.5 - 0.02)
	_root.add_child(_door_pivot)
	var mat := _quad_mat("caravan_door", 0.0)
	for s: float in [1.0, -1.0]:
		var q := MeshInstance3D.new()
		q.name = "Door"
		var qm := QuadMesh.new()
		qm.size = Vector2(DOOR_W, DOOR_H)
		q.mesh = qm
		var m := mat.duplicate() as StandardMaterial3D
		if s < 0.0:
			m.uv1_scale = Vector3(-1, 1, 1)
		q.material_override = m
		# The room's face looks in (-z), the other out.
		q.position = Vector3(DOOR_W * 0.5, DOOR_H * 0.5, -0.01 * s)
		q.rotation.y = PI if s > 0.0 else 0.0
		_door_pivot.add_child(q)
	INTERIOR_KIT.slab(_door_pivot, Vector3(DOOR_W, DOOR_H, 0.018), Vector3(DOOR_W * 0.5, DOOR_H * 0.5, 0.0), INTERIOR_KIT.surface("veneer_dark", 0.6), "DoorEdge")


## How far the door stands open, 0 shut .. 1 wide.
func _door_open() -> float:
	return clampf(_door_pivot.rotation_degrees.y / DOOR_OPEN_DEG, 0.0, 1.0) if _door_pivot != null else 0.0


## In from the doorstep (interior_manager has walked you up to the door and opened it).
func _walk_in() -> void:
	_kill_walk()
	_walking = true
	_door_pivot.rotation_degrees.y = DOOR_OPEN_DEG
	_interior_camera.fov = CAMP_FOV
	_interior_camera.position = STEP_EYE
	_interior_camera.rotation = Vector3(-0.04, 0.0, 0.0)
	_walk = WALK_PATH.play(self, _interior_camera, [
		{"pos": STEP_EYE, "rot": Vector3(-0.04, 0.0, 0.0)},
		{"pos": Vector3(DOOR_X + 0.06, 1.46, W * 0.5 - 0.24), "rot": Vector3(-0.07, deg_to_rad(-38.0), 0.0)},
		{"pos": EYE, "rot": Vector3(deg_to_rad(EYE_PITCH_DEG), deg_to_rad(EYE_YAW_DEG), 0.0)},
	], 1.2)
	_walk.parallel().tween_property(_interior_camera, "fov", ROOM_FOV, 0.8)
	_walk.parallel().tween_callback(_play.bind(SFX_STEP, -8.0)).set_delay(0.12)
	_walk.parallel().tween_callback(_rock.bind(0.6)).set_delay(0.18)
	_walk.parallel().tween_property(_door_pivot, "rotation_degrees:y", 0.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(0.72)
	_walk.parallel().tween_callback(_play.bind(SFX_DOOR_SHUT, -4.0)).set_delay(1.12)
	_walk.tween_callback(_walk_done)


## Out by the door (S, the way out behind you): the room ends on the doorstep, the camp
## takes it on.
func walk_out() -> void:
	if _walking or not _is_open:
		return
	_kill_walk()
	_walking = true
	_leaving = true
	_play_steps()
	_walk = WALK_PATH.play(self, _interior_camera, [
		{"pos": _interior_camera.position, "rot": _interior_camera.rotation},
		{"pos": Vector3(DOOR_X + 0.06, 1.48, W * 0.5 - 0.52), "rot": Vector3(-0.05, PI, 0.0)},
		{"pos": Vector3(DOOR_X + 0.04, 1.36, W * 0.5 - 0.1), "rot": Vector3(-0.08, PI, 0.0)},
		{"pos": STEP_EYE + Vector3(0.0, 0.02, -0.02), "rot": Vector3(0.0, PI, 0.0)},
	], 1.3)
	_walk.parallel().tween_callback(_play.bind(SFX_DOOR_OPEN, -4.0)).set_delay(0.32)
	_walk.parallel().tween_property(_door_pivot, "rotation_degrees:y", DOOR_OPEN_DEG, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).set_delay(0.34)
	_walk.parallel().tween_callback(_play.bind(SFX_STEP, -8.0)).set_delay(0.95)
	_walk.parallel().tween_callback(_rock.bind(-0.5)).set_delay(1.0)
	_walk.parallel().tween_property(_interior_camera, "fov", CAMP_FOV, 0.7).set_delay(0.55)
	_walk.tween_callback(func() -> void:
		_walking = false
		close_caravan())


## The things as you find them coming in (after the room's state is in: the bed made?).
func _life_enter() -> void:
	if _life == null or not _is_open:
		return
	var scene := get_tree().current_scene
	var hour := float(scene.get("_time_of_day_hours")) if scene != null and scene.get("_time_of_day_hours") != null else 12.0
	_life.spec["daylight"] = _daylight
	_life.on_enter(hour, _bed_made_node != null and _bed_made_node.visible)


func _walk_done() -> void:
	_walking = false
	_cam_base_rot = _interior_camera.rotation
	_look.reset()


func _kill_walk() -> void:
	if _walk != null and _walk.is_valid():
		_walk.kill()
	_walk = null


## The van rocks on its springs under your weight (`amount` -1..1: the way it leans).
var _cam_rig: Node3D


func _rock(amount: float) -> void:
	if _cam_rig == null:
		return
	var tw := create_tween()
	tw.tween_property(_cam_rig, "rotation:z", 0.010 * amount, 0.12).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_cam_rig, "rotation:z", -0.005 * amount, 0.22).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_cam_rig, "rotation:z", 0.0, 0.3).set_trans(Tween.TRANS_SINE)


func _play_steps() -> void:
	_play("res://assets/sfx/rooms/steps_wood.mp3", -12.0)


func _play(path: String, db: float, pitch := 1.0) -> void:
	if not ResourceLoader.exists(path):
		return
	var a := AudioStreamPlayer.new()
	a.stream = load(path)
	a.volume_db = db
	a.pitch_scale = pitch
	add_child(a)
	a.finished.connect(a.queue_free)
	a.play()


static func _hide_from_camp(n: Node) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = INVIEW_HIDE_LAYER
	for c in n.get_children():
		_hide_from_camp(c)


func _brochure_hover() -> bool:
	if _brochure == null or _viewport == null:
		return false
	var r := INTERIOR_LOOK.screen_rect_of(_interior_camera, Vector2(_viewport.size), _brochure)
	if not r.has_area():
		return false
	var c := INTERIOR_LOOK.cursor_of(get_viewport())
	return r.grow(0.01).has_point(c)


# ── building ─────────────────────────────────────────────────────────────────

func _build_viewport() -> void:
	_viewport_container = SubViewportContainer.new()
	_viewport_container.name = "CaravanViewportContainer"
	_viewport_container.anchor_right = 1.0
	_viewport_container.anchor_bottom = 1.0
	_viewport_container.stretch = true
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_viewport_container)
	RETRO_RENDER.register(_viewport_container)
	_viewport = SubViewport.new()
	_viewport.name = "CaravanViewport"
	_viewport.own_world_3d = true
	_viewport.size = INTERIOR_RENDER_MIN_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.handle_input_locally = false
	_viewport_container.add_child(_viewport)
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.1, 0.1, 0.12)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.8, 0.78, 0.72)
	_env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = _env
	_viewport.add_child(we)


func _build_room() -> void:
	var K := INTERIOR_KIT
	_root = Node3D.new()
	_root.name = "CaravanRoom"
	_viewport.add_child(_root)
	_interior_camera = Camera3D.new()
	_interior_camera.name = "CaravanCamera"
	_interior_camera.fov = 70.0
	_interior_camera.near = 0.05
	_interior_camera.far = 12.0
	_interior_camera.current = true
	_interior_camera.position = EYE
	_interior_camera.rotation_degrees = Vector3(EYE_PITCH_DEG, EYE_YAW_DEG, 0.0)
	# The camera on a rig that rocks with the van on its springs (_rock); still, it is the
	# room's own space (lodge_bed and the torch read the camera's parent).
	_cam_rig = Node3D.new()
	_cam_rig.name = "CamRig"
	_root.add_child(_cam_rig)
	_cam_rig.add_child(_interior_camera)
	var shell: Dictionary = K.room(_root, Vector3(L, H, W), "caravan_floor", "caravan_veneer", "caravan_ceiling", 1.1, 0.7)
	# The door wall with its doorway cut out (you walk in and out through it).
	var front_mat: Material = (shell["front"] as MeshInstance3D).material_override
	(shell["front"] as Node).free()
	var dl := DOOR_X - DOOR_W * 0.5
	var dr := DOOR_X + DOOR_W * 0.5
	var dtop := 0.04 + DOOR_H
	var fz := W * 0.5 + WALL_T * 0.5
	K.slab(_root, Vector3(dl + L * 0.5, H, WALL_T), Vector3((-L * 0.5 + dl) * 0.5, H * 0.5, fz), front_mat, "WallFront")
	K.slab(_root, Vector3(L * 0.5 - dr, H, WALL_T), Vector3((dr + L * 0.5) * 0.5, H * 0.5, fz), front_mat, "WallFrontB")
	K.slab(_root, Vector3(DOOR_W, H - dtop, WALL_T), Vector3(DOOR_X, (dtop + H) * 0.5, fz), front_mat, "WallFrontC")
	K.skirting(_root, Vector3(L, H, W), "veneer_dark")
	var veneer := K.surface("caravan_veneer", 1.1)
	var veneer_dark := K.surface("veneer_dark", 0.8)
	var formica := K.surface("formica", 0.6, Color(0.96, 0.92, 0.82))
	var cushion := K.surface("cv_cushion", 0.6)
	# The door you came in by, on its hinge (the walks in and out swing it), and behind
	# it the doorway's view of the camp, there while it stands open.
	_build_door()
	for wspec in WINDOWS:
		# The glass looks out of the caravan where it stands (scripts/ui/window_portal.gd),
		# a curtain to draw over it.
		var into := _inward(float(wspec[2]))
		var wp = WINDOW_PORTAL.make(self, _root, (wspec[1] as Vector3) + into * 0.01, -into, wspec[0], "curtain_floral", 192)
		_windows.append(wp)
		_room_weather().add_window(wp.quad)
		_hide_from_camp(wp.quad)
		# A plain frame round it.
		var fr := K.slab(_root, Vector3((wspec[0] as Vector2).x + 0.08, 0.05, 0.05), (wspec[1] as Vector3) + _inward(float(wspec[2])) * 0.02 + Vector3(0, -(wspec[0] as Vector2).y * 0.5 - 0.03, 0), veneer_dark, "Sill")
		fr.rotation_degrees.y = float(wspec[2])
	# The dinette at the far end: two benches, their backs, the table between.
	var dx := L * 0.5 - 0.52
	for side: float in [-1.0, 1.0]:
		var z := side * (W * 0.5 - 0.26)
		K.slab(_root, Vector3(0.98, 0.42, 0.5), Vector3(dx, 0.21, z), veneer, "BenchBox")
		K.slab(_root, Vector3(0.98, 0.1, 0.5), Vector3(dx, 0.47, z), cushion, "BenchCushion")
		K.slab(_root, Vector3(0.98, 0.42, 0.1), Vector3(dx, 0.75, side * (W * 0.5 - 0.05)), cushion, "BenchBack")
	var table := K.slab(_root, Vector3(0.7, 0.04, 0.86), Vector3(dx, 0.72, 0), formica, "DinetteTable")
	var leg := K.slab(_root, Vector3(0.06, 0.7, 0.06), Vector3(dx, 0.35, 0), K.surface("galvanized", 0.4), "DinetteLeg")
	# The kitchenette across from the door: cabinet, worktop, sink, two rings, fridge.
	var kx := 0.05
	var kz := -W * 0.5 + 0.28
	K.slab(_root, Vector3(1.1, 0.86, 0.54), Vector3(kx, 0.43, kz), veneer, "KitchenCabinet")
	K.slab(_root, Vector3(1.14, 0.04, 0.58), Vector3(kx, 0.88, kz + 0.01), formica, "Worktop")
	# (The sink and the rings are in the worktop's picture, the fridge and the locker's
	# front are caravan_life's: they open.)
	K.slab(_root, Vector3(1.1, 0.34, 0.3), Vector3(kx, 1.76, kz - 0.1), veneer_dark, "Cupboard")
	# A low cupboard on the door side past the door (a tall wardrobe there filled the
	# view down the aisle), a coat hook by the door.
	K.slab(_root, Vector3(0.7, 0.78, 0.38), Vector3(0.45, 0.39, W * 0.5 - 0.19), veneer, "Sideboard")
	K.slab(_root, Vector3(0.74, 0.03, 0.42), Vector3(0.45, 0.795, W * 0.5 - 0.2), veneer_dark, "SideboardTop")
	for kx2: float in [0.3, 0.6]:
		K.slab(_root, Vector3(0.03, 0.03, 0.03), Vector3(kx2, 0.6, W * 0.5 - 0.39), K.surface("galvanized", 0.4), "SideboardKnob")
	K.slab(_root, Vector3(0.05, 0.05, 0.12), Vector3(DOOR_X + 0.5, 1.6, W * 0.5 - 0.06), K.surface("galvanized", 0.4), "CoatHook")
	# The near end: a crate and the gas bottle (Lv1); the bunks (Lv2, Lv3).
	var ex := -L * 0.5 + 0.38
	var gas := MeshInstance3D.new()
	gas.name = "EndGas"
	var gcyl := CylinderMesh.new()
	gcyl.top_radius = 0.14
	gcyl.bottom_radius = 0.14
	gcyl.height = 0.5
	gas.mesh = gcyl
	gas.material_override = INTERIOR_PREP.flat(Color(0.72, 0.22, 0.12))
	gas.position = Vector3(ex, 0.25, 0.5)
	_root.add_child(gas)
	var lower := Node3D.new()
	lower.name = "BunkLower"
	_root.add_child(lower)
	K.slab(lower, Vector3(0.74, 0.36, W - 0.06), Vector3(ex, 0.18, 0), veneer, "BunkBase")
	K.slab(lower, Vector3(0.7, 0.12, W - 0.12), Vector3(ex, 0.42, 0), K.surface("mattress", 0.6), "BunkMattress")
	var upper := Node3D.new()
	upper.name = "BunkUpper"
	_root.add_child(upper)
	K.slab(upper, Vector3(0.74, 0.06, W - 0.06), Vector3(ex, 1.18, 0), veneer, "BunkShelf")
	K.slab(upper, Vector3(0.7, 0.12, W - 0.12), Vector3(ex, 1.27, 0), K.surface("mattress", 0.6), "BunkMattress2")
	var ladder := Node3D.new()
	ladder.name = "BunkLadder"
	_root.add_child(ladder)
	for i in 3:
		K.slab(ladder, Vector3(0.04, 0.04, 0.34), Vector3(ex + 0.4, 0.5 + i * 0.3, 0.6), K.surface("galvanized", 0.4), "Rung")
	for zz: float in [0.43, 0.77]:
		K.slab(ladder, Vector3(0.04, 1.2, 0.04), Vector3(ex + 0.4, 0.6, zz), K.surface("galvanized", 0.4), "LadderRail")
	K.slab(_root, Vector3(2.4, 0.01, 0.7), Vector3(-0.2, 0.006, 0.12), K.surface("rug", 1.0), "Rug")
	# The fairy lights along the top of the dinette end (Lv3).
	var fairy := Node3D.new()
	fairy.name = "FairyLights"
	_root.add_child(fairy)
	_fairy_mat = StandardMaterial3D.new()
	_fairy_mat.albedo_color = Color(1.0, 0.86, 0.5)
	_fairy_mat.emission_enabled = true
	_fairy_mat.emission = Color(1.0, 0.76, 0.36)
	for i in 10:
		var z := -W * 0.5 + 0.1 + float(i) * (W - 0.2) / 9.0
		K.slab(fairy, Vector3(0.04, 0.05, 0.04), Vector3(L * 0.5 - 0.06, H - 0.12 - absf(sin(float(i) * 0.8)) * 0.06, z), _fairy_mat, "Bulb")
	# The dome lamp in the middle of the ceiling.
	_lamp_shade = INTERIOR_PREP.flat(Color(0.98, 0.95, 0.86))
	_lamp_shade.emission_enabled = true
	_lamp_shade.emission = Color(1.0, 0.9, 0.7)
	var dome := MeshInstance3D.new()
	var dcyl := CylinderMesh.new()
	dcyl.top_radius = 0.2
	dcyl.bottom_radius = 0.24
	dcyl.height = 0.07
	dome.mesh = dcyl
	dome.material_override = _lamp_shade
	dome.position = Vector3(0.2, H - 0.035, 0.0)
	_root.add_child(dome)
	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(0.2, H - 0.25, 0.0)
	_lamp.omni_range = 4.8
	_lamp.omni_attenuation = 1.1
	_lamp.light_color = Color(1.0, 0.9, 0.72)
	_lamp.shadow_enabled = true
	_root.add_child(_lamp)
	# The brochure on the worktop: next year's accessories (a click: the upgrade).
	_brochure = K.slab(_root, Vector3(0.22, 0.012, 0.3), Vector3(kx - 0.02, 0.907, kz + 0.06), INTERIOR_PREP.flat(Color(0.94, 0.9, 0.78)), "Brochure")
	_brochure.rotation_degrees.y = 12.0
	_brochure_cover = MeshInstance3D.new()
	var bq := QuadMesh.new()
	bq.size = Vector2(0.18, 0.15)
	_brochure_cover.mesh = bq
	_brochure_cover.position = Vector3(0, 0.008, -0.04)
	_brochure_cover.rotation_degrees.x = -90.0
	_brochure.add_child(_brochure_cover)
	# The things to play with, and the furniture's faces (scripts/caravan_life.gd).
	_life = CARAVAN_LIFE.new()
	_root.add_child(_life)
	var ring_at := func(u: float, v: float) -> Vector3:
		return Vector3(kx - 0.57 + u * 1.14, 0.902, kz + 0.01 - 0.29 + v * 0.58)
	_life.build(_root, {
		"L": L, "W": W, "H": H, "kx": kx, "kz": kz, "dx": dx,
		"fridge": Vector3(kx + 0.82, 0.42, kz), "locker": Vector3(kx, 1.76, kz - 0.1),
		"rings": [ring_at.call(0.81, 0.21), ring_at.call(0.813, 0.6)], "sink": ring_at.call(0.215, 0.556),
		"sideboard": Vector3(0.45, 0.39, W * 0.5 - 0.19),
		"radio": Vector3(kx - 0.02, 0.905, kz - 0.18),
		"tv": Vector3(0.62, 0.81, W * 0.5 - 0.24),
		"heater": Vector3(1.28, 0.0, -W * 0.5 + 0.24),
		"teddy": Vector3(ex + 0.12, 0.48, -0.55),
		"flowers": Vector3(L * 0.5 - 0.09, 0.995, 0.28),
		"boots": Vector3(DOOR_X + 0.46, 0.0, W * 0.5 - 0.2),
		"crate": Vector3(ex, 0.0, -0.5),
		"lamp": Vector3(0.2, H - 0.06, 0.0),
		"vent": Vector3(-0.74, H, 0.0),
		"cat_bench": Vector3(dx, 0.52, -(W * 0.5 - 0.3)), "cat_bed": Vector3(dx - 0.1, 0.66, 0.2),
		"cat_bunk": Vector3(ex + 0.05, 0.48, 0.35),
		"door_floor": Vector3(DOOR_X, 0.0, W * 0.5 - 0.1),
	})
	_life.lamp_clicked.connect(func() -> void:
		_lights_on = not _lights_on
		_apply_light())
	_build_prep(dx)
	_apply_level()
	_apply_light()


## The dinette as the last guests left it (cushions off, the blanket in a heap, the
## table up and sticky); made up it is the double bed. Then the spots for the mess.
func _build_prep(dx: float) -> void:
	var P := INTERIOR_PREP
	var K := INTERIOR_KIT
	var made := Node3D.new()
	made.name = "MadeBed"
	_root.add_child(made)
	K.slab(made, Vector3(0.96, 0.16, W - 0.08), Vector3(dx, 0.58, 0), K.surface("mattress", 0.6), "BedMattress")
	K.slab(made, Vector3(0.9, 0.04, W - 0.3), Vector3(dx - 0.02, 0.68, 0.06), K.surface("blanket_check", 0.6), "BedBlanket")
	for z: float in [-0.45, 0.45]:
		K.slab(made, Vector3(0.36, 0.08, 0.26), Vector3(dx + 0.26, 0.7, z * 0.9), K.surface("mattress", 0.4, Color(1, 1, 0.96)), "Pillow")
	var heap_mat := P.camp_material("blanket_check.png", Color(0.75, 0.72, 0.7))
	var heap := P.box(_root, Vector3(dx - 0.1, 0.56, 0.5), Vector3(0.5, 0.18, 0.4), heap_mat, Vector3(0.15, 0.4, -0.1))
	var cushion_off := P.box(_root, Vector3(dx - 0.62, 0.06, -0.35), Vector3(0.6, 0.1, 0.42), P.camp_material("velvet.png", Color(0.92, 0.6, 0.36)), Vector3(0.0, 0.7, 0.12))
	var table: Node3D = _root.get_node_or_null("DinetteTable")
	var leg: Node3D = _root.get_node_or_null("DinetteLeg")
	var body := P.body(_root, Vector3(dx, 0.5, 0.0), Vector3(1.0, 0.6, W - 0.1))
	# Messy: the table up, the heap, a cushion on the floor; made: the bed (no table). The
	# prep puts the mess away; the table going down and the bed made up are ours
	# (set_room, _make_up_bed: an animation, not a pop).
	_prep.register("bed", body, [heap, cushion_off], [])
	_bed_made_node = made
	_table_nodes = [table, leg]
	for spot in [["f1", Vector3(0.45, 0.0, 0.25)], ["f2", Vector3(-0.85, 0.0, -0.15)], ["f3", Vector3(1.05, 0.0, -0.1)],
			["f4", Vector3(-1.7, 0.0, 0.3)], ["t1", Vector3(0.3, 0.9, -W * 0.5 + 0.32)]]:
		_prep.add_spot(spot[0], _root, spot[1])
	_prep.setup_tasks(self, _interior_camera, _viewport, "caravan")
	_prep.task_completed.connect(func(id: String): room_task_completed.emit(id))


func _apply_level() -> void:
	for n in _lv1_nodes:
		_set_visible(n, _level == 1)
	for n in _lv2_nodes:
		_set_visible(n, _level >= 2)
	for n in _lv3_nodes:
		_set_visible(n, _level >= 3)
	if _brochure_cover != null:
		var next := "res://assets/textury/builder/iso_caravan%d.png" % mini(3, _level + 1)
		var m := StandardMaterial3D.new()
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		if ResourceLoader.exists(next):
			m.albedo_texture = load(next)
		_brochure_cover.material_override = m
	# The old one is a bit grubbier.
	var tint := Color(0.86, 0.82, 0.76) if _level == 1 else Color(1, 1, 1)
	# Lv1 the old lino worn through; done up the check vinyl; Lv3 the walls papered.
	var floor_mi := _root.get_node_or_null("Floor") as MeshInstance3D
	if floor_mi != null:
		floor_mi.material_override = INTERIOR_KIT.surface("cv_lino_worn" if _level == 1 else "caravan_floor", 0.7)
	for wall in ["WallBack", "WallFront", "WallFrontB", "WallFrontC", "WallLeft", "WallRight"]:
		var mi := _root.get_node_or_null(wall) as MeshInstance3D
		if mi != null:
			var mm := INTERIOR_KIT.surface("cv_wallpaper" if _level >= 3 else "caravan_veneer", 1.1).duplicate() as StandardMaterial3D
			mm.albedo_color = tint
			mi.material_override = mm
	if _life != null:
		_life.apply_level(_level)


func _set_visible(n: String, on: bool) -> void:
	var node := _root.get_node_or_null(n) as Node3D
	if node != null:
		node.visible = on


## Shut, looked into from the camp: lit as window_lights has the van (its guests up).
var _inview_lit := false


func _apply_light() -> void:
	if _env == null:
		return
	var lit := (_lights_on if _is_open else _inview_lit) and _grid_power_available
	match _time_state:
		TIME_DAY:
			_env.ambient_light_energy = lerpf(0.62, 0.9, _daylight)
			_env.ambient_light_color = Color(0.86, 0.84, 0.78).lerp(_sun_color, 0.15)
		TIME_EVENING:
			_env.ambient_light_energy = 0.32
			_env.ambient_light_color = Color(0.7, 0.56, 0.5)
		_:
			_env.ambient_light_energy = 0.04
			_env.ambient_light_color = Color(0.3, 0.34, 0.44)
	if _lamp != null:
		_lamp.light_energy = (1.15 if _time_state != TIME_DAY else 0.5) if lit else 0.0
		_lamp.visible = lit
	if _lamp_shade != null:
		_lamp_shade.emission_energy_multiplier = 0.9 if lit else 0.0
	var glow := 0.22 if _time_state == TIME_DAY else (0.08 if _time_state == TIME_EVENING else 0.0)
	for m in _window_mats:
		m.emission_energy_multiplier = glow


func _quad_mat(tex: String, glow: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var path := "res://assets/textury/camp/%s.png" % tex
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
		m.emission_enabled = true
		m.emission_texture = m.albedo_texture
		m.emission = Color(1, 1, 1)
		m.emission_energy_multiplier = glow
	return m


func _inward(yaw_deg: float) -> Vector3:
	return Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Vector3(0, 0, 1)


# ── room preparation (see scripts/interior_prep.gd) ──────────────────────────

var _bed_made_node: Node3D
var _table_nodes: Array = []
var _bed_room_key := ""


func set_room(room: Dictionary) -> void:
	var key := str(room.get("key", ""))
	var was: bool = bool(_prep._was_tidy.get("bed", false)) if key == _bed_room_key else true
	_prep.set_room(room)
	var made: bool = bool(_prep._was_tidy.get("bed", true))
	if _is_open and key == _bed_room_key and made and not was:
		_make_up_bed()
	else:
		_bed_made_node.visible = made
		for n in _table_nodes:
			(n as Node3D).visible = not made
	_bed_room_key = key


## The dinette made into the bed before your eyes: the table drops to the benches and is
## gone into them, the mattress settles, the blanket rolls out, the pillows plop down.
func _make_up_bed() -> void:
	_play("res://assets/sfx/caravan/bed_make.mp3", -6.0)
	var tw := create_tween()
	for n in _table_nodes:
		var node := n as Node3D
		var rest_y := node.position.y
		tw.parallel().tween_property(node, "position:y", rest_y - 0.24, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_callback(func() -> void:
			node.visible = false
			node.position.y = rest_y).set_delay(0.34)
	var made := _bed_made_node
	made.visible = true
	for c in made.get_children():
		var part := c as Node3D
		var rest_pos := part.position
		var rest_scale := part.scale
		if part.name.begins_with("BedMattress"):
			part.position = rest_pos + Vector3(0, 0.12, 0)
			tw.parallel().tween_property(part, "position", rest_pos, 0.26).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT).set_delay(0.3)
		elif part.name.begins_with("BedBlanket"):
			part.scale = Vector3(rest_scale.x, rest_scale.y, 0.05)
			tw.parallel().tween_property(part, "scale", rest_scale, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.45)
		elif part.name.begins_with("Pillow"):
			part.position = rest_pos + Vector3(0, 0.35, 0)
			tw.parallel().tween_property(part, "position", rest_pos, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT).set_delay(0.7 + randf() * 0.15)
	tw.parallel().tween_callback(_rock.bind(0.4)).set_delay(0.3)


func play_room_ready() -> void:
	_prep.play_room_ready()


func _update_torch(delta: float) -> void:
	if _torch == null:
		_torch = INTERIOR_TORCH.new()
		_torch.name = "Torch"
		add_child(_torch)
		_torch.setup(_interior_camera, _viewport, _interior_camera.get_parent() as Node3D, layer)
	_torch.update(delta, room_is_dark())


## After dusk with the lamp off (L) or no power.
func room_is_dark() -> bool:
	return _time_state != TIME_DAY and (not _lights_on or not _grid_power_available)
