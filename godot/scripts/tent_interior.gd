extends CanvasLayer

const RETRO_RENDER = preload("res://scripts/retro_render.gd")
## The tent's cross-section: floor half-width and ridge height (metres).
const TENT_HALF_WIDTH := 0.98
const TENT_RIDGE_HEIGHT := 1.26
const INTERIOR_LOOK = preload("res://scripts/interior_look.gd")
const INTERIOR_PREP = preload("res://scripts/interior_prep.gd")

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
var _look = INTERIOR_LOOK.new(48.0, 16.0, 30.0)
var _exit_hint: Control

# Screen-space zones for click detection.
var _catalog_mesh: MeshInstance3D
var _prep = INTERIOR_PREP.new()

var _level2_nodes: Array[String] = [
	"LanternStem",
	"LanternBody",
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
	layer = 80
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
	if _interior_camera == null:
		return
	_tent_level = int(clamp(level, 1, 3))
	if _is_open:
		_apply_level_variant()
		_apply_time_profile()
		_refresh_guest_visuals()
		return
	_is_open = true
	visible = true
	_sync_viewport_to_window()
	_interior_camera.position = Vector3(0.0, 0.50, 0.64)
	_interior_camera.rotation_degrees = Vector3(-7.5, 0.0, 0.0)
	_apply_level_variant()
	_apply_time_profile()
	_refresh_guest_visuals()
	_cam_base_rot = _interior_camera.rotation
	_look.reset()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func close_tent() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	request_close.emit()


func _process(delta: float) -> void:
	if not _is_open or _interior_camera == null:
		return
	_apply_idle_mouse_look(delta)
	if _exit_hint == null:
		_exit_hint = INTERIOR_LOOK.make_exit_hint(self)
	INTERIOR_LOOK.update_exit_hint(_exit_hint, get_viewport(), delta)


func _apply_idle_mouse_look(delta: float) -> void:
	var offset: Vector3 = _look.update(delta, INTERIOR_LOOK.cursor_of(get_viewport()), INTERIOR_LOOK.key_axis())
	_interior_camera.rotation = _interior_camera.rotation.lerp(_cam_base_rot + offset, clampf(delta * 12.0, 0.0, 1.0))


func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		close_tent()
		get_viewport().set_input_as_handled()
		return
	if INTERIOR_LOOK.is_exit_event(event, get_viewport()):
		close_tent()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# A press on something to tidy belongs to the tidying, not to the catalog.
		if _prep.is_busy():
			get_viewport().set_input_as_handled()
			return
		_try_click()


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
	_viewport.own_world_3d = true
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
	_tent_env = env

	var world_env = WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)

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
	_interior_camera.fov = 60.0
	_interior_camera.near = 0.05
	_interior_camera.far = 10.0
	_interior_camera.current = true
	_tent_root.add_child(_interior_camera)

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

	# Visible paper catalog.
	_catalog_mesh = _add_box("CatalogBacker", Vector3(0.46, 0.055, -0.18), Vector3(0.36, 0.01, 0.46), Color(0.08, 0.08, 0.08))
	_add_box("Catalog", Vector3(0.46, 0.062, -0.18), Vector3(0.32, 0.02, 0.42), Color(0.96, 0.90, 0.74))
	_add_box("CatalogText1", Vector3(0.46, 0.075, -0.30), Vector3(0.20, 0.005, 0.02), Color(0.12, 0.12, 0.12))
	_add_box("CatalogText2", Vector3(0.46, 0.075, -0.24), Vector3(0.18, 0.005, 0.02), Color(0.12, 0.12, 0.12))
	_add_box("CatalogText3", Vector3(0.46, 0.075, -0.18), Vector3(0.16, 0.005, 0.02), Color(0.12, 0.12, 0.12))
	_add_box("CatalogPic", Vector3(0.44, 0.075, -0.08), Vector3(0.12, 0.005, 0.12), Color(0.74, 0.36, 0.24))
	_add_box("CatalogMark", Vector3(0.56, 0.075, -0.08), Vector3(0.03, 0.005, 0.12), Color(0.92, 0.24, 0.22))

	# Level-based props.
	var lantern_stem = _add_box("LanternStem", Vector3(0.0, 0.90, -0.56), Vector3(0.03, 0.28, 0.03), Color(0.22, 0.20, 0.18))
	var lantern_body = _add_box("LanternBody", Vector3(0.0, 1.04, -0.56), Vector3(0.12, 0.12, 0.12), Color(0.96, 0.84, 0.50))
	var storage_crate = _add_box("StorageCrate", Vector3(-0.54, 0.10, 0.56), Vector3(0.30, 0.18, 0.28), Color(0.36, 0.24, 0.16))
	lantern_stem.visible = false
	lantern_body.visible = false
	storage_crate.visible = false

	var rug = _add_box("Rug", Vector3(0.0, 0.03, -0.40), Vector3(1.24, 0.01, 1.10), Color(0.28, 0.36, 0.54))
	var mini_table = _add_box("MiniTable", Vector3(0.56, 0.16, -0.78), Vector3(0.34, 0.12, 0.24), Color(0.46, 0.34, 0.24))
	var mini_shelf = _add_box("MiniShelf", Vector3(-0.56, 0.40, -1.08), Vector3(0.34, 0.40, 0.10), Color(0.40, 0.30, 0.22))
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
	var pillow_off := P.box(_tent_root, Vector3(-0.58, 0.07, 0.05), Vector3(0.36, 0.08, 0.22), P.flat(Color(0.42, 0.40, 0.36)), Vector3(0.0, 0.9, 0.5))
	var tidy_bag := _tent_root.get_node_or_null("SleepingBag")
	var tidy_pillow := _tent_root.get_node_or_null("Pillow")
	if tidy_bag is MeshInstance3D:
		(tidy_bag as MeshInstance3D).material_override = heap_mat
	var bed_body := P.body(_tent_root, Vector3(-0.28, 0.15, -0.45), Vector3(0.9, 0.3, 1.2))
	_prep.register("bed", bed_body, [heap_a, heap_b, pillow_off], [tidy_bag, tidy_pillow])

	var litter := Node3D.new()
	litter.name = "Litter"
	_tent_root.add_child(litter)
	P.can(litter, Vector3(0.30, 0.035, -0.72), true, Color(0.7, 0.12, 0.1), 0.4)
	P.can(litter, Vector3(0.50, 0.035, -0.88), true, Color(0.75, 0.72, 0.68), 1.9)
	P.bottle(litter, Vector3(0.22, 0.04, -0.98), true, 2.6)
	P.paper(litter, Vector3(0.52, 0.03, -1.05), 0.7)
	P.paper(litter, Vector3(0.40, 0.03, -0.62), 2.2)
	var litter_body := P.body(_tent_root, Vector3(0.38, 0.08, -0.85), Vector3(0.55, 0.18, 0.6))
	_prep.register("floor", litter_body, [litter], [])
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
			std_mat.albedo_color = color.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.20)
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


func _add_box(node_name: String, pos: Vector3, box_size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = node_name
	var box = BoxMesh.new()
	box.size = box_size
	mesh_inst.mesh = box
	mesh_inst.position = pos
	var category = _category_for_node(node_name, color)
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
	if _texture_style != null:
		var tex = _texture_style.pick_texture(category, color)
		if tex != null:
			mat.albedo_texture = tex
			mat.albedo_color = color.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.20)
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
