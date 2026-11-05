extends CanvasLayer

const RETRO_RENDER = preload("res://scripts/retro_render.gd")
## The tent's cross-section: floor half-width and ridge height (metres).
const TENT_HALF_WIDTH := 0.98
const TENT_RIDGE_HEIGHT := 1.26
const INTERIOR_LOOK = preload("res://scripts/interior_look.gd")
const INTERIOR_TORCH = preload("res://scripts/ui/interior_torch.gd")
## Your torch, in here when it is dark: it shines where the cursor points.
var _torch: Node
const INTERIOR_PREP = preload("res://scripts/interior_prep.gd")
const INTERIOR_KIT = preload("res://scripts/interior_kit.gd")
const DOOR_ANIM = preload("res://scripts/attractions/door_anim.gd")
const ROOM_WEATHER = preload("res://scripts/ambient/room_weather.gd")
## One world (W26): the room stands in its tent in the camp's own world, its front gable in
## the canvas's doorway (scripts/one_world_room.gd, building_models.TENT_DOORWAY).
const ONE_WORLD_ROOM = preload("res://scripts/one_world_room.gd")
var _probe: ReflectionProbe
var _dry: GPUParticlesCollisionBox3D
var _walls_t := 0.0
## The room's floor over the canvas's foot: the tent stands 5 cm into the ground and the
## ground is not flat (the grass came up through the groundsheet, the user 5. 11.).
const TENT_LIFT := 0.1
## The doorway (TentDoorWay) of the tent the room stands in, and its layers before.
var _host_way: MeshInstance3D
## The tent you are coming to by its door (door_ready), and when.
var _door_tent: Node3D
var _door_tent_ms := -100000
## Node name prefix -> [camp texture, metres per repeat] (world mapped, see interior_kit).
const SURFACES := {
	"FloorMat": ["tent_floor", 0.8], "LeftWall": ["tarp_canvas", 0.9], "RightWall": ["tarp_canvas", 0.9],
	"BackWall": ["tarp_canvas", 0.9], "FrontWall": ["tarp_canvas", 0.9], "CeilingRidge": ["planks_dark", 0.5],
	"ZipLine": ["tarp_canvas", 0.4], "SleepingBag": ["blanket_check", 0.5], "Pillow": ["mattress", 0.4],
	"Rug": ["rug", 1.1], "MiniTable": ["knotty_pine", 0.5], "MiniShelf": ["knotty_pine", 0.5], "DoorRoll": ["tarp_canvas", 0.4], "ZipHandle": ["galvanized", 0.2],
}

signal room_task_completed(task_id: String)
signal request_close
signal request_upgrade

const INTERIOR_BARREL_SHADER = preload("res://materials/interior_barrel_post.gdshader")
const TEXTURE_STYLE_SCRIPT = preload("res://scripts/texture_style.gd")
const HOST_QUIET_TEXTURE = preload("res://assets/textury/npc/host1.png")
const HOST_DRUNK_TEXTURE = preload("res://assets/textury/npc/host2.png")
const HOST_CHEAP_TEXTURE = preload("res://assets/textury/npc/host3.png")

const TIME_DAY: int = 0
const TIME_EVENING: int = 1
const TIME_NIGHT: int = 2
const INTERIOR_RENDER_MIN_SIZE := Vector2i(960, 540)
const TENT_GUEST_SPRITE_PIXEL_SIZE := 0.0030
const TENT_GUEST_TARGET_HEIGHT := 1.30
const TENT_GUEST_STAND_POINTS := [
	Vector3(0.24, 0.66, -0.10),
	Vector3(-0.12, 0.66, -0.26),
]

var _is_open: bool = false
var _tent_level: int = 1
var _time_state: int = TIME_DAY
var _is_day_mode: bool = true
var _daylight_factor: float = 0.0
var _sunlight_color: Color = Color(1.0, 0.95, 0.84)

var _viewport_container: SubViewportContainer
var _viewport: SubViewport
var _interior_camera: Camera3D
var _tent_root: Node3D
var _guest_visual_root: Node3D
var _guest_occupants: Array = []
var _tent_env: Environment
var _tent_light: OmniLight3D
var _grid_power_available: bool = true
var _barrel_overlay: ColorRect
var _cam_base_rot: Vector3 = Vector3.ZERO
## Kneeling in a two-man tent: you can turn to the walls, not past them.
var _look = INTERIOR_LOOK.new(180.0, 24.0, 36.0)
## Lying in this room's bed (scripts/lodge_bed.gd has the camera): no looking round,
## no leaving, no clicks till you are up.
var lodge_sleeping := false
var _exit_hint: Control

# Screen-space zones for click detection.
var _catalog_mesh: MeshInstance3D
var _weather
var _prep = INTERIOR_PREP.new()

var _level2_nodes: Array[String] = [
	"LanternHook/LanternStem",
	"LanternHook/LanternBody",
	"StorageCrate",
]
var _level3_nodes: Array[String] = [
	"Rug",
	"MiniTable",
	"MiniShelf",
]
var _texture_style


func _ready() -> void:
	_texture_style = TEXTURE_STYLE_SCRIPT.new()
	# Under the HUD (65), whose messages show over a room.
	layer = 56
	visible = false
	_build_viewport()
	_sync_viewport_to_window()
	_build_tent_room()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_sync_viewport_to_window()


func is_open() -> bool:
	return _is_open


func set_is_day(is_day: bool) -> void:
	set_time_state(TIME_DAY if is_day else TIME_NIGHT)


func set_time_state(new_state: int) -> void:
	_time_state = int(clamp(new_state, TIME_DAY, TIME_NIGHT))
	_is_day_mode = (_time_state != TIME_NIGHT)
	_apply_time_profile()


func set_daylight_profile(daylight_factor: float, sun_color: Color, _ambient_color: Color, _ambient_energy: float) -> void:
	_daylight_factor = clampf(daylight_factor, 0.0, 1.0)
	_sunlight_color = sun_color
	_apply_time_profile()


func set_grid_power_available(power_available: bool) -> void:
	_grid_power_available = power_available
	_apply_time_profile()


func set_guest_occupants(entries: Array) -> void:
	_guest_occupants.clear()
	for entry_any in entries:
		if entry_any is Dictionary:
			_guest_occupants.append((entry_any as Dictionary).duplicate(true))
	_refresh_guest_visuals()


func open_tent(level: int = 1) -> void:
	# Registered before it was in the tree (size 0, shrink 1): the low resolution now.
	if _viewport_container != null:
		RETRO_RENDER.apply_to(_viewport_container)
	if _interior_camera == null:
		return
	_tent_level = int(clamp(level, 1, 3))
	if _is_open:
		_apply_level_variant()
		_apply_time_profile()
		_refresh_guest_visuals()
		return
	_release_inview()
	_is_open = true
	visible = true
	ONE_WORLD_ROOM.camp_view(get_tree(), false)
	_viewport.audio_listener_enable_3d = true
	_sync_viewport_to_window()
	_interior_camera.position = Vector3(0.0, 0.50, 0.64)
	_interior_camera.rotation_degrees = Vector3(-7.5, 0.0, 0.0)
	_apply_level_variant()
	_apply_time_profile()
	_refresh_guest_visuals()
	_cam_base_rot = _interior_camera.rotation
	_look.reset()
	_facing_door = false
	# The door as it was left (open if you came in through it).
	_set_door_open(_tent_door_state(), false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func close_tent() -> void:
	if not _is_open:
		return
	_is_open = false
	if _turn_tween != null and _turn_tween.is_valid():
		_turn_tween.kill()
	_facing_door = false
	_set_door_open(false, false)
	_set_torn(false)
	_glint.clear()
	visible = false
	_viewport.audio_listener_enable_3d = false
	ONE_WORLD_ROOM.camp_view(get_tree(), true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	request_close.emit()


func _process(delta: float) -> void:
	if not _is_open:
		_update_inview(delta)
	_bind_one_world(delta)
	if not _is_open:
		return
	if _interior_camera == null:
		return
	# (Through the door: the walk has the eye.)
	if door_walking:
		_tick_door(delta)
		return
	_apply_idle_mouse_look(delta)
	_tick_turn(delta)
	_tick_tear()
	_tick_door(delta)
	_update_torch(delta)
	if _exit_hint == null:
		_exit_hint = INTERIOR_LOOK.make_exit_hint(self)
	INTERIOR_LOOK.update_exit_hint(_exit_hint, get_viewport(), delta)
	_update_hover()


const HOVER_GLINT = preload("res://scripts/ui/hover_glint.gd")
var _glint = HOVER_GLINT.new()


## What you can use glints under the pointer, as in every room (the user 4. 11.: "check the
## hovers everywhere"): the door (zipped, its canvas and zip; open, the rolled flaps), the
## catalogue.
func _update_hover() -> void:
	var vp := get_viewport()
	var size := vp.get_visible_rect().size
	if size.x <= 0.0 or _prep.is_busy():
		_glint.clear()
		return
	var norm := vp.get_mouse_position() / size
	var lit: Array = []
	if _catalog_screen_rect().has_point(norm):
		lit = [_catalog_mesh]
		var cover := _tent_root.get_node_or_null("CatalogCover")
		if cover != null:
			lit.append(cover)
	elif _door_under(norm):
		for n in (["DoorRollL", "DoorRollR"] if _door_open else ["FrontWall", "ZipLine", "ZipHandle"]):
			var m := _tent_root.get_node_or_null(n)
			if m != null:
				lit.append(m)
	_glint.show_on(lit)
	if not lit.is_empty():
		HandCursor.want(HandCursor.POINT)


func _apply_idle_mouse_look(delta: float) -> void:
	if lodge_sleeping:
		return
	var offset: Vector3 = _look.update(delta, INTERIOR_LOOK.cursor_of(get_viewport()), INTERIOR_LOOK.turn_axis())
	_interior_camera.rotation = _cam_base_rot + offset


func _input(event: InputEvent) -> void:
	if not _is_open or lodge_sleeping:
		return
	if door_walking:
		if (event is InputEventMouseButton and event.pressed) or event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
		return
	if _prep != null and _prep.is_scrubbing():
		return
	# Esc or the way out behind you leaves (but not a
	# click on something to tidy, however low on the screen it is): out through the door on
	# your knees (door_through), unzipping it if it is zipped.
	if INTERIOR_LOOK.is_exit_event(event, get_viewport()) and not (_prep.is_busy() and event is InputEventMouseButton):
		var im := get_parent()
		var at = im.get("_active_tent_node") if im != null else null
		if im == null or not im.has_method("leave_on_foot") or not bool(im.call("leave_on_foot", self, at, close_tent)):
			close_tent()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# A press on something to tidy belongs to the tidying, not to the catalog.
		if _prep.is_busy():
			get_viewport().set_input_as_handled()
			return
		_try_click()
		return
	# E: turned to the door, it opens or closes; else round to it (and E again opens it).
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_E:
		if _facing_door:
			_set_door_open(not _door_open)
		else:
			_turn_to_door()
		get_viewport().set_input_as_handled()


## The upgrade catalog on screen (normalised), wherever the head is turned.
func _catalog_screen_rect() -> Rect2:
	if _viewport != null:
		var r := INTERIOR_LOOK.screen_rect_of(_interior_camera, Vector2(_viewport.size), _catalog_mesh)
		if r.has_area():
			return r.grow(0.02)
	return Rect2()


func _try_click() -> void:
	var main_vp = get_viewport()
	if main_vp == null:
		return
	var mouse_pos = main_vp.get_mouse_position()
	var screen_size = main_vp.get_visible_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return
	var norm = mouse_pos / screen_size

	# Exit is handled only by ESC.

	# A click on the door unzips it (or zips it up): anywhere on its gable, and a good way
	# round it. (Its picture on the screen was no use: that near, part of the gable is behind
	# the eye and it came out empty; the user 4. 11.: "jde velmi špatně kliknout".)
	if _door_under(mouse_pos / screen_size):
		_set_door_open(not _door_open)
		get_viewport().set_input_as_handled()
		return
	if _catalog_screen_rect().has_point(norm):
		request_upgrade.emit()


func _build_viewport() -> void:
	_viewport_container = SubViewportContainer.new()
	_viewport_container.name = "TentViewportContainer"
	_viewport_container.anchor_right = 1.0
	_viewport_container.anchor_bottom = 1.0
	_viewport_container.stretch = true
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_viewport_container)
	RETRO_RENDER.register(_viewport_container)

	_viewport = SubViewport.new()
	_viewport.name = "TentViewport"
	# The camp's own world: the room stands in its tent there (_bind_one_world).
	ONE_WORLD_ROOM.viewport(_viewport)
	_viewport.size = INTERIOR_RENDER_MIN_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.handle_input_locally = false
	_viewport_container.add_child(_viewport)

	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.60, 0.64, 0.70)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.76, 0.80, 0.76)
	env.ambient_light_energy = 0.92
	# (The camp's world has its own environment: these are the room's numbers, its probe's
	# ambient, _bind_one_world.)
	_tent_env = env

	_barrel_overlay = ColorRect.new()
	_barrel_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_barrel_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barrel_overlay.color = Color(1.0, 1.0, 1.0, 1.0)
	var barrel_mat = ShaderMaterial.new()
	barrel_mat.shader = INTERIOR_BARREL_SHADER
	barrel_mat.set_shader_parameter("barrel_strength", 0.0)
	barrel_mat.set_shader_parameter("vignette_strength", 0.0)
	barrel_mat.set_shader_parameter("chroma_shift", 0.0)
	_barrel_overlay.material = barrel_mat
	_barrel_overlay.visible = false
	add_child(_barrel_overlay)


func _sync_viewport_to_window() -> void:
	if _viewport_container != null and _viewport_container.stretch:
		return
	if _viewport == null:
		return
	var screen_size = get_viewport().get_visible_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return
	_viewport.size = Vector2i(
		max(INTERIOR_RENDER_MIN_SIZE.x, int(screen_size.x)),
		max(INTERIOR_RENDER_MIN_SIZE.y, int(screen_size.y))
	)


func _build_tent_room() -> void:
	_tent_root = Node3D.new()
	_tent_root.name = "TentRoom"
	_viewport.add_child(_tent_root)
	_guest_visual_root = Node3D.new()
	_guest_visual_root.name = "GuestVisuals"
	_tent_root.add_child(_guest_visual_root)

	_interior_camera = Camera3D.new()
	_interior_camera.name = "TentCamera"
	_interior_camera.position = Vector3(0.0, 0.50, 0.64)
	_interior_camera.rotation_degrees = Vector3(-7.5, 0.0, 0.0)
	_interior_camera.fov = 68.0
	_interior_camera.near = 0.05
	_interior_camera.current = true
	ONE_WORLD_ROOM.eye(_interior_camera)
	_tent_root.add_child(_interior_camera)
	_probe = ONE_WORLD_ROOM.probe(_tent_root, "TentLightInside")
	_dry = ONE_WORLD_ROOM.dry(_tent_root, "Dry")
	ONE_WORLD_ROOM.fit(_probe, _dry, Vector3(-TENT_HALF_WIDTH - 0.02, 0.0, -1.38), Vector3(TENT_HALF_WIDTH + 0.02, TENT_RIDGE_HEIGHT + 0.04, DOOR_PLANE_Z))

	_tent_light = OmniLight3D.new()
	_tent_light.name = "TentLight"
	_tent_light.position = Vector3(0.0, 0.94, -0.28)
	_tent_light.light_color = Color(0.96, 0.92, 0.82)
	_tent_light.light_energy = 0.96
	_tent_light.omni_range = 4.4
	_tent_light.omni_attenuation = 1.5
	_tent_light.shadow_enabled = false
	_tent_root.add_child(_tent_light)

	_add_box("FloorMat", Vector3(0.0, 0.0, -0.10), Vector3(1.92, 0.04, 2.46), Color(0.42, 0.52, 0.70))

	# An A-frame: two cloth slopes meeting at the ridge, triangular gables front and back.
	# (Closed all round, because the view can turn now.)
	var half_w := TENT_HALF_WIDTH
	var ridge := TENT_RIDGE_HEIGHT
	var slope_len := sqrt(half_w * half_w + ridge * ridge) + 0.06
	var slope_deg := rad_to_deg(atan2(half_w, ridge))
	var left_wall = _add_box("LeftWall", Vector3(-half_w * 0.5, ridge * 0.5, -0.10), Vector3(0.04, slope_len, 2.50), Color(0.74, 0.70, 0.52))
	left_wall.rotation_degrees = Vector3(0.0, 0.0, -slope_deg)
	var right_wall = _add_box("RightWall", Vector3(half_w * 0.5, ridge * 0.5, -0.10), Vector3(0.04, slope_len, 2.50), Color(0.74, 0.70, 0.52))
	right_wall.rotation_degrees = Vector3(0.0, 0.0, slope_deg)
	_add_box("CeilingRidge", Vector3(0.0, ridge - 0.03, -0.10), Vector3(0.06, 0.05, 2.50), Color(0.30, 0.28, 0.20))

	_add_gable("BackWall", Vector3(0.0, ridge * 0.5, -1.34), Color(0.60, 0.50, 0.42))
	_add_gable("FrontWall", Vector3(0.0, ridge * 0.5, 1.12), Color(0.60, 0.50, 0.42))

	_add_box("ZipLine", Vector3(0.0, 0.56, 1.10), Vector3(0.02, 0.98, 0.01), Color(0.74, 0.70, 0.52))
	_add_box("ZipHandle", Vector3(0.0, 0.14, 1.09), Vector3(0.05, 0.06, 0.03), Color(0.84, 0.80, 0.56))

	_add_box("SleepingBag", Vector3(-0.20, 0.06, -0.02), Vector3(0.64, 0.08, 1.34), Color(0.36, 0.58, 0.82))
	_add_box("Pillow", Vector3(-0.20, 0.11, -0.68), Vector3(0.40, 0.08, 0.24), Color(0.42, 0.40, 0.36))

	# The upgrade catalog on the groundsheet: its cover (Grok, camp/tent_catalog.png) on
	# the paper.
	_catalog_mesh = _add_box("CatalogBacker", Vector3(0.46, 0.055, -0.18), Vector3(0.36, 0.01, 0.46), Color(0.08, 0.08, 0.08))
	_add_box("Catalog", Vector3(0.46, 0.062, -0.18), Vector3(0.32, 0.02, 0.42), Color(0.96, 0.90, 0.74))
	_add_catalog_cover(Vector3(0.46, 0.0725, -0.18), Vector2(0.31, 0.41))

	# Level-based props.
	# A storm lantern on a cord from the ridge, a rucksack by the door (level 2+).
	var lantern_stem = _add_box("LanternStem", Vector3(0.0, 1.06, -0.56), Vector3(0.012, 0.36, 0.012), Color(0.22, 0.20, 0.18))
	var lantern := INTERIOR_KIT.prop(_tent_root, "lantern", Vector3(0.0, 0.58, -0.56))
	lantern.name = "LanternBody"
	# Both hang from a hook on the ridge, so the wind can swing them (room_weather.gd).
	var hook := Node3D.new()
	hook.name = "LanternHook"
	hook.position = Vector3(0.0, 1.24, -0.56)
	_tent_root.add_child(hook)
	for part: Node3D in [lantern_stem, lantern]:
		var local := part.position - hook.position
		_tent_root.remove_child(part)
		hook.add_child(part)
		part.position = local
	# The weather in here (scripts/ambient/room_weather.gd): the canvas lit by the lightning,
	# breathing in the gusts, rain drumming on it, a leak by the ridge, the lantern swinging.
	_weather = ROOM_WEATHER.new()
	_weather.canvas = true
	_weather.is_open = func(): return _is_open
	_tent_root.add_child(_weather)
	_weather.add_breather(left_wall, Vector3(0, 0, 1))
	_weather.add_breather(right_wall, Vector3(0, 0, -1))
	_weather.add_swinger(hook)
	_weather.set_drip(Vector3(0.22, 1.12, -0.05), 0.06)
	var storage_crate := INTERIOR_KIT.prop(_tent_root, "backpack", Vector3(-0.56, 0.0, 0.62), 70.0, 0.8)
	storage_crate.name = "StorageCrate"
	lantern_stem.visible = false
	lantern.visible = false
	storage_crate.visible = false

	var rug = _add_box("Rug", Vector3(0.0, 0.03, -0.40), Vector3(1.24, 0.01, 1.10), Color(0.28, 0.36, 0.54))
	var mini_table = _add_box("MiniTable", Vector3(0.56, 0.16, -0.78), Vector3(0.34, 0.12, 0.24), Color(0.46, 0.34, 0.24))
	var mini_shelf = _add_box("MiniShelf", Vector3(-0.56, 0.12, -0.98), Vector3(0.36, 0.24, 0.3), Color(0.70, 0.56, 0.40))
	rug.visible = false
	mini_table.visible = false
	mini_shelf.visible = false

	_build_prep_props()
	_apply_level_variant()
	_apply_time_profile()


## The tent as the last guests left it: the sleeping bag kicked into a heap with the
## pillow thrown off, and litter by the door. Tidy versions are the normal props.
func _build_prep_props() -> void:
	var P := INTERIOR_PREP
	var heap_mat := P.camp_material("blanket_check.png", Color(0.75, 0.72, 0.7))
	var heap_a := P.box(_tent_root, Vector3(-0.24, 0.12, -0.30), Vector3(0.62, 0.22, 0.46), heap_mat, Vector3(0.12, 0.35, -0.08))
	var heap_b := P.box(_tent_root, Vector3(-0.18, 0.06, -0.75), Vector3(0.5, 0.08, 0.5), heap_mat, Vector3(0.0, -0.4, 0.06))
	var pillow_off := P.box(_tent_root, Vector3(-0.58, 0.07, 0.05), Vector3(0.36, 0.08, 0.22), INTERIOR_KIT.surface("mattress", 0.4, Color(0.72, 0.7, 0.64)), Vector3(0.0, 0.9, 0.5))
	var tidy_bag := _tent_root.get_node_or_null("SleepingBag")
	var tidy_pillow := _tent_root.get_node_or_null("Pillow")
	if tidy_bag is MeshInstance3D:
		(tidy_bag as MeshInstance3D).material_override = heap_mat
	# Round the heap (not the whole sleeping bag's place): the litter lies close beside it.
	var bed_body := P.body(_tent_root, Vector3(-0.26, 0.12, -0.45), Vector3(0.7, 0.24, 1.0))
	_prep.register("bed", bed_body, [heap_a, heap_b, pillow_off], [tidy_bag, tidy_pillow])

	# Where the mess can be this time (core/systems/mess_rules.gd ROOM_SPOTS).
	for spot in [["f1", Vector3(0.38, 0.0, -0.85)], ["f2", Vector3(0.3, 0.0, 0.05)], ["f3", Vector3(-0.72, 0.0, -0.2)],
			["f4", Vector3(0.12, 0.0, -1.08)], ["f5", Vector3(-0.7, 0.0, -0.9)]]:
		_prep.add_spot(spot[0], _tent_root, spot[1])
	# The back canvas, where the granny's knife came through (mess_rules CARNAGE_WALL).
	_prep.add_spot("w1", _tent_root, Vector3(0.05, 0.62, -1.31), 0.0, true)
	_prep.setup_tasks(self, _interior_camera, _viewport, "tent")
	_prep.task_completed.connect(func(id: String): room_task_completed.emit(id))


func _apply_level_variant() -> void:
	var wall_col = Color(1.00, 0.84, 0.18)
	var floor_col = Color(0.72, 0.58, 0.20)
	var bag_col = Color(1.00, 0.82, 0.18)
	match _tent_level:
		2:
			wall_col = Color(0.98, 0.22, 0.16)
			floor_col = Color(0.72, 0.24, 0.20)
			bag_col = Color(0.98, 0.16, 0.14)
		3:
			wall_col = Color(0.18, 0.40, 1.00)
			floor_col = Color(0.12, 0.26, 0.78)
			bag_col = Color(0.28, 0.58, 1.00)

	_set_node_color("LeftWall", wall_col)
	_set_node_color("RightWall", wall_col)
	_set_node_color("BackWall", wall_col.darkened(0.12))
	_set_node_color("FrontWall", wall_col.darkened(0.10))
	_set_node_color("CeilingRidge", wall_col.darkened(0.26))
	_set_node_color("ZipLine", wall_col.darkened(0.10))
	_set_node_color("FloorMat", floor_col)
	_set_node_color("SleepingBag", bag_col.lerp(Color(1, 1, 1), 0.55))

	for node_name in _level2_nodes:
		_set_node_visible(node_name, _tent_level >= 2)
	for node_name in _level3_nodes:
		_set_node_visible(node_name, _tent_level >= 3)


func _set_node_visible(node_name: String, visible_flag: bool) -> void:
	if _tent_root == null:
		return
	var node = _tent_root.get_node_or_null(node_name) as Node3D
	if node != null:
		node.visible = visible_flag


func _set_node_color(node_name: String, color: Color) -> void:
	if _tent_root == null:
		return
	var mesh_inst = _tent_root.get_node_or_null(node_name) as MeshInstance3D
	if mesh_inst == null:
		return
	var shader_mat = mesh_inst.material_override as ShaderMaterial
	if shader_mat != null:
		shader_mat.set_shader_parameter("base_color", color)
		return
	var std_mat = mesh_inst.material_override as StandardMaterial3D
	if std_mat != null:
		if std_mat.albedo_texture != null:
			std_mat.albedo_color = color.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.45)
		else:
			std_mat.albedo_color = color


func _apply_time_profile() -> void:
	if _tent_env != null:
		match _time_state:
			TIME_DAY:
				_tent_env.background_color = Color(0.56, 0.60, 0.64)
				_tent_env.ambient_light_color = Color(0.64, 0.66, 0.62)
				_tent_env.ambient_light_energy = 0.72
			TIME_EVENING:
				_tent_env.background_color = Color(0.14, 0.11, 0.12)
				_tent_env.ambient_light_color = Color(0.26, 0.20, 0.18)
				_tent_env.ambient_light_energy = 0.20
			_:
				_tent_env.background_color = Color(0.02, 0.03, 0.05)
				_tent_env.ambient_light_color = Color(0.08, 0.10, 0.14)
				_tent_env.ambient_light_energy = 0.03

	if _tent_light != null:
		match _time_state:
			TIME_DAY:
				_tent_light.light_color = Color(0.98, 0.94, 0.84)
				_tent_light.light_energy = 0.96
			TIME_EVENING:
				_tent_light.light_color = Color(0.84, 0.62, 0.46)
				_tent_light.light_energy = 0.22
			_:
				_tent_light.light_color = Color(0.44, 0.50, 0.72)
				_tent_light.light_energy = 0.05

	var daylight = clampf(_daylight_factor, 0.0, 1.0)
	var sun_tint = _sunlight_color.lerp(Color(1.0, 0.96, 0.90), 0.25)
	if _tent_env != null:
		_tent_env.ambient_light_color = _tent_env.ambient_light_color.lerp(sun_tint, 0.14 * daylight)
		_tent_env.ambient_light_energy = lerpf(_tent_env.ambient_light_energy * 0.82, _tent_env.ambient_light_energy * 1.16, daylight)
	if _tent_light != null:
		_tent_light.light_color = _tent_light.light_color.lerp(sun_tint, 0.10 * daylight)
		_tent_light.light_energy = lerpf(_tent_light.light_energy * 0.90, _tent_light.light_energy * 1.08, daylight)
	if not _grid_power_available and _tent_light != null:
		_tent_light.light_energy = 0.0


func _refresh_guest_visuals() -> void:
	if _guest_visual_root == null:
		return
	for child in _guest_visual_root.get_children():
		child.queue_free()

	if _guest_occupants.is_empty():
		return

	var sorted = _guest_occupants.duplicate(true)
	sorted.sort_custom(func(a, b):
		var da = a if a is Dictionary else {}
		var db = b if b is Dictionary else {}
		var slot_a = int(da.get("slot_index", 0))
		var slot_b = int(db.get("slot_index", 0))
		if slot_a == slot_b:
			return int(da.get("guest_id", 0)) < int(db.get("guest_id", 0))
		return slot_a < slot_b
	)

	for i in range(sorted.size()):
		var entry_any = sorted[i]
		if not (entry_any is Dictionary):
			continue
		var entry: Dictionary = entry_any
		var sprite = _create_guest_sprite(entry)
		if sprite == null:
			continue
		var stand_pos = TENT_GUEST_STAND_POINTS[min(i, TENT_GUEST_STAND_POINTS.size() - 1)]
		if i >= TENT_GUEST_STAND_POINTS.size():
			stand_pos += Vector3(0.12 * float(i - TENT_GUEST_STAND_POINTS.size() + 1), 0.0, 0.0)
		sprite.position = stand_pos
		_guest_visual_root.add_child(sprite)


func _create_guest_sprite(entry: Dictionary) -> Sprite3D:
	var sprite = Sprite3D.new()
	var texture = _resolve_guest_texture(entry)
	if texture == null:
		return null
	sprite.texture = texture
	sprite.pixel_size = TENT_GUEST_SPRITE_PIXEL_SIZE
	sprite.shaded = false
	sprite.double_sided = true
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fit_sprite_height(sprite, texture, TENT_GUEST_TARGET_HEIGHT)
	return sprite


func _resolve_guest_texture(entry: Dictionary) -> Texture2D:
	var archetype = str(entry.get("archetype", "quiet_guy")).to_lower().strip_edges()
	match archetype:
		"drunk":
			return HOST_DRUNK_TEXTURE
		"cheap_chick", "cheapchick":
			return HOST_CHEAP_TEXTURE
		"tramp", "family", "picker":
			var path := "res://assets/textury/npc/%s.png" % {"tramp": "host_tramp", "family": "host_family", "picker": "host_pensioner"}[archetype]
			if ResourceLoader.exists(path):
				return load(path)
			return HOST_QUIET_TEXTURE
		_:
			return HOST_QUIET_TEXTURE


func _fit_sprite_height(sprite: Sprite3D, texture: Texture2D, target_height: float) -> void:
	if sprite == null or texture == null:
		return
	var tex_height = max(1.0, float(texture.get_height()))
	var base_world_height = tex_height * sprite.pixel_size
	if base_world_height <= 0.0001:
		return
	var scale_factor = target_height / base_world_height
	sprite.scale = Vector3.ONE * scale_factor


## A triangular end wall of the A-frame (same material rules as `_add_box`).
func _add_gable(node_name: String, pos: Vector3, color: Color) -> MeshInstance3D:
	var size := Vector3(TENT_HALF_WIDTH * 2.0 + 0.04, TENT_RIDGE_HEIGHT, 0.04)
	var wall := _add_box(node_name, pos, size, color)
	var prism := PrismMesh.new()
	prism.size = size
	prism.left_to_right = 0.5
	wall.mesh = prism
	return wall


# -- turning round, the door (the user 20. 10.: turn round in the tent and unzip it, the
# camp outside as it really is from there) --

const WINDOW_PORTAL = preload("res://scripts/ui/window_portal.gd")
const STEP12 = preload("res://scripts/ui/step12.gd")
## The front gable's plane in the tent (z).
const DOOR_PLANE_Z := 1.16
const SFX_ZIP := "res://assets/sfx/rooms/tent_zip.mp3"
const TURN_SEC := 0.6
var _facing_door := false
var _door_open := false
var _door_portal
var _turn_tween: Tween
var _zip: AudioStreamPlayer


## You turn all the way round in the tent as in any room (the user 4. 11.: turning round by
## holding the head at the end of its turn was bad with the mouse): the door behind you is
## simply there.
func _tick_turn(_delta: float) -> void:
	_look.take_push()
	_facing_door = absf(float(_look.yaw_deg)) > 105.0


## E, turned away from the door: round to it, the short way.
func _turn_to_door() -> void:
	if _turn_tween != null and _turn_tween.is_valid() and _turn_tween.is_running():
		return
	var side := -1.0 if float(_look.yaw_deg) < 0.0 else 1.0
	_turn_tween = STEP12.move(self, _look, {"yaw_deg": side * 179.0}, TURN_SEC)


## The doorway's view out (a portal in the front gable), live while it is open.
func _tick_door(delta: float) -> void:
	if _door_portal == null:
		return
	# (One world: the camp itself is out there, through the canvas's doorway.)
	_door_portal.quad.visible = false
	return
	# (Not while you come in through it: the eye is out in front of it, the view behind you.)
	# (Not while your eye is still on its far side, coming in: it filled the view, grey.)
	_door_portal.quad.visible = _door_open and not door_walking and _tent_root.to_local(_interior_camera.global_position).z < 1.05
	var im := get_parent()
	var a = im.get("_active_tent_node") if im != null else null
	var anchor := a as Node3D if a != null and is_instance_valid(a) and (a as Node3D).is_inside_tree() else null
	var world: World3D = anchor.get_world_3d() if anchor != null else null
	_door_portal.update(_tent_root, _interior_camera, WINDOW_PORTAL.room_to_world(anchor, _door_portal) if anchor != null else Transform3D(), _door_open and anchor != null, world, delta, anchor)


# -- the canvas torn open (the granny's "slit": interior_prep, mess_rules CARNAGE_WALL;
# Richard 3. 11.: "lepe udelat protrzeny stan. fakt dirou videt ven") --

const WINDOW_SHARED_VIEW = preload("res://scripts/ui/window_shared_view.gd")
var _tear: MeshInstance3D
var _tear_seek := 0
var _torn := false


## The hole in the back canvas while it is there: the camp through it as it is from here
## (the room's shared view, offered before the doorway's, so while you face the hole the
## view is placed for its side of the tent outside), the wind in its flaps, the outside
## heard through it.
func _tick_tear() -> void:
	if _tear == null or not is_instance_valid(_tear) or not _tear.is_inside_tree():
		_tear = null
		_tear_seek -= 1
		if _tear_seek <= 0:
			# (Every few frames: once in twenty it was a beat late, the user 4. 11.)
			_tear_seek = 3
			_tear = _tent_root.find_child("TentTear", true, false) as MeshInstance3D
	var on := _tear != null and _tear.is_visible_in_tree()
	_set_torn(on)
	if not on:
		return
	var im := get_parent()
	var a = im.get("_active_tent_node") if im != null else null
	var anchor := a as Node3D if a != null and is_instance_valid(a) and (a as Node3D).is_inside_tree() else null
	var world: World3D = anchor.get_world_3d() if anchor != null else null
	var to := (_tear.global_position - _interior_camera.global_position).normalized()
	# Already drawn as it comes into view at the edge (it came alive late as you turned).
	var live := world != null and (-_interior_camera.global_transform.basis.z).dot(to) > -0.25
	var view = WINDOW_SHARED_VIEW.for_host(self)
	if live:
		var hole := {"outward": Vector3(0, 0, -1), "frame": Transform3D(Basis(), _tent_root.to_local(_tear.global_position))}
		view.offer(_interior_camera, _tent_root, WINDOW_PORTAL.room_to_world(anchor, hole), world, anchor)
	var wind := float(_weather.get("wind_now")) if _weather != null and _weather.get("wind_now") != null else 0.3
	for m in _tear.get_meta("tear_mats", []):
		var sm := m as ShaderMaterial
		sm.set_shader_parameter("room_tex", view.texture())
		sm.set_shader_parameter("live", 1.0 if live else 0.0)
		sm.set_shader_parameter("wind", maxf(wind, 0.35))


## The tent open to the night: its canvas snaps in every breeze (room_weather `torn`) and
## the outside comes in through the hole, less muffled (audio_manager.set_room_leak).
func _set_torn(on: bool) -> void:
	if on == _torn:
		return
	_torn = on
	if _weather != null:
		_weather.set("torn", on)
	var im := get_parent()
	var am = im.get("_audio_manager") if im != null else null
	if am != null and am.has_method("set_room_leak"):
		am.set_room_leak(0.6 if on else 0.0)


## The key of the tent you are in ("x:y"), "" none.
func _tent_key() -> String:
	var im := get_parent()
	var a = im.get("_active_tent_node") if im != null else null
	if a == null or not is_instance_valid(a) or not im.has_method("_room_key_for"):
		return ""
	return str(im.call("_room_key_for", a))


## Its door as the wardens left it (interior_manager.tent_doors).
func _tent_door_state() -> bool:
	var im := get_parent()
	var key := _tent_key()
	return key != "" and im != null and im.has_method("tent_door_open") and bool(im.call("tent_door_open", key))


## `tell`: zipped or unzipped by you, the camp's tent (and the others') as you left it.
func _set_door_open(open: bool, tell := true) -> void:
	if _tent_root == null:
		return
	if tell and _is_open:
		var im := get_parent()
		var key := _tent_key()
		if key != "" and im != null and im.has_method("set_tent_door"):
			im.call("set_tent_door", key, open)
	if _door_portal == null:
		_door_portal = WINDOW_PORTAL.make(self, _tent_root, Vector3(0.0, TENT_RIDGE_HEIGHT * 0.48, 1.16), Vector3(0, 0, 1),
			Vector2(TENT_HALF_WIDTH * 2.0, TENT_RIDGE_HEIGHT), "", 192, false)
		_door_portal.quad.visible = false
		# The view out is for the inside: not for the camp looking in (_update_inview).
		_hide_from_camp(_door_portal.quad)
		# The flaps rolled up and tied either side of the doorway.
		for sx: float in [-1.0, 1.0]:
			var roll := _add_box("DoorRoll%s" % ("L" if sx < 0.0 else "R"), Vector3(sx * TENT_HALF_WIDTH * 0.62, 0.42, 1.1), Vector3(0.09, 0.62, 0.09), Color(0.58, 0.48, 0.40))
			roll.rotation_degrees.z = -sx * rad_to_deg(atan2(TENT_HALF_WIDTH, TENT_RIDGE_HEIGHT)) * 0.9
			roll.visible = false
	var changed := open != _door_open
	_door_open = open
	_door_portal.quad.visible = false
	for n in ["FrontWall", "ZipLine", "ZipHandle"]:
		var m := _tent_root.get_node_or_null(n) as Node3D
		if m != null:
			m.visible = not open
	for n in ["DoorRollL", "DoorRollR"]:
		var r := _tent_root.get_node_or_null(n) as Node3D
		if r != null:
			r.visible = open
	if changed and _is_open:
		if _zip == null:
			_zip = AudioStreamPlayer.new()
			add_child(_zip)
		_zip.stream = load(SFX_ZIP) if ResourceLoader.exists(SFX_ZIP) else null
		_zip.volume_db = -8.0
		if _zip.stream != null:
			_zip.play()


# -- through the door on your knees (scripts/ui/door_through.gd) and the camp looking in
# through it while it is unzipped (the user 4. 11.: "unzipped from inside it should be open
# from outside too and you should see in; you should see the warden") --

var door_walking := false


func door_ready(structure: Node3D) -> void:
	# Into the tent you are coming to, now: the walk in starts at its door (it started where
	# the room last stood, a crawl across half the camp, the user 5. 11.).
	_door_tent = structure
	_door_tent_ms = Time.get_ticks_msec()
	_make_up_as(structure)
	_bind_one_world(0.0)


## The room as `structure`'s tent: its tier, its guests, its door open.
func _make_up_as(structure: Node3D) -> void:
	var t := str(structure.get_meta("building_type", "tent_1"))
	_tent_level = clampi(int(t.right(1)) if t.right(1).is_valid_int() else 1, 1, 3)
	_apply_level_variant()
	_apply_time_profile()
	var im := get_parent()
	if im != null and im.has_method("_guest_visuals_for_structure"):
		_guest_occupants = im.call("_guest_visuals_for_structure", structure)
		_refresh_guest_visuals()
	if im != null and im.has_method("_push_room_state"):
		im.call("_push_room_state", self, structure)
	_set_door_open(true, false)


func door_spec(_structure: Node3D) -> Dictionary:
	if _tent_root == null:
		return {}
	return {"root": _tent_root, "at": Vector3(0.0, 0.0, DOOR_PLANE_Z), "out": Vector3(0, 0, 1),
		"size": Vector2(TENT_HALF_WIDTH * 2.0, TENT_RIDGE_HEIGHT), "inner": 0.05, "leaf": [], "one_world": true}


## On the way out: the door unzips as you come to it (and stays so).
func door_opening() -> void:
	if not _door_open:
		_set_door_open(true)


const INVIEW_RANGE := 26.0
## What lies over the room's doorway inside (the camp's view in it): not for the camp's eye.
const INVIEW_HIDE_LAYER := 1 << 17
const COOP_FIGURE = preload("res://scripts/coop/remote_player.gd")
const COOP_LOOKS = preload("res://scripts/coop/warden_looks.gd")
var _inview_way: MeshInstance3D
## What you see in through: the doorway's pane, or the slit hole (TentTear).
var _inview_opening: MeshInstance3D
var _inview_tent: Node3D
var _inview_ways: Array = []
var _inview_scan_t := 0.0
var _inview_light_t := 0.0
var _inview_figs: Dictionary = {}


## The room in the tent you are in (its doorway the one you came in by), or out in the
## camp in the one you look in at (_update_inview); none, it is put away (its lantern with
## it). Its front gable in the canvas's doorway (TentDoorWay, never drawn while the room is
## in it); its light inside is its probe's; heard from the camp its sounds come through.
func _bind_one_world(delta: float) -> void:
	if _tent_root == null:
		return
	var way: MeshInstance3D = null
	var coming: bool = _door_tent != null and is_instance_valid(_door_tent) and _door_tent.is_inside_tree() and (door_walking or Time.get_ticks_msec() - _door_tent_ms < 8000)
	if coming and not _is_open:
		if _host_way == null or not is_instance_valid(_host_way) or not _door_tent.is_ancestor_of(_host_way):
			way = _doorway_near(_door_tent)
		else:
			way = _host_way
	elif _is_open:
		var im := get_parent()
		var a = im.get("_active_tent_node") if im != null else null
		if a != null and is_instance_valid(a) and (a as Node3D).is_inside_tree():
			if _host_way == null or not is_instance_valid(_host_way) or not (a as Node).is_ancestor_of(_host_way):
				way = _doorway_near(a as Node3D)
			else:
				way = _host_way
	elif _inview_way != null and is_instance_valid(_inview_way) and _inview_way.is_inside_tree():
		way = _inview_way
	if way != _host_way:
		if _host_way != null and is_instance_valid(_host_way):
			_host_way.layers = 1
			_poles_of(_host_way, false)
		_host_way = way
		if way != null:
			_poles_of(way, true)
	# (Kept so: a door's walk puts back what it took away.)
	if _host_way != null and is_instance_valid(_host_way):
		_host_way.layers = 0
	var ok := way != null
	if _tent_root.visible != (ok or _is_open):
		_tent_root.visible = ok or _is_open
	if ok:
		var x := Transform3D(way.global_basis.orthonormalized(), way.global_position) * Transform3D(Basis(), Vector3(0.0, TENT_LIFT, -DOOR_PLANE_Z))
		if not _tent_root.transform.is_equal_approx(x):
			_tent_root.transform = x
	if _probe != null and _tent_env != null:
		_probe.ambient_color = _tent_env.ambient_light_color
		_probe.ambient_color_energy = _tent_env.ambient_light_energy
	_walls_t -= delta
	if _walls_t <= 0.0:
		_walls_t = 0.5
		ONE_WORLD_ROOM.sounds_through_walls(_tent_root, not _is_open)


## The poles at the doorway and the back of the tent the room stands in: the room's eye
## leaves them out (crawling in, the front one stood across the whole view for a frame);
## the room has its own ridge.
func _poles_of(way: MeshInstance3D, hide: bool) -> void:
	var t := way.get_parent()
	if t == null:
		return
	for c in t.get_children():
		if c is GeometryInstance3D and (c as Node).has_meta("tent_pole"):
			(c as GeometryInstance3D).layers = ONE_WORLD_ROOM.GLASS_LAYER if hide else 1


## Of a tent's doorways (a pair's two) the one nearest your body in the camp: the one you
## came in by.
func _doorway_near(tent: Node3D) -> MeshInstance3D:
	var scene := get_tree().current_scene if is_inside_tree() else null
	var p = scene.get("_player") if scene != null else null
	var at: Vector3 = (p as Node3D).global_position if p is Node3D else tent.global_position
	var best: MeshInstance3D = null
	var best_d := INF
	for w in tent.find_children("TentDoorWay", "MeshInstance3D", true, false):
		var dd := (w as Node3D).global_position.distance_to(at)
		if dd < best_d:
			best_d = dd
			best = w
	return best


func _camp_camera() -> Camera3D:
	var scene := get_tree().current_scene if is_inside_tree() else null
	var w3d = scene.get("_world_3d") if scene != null else null
	if w3d is Node3D and (w3d as Node3D).is_inside_tree():
		return (w3d as Node3D).get_viewport().get_camera_3d()
	return null


## The camp's tents that can be seen into: [[structure, pane of its doorway, what you see
## through]]: the doorway unzipped, or the hole the granny slit in its back (the user 4. 11.:
## "from outside you cannot see in through it"). The doorway's pane lays the rooms one on
## the other either way.
func _find_open_ways() -> Array:
	var out: Array = []
	var im := get_parent()
	var doors = im.get("tent_doors") if im != null else null
	if doors is Dictionary:
		for key in (doors as Dictionary).keys():
			var p := str(key).split(":")
			if p.size() != 2:
				continue
			var s: Node3D = DOOR_ANIM.structure_at(Vector2i(int(p[0]), int(p[1])))
			if s == null:
				continue
			for w in s.find_children("TentDoorWay", "MeshInstance3D", true, false):
				out.append([s, w, w])
	var scene := get_tree().current_scene if is_inside_tree() else null
	var bm = scene.get("building_manager") if scene != null else null
	var structures: Node = bm.get_node_or_null("Structures") if bm != null else null
	if structures != null:
		for s in structures.get_children():
			if not str((s as Node).get_meta("building_type", "")).begins_with("tent"):
				continue
			var tear := (s as Node).find_child("TentTear", true, false) as MeshInstance3D
			var way := (s as Node).find_child("TentDoorWay", true, false) as MeshInstance3D
			if tear != null and way != null:
				out.append([s, way, tear])
	return out


func _update_inview(delta: float) -> void:
	var cam := _camp_camera()
	var way: MeshInstance3D = null
	var tent: Node3D = null
	var opening: MeshInstance3D = null
	if cam != null and _tent_root != null:
		_inview_scan_t -= delta
		if _inview_scan_t <= 0.0:
			_inview_scan_t = 0.5
			_inview_ways = _find_open_ways()
		var best := INVIEW_RANGE
		for e in _inview_ways:
			var o = e[2]
			if not is_instance_valid(o) or not is_instance_valid(e[1]) or not (o as MeshInstance3D).is_visible_in_tree():
				continue
			var to: Vector3 = cam.global_position - (o as Node3D).global_position
			if to.length() >= best or (o as Node3D).global_basis.z.dot(to) <= 0.05:
				continue
			best = to.length()
			way = e[1]
			tent = e[0]
			opening = o
	if way != _inview_way or opening != _inview_opening:
		_release_inview()
		if way != null:
			_take_inview(tent, way, opening)
	if _inview_way == null:
		return
	_inview_light_t -= delta
	if _inview_light_t <= 0.0:
		_inview_light_t = 0.25
		var im := get_parent()
		var ll: Array = im.get("_last_light") if im != null and im.get("_last_light") != null else []
		if ll.size() >= 4:
			set_daylight_profile(ll[0], ll[1], ll[2], ll[3])
		_inview_wardens()


func _take_inview(tent: Node3D, way: MeshInstance3D, opening: MeshInstance3D = null) -> void:
	_inview_tent = tent
	_inview_way = way
	_inview_opening = opening if opening != null else way
	_make_up_as(tent)
	_inview_light_t = 0.0


func _release_inview() -> void:
	_inview_opening = null
	_inview_way = null
	_inview_tent = null
	for id in _inview_figs.keys():
		var f = _inview_figs[id]
		if f != null and is_instance_valid(f):
			f.queue_free()
	_inview_figs.clear()


static func _hide_from_camp(n: Node) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = INVIEW_HIDE_LAYER
	for c in n.get_children():
		_hide_from_camp(c)


## The other wardens in this tent, seen through its door: on their knees in it, facing out.
func _inview_wardens() -> void:
	var key := ""
	var im := get_parent()
	if im != null and _inview_tent != null and im.has_method("_room_key_for"):
		key = str(im.call("_room_key_for", _inview_tent))
	var seen: Array = []
	if key != "" and Coop.is_active():
		for id in Coop.others():
			var info: Dictionary = Coop.state_of(id).get("room", {})
			if str(info.get("k", "")) != key:
				continue
			seen.append(id)
			var fig = _inview_figs.get(id)
			if fig == null or not is_instance_valid(fig):
				var look: Dictionary = Coop.look_of(id)
				fig = COOP_FIGURE.new()
				fig.setup(int(look.get("m", 1)), int(look.get("c", 0)), true)
				_viewport.add_child(fig)
				_inview_figs[id] = fig
			fig.show_at(_tent_root.global_transform * Vector3(0.0, 0.0, 0.25), "crouch", false, _tent_root.global_basis * Vector3(0, 0, 1))
	for id in _inview_figs.keys():
		if not id in seen:
			var f = _inview_figs[id]
			if f != null and is_instance_valid(f):
				f.queue_free()
			_inview_figs.erase(id)


## Whether the pointer (normalised) is on the door: the ray through it onto the front
## gable's plane, the gable and a margin round it.
func _door_under(norm: Vector2) -> bool:
	if _viewport == null or _interior_camera == null or _tent_root == null:
		return false
	var at := norm * Vector2(_viewport.size)
	var o: Vector3 = _tent_root.to_local(_interior_camera.project_ray_origin(at))
	var d: Vector3 = _tent_root.global_basis.inverse() * _interior_camera.project_ray_normal(at)
	if d.z <= 0.05:
		return false
	var p: Vector3 = o + d * ((DOOR_PLANE_Z - o.z) / d.z)
	return absf(p.x) <= TENT_HALF_WIDTH + 0.3 and p.y >= -0.2 and p.y <= TENT_RIDGE_HEIGHT + 0.3


## A picture lying flat on top of something (a quad: a box would show a third of it).
func _add_catalog_cover(pos: Vector3, size: Vector2) -> void:
	var path := "res://assets/textury/camp/tent_catalog.png"
	if not ResourceLoader.exists(path):
		return
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.name = "CatalogCover"
	mi.mesh = q
	mi.position = pos
	mi.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(path)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 0.9
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mi.material_override = mat
	_tent_root.add_child(mi)


func _add_box(node_name: String, pos: Vector3, box_size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = node_name
	var box = BoxMesh.new()
	box.size = box_size
	mesh_inst.mesh = box
	mesh_inst.position = pos
	var uv_scale = Vector3(max(1.0, box_size.x * 1.6), 1.0, max(1.0, box_size.z * 1.6))

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.96
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.uv1_scale = uv_scale
	for prefix in SURFACES.keys():
		if node_name.begins_with(prefix):
			var spec: Array = SURFACES[prefix]
			mat = INTERIOR_KIT.surface(str(spec[0]), float(spec[1])).duplicate()
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.albedo_color = color.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.45)
			break
	mesh_inst.material_override = mat

	_tent_root.add_child(mesh_inst)
	return mesh_inst


func _category_for_node(node_name: String, color: Color) -> String:
	var n = node_name.to_lower()
	if n.contains("floor") or n.contains("rug"):
		return "floor"
	if n.contains("wall") or n.contains("ceiling"):
		return "decor_fabric"
	if n.contains("table") or n.contains("shelf") or n.contains("crate"):
		return "decor_wood"
	if n.contains("catalog"):
		return "decor_paper"
	if n.contains("zip") or n.contains("lantern"):
		return "decor_metal"
	if n.contains("sleepingbag") or n.contains("pillow"):
		return "decor_fabric"
	if color.s < 0.20 and color.v > 0.55:
		return "stone"
	return "decor_fabric"



# ── room preparation (see scripts/interior_prep.gd) ──────────────────────────

func set_room(room: Dictionary) -> void:
	_prep.set_room(room)


func play_room_ready() -> void:
	_prep.play_room_ready()


## The torch comes on in here by itself when the room is dark (if it is on, F).
func _update_torch(delta: float) -> void:
	if _torch == null:
		_torch = INTERIOR_TORCH.new()
		_torch.name = "Torch"
		add_child(_torch)
		_torch.setup(_interior_camera, _viewport, _interior_camera.get_parent() as Node3D, layer)
	_torch.update(delta, room_is_dark())


## A tent has no light of its own: dark from dusk.
func room_is_dark() -> bool:
	return _time_state != TIME_DAY
