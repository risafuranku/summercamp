extends CanvasLayer

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
const CABIN_GUEST_SPRITE_PIXEL_SIZE := 0.0032
const CABIN_GUEST_TARGET_HEIGHT := 1.62
const CABIN_GUEST_STAND_POINTS := [
	Vector3(-0.20, 0.82, -0.44),
	Vector3(0.24, 0.82, -0.30),
]

var _is_open: bool = false
var _cabin_level: int = 1
var _viewport_container: SubViewportContainer
var _viewport: SubViewport
var _interior_camera: Camera3D
var _cabin_root: Node3D
var _guest_visual_root: Node3D
var _guest_occupants: Array = []
var _room_env: Environment
var _main_light: OmniLight3D
var _window_view_sky: MeshInstance3D
var _window_view_ground: MeshInstance3D
var _window_view_trees: MeshInstance3D
var _light_switch_body: StaticBody3D
var _light_switch_mesh: MeshInstance3D
var _light_switch_tex_on: Texture2D
var _light_switch_tex_off: Texture2D
var _manual_lights_on: bool = true
var _grid_power_available: bool = true
var _manual_light_tween: Tween
var _is_day_mode: bool = true
var _time_state: int = TIME_DAY
var _daylight_factor: float = 0.0
var _sunlight_color: Color = Color(1.0, 0.95, 0.84)
var _barrel_overlay: ColorRect
var _cam_base_rot: Vector3 = Vector3.ZERO
var _level2_nodes: Array[String] = ["WallLamp", "StorageChest"]
var _level3_nodes: Array[String] = ["MiniFridge", "Rug", "WallShelf", "GuestTVTableBase", "GuestTVTableTop", "GuestTVBody", "GuestTVScreen", "GuestTVAntennaL", "GuestTVAntennaR", "WallPictureLv3"]
var _texture_style
var _bathroom_root: Node3D
var _active_room: String = "main"
var _swipe_overlay: ColorRect
var _swipe_tween: Tween
var _swipe_animating: bool = false

# Screen-space active zones.
var _catalog_rect: Rect2 = Rect2(0.58, 0.58, 0.30, 0.26)


func _ready() -> void:
	_texture_style = TEXTURE_STYLE_SCRIPT.new()
	layer = 80
	visible = false
	_build_viewport()
	_sync_viewport_to_window()
	_update_swipe_overlay_size()
	_build_cabin_room()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_sync_viewport_to_window()
		_update_swipe_overlay_size()


func is_open() -> bool:
	return _is_open


func set_is_day(is_day: bool) -> void:
	_time_state = TIME_DAY if is_day else TIME_NIGHT
	_is_day_mode = is_day
	_apply_time_profile()


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
	_apply_time_profile(true)


func set_guest_occupants(entries: Array) -> void:
	_guest_occupants.clear()
	for entry_any in entries:
		if entry_any is Dictionary:
			_guest_occupants.append((entry_any as Dictionary).duplicate(true))
	_refresh_guest_visuals()


func open_cabin(level: int = 1) -> void:
	_cabin_level = clampi(level, 1, 3)
	_manual_lights_on = true
	_apply_switch_visual()
	if _is_open:
		_apply_level_variant()
		_apply_time_profile()
		_refresh_guest_visuals()
		_cam_base_rot = _interior_camera.rotation
		return
	if _interior_camera == null:
		return
	_is_open = true
	visible = true
	_sync_viewport_to_window()
	_interior_camera.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
	_set_cabin_room("main", false)
	_apply_level_variant()
	_apply_time_profile()
	_refresh_guest_visuals()
	_cam_base_rot = _interior_camera.rotation
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func close_cabin() -> void:
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


func _apply_idle_mouse_look(delta: float) -> void:
	var screen_size = get_viewport().get_visible_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return
	var mouse_pos = get_viewport().get_mouse_position()
	var nx = clamp(((mouse_pos.x / screen_size.x) - 0.5) * 2.0, -1.0, 1.0)
	var ny = clamp(((mouse_pos.y / screen_size.y) - 0.5) * 2.0, -1.0, 1.0)
	var yaw = deg_to_rad(-nx * 3.4)
	var pitch = deg_to_rad(-ny * 2.2)
	var target = _cam_base_rot + Vector3(pitch, yaw, 0.0)
	_interior_camera.rotation = _interior_camera.rotation.lerp(target, clamp(delta * 5.0, 0.0, 1.0))


func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		close_cabin()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_event = event as InputEventMouseButton
		if _try_click_world(mouse_event):
			get_viewport().set_input_as_handled()
			return
		_try_click(mouse_event)
	
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event = event as InputEventKey
		if key_event.physical_keycode == KEY_D:
			_switch_cabin_room(1)
			get_viewport().set_input_as_handled()
			return
		if key_event.physical_keycode == KEY_A:
			_switch_cabin_room(-1)
			get_viewport().set_input_as_handled()
			return
		if key_event.physical_keycode == KEY_L:
			_toggle_manual_lights()
			get_viewport().set_input_as_handled()
			return


func _try_click(_event: InputEventMouseButton) -> void:
	var main_vp = get_viewport()
	if main_vp == null:
		return
	var mouse_pos = main_vp.get_mouse_position()
	var screen_size = main_vp.get_visible_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return
	var norm = mouse_pos / screen_size

	# Upgrade catalog on table.
	if _catalog_rect.has_point(norm):
		request_upgrade.emit()
		return


func _try_click_world(event: InputEventMouseButton) -> bool:
	var hit = _raycast_world(event.position)
	if hit.is_empty():
		return false
	var collider = hit.get("collider", null) as Node
	if collider == null:
		return false
	if _node_has_click_type(collider, "cabin_light_switch"):
		_toggle_manual_lights()
		return true
	return false


func _node_has_click_type(node: Node, click_type: String) -> bool:
	var current = node
	while current != null:
		if str(current.get_meta("interior_click_type", "")) == click_type:
			return true
		current = current.get_parent()
	return false


func _raycast_world(mouse_pos: Vector2) -> Dictionary:
	if _interior_camera == null or _viewport == null:
		return {}
	var world = _viewport.get_world_3d()
	if world == null:
		return {}
	var screen_size = get_viewport().get_visible_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return {}
	var local_mouse = Vector2(
		clamp(mouse_pos.x / screen_size.x, 0.0, 1.0) * float(_viewport.size.x),
		clamp(mouse_pos.y / screen_size.y, 0.0, 1.0) * float(_viewport.size.y)
	)
	var ray_origin = _interior_camera.project_ray_origin(local_mouse)
	var ray_dir = _interior_camera.project_ray_normal(local_mouse)
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + (ray_dir * 24.0))
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return world.direct_space_state.intersect_ray(query)


func _build_light_switch() -> void:
	if _cabin_root == null:
		return
	_light_switch_tex_on = _pick_light_texture("cabin_switch_on", Color(0.82, 0.78, 0.66))
	_light_switch_tex_off = _pick_light_texture("cabin_switch_off", Color(0.66, 0.64, 0.58))
	var switch_body = StaticBody3D.new()
	switch_body.name = "CabinLightSwitch"
	switch_body.position = Vector3(1.38, 1.24, 0.84)
	switch_body.rotation = Vector3(0.0, -PI * 0.5, 0.0)
	switch_body.set_meta("interior_click_type", "cabin_light_switch")
	var switch_mesh = MeshInstance3D.new()
	switch_mesh.name = "SwitchVisual"
	var switch_box = BoxMesh.new()
	switch_box.size = Vector3(0.08, 0.32, 0.20)
	switch_mesh.mesh = switch_box
	var switch_mat := StandardMaterial3D.new()
	switch_mat.albedo_color = Color(0.82, 0.78, 0.66, 1.0)
	switch_mat.roughness = 0.96
	switch_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	switch_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	switch_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	switch_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	switch_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	switch_mat.emission_enabled = true
	switch_mat.emission = Color(0.16, 0.14, 0.10, 1.0)
	switch_mesh.material_override = switch_mat
	switch_body.add_child(switch_mesh)
	var switch_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(0.22, 0.46, 0.28)
	switch_shape.shape = box_shape
	switch_body.add_child(switch_shape)
	_cabin_root.add_child(switch_body)
	_light_switch_body = switch_body
	_light_switch_mesh = switch_mesh
	_apply_switch_visual()


func _pick_light_texture(category: String, color: Color) -> Texture2D:
	if _texture_style == null:
		return null
	return _texture_style.pick_texture(category, color)


func _apply_switch_visual() -> void:
	if _light_switch_mesh == null:
		return
	var switch_mat = _light_switch_mesh.material_override as StandardMaterial3D
	if switch_mat == null:
		return
	var wanted_tex: Texture2D = _light_switch_tex_on if _manual_lights_on else _light_switch_tex_off
	if wanted_tex != null:
		switch_mat.albedo_texture = wanted_tex
		switch_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
		return
	switch_mat.albedo_texture = null
	switch_mat.albedo_color = Color(0.84, 0.80, 0.66, 1.0) if _manual_lights_on else Color(0.58, 0.56, 0.52, 1.0)


func _toggle_manual_lights() -> void:
	_manual_lights_on = not _manual_lights_on
	_apply_switch_visual()
	_apply_time_profile(true)


func _build_viewport() -> void:
	_viewport_container = SubViewportContainer.new()
	_viewport_container.name = "CabinViewportContainer"
	_viewport_container.anchor_right = 1.0
	_viewport_container.anchor_bottom = 1.0
	_viewport_container.stretch = true
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_viewport_container)

	_viewport = SubViewport.new()
	_viewport.name = "CabinViewport"
	_viewport.own_world_3d = true
	_viewport.size = INTERIOR_RENDER_MIN_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.handle_input_locally = false
	_viewport_container.add_child(_viewport)

	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.66, 0.70)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.82, 0.78)
	env.ambient_light_energy = 0.98
	_room_env = env

	var world_env = WorldEnvironment.new()
	world_env.environment = env
	_viewport.add_child(world_env)

	# Interior-only barrel/fisheye pass.
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
	_barrel_overlay.material = barrel_mat
	_barrel_overlay.visible = false
	add_child(_barrel_overlay)

	_swipe_overlay = ColorRect.new()
	_swipe_overlay.name = "CabinSwipe"
	_swipe_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_swipe_overlay.color = Color(0.04, 0.05, 0.06, 0.92)
	_swipe_overlay.visible = false
	add_child(_swipe_overlay)
	_update_swipe_overlay_size()


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


func _build_cabin_room() -> void:
	_cabin_root = Node3D.new()
	_cabin_root.name = "CabinRoom"
	_viewport.add_child(_cabin_root)
	_guest_visual_root = Node3D.new()
	_guest_visual_root.name = "GuestVisuals"
	_cabin_root.add_child(_guest_visual_root)
	_light_switch_body = null
	_light_switch_mesh = null
	_bathroom_root = Node3D.new()
	_bathroom_root.name = "BathroomRoom"
	_viewport.add_child(_bathroom_root)

	_interior_camera = Camera3D.new()
	_interior_camera.name = "CabinCamera"
	_interior_camera.position = Vector3(0.0, 1.5, 1.0)
	_interior_camera.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
	_interior_camera.fov = 60.0
	_interior_camera.current = true
	_cabin_root.add_child(_interior_camera)

	# Warm cabin light.
	_main_light = OmniLight3D.new()
	_main_light.position = Vector3(0.0, 2.2, 0.0)
	_main_light.light_color = Color(0.96, 0.93, 0.84)
	_main_light.light_energy = 1.55
	_main_light.omni_range = 7.0
	_main_light.omni_attenuation = 1.2
	_main_light.shadow_enabled = true
	_cabin_root.add_child(_main_light)

	# Dimensions.
	var w = 3.0
	var d = 3.0
	var h = 2.6
	var wall_col = Color(0.60, 0.46, 0.32)
	var floor_col = Color(0.52, 0.40, 0.28)

	# Floor.
	_add_box(_cabin_root, "Floor", Vector3(0.0, 0.0, 0.0), Vector3(w, 0.1, d), floor_col)
	# Ceiling.
	_add_box(_cabin_root, "Ceiling", Vector3(0.0, h, 0.0), Vector3(w, 0.1, d), wall_col)
	# Back wall.
	_add_box(_cabin_root, "BackWall", Vector3(0.0, h*0.5, -d*0.5), Vector3(w, h, 0.1), wall_col)
	# Left wall.
	_add_box(_cabin_root, "LeftWall", Vector3(-w*0.5, h*0.5, 0.0), Vector3(0.1, h, d), wall_col)
	# Right wall (with door gap).
	#   We keep the door visual on the right wall for consistent room orientation.
	_add_box(_cabin_root, "RightWallBack", Vector3(w*0.5, h*0.5, -d*0.35), Vector3(0.1, h, d*0.3), wall_col)
	_add_box(_cabin_root, "RightWallFront", Vector3(w*0.5, h*0.5, d*0.35), Vector3(0.1, h, d*0.3), wall_col)
	_add_box(_cabin_root, "RightWallTop", Vector3(w*0.5, h*0.85, 0.0), Vector3(0.1, h*0.3, d*0.4), wall_col)

	# Door frame/visual on right wall.
	_add_box(_cabin_root, "DoorFrame", Vector3(w*0.5, h*0.35, 0.0), Vector3(0.12, h*0.7, 0.9), Color(0.28, 0.20, 0.12))
	# Door Frame (text labels removed as requested)
	_add_box(_cabin_root, "DoorFrame", Vector3(w*0.5, h*0.35, 0.0), Vector3(0.12, h*0.7, 0.9), Color(0.28, 0.20, 0.12))
	
	var nav_label = Label3D.new()
	nav_label.text = "D > KOUPELNA"
	nav_label.position = Vector3(w*0.4, 1.5, 0.0)
	nav_label.rotation_degrees = Vector3(0, -90, 0)
	nav_label.font_size = 20
	nav_label.modulate = Color(1.0, 1.0, 1.0, 0.8)
	_cabin_root.add_child(nav_label)

	# Bunk bed (left side).
	_add_box(_cabin_root, "BedFrame", Vector3(-w*0.4, 0.4, -0.6), Vector3(0.9, 0.6, 1.8), Color(0.44, 0.32, 0.22))
	_add_box(_cabin_root, "Mattress", Vector3(-w*0.4, 0.72, -0.6), Vector3(0.8, 0.1, 1.7), Color(0.46, 0.62, 0.84))
	_add_box(_cabin_root, "Pillow", Vector3(-w*0.4, 0.8, -1.3), Vector3(0.6, 0.1, 0.3), Color(0.7, 0.7, 0.7))

	# Small table (back right).
	_add_box(_cabin_root, "Table", Vector3(0.8, 0.5, -1.0), Vector3(0.8, 0.05, 0.8), Color(0.54, 0.40, 0.26))
	_add_box(_cabin_root, "TableLeg", Vector3(0.8, 0.25, -1.0), Vector3(0.1, 0.5, 0.1), Color(0.44, 0.32, 0.22))
	_add_box(_cabin_root, "UpgradeCatalog", Vector3(0.86, 0.54, -1.02), Vector3(0.26, 0.02, 0.20), Color(0.84, 0.78, 0.68))
	_add_box(_cabin_root, "UpgradeCatalogInk1", Vector3(0.86, 0.552, -1.08), Vector3(0.18, 0.004, 0.02), Color(0.18, 0.16, 0.14))
	_add_box(_cabin_root, "UpgradeCatalogInk2", Vector3(0.86, 0.552, -1.02), Vector3(0.16, 0.004, 0.02), Color(0.18, 0.16, 0.14))
	_add_box(_cabin_root, "UpgradeCatalogInk3", Vector3(0.86, 0.552, -0.96), Vector3(0.14, 0.004, 0.02), Color(0.18, 0.16, 0.14))
	var up_lbl = Label3D.new()
	up_lbl.text = "KATALOG"
	up_lbl.position = Vector3(0.86, 0.57, -1.18)
	up_lbl.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	up_lbl.font_size = 12
	up_lbl.modulate = Color(0.34, 0.28, 0.20, 0.8)
	_cabin_root.add_child(up_lbl)

	# Level props.
	var wall_lamp = _add_box(_cabin_root, "WallLamp", Vector3(-1.36, 1.74, -0.38), Vector3(0.08, 0.22, 0.12), Color(0.90, 0.80, 0.52))
	var storage_chest = _add_box(_cabin_root, "StorageChest", Vector3(-1.06, 0.22, 0.62), Vector3(0.44, 0.24, 0.30), Color(0.40, 0.28, 0.18))
	var mini_fridge = _add_box(_cabin_root, "MiniFridge", Vector3(1.12, 0.38, 0.78), Vector3(0.36, 0.70, 0.34), Color(0.76, 0.80, 0.86))
	var rug = _add_box(_cabin_root, "Rug", Vector3(0.0, 0.03, -0.20), Vector3(1.18, 0.01, 0.86), Color(0.34, 0.24, 0.20))
	var wall_shelf = _add_box(_cabin_root, "WallShelf", Vector3(1.06, 1.22, -1.18), Vector3(0.44, 0.10, 0.16), Color(0.42, 0.30, 0.22))
	var guest_tv_table_base = _add_box(_cabin_root, "GuestTVTableBase", Vector3(0.74, 0.26, -1.08), Vector3(0.76, 0.52, 0.44), Color(0.42, 0.30, 0.22))
	var guest_tv_table_top = _add_box(_cabin_root, "GuestTVTableTop", Vector3(0.74, 0.56, -1.08), Vector3(0.84, 0.06, 0.50), Color(0.52, 0.38, 0.28))
	var guest_tv_body = _add_box(_cabin_root, "GuestTVBody", Vector3(0.74, 0.86, -1.18), Vector3(0.62, 0.36, 0.28), Color(0.38, 0.42, 0.50))
	var guest_tv_screen = _add_box(_cabin_root, "GuestTVScreen", Vector3(0.74, 0.86, -1.03), Vector3(0.52, 0.24, 0.03), Color(0.56, 0.60, 0.68))
	var guest_tv_antenna_l = _add_box(_cabin_root, "GuestTVAntennaL", Vector3(0.60, 1.12, -1.22), Vector3(0.02, 0.18, 0.02), Color(0.30, 0.34, 0.40))
	var guest_tv_antenna_r = _add_box(_cabin_root, "GuestTVAntennaR", Vector3(0.88, 1.12, -1.22), Vector3(0.02, 0.18, 0.02), Color(0.30, 0.34, 0.40))
	var wall_picture_lv3 = _add_box(_cabin_root, "WallPictureLv3", Vector3(-0.02, 1.66, -1.45), Vector3(1.04, 0.70, 0.03), Color(0.76, 0.72, 0.64))
	wall_lamp.visible = false
	storage_chest.visible = false
	mini_fridge.visible = false
	rug.visible = false
	wall_shelf.visible = false
	guest_tv_table_base.visible = false
	guest_tv_table_top.visible = false
	guest_tv_body.visible = false
	guest_tv_screen.visible = false
	guest_tv_antenna_l.visible = false
	guest_tv_antenna_r.visible = false
	wall_picture_lv3.visible = false

	# Window (back wall).
	var win = _add_box(_cabin_root, "WindowFrame", Vector3(0.0, 1.6, -d*0.48), Vector3(1.2, 0.8, 0.05), Color(0.2, 0.15, 0.1))
	win.rotation_degrees = Vector3(0, 0, 0)

	# Placeholder view outside the window.
	_window_view_sky = MeshInstance3D.new()
	var sky_box = BoxMesh.new()
	sky_box.size = Vector3(1.04, 0.62, 0.02)
	_window_view_sky.mesh = sky_box
	_window_view_sky.position = Vector3(0.0, 1.64, -d * 0.62)
	var sky_mat = StandardMaterial3D.new()
	sky_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sky_mat.albedo_color = Color(0.56, 0.74, 0.90)
	if _texture_style != null:
		var sky_tex = _texture_style.pick_texture("sky", sky_mat.albedo_color)
		if sky_tex != null:
			sky_mat.albedo_texture = sky_tex
			sky_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_window_view_sky.material_override = sky_mat
	_cabin_root.add_child(_window_view_sky)

	_window_view_ground = MeshInstance3D.new()
	var ground_box = BoxMesh.new()
	ground_box.size = Vector3(1.04, 0.22, 0.03)
	_window_view_ground.mesh = ground_box
	_window_view_ground.position = Vector3(0.0, 1.30, -d * 0.615)
	var ground_mat = StandardMaterial3D.new()
	ground_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ground_mat.albedo_color = Color(0.28, 0.46, 0.26)
	if _texture_style != null:
		var ground_tex = _texture_style.pick_texture("grass", ground_mat.albedo_color)
		if ground_tex != null:
			ground_mat.albedo_texture = ground_tex
			ground_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_window_view_ground.material_override = ground_mat
	_cabin_root.add_child(_window_view_ground)

	_window_view_trees = MeshInstance3D.new()
	var trees_box = BoxMesh.new()
	trees_box.size = Vector3(0.90, 0.16, 0.02)
	_window_view_trees.mesh = trees_box
	_window_view_trees.position = Vector3(0.02, 1.44, -d * 0.617)
	var trees_mat = StandardMaterial3D.new()
	trees_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trees_mat.albedo_color = Color(0.16, 0.30, 0.16)
	if _texture_style != null:
		var trees_tex = _texture_style.pick_texture("foliage", trees_mat.albedo_color)
		if trees_tex != null:
			trees_mat.albedo_texture = trees_tex
			trees_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_window_view_trees.material_override = trees_mat
	_cabin_root.add_child(_window_view_trees)

	# Window glass (semi transparent overlay).
	var glass = MeshInstance3D.new()
	var g_box = BoxMesh.new()
	g_box.size = Vector3(1.0, 0.6, 0.04)
	glass.mesh = g_box
	glass.position = Vector3(0.0, 1.6, -d*0.48 + 0.01)
	var g_mat = StandardMaterial3D.new()
	g_mat.albedo_color = Color(0.4, 0.6, 0.8, 0.26)
	g_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.material_override = g_mat
	_cabin_root.add_child(glass)
	_build_light_switch()
	_build_bathroom_room()
	_apply_level_variant()
	_apply_time_profile()


func _build_bathroom_room() -> void:
	if _bathroom_root == null:
		return
	var w = 2.4
	var d = 2.4
	var h = 2.6
	
	_add_box(_bathroom_root, "BFloor", Vector3(0.0, 0.0, 0.0), Vector3(w, 0.1, d), Color(0.36, 0.42, 0.48))
	_add_box(_bathroom_root, "BCeiling", Vector3(0.0, h, 0.0), Vector3(w, 0.1, d), Color(0.60, 0.46, 0.32))
	var wall_col = Color(0.50, 0.48, 0.44)
	_add_box(_bathroom_root, "BWallBack", Vector3(0.0, h*0.5, -d*0.5), Vector3(w, h, 0.1), wall_col)
	_add_box(_bathroom_root, "BWallFront", Vector3(0.0, h*0.5, d*0.5), Vector3(w, h, 0.1), wall_col)
	_add_box(_bathroom_root, "BWallLeft", Vector3(-w*0.5, h*0.5, 0.0), Vector3(0.1, h, d), wall_col)
	_add_box(_bathroom_root, "BWallRight", Vector3(w*0.5, h*0.5, 0.0), Vector3(0.1, h, d), wall_col)

	var nav = Label3D.new()
	nav.text = "< A POKOJ"
	nav.position = Vector3(-w * 0.4, 1.5, 0.0)
	nav.rotation_degrees = Vector3(0, 90, 0)
	nav.font_size = 20
	nav.modulate = Color(1.0, 1.0, 1.0, 0.8)
	_bathroom_root.add_child(nav)
	
	# Props based on level (will be controlled by _refresh_level_textures via visibility/replacement?)
	# Or better, just build all and toggle visibility in _apply_level_variant.
	
	# Level 1: Bucket
	_add_box(_bathroom_root, "Bucket", Vector3(0.6, 0.3, -0.6), Vector3(0.4, 0.5, 0.4), Color(0.40, 0.36, 0.32))
	
	# Level 2: Toilet + Sink
	_add_box(_bathroom_root, "ToiletLv2", Vector3(0.6, 0.4, -0.6), Vector3(0.5, 0.6, 0.7), Color(0.70, 0.72, 0.74))
	_add_box(_bathroom_root, "SinkLv2", Vector3(-0.6, 0.9, -0.8), Vector3(0.6, 0.2, 0.5), Color(0.80, 0.82, 0.84))
	_add_box(_bathroom_root, "SinkMirror", Vector3(-0.6, 1.5, -1.1), Vector3(0.5, 0.6, 0.05), Color(0.60, 0.70, 0.80))
	
	# Level 3: Shower
	_add_box(_bathroom_root, "ShowerBase", Vector3(-0.6, 0.1, 0.6), Vector3(0.8, 0.1, 0.8), Color(0.90, 0.92, 0.94))
	_add_box(_bathroom_root, "ShowerHead", Vector3(-0.6, 1.9, 0.9), Vector3(0.2, 0.1, 0.2), Color(0.60, 0.64, 0.70))
	_add_box(_bathroom_root, "ShowerCurtain", Vector3(-0.3, 1.2, 0.6), Vector3(0.05, 1.8, 0.8), Color(0.40, 0.60, 0.50))



func _apply_level_variant() -> void:
	var wall_col = Color(0.60, 0.46, 0.32)
	var floor_col = Color(0.52, 0.40, 0.28)
	var bed_col = Color(0.46, 0.62, 0.84)
	match _cabin_level:
		2:
			wall_col = Color(0.54, 0.40, 0.30)
			floor_col = Color(0.42, 0.34, 0.26)
			bed_col = Color(0.62, 0.48, 0.36)
		3:
			wall_col = Color(0.46, 0.54, 0.66)
			floor_col = Color(0.34, 0.38, 0.46)
			bed_col = Color(0.64, 0.76, 0.92)

	_refresh_level_textures()
	_set_node_color("BackWall", wall_col)
	_set_node_color("LeftWall", wall_col)
	_set_node_color("RightWallBack", wall_col)
	_set_node_color("RightWallFront", wall_col)
	_set_node_color("RightWallTop", wall_col.darkened(0.06))
	_set_node_color("Ceiling", wall_col.darkened(0.10))
	_set_node_color("Floor", floor_col)
	_set_node_color("Mattress", bed_col)

	for node_name in _level2_nodes:
		_set_node_visible(node_name, _cabin_level >= 2)
	for node_name in _level3_nodes:
		_set_node_visible(node_name, _cabin_level >= 3)
	
	_set_bathroom_variant()


func _set_bathroom_variant() -> void:
	if _bathroom_root == null:
		return
	var lv = _cabin_level
	_set_node_visible_in(_bathroom_root, "Bucket", lv == 1)
	_set_node_visible_in(_bathroom_root, "ToiletLv2", lv >= 2)
	_set_node_visible_in(_bathroom_root, "SinkLv2", lv >= 2)
	_set_node_visible_in(_bathroom_root, "SinkMirror", lv >= 2)
	_set_node_visible_in(_bathroom_root, "ShowerBase", lv == 3)
	_set_node_visible_in(_bathroom_root, "ShowerHead", lv == 3)
	_set_node_visible_in(_bathroom_root, "ShowerCurtain", lv == 3)


func _refresh_level_textures() -> void:
	if _cabin_root == null or _texture_style == null:
		return
	for child in _cabin_root.get_children():
		var mesh_inst = child as MeshInstance3D
		if mesh_inst == null:
			continue
		var std_mat = mesh_inst.material_override as StandardMaterial3D
		if std_mat == null:
			continue
		var category = _category_for_node(mesh_inst.name, std_mat.albedo_color)
		var tex = _texture_style.pick_texture(category, std_mat.albedo_color)
		if tex != null:
			std_mat.albedo_texture = tex
			std_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)


func _cabin_level_category(slot: String) -> String:
	var lv = _cabin_level
	# Swap Lv2 (Red) and Lv3 (Blue) materials/textures as requested
	if lv == 2: lv = 3
	elif lv == 3: lv = 2
	return "cabin_lv%d_%s" % [lv, slot]


func _set_node_visible(node_name: String, visible_flag: bool) -> void:
	if _cabin_root == null:
		return
	var node = _cabin_root.get_node_or_null(node_name) as Node3D
	if node != null:
		node.visible = visible_flag


func _set_node_visible_in(parent: Node, node_name: String, visible_flag: bool) -> void:
	if parent == null:
		return
	var node = parent.get_node_or_null(node_name) as Node3D
	if node != null:
		node.visible = visible_flag


func _switch_cabin_room(direction: int) -> void:
	if _swipe_animating:
		return
	var target = "main"
	if _active_room == "main" and direction > 0:
		if _cabin_level >= 2:
			target = "bathroom"
		else:
			print("[CabinInterior] Bathroom not available for Level 1 cabin.")
			return
	elif _active_room == "bathroom" and direction < 0:
		target = "main"
	
	if target == _active_room:
		return
	_play_room_swipe(target, direction)


func _play_room_swipe(target_room: String, direction: int) -> void:
	if _swipe_overlay == null:
		_set_cabin_room(target_room, true)
		return
	_update_swipe_overlay_size()
	var screen_size = get_viewport().get_visible_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		_set_cabin_room(target_room, true)
		return
	var overlay_width = _swipe_overlay.size.x
	var start_x = screen_size.x if direction >= 0 else -overlay_width
	var mid_x = -screen_size.x * 0.06
	var end_x = -overlay_width if direction >= 0 else screen_size.x
	_swipe_animating = true
	_swipe_overlay.visible = true
	_swipe_overlay.position = Vector2(start_x, 0.0)
	if _swipe_tween != null and is_instance_valid(_swipe_tween):
		_swipe_tween.kill()
	_swipe_tween = create_tween()
	_swipe_tween.tween_property(_swipe_overlay, "position:x", mid_x, 0.11).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_swipe_tween.tween_callback(Callable(self, "_set_cabin_room").bind(target_room, true))
	_swipe_tween.tween_property(_swipe_overlay, "position:x", end_x, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_swipe_tween.tween_callback(Callable(self, "_finish_room_swipe"))


func _finish_room_swipe() -> void:
	_swipe_animating = false
	if _swipe_overlay != null:
		_swipe_overlay.visible = false


func _update_swipe_overlay_size() -> void:
	if _swipe_overlay == null:
		return
	var screen_size = get_viewport().get_visible_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return
	_swipe_overlay.size = Vector2(screen_size.x * 1.18, screen_size.y)


func _set_cabin_room(room: String, update_camera: bool = true) -> void:
	if _cabin_root == null or _bathroom_root == null:
		return
	_active_room = room
	_cabin_root.visible = (room == "main")
	_bathroom_root.visible = (room == "bathroom")
	
	if update_camera and _interior_camera != null:
		if room == "bathroom":
			_interior_camera.position = Vector3(0.0, 1.45, 1.1)
			_interior_camera.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
		else:
			_interior_camera.position = Vector3(0.0, 1.5, 1.0)
			_interior_camera.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
	_cam_base_rot = _interior_camera.rotation


func _set_node_color(node_name: String, color: Color) -> void:
	if _cabin_root == null:
		return
	var mesh_inst = _cabin_root.get_node_or_null(node_name) as MeshInstance3D
	if mesh_inst == null:
		return
	var shader_mat = mesh_inst.material_override as ShaderMaterial
	if shader_mat != null:
		shader_mat.set_shader_parameter("base_color", color)
		return
	var std_mat = mesh_inst.material_override as StandardMaterial3D
	if std_mat != null and std_mat.albedo_texture == null:
		std_mat.albedo_color = color


func _apply_time_profile(animated: bool = false) -> void:
	if _room_env != null:
		match _time_state:
			TIME_DAY:
				_room_env.background_color = Color(0.62, 0.66, 0.70)
				_room_env.ambient_light_color = Color(0.78, 0.82, 0.78)
				_room_env.ambient_light_energy = 0.98
			TIME_EVENING:
				_room_env.background_color = Color(0.24, 0.20, 0.22)
				_room_env.ambient_light_color = Color(0.48, 0.42, 0.44)
				_room_env.ambient_light_energy = 0.52
			_:
				_room_env.background_color = Color(0.08, 0.10, 0.14)
				_room_env.ambient_light_color = Color(0.22, 0.26, 0.34)
				_room_env.ambient_light_energy = 0.04

	if _main_light != null:
		match _time_state:
			TIME_DAY:
				_main_light.light_color = Color(1.0, 0.96, 0.86)
				_main_light.light_energy = 1.66
			TIME_EVENING:
				_main_light.light_color = Color(0.92, 0.76, 0.64)
				_main_light.light_energy = 0.84
			_:
				_main_light.light_color = Color(0.66, 0.72, 0.90)
				_main_light.light_energy = 0.08

	if _window_view_sky != null:
		var sky_mat = _window_view_sky.material_override as StandardMaterial3D
		if sky_mat != null:
			match _time_state:
				TIME_DAY:
					sky_mat.albedo_color = Color(0.58, 0.76, 0.94)
				TIME_EVENING:
					sky_mat.albedo_color = Color(0.70, 0.46, 0.34)
				_:
					sky_mat.albedo_color = Color(0.10, 0.14, 0.24)

	if _window_view_ground != null:
		var ground_mat = _window_view_ground.material_override as StandardMaterial3D
		if ground_mat != null:
			match _time_state:
				TIME_DAY:
					ground_mat.albedo_color = Color(0.30, 0.48, 0.28)
				TIME_EVENING:
					ground_mat.albedo_color = Color(0.36, 0.28, 0.22)
				_:
					ground_mat.albedo_color = Color(0.08, 0.14, 0.10)

	if _window_view_trees != null:
		var trees_mat = _window_view_trees.material_override as StandardMaterial3D
		if trees_mat != null:
			match _time_state:
				TIME_DAY:
					trees_mat.albedo_color = Color(0.14, 0.30, 0.16)
				TIME_EVENING:
					trees_mat.albedo_color = Color(0.20, 0.18, 0.14)
				_:
					trees_mat.albedo_color = Color(0.05, 0.08, 0.10)

	var daylight = clampf(_daylight_factor, 0.0, 1.0)
	var sun_tint = _sunlight_color.lerp(Color(1.0, 0.96, 0.90), 0.25)
	if _room_env != null:
		_room_env.ambient_light_color = _room_env.ambient_light_color.lerp(sun_tint, 0.16 * daylight)
		_room_env.ambient_light_energy = lerpf(_room_env.ambient_light_energy * 0.82, _room_env.ambient_light_energy * 1.18, daylight)
	if _main_light != null:
		_main_light.light_color = _main_light.light_color.lerp(sun_tint, 0.10 * daylight)
		_main_light.light_energy = lerpf(_main_light.light_energy * 0.88, _main_light.light_energy * 1.10, daylight)
	if _window_view_sky != null:
		var sky_mat = _window_view_sky.material_override as StandardMaterial3D
		if sky_mat != null:
			sky_mat.albedo_color = sky_mat.albedo_color.lerp(sun_tint, 0.22 * daylight)
	_apply_manual_light_profile(animated)


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
		var stand_pos = CABIN_GUEST_STAND_POINTS[min(i, CABIN_GUEST_STAND_POINTS.size() - 1)]
		if i >= CABIN_GUEST_STAND_POINTS.size():
			stand_pos += Vector3(0.12 * float(i - CABIN_GUEST_STAND_POINTS.size() + 1), 0.0, 0.0)
		sprite.position = stand_pos
		_guest_visual_root.add_child(sprite)


func _create_guest_sprite(entry: Dictionary) -> Sprite3D:
	var sprite = Sprite3D.new()
	var texture = _resolve_guest_texture(entry)
	if texture == null:
		return null
	sprite.texture = texture
	sprite.pixel_size = CABIN_GUEST_SPRITE_PIXEL_SIZE
	sprite.shaded = false
	sprite.double_sided = true
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fit_sprite_height(sprite, texture, CABIN_GUEST_TARGET_HEIGHT)
	return sprite


func _resolve_guest_texture(entry: Dictionary) -> Texture2D:
	var archetype = str(entry.get("archetype", "quiet_guy")).to_lower().strip_edges()
	match archetype:
		"drunk":
			return HOST_DRUNK_TEXTURE
		"cheap_chick", "cheapchick":
			return HOST_CHEAP_TEXTURE
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


func _apply_manual_light_profile(animated: bool) -> void:
	if _main_light == null:
		return
	var target_energy = _main_light.light_energy
	if not _manual_lights_on:
		target_energy *= 0.10
	if not _grid_power_available:
		target_energy = 0.0
	if animated:
		if _manual_light_tween != null and is_instance_valid(_manual_light_tween):
			_manual_light_tween.kill()
		_manual_light_tween = create_tween()
		_manual_light_tween.set_ease(Tween.EASE_IN_OUT)
		_manual_light_tween.set_trans(Tween.TRANS_SINE)
		_manual_light_tween.tween_property(_main_light, "light_energy", target_energy, 0.56)
		return
	_main_light.light_energy = target_energy


func _add_box(parent: Node, node_name: String, pos: Vector3, box_size: Vector3, color: Color) -> MeshInstance3D:
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
			mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mesh_inst.material_override = mat

	parent.add_child(mesh_inst)
	return mesh_inst


func _category_for_node(node_name: String, color: Color) -> String:
	var n = node_name.to_lower()
	if n.contains("catalog"):
		return "decor_paper"
	if n.contains("wallpicture"):
		return "cabin_lv3_front"
	if n.contains("fridge") or n.contains("lamp"):
		return _cabin_level_category("metal")
	if n.contains("tvscreen"):
		return "cabin_lv3_front"
	if n.contains("tvbody") or n.contains("tvantenna"):
		return "cabin_lv3_side"
	if n.contains("mattress") or n.contains("pillow"):
		return _cabin_level_category("bed")
	if n.contains("floor") or n.contains("rug"):
		return _cabin_level_category("floor")
	if n.contains("chest"):
		return _cabin_level_category("drawer") if _cabin_level >= 2 else _cabin_level_category("wood")
	if n.contains("door") or n.contains("frame") or n.contains("table") or n.contains("shelf") or n.contains("bed"):
		return _cabin_level_category("wood")
	if n.contains("wall") or n.contains("ceiling"):
		return _cabin_level_category("wall")
	if color.s < 0.20 and color.v > 0.65:
		return "stone"
	return _cabin_level_category("wood")
