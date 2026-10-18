extends CanvasLayer

## The room swipe is a smooth push (scripts/ui/room_push.gd).
const ROOM_PUSH = preload("res://scripts/ui/room_push.gd")
const RETRO_RENDER = preload("res://scripts/retro_render.gd")
const SLOP_BUCKET_POS := Vector3(1.12, 0.05, 0.62)
## The bed: frame centre on the floor, and the top of its mattress.
const BED_POS := Vector3(-1.0, 0.05, -0.6)
const BED_TOP := 0.59
## Surfaces per cabin level: walls, floor, ceiling (assets/textury/camp).
const LEVEL_SURFACES := {
	1: ["planks_grey", "planks_red", "planks_grey"],
	2: ["knotty_pine", "lino_floor", "ceiling_board"],
	3: ["wallpaper_70s", "parquet", "ceiling_board"],
}
const INTERIOR_LOOK = preload("res://scripts/interior_look.gd")
const INTERIOR_TORCH = preload("res://scripts/ui/interior_torch.gd")
## Your torch, in here when it is dark: it shines where the cursor points.
var _torch: Node
const INTERIOR_PREP = preload("res://scripts/interior_prep.gd")
const INTERIOR_KIT = preload("res://scripts/interior_kit.gd")

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
## The cabin outside (InteriorManager sets it): the windows look out of it into the camp
## (off-axis cameras through each window, like the reception's), not at a picture.
const GLASS_LAYER := 1 << 19
var _anchor: Node3D
var _portals: Array = []          # {vp, cam, quad, frame: Transform3D (room), size: Vector2, ext: Vector3 (model), lv1_only}
var _window_view_ground: MeshInstance3D
## Shown only in the basic cabin (the right wall's window, where better cabins have the
## bathroom door).
var _level1_nodes: Array[String] = []
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
## Standing inside the door of the cabin: most of the room, never the door behind you.
var _look = INTERIOR_LOOK.new(72.0, 28.0, 38.0)
var _exit_hint: Control
var _level2_nodes: Array[String] = ["WallLamp", "Wardrobe", "FridgeSmall"]
var _level2_only: Array[String] = ["PosterLake"]
var _level3_nodes: Array[String] = ["Rug", "WallShelf", "TvOld", "Chair2", "PictureDeer"]
## The room's surfaces, re-skinned per level: {walls: [...], floor, ceiling}.
var _shell: Dictionary = {}
var _bath_shell: Dictionary = {}
var _texture_style
var _bathroom_root: Node3D
var _active_room: String = "main"
var _swipe_overlay: ColorRect
var _swipe_tween: Tween
var _swipe_animating: bool = false

# Screen-space active zones.
var _catalog_mesh: MeshInstance3D
var _side_hints: Control
var _prep = INTERIOR_PREP.new()


func _ready() -> void:
	_texture_style = TEXTURE_STYLE_SCRIPT.new()
	# Under the HUD (65), whose messages show over a room.
	layer = 56
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
	# Registered before it was in the tree (size 0, shrink 1): the low resolution now.
	if _viewport_container != null:
		RETRO_RENDER.apply_to(_viewport_container)
	_cabin_level = clampi(level, 1, 3)
	_manual_lights_on = true
	_apply_switch_visual()
	if _is_open:
		_apply_level_variant()
		_apply_time_profile()
		_refresh_guest_visuals()
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


## The cabin you are in, outside: its windows look out of it.
func set_world_anchor(n: Node3D) -> void:
	_anchor = n


func door_surface() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textury/camp/door_wood.png")
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m


## A pine window frame with a cross bar on a wall (`yaw` turns it to that wall); the glass
## behind is a portal (_add_portal) or, for the front windows you never look out of, dim.
func _frame_window(c: Vector3, size: Vector2, yaw: float, tag: String) -> void:
	var K := INTERIOR_KIT
	var frame := K.surface("knotty_pine", 0.6)
	var holder := Node3D.new()
	holder.name = tag + "Window"
	holder.position = c
	holder.rotation_degrees.y = yaw
	_cabin_root.add_child(holder)
	K.slab(holder, Vector3(size.x + 0.1, 0.07, 0.1), Vector3(0, -size.y * 0.5 - 0.03, 0.02), frame, "Sill")
	K.slab(holder, Vector3(size.x + 0.1, 0.06, 0.08), Vector3(0, size.y * 0.5 + 0.03, 0.0), frame, "Top")
	for x: float in [-size.x * 0.5 - 0.03, size.x * 0.5 + 0.03]:
		K.slab(holder, Vector3(0.06, size.y + 0.1, 0.08), Vector3(x, 0, 0), frame, "Side")
	K.slab(holder, Vector3(0.04, size.y, 0.05), Vector3(0, 0, -0.01), frame, "Mullion")
	K.slab(holder, Vector3(size.x, 0.04, 0.05), Vector3(0, 0.02, -0.01), frame, "Transom")
	if tag == "Front":
		var g := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = size
		g.mesh = q
		var gm := StandardMaterial3D.new()
		gm.albedo_texture = load("res://assets/textury/camp/window_curtain.png")
		gm.albedo_color = Color(0.7, 0.72, 0.74)
		gm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		g.material_override = gm
		g.position = Vector3(0, 0, -0.03)
		holder.add_child(g)
	if tag == "Side":
		_level1_nodes.append(holder.name)


## A window looking out: a quad in the opening shows what a camera sees through the same
## window of the cabin outside (the room maps onto the model by lining the two windows up).
func _add_portal(n: String, centre: Vector3, outward: Vector3, size: Vector2, lv1_only: bool) -> void:
	var vp := SubViewport.new()
	vp.name = n
	vp.size = Vector2i(224, int(224.0 * size.y / size.x))
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_FRUSTUM
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.cull_mask = 0xFFFFF & ~GLASS_LAYER
	vp.add_child(cam)
	var quad := MeshInstance3D.new()
	quad.name = n + "Glass"
	var q := QuadMesh.new()
	q.size = size
	quad.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.albedo_texture = vp.get_texture()
	quad.material_override = m
	var z := -outward.normalized()
	var x := Vector3.UP.cross(z).normalized()
	var frame := Transform3D(Basis(x, Vector3.UP, z), centre)
	quad.transform = frame
	quad.visible = false
	_cabin_root.add_child(quad)
	_portals.append({"vp": vp, "cam": cam, "quad": quad, "frame": frame, "size": size, "outward": outward.normalized(), "lv1_only": lv1_only})


## Each frame while you are in: every window's camera where your eye is, mapped out into
## the camp, the window its near plane (so it moves as you turn, a real view).
func _update_portals() -> void:
	var live := _anchor != null and is_instance_valid(_anchor) and _anchor.is_inside_tree()
	var ws: Vector3 = _anchor.get_meta("wall_size", Vector3(6.24, 2.4, 6.24)) if live else Vector3.ZERO
	for pt in _portals:
		var on: bool = live and _active_room == "main" and (not bool(pt["lv1_only"]) or _cabin_level == 1)
		(pt["quad"] as MeshInstance3D).visible = on
		var vp: SubViewport = pt["vp"]
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
		if not on:
			continue
		if vp.world_3d != _anchor.get_world_3d():
			vp.world_3d = _anchor.get_world_3d()
		var frame: Transform3D = pt["frame"]
		var out: Vector3 = pt["outward"]
		# The same window outside, in the model's space (building_models.cabin()).
		var ext := Vector3(0, ws.y * 0.62, -ws.z * 0.5 - 0.02) if out.z < -0.5 else Vector3(ws.x * 0.5 + 0.02, ws.y * 0.62, 0)
		var room_to_world: Transform3D = _anchor.global_transform * Transform3D(Basis(), ext - frame.origin)
		var eye := _cabin_root.global_transform.affine_inverse() * _interior_camera.global_position
		var e := frame.affine_inverse() * eye
		if e.z < 0.05:
			continue
		var cam: Camera3D = pt["cam"]
		cam.global_transform = Transform3D(room_to_world.basis * frame.basis, room_to_world * eye)
		cam.set_frustum((pt["size"] as Vector2).y, Vector2(-e.x, -e.y), e.z + 0.06, e.z + 220.0)
	if _window_view_sky != null:
		_window_view_sky.visible = not live


func close_cabin() -> void:
	if not _is_open:
		return
	_is_open = false
	if _swipe_tween != null and is_instance_valid(_swipe_tween):
		_swipe_tween.kill()
	ROOM_PUSH.cancel(_viewport_container)
	_swipe_animating = false
	for pt in _portals:
		(pt["vp"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	request_close.emit()


func _process(delta: float) -> void:
	if not _is_open or _interior_camera == null:
		return
	_apply_idle_mouse_look(delta)
	_update_portals()
	_update_torch(delta)
	if _exit_hint == null:
		_exit_hint = INTERIOR_LOOK.make_exit_hint(self)
		_side_hints = INTERIOR_LOOK.make_side_hints(self)
	INTERIOR_LOOK.update_exit_hint(_exit_hint, get_viewport(), delta)
	if _active_room == "bathroom":
		INTERIOR_LOOK.set_side_hints(_side_hints, "Room  [A]", "")
	else:
		INTERIOR_LOOK.set_side_hints(_side_hints, "", "Bathroom  [D]" if _cabin_level >= 2 else "")


func _apply_idle_mouse_look(delta: float) -> void:
	var offset: Vector3 = _look.update(delta, INTERIOR_LOOK.cursor_of(get_viewport()), INTERIOR_LOOK.turn_axis())
	_interior_camera.rotation = _cam_base_rot + offset
	# A/D turn the head; held on at the end of the turn, through the door that way.
	var push: int = _look.take_push()
	if push != 0:
		_switch_cabin_room(push)


func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	if _prep != null and _prep.is_scrubbing():
		return
	# Esc is the pause menu's (main): S or the way out behind you leaves (but not a
	# click on something to tidy, however low on the screen it is).
	if INTERIOR_LOOK.is_exit_event(event, get_viewport()) and not (_prep.is_busy() and event is InputEventMouseButton):
		close_cabin()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_event = event as InputEventMouseButton
		if _prep.is_busy():
			get_viewport().set_input_as_handled()
			return
		var tab := INTERIOR_LOOK.side_tab_at(get_viewport(), _side_hints)
		if tab != 0:
			_switch_cabin_room(tab)
			get_viewport().set_input_as_handled()
			return
		if _try_click_world(mouse_event):
			get_viewport().set_input_as_handled()
			return
		_try_click(mouse_event)
	
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event = event as InputEventKey
		if key_event.physical_keycode == KEY_L:
			_toggle_manual_lights()
			get_viewport().set_input_as_handled()
			return


## The upgrade catalog on screen (normalised), wherever the head is turned.
func _catalog_screen_rect() -> Rect2:
	if _catalog_mesh != null and _catalog_mesh.is_visible_in_tree() and _viewport != null:
		var r := INTERIOR_LOOK.screen_rect_of(_interior_camera, Vector2(_viewport.size), _catalog_mesh)
		if r.has_area():
			return r.grow(0.03)
	return Rect2()


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
	if _catalog_screen_rect().has_point(norm):
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
	var world = _viewport.find_world_3d()
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


## A Grok sprite lying flat on the floor (a rug), or on the ceiling seen from below (the
## light, glowing).
func _flat_sprite(parent: Node3D, tex: String, size: Vector2, pos: Vector3, ceiling: bool, name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var q := QuadMesh.new()
	q.size = size
	q.orientation = PlaneMesh.FACE_Y
	mi.mesh = q
	var m := StandardMaterial3D.new()
	var path := "res://assets/textury/camp/" + tex + ".png"
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if ceiling:
		m.emission_enabled = true
		m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		m.emission_texture = m.albedo_texture
		m.emission = Color(1.0, 0.94, 0.82)
		m.emission_energy_multiplier = 0.7
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


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
	RETRO_RENDER.register(_viewport_container)

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
	_interior_camera.fov = 68.0
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

	# The room: 3 x 3 m, 2.6 m high, floor top at 0.05. Surfaces are skinned per level
	# in _apply_level_variant (LEVEL_SURFACES); the door is on the right wall, the window
	# is a real opening in the back wall.
	var K := INTERIOR_KIT
	var w = 3.0
	var d = 3.0
	var h = 2.6
	var wall_mat := K.surface("planks_grey", 1.2)
	var walls: Array = []
	_shell["floor"] = K.slab(_cabin_root, Vector3(w, 0.1, d), Vector3(0, 0, 0), K.surface("planks_dark", 1.0), "Floor")
	_shell["ceiling"] = K.slab(_cabin_root, Vector3(w, 0.1, d), Vector3(0, h, 0), K.surface("planks_grey", 1.0), "Ceiling")
	# Back wall round the window (1.0 x 0.62 opening centred at y 1.6).
	walls.append(K.slab(_cabin_root, Vector3(1.0, h, 0.1), Vector3(-1.0, h * 0.5, -d * 0.5), wall_mat, "BackWallL"))
	walls.append(K.slab(_cabin_root, Vector3(1.0, h, 0.1), Vector3(1.0, h * 0.5, -d * 0.5), wall_mat, "BackWallR"))
	walls.append(K.slab(_cabin_root, Vector3(1.0, 1.29, 0.1), Vector3(0, 0.645, -d * 0.5), wall_mat, "BackWallLow"))
	walls.append(K.slab(_cabin_root, Vector3(1.0, h - 1.91, 0.1), Vector3(0, (h + 1.91) * 0.5, -d * 0.5), wall_mat, "BackWallHigh"))
	walls.append(K.slab(_cabin_root, Vector3(w, h, 0.1), Vector3(0, h * 0.5, d * 0.5), wall_mat, "FrontWall"))
	walls.append(K.slab(_cabin_root, Vector3(0.1, h, d), Vector3(-w * 0.5, h * 0.5, 0), wall_mat, "LeftWall"))
	walls.append(K.slab(_cabin_root, Vector3(0.1, h, d * 0.3), Vector3(w * 0.5, h * 0.5, -d * 0.35), wall_mat, "RightWallBack"))
	walls.append(K.slab(_cabin_root, Vector3(0.1, h, d * 0.3), Vector3(w * 0.5, h * 0.5, d * 0.35), wall_mat, "RightWallFront"))
	walls.append(K.slab(_cabin_root, Vector3(0.1, h * 0.3, d * 0.4), Vector3(w * 0.5, h * 0.85, 0), wall_mat, "RightWallTop"))
	_shell["walls"] = walls
	# Skirting and a ceiling cornice in dark wood, Build-style trim.
	var trim := K.surface("planks_dark", 0.6)
	for z: float in [-d * 0.5 + 0.06, d * 0.5 - 0.06]:
		K.slab(_cabin_root, Vector3(w, 0.1, 0.03), Vector3(0, 0.1, z), trim, "Skirting")
		K.slab(_cabin_root, Vector3(w, 0.06, 0.04), Vector3(0, h - 0.06, z), trim, "Cornice")
	K.slab(_cabin_root, Vector3(0.03, 0.1, d), Vector3(-w * 0.5 + 0.06, 0.1, 0), trim, "Skirting")

	# The front wall as the cabin has it outside: the door you came in by in the middle,
	# a window either side of it.
	var fz: float = d * 0.5 - 0.055
	K.slab(_cabin_root, Vector3(1.0, 2.02, 0.04), Vector3(0, 1.06, fz + 0.02), trim, "FrontDoorFrame")
	var fdoor := MeshInstance3D.new()
	fdoor.name = "FrontDoor"
	var fdq := QuadMesh.new()
	fdq.size = Vector2(0.86, 1.92)
	fdoor.mesh = fdq
	fdoor.material_override = door_surface()
	fdoor.position = Vector3(0, 1.01, fz - 0.002)
	fdoor.rotation_degrees.y = 180.0
	_cabin_root.add_child(fdoor)
	K.slab(_cabin_root, Vector3(0.05, 0.05, 0.06), Vector3(-0.32, 1.0, fz - 0.03), K.surface("galvanized", 0.4), "FrontDoorHandle")
	for x: float in [-0.92, 0.92]:
		_frame_window(Vector3(x, 1.55, fz - 0.002), Vector2(0.62, 0.56), 180.0, "Front")
	# The right wall: the basic cabin has a window there (as outside); the better ones
	# the door to the bathroom built on at that side.
	for piece in [[Vector3(0.1, 1.22, 1.2), Vector3(w * 0.5, 0.61, 0), "RightFillLow"],
			[Vector3(0.1, 0.5, 0.2), Vector3(w * 0.5, 1.47, -0.5), "RightFillL"],
			[Vector3(0.1, 0.5, 0.2), Vector3(w * 0.5, 1.47, 0.5), "RightFillR"],
			[Vector3(0.1, 0.1, 1.2), Vector3(w * 0.5, 1.77, 0), "RightFillHigh"]]:
		var fill := K.slab(_cabin_root, piece[0], piece[1], wall_mat, str(piece[2]))
		walls.append(fill)
		_level1_nodes.append(str(piece[2]))
	_frame_window(Vector3(w * 0.5 - 0.04, 1.47, 0), Vector2(0.8, 0.5), -90.0, "Side")
	_add_portal("SideView", Vector3(w * 0.5 - 0.02, 1.47, 0), Vector3(1, 0, 0), Vector2(0.8, 0.5), true)

	# The door on the right wall: a textured panel in a dark frame, closing the opening.
	K.slab(_cabin_root, Vector3(0.12, h * 0.7, d * 0.4 + 0.02), Vector3(w * 0.5 + 0.02, h * 0.35, 0), trim, "DoorFrame")
	var door := MeshInstance3D.new()
	door.name = "Door"
	var door_q := QuadMesh.new()
	door_q.size = Vector2(d * 0.4 - 0.12, h * 0.7 - 0.06)
	door.mesh = door_q
	var door_mat := StandardMaterial3D.new()
	door_mat.albedo_texture = load("res://assets/textury/camp/door_wood.png")
	door_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	door_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	door.material_override = door_mat
	door.position = Vector3(w * 0.5 - 0.045, h * 0.35, 0)
	door.rotation_degrees.y = -90
	_cabin_root.add_child(door)


	# The bed (left), a pillow that room prep moves, a table with the catalogue (back right).
	K.prop(_cabin_root, "bed_wood", BED_POS)
	var pillow := K.slab(_cabin_root, Vector3(0.6, 0.12, 0.32), Vector3(BED_POS.x, BED_TOP + 0.06, BED_POS.z - 0.68), K.surface("mattress", 0.5, Color(1.0, 0.98, 0.94)), "Pillow")
	pillow.rotation.x = -0.12
	K.prop(_cabin_root, "table_wood", Vector3(0.75, 0.05, -1.0))
	K.prop(_cabin_root, "chair_wood", Vector3(0.75, 0.05, -0.42), 180.0)
	var chair2 := K.prop(_cabin_root, "chair_wood", Vector3(0.18, 0.05, -1.05), 95.0)
	chair2.name = "Chair2"
	_catalog_mesh = _add_box(_cabin_root, "UpgradeCatalog", Vector3(0.82, 0.815, -1.02), Vector3(0.26, 0.02, 0.20), Color(0.84, 0.78, 0.68))
	_add_box(_cabin_root, "UpgradeCatalogInk1", Vector3(0.82, 0.827, -1.08), Vector3(0.18, 0.004, 0.02), Color(0.18, 0.16, 0.14))
	_add_box(_cabin_root, "UpgradeCatalogInk2", Vector3(0.82, 0.827, -1.02), Vector3(0.16, 0.004, 0.02), Color(0.18, 0.16, 0.14))
	_add_box(_cabin_root, "UpgradeCatalogInk3", Vector3(0.82, 0.827, -0.96), Vector3(0.14, 0.004, 0.02), Color(0.18, 0.16, 0.14))
	var up_lbl = Label3D.new()
	up_lbl.text = "CATALOGUE"
	up_lbl.position = Vector3(0.82, 0.845, -1.18)
	up_lbl.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	up_lbl.font_size = 12
	up_lbl.modulate = Color(0.34, 0.28, 0.20, 0.8)
	_cabin_root.add_child(up_lbl)

	# Level props: the slop bucket (1); wardrobe, wall lamp, a small fridge (2+); a rug,
	# a shelf, the TV and a second chair (3).
	var bucket := K.prop(_cabin_root, "slop_bucket", SLOP_BUCKET_POS)
	bucket.name = "SlopBucket"
	K.prop(_cabin_root, "wardrobe", Vector3(-1.2, 0.05, 1.0), 90.0)
	K.prop(_cabin_root, "wall_lamp", Vector3(-1.45, 1.5, -1.25), 90.0)
	K.prop(_cabin_root, "fridge_small", Vector3(1.2, 0.05, 1.18), -90.0)
	_flat_sprite(_cabin_root, "rug_rag", Vector2(1.25, 1.0), Vector3(0.05, 0.057, -0.15), false, "Rug")
	K.prop(_cabin_root, "wall_shelf", Vector3(1.05, 1.45, -1.4))
	K.prop(_cabin_root, "tv_old", Vector3(1.15, 0.05, 0.55), -90.0)
	K.picture(_cabin_root, "poster_lake", Vector2(0.48, 0.64), Vector3(-1.44, 1.55, -0.1), 90.0, "PosterLake")
	K.picture(_cabin_root, "picture_deer", Vector2(0.5, 0.66), Vector3(-1.44, 1.55, -0.1), 90.0, "PictureDeer")
	for n in ["WallLamp", "Wardrobe", "FridgeSmall", "Rug", "WallShelf", "TvOld", "Chair2", "PosterLake", "PictureDeer"]:
		_set_node_visible(n, false)

	# Lived in, at every level: the warden's jacket by the door you came in by, the
	# year's calendar by the window, floral curtains either side of it, the milk-glass
	# light on the ceiling (Grok art, assets/textury/camp).
	K.cutout(_cabin_root, "coat_hook", Vector2(0.4, 0.6), Vector3(-0.75, 1.0, 1.44), 180.0, false, "Jacket")
	K.picture(_cabin_root, "calendar", Vector2(0.32, 0.43), Vector3(-0.95, 1.72, -1.445), 0.0, "Calendar")
	for cx in [-0.7, 0.7]:
		K.picture(_cabin_root, "curtain_floral", Vector2(0.26, 0.8), Vector3(cx, 1.58, -1.435), 0.0, "WindowCurtain")
	_flat_sprite(_cabin_root, "ceiling_lamp", Vector2(0.34, 0.34), Vector3(0.0, h - 0.055, 0.0), true, "CeilingLamp")

	# The window in the back wall: a pine frame with a cross bar.
	var frame := K.surface("knotty_pine", 0.6)
	var wz: float = -d * 0.5 + 0.03
	K.slab(_cabin_root, Vector3(1.1, 0.07, 0.1), Vector3(0, 1.255, wz), frame, "WindowSill")
	K.slab(_cabin_root, Vector3(1.1, 0.06, 0.08), Vector3(0, 1.94, wz), frame, "WindowTop")
	K.slab(_cabin_root, Vector3(0.06, 0.72, 0.08), Vector3(-0.53, 1.6, wz), frame, "WindowFrameL")
	K.slab(_cabin_root, Vector3(0.06, 0.72, 0.08), Vector3(0.53, 1.6, wz), frame, "WindowFrameR")
	K.slab(_cabin_root, Vector3(0.04, 0.62, 0.05), Vector3(0, 1.6, wz - 0.01), frame, "WindowMullion")
	K.slab(_cabin_root, Vector3(1.0, 0.04, 0.05), Vector3(0, 1.62, wz - 0.01), frame, "WindowTransom")

	_add_portal("BackView", Vector3(0, 1.6, -d * 0.5 - 0.02), Vector3(0, 0, -1), Vector2(1.0, 0.62), false)

	# Placeholder view outside the window (no cabin outside to look out of: tools).
	_window_view_sky = MeshInstance3D.new()
	var sky_box = QuadMesh.new()
	sky_box.size = Vector2(1.7, 1.06)
	_window_view_sky.mesh = sky_box
	_window_view_sky.position = Vector3(0.0, 1.6, -d * 0.58)
	var sky_mat = StandardMaterial3D.new()
	sky_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sky_mat.albedo_color = Color(0.56, 0.74, 0.90)
	if _texture_style != null:
		var sky_tex = _texture_style.pick_texture("sky", sky_mat.albedo_color)
		if sky_tex != null:
			sky_mat.albedo_texture = sky_tex
			sky_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# The camp seen through the glass (assets/textury/camp/window_view.png), tinted by the hour.
	sky_mat.albedo_texture = load("res://assets/textury/camp/window_view.png")
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
	_window_view_ground.visible = false

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
	_window_view_trees.visible = false

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
	_build_prep_props()
	_apply_level_variant()
	_apply_time_profile()


## The cabin as the last guests left it: the blanket kicked into a heap with the pillow
## on the floor, empty bottles by the bed, and a toilet (or the bucket) nobody cleaned.
func _build_prep_props() -> void:
	var P := INTERIOR_PREP
	var blanket := P.camp_material("blanket_check.png", Color(0.9, 0.86, 0.8))
	var b := BED_POS
	var top := BED_TOP
	var heap_a := P.box(_cabin_root, Vector3(b.x + 0.02, top + 0.09, b.z + 0.35), Vector3(0.72, 0.2, 0.6), blanket, Vector3(0.1, 0.4, -0.12))
	var heap_b := P.box(_cabin_root, Vector3(b.x - 0.05, top + 0.04, b.z - 0.35), Vector3(0.6, 0.1, 0.5), blanket, Vector3(0.0, -0.3, 0.08))
	var pillow_floor := P.box(_cabin_root, Vector3(-0.3, 0.11, -0.15), Vector3(0.6, 0.1, 0.3), P.flat(Color(0.7, 0.7, 0.7)), Vector3(0.0, 0.7, 0.25))
	var made := P.box(_cabin_root, Vector3(b.x, top + 0.025, b.z + 0.18), Vector3(0.84, 0.05, 1.3), blanket)
	var made_fold := P.box(_cabin_root, Vector3(b.x, top + 0.04, b.z - 0.42), Vector3(0.84, 0.07, 0.14), P.flat(Color(0.88, 0.86, 0.8)))
	var pillow_bed := _cabin_root.get_node_or_null("Pillow")
	var bed_body := P.body(_cabin_root, Vector3(b.x, 0.4, b.z), Vector3(1.0, 0.7, 1.9))
	_prep.register("bed", bed_body, [heap_a, heap_b, pillow_floor], [made, made_fold, pillow_bed])

	# Where the mess can be this time (core/systems/mess_rules.gd ROOM_SPOTS, BATH_SPOTS).
	for spot in [["f1", Vector3(-0.35, 0.04, -1.15)], ["f2", Vector3(0.05, 0.04, -0.5)], ["f3", Vector3(0.4, 0.04, 0.0)],
			["f4", Vector3(-0.42, 0.04, 0.05)], ["f5", Vector3(0.75, 0.04, -0.3)], ["f6", Vector3(0.9, 0.04, 0.12)]]:
		_prep.add_spot(spot[0], _cabin_root, spot[1])
	# The toilet seat top, the basin, the floor in front of them.
	_prep.add_spot("wc", _bathroom_root, Vector3(0.6, 0.5, -0.88))
	_prep.add_spot("sink", _bathroom_root, Vector3(-0.6, 0.97, -1.0))
	_prep.add_spot("bfloor", _bathroom_root, Vector3(0.05, 0.04, -0.7))
	_prep.add_spot("pail", _cabin_root, SLOP_BUCKET_POS + Vector3(0, 0.31, 0))
	# The back-left corner over the bed, across it at 45 degrees (the old cabin's cobwebs).
	_prep.add_spot("w1", _cabin_root, Vector3(-1.45 + 0.354, 2.07, -1.45 + 0.354), deg_to_rad(45.0), true)
	_prep.setup_tasks(self, _interior_camera, _viewport, "cabin")
	_prep.task_completed.connect(func(id: String): room_task_completed.emit(id))


# ── room preparation (see scripts/interior_prep.gd) ──────────────────────────

func set_room(room: Dictionary) -> void:
	_set_derelict(_is_derelict(str(room.get("key", ""))))
	_prep.set_room(room)


## The old cabin at the start (main._place_ruined_cabin) until it is patched up outside:
## the window boarded up from inside as well, and the bulb dead (the torch comes on).
var _derelict := false


func _is_derelict(key: String) -> bool:
	var state = CoreRoot.get_state() if CoreRoot != null else null
	if state == null or key.is_empty():
		return false
	return bool((state.failures.get(key, {}) as Dictionary).get("derelict", false))


func _set_derelict(on: bool) -> void:
	if _cabin_root == null:
		return
	var boards := _cabin_root.get_node_or_null("RuinBoards")
	if on and boards == null:
		boards = Node3D.new()
		boards.name = "RuinBoards"
		_cabin_root.add_child(boards)
		var plank := INTERIOR_KIT.surface("planks_grey", 0.5, Color(0.9, 0.8, 0.66))
		for b in [[Vector3(1.24, 0.13, 0.03), Vector3(0.0, 1.8, -1.39), 0.2],
				[Vector3(1.2, 0.12, 0.03), Vector3(0.03, 1.44, -1.38), -0.16],
				[Vector3(1.16, 0.12, 0.03), Vector3(-0.02, 1.62, -1.37), 0.05]]:
			var s := INTERIOR_KIT.slab(boards, b[0], b[1], plank, "Board")
			s.rotation.z = float(b[2])
	elif not on and boards != null:
		boards.queue_free()
	if on != _derelict:
		_derelict = on
		# The whole profile again: the bulb's energy is built up from the time of day.
		_apply_time_profile(false)


func play_room_ready() -> void:
	_prep.play_room_ready()


func _build_bathroom_room() -> void:
	if _bathroom_root == null:
		return
	var K := INTERIOR_KIT
	var w = 2.4
	var d = 2.4
	var h = 2.6
	var shell := K.room(_bathroom_root, Vector3(w, h, d), "tiles_green", "oil_wall", "ceiling_board", h, 0.8)
	for key in shell.keys():
		(shell[key] as Node3D).position.y += 0.05
	_bath_shell = shell


	# Level 2+: the toilet, the basin and its mirror; level 3: a shower corner.
	var wc := K.prop(_bathroom_root, "toilet", Vector3(0.6, 0.05, -0.95))
	wc.name = "ToiletLv2"
	var sink := K.prop(_bathroom_root, "sink_pedestal", Vector3(-0.6, 0.05, -1.03))
	sink.name = "SinkLv2"
	var mirror := K.prop(_bathroom_root, "mirror_frame", Vector3(-0.6, 1.3, -1.12))
	mirror.name = "SinkMirror"
	var shower := K.prop(_bathroom_root, "shower_corner", Vector3(-0.78, 0.05, -0.2), 90.0)
	shower.name = "ShowerCorner"
	# Newspaper squares on a nail by the toilet.
	K.slab(_bathroom_root, Vector3(0.14, 0.18, 0.015), Vector3(0.18, 0.85, -1.18), INTERIOR_PREP.flat(Color(0.82, 0.8, 0.72)), "Newspaper")


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

	var K := INTERIOR_KIT
	var surf: Array = LEVEL_SURFACES.get(_cabin_level, LEVEL_SURFACES[1])
	for wall in _shell.get("walls", []):
		(wall as MeshInstance3D).material_override = K.surface(str(surf[0]), 1.2)
	if _shell.has("floor"):
		(_shell["floor"] as MeshInstance3D).material_override = K.surface(str(surf[1]), 1.0)
	if _shell.has("ceiling"):
		(_shell["ceiling"] as MeshInstance3D).material_override = K.surface(str(surf[2]), 1.0, Color(0.7, 0.66, 0.6) if _cabin_level == 1 else Color(1, 1, 1))
	if not _bath_shell.is_empty():
		var bath_wall := K.surface("tiles_bathroom", 0.9) if _cabin_level >= 3 else K.surface("oil_wall", 2.6)
		for key in ["back", "front", "left", "right"]:
			(_bath_shell[key] as MeshInstance3D).material_override = bath_wall

	_set_node_visible("SlopBucket", _cabin_level == 1)
	for node_name in _level1_nodes:
		_set_node_visible(node_name, _cabin_level == 1)
	_set_node_visible("Door", _cabin_level >= 2)
	_set_node_visible("DoorFrame", _cabin_level >= 2)
	for node_name in _level2_nodes:
		_set_node_visible(node_name, _cabin_level >= 2)
	for node_name in _level3_nodes:
		_set_node_visible(node_name, _cabin_level >= 3)
	for node_name in _level2_only:
		_set_node_visible(node_name, _cabin_level == 2)
	
	_set_bathroom_variant()


func _set_bathroom_variant() -> void:
	if _bathroom_root == null:
		return
	var lv = _cabin_level
	_set_node_visible_in(_bathroom_root, "ToiletLv2", lv >= 2)
	_set_node_visible_in(_bathroom_root, "SinkLv2", lv >= 2)
	_set_node_visible_in(_bathroom_root, "SinkMirror", lv >= 2)
	_set_node_visible_in(_bathroom_root, "ShowerCorner", lv == 3)


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
	# The room you leave slides away as the next slides in (scripts/ui/room_push.gd).
	_swipe_animating = true
	_swipe_overlay.visible = false
	if _swipe_tween != null and is_instance_valid(_swipe_tween):
		_swipe_tween.kill()
	_swipe_tween = ROOM_PUSH.play(self, _viewport_container, _viewport, direction,
		Callable(self, "_set_cabin_room").bind(target_room, true), Callable(self, "_finish_room_swipe"))


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
	if room != _active_room:
		_look.reset()
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
	_look.reset()


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
					sky_mat.albedo_color = Color(1.0, 1.0, 1.0)
				TIME_EVENING:
					sky_mat.albedo_color = Color(0.86, 0.6, 0.48)
				_:
					sky_mat.albedo_color = Color(0.1, 0.13, 0.22)

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
	# The old cabin while it is boarded up: only what gets in round the boards, grey-green.
	if _derelict and _room_env != null:
		_room_env.ambient_light_energy *= 0.36
		_room_env.ambient_light_color = _room_env.ambient_light_color.lerp(Color(0.5, 0.56, 0.46), 0.5)
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


func _apply_manual_light_profile(animated: bool) -> void:
	if _main_light == null:
		return
	var target_energy = _main_light.light_energy
	if not _manual_lights_on:
		target_energy *= 0.10
	elif _time_state != TIME_DAY and _grid_power_available:
		# After dusk the bulb lights the room, not the window (the night profile above
		# is the moon through it): warm, and enough to see the corners.
		target_energy = maxf(target_energy, 1.15)
		_main_light.light_color = Color(1.0, 0.88, 0.68)
		if _room_env != null:
			_room_env.ambient_light_energy = maxf(_room_env.ambient_light_energy, 0.3)
	if not _grid_power_available or _derelict:
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


## The torch comes on in here by itself when the room is dark (if it is on, F).
func _update_torch(delta: float) -> void:
	if _torch == null:
		_torch = INTERIOR_TORCH.new()
		_torch.name = "Torch"
		add_child(_torch)
		_torch.setup(_interior_camera, _viewport, _interior_camera.get_parent() as Node3D, layer)
	_torch.update(delta, room_is_dark())


## After dusk with the lights off (L) or the camp's power gone.
func room_is_dark() -> bool:
	return _derelict or (_time_state != TIME_DAY and (not _manual_lights_on or not _grid_power_available))
