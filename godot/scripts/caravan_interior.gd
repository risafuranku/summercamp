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
## One world (W26): the room stands in its van in the camp's own world
## (scripts/one_world_room.gd); the van it stands in has its shell left out by the room's
## eye (and by the eye looking in from the camp) and casts no shadow then, the room's own
## walls and windows doing it.
const ONE_WORLD_ROOM = preload("res://scripts/one_world_room.gd")
const DAY_FILL := 0.35
const DAY_LAMP := 0.4
const DAY_EXPOSURE := 1.3
var _eye: CameraAttributesPractical
var _probe: ReflectionProbe
var _dry: GPUParticlesCollisionBox3D
var _walls_t := 0.0
var _host: Node3D
## [node, its layers, its cast_shadow] of the host van's shell.
var _host_shell: Array = []

const TIME_DAY: int = 0
const TIME_EVENING: int = 1
const TIME_NIGHT: int = 2
const INTERIOR_RENDER_MIN_SIZE := Vector2i(960, 540)

## The room: length along x, width along z (the door wall is +z), height: caravan_layout,
## the van's body built round it (building_models.caravan), so its windows from outside and
## in are the same windows (_update_inview).
const CVL = preload("res://scripts/caravan_layout.gd")
const L: float = CVL.L
const W: float = CVL.W
const H: float = CVL.H
const DOOR_X: float = CVL.DOOR_X
## Where you stand: in the aisle a step in from the door, near the kitchen, so the fridge
## opened is seen into (playtest 25. 10.: "stand nearer the fridge").
const EYE := Vector3(0.25, 1.52, 0.42)
## The van's windows where the model has them (caravan_layout): [glass size, centre, yaw].
const WINDOWS: Array = CVL.WINDOWS
## The model's floor is this high over the ground (building_models.caravan y0).
const VAN_FLOOR: float = CVL.VAN_FLOOR
## The door: its leaf on the hinge, how far it opens, the camp's eye on the doorstep
## (the room's coordinates: the ground is VAN_FLOOR below its floor).
const DOOR_W: float = CVL.DOOR_W
const DOOR_H: float = CVL.DOOR_H
const DOOR_OPEN_DEG := -104.0
## In the doorway, in the wall's thickness: the walk in starts here, the walk out ends here
## looking out through the doorway's view of the camp.
const STEP_EYE := Vector3(DOOR_X + 0.04, 1.18, W * 0.5 + 0.06)
const WALL_T: float = CVL.WALL_T
## The camp's eye when there is no warden: the walk in starts from it, the walk out ends in
## it (_camp_fov: the warden's Options since 21. 10.; a fixed 56 here jumped wider as the
## camp took over at the doorstep, playtest 25. 10.).
const CAMP_FOV := 72.0
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
	ONE_WORLD_ROOM.camp_view(get_tree(), false)
	_viewport.audio_listener_enable_3d = true
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
	_door_anchor = null
	_glint.clear()
	if not _is_open:
		return
	_kill_walk()
	_walking = false
	_leaving = false
	_is_open = false
	visible = false
	# Shut, the room is drawn only for the camp looking in (_update_inview).
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.audio_listener_enable_3d = false
	ONE_WORLD_ROOM.camp_view(get_tree(), true)
	_door_pivot.rotation_degrees.y = 0.0
	if _life != null:
		_life.on_leave()
	_interior_camera.fov = ROOM_FOV
	_set_smash_heard(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	request_close.emit()


func _process(delta: float) -> void:
	if _interior_camera == null:
		return
	if not _is_open:
		_update_inview(delta)
	_bind_one_world(delta)
	if not _is_open:
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
	# What you can use glints under the pointer, as in every room (the user 4. 11.: "check
	# the hovers everywhere"): the brochure, a curtain, the van's things.
	var under := _collider_under(get_viewport().get_mouse_position())
	var lit: Array = []
	if _brochure_hover():
		lit = [_brochure, _brochure_cover]
	elif _life != null and _life.is_thing(under):
		lit = _meshes_under(under)
	else:
		var wp = _curtain_under(get_viewport().get_mouse_position())
		if wp != null and wp.curtain != null:
			lit = wp.curtain.meshes
	_glint.show_on(lit)
	if not lit.is_empty():
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
	# Esc or the way out behind you leaves (but not a
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
	if n == null:
		n = _door_anchor
	return n as Node3D if n != null and is_instance_valid(n) and (n as Node3D).is_inside_tree() else null


## The way through the door (scripts/ui/door_through.gd): the van as this one is, its door
## where the model has it; the van walks its own way in from your eye in the doorway.
var _door_anchor: Node3D


func door_ready(structure: Node3D) -> void:
	_door_anchor = structure
	if _inview_van != structure:
		_release_inview()
		_take_inview(structure)
	# Into this van, now: the way in is worked out from where the room stands (door_spec).
	_bind_one_world(0.0)


func door_spec(structure: Node3D) -> Dictionary:
	var panes := _panes_of(structure)
	if panes.is_empty() or _root == null:
		return {}
	var model := (panes[0] as Node3D).get_parent() as Node3D
	# (Its own leaf out of the doorway while you come in by the van's: the walk in swings it
	# open as it starts, _walk_in.)
	var leaf: Array = _door_pivot.get_children() if _door_pivot != null else []
	return {"root": _root, "at": Vector3(DOOR_X, 0.0, W * 0.5 + 0.026), "out": Vector3(0, 0, 1), "size": Vector2(DOOR_W, DOOR_H),
		"inner": WALL_T + 0.026, "leaf": leaf, "in_camp": model.global_transform * Transform3D(Basis(), Vector3(0.0, VAN_FLOOR, 0.0)), "one_world": true}


func door_walk_in(from: Transform3D, fov: float) -> void:
	_walk_in(from, fov)


func _tick_windows(delta: float) -> void:
	var a := _anchor()
	var world: World3D = a.get_world_3d() if a != null else null
	# One view of the camp for all of them (window_shared_view.gd), drawn while one of
	# them is in sight and open.
	for w in _windows:
		w.update(_root, _interior_camera, WINDOW_PORTAL.room_to_world(a, w, FLOOR_UP) if a != null else Transform3D(), a != null and _in_sight(w), world, delta, a)
	_tick_smashed()
	if _door_view != null:
		# (Drawn from the start of the walk out: it is ready when the door swings open.)
		_door_view.update(_root, _interior_camera, WINDOW_PORTAL.room_to_world(a, _door_view, FLOOR_UP) if a != null else Transform3D(), a != null and (_door_open() > 0.02 or _leaving), world, delta, a)


## The window the mushroom granny smashed (mess_rules CARNAGE_WALL "smashed"; Richard
## 3. 11.: "vyražené okno, kterým je vidět ven"): the middle one of the side away from the
## door. While its mess is there its glass is gone but for the shards in the frame
## (interior_prep.smashed_window) and the outside is heard through it.
const SMASH_WINDOW := 6
var _smash_mess: Node3D
var _smash_seek := 0
var _smash_heard := false


func _tick_smashed() -> void:
	if _smash_mess == null or not is_instance_valid(_smash_mess) or not _smash_mess.is_inside_tree():
		_smash_mess = null
		_smash_seek -= 1
		if _smash_seek <= 0:
			_smash_seek = 20
			_smash_mess = _root.find_child("Mess_smashed", true, false) as Node3D
	var on := _smash_mess != null and _smash_mess.is_visible_in_tree()
	if _windows.size() > SMASH_WINDOW:
		var sw = _windows[SMASH_WINDOW]
		INTERIOR_PREP.smashed_window(sw.quad, null, sw.size, on)
		(sw.quad as MeshInstance3D).visible = not on
	_set_smash_heard(on and _is_open)


func _set_smash_heard(on: bool) -> void:
	if on == _smash_heard:
		return
	_smash_heard = on
	var im := get_parent()
	var am = im.get("_audio_manager") if im != null else null
	if am != null and am.has_method("set_room_leak"):
		am.set_room_leak(0.35 if on else 0.0)


## Is the window's glass on the screen of `eye` (the room's camera unless given; any
## corner in front of the eye and inside its picture of `px`, or `margin` of its width
## past the edges)?
func _in_sight(w, eye: Camera3D = null, px := Vector2.ZERO, margin := 0.35) -> bool:
	if eye == null:
		eye = _interior_camera
		px = Vector2(_viewport.size)
	# (A good way past the edges: it is drawn before it turns into view, not a frame late.)
	var vp_rect := Rect2(Vector2.ZERO, px).grow(px.x * margin)
	for i in 4:
		var c := Vector3((float(i % 2) - 0.5) * w.size.x, (float(i / 2) - 0.5) * w.size.y, 0.0)
		var p: Vector3 = _root.global_transform * (w.frame * c)
		if not eye.is_position_behind(p) and vp_rect.has_point(eye.unproject_position(p)):
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


## The guests' hands on the curtains while you look in from the camp (window_lights): the
## room standing in `van`, its curtains as its panes have them.
func guest_curtains(van: Node3D, shut: Array) -> void:
	if van != _inview_van or _is_open:
		return
	for i in mini(shut.size(), _windows.size()):
		var cur = _windows[i].curtain
		if cur != null:
			cur.target = 0.0 if bool(shut[i]) else 1.0


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

## (40 since 4. 11.: past it the van's cube shows it, the live view fades in over that.)
const INVIEW_RANGE := 40.0
## Nearer than this the windows across the van show the camp beyond it (farther they are a
## few pixels: dark glass).
const INVIEW_THROUGH_M := 10.0
var _inview_vp: SubViewport
var _inview_cam: Camera3D
var _inview_mat: ShaderMaterial
var _inview_van: Node3D
var _inview_panes: Array = []
var _inview_scan_t := 0.0
var _inview_light_t := 0.0
var _vans: Array = []


# ── one world (W26) ──────────────────────────────────────────────────────────

## The room in the van you are in, or (out in the camp) in the one you look in at; none, it
## is put away (its lamp with it). That van's shell is left out by the room's eye and casts
## no shadow while the room is in it; its light inside is its probe's; heard from the camp
## its sounds come through the walls.
func _bind_one_world(delta: float) -> void:
	if _root == null or _cube_baking:
		return
	# (A van replaced by its upgrade: the old one freed under us.)
	# (A freed van equals null: `v != null` let it through to the typed line below.)
	var v = _anchor() if _is_open else _inview_van
	if not is_instance_valid(v) or not (v as Node3D).is_inside_tree():
		v = null
	var van: Node3D = v
	_host_shell_of(van)
	_host_doorways(van, delta)
	if _root.visible != (van != null or _is_open):
		_root.visible = van != null or _is_open
	if van != null:
		var panes := _panes_of(van)
		if not panes.is_empty():
			var model := (panes[0] as Node3D).get_parent() as Node3D
			var x: Transform3D = model.global_transform * Transform3D(Basis(), Vector3(0.0, VAN_FLOOR, 0.0))
			if not _root.transform.is_equal_approx(x):
				_root.transform = x
	if _probe != null and _env != null:
		_probe.ambient_color = _env.ambient_light_color
		_probe.ambient_color_energy = _env.ambient_light_energy
	_walls_t -= delta
	if _walls_t <= 0.0:
		_walls_t = 0.5
		ONE_WORLD_ROOM.sounds_through_walls(_root, not _is_open)
		ONE_WORLD_ROOM.own_layer(_root)


func _host_shell_of(van: Node3D) -> void:
	if _host != null and not is_instance_valid(_host):
		_host = null
	if van == _host:
		return
	for e in _host_shell:
		var g = e[0]
		if g != null and is_instance_valid(g):
			(g as GeometryInstance3D).layers = int(e[1])
			(g as GeometryInstance3D).cast_shadow = int(e[2])
	_host_shell.clear()
	_host = van
	if van == null:
		return
	var panes := _panes_of(van)
	if panes.is_empty():
		return
	var model := (panes[0] as Node3D).get_parent() as Node3D
	# (Below the model too: the door leaf goes onto its hinge.)
	for c in model.find_children("*", "GeometryInstance3D", true, false):
		var g := c as GeometryInstance3D
		if not (g.has_meta("van_shell") or g.has_meta("lit_window")):
			continue
		_host_shell.append([g, g.layers, g.cast_shadow])
		g.layers = ONE_WORLD_ROOM.GLASS_LAYER
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


var _way_host: Node3D
var _host_ways: Array = []
var _ways_t := 0.0


## The dark doorways of the van the room stands in, out of the way (one_world_room).
func _host_doorways(host: Node3D, delta: float) -> void:
	if _way_host != null and not is_instance_valid(_way_host):
		_way_host = null
	if host != _way_host:
		ONE_WORLD_ROOM.hide_ways(_host_ways, false)
		_host_ways = []
		_way_host = host
		_ways_t = 0.0
	if _way_host == null:
		return
	_ways_t -= delta
	if _ways_t <= 0.0:
		_ways_t = 0.5
		_host_ways = ONE_WORLD_ROOM.doorways(_way_host)
	ONE_WORLD_ROOM.hide_ways(_host_ways, true)


func _camp_weather() -> int:
	var scene := get_tree().current_scene if is_inside_tree() else null
	return int(scene.get("_weather_state")) if scene != null and scene.get("_weather_state") != null else 0


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
	# (Its cubes being drawn: the van is each tier in turn.)
	if _cube_baking:
		return
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
	var room_in_camp: Transform3D = model.global_transform * Transform3D(Basis(), Vector3(0.0, VAN_FLOOR, 0.0))
	var to_room: Transform3D = _root.global_transform * room_in_camp.affine_inverse()
	var t := to_room * cam.global_transform
	_inview_cam.global_transform = Transform3D(t.basis.orthonormalized(), t.origin)
	_inview_cam.fov = cam.fov
	_inview_cam.keep_aspect = cam.keep_aspect
	# The camp's eye looking up or down is a shifted frustum (player_controller): the same.
	_inview_cam.projection = cam.projection
	var nk := _inview_cam.near / maxf(cam.near, 0.001)
	_inview_cam.size = cam.size * nk
	_inview_cam.frustum_offset = cam.frustum_offset * nk
	var px := Vector2i(cam.get_viewport().get_visible_rect().size)
	if _inview_vp.size != px and px.x > 0:
		_inview_vp.size = px
	# Looking in through a window on this side: the ones across the van (their glass turned
	# to the eye) show the camp beyond it, the room's shared view put back at the camp's
	# own eye with the van left out of it; the ones on this side are looked through, their
	# glass hidden (the openings in the walls, _cut_walls).
	# (Near enough to see through, and only while one of them is in sight: it draws the
	# camp a second time.)
	# (One world: through the van's windows the camp itself, the room's glass its own.)
	for w in _windows:
		w.update(_root, _inview_cam, room_in_camp, false, null, delta, _inview_van)
	_inview_light_t -= delta
	if _inview_light_t <= 0.0:
		_inview_light_t = 0.5
		_inview_room_light()


# -- the van drawn once into a cube for its windows from far off (scripts/ui/room_cube.gd;
# as cabin_interior's: each tier once, the lamp on, by day; window_lights lights it and the
# near van's live view fades in over it). --

const ROOM_CUBE = preload("res://scripts/ui/room_cube.gd")
var cubes: Dictionary = {}
var _cube_baking := false


func bake_cubes() -> void:
	if _cube_baking or not cubes.is_empty() or _root == null or _viewport == null or _is_open:
		return
	_cube_baking = true
	_release_inview()
	var was_level := _level
	var was_state := _time_state
	var was_lights := _lights_on
	# Drawn far over the camp (the room is in the camp's world; under the land nothing is
	# drawn): nothing round it, past the camp's eye's reach.
	_root.transform = Transform3D(Basis(), Vector3(0.0, ONE_WORLD_ROOM.BAKE_UP, 0.0))
	for lv in [1, 2, 3]:
		if _is_open:
			break
		_level = lv
		_apply_level()
		_lights_on = true
		set_time_state(TIME_DAY)
		_apply_light()
		cubes[lv] = ROOM_CUBE.bake(self, _viewport.find_world_3d(), _root.global_transform * cube_eye(lv), 0xFFFFF & ~INVIEW_HIDE_LAYER & ~(1 << 19))
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
	_level = was_level
	_apply_level()
	_lights_on = was_lights
	set_time_state(was_state)
	_apply_light()
	_cube_baking = false


func cube_eye(_lv: int) -> Vector3:
	return Vector3(0.0, 1.05, 0.0)


func cube_box(_lv: int) -> AABB:
	return AABB(Vector3(-L * 0.5, 0.0, -W * 0.5), Vector3(L, H, W))


func cube_spec(structure: Node3D) -> Dictionary:
	var t := str(structure.get_meta("building_type", "caravan_1"))
	var lv := clampi(int(t.right(1)) if t.right(1).is_valid_int() else 1, 1, 3)
	var panes := _panes_of(structure)
	if not cubes.has(lv) or _cube_baking or panes.is_empty():
		return {}
	var model := (panes[0] as Node3D).get_parent() as Node3D
	return {"tex": cubes[lv], "box": cube_box(lv), "eye": cube_eye(lv),
		"world_to_room": (model.global_transform * Transform3D(Basis(), Vector3(0.0, VAN_FLOOR, 0.0))).affine_inverse()}


func _fade_live(mat: ShaderMaterial, to: float) -> void:
	var from := float(mat.get_shader_parameter("live")) if mat.get_shader_parameter("live") != null else 0.0
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("live", v), from, to, 0.4)


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
		# Its cube's pane (window_lights): the live room fades in over it.
		var cube := mi.get_meta("wl_cube") as ShaderMaterial if mi.has_meta("wl_cube") else null
		if cube != null:
			mi.remove_meta("inview_was")
			mi.material_override = cube
			cube.set_shader_parameter("room_tex", _inview_vp.get_texture())
			_fade_live(cube, 1.0)
			continue
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
		var cube := mi.get_meta("wl_cube") as ShaderMaterial if mi.has_meta("wl_cube") else null
		if cube != null:
			cube.set_shader_parameter("live", 0.0)
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
	var bright := 1.0 if state == TIME_NIGHT else (0.8 if state == TIME_EVENING else 0.62)
	_inview_mat.set_shader_parameter("bright", bright)
	_inview_mat.set_shader_parameter("glow", 0.0)
	for p in _inview_panes:
		var cube := (p as Node).get_meta("wl_cube") as ShaderMaterial if is_instance_valid(p) and (p as Node).has_meta("wl_cube") else null
		if cube != null:
			cube.set_shader_parameter("bright", bright)


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
	# (The camp's own world now, the room in its van: near is all it needs.)
	_inview_cam.far = 14.0
	_inview_cam.cull_mask = 0xFFFFF & ~INVIEW_HIDE_LAYER & ~ONE_WORLD_ROOM.GLASS_LAYER
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
	# (One world: the doorway is an opening onto the camp itself.)
	_door_view.set_one_world(null)
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


## The camp eye's FOV now (the warden's Options), for the walk in to start in and the walk
## out to end in.
func _camp_fov() -> float:
	var scene := get_tree().current_scene if is_inside_tree() else null
	var p = scene.get("_player") if scene != null else null
	var cam = p.get("_camera") if p != null else null
	return float((cam as Camera3D).fov) if cam is Camera3D else CAMP_FOV


## How far the door stands open, 0 shut .. 1 wide.
func _door_open() -> float:
	return clampf(_door_pivot.rotation_degrees.y / DOOR_OPEN_DEG, 0.0, 1.0) if _door_pivot != null else 0.0


## In from the doorstep (interior_manager has walked you up to the door and opened it);
## `from` (global) where your eye was in the doorway when you walked up to it.
func _walk_in(from := Transform3D(), from_fov := -1.0) -> void:
	_kill_walk()
	_walking = true
	_door_pivot.rotation_degrees.y = DOOR_OPEN_DEG
	var start_pos := STEP_EYE
	var start_rot := Vector3(-0.04, 0.0, 0.0)
	if from != Transform3D() and _interior_camera.get_parent() is Node3D:
		var l := (_interior_camera.get_parent() as Node3D).global_transform.affine_inverse() * from
		start_pos = l.origin
		start_rot = l.basis.orthonormalized().get_euler(EULER_ORDER_YXZ)
	_interior_camera.fov = from_fov if from_fov > 0.0 else _camp_fov()
	_interior_camera.position = start_pos
	_interior_camera.rotation = start_rot
	_walk = WALK_PATH.play(self, _interior_camera, [
		{"pos": start_pos, "rot": start_rot},
		{"pos": Vector3(DOOR_X + 0.06, 1.46, W * 0.5 - 0.24), "rot": Vector3(-0.07, deg_to_rad(-38.0), 0.0)},
		{"pos": EYE, "rot": Vector3(deg_to_rad(EYE_PITCH_DEG), deg_to_rad(EYE_YAW_DEG), 0.0)},
	], 1.2)
	_walk.parallel().tween_property(_interior_camera, "fov", ROOM_FOV, 0.8)
	_walk.parallel().tween_callback(_play.bind(SFX_STEP, -8.0)).set_delay(0.12)
	_walk.parallel().tween_callback(_rock.bind(0.6)).set_delay(0.18)
	_walk.parallel().tween_property(_door_pivot, "rotation_degrees:y", 0.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(0.72)
	_walk.parallel().tween_callback(_play.bind(SFX_DOOR_SHUT, -4.0)).set_delay(1.12)
	_walk.tween_callback(_walk_done)


## The van's leaf (door_anim's) open for the walk out: the camp beyond it, the room's own
## leaf swinging in with it.
func _open_van_door() -> void:
	var a := _anchor()
	if a == null:
		return
	var da = load("res://scripts/attractions/door_anim.gd")
	for d in da.find_doors(a):
		da.open(d, 4.0)


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
	# The van's own leaf with it: the room stands in the van, the camp is right out there.
	_walk.parallel().tween_callback(_open_van_door).set_delay(0.34)
	_walk.parallel().tween_callback(_play.bind(SFX_STEP, -8.0)).set_delay(0.95)
	_walk.parallel().tween_callback(_rock.bind(-0.5)).set_delay(1.0)
	_walk.parallel().tween_property(_interior_camera, "fov", _camp_fov(), 0.7).set_delay(0.55)
	_walk.tween_callback(func() -> void:
		_walking = false
		handoff_eye = _doorway_eye()
		close_caravan())


## Where the camp's eye was in the walk out's last frame (the doorway's view drew the camp
## from there): the camp takes the walk on from that very point (interior_manager.
## _on_caravan_closed); INF when it could not tell. (The camp started half a metre off
## it: the near grass jumped as the doorway's picture gave way, playtest 25. 10.)
var handoff_eye := Vector3.INF


func _doorway_eye() -> Vector3:
	var a := _anchor()
	if a == null or _door_view == null or _root == null:
		return Vector3.INF
	var xf: Transform3D = WINDOW_PORTAL.room_to_world(a, _door_view, FLOOR_UP)
	return xf * (_root.global_transform.affine_inverse() * _interior_camera.global_position)


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


const HOVER_GLINT = preload("res://scripts/ui/hover_glint.gd")
var _glint = HOVER_GLINT.new()


## The meshes of the thing a click box is for: under its parent, the box's own size round it.
func _meshes_under(body: Node) -> Array:
	var out: Array = []
	var p := body.get_parent() if body != null else null
	if p == null:
		return out
	for m in p.find_children("*", "MeshInstance3D", true, false):
		if (m as Node3D).is_visible_in_tree():
			out.append(m)
	return out


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
	# The camp's own world: the room stands in its van there (_bind_one_world).
	ONE_WORLD_ROOM.viewport(_viewport)
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
	# (The camp's world has its own environment: these are the room's numbers, its probe's
	# ambient, _bind_one_world.)


func _build_room() -> void:
	var K := INTERIOR_KIT
	_root = Node3D.new()
	_root.name = "CaravanRoom"
	_viewport.add_child(_root)
	_interior_camera = Camera3D.new()
	_interior_camera.name = "CaravanCamera"
	_interior_camera.fov = 70.0
	_interior_camera.near = 0.05
	_interior_camera.current = true
	_eye = ONE_WORLD_ROOM.eye(_interior_camera)
	_interior_camera.position = EYE
	_interior_camera.rotation_degrees = Vector3(EYE_PITCH_DEG, EYE_YAW_DEG, 0.0)
	# The camera on a rig that rocks with the van on its springs (_rock); still, it is the
	# room's own space (lodge_bed and the torch read the camera's parent).
	_cam_rig = Node3D.new()
	_cam_rig.name = "CamRig"
	_root.add_child(_cam_rig)
	_cam_rig.add_child(_interior_camera)
	_probe = ONE_WORLD_ROOM.probe(_root, "VanLight")
	_dry = ONE_WORLD_ROOM.dry(_root, "Dry")
	ONE_WORLD_ROOM.fit(_probe, _dry, Vector3(-L * 0.5, 0.0, -W * 0.5), Vector3(L * 0.5, H + 0.1, W * 0.5))
	var shell: Dictionary = K.room(_root, Vector3(L, H, W), "caravan_floor", "caravan_veneer", "caravan_ceiling", 1.1, 0.7)
	# The walls with the doorway (you walk in and out through it) and the windows cut out.
	_cut_walls(shell)
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
		# Glass in the opening, the camp itself behind it, the rain on it; for the inside.
		wp.set_one_world(ONE_WORLD_ROOM.clear_glass())
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
	K.cutout(_root, "gas_bottle", Vector2(0.26, 0.54), Vector3(ex, 0.0, 0.5), 0.0, true, "EndGas")
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
	# The window she smashed (mess_rules CARNAGE_WALL "smashed"): on the inside of its glass,
	# its glass on the floor (at 0) under it.
	if _windows.size() > SMASH_WINDOW:
		var sw = _windows[SMASH_WINDOW]
		var sout: Vector3 = sw.outward
		_prep.add_spot("win", _root, sw.frame.origin - sout * 0.03, atan2(-sout.x, -sout.z), true, 0.0)
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
	var mm := INTERIOR_KIT.surface("cv_wallpaper" if _level >= 3 else "caravan_veneer", 1.1).duplicate() as StandardMaterial3D
	mm.albedo_color = tint
	for wall in _walls:
		if is_instance_valid(wall):
			(wall as MeshInstance3D).material_override = mm
	if _life != null:
		_life.apply_level(_level)


## The van's walls (_cut_walls), the pieces round its openings.
var _walls: Array = []


## The four walls with their openings cut out: the doorway and every window (its glass,
## the window's portal, sits just inside). From the camp the windows look into the room
## through them (_update_inview); solid, every window showed the boards of the wall
## from outside (playtest 25. 10.: "the caravan's windows do not work from outside").
func _cut_walls(shell: Dictionary) -> void:
	var holes := {"front": [], "back": [], "left": [], "right": []}
	(holes["front"] as Array).append([DOOR_X - DOOR_W * 0.5, DOOR_X + DOOR_W * 0.5, 0.0, 0.04 + DOOR_H])
	for wspec in WINDOWS:
		var g: Vector2 = wspec[0]
		var c: Vector3 = wspec[1]
		var side := ("right" if c.x > 0.0 else "left") if absf(c.x) > L * 0.5 - 0.05 else ("front" if c.z > 0.0 else "back")
		var along := c.z if side == "right" or side == "left" else c.x
		(holes[side] as Array).append([along - g.x * 0.5, along + g.x * 0.5, c.y - g.y * 0.5, c.y + g.y * 0.5])
	var t := WALL_T
	for side: String in holes:
		var mat: Material = (shell[side] as MeshInstance3D).material_override
		(shell[side] as Node).free()
		var ends := side == "right" or side == "left"
		var i := 0
		for r in _wall_pieces((W if ends else L) * 0.5, H, holes[side]):
			var a := (float(r[0]) + float(r[1])) * 0.5
			var y := (float(r[2]) + float(r[3])) * 0.5
			var la := float(r[1]) - float(r[0])
			var ly := float(r[3]) - float(r[2])
			var pos := Vector3(a, y, (W + t) * 0.5 * (1.0 if side == "front" else -1.0))
			var sz := Vector3(la, ly, t)
			if ends:
				pos = Vector3((L + t) * 0.5 * (1.0 if side == "right" else -1.0), y, a)
				sz = Vector3(t, ly, la)
			_walls.append(INTERIOR_KIT.slab(_root, sz, pos, mat, "Wall%s%d" % [side.capitalize(), i]))
			i += 1


## A wall `half` each way along it and `h` high, less its openings ([from, to, bottom, top]
## along it): the pieces left, [from, to, bottom, top] each (strips between the openings'
## edges, the parts over and under an opening in its strip).
static func _wall_pieces(half: float, h: float, holes: Array) -> Array:
	var cuts: Array = [-half, half]
	for hl in holes:
		cuts.append(clampf(float(hl[0]), -half, half))
		cuts.append(clampf(float(hl[1]), -half, half))
	cuts.sort()
	var out: Array = []
	for i in cuts.size() - 1:
		var a0: float = cuts[i]
		var a1: float = cuts[i + 1]
		if a1 - a0 < 0.002:
			continue
		var mid := (a0 + a1) * 0.5
		var lo := 0.0
		var spans: Array = []
		for hl in holes:
			if mid > float(hl[0]) and mid < float(hl[1]):
				spans.append([float(hl[2]), float(hl[3])])
		spans.sort_custom(func(p, q) -> bool: return float(p[0]) < float(q[0]))
		for sp in spans:
			if float(sp[0]) - lo > 0.002:
				out.append([a0, a1, lo, float(sp[0])])
			lo = maxf(lo, float(sp[1]))
		if h - lo > 0.002:
			out.append([a0, a1, lo, h])
	return out


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
	# One world: the day comes in through the windows itself; while it does the room's fill
	# and its lamp go down a little and the eye opens.
	var dw: Vector2 = ONE_WORLD_ROOM.day_of(_daylight, get_tree(), _camp_weather())
	_env.ambient_light_energy *= lerpf(1.0, DAY_FILL, dw.x)
	if _lamp != null:
		_lamp.light_energy *= lerpf(1.0, DAY_LAMP, dw.y)
	if _eye != null:
		_eye.exposure_multiplier = lerpf(1.0, DAY_EXPOSURE, dw.y)


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
