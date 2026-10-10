extends CanvasLayer

const RETRO_RENDER = preload("res://scripts/retro_render.gd")
const INTERIOR_LOOK = preload("res://scripts/interior_look.gd")
const INTERIOR_PREP = preload("res://scripts/interior_prep.gd")
const MESS_RULES = preload("res://core/systems/mess_rules.gd")
const UPKEEP_RULES = preload("res://core/systems/maintenance_rules.gd")

signal request_close
signal request_repair

const INTERIOR_BARREL_SHADER = preload("res://materials/interior_barrel_post.gdshader")
const TEXTURE_STYLE_SCRIPT = preload("res://scripts/texture_style.gd")
const AUDIO_MANAGER_SCRIPT = preload("res://scripts/audio_manager.gd")
const USE_LEGACY_SEWER_AMBIENCE := false
const SFX_SEWER_AMBIENCE := "res://assets/sfx/rednecksfx/rrswerambience.wav"
const SEWER_AMBIENCE_VOLUME_DB := -3.5
const BASEMENT_MACHINE_ANIM_FRAME_TIME := 0.18

const TIME_DAY: int = 0
const TIME_EVENING: int = 1
const TIME_NIGHT: int = 2
const INTERIOR_RENDER_MIN_SIZE := Vector2i(960, 540)

var _is_open: bool = false
var _time_state: int = TIME_DAY
var _is_day_mode: bool = true
var _daylight_factor: float = 0.0
var _sunlight_color: Color = Color(1.0, 0.95, 0.84)
var _service_type: String = "restaurant"
var _current_profile: String = "rest"

var _viewport_container: SubViewportContainer
var _viewport: SubViewport
var _room_root: Node3D
var _interior_camera: Camera3D
var _room_env: Environment
var _main_light: OmniLight3D
var _light_switch_body: StaticBody3D
var _light_switch_mesh: MeshInstance3D
var _light_switch_tex_on: Texture2D
var _light_switch_tex_off: Texture2D
var _manual_lights_on: bool = true
var _grid_power_available: bool = true
var _manual_light_tween: Tween
var _barrel_overlay: ColorRect
var _cam_base_rot: Vector3 = Vector3.ZERO
## Standing in a service building: you look around the room you are in.
var _sewer_hint: Label3D
var _sewer_broken: bool = false
var _look = INTERIOR_LOOK.new(65.0, 20.0, 30.0)
var _exit_hint: Control
var _texture_style
var _restaurant_dining_root: Node3D
var _restaurant_kitchen_root: Node3D
var _restaurant_basement_root: Node3D
var _restaurant_room: String = "dining"
var _kitchen_texture_variant_alt: bool = false
var _pub_main_root: Node3D
var _vecerka_shop_root: Node3D
var _vecerka_storage_root: Node3D
var _active_subroom: String = "shop" # Generic subroom tracker
var _swipe_overlay: ColorRect
var _swipe_tween: Tween
var _swipe_animating: bool = false
var _sewer_ambience_player: AudioStreamPlayer
var _audio_loader: Node
var _basement_machine_anim_materials: Array[StandardMaterial3D] = []
var _basement_machine_anim_frames: Array[Texture2D] = []
var _basement_machine_anim_timer: float = 0.0
var _basement_machine_anim_frame: int = 0
## Cleaning a toilet / shower block from the inside (core/systems/mess_rules.gd
## block_tasks): the list is fixed when you first walk in and remembered per block
## until it is serviced, so leaving halfway keeps what you did.
var _upkeep_prep = null
var _upkeep_key := ""
var _upkeep_coord := Vector2i(-999, -999)
var _upkeep_type := ""
static var _upkeep_cache: Dictionary = {}   # key -> {tasks, done, broken}


func _ready() -> void:
	_texture_style = TEXTURE_STYLE_SCRIPT.new()
	_audio_loader = AUDIO_MANAGER_SCRIPT.new()
	layer = 82
	visible = false
	_build_viewport()
	_sync_viewport_to_window()
	_setup_sewer_ambience_player()
	_build_service_room("rest")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_sync_viewport_to_window()
		_update_swipe_overlay_size()


func is_open() -> bool:
	return _is_open


func is_sewer_profile_active() -> bool:
	return _is_open and _current_profile == "sewer"


func is_restaurant_basement_active() -> bool:
	return _is_open and _current_profile == "rest" and _restaurant_room == "basement"


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
	_apply_time_profile(true)


func open_service(service_type: String) -> void:
	_service_type = service_type
	var wanted_profile = _profile_for_service(service_type)
	if wanted_profile == "rest":
		_restaurant_room = "dining"
	if wanted_profile != _current_profile:
		_current_profile = wanted_profile
		_build_service_room(_current_profile)
	else:
		if _current_profile == "rest":
			_set_restaurant_room("dining", true)
		_apply_time_profile()
	if _interior_camera == null:
		return
	if _is_open:
		_update_sewer_ambience_state()
		return
	_is_open = true
	visible = true
	_sync_viewport_to_window()
	_cam_base_rot = _interior_camera.rotation
	_look.reset()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_update_sewer_ambience_state()


func close_service() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	_update_sewer_ambience_state()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	request_close.emit()


func _process(delta: float) -> void:
	if not _is_open or _interior_camera == null:
		return
	_update_basement_machine_animation(delta)
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
		close_service()
		get_viewport().set_input_as_handled()
		return
	if INTERIOR_LOOK.is_exit_event(event, get_viewport()):
		close_service()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_event = event as InputEventMouseButton
		if _try_click_world(mouse_event):
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("service_repair"):
		_try_request_service_repair()
		get_viewport().set_input_as_handled()
		return
	if _current_profile == "sewer" and event.is_action_pressed("interact"):
		_try_request_service_repair()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("service_room_next"):
		_switch_service_room(1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("service_room_prev"):
		_switch_service_room(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("service_secret_room"):
		_toggle_secret_room()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("service_kitchen_variant"):
		_toggle_kitchen_texture_variant()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event = event as InputEventKey
		if key_event.physical_keycode == KEY_D:
			_switch_service_room(1)
			get_viewport().set_input_as_handled()
			return
		if key_event.physical_keycode == KEY_A:
			_switch_service_room(-1)
			get_viewport().set_input_as_handled()
			return
		if key_event.physical_keycode == KEY_L:
			_toggle_manual_service_lights()
			get_viewport().set_input_as_handled()
			return
		if key_event.physical_keycode == KEY_R or key_event.keycode == KEY_R:
			_try_request_service_repair()
			get_viewport().set_input_as_handled()
			return
		if key_event.physical_keycode == KEY_S:
			_toggle_secret_room()
			get_viewport().set_input_as_handled()
			return
		if key_event.physical_keycode == KEY_P:
			_toggle_kitchen_texture_variant()
			get_viewport().set_input_as_handled()
			return


func _try_click_world(event: InputEventMouseButton) -> bool:
	var hit = _raycast_world(event.position)
	if hit.is_empty():
		return false
	var collider = hit.get("collider", null) as Node
	if collider == null:
		return false
	if _node_has_click_type(collider, "service_light_switch"):
		_toggle_manual_service_lights()
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


func _build_service_light_switch(profile: String) -> void:
	if _room_root == null:
		return
	_light_switch_tex_on = _pick_service_texture("interior_switch_on", Color(0.82, 0.78, 0.66))
	_light_switch_tex_off = _pick_service_texture("interior_switch_off", Color(0.66, 0.64, 0.58))
	var switch_pos = Vector3(2.74, 1.22, 1.78)
	if profile == "pub" or profile == "rest":
		switch_pos = Vector3(2.70, 1.26, 2.04)
	elif profile == "wash":
		switch_pos = Vector3(1.92, 1.24, 1.32)
	elif profile == "toilet":
		switch_pos = Vector3(2.00, 1.24, 1.20)
	var switch_body = StaticBody3D.new()
	switch_body.name = "ServiceLightSwitch"
	switch_body.position = switch_pos
	switch_body.rotation = Vector3(0.0, -PI * 0.5, 0.0)
	switch_body.set_meta("interior_click_type", "service_light_switch")
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
	_room_root.add_child(switch_body)
	_light_switch_body = switch_body
	_light_switch_mesh = switch_mesh
	_apply_service_switch_visual()


func _pick_service_texture(category: String, color: Color) -> Texture2D:
	if _texture_style == null:
		return null
	return _texture_style.pick_texture(category, color)


func _apply_service_switch_visual() -> void:
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


func _toggle_manual_service_lights() -> void:
	_manual_lights_on = not _manual_lights_on
	_apply_service_switch_visual()
	_apply_time_profile(true)


func _build_viewport() -> void:
	_viewport_container = SubViewportContainer.new()
	_viewport_container.name = "ServiceViewportContainer"
	_viewport_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewport_container.stretch = true
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_viewport_container)
	RETRO_RENDER.register(_viewport_container)

	_viewport = SubViewport.new()
	_viewport.name = "ServiceViewport"
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
	env.ambient_light_energy = 0.94
	_room_env = env

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

	_swipe_overlay = ColorRect.new()
	_swipe_overlay.name = "ServiceRoomSwipe"
	_swipe_overlay.anchor_left = 0.0
	_swipe_overlay.anchor_top = 0.0
	_swipe_overlay.anchor_right = 0.0
	_swipe_overlay.anchor_bottom = 0.0
	_swipe_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_swipe_overlay.color = Color(0.04, 0.05, 0.06, 0.92)
	_swipe_overlay.visible = false
	add_child(_swipe_overlay)
	_update_swipe_overlay_size()


func _setup_sewer_ambience_player() -> void:
	if _sewer_ambience_player != null:
		return
	_sewer_ambience_player = AudioStreamPlayer.new()
	_sewer_ambience_player.name = "SewerAmbience"
	_sewer_ambience_player.volume_db = SEWER_AMBIENCE_VOLUME_DB
	_sewer_ambience_player.bus = "OutdoorAmbience"
	var stream = _load_service_stream(SFX_SEWER_AMBIENCE)
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_sewer_ambience_player.stream = stream
	add_child(_sewer_ambience_player)


func _load_service_stream(res_path: String) -> AudioStream:
	var stream = load(res_path) as AudioStream
	if stream != null:
		if stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		elif stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
		elif stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		return stream
	if _audio_loader != null and _audio_loader.has_method("_try_load_stream"):
		var fallback = _audio_loader.call("_try_load_stream", res_path) as AudioStream
		if fallback is AudioStreamWAV:
			(fallback as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		elif fallback is AudioStreamMP3:
			(fallback as AudioStreamMP3).loop = true
		elif fallback is AudioStreamOggVorbis:
			(fallback as AudioStreamOggVorbis).loop = true
		return fallback
	return null


func _update_sewer_ambience_state() -> void:
	if not USE_LEGACY_SEWER_AMBIENCE:
		if _sewer_ambience_player != null and _sewer_ambience_player.playing:
			_sewer_ambience_player.stop()
		return
	if _sewer_ambience_player == null:
		return
	if _sewer_ambience_player.stream == null:
		_sewer_ambience_player.stream = _load_service_stream(SFX_SEWER_AMBIENCE)
		if _sewer_ambience_player.stream == null:
			printerr("[ServiceInterior] FAILED to load sewer ambience stream: ", SFX_SEWER_AMBIENCE)
			return
	
	var should_play = _is_open and _current_profile == "sewer"
	if should_play:
		if not _sewer_ambience_player.playing:
			var s = _sewer_ambience_player.stream
			if s is AudioStreamWAV:
				(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
			elif s is AudioStreamMP3:
				(s as AudioStreamMP3).loop = true
			elif s is AudioStreamOggVorbis:
				(s as AudioStreamOggVorbis).loop = true
				
			print("[ServiceInterior] STARTING sewer ambience. Vol: ", _sewer_ambience_player.volume_db, " Bus: ", _sewer_ambience_player.bus)
			_sewer_ambience_player.play()
	elif _sewer_ambience_player.playing:
		print("[ServiceInterior] STOPPING sewer ambience")
		_sewer_ambience_player.stop()


func _build_service_room(profile: String) -> void:
	if _viewport == null:
		return
	_swipe_animating = false
	if _swipe_tween != null and is_instance_valid(_swipe_tween):
		_swipe_tween.kill()
	if _swipe_overlay != null:
		_swipe_overlay.visible = false
	if _room_root != null and is_instance_valid(_room_root):
		if _room_root.get_parent() != null:
			_room_root.get_parent().remove_child(_room_root)
		_room_root.free()

	_room_root = Node3D.new()
	_room_root.name = "ServiceRoom"
	_viewport.add_child(_room_root)

	_interior_camera = Camera3D.new()
	_interior_camera.name = "ServiceCamera"
	_interior_camera.position = Vector3(0.0, 1.46, 1.96)
	_interior_camera.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
	_interior_camera.fov = 60.0
	_interior_camera.near = 0.05
	_interior_camera.far = 18.0
	_interior_camera.current = true
	_room_root.add_child(_interior_camera)

	_main_light = OmniLight3D.new()
	_main_light.position = Vector3(0.0, 2.30, 0.0)
	_main_light.light_color = Color(0.96, 0.94, 0.88)
	_main_light.light_energy = 1.28
	_main_light.omni_range = 8.0
	_main_light.omni_attenuation = 1.2
	_main_light.shadow_enabled = true
	_room_root.add_child(_main_light)
	_restaurant_dining_root = null
	_restaurant_kitchen_root = null
	_restaurant_basement_root = null
	_pub_main_root = null
	_vecerka_shop_root = null
	_vecerka_storage_root = null
	_light_switch_body = null
	_light_switch_mesh = null
	_manual_lights_on = true
	_basement_machine_anim_materials.clear()
	_basement_machine_anim_frames.clear()
	_basement_machine_anim_timer = 0.0
	_basement_machine_anim_frame = 0
	_free_upkeep_prep()
	if profile == "toilet":
		_build_toilet_layout()
		# _interior_camera set by _set_hygiene_room
		_active_subroom = "center"
		_set_hygiene_room("center")
	elif profile == "wash":
		_build_wash_layout(true)
		# _interior_camera set by _set_hygiene_room
		_active_subroom = "center"
		_set_hygiene_room("center")
	elif profile == "sewer":
		_build_sewer_layout()
	elif profile == "pub":
		_pub_main_root = Node3D.new()
		_pub_main_root.name = "PubMainRoom"
		_room_root.add_child(_pub_main_root)
		_build_pub_main_layout(_pub_main_root)
	elif profile == "vecerka":
		_vecerka_shop_root = Node3D.new()
		_vecerka_shop_root.name = "VecerkaShop"
		_room_root.add_child(_vecerka_shop_root)
		_vecerka_storage_root = Node3D.new()
		_vecerka_storage_root.name = "VecerkaStorage"
		_room_root.add_child(_vecerka_storage_root)
		
		_build_vecerka_shop_layout(_vecerka_shop_root)
		_build_vecerka_storage_layout(_vecerka_storage_root)
		_set_vecerka_room("shop", true)
	elif profile == "generator":
		_build_generator_layout()
		if _interior_camera != null:
			_interior_camera.position = Vector3(0.0, 1.5, 1.8)
			_interior_camera.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
			_cam_base_rot = _interior_camera.rotation
	else:
		_restaurant_dining_root = Node3D.new()
		_restaurant_dining_root.name = "RestaurantDining"
		_room_root.add_child(_restaurant_dining_root)
		_restaurant_kitchen_root = Node3D.new()
		_restaurant_kitchen_root.name = "RestaurantKitchen"
		_room_root.add_child(_restaurant_kitchen_root)
		_restaurant_basement_root = Node3D.new()
		_restaurant_basement_root.name = "RestaurantBasement"
		_room_root.add_child(_restaurant_basement_root)
		# Restaurant dining now mirrors pub layout (pub is low-cost restaurant variant).
		_build_pub_main_layout(_restaurant_dining_root, "DINING ROOM", "D > KITCHEN", "service_rest_booth_restaurant")
		_build_restaurant_kitchen_layout(_restaurant_kitchen_root)
		_build_restaurant_basement_layout(_restaurant_basement_root)
		_set_restaurant_room(_restaurant_room, true)
	if profile != "sewer":
		_build_service_light_switch(profile)

	_cam_base_rot = _interior_camera.rotation
	_apply_time_profile()
	_update_sewer_ambience_state()


func _build_restaurant_dining_layout(parent: Node3D) -> void:
	var w = 6.2
	var d = 4.8
	var h = 2.9

	_add_box("DiningFloor", Vector3(0.0, 0.0, 0.0), Vector3(w, 0.1, d), Color(0.54, 0.42, 0.34), "service_rest_floor", parent)
	_add_box("DiningCeiling", Vector3(0.0, h, 0.0), Vector3(w, 0.1, d), Color(0.70, 0.66, 0.60), "service_rest_ceiling", parent)
	_add_box("DiningWallBack", Vector3(0.0, h * 0.5, -d * 0.5), Vector3(w, h, 0.1), Color(0.64, 0.48, 0.36), "service_rest_wall", parent)
	_add_box("DiningWallFront", Vector3(0.0, h * 0.5, d * 0.5), Vector3(w, h, 0.1), Color(0.64, 0.48, 0.36), "service_rest_wall", parent)
	_add_box("DiningWallLeft", Vector3(-w * 0.5, h * 0.5, 0.0), Vector3(0.1, h, d), Color(0.62, 0.46, 0.34), "service_rest_wall", parent)
	_add_box("DiningWallRight", Vector3(w * 0.5, h * 0.5, 0.0), Vector3(0.1, h, d), Color(0.62, 0.46, 0.34), "service_rest_wall", parent)
	_add_box("DiningWallBandBack", Vector3(0.0, 1.18, -2.41), Vector3(w * 0.96, 0.20, 0.04), Color(0.74, 0.64, 0.52), "service_rest_decor", parent)
	_add_box("DiningWallBandFront", Vector3(0.0, 1.18, 2.41), Vector3(w * 0.96, 0.20, 0.04), Color(0.74, 0.64, 0.52), "service_rest_decor", parent)

	_add_box("DiningCounterBase", Vector3(2.08, 0.52, -1.10), Vector3(1.80, 1.04, 0.88), Color(0.42, 0.30, 0.20), "service_rest_counter", parent)
	_add_box("DiningCounterTop", Vector3(2.08, 1.08, -1.10), Vector3(1.92, 0.08, 0.98), Color(0.54, 0.42, 0.30), "service_rest_tabletop", parent)
	_add_box("DiningCounterBack", Vector3(2.38, 1.54, -2.12), Vector3(1.28, 1.22, 0.30), Color(0.42, 0.30, 0.22), "service_rest_wall", parent)

	_add_box("DiningBoothBackL", Vector3(-1.58, 0.66, -1.28), Vector3(1.52, 0.86, 0.28), Color(0.48, 0.28, 0.24), "service_rest_booth", parent)
	_add_box("DiningBoothSeatL", Vector3(-1.58, 0.34, -0.82), Vector3(1.52, 0.16, 0.72), Color(0.52, 0.30, 0.26), "service_rest_booth", parent)
	_add_box("DiningBoothBackR", Vector3(-1.58, 0.66, 1.28), Vector3(1.52, 0.86, 0.28), Color(0.48, 0.28, 0.24), "service_rest_booth", parent)
	_add_box("DiningBoothSeatR", Vector3(-1.58, 0.34, 0.82), Vector3(1.52, 0.16, 0.72), Color(0.52, 0.30, 0.26), "service_rest_booth", parent)

	_add_box("DiningTableBaseL", Vector3(-1.58, 0.42, -0.10), Vector3(0.12, 0.72, 0.12), Color(0.38, 0.28, 0.20), "service_rest_counter", parent)
	_add_box("DiningTableTopL", Vector3(-1.58, 0.82, -0.10), Vector3(1.12, 0.08, 0.72), Color(0.52, 0.40, 0.28), "service_rest_tabletop", parent)
	_add_box("DiningTableBaseR", Vector3(-1.58, 0.42, 0.10), Vector3(0.12, 0.72, 0.12), Color(0.38, 0.28, 0.20), "service_rest_counter", parent)
	_add_box("DiningTableTopR", Vector3(-1.58, 0.82, 0.10), Vector3(1.12, 0.08, 0.72), Color(0.52, 0.40, 0.28), "service_rest_tabletop", parent)

	_add_box("DiningCenterTableLeg", Vector3(0.32, 0.42, 0.88), Vector3(0.14, 0.72, 0.14), Color(0.36, 0.26, 0.18), "service_rest_counter", parent)
	_add_box("DiningCenterTableTop", Vector3(0.32, 0.82, 0.88), Vector3(1.04, 0.08, 0.78), Color(0.52, 0.40, 0.28), "service_rest_tabletop", parent)
	_add_box("DiningFloorInlay", Vector3(0.30, 0.06, 0.88), Vector3(1.40, 0.01, 1.02), Color(0.48, 0.30, 0.26), "service_rest_booth", parent)

	_add_box("DiningMenuBoard", Vector3(0.0, 1.98, -2.44), Vector3(1.90, 0.78, 0.04), Color(0.74, 0.66, 0.52), "service_rest_decor", parent)
	_add_box("DiningNeonStrip", Vector3(0.0, 2.52, -2.38), Vector3(1.40, 0.06, 0.06), Color(0.80, 0.72, 0.42), "service_rest_decor", parent)
	_add_box("DiningPosterA", Vector3(-2.60, 1.56, -0.62), Vector3(0.04, 0.72, 0.96), Color(0.76, 0.68, 0.56), "service_rest_decor", parent)
	_add_box("DiningPosterB", Vector3(2.60, 1.54, 0.76), Vector3(0.04, 0.82, 0.82), Color(0.76, 0.68, 0.56), "service_rest_decor", parent)

	var title = Label3D.new()
	title.text = "DINER"
	title.position = Vector3(0.0, 2.16, -2.34)
	title.font_size = 42
	title.modulate = Color(0.88, 0.80, 0.62, 0.92)
	parent.add_child(title)
	var nav_label = Label3D.new()
	nav_label.text = "D > KITCHEN"
	nav_label.position = Vector3(2.10, 1.72, 2.12)
	nav_label.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	nav_label.font_size = 20
	nav_label.modulate = Color(0.92, 0.86, 0.74, 0.86)
	parent.add_child(nav_label)


func _build_restaurant_kitchen_layout(parent: Node3D) -> void:
	var w = 6.2
	var d = 4.8
	var h = 2.9
	var kitchen_wall_category := "service_kitchen_wall_alt" if _kitchen_texture_variant_alt else "service_kitchen_wall"
	var kitchen_floor_category := "service_kitchen_floor_alt" if _kitchen_texture_variant_alt else "service_kitchen_floor"

	_add_box("KitchenFloor", Vector3(0.0, 0.0, 0.0), Vector3(w, 0.1, d), Color(0.48, 0.50, 0.54), kitchen_floor_category, parent)
	_add_box("KitchenCeiling", Vector3(0.0, h, 0.0), Vector3(w, 0.1, d), Color(0.60, 0.62, 0.66), "service_kitchen_ceiling", parent)
	_add_box("KitchenWallBack", Vector3(0.0, h * 0.5, -d * 0.5), Vector3(w, h, 0.1), Color(0.56, 0.58, 0.62), kitchen_wall_category, parent)
	_add_box("KitchenWallFront", Vector3(0.0, h * 0.5, d * 0.5), Vector3(w, h, 0.1), Color(0.56, 0.58, 0.62), kitchen_wall_category, parent)
	_add_box("KitchenWallLeft", Vector3(-w * 0.5, h * 0.5, 0.0), Vector3(0.1, h, d), Color(0.54, 0.56, 0.60), kitchen_wall_category, parent)
	_add_box("KitchenWallRight", Vector3(w * 0.5, h * 0.5, 0.0), Vector3(0.1, h, d), Color(0.54, 0.56, 0.60), kitchen_wall_category, parent)
	_add_box("KitchenWallSquareA", Vector3(-0.98, 1.86, -d * 0.5 + 0.056), Vector3(0.62, 0.62, 0.02), Color(0.90, 0.90, 0.88), "service_kitchen_wall_square_499", parent)
	_add_box("KitchenWallSquareB", Vector3(0.98, 1.86, -d * 0.5 + 0.056), Vector3(0.62, 0.62, 0.02), Color(0.90, 0.90, 0.88), "service_kitchen_wall_square_500", parent)

	_add_box("KitchenCounterA", Vector3(-1.70, 0.56, -1.48), Vector3(1.82, 1.12, 0.82), Color(0.44, 0.46, 0.50), "service_kitchen_cabinet", parent)
	_add_box("KitchenCounterATop", Vector3(-1.70, 1.14, -1.48), Vector3(1.96, 0.08, 0.94), Color(0.64, 0.66, 0.70), "service_kitchen_tabletop", parent)
	_add_box("KitchenCounterB", Vector3(1.76, 0.56, -1.48), Vector3(1.74, 1.12, 0.82), Color(0.44, 0.46, 0.50), "service_kitchen_cabinet", parent)
	_add_box("KitchenCounterBTop", Vector3(1.76, 1.14, -1.48), Vector3(1.88, 0.08, 0.94), Color(0.64, 0.66, 0.70), "service_kitchen_tabletop", parent)

	_add_box("KitchenPrepTableBase", Vector3(0.0, 0.46, 0.42), Vector3(1.86, 0.84, 0.96), Color(0.44, 0.46, 0.50), "service_kitchen_cabinet", parent)
	_add_box("KitchenPrepTableTop", Vector3(0.0, 0.92, 0.42), Vector3(2.02, 0.08, 1.08), Color(0.64, 0.66, 0.70), "service_kitchen_island_top", parent)
	_add_box("KitchenPrepTableFront", Vector3(0.0, 0.46, 0.92), Vector3(1.86, 0.84, 0.04), Color(0.42, 0.44, 0.48), "service_kitchen_island_front", parent)
	_add_box("KitchenStoveBlock", Vector3(0.0, 0.58, -1.54), Vector3(1.46, 1.16, 0.66), Color(0.38, 0.40, 0.44), "service_kitchen_counter", parent)
	_add_box("KitchenStoveTop", Vector3(0.0, 1.16, -1.54), Vector3(1.52, 0.08, 0.74), Color(0.62, 0.64, 0.68), "service_kitchen_stove_top", parent)

	_add_box("KitchenShelfA", Vector3(-2.54, 1.58, 1.84), Vector3(1.12, 1.44, 0.26), Color(0.42, 0.44, 0.48), "service_kitchen_shelf", parent)
	_add_box("KitchenShelfB", Vector3(2.54, 1.58, 1.84), Vector3(1.12, 1.44, 0.26), Color(0.42, 0.44, 0.48), "service_kitchen_shelf", parent)
	_add_box("KitchenShelfItemA", Vector3(-2.54, 1.94, 1.86), Vector3(0.44, 0.24, 0.10), Color(0.74, 0.76, 0.80), "service_kitchen_decor", parent)
	_add_box("KitchenShelfItemB", Vector3(2.54, 1.94, 1.86), Vector3(0.44, 0.24, 0.10), Color(0.74, 0.76, 0.80), "service_kitchen_decor", parent)
	_add_box("KitchenPassDoor", Vector3(0.0, 1.66, 2.42), Vector3(1.70, 1.06, 0.04), Color(0.70, 0.72, 0.76), "service_kitchen_sign", parent)
	_add_box("KitchenFreezerDoor", Vector3(-2.12, 1.02, -2.34), Vector3(0.82, 1.86, 0.06), Color(0.74, 0.78, 0.82), "service_kitchen_freezer_door", parent)
	_add_box("KitchenFridgeDoor", Vector3(2.08, 1.02, -2.34), Vector3(0.82, 1.86, 0.06), Color(0.76, 0.80, 0.84), "service_kitchen_fridge_door", parent)
	_add_box("KitchenDrainA", Vector3(-0.70, 0.06, 1.60), Vector3(0.78, 0.02, 0.32), Color(0.30, 0.32, 0.34), "service_kitchen_drain", parent)
	_add_box("KitchenDrainB", Vector3(0.84, 0.06, 1.60), Vector3(0.78, 0.02, 0.32), Color(0.30, 0.32, 0.34), "service_kitchen_drain", parent)
	_add_box("KitchenEmployeesSign", Vector3(0.0, 2.28, 2.36), Vector3(1.26, 0.34, 0.03), Color(0.86, 0.84, 0.70), "service_kitchen_sign", parent)

	var title = Label3D.new()
	title.text = "KITCHEN"
	title.position = Vector3(0.0, 2.16, -2.34)
	title.font_size = 40
	title.modulate = Color(0.88, 0.80, 0.62, 0.92)
	parent.add_child(title)
	var nav_label = Label3D.new()
	nav_label.text = "< A DINING ROOM | S CELLAR"
	nav_label.position = Vector3(-2.14, 1.72, 2.12)
	nav_label.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	nav_label.font_size = 20
	nav_label.modulate = Color(0.92, 0.86, 0.74, 0.86)
	parent.add_child(nav_label)


func _build_restaurant_basement_layout(parent: Node3D) -> void:
	var w = 6.2
	var d = 4.8
	var h = 2.7

	_add_box("BasementFloor", Vector3(0.0, 0.0, 0.0), Vector3(w, 0.1, d), Color(0.28, 0.30, 0.32), "service_basement_floor", parent)
	_add_box("BasementCeiling", Vector3(0.0, h, 0.0), Vector3(w, 0.1, d), Color(0.36, 0.38, 0.40), "service_basement_wall", parent)
	_add_box("BasementWallBack", Vector3(0.0, h * 0.5, -d * 0.5), Vector3(w, h, 0.1), Color(0.34, 0.36, 0.38), "service_basement_wall", parent)
	_add_box("BasementWallFront", Vector3(0.0, h * 0.5, d * 0.5), Vector3(w, h, 0.1), Color(0.34, 0.36, 0.38), "service_basement_wall", parent)
	_add_box("BasementWallLeft", Vector3(-w * 0.5, h * 0.5, 0.0), Vector3(0.1, h, d), Color(0.32, 0.34, 0.36), "service_basement_wall", parent)
	_add_box("BasementWallRight", Vector3(w * 0.5, h * 0.5, 0.0), Vector3(0.1, h, d), Color(0.32, 0.34, 0.36), "service_basement_wall", parent)

	_add_box("MachineBase", Vector3(0.0, 0.72, -0.20), Vector3(2.16, 1.44, 1.18), Color(0.24, 0.26, 0.28), "service_basement_machine", parent)
	_add_box("MachineTop", Vector3(0.0, 1.48, -0.20), Vector3(2.28, 0.10, 1.30), Color(0.36, 0.40, 0.44), "service_basement_machine", parent)
	var machine_core = _add_box("MachineCore", Vector3(0.0, 1.14, 0.42), Vector3(1.12, 0.66, 0.36), Color(0.70, 0.24, 0.18), "service_basement_machine_anim_539", parent)
	_add_box("MachinePipeL", Vector3(-1.28, 1.64, -0.70), Vector3(0.20, 0.84, 0.20), Color(0.34, 0.36, 0.38), "service_basement_machine", parent)
	_add_box("MachinePipeR", Vector3(1.28, 1.64, -0.70), Vector3(0.20, 0.84, 0.20), Color(0.34, 0.36, 0.38), "service_basement_machine", parent)
	_add_box("BasementWallPoster523", Vector3(0.0, 1.72, -2.34), Vector3(2.26, 0.92, 0.05), Color(0.86, 0.80, 0.68), "service_basement_rect_523", parent)
	_setup_basement_machine_animation([machine_core])

	var title = Label3D.new()
	title.text = "CELLAR"
	title.position = Vector3(0.0, 2.10, -2.22)
	title.font_size = 36
	title.modulate = Color(0.82, 0.84, 0.88, 0.92)
	parent.add_child(title)

	var machine_title = Label3D.new()
	machine_title.text = "PROTOTYPE 540"
	machine_title.position = Vector3(0.0, 1.80, 0.52)
	machine_title.font_size = 22
	machine_title.modulate = Color(0.88, 0.30, 0.24, 0.92)
	parent.add_child(machine_title)

	var nav_label = Label3D.new()
	nav_label.text = "A > KITCHEN"
	nav_label.position = Vector3(-2.20, 1.70, 2.06)
	nav_label.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	nav_label.font_size = 20
	nav_label.modulate = Color(0.86, 0.88, 0.92, 0.86)
	parent.add_child(nav_label)


func _setup_basement_machine_animation(meshes: Array) -> void:
	_basement_machine_anim_materials.clear()
	_basement_machine_anim_frames.clear()
	_basement_machine_anim_timer = 0.0
	_basement_machine_anim_frame = 0
	if _texture_style == null:
		return
	var frame_categories = [
		"service_basement_machine_anim_539",
		"service_basement_machine_anim_540",
		"service_basement_machine_anim_541",
		"service_basement_machine_anim_542"
	]
	for category in frame_categories:
		var tex = _texture_style.pick_texture(category, Color(0.70, 0.24, 0.18))
		if tex != null:
			_basement_machine_anim_frames.append(tex)
	if _basement_machine_anim_frames.is_empty():
		return
	for mesh_any in meshes:
		var mesh = mesh_any as MeshInstance3D
		if mesh == null:
			continue
		var mat = mesh.material_override as StandardMaterial3D
		if mat == null:
			continue
		_basement_machine_anim_materials.append(mat)
	_apply_basement_machine_frame(0)


func _update_basement_machine_animation(delta: float) -> void:
	if _basement_machine_anim_frames.size() < 2:
		return
	if _basement_machine_anim_materials.is_empty():
		return
	_basement_machine_anim_timer += max(delta, 0.0)
	while _basement_machine_anim_timer >= BASEMENT_MACHINE_ANIM_FRAME_TIME:
		_basement_machine_anim_timer -= BASEMENT_MACHINE_ANIM_FRAME_TIME
		_apply_basement_machine_frame(_basement_machine_anim_frame + 1)


func _apply_basement_machine_frame(frame_index: int) -> void:
	var frame_count = _basement_machine_anim_frames.size()
	if frame_count == 0:
		return
	_basement_machine_anim_frame = wrapi(frame_index, 0, frame_count)
	var tex = _basement_machine_anim_frames[_basement_machine_anim_frame]
	for mat in _basement_machine_anim_materials:
		if mat == null:
			continue
		mat.albedo_texture = tex
		mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)


func _set_restaurant_room(room: String, update_camera: bool = true) -> void:
	if _restaurant_dining_root == null or _restaurant_kitchen_root == null or _restaurant_basement_root == null:
		return
	var wanted_room = "dining"
	if room == "kitchen":
		wanted_room = "kitchen"
	elif room == "basement":
		wanted_room = "basement"
	_restaurant_room = wanted_room
	_restaurant_dining_root.visible = (_restaurant_room == "dining")
	_restaurant_kitchen_root.visible = (_restaurant_room == "kitchen")
	_restaurant_basement_root.visible = (_restaurant_room == "basement")
	if update_camera and _interior_camera != null:
		if _restaurant_room == "kitchen":
			_interior_camera.position = Vector3(0.12, 1.50, 1.92)
			_interior_camera.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
		elif _restaurant_room == "basement":
			_interior_camera.position = Vector3(0.0, 1.44, 1.86)
			_interior_camera.rotation_degrees = Vector3(-6.0, 0.0, 0.0)
		else:
			_interior_camera.position = Vector3(0.0, 1.46, 1.96)
			_interior_camera.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
	_cam_base_rot = _interior_camera.rotation


func _build_pub_main_layout(
	parent: Node3D,
	title_text: String = "HOSPODA",
	nav_text: String = "",
	seat_category: String = "service_rest_booth"
) -> void:
	var w = 5.8
	var d = 4.6
	var h = 2.8
	_add_box("PubFloor", Vector3(0.0, 0.0, 0.0), Vector3(w, 0.1, d), Color(0.34, 0.28, 0.22), "service_rest_floor", parent)
	_add_box("PubCeiling", Vector3(0.0, h, 0.0), Vector3(w, 0.1, d), Color(0.44, 0.36, 0.30), "service_rest_ceiling", parent)
	_add_box("PubWallBack", Vector3(0.0, h * 0.5, -d * 0.5), Vector3(w, h, 0.1), Color(0.36, 0.30, 0.24), "service_rest_wall", parent)
	_add_box("PubWallFront", Vector3(0.0, h * 0.5, d * 0.5), Vector3(w, h, 0.1), Color(0.36, 0.30, 0.24), "service_rest_wall", parent)
	_add_box("PubWallLeft", Vector3(-w * 0.5, h * 0.5, 0.0), Vector3(0.1, h, d), Color(0.34, 0.28, 0.22), "service_rest_wall", parent)
	_add_box("PubWallRight", Vector3(w * 0.5, h * 0.5, 0.0), Vector3(0.1, h, d), Color(0.34, 0.28, 0.22), "service_rest_wall", parent)
	_add_box("PubBarBase", Vector3(1.56, 0.60, -1.34), Vector3(2.20, 1.20, 0.80), Color(0.26, 0.20, 0.16), "service_rest_counter", parent)
	_add_box("PubBarTop", Vector3(1.56, 1.22, -1.34), Vector3(2.34, 0.09, 0.94), Color(0.46, 0.36, 0.28), "service_rest_tabletop", parent)
	_add_box("PubBackShelf", Vector3(1.58, 1.66, -2.18), Vector3(2.00, 1.10, 0.20), Color(0.30, 0.24, 0.18), "service_pub_shelf", parent)
	_add_box("PubBottleRowA", Vector3(1.58, 1.88, -2.10), Vector3(1.70, 0.16, 0.08), Color(0.70, 0.56, 0.36), "service_rest_decor", parent)
	_add_box("PubBottleRowB", Vector3(1.58, 1.54, -2.10), Vector3(1.70, 0.16, 0.08), Color(0.62, 0.44, 0.28), "service_rest_decor", parent)
	_add_box("PubBoothLeftBack", Vector3(-2.22, 0.66, -0.96), Vector3(0.24, 0.86, 1.42), Color(0.32, 0.22, 0.18), seat_category, parent)
	_add_box("PubBoothLeftSeat", Vector3(-2.02, 0.34, -0.96), Vector3(0.44, 0.18, 1.22), Color(0.36, 0.24, 0.18), seat_category, parent)
	_add_box("PubBoothRightBack", Vector3(-2.22, 0.66, 0.96), Vector3(0.24, 0.86, 1.42), Color(0.32, 0.22, 0.18), seat_category, parent)
	_add_box("PubBoothRightSeat", Vector3(-2.02, 0.34, 0.96), Vector3(0.44, 0.18, 1.22), Color(0.36, 0.24, 0.18), seat_category, parent)
	_add_box("PubTableLeftLeg", Vector3(-1.46, 0.40, -0.96), Vector3(0.10, 0.72, 0.10), Color(0.30, 0.22, 0.18), "service_rest_counter", parent)
	_add_box("PubTableRightLeg", Vector3(-1.46, 0.40, 0.96), Vector3(0.10, 0.72, 0.10), Color(0.30, 0.22, 0.18), "service_rest_counter", parent)
	_add_box("PubTableLeft", Vector3(-1.46, 0.80, -0.96), Vector3(0.72, 0.08, 0.90), Color(0.46, 0.36, 0.28), "service_rest_tabletop", parent)
	_add_box("PubTableRight", Vector3(-1.46, 0.80, 0.96), Vector3(0.72, 0.08, 0.90), Color(0.46, 0.36, 0.28), "service_rest_tabletop", parent)
	_add_box("PubDartBoard", Vector3(-2.84, 1.72, -1.26), Vector3(0.04, 0.62, 0.62), Color(0.66, 0.56, 0.40), "service_rest_decor", parent)
	_add_box("PubPoster", Vector3(2.84, 1.58, 0.82), Vector3(0.04, 0.82, 0.62), Color(0.66, 0.56, 0.40), "service_rest_decor", parent)
	var title = Label3D.new()
	title.text = title_text
	title.position = Vector3(0.0, 2.10, -2.20)
	title.font_size = 36
	title.modulate = Color(0.92, 0.78, 0.56, 0.90)
	parent.add_child(title)
	if nav_text != "":
		var nav_label = Label3D.new()
		nav_label.text = nav_text
		nav_label.position = Vector3(2.06, 1.66, 2.06)
		nav_label.rotation_degrees = Vector3(0.0, 180.0, 0.0)
		nav_label.font_size = 18
		nav_label.modulate = Color(0.90, 0.82, 0.68, 0.84)
		parent.add_child(nav_label)


func _build_vecerka_shop_layout(parent: Node3D) -> void:
	var w = 3.6
	var d = 3.6
	var h = 3.2
	
	_add_box("VFloor", Vector3(0.0, 0.0, 0.0), Vector3(w, 0.1, d), Color(0.58, 0.56, 0.54), "service_kitchen_floor", parent)
	_add_box("VCeiling", Vector3(0.0, h, 0.0), Vector3(w, 0.1, d), Color(0.66, 0.64, 0.62), "service_rest_ceiling", parent)
	_add_box("VWallBack", Vector3(0.0, h * 0.5, -d * 0.5), Vector3(w, h, 0.1), Color(0.64, 0.60, 0.58), "service_vecerka_wall", parent)
	_add_box("VWallFront", Vector3(0.0, h * 0.5, d * 0.5), Vector3(w, h, 0.1), Color(0.64, 0.60, 0.58), "service_vecerka_wall", parent)
	_add_box("VWallLeft", Vector3(-w * 0.5, h * 0.5, 0.0), Vector3(0.1, h, d), Color(0.62, 0.58, 0.56), "service_vecerka_wall", parent)
	_add_box("VWallRight", Vector3(w * 0.5, h * 0.5, 0.0), Vector3(0.1, h, d), Color(0.62, 0.58, 0.56), "service_vecerka_wall", parent)

	# Main Counter
	_add_box("CounterBase", Vector3(-0.8, 0.5, 0.8), Vector3(1.8, 1.0, 0.6), Color(0.48, 0.44, 0.40), "service_rest_counter", parent)
	_add_box("CounterTop", Vector3(-0.8, 1.02, 0.8), Vector3(1.9, 0.05, 0.7), Color(0.56, 0.52, 0.48), "service_rest_tabletop", parent)
	
	# Shelves
	_add_box("ShelfBackL", Vector3(-1.0, 1.2, -1.6), Vector3(1.2, 1.8, 0.4), Color(0.44, 0.40, 0.36), "service_vecerka_shelf", parent)
	_add_box("ShelfBackR", Vector3(1.0, 1.2, -1.6), Vector3(1.2, 1.8, 0.4), Color(0.44, 0.40, 0.36), "service_vecerka_shelf", parent)
	_add_box("ShelfRight", Vector3(1.6, 1.2, 0.0), Vector3(0.4, 1.8, 2.0), Color(0.44, 0.40, 0.36), "service_vecerka_shelf", parent)
	
	# Hotdog Counter (as requested)
	_add_box("HotdogCounterBase", Vector3(0.6, 0.5, 0.8), Vector3(1.0, 1.0, 0.6), Color(0.44, 0.36, 0.30), "service_rest_counter", parent)
	_add_box("HotdogCounterTop", Vector3(0.6, 1.02, 0.8), Vector3(1.1, 0.05, 0.7), Color(0.52, 0.46, 0.40), "service_rest_tabletop", parent)
	_add_box("HotdogGrill", Vector3(0.6, 1.10, 0.8), Vector3(0.7, 0.12, 0.4), Color(0.36, 0.34, 0.32), "service_kitchen_island_top", parent)

	# Posters
	_add_box("PosterA", Vector3(-1.7, 1.8, -0.2), Vector3(0.02, 0.8, 0.6), Color(0.8, 0.8, 0.8), "service_vecerka_poster", parent)
	_add_box("PosterB", Vector3(-1.7, 1.8, 0.6), Vector3(0.02, 0.8, 0.6), Color(0.8, 0.8, 0.8), "service_vecerka_poster", parent)

	var title = Label3D.new()
	title.text = "GROCERY"
	title.position = Vector3(0.0, 2.4, -1.78)
	title.font_size = 42
	title.modulate = Color(1.0, 0.96, 0.84, 0.9)
	parent.add_child(title)

	var nav = Label3D.new()
	nav.text = "D > STOREROOM"
	nav.position = Vector3(1.0, 1.5, 1.0)
	nav.rotation_degrees = Vector3(0, 180, 0)
	nav.font_size = 20
	nav.modulate = Color(1.0, 1.0, 1.0, 0.8)
	parent.add_child(nav)


func _build_vecerka_storage_layout(parent: Node3D) -> void:
	var w = 3.6
	var d = 3.6
	var h = 3.2
	
	_add_box("SFloor", Vector3(0.0, 0.0, 0.0), Vector3(w, 0.1, d), Color(0.48, 0.46, 0.44), "service_kitchen_floor", parent)
	_add_box("SCeiling", Vector3(0.0, h, 0.0), Vector3(w, 0.1, d), Color(0.56, 0.54, 0.52), "service_rest_ceiling", parent)
	# Walls using same texture as shop
	_add_box("SWallBack", Vector3(0.0, h * 0.5, -d * 0.5), Vector3(w, h, 0.1), Color(0.54, 0.50, 0.48), "service_vecerka_wall", parent)
	_add_box("SWallFront", Vector3(0.0, h * 0.5, d * 0.5), Vector3(w, h, 0.1), Color(0.54, 0.50, 0.48), "service_vecerka_wall", parent)
	_add_box("SWallLeft", Vector3(-w * 0.5, h * 0.5, 0.0), Vector3(0.1, h, d), Color(0.52, 0.48, 0.46), "service_vecerka_wall", parent)
	_add_box("SWallRight", Vector3(w * 0.5, h * 0.5, 0.0), Vector3(0.1, h, d), Color(0.52, 0.48, 0.46), "service_vecerka_wall", parent)
	
	# Storage Cabinets (0513)
	for i in range(3):
		var x = -1.2 + i * 1.2
		_add_box("CabBack" + str(i), Vector3(x, 1.0, -1.4), Vector3(1.0, 2.0, 0.6), Color(0.44, 0.40, 0.36), "service_vecerka_storage", parent)
	
	for i in range(2):
		var z = -0.5 + i * 1.4
		_add_box("CabLeft" + str(i), Vector3(-1.4, 1.0, z), Vector3(0.6, 2.0, 1.0), Color(0.44, 0.40, 0.36), "service_vecerka_storage", parent)

	var title = Label3D.new()
	title.text = "STOREROOM"
	title.position = Vector3(0.0, 2.4, -1.6)
	title.font_size = 42
	title.modulate = Color(0.9, 0.9, 0.9, 0.9)
	parent.add_child(title)
	
	var nav = Label3D.new()
	nav.text = "< A SHOP"
	nav.position = Vector3(-1.0, 1.5, 1.0)
	nav.rotation_degrees = Vector3(0, 180, 0)
	nav.font_size = 20
	nav.modulate = Color(1.0, 1.0, 1.0, 0.8)
	parent.add_child(nav)


func _set_vecerka_room(room: String, update_camera: bool = true) -> void:
	if _vecerka_shop_root == null or _vecerka_storage_root == null:
		return
	_active_subroom = room
	_vecerka_shop_root.visible = (room == "shop")
	_vecerka_storage_root.visible = (room == "storage")
	
	if update_camera and _interior_camera != null:
		if room == "storage":
			_interior_camera.position = Vector3(0.0, 1.5, 1.4)
			_interior_camera.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
		else:
			# Keep camera inside room volume; z=1.8 sits in the front wall plane for 3.6 depth.
			_interior_camera.position = Vector3(0.0, 1.5, 1.28)
			_interior_camera.rotation_degrees = Vector3(-10.0, 0.0, 0.0)
	_cam_base_rot = _interior_camera.rotation


func _switch_service_room(direction: int) -> void:
	if _swipe_animating:
		return
	var target_room = ""
	if _current_profile == "rest":
		if direction > 0 and _restaurant_room == "dining":
			target_room = "kitchen"
		elif direction < 0 and _restaurant_room == "basement":
			target_room = "kitchen"
		elif direction < 0 and _restaurant_room == "kitchen":
			target_room = "dining"
		# Add forward logic for kitchen -> basement if needed, or maybe it was secret only?
	elif _current_profile == "vecerka":
		if direction > 0 and _active_subroom == "shop":
			target_room = "storage"
		elif direction < 0 and _active_subroom == "storage":
			target_room = "shop"
	elif _current_profile == "toilet" or _current_profile == "wash":
		if _active_subroom == "center":
			target_room = "left" if direction < 0 else "right"
		elif _active_subroom == "left" and direction > 0:
			target_room = "center"
		elif _active_subroom == "right" and direction < 0:
			target_room = "center"
	
	if target_room == "":
		return
	if _current_profile == "rest" and target_room == _restaurant_room:
		return
	if _current_profile == "vecerka" and target_room == _active_subroom:
		return
	if (_current_profile == "toilet" or _current_profile == "wash") and target_room == _active_subroom:
		return
	_play_room_swipe(target_room, direction)


func _toggle_secret_room() -> void:
	if _current_profile != "rest":
		return
	if _swipe_animating:
		return
	if _restaurant_room == "kitchen":
		_play_room_swipe("basement", 1)
	elif _restaurant_room == "basement":
		_play_room_swipe("kitchen", -1)


func _toggle_kitchen_texture_variant() -> void:
	_kitchen_texture_variant_alt = not _kitchen_texture_variant_alt
	if _current_profile != "rest":
		return
	var wanted_room = _restaurant_room
	var wanted_manual_lights = _manual_lights_on
	_build_service_room("rest")
	_set_restaurant_room(wanted_room, true)
	_manual_lights_on = wanted_manual_lights
	_apply_service_switch_visual()
	_apply_manual_service_light_profile(false)


func _apply_service_subroom(target_room: String, update_camera: bool = true) -> void:
	if _current_profile == "rest":
		_set_restaurant_room(target_room, update_camera)
	elif _current_profile == "vecerka":
		_set_vecerka_room(target_room, update_camera)
	elif _current_profile == "toilet" or _current_profile == "wash":
		_set_hygiene_room(target_room)


func _set_hygiene_room(room: String) -> void:
	if _interior_camera == null:
		return
	_active_subroom = room
	if room == "left":
		_interior_camera.position = Vector3(-1.2, 1.4, -0.2)
		_interior_camera.rotation_degrees = Vector3(-4.0, 35.0, 0.0)
	elif room == "right":
		_interior_camera.position = Vector3(1.2, 1.4, -0.2)
		_interior_camera.rotation_degrees = Vector3(-4.0, -35.0, 0.0)
	else:
		# Center
		_interior_camera.position = Vector3(0.0, 1.46, 0.52)
		_interior_camera.rotation_degrees = Vector3(-7.0, 0.0, 0.0)
	_cam_base_rot = _interior_camera.rotation


func _play_room_swipe(target_room: String, direction: int) -> void:
	if _swipe_overlay == null:
		_apply_service_subroom(target_room, true)
		return
	_update_swipe_overlay_size()
	var screen_size = get_viewport().get_visible_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		_apply_service_subroom(target_room, true)
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
	_swipe_tween.tween_callback(Callable(self, "_apply_service_subroom").bind(target_room, true))
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


func _build_wash_layout(shower_mode: bool, title_override: String = "") -> void:
	var w = 4.2
	var d = 4.0
	var h = 2.7

	_add_box("Floor", Vector3(0.0, 0.0, 0.0), Vector3(w, 0.1, d), Color(0.42, 0.48, 0.54), "service_wash_floor")
	_add_box("Ceiling", Vector3(0.0, h, 0.0), Vector3(w, 0.1, d), Color(0.72, 0.74, 0.78), "service_wash_wall")
	_add_box("WallBack", Vector3(0.0, h * 0.5, -d * 0.5), Vector3(w, h, 0.1), Color(0.66, 0.72, 0.76), "service_wash_wall")
	_add_box("WallFront", Vector3(0.0, h * 0.5, d * 0.5), Vector3(w, h, 0.1), Color(0.66, 0.72, 0.76), "service_wash_wall")
	var wl = _add_box("WallLeft", Vector3(-w * 0.5, h * 0.5, 0.0), Vector3(0.1, h, d), Color(0.66, 0.72, 0.76), "service_wash_wall")
	wl.rotation_degrees.y = 180
	var wr = _add_box("WallRight", Vector3(w * 0.5, h * 0.5, 0.0), Vector3(0.1, h, d), Color(0.66, 0.72, 0.76), "service_wash_wall")
	wr.rotation_degrees.y = 180

	_add_box("DividerA", Vector3(-0.54, 1.20, -0.42), Vector3(0.06, 2.0, 2.30), Color(0.72, 0.74, 0.78), "service_wash_wall")
	_add_box("DividerB", Vector3(0.56, 1.20, -0.42), Vector3(0.06, 2.0, 2.30), Color(0.72, 0.74, 0.78), "service_wash_wall")

	if shower_mode:
		_add_box("ShowerPipeL", Vector3(-1.20, 1.86, -1.36), Vector3(0.06, 0.90, 0.06), Color(0.66, 0.70, 0.76), "service_wash_fixture")
		_add_box("ShowerHeadL", Vector3(-1.20, 2.20, -1.20), Vector3(0.14, 0.06, 0.14), Color(0.72, 0.76, 0.82), "service_wash_fixture")
		_add_box("ShowerDrainL", Vector3(-1.20, 0.06, -1.06), Vector3(0.30, 0.02, 0.30), Color(0.26, 0.30, 0.34), "service_wash_fixture")

		_add_box("ShowerPipeR", Vector3(1.20, 1.86, -1.36), Vector3(0.06, 0.90, 0.06), Color(0.66, 0.70, 0.76), "service_wash_fixture")
		_add_box("ShowerHeadR", Vector3(1.20, 2.20, -1.20), Vector3(0.14, 0.06, 0.14), Color(0.72, 0.76, 0.82), "service_wash_fixture")
		_add_box("ShowerDrainR", Vector3(1.20, 0.06, -1.06), Vector3(0.30, 0.02, 0.30), Color(0.26, 0.30, 0.34), "service_wash_fixture")
	else:
		_add_box("StallDoorL", Vector3(-1.20, 1.00, -1.10), Vector3(0.76, 2.0, 0.04), Color(0.62, 0.66, 0.72), "service_wash_fixture")
		_add_box("StallDoorR", Vector3(1.20, 1.00, -1.10), Vector3(0.76, 2.0, 0.04), Color(0.62, 0.66, 0.72), "service_wash_fixture")
		_add_box("StallSeatL", Vector3(-1.20, 0.34, -1.52), Vector3(0.56, 0.50, 0.66), Color(0.70, 0.72, 0.76), "service_wash_fixture")
		_add_box("StallSeatR", Vector3(1.20, 0.34, -1.52), Vector3(0.56, 0.50, 0.66), Color(0.70, 0.72, 0.76), "service_wash_fixture")

	_add_box("SinkCounter", Vector3(0.0, 0.66, 1.26), Vector3(2.56, 0.76, 0.64), Color(0.70, 0.72, 0.76), "service_wash_fixture")
	_add_box("SinkBasinL", Vector3(-0.76, 0.94, 1.26), Vector3(0.56, 0.16, 0.32), Color(0.82, 0.84, 0.88), "service_wash_fixture")
	_add_box("SinkBasinR", Vector3(0.76, 0.94, 1.26), Vector3(0.56, 0.16, 0.32), Color(0.82, 0.84, 0.88), "service_wash_fixture")
	_add_box("Mirror", Vector3(0.0, 1.74, 1.94), Vector3(1.90, 0.82, 0.04), Color(0.72, 0.78, 0.84), "service_wash_fixture")
	_add_box("Bench", Vector3(0.0, 0.34, 0.22), Vector3(1.60, 0.26, 0.52), Color(0.58, 0.56, 0.52), "service_wash_fixture")

	var title = Label3D.new()
	var default_title = "SPRCHY" if shower_mode else "KOUPELNA"
	title.text = title_override if title_override != "" else default_title
	title.position = Vector3(0.0, 2.20, -1.90)
	title.font_size = 32
	title.modulate = Color(0.90, 0.92, 0.96, 0.86)
	_room_root.add_child(title)
	
	var nav_l = Label3D.new()
	nav_l.text = "< A SHOWERS"
	nav_l.position = Vector3(-1.4, 1.6, -0.8)
	nav_l.rotation_degrees = Vector3(0, 45, 0)
	nav_l.font_size = 18
	nav_l.modulate = Color(1.0, 1.0, 1.0, 0.7)
	_room_root.add_child(nav_l)
	
	var nav_r = Label3D.new()
	nav_r.text = "SHOWERS D >"
	nav_r.position = Vector3(1.4, 1.6, -0.8)
	nav_r.rotation_degrees = Vector3(0, -45, 0)
	nav_r.font_size = 18
	nav_r.modulate = Color(1.0, 1.0, 1.0, 0.7)
	_room_root.add_child(nav_r)


func _build_toilet_layout() -> void:
	var w = 4.4
	var d = 3.8
	var h = 2.6

	_add_box("ToiletFloor", Vector3(0.0, 0.0, 0.0), Vector3(w, 0.1, d), Color(0.34, 0.34, 0.32), "service_toilet_floor")
	_add_box("ToiletCeiling", Vector3(0.0, h, 0.0), Vector3(w, 0.1, d), Color(0.44, 0.42, 0.38), "service_toilet_ceiling")
	_add_box("ToiletWallBack", Vector3(0.0, h * 0.5, -d * 0.5), Vector3(w, h, 0.1), Color(0.52, 0.50, 0.44), "service_toilet_wall")
	_add_box("ToiletWallFront", Vector3(0.0, h * 0.5, d * 0.5), Vector3(w, h, 0.1), Color(0.52, 0.50, 0.44), "service_toilet_wall")
	var wl = _add_box("ToiletWallLeft", Vector3(-w * 0.5, h * 0.5, 0.0), Vector3(0.1, h, d), Color(0.50, 0.48, 0.42), "service_toilet_wall")
	wl.rotation_degrees.y = 180
	var wr = _add_box("ToiletWallRight", Vector3(w * 0.5, h * 0.5, 0.0), Vector3(0.1, h, d), Color(0.50, 0.48, 0.42), "service_toilet_wall")
	wr.rotation_degrees.y = 180

	_add_box("ToiletStallDividerA", Vector3(-0.64, 1.12, -0.52), Vector3(0.08, 2.0, 2.06), Color(0.56, 0.54, 0.48), "service_toilet_wall")
	_add_box("ToiletStallDividerB", Vector3(0.64, 1.12, -0.52), Vector3(0.08, 2.0, 2.06), Color(0.56, 0.54, 0.48), "service_toilet_wall")
	_add_box("ToiletDoorL", Vector3(-1.34, 0.98, -1.36), Vector3(0.70, 1.86, 0.04), Color(0.30, 0.28, 0.24), "service_toilet_fixture")
	_add_box("ToiletDoorR", Vector3(1.34, 0.98, -1.36), Vector3(0.70, 1.86, 0.04), Color(0.30, 0.28, 0.24), "service_toilet_fixture")
	_add_box("ToiletSeatL", Vector3(-1.34, 0.34, -1.74), Vector3(0.54, 0.52, 0.62), Color(0.66, 0.66, 0.62), "service_toilet_fixture")
	_add_box("ToiletSeatR", Vector3(1.34, 0.34, -1.74), Vector3(0.54, 0.52, 0.62), Color(0.66, 0.66, 0.62), "service_toilet_fixture")
	_add_box("ToiletUrinalA", Vector3(-0.12, 0.88, -1.72), Vector3(0.32, 0.96, 0.28), Color(0.76, 0.74, 0.66), "service_toilet_fixture")
	_add_box("ToiletUrinalB", Vector3(0.12, 0.88, -1.72), Vector3(0.32, 0.96, 0.28), Color(0.76, 0.74, 0.66), "service_toilet_fixture")
	_add_box("ToiletSinkCounter", Vector3(0.0, 0.64, 1.08), Vector3(2.52, 0.72, 0.62), Color(0.58, 0.56, 0.50), "service_toilet_fixture")
	_add_box("ToiletMirror", Vector3(0.0, 1.72, 1.82), Vector3(1.92, 0.72, 0.04), Color(0.58, 0.64, 0.66), "service_toilet_fixture")
	_add_box("ToiletDrainA", Vector3(-1.30, 0.06, -0.20), Vector3(0.28, 0.02, 0.28), Color(0.24, 0.24, 0.22), "service_toilet_fixture")
	_add_box("ToiletDrainB", Vector3(1.30, 0.06, -0.20), Vector3(0.28, 0.02, 0.28), Color(0.24, 0.24, 0.22), "service_toilet_fixture")

	var title = Label3D.new()
	title.text = "TOILETS"
	title.position = Vector3(0.0, 2.12, -1.76)
	title.font_size = 34
	title.modulate = Color(0.82, 0.86, 0.76, 0.88)
	_room_root.add_child(title)

	var nav_l = Label3D.new()
	nav_l.text = "< A STALLS"
	nav_l.position = Vector3(-1.4, 1.6, -0.8)
	nav_l.rotation_degrees = Vector3(0, 45, 0)
	nav_l.font_size = 18
	nav_l.modulate = Color(1.0, 1.0, 1.0, 0.7)
	_room_root.add_child(nav_l)
	
	var nav_r = Label3D.new()
	nav_r.text = "STALLS D >"
	nav_r.position = Vector3(1.4, 1.6, -0.8)
	nav_r.rotation_degrees = Vector3(0, -45, 0)
	nav_r.font_size = 18
	nav_r.modulate = Color(1.0, 1.0, 1.0, 0.7)
	_room_root.add_child(nav_r)


func _build_sewer_layout() -> void:
	var w = 4.8
	var d = 4.8
	var h = 2.6

	_add_box("SewerFloor", Vector3(0.0, 0.0, 0.0), Vector3(w, 0.1, d), Color(0.28, 0.30, 0.30), "service_sewer_floor")
	_add_box("SewerChannel521", Vector3(-1.02, 0.035, 0.0), Vector3(0.72, 0.06, d - 0.56), Color(0.30, 0.32, 0.34), "service_sewer_channel_521")
	_add_box("SewerChannel522", Vector3(1.02, 0.035, 0.0), Vector3(0.72, 0.06, d - 0.56), Color(0.32, 0.34, 0.36), "service_sewer_channel_522")
	_add_box("SewerCeiling", Vector3(0.0, h, 0.0), Vector3(w, 0.1, d), Color(0.34, 0.36, 0.36), "service_sewer_ceiling")
	_add_box("SewerWallBack", Vector3(0.0, h * 0.5, -d * 0.5), Vector3(w, h, 0.1), Color(0.34, 0.36, 0.36), "service_sewer_wall")
	_add_box("SewerWallFront", Vector3(0.0, h * 0.5, d * 0.5), Vector3(w, h, 0.1), Color(0.34, 0.36, 0.36), "service_sewer_wall")
	_add_box("SewerWallLeft", Vector3(-w * 0.5, h * 0.5, 0.0), Vector3(0.1, h, d), Color(0.32, 0.34, 0.34), "service_sewer_wall")
	_add_box("SewerWallRight", Vector3(w * 0.5, h * 0.5, 0.0), Vector3(0.1, h, d), Color(0.32, 0.34, 0.34), "service_sewer_wall")

	var title = Label3D.new()
	title.text = "SEWER"
	title.position = Vector3(0.0, 2.08, -2.16)
	title.font_size = 36
	title.modulate = Color(0.84, 0.86, 0.88, 0.88)
	_room_root.add_child(title)

	_sewer_hint = Label3D.new()
	_sewer_hint.position = Vector3(0.0, 1.70, -2.16)
	_sewer_hint.font_size = 18
	_room_root.add_child(_sewer_hint)
	_apply_sewer_hint()


func _build_generator_layout() -> void:
	var w = 4.0
	var d = 4.0
	var h = 2.8

	_add_box("GenFloor", Vector3(0.0, 0.0, 0.0), Vector3(w, 0.1, d), Color(0.24, 0.22, 0.20), "service_sewer_floor")
	_add_box("GenCeiling", Vector3(0.0, h, 0.0), Vector3(w, 0.1, d), Color(0.34, 0.32, 0.30), "utility_exterior_wall")
	_add_box("GenWallBack", Vector3(0.0, h * 0.5, -d * 0.5), Vector3(w, h, 0.1), Color(0.36, 0.34, 0.32), "utility_exterior_wall")
	_add_box("GenWallFront", Vector3(0.0, h * 0.5, d * 0.5), Vector3(w, h, 0.1), Color(0.36, 0.34, 0.32), "utility_exterior_wall")
	_add_box("GenWallLeft", Vector3(-w * 0.5, h * 0.5, 0.0), Vector3(0.1, h, d), Color(0.34, 0.32, 0.30), "utility_power_side_610")
	_add_box("GenWallRight", Vector3(w * 0.5, h * 0.5, 0.0), Vector3(0.1, h, d), Color(0.34, 0.32, 0.30), "utility_power_back_609")

	# Internal machinery
	_add_box("GenCore", Vector3(0.0, 0.8, 0.0), Vector3(1.8, 1.6, 1.8), Color(0.4, 0.4, 0.4), "service_basement_machine")
	_add_box("GenPipes", Vector3(0.0, 1.8, -0.6), Vector3(1.2, 0.4, 0.4), Color(0.3, 0.3, 0.3), "service_basement_machine")

	var title = Label3D.new()
	title.text = "GENERATOR"
	title.position = Vector3(0.0, 2.22, -1.82)
	title.font_size = 38
	title.modulate = Color(1.0, 0.88, 0.44, 0.94)
	_room_root.add_child(title)


# ── cleaning the block from the inside ────────────────────────────────────────

func _free_upkeep_prep() -> void:
	if _upkeep_prep != null and _upkeep_prep.tasks != null and is_instance_valid(_upkeep_prep.tasks):
		_upkeep_prep.tasks.queue_free()
	_upkeep_prep = null


## Spots of the current hygiene layout, where the mess can be (MESS_RULES.BLOCK_SPOTS).
func _build_upkeep_spots(block: String) -> void:
	_free_upkeep_prep()
	_upkeep_prep = INTERIOR_PREP.new()
	var r := _room_root
	if block == "toilet":
		_upkeep_prep.add_spot("stall_l", r, Vector3(-1.34, 0.04, -0.95))
		_upkeep_prep.add_spot("stall_r", r, Vector3(1.34, 0.04, -0.95))
		_upkeep_prep.add_spot("urinal", r, Vector3(0.0, 0.04, -1.3))
		_upkeep_prep.add_spot("door_l", r, Vector3(-1.34, 1.25, -1.33), 0.0, true)
		_upkeep_prep.add_spot("door_r", r, Vector3(1.34, 1.25, -1.33), 0.0, true)
		_upkeep_prep.add_spot("floor_c", r, Vector3(0.0, 0.04, -0.45))
		_upkeep_prep.add_spot("wall_l", r, Vector3(-2.14, 1.35, -0.3), PI * 0.5, true)
	else:
		_upkeep_prep.add_spot("shower_l", r, Vector3(-1.2, 0.5, -1.94), 0.0, true)
		_upkeep_prep.add_spot("shower_r", r, Vector3(1.2, 0.5, -1.94), 0.0, true)
		_upkeep_prep.add_spot("drain_l", r, Vector3(-1.2, 0.07, -1.06))
		_upkeep_prep.add_spot("drain_r", r, Vector3(1.2, 0.07, -1.06))
		_upkeep_prep.add_spot("floor_c", r, Vector3(0.0, 0.04, -0.6))
		_upkeep_prep.add_spot("floor_l", r, Vector3(-1.2, 0.04, -0.35))
		_upkeep_prep.add_spot("floor_r", r, Vector3(1.2, 0.04, -0.35))
	_upkeep_prep.setup_tasks(self, _interior_camera, _viewport)
	_upkeep_prep.task_completed.connect(_on_upkeep_task_done)


## InteriorManager, after open_service(): which block this is. Toilet and shower blocks
## get their cleaning list; everything else ignores it.
func set_upkeep_target(coord: Vector2i, building_type: String) -> void:
	_upkeep_coord = coord
	_upkeep_type = building_type
	_upkeep_key = "%d:%d" % [coord.x, coord.y]
	var block := "toilet" if building_type == "toilet_block" else ("wash" if building_type == "shower_block" else "")
	if block.is_empty() or _room_root == null:
		_free_upkeep_prep()
		return
	if not EventBus.building_serviced.is_connected(_on_block_serviced):
		EventBus.building_serviced.connect(_on_block_serviced)
	var state = CoreRoot.get_state()
	var cell: Dictionary = state.grid.cells.get(coord, {}) if state != null else {}
	var condition := float(cell.get("maintenance", 1.0))
	var broken: bool = state != null and state.failures.has(_upkeep_key)
	var entry: Dictionary = _upkeep_cache.get(_upkeep_key, {})
	if bool(entry.get("spent", false)):
		entry = {}
	# A breakdown since the last visit adds its job to the list.
	if entry.is_empty() or (broken and not bool(entry.get("broken", false))):
		var day := int(state.day) if state != null else 1
		entry = {
			"tasks": MESS_RULES.block_tasks(block, condition, broken, absi(("%s|%d" % [_upkeep_key, day]).hash())),
			"done": (entry.get("done", []) as Array).duplicate() if not entry.is_empty() else [],
			"broken": broken,
		}
		_upkeep_cache[_upkeep_key] = entry
	_build_upkeep_spots(block)
	_refresh_upkeep_room()
	# Everything done last time but the bill was not paid: try again now.
	if not (entry["tasks"] as Array).is_empty() and _all_upkeep_done(entry):
		_finish_upkeep()


func _upkeep_room_dict() -> Dictionary:
	var entry: Dictionary = _upkeep_cache.get(_upkeep_key, {})
	var tasks: Array = entry.get("tasks", [])
	var clean := tasks.is_empty() or bool(entry.get("spent", false))
	var label := "Toilets" if _upkeep_type == "toilet_block" else "Showers"
	return {
		"label": "%s %s" % [label, _upkeep_key],
		"status": "ready" if clean else "dirty",
		"ready_text": "CLEAN",
		"dirty_text": "BROKEN DOWN" if bool(entry.get("broken", false)) else "NEEDS CLEANING",
		"done": entry.get("done", []),
		"tasks": tasks,
		"occupied": false,
		"note": "" if bool(entry.get("spent", false)) else str(entry.get("note", "")),
	}


func _refresh_upkeep_room() -> void:
	if _upkeep_prep != null:
		_upkeep_prep.set_room(_upkeep_room_dict())


func _all_upkeep_done(entry: Dictionary) -> bool:
	for t in entry.get("tasks", []):
		if not (entry.get("done", []) as Array).has(str(t["id"])):
			return false
	return true


func _on_upkeep_task_done(task_id: String) -> void:
	var entry: Dictionary = _upkeep_cache.get(_upkeep_key, {})
	if entry.is_empty():
		return
	var done: Array = entry.get("done", [])
	if not done.has(task_id):
		done.append(task_id)
	entry["done"] = done
	_upkeep_cache[_upkeep_key] = entry
	if _all_upkeep_done(entry):
		_finish_upkeep()
	else:
		_refresh_upkeep_room()


## The last job done: the block is back to 100%. Cleaning costs the supplies, a
## breakdown the spare part (the same prices as the crew's, minus the crew).
func _finish_upkeep() -> void:
	var entry: Dictionary = _upkeep_cache.get(_upkeep_key, {})
	var def = CoreRoot.registry.get_def(StringName(_upkeep_type)) if CoreRoot != null else null
	var state = CoreRoot.get_state()
	var cell: Dictionary = state.grid.cells.get(_upkeep_coord, {}) if state != null else {}
	var broken := bool(entry.get("broken", false))
	var cost := UPKEEP_RULES.repair_cost(def) if broken else UPKEEP_RULES.service_cost(def, float(cell.get("maintenance", 1.0)))
	if not CoreRoot.actions.service_building(_upkeep_coord, cost):
		entry["note"] = "NO CASH FOR THE %s ($%d)" % ["SPARE PART" if broken else "SUPPLIES", cost]
		_upkeep_cache[_upkeep_key] = entry
		_refresh_upkeep_room()
		return
	if _upkeep_prep != null:
		_upkeep_prep.play_room_ready()
	_refresh_upkeep_room()


func _on_block_serviced(coord: Vector2i, _type: String, _was_broken: bool, _cost: int) -> void:
	var key := "%d:%d" % [coord.x, coord.y]
	var entry: Dictionary = _upkeep_cache.get(key, {})
	if entry.is_empty():
		return
	# Serviced (by you or the crew): the list is spent. Keep it shown as done while you
	# are still standing in there.
	if key == _upkeep_key and _is_open:
		var all_ids: Array = (entry.get("tasks", []) as Array).map(func(t): return str(t["id"]))
		entry["done"] = all_ids
		entry["spent"] = true
		_upkeep_cache[key] = entry
		_refresh_upkeep_room()
	else:
		_upkeep_cache.erase(key)


func _profile_for_service(service_type: String) -> String:
	if service_type == "restaurant":
		return "rest"
	if service_type == "pub":
		return "pub"
	if service_type == "shower_block":
		return "wash"
	if service_type == "toilet_block":
		return "toilet"
	if service_type == "sewer":
		return "sewer"
	if service_type == "vecerka":
		return "vecerka"
	if service_type == "power_generator":
		return "generator"
	return "rest"


func _try_request_service_repair() -> void:
	if _current_profile != "sewer" or not _sewer_broken:
		return
	request_repair.emit()


## Whether the building behind this hatch is broken. Only then is there a leak to find
## down there, and only then does R take you into the pipes.
func set_sewer_broken(broken: bool) -> void:
	_sewer_broken = broken
	_apply_sewer_hint()


func _apply_sewer_hint() -> void:
	if _sewer_hint == null or not is_instance_valid(_sewer_hint):
		return
	if _sewer_broken:
		_sewer_hint.text = "LEAK REPORTED
R > CRAWL INTO THE PIPES"
		_sewer_hint.modulate = Color(1.0, 0.62, 0.36, 0.95)
	else:
		_sewer_hint.text = "NO FAULTS"
		_sewer_hint.modulate = Color(0.70, 0.76, 0.70, 0.70)


func _apply_time_profile(animated: bool = false) -> void:
	if _room_env != null:
		match _time_state:
			TIME_DAY:
				_room_env.background_color = Color(0.62, 0.68, 0.74)
				_room_env.ambient_light_color = Color(0.80, 0.84, 0.82)
				_room_env.ambient_light_energy = 0.94
			TIME_EVENING:
				_room_env.background_color = Color(0.24, 0.22, 0.26)
				_room_env.ambient_light_color = Color(0.54, 0.52, 0.56)
				_room_env.ambient_light_energy = 0.50
			_:
				_room_env.background_color = Color(0.08, 0.10, 0.14)
				_room_env.ambient_light_color = Color(0.24, 0.28, 0.36)
				_room_env.ambient_light_energy = 0.12 # Increased base night ambient

	if _main_light != null:
		match _time_state:
			TIME_DAY:
				_main_light.light_color = Color(1.0, 0.96, 0.88)
				_main_light.light_energy = 1.30
			TIME_EVENING:
				_main_light.light_color = Color(0.92, 0.80, 0.68)
				_main_light.light_energy = 0.88
			_:
				_main_light.light_color = Color(0.66, 0.72, 0.88)
				_main_light.light_energy = 0.24 # Increased base night energy

	var daylight = clampf(_daylight_factor, 0.0, 1.0)
	var sun_tint = _sunlight_color.lerp(Color(1.0, 0.96, 0.90), 0.25)
	if _room_env != null:
		_room_env.ambient_light_color = _room_env.ambient_light_color.lerp(sun_tint, 0.16 * daylight)
		_room_env.ambient_light_energy = lerpf(_room_env.ambient_light_energy * 0.82, _room_env.ambient_light_energy * 1.16, daylight)
	if _main_light != null:
		_main_light.light_color = _main_light.light_color.lerp(sun_tint, 0.10 * daylight)
		_main_light.light_energy = lerpf(_main_light.light_energy * 0.90, _main_light.light_energy * 1.10, daylight)
	_apply_manual_service_light_profile(animated)


func _apply_manual_service_light_profile(animated: bool) -> void:
	if _main_light == null:
		return
	var target_ambient = _room_env.ambient_light_energy if _room_env != null else 0.0
	var target_light = _main_light.light_energy
	if not _manual_lights_on:
		target_ambient *= 0.45
		target_light = 0.0
	else:
		# If ON, we want a decent minimum brightness even at night
		target_ambient = max(target_ambient, 0.50)
		target_light = max(target_light, 1.10)
	if not _grid_power_available:
		target_ambient *= 0.30
		target_light = 0.0
	if animated:
		if _manual_light_tween != null and is_instance_valid(_manual_light_tween):
			_manual_light_tween.kill()
		_manual_light_tween = create_tween()
		_manual_light_tween.set_parallel(true)
		_manual_light_tween.set_ease(Tween.EASE_IN_OUT)
		_manual_light_tween.set_trans(Tween.TRANS_SINE)
		if _room_env != null:
			_manual_light_tween.tween_property(_room_env, "ambient_light_energy", target_ambient, 0.56)
		_manual_light_tween.tween_property(_main_light, "light_energy", target_light, 0.56)
		return
	if _room_env != null:
		_room_env.ambient_light_energy = target_ambient
	_main_light.light_energy = target_light


func _add_box(node_name: String, pos: Vector3, box_size: Vector3, color: Color, category: String, parent: Node3D = null) -> MeshInstance3D:
	if _room_root == null:
		return null
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = node_name
	var box = BoxMesh.new()
	box.size = box_size
	mesh_inst.mesh = box
	mesh_inst.position = pos

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.96
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.uv1_scale = Vector3(max(1.0, box_size.x * 1.4), 1.0, max(1.0, box_size.z * 1.4))
	if _texture_style != null:
		var tex = _texture_style.pick_texture(category, color)
		if tex != null:
			mat.albedo_texture = tex
			mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mesh_inst.material_override = mat

	var parent_node = parent if parent != null else _room_root
	parent_node.add_child(mesh_inst)
	return mesh_inst
