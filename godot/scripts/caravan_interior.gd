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

## The room: length along x, width along z (the door wall is +z), height.
const L := 4.6
const W := 2.0
const H := 1.95
const DOOR_X := -1.25
const EYE := Vector3(DOOR_X + 0.1, 1.52, 0.22)
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
var _lv2_nodes: Array[String] = ["BunkLower", "Teddy", "Rug"]
var _lv3_nodes: Array[String] = ["BunkUpper", "BunkLadder", "TV", "Flowers", "FairyLights"]
var _lv1_nodes: Array[String] = ["EndCrate", "EndGas"]


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


func open_caravan(level: int = 1) -> void:
	if _viewport_container != null:
		RETRO_RENDER.apply_to(_viewport_container)
	_level = clampi(level, 1, 3)
	_apply_level()
	_apply_light()
	if _is_open:
		return
	_is_open = true
	visible = true
	_interior_camera.position = EYE
	_interior_camera.rotation_degrees = Vector3(EYE_PITCH_DEG, EYE_YAW_DEG, 0.0)
	_cam_base_rot = _interior_camera.rotation
	_look.reset()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func close_caravan() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	request_close.emit()


func _process(delta: float) -> void:
	if not _is_open or _interior_camera == null:
		return
	_tick_windows(delta)
	if not lodge_sleeping:
		var offset: Vector3 = _look.update(delta, INTERIOR_LOOK.cursor_of(get_viewport()), INTERIOR_LOOK.turn_axis())
		_interior_camera.rotation = _cam_base_rot + offset
	_update_torch(delta)
	if _exit_hint == null:
		_exit_hint = INTERIOR_LOOK.make_exit_hint(self)
	INTERIOR_LOOK.update_exit_hint(_exit_hint, get_viewport(), delta)
	if _brochure_hover():
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
	if INTERIOR_LOOK.is_exit_event(event, get_viewport()) and not (_prep.is_busy() and event is InputEventMouseButton):
		close_caravan()
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
	for w in _windows:
		w.update(_root, _interior_camera, WINDOW_PORTAL.room_to_world(a, w, FLOOR_UP) if a != null else Transform3D(), a != null, world, delta)


## The curtain under the pointer (a ray from the room's camera), null none.
func _curtain_under(screen: Vector2):
	if _viewport == null or _interior_camera == null:
		return null
	var size := get_viewport().get_visible_rect().size
	var local := Vector2(screen.x / size.x * float(_viewport.size.x), screen.y / size.y * float(_viewport.size.y))
	var from := _interior_camera.project_ray_origin(local)
	var q := PhysicsRayQueryParameters3D.create(from, from + _interior_camera.project_ray_normal(local) * 8.0)
	var hit := _viewport.find_world_3d().direct_space_state.intersect_ray(q)
	var n: Node = hit.get("collider", null)
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
	_root.add_child(_interior_camera)
	K.room(_root, Vector3(L, H, W), "caravan_floor", "caravan_veneer", "caravan_ceiling", 1.1, 0.7)
	K.skirting(_root, Vector3(L, H, W), "veneer_dark")
	var veneer := K.surface("caravan_veneer", 1.1)
	var veneer_dark := K.surface("veneer_dark", 0.8)
	var formica := K.surface("formica", 0.6, Color(0.96, 0.92, 0.82))
	var cushion := K.surface("velvet", 0.5, Color(0.92, 0.6, 0.36))
	# The door you came in by, and the windows (the caravan's own, curtains drawn half).
	var door := K.picture(_root, "caravan_door", Vector2(0.62, 1.55), Vector3(DOOR_X, 0.85, W * 0.5 - 0.004), 180.0, "Door")
	door.material_override = _quad_mat("caravan_door", 0.0)
	for wspec in [[Vector2(1.1, 0.62), Vector3(L * 0.5 - 0.004, 1.32, 0.0), -90.0], [Vector2(0.8, 0.5), Vector3(0.05, 1.45, -W * 0.5 + 0.004), 0.0],
			[Vector2(0.7, 0.5), Vector3(1.75, 1.42, W * 0.5 - 0.004), 180.0], [Vector2(0.62, 0.48), Vector3(-L * 0.5 + 0.004, 1.42, 0.35), 90.0]]:
		# The glass looks out of the caravan where it stands (scripts/ui/window_portal.gd),
		# a curtain to draw over it.
		var into := _inward(float(wspec[2]))
		var wp = WINDOW_PORTAL.make(self, _root, (wspec[1] as Vector3) + into * 0.01, -into, wspec[0], "curtain_floral", 192)
		_windows.append(wp)
		_room_weather().add_window(wp.quad)
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
	K.slab(_root, Vector3(0.34, 0.02, 0.3), Vector3(kx - 0.24, 0.9, kz), K.surface("steel_kitchen", 0.4), "Sink")
	K.slab(_root, Vector3(0.04, 0.2, 0.04), Vector3(kx - 0.24, 1.0, kz - 0.2), K.surface("galvanized", 0.4), "Tap")
	for bx: float in [0.2, 0.42]:
		var ring := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.08
		cyl.bottom_radius = 0.08
		cyl.height = 0.015
		cyl.radial_segments = 10
		ring.mesh = cyl
		ring.material_override = INTERIOR_PREP.flat(Color(0.12, 0.12, 0.12))
		ring.position = Vector3(kx + bx - 0.06, 0.905, kz)
		_root.add_child(ring)
	K.slab(_root, Vector3(0.5, 0.84, 0.52), Vector3(kx + 0.82, 0.42, kz), INTERIOR_PREP.flat(Color(0.9, 0.88, 0.82)), "Fridge")
	K.slab(_root, Vector3(0.04, 0.3, 0.03), Vector3(kx + 0.6, 0.56, kz + 0.27), K.surface("galvanized", 0.4), "FridgeHandle")
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
	K.slab(_root, Vector3(0.6, 0.4, 0.5), Vector3(ex, 0.2, -0.55), K.surface("cardboard", 0.5), "EndCrate")
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
	K.slab(_root, Vector3(0.16, 0.2, 0.12), Vector3(ex + 0.1, 0.58, -0.6), INTERIOR_PREP.flat(Color(0.62, 0.44, 0.26)), "Teddy")
	K.slab(_root, Vector3(2.4, 0.01, 0.7), Vector3(-0.2, 0.006, 0.12), K.surface("rug", 1.0), "Rug")
	var tv := K.prop(_root, "tv_small", Vector3(kx + 0.3, 0.9, kz - 0.06), 0.0, 0.7)
	if tv != null:
		tv.name = "TV"
	var flowers := Node3D.new()
	flowers.name = "Flowers"
	_root.add_child(flowers)
	var vase := MeshInstance3D.new()
	var vcyl := CylinderMesh.new()
	vcyl.top_radius = 0.05
	vcyl.bottom_radius = 0.04
	vcyl.height = 0.14
	vase.mesh = vcyl
	vase.material_override = INTERIOR_PREP.flat(Color(0.3, 0.5, 0.7))
	vase.position = Vector3(kx - 0.48, 0.97, kz)
	flowers.add_child(vase)
	for i in 4:
		K.slab(flowers, Vector3(0.05, 0.05, 0.05), Vector3(kx - 0.48 + (i % 2) * 0.04 - 0.02, 1.07 + (i >> 1) * 0.04, kz + (i % 2) * 0.03), INTERIOR_PREP.flat(Color(0.86, 0.12, 0.16)), "Petal")
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
	# Messy: the table up, the heap, a cushion on the floor; made: the bed (no table).
	_prep.register("bed", body, [heap, cushion_off, table, leg], [made])
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
	for wall in ["WallBack", "WallFront", "WallLeft", "WallRight"]:
		var mi := _root.get_node_or_null(wall) as MeshInstance3D
		if mi != null and mi.material_override is StandardMaterial3D:
			var mm := (mi.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
			mm.albedo_color = tint
			mi.material_override = mm


func _set_visible(n: String, on: bool) -> void:
	var node := _root.get_node_or_null(n) as Node3D
	if node != null:
		node.visible = on


func _apply_light() -> void:
	if _env == null:
		return
	var lit := _lights_on and _grid_power_available
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

func set_room(room: Dictionary) -> void:
	_prep.set_room(room)


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
