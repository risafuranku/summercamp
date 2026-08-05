extends CanvasLayer

@warning_ignore("unused_signal")
signal repair_completed(coord: Vector2i, building_type: String)
signal repair_cancelled

const PIPE_AMBIENCE_PATH := "res://assets/sfx/rednecksfx/rrswerambience.wav"
const INTERIOR_RENDER_MIN_SIZE := Vector2i(960, 540)

const DIR_NORTH := 0
const DIR_EAST := 1
const DIR_SOUTH := 2
const DIR_WEST := 3

const DIR_TO_YAW := {
	DIR_NORTH: 0.0,
	DIR_EAST: -PI * 0.5,
	DIR_SOUTH: PI,
	DIR_WEST: PI * 0.5,
}

const DIR_TO_WORLD := {
	DIR_NORTH: Vector3(0.0, 0.0, -1.0),
	DIR_EAST: Vector3(1.0, 0.0, 0.0),
	DIR_SOUTH: Vector3(0.0, 0.0, 1.0),
	DIR_WEST: Vector3(-1.0, 0.0, 0.0),
}

const NODE_LAYOUT := {
	"A": Vector2i(0, 0),
	"B": Vector2i(0, -1),
	"C": Vector2i(1, -1),
	"D": Vector2i(2, -1),
	"E": Vector2i(2, 0),
	"F": Vector2i(2, 1),
	"G": Vector2i(1, 1),
	"H": Vector2i(0, 1),
	"I": Vector2i(-1, 1),
	"J": Vector2i(-1, 0),
	"K": Vector2i(-1, -1),
	"L": Vector2i(0, -2),
	"M": Vector2i(1, -2),
	"N": Vector2i(3, 0),
	"O": Vector2i(3, 1),
	"P": Vector2i(3, -1),
}

# Dead-end free graph.
const NODE_LINKS := {
	"A": {DIR_NORTH: "B", DIR_SOUTH: "H", DIR_WEST: "J"},
	"B": {DIR_NORTH: "L", DIR_EAST: "C", DIR_SOUTH: "A", DIR_WEST: "K"},
	"C": {DIR_EAST: "D", DIR_WEST: "B", DIR_NORTH: "M"},
	"D": {DIR_EAST: "P", DIR_SOUTH: "E", DIR_WEST: "C"},
	"E": {DIR_NORTH: "D", DIR_SOUTH: "F", DIR_EAST: "N"},
	"F": {DIR_NORTH: "E", DIR_WEST: "G", DIR_EAST: "O"},
	"G": {DIR_EAST: "F", DIR_WEST: "H"},
	"H": {DIR_EAST: "G", DIR_WEST: "I", DIR_NORTH: "A"},
	"I": {DIR_EAST: "H", DIR_NORTH: "J"},
	"J": {DIR_EAST: "A", DIR_NORTH: "K", DIR_SOUTH: "I"},
	"K": {DIR_EAST: "B", DIR_SOUTH: "J"},
	"L": {DIR_SOUTH: "B", DIR_EAST: "M"},
	"M": {DIR_WEST: "L", DIR_SOUTH: "C"},
	"N": {DIR_NORTH: "O", DIR_SOUTH: "P", DIR_WEST: "E"},
	"O": {DIR_SOUTH: "N", DIR_WEST: "F"},
	"P": {DIR_NORTH: "N", DIR_WEST: "D"},
}

const PLAYER_START_NODE := "A"
const PLAYER_START_FACING := DIR_NORTH

const CELL_WORLD_SIZE := 3.0
const PIPE_CENTER_Y := 0.78
const PIPE_RADIUS := 0.78
const JUNCTION_ARM_RADIUS := 0.83
const JUNCTION_ARM_LENGTH := 1.04
const JUNCTION_JOIN_OVERLAP := 0.34
const PIPE_RADIAL_SEGMENTS := 72
const PIPE_RINGS := 8
const JUNCTION_LIGHT_ENERGY := 0.22
const JUNCTION_VIEW_BACK_OFFSET := 0.22
const MOVE_SECONDS := 0.42
const PLAYER_FOV := 54.0
const FLASHLIGHT_BASE_ENERGY := 2.8

var _active: bool = false
var _coord: Vector2i = Vector2i.ZERO
var _building_type: String = ""

var _root: Control
var _viewport_container: SubViewportContainer
var _viewport: SubViewport
var _world_root: Node3D
var _pipe_geo_root: Node3D

var _player_rig: Node3D
var _camera: Camera3D
var _flashlight: SpotLight3D
var _ambience_player: AudioStreamPlayer
var _pipe_inner_material: StandardMaterial3D

var _node_world: Dictionary = {}

var _player_node: String = PLAYER_START_NODE
var _player_from_node: String = PLAYER_START_NODE
var _player_to_node: String = PLAYER_START_NODE
var _player_facing: int = PLAYER_START_FACING
var _player_moving: bool = false
var _player_move_t: float = 0.0
var _headbob_t: float = 0.0
var _flashlight_on: bool = true


func _ready() -> void:
	layer = 128
	visible = false
	_build_shell()
	_build_network()
	set_process(true)


func is_open() -> bool:
	return _active


func open_repair(coord: Vector2i, building_type: String, _label_text: String = "") -> void:
	_coord = coord
	_building_type = building_type
	_active = true
	visible = true
	_reset_player_state()
	_play_ambience()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func close_repair(cancelled: bool = true) -> void:
	if not _active:
		return
	_active = false
	visible = false
	_stop_ambience()
	if cancelled:
		repair_cancelled.emit()


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("ui_cancel"):
		close_repair(true)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var key_event = event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		var consumed := false
		match key_event.physical_keycode:
			KEY_W, KEY_UP:
				_try_move_forward()
				consumed = true
			KEY_A, KEY_LEFT:
				_try_move_turn(-1)
				consumed = true
			KEY_D, KEY_RIGHT:
				_try_move_turn(1)
				consumed = true
			KEY_F:
				_toggle_flashlight()
				consumed = true
			_:
				consumed = false
		if consumed:
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _active:
		return
	_update_player_motion(delta)
	_update_camera_pose(delta)


func _build_shell() -> void:
	_root = Control.new()
	_root.name = "SewerPipeRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	_viewport_container = SubViewportContainer.new()
	_viewport_container.name = "SewerPipeViewportContainer"
	_viewport_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewport_container.stretch = true
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_viewport_container)

	_viewport = SubViewport.new()
	_viewport.name = "SewerPipeViewport"
	_viewport.own_world_3d = true
	_viewport.size = INTERIOR_RENDER_MIN_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_viewport.handle_input_locally = false
	_viewport_container.add_child(_viewport)

	_world_root = Node3D.new()
	_world_root.name = "PipeWorld"
	_viewport.add_child(_world_root)

	var world_env = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.01, 0.01)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.09, 0.10, 0.11)
	env.ambient_light_energy = 0.14
	env.fog_enabled = true
	env.fog_density = 0.03
	env.fog_light_energy = 0.10
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.0
	world_env.environment = env
	_world_root.add_child(world_env)

	_setup_pipe_materials()
	_build_player_rig()
	_build_audio()


func _setup_pipe_materials() -> void:
	_pipe_inner_material = StandardMaterial3D.new()
	_pipe_inner_material.albedo_color = Color(0.17, 0.19, 0.19, 1.0)
	_pipe_inner_material.roughness = 0.96
	_pipe_inner_material.metallic = 0.02
	_pipe_inner_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_pipe_inner_material.cull_mode = BaseMaterial3D.CULL_FRONT


func _build_player_rig() -> void:
	_player_rig = Node3D.new()
	_player_rig.name = "PlayerRig"
	_world_root.add_child(_player_rig)

	_camera = Camera3D.new()
	_camera.name = "PipeCamera"
	_camera.current = true
	_camera.fov = PLAYER_FOV
	_camera.near = 0.03
	_camera.far = 45.0
	_player_rig.add_child(_camera)

	_flashlight = SpotLight3D.new()
	_flashlight.name = "Flashlight"
	_flashlight.position = Vector3(0.0, 0.0, 0.10)
	_flashlight.rotation_degrees = Vector3(-1.1, 0.0, 0.0)
	_flashlight.light_color = Color(0.95, 0.92, 0.78)
	_flashlight.light_energy = FLASHLIGHT_BASE_ENERGY
	_flashlight.spot_range = 10.5
	_flashlight.spot_angle = 44.0
	_flashlight.spot_angle_attenuation = 0.80
	_flashlight.shadow_enabled = true
	_camera.add_child(_flashlight)


func _build_audio() -> void:
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.name = "PipeAmbience"
	_ambience_player.bus = "Master"
	_ambience_player.volume_db = -8.0
	var stream = load(PIPE_AMBIENCE_PATH) as AudioStream
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_ambience_player.stream = stream
	add_child(_ambience_player)


func _build_network() -> void:
	if _pipe_geo_root != null and is_instance_valid(_pipe_geo_root):
		_pipe_geo_root.queue_free()
	_pipe_geo_root = Node3D.new()
	_pipe_geo_root.name = "PipeGeometry"
	_world_root.add_child(_pipe_geo_root)

	_node_world.clear()
	for node_id in NODE_LAYOUT.keys():
		var cell = NODE_LAYOUT[node_id] as Vector2i
		_node_world[node_id] = Vector3(float(cell.x) * CELL_WORLD_SIZE, PIPE_CENTER_Y, float(cell.y) * CELL_WORLD_SIZE)
		_add_junction_cavity(str(node_id))
		_add_junction_light(str(node_id))

	var seen: Dictionary = {}
	for node_id in NODE_LINKS.keys():
		var links = NODE_LINKS[node_id] as Dictionary
		for dir_id in links.keys():
			var next_id = str(links[dir_id])
			var edge = _edge_key(str(node_id), next_id)
			if seen.has(edge):
				continue
			seen[edge] = true
			_add_tunnel_segment(str(node_id), next_id)


func _add_junction_cavity(node_id: String) -> void:
	if not _node_world.has(node_id) or _pipe_geo_root == null:
		return
	var center = _node_world[node_id] as Vector3
	var links = NODE_LINKS.get(node_id, {}) as Dictionary
	for dir_id in links.keys():
		var dir_vec = DIR_TO_WORLD.get(int(dir_id), Vector3.ZERO) as Vector3
		if dir_vec == Vector3.ZERO:
			continue
		_add_open_tube(
			center,
			center + (dir_vec * JUNCTION_ARM_LENGTH),
			JUNCTION_ARM_RADIUS,
			"JunctionArm_%s_%d" % [node_id, int(dir_id)]
		)


func _add_junction_light(node_id: String) -> void:
	var links = NODE_LINKS.get(node_id, {}) as Dictionary
	if links.size() < 3:
		return
	if not _node_world.has(node_id):
		return
	var lamp = OmniLight3D.new()
	lamp.name = "JunctionLight_%s" % node_id
	lamp.position = _node_world[node_id] as Vector3
	lamp.light_color = Color(0.42, 0.47, 0.44)
	lamp.light_energy = JUNCTION_LIGHT_ENERGY
	lamp.omni_range = 4.2
	lamp.shadow_enabled = false
	_world_root.add_child(lamp)


func _add_tunnel_segment(from_id: String, to_id: String) -> void:
	if not _node_world.has(from_id) or not _node_world.has(to_id) or _pipe_geo_root == null:
		return
	var a = _node_world[from_id] as Vector3
	var b = _node_world[to_id] as Vector3
	var delta = b - a
	var axis_is_x = absf(delta.x) > absf(delta.z)
	var dir = Vector3.ZERO
	if axis_is_x:
		dir = Vector3(signf(delta.x), 0.0, 0.0)
	else:
		dir = Vector3(0.0, 0.0, signf(delta.z))
	if dir == Vector3.ZERO:
		return

	var trim = JUNCTION_ARM_LENGTH - JUNCTION_JOIN_OVERLAP
	var start = a + (dir * trim)
	var end = b - (dir * trim)
	_add_open_tube(start, end, PIPE_RADIUS, "Tunnel_%s_%s" % [from_id, to_id])


func _add_open_tube(from_pos: Vector3, to_pos: Vector3, radius: float, node_name: String) -> void:
	var delta = to_pos - from_pos
	var run = delta.length()
	if run <= 0.01:
		return
	var axis_is_x = absf(delta.x) > absf(delta.z)
	var tube = MeshInstance3D.new()
	tube.name = node_name
	var cyl = CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = run
	cyl.radial_segments = PIPE_RADIAL_SEGMENTS
	cyl.rings = PIPE_RINGS
	cyl.cap_top = false
	cyl.cap_bottom = false
	tube.mesh = cyl
	tube.position = (from_pos + to_pos) * 0.5
	_apply_tunnel_axis_rotation(tube, axis_is_x)
	if _pipe_inner_material != null:
		tube.material_override = _pipe_inner_material
	_pipe_geo_root.add_child(tube)


func _apply_tunnel_axis_rotation(node: Node3D, axis_is_x: bool) -> void:
	if axis_is_x:
		node.rotation = Vector3(0.0, 0.0, PI * 0.5)
	else:
		node.rotation = Vector3(PI * 0.5, 0.0, 0.0)


func _edge_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]


func _reset_player_state() -> void:
	_player_node = PLAYER_START_NODE
	_player_from_node = PLAYER_START_NODE
	_player_to_node = PLAYER_START_NODE
	_player_facing = PLAYER_START_FACING
	_player_moving = false
	_player_move_t = 0.0
	_headbob_t = 0.0
	_flashlight_on = true
	if _flashlight != null:
		_flashlight.visible = true
	_update_camera_pose(0.0)


func _try_move_forward() -> void:
	if _player_moving:
		return
	var next_id = _neighbor_for_direction(_player_node, _player_facing)
	if next_id == "":
		return
	_begin_move(next_id, _player_facing)


func _try_move_turn(turn_dir: int) -> void:
	if _player_moving:
		return
	var target_facing = wrapi(_player_facing + turn_dir, 0, 4)
	var next_id = _neighbor_for_direction(_player_node, target_facing)
	if next_id == "":
		return
	_begin_move(next_id, target_facing)


func _begin_move(next_id: String, facing_after_move: int) -> void:
	_player_from_node = _player_node
	_player_to_node = next_id
	_player_facing = facing_after_move
	_player_move_t = 0.0
	_player_moving = true


func _neighbor_for_direction(node_id: String, direction: int) -> String:
	var links = NODE_LINKS.get(node_id, {}) as Dictionary
	if not links.has(direction):
		return ""
	return str(links[direction])


func _update_player_motion(delta: float) -> void:
	if not _player_moving:
		return
	_player_move_t = minf(1.0, _player_move_t + (max(delta, 0.0) / MOVE_SECONDS))
	if _player_move_t >= 1.0:
		var travel_facing = _player_facing
		_player_node = _player_to_node
		_player_from_node = _player_node
		_player_facing = _resolve_facing_after_arrival(_player_node, travel_facing)
		_player_moving = false
		_player_move_t = 0.0


func _player_world_position() -> Vector3:
	if _player_moving:
		var a = _node_world.get(_player_from_node, Vector3.ZERO) as Vector3
		var b = _node_world.get(_player_to_node, a) as Vector3
		var t = _player_move_t * _player_move_t * (3.0 - 2.0 * _player_move_t)
		return a.lerp(b, t)
	var base = _node_world.get(_player_node, Vector3.ZERO) as Vector3
	if _node_has_visible_branch(_player_node, _player_facing):
		var back_dir = wrapi(_player_facing + 2, 0, 4)
		if _neighbor_for_direction(_player_node, back_dir) != "":
			var back_vec = DIR_TO_WORLD.get(back_dir, Vector3.ZERO) as Vector3
			base += back_vec * JUNCTION_VIEW_BACK_OFFSET
	return base


func _node_has_visible_branch(node_id: String, facing: int) -> bool:
	var left_dir = wrapi(facing - 1, 0, 4)
	var right_dir = wrapi(facing + 1, 0, 4)
	return _neighbor_for_direction(node_id, left_dir) != "" or _neighbor_for_direction(node_id, right_dir) != ""


func _resolve_facing_after_arrival(node_id: String, travel_facing: int) -> int:
	var links = NODE_LINKS.get(node_id, {}) as Dictionary
	if links.has(travel_facing):
		return travel_facing
	var right_dir = wrapi(travel_facing + 1, 0, 4)
	if links.has(right_dir):
		return right_dir
	var left_dir = wrapi(travel_facing - 1, 0, 4)
	if links.has(left_dir):
		return left_dir
	var back_dir = wrapi(travel_facing + 2, 0, 4)
	if links.has(back_dir):
		return back_dir
	return travel_facing


func _update_camera_pose(delta: float) -> void:
	if _player_rig == null or _camera == null:
		return
	_player_rig.position = _player_world_position()
	var target_yaw = float(DIR_TO_YAW.get(_player_facing, 0.0))
	_player_rig.rotation.y = target_yaw

	var bob_strength = 0.019 if _player_moving else 0.006
	var bob_speed = 9.3 if _player_moving else 2.2
	_headbob_t += max(delta, 0.0) * bob_speed
	_camera.position = Vector3(0.0, sin(_headbob_t) * bob_strength, 0.0)

	if _flashlight != null:
		var pulse = 1.0 + (sin(_headbob_t * 0.6) * 0.05)
		_flashlight.light_energy = FLASHLIGHT_BASE_ENERGY * pulse


func _toggle_flashlight() -> void:
	_flashlight_on = not _flashlight_on
	if _flashlight != null:
		_flashlight.visible = _flashlight_on


func _play_ambience() -> void:
	if _ambience_player == null:
		return
	if _ambience_player.stream == null:
		return
	if not _ambience_player.playing:
		_ambience_player.play()


func _stop_ambience() -> void:
	if _ambience_player == null:
		return
	if _ambience_player.playing:
		_ambience_player.stop()
