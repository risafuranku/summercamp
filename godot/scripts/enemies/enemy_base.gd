extends "res://scripts/enemies/i_enemy_brain.gd"

## Shared plumbing for night enemies: references from main.gd, the player's view and
## light, ground projection, a billboard body, positional sounds. Each archetype brain
## extends this and implements `_on_start()` and `_on_tick(dt)`.
##
## Rules every enemy keeps (DESIGN.md "Rules of the scare"):
## - it is forecast before it is encountered (night risk, a feed line on first sign);
## - it is avoidable by paying attention: each one has a readable tell and a counter;
## - bodies are lit by the scene (shaded sprites): in the dark they exist only where
##   the flashlight or a lamp touches them.

var _world_root: Node3D
var _player: CharacterBody3D
var _grid_manager: Node
var _building_manager: Node
var _damage_callable: Callable
var _is_night_callable: Callable
var _allow_actions_callable: Callable
var _notify_callable: Callable
var _night_entry: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var _night_active: bool = false
var _elapsed: float = 0.0
var _difficulty: int = 1
var _root: Node3D
var _body: Sprite3D
var _announced: bool = false
var _cue_pos: Vector3 = Vector3.INF
var _cue_time: float = -999.0

## How long the place of a sound stays "sensed" after the sound.
const CUE_MEMORY_SECONDS := 4.0


func start_night(seed: int, difficulty: int, references: Dictionary) -> void:
	stop_night()
	_world_root = references.get("world_root", null) as Node3D
	_player = references.get("player", null) as CharacterBody3D
	_grid_manager = references.get("grid_manager", null) as Node
	_building_manager = references.get("building_manager", null) as Node
	_damage_callable = references.get("damage_callable", Callable()) as Callable
	_is_night_callable = references.get("is_night_callable", Callable()) as Callable
	_allow_actions_callable = references.get("allow_actions_callable", Callable()) as Callable
	_notify_callable = references.get("notify_callable", Callable()) as Callable
	var entry_any = references.get("night_entry", {})
	_night_entry = (entry_any as Dictionary).duplicate(true) if entry_any is Dictionary else {}
	if _world_root == null or _player == null:
		return
	_difficulty = clampi(difficulty, 1, 5)
	_rng.seed = seed if seed != 0 else int(Time.get_ticks_usec())
	_root = Node3D.new()
	_root.name = "Enemy_%s" % get_enemy_id()
	_world_root.add_child(_root)
	_night_active = true
	_elapsed = 0.0
	_announced = false
	_on_start()


func tick(delta: float) -> void:
	if not _night_active:
		return
	var dt := maxf(delta, 0.0)
	_elapsed += dt
	if not _is_ready():
		if _body != null:
			_body.visible = false
		return
	_on_tick(dt)


func stop_night() -> void:
	_night_active = false
	_on_stop()
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = null
	_body = null
	_cue_pos = Vector3.INF


func get_presence() -> Dictionary:
	if not _night_active:
		return {}
	if _body != null and is_instance_valid(_body) and _body.visible:
		return {"position": _body.global_position}
	if _cue_pos != Vector3.INF and _elapsed - _cue_time <= CUE_MEMORY_SECONDS:
		return {"position": _cue_pos}
	return {}


# ── overridables ──────────────────────────────────────────────────────────────

func _on_start() -> void:
	pass


func _on_tick(_dt: float) -> void:
	pass


func _on_stop() -> void:
	pass


# ── context ───────────────────────────────────────────────────────────────────

func _is_ready() -> bool:
	if _world_root == null or not is_instance_valid(_world_root):
		return false
	if _player == null or not is_instance_valid(_player) or not _player.is_inside_tree():
		return false
	if _is_night_callable.is_valid() and not bool(_is_night_callable.call()):
		return false
	if _allow_actions_callable.is_valid() and not bool(_allow_actions_callable.call()):
		return false
	return true


## One feed line the first time this enemy makes itself known each night.
func _announce(text: String) -> void:
	if _announced:
		return
	_announced = true
	if _notify_callable.is_valid():
		_notify_callable.call(text)


## A feed line every time (the outcome of an encounter, not its first sign).
func _feed(text: String) -> void:
	if _notify_callable.is_valid():
		_notify_callable.call(text)


func _hurt(amount: int) -> void:
	if _damage_callable.is_valid():
		_damage_callable.call(amount)


# ── the player ────────────────────────────────────────────────────────────────

func _camera() -> Camera3D:
	return _player.get_node_or_null("Head/Camera3D") as Camera3D if _player != null else null


func _player_pos() -> Vector3:
	return _player.global_position


func _distance_to_player(p: Vector3) -> float:
	return Vector2(p.x - _player.global_position.x, p.z - _player.global_position.z).length()


func _forward_flat() -> Vector3:
	var cam := _camera()
	var f := -(cam.global_transform.basis.z if cam != null else _player.global_transform.basis.z)
	f.y = 0.0
	return f.normalized() if f.length_squared() > 0.0001 else Vector3.FORWARD


## True when `point` is inside the camera's view cone (plus margin) with a clear line.
func _is_seen(point: Vector3, margin_deg: float = 0.0) -> bool:
	var cam := _camera()
	if cam == null:
		return false
	var to := point - cam.global_position
	var dist := to.length()
	if dist < 0.01:
		return true
	var half := cam.fov * 0.5 * 1.25 + margin_deg
	if (-cam.global_transform.basis.z).normalized().dot(to / dist) < cos(deg_to_rad(half)):
		return false
	return not _ray_blocked(cam.global_position, point)


## Lamp-post light at a point, 0..1 (BuildingManager samples the real lamps).
func _lamp_light_at(p: Vector3) -> float:
	if _building_manager != null and _building_manager.has_method("get_light_level_at"):
		return clampf(float(_building_manager.call("get_light_level_at", p + Vector3(0, 1.0, 0))), 0.0, 1.0)
	return 0.0


func _flashlight_on() -> bool:
	return _player != null and _player.has_method("is_flashlight_active") and bool(_player.call("is_flashlight_active"))


## Is `point` inside the flashlight's cone and range?
func _in_flashlight(point: Vector3) -> bool:
	if not _flashlight_on():
		return false
	var cam := _camera()
	if cam == null:
		return false
	var to := point - cam.global_position
	var dist := to.length()
	if dist > 22.0:
		return false
	return (-cam.global_transform.basis.z).normalized().dot(to / maxf(dist, 0.01)) > cos(deg_to_rad(26.0))


# ── space ─────────────────────────────────────────────────────────────────────

func _ray_blocked(from: Vector3, to: Vector3) -> bool:
	var space := _world_root.get_world_3d().direct_space_state if _world_root.get_world_3d() != null else null
	if space == null:
		return false
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collide_with_areas = false
	q.exclude = [_player.get_rid()]
	return not space.intersect_ray(q).is_empty()


## Snaps a point to the ground; Vector3.INF if there is nothing below it.
func _ground(p: Vector3) -> Vector3:
	var space := _world_root.get_world_3d().direct_space_state if _world_root.get_world_3d() != null else null
	if space == null:
		return Vector3(p.x, 0.0, p.z)
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 20, 0), p + Vector3(0, -30, 0))
	q.exclude = [_player.get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return Vector3.INF
	return hit["position"]


## A ground point at `dist` from the player in direction `angle_deg` from where the
## player looks (0 = ahead, 180 = behind), clamped into the camp bounds.
func _point_from_player(dist: float, angle_deg: float) -> Vector3:
	var dir := _forward_flat().rotated(Vector3.UP, deg_to_rad(angle_deg))
	var p := _player_pos() + dir * dist
	if _grid_manager != null and _grid_manager.has_method("get_map_size_world"):
		var c: Vector3 = _grid_manager.get_map_center_world()
		var s: Vector2 = _grid_manager.get_map_size_world()
		p.x = clampf(p.x, c.x - s.x * 0.5 + 1.0, c.x + s.x * 0.5 - 1.0)
		p.z = clampf(p.z, c.z - s.y * 0.5 + 1.0, c.z + s.y * 0.5 - 1.0)
	return _ground(p)


# ── body ──────────────────────────────────────────────────────────────────────

## Billboard sprite standing on the ground, ~`height_m` tall, lit by the scene.
func _make_body(texture_path: String, height_m: float, shaded: bool = true) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = load(texture_path) as Texture2D
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = shaded
	s.double_sided = true
	if s.texture != null:
		s.pixel_size = height_m / float(s.texture.get_height())
		s.offset = Vector2(0.0, float(s.texture.get_height()) * 0.5)
	s.visible = false
	_root.add_child(s)
	return s


func _place_body(p: Vector3) -> void:
	if _body == null or p == Vector3.INF:
		return
	_body.global_position = p
	_body.visible = true


# ── sound ─────────────────────────────────────────────────────────────────────

func _sound(path: String, at: Vector3, volume_db: float = 0.0, pitch: float = 1.0, max_dist: float = 40.0) -> AudioStreamPlayer3D:
	if _root == null or not ResourceLoader.exists(path):
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = load(path)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.max_distance = max_dist
	p.unit_size = 3.0
	_root.add_child(p)
	p.global_position = at
	p.play()
	p.finished.connect(p.queue_free)
	# A sound at the player's own position (the flash going off in your face) is not
	# a place something is; everything else is.
	if Vector2(at.x - _player.global_position.x, at.z - _player.global_position.z).length() > 1.5:
		_cue_pos = at
		_cue_time = _elapsed
	return p


## A looping positional sound that follows a node (kept by the caller).
func _loop(path: String, volume_db: float) -> AudioStreamPlayer3D:
	if _root == null or not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStream
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(stream as AudioStreamWAV).loop_end = int((stream as AudioStreamWAV).get_length() * (stream as AudioStreamWAV).mix_rate)
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.max_distance = 30.0
	p.unit_size = 3.0
	_root.add_child(p)
	p.play()
	return p
