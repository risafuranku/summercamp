extends "res://scripts/enemies/i_enemy_brain.gd"
class_name SilentManBrain

const STATE_HAUNTING := 0
const STATE_PRESSURE := 1
const STATE_ATTACK_WINDOW := 2
const STATE_COOLDOWN := 3

const SHUST1_PATH := "res://assets/sfx/shust.mp3"
const SHUST2_PATH := "res://assets/sfx/shust2.mp3"
const DISTRACT_A_PATH := "res://assets/sfx/npc/silentdistract1.mp3"
const DISTRACT_B_PATH := "res://assets/sfx/npc/silentdistract2.mp3"

const HATTER_SPRITE := "res://assets/textury/npc/hrot1.png"
## Chance that a presence cue also shows him: standing where the sound came from,
## gone the moment you turn to look (or after a couple of seconds).
const PEEK_CHANCE := 0.4
const PEEK_SECONDS := 2.4

const TELEPORT_DESPAWN_THRESHOLD: float = 45.0
const MAX_AUDIO_EVENTS: int = 48

const FLASHLIGHT_BLINK_MIN_SEC: float = 0.05
const FLASHLIGHT_BLINK_MAX_SEC: float = 0.12

const CUE_REACTION_WINDOW: float = 1.05
const CUE_REACTION_YAW_DEG: float = 22.0
const CUE_REACTION_MOVE_METERS: float = 0.48

var _world_root: Node3D
var _player: CharacterBody3D
var _grid_manager: Node
var _building_manager: Node
var _audio_manager: Node
var _damage_callable: Callable
var _is_night_callable: Callable
var _allow_actions_callable: Callable
var _night_entry: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var _night_active: bool = false
var _elapsed: float = 0.0
var _difficulty: int = 1

var state: int = STATE_HAUNTING
var last_state_change_time: float = 0.0
var last_trick_time: float = -9999.0
var successful_scares: int = 0
var scare_timestamps: Array[float] = []
var player_is_looking: bool = false
var active_entity: Node3D
var active_entity_visible: bool = false
var close_peek_cooldown: float = 0.0
var attack_active: bool = false
var attack_start_time: float = 0.0

var _state_deadline: float = 0.0
var _next_presence_cue_time: float = 0.0
var _next_attack_cue_time: float = 0.0

var _threat_meter: float = 0.0
var _threat_to_attack_threshold: float = 4.0
var _attack_progress: float = 0.0
var _attack_commit_seconds: float = 1.4
var _damage_per_hit: int = 16

var _cue_watch_active: bool = false
var _cue_watch_start_time: float = 0.0
var _cue_watch_start_yaw: float = 0.0
var _cue_watch_start_pos: Vector3 = Vector3.ZERO

var _player_recent_speed: float = 0.0
var _player_recent_yaw_speed: float = 0.0
var _last_player_yaw: float = 0.0
var _last_player_position: Vector3 = Vector3.ZERO
var _last_player_position_valid: bool = false

var _flashlight_forced_off_until: float = 0.0
var _flashlight_restore_pending: bool = false

var _audio_root: Node3D
var _body: Sprite3D
var _peek_until: float = 0.0
var _peek_seen_at: float = -1.0
var _scheduled_audio_events: Array[Dictionary] = []
var _shust_stream_1: AudioStream
var _shust_stream_2: AudioStream
var _distract_stream_a: AudioStream
var _distract_stream_b: AudioStream

var _footstep_bursts: int = 0
var _visual_spawns: int = 0
var _close_peeks: int = 0
var _damage_hits: int = 0
var _attack_windows_started: int = 0


func get_enemy_id() -> String:
	return "silent_man"


func start_night(seed: int, difficulty: int, references: Dictionary) -> void:
	stop_night()
	_resolve_references(references)
	if _world_root == null or _player == null:
		return

	_difficulty = clampi(difficulty, 1, 5)
	_rng.seed = int(seed) if seed != 0 else int(Time.get_unix_time_from_system())
	if seed == 0:
		_rng.randomize()
	_load_resources()
	_ensure_audio_root()
	_ensure_body()
	_apply_difficulty_scaling()

	_night_active = true
	_elapsed = 0.0
	_reset_runtime_state()
	_enter_state(STATE_HAUNTING)

	_last_player_position = _player.global_position
	_last_player_yaw = _player.global_rotation.y
	_last_player_position_valid = true


func tick(delta: float) -> void:
	if not _night_active:
		return

	var dt = maxf(delta, 0.0)
	_elapsed += dt
	_update_flashlight_gate()
	_process_scheduled_audio_events()

	if not _is_runtime_context_ready():
		return

	_detect_player_teleport()
	_track_player_motion(dt)
	_cleanup_scare_timestamps()
	active_entity_visible = false
	player_is_looking = false

	_update_peek()
	match state:
		STATE_HAUNTING:
			_tick_haunting(dt)
		STATE_PRESSURE:
			_enter_state(STATE_ATTACK_WINDOW)
		STATE_ATTACK_WINDOW:
			_tick_attack(dt)
		STATE_COOLDOWN:
			_tick_cooldown(dt)


func stop_night() -> void:
	if _flashlight_restore_pending:
		_restore_flashlight_if_possible()
	_night_active = false
	_scheduled_audio_events.clear()
	if _audio_root != null and is_instance_valid(_audio_root):
		_audio_root.queue_free()
	_audio_root = null


func get_debug_snapshot() -> Dictionary:
	return {
		"state": _state_name(state),
		"successful_scares": successful_scares,
		"recent_successes": scare_timestamps.size(),
		"entity_active": false,
		"entity_visible": false,
		"close_peeks": _close_peeks,
		"footstep_bursts": _footstep_bursts,
		"visual_spawns": _visual_spawns,
		"damage_hits": _damage_hits,
		"attack_windows_started": _attack_windows_started,
		"threat_meter": _threat_meter,
	}


func _resolve_references(references: Dictionary) -> void:
	_world_root = references.get("world_root", null) as Node3D
	_player = references.get("player", null) as CharacterBody3D
	_grid_manager = references.get("grid_manager", null) as Node
	_building_manager = references.get("building_manager", null) as Node
	_audio_manager = references.get("audio_manager", null) as Node
	_damage_callable = references.get("damage_callable", Callable()) as Callable
	_is_night_callable = references.get("is_night_callable", Callable()) as Callable
	_allow_actions_callable = references.get("allow_actions_callable", Callable()) as Callable
	var night_entry_any: Variant = references.get("night_entry", {})
	if night_entry_any is Dictionary:
		_night_entry = (night_entry_any as Dictionary).duplicate(true)
	else:
		_night_entry = {}


func _load_resources() -> void:
	_shust_stream_1 = load(SHUST1_PATH) as AudioStream
	_shust_stream_2 = load(SHUST2_PATH) as AudioStream
	_distract_stream_a = load(DISTRACT_A_PATH) as AudioStream
	_distract_stream_b = load(DISTRACT_B_PATH) as AudioStream


func _ensure_audio_root() -> void:
	if _world_root == null:
		return
	if _audio_root != null and is_instance_valid(_audio_root):
		return
	_audio_root = Node3D.new()
	_audio_root.name = "SilentManAudioRoot"
	_world_root.add_child(_audio_root)


func _apply_difficulty_scaling() -> void:
	var t = clampf(float(_difficulty - 1) / 4.0, 0.0, 1.0)
	_threat_to_attack_threshold = lerpf(4.7, 2.8, t)
	_attack_commit_seconds = lerpf(1.55, 0.82, t)
	_damage_per_hit = int(round(lerpf(14.0, 24.0, t)))


func _reset_runtime_state() -> void:
	successful_scares = 0
	scare_timestamps.clear()
	active_entity = null
	active_entity_visible = false
	player_is_looking = false
	close_peek_cooldown = 0.0
	attack_active = false
	attack_start_time = 0.0
	last_state_change_time = 0.0
	last_trick_time = -9999.0
	_state_deadline = 0.0
	_next_presence_cue_time = 0.0
	_next_attack_cue_time = 0.0
	_threat_meter = 0.0
	_attack_progress = 0.0
	_cue_watch_active = false
	_cue_watch_start_time = 0.0
	_cue_watch_start_yaw = 0.0
	_cue_watch_start_pos = Vector3.ZERO
	_player_recent_speed = 0.0
	_player_recent_yaw_speed = 0.0
	_flashlight_forced_off_until = 0.0
	_flashlight_restore_pending = false
	_footstep_bursts = 0
	_visual_spawns = 0
	_close_peeks = 0
	_damage_hits = 0
	_attack_windows_started = 0


func _state_name(state_id: int) -> String:
	match state_id:
		STATE_HAUNTING:
			return "HAUNTING"
		STATE_PRESSURE:
			return "PRESSURE"
		STATE_ATTACK_WINDOW:
			return "ATTACK_WINDOW"
		STATE_COOLDOWN:
			return "COOLDOWN"
		_:
			return "UNKNOWN"


func _is_runtime_context_ready() -> bool:
	if _world_root == null or not is_instance_valid(_world_root):
		return false
	if _player == null or not is_instance_valid(_player):
		return false
	if _is_night_callable.is_valid() and not bool(_is_night_callable.call()):
		return false
	if _allow_actions_callable.is_valid() and not bool(_allow_actions_callable.call()):
		return false
	return true


func _enter_state(new_state: int) -> void:
	if new_state == STATE_PRESSURE:
		new_state = STATE_ATTACK_WINDOW
	state = new_state
	last_state_change_time = _elapsed
	last_trick_time = _elapsed

	match state:
		STATE_HAUNTING:
			attack_active = false
			_attack_progress = 0.0
			_cue_watch_active = false
			_state_deadline = 0.0
			_next_presence_cue_time = _elapsed + _rng.randf_range(0.35, 1.25)
		STATE_ATTACK_WINDOW:
			_attack_windows_started += 1
			attack_active = true
			attack_start_time = _elapsed
			_attack_progress = 0.0
			_state_deadline = _elapsed + _rng.randf_range(10.0, 16.0)
			_next_attack_cue_time = _elapsed + _rng.randf_range(0.20, 0.65)
		STATE_COOLDOWN:
			attack_active = false
			_attack_progress = 0.0
			_cue_watch_active = false
			_state_deadline = _elapsed + _rng.randf_range(6.0, 10.0)


func _tick_haunting(delta: float) -> void:
	if _elapsed >= _next_presence_cue_time:
		_emit_presence_cue()
		_next_presence_cue_time = _elapsed + _rng.randf_range(1.7, 3.7)

	_update_cue_reaction()

	var light = _get_player_light_level()
	if light < 0.35:
		_threat_meter += delta * 0.45
	else:
		_threat_meter += delta * 0.18

	if _player_recent_yaw_speed > 26.0:
		_threat_meter = maxf(0.0, _threat_meter - delta * 0.32)

	if _threat_meter >= _threat_to_attack_threshold:
		successful_scares += 1
		scare_timestamps.append(_elapsed)
		_enter_state(STATE_ATTACK_WINDOW)


func _tick_attack(delta: float) -> void:
	if _elapsed >= _state_deadline:
		_enter_state(STATE_COOLDOWN)
		return

	if _elapsed >= _next_attack_cue_time:
		_emit_attack_cue()
		_next_attack_cue_time = _elapsed + _rng.randf_range(0.9, 1.8)

	var light = _get_player_light_level()
	var has_flashlight = _is_player_flashlight_on()
	var pressure_gain = 0.0
	if not has_flashlight:
		pressure_gain += 1.05
	elif light < 0.25:
		pressure_gain += 0.86
	else:
		pressure_gain += 0.45

	if _player_recent_speed < 0.08 and _player_recent_yaw_speed < 9.0:
		pressure_gain += 0.52
	else:
		pressure_gain -= 0.18

	_attack_progress = clampf(_attack_progress + (delta * pressure_gain), 0.0, _attack_commit_seconds + 0.8)
	if _attack_progress >= _attack_commit_seconds:
		_perform_attack()


func _tick_cooldown(delta: float) -> void:
	_threat_meter = maxf(0.0, _threat_meter - (delta * 0.9))
	if _elapsed >= _state_deadline:
		_enter_state(STATE_HAUNTING)


func _update_cue_reaction() -> void:
	if not _cue_watch_active:
		return
	if (_elapsed - _cue_watch_start_time) < CUE_REACTION_WINDOW:
		return

	var yaw_delta = absf(rad_to_deg(_shortest_angle(_player.global_rotation.y - _cue_watch_start_yaw)))
	var moved = _player.global_position.distance_to(_cue_watch_start_pos)
	var reacted = yaw_delta >= CUE_REACTION_YAW_DEG or moved >= CUE_REACTION_MOVE_METERS
	if reacted:
		_threat_meter = maxf(0.0, _threat_meter - 0.72)
	else:
		_threat_meter += 0.88
	_cue_watch_active = false


func _emit_presence_cue() -> void:
	var stream = _pick_presence_stream()
	if stream == null:
		return
	_apply_flashlight_blink(_rng.randf_range(FLASHLIGHT_BLINK_MIN_SEC, FLASHLIGHT_BLINK_MAX_SEC))
	var pos = _position_around_player(4.2, 8.2, true)
	_play_3d_stream(stream, pos + Vector3(0.0, 1.0, 0.0), -6.2, _rng.randf_range(0.95, 1.05))
	_footstep_bursts += 1
	if _rng.randf() < PEEK_CHANCE:
		_show_peek(pos)
	_visual_spawns += 1
	_cue_watch_active = true
	_cue_watch_start_time = _elapsed
	_cue_watch_start_yaw = _player.global_rotation.y
	_cue_watch_start_pos = _player.global_position


func _ensure_body() -> void:
	if _body != null and is_instance_valid(_body):
		return
	_body = Sprite3D.new()
	_body.texture = load(HATTER_SPRITE) as Texture2D
	_body.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_body.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_body.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_body.shaded = true
	if _body.texture != null:
		_body.pixel_size = 1.85 / float(_body.texture.get_height())
		_body.offset = Vector2(0.0, float(_body.texture.get_height()) * 0.5)
	_body.visible = false
	_audio_root.add_child(_body)


func _show_peek(pos: Vector3) -> void:
	if _body == null or not is_instance_valid(_body) or not _is_valid_world_point(pos):
		return
	_body.global_position = pos
	_body.visible = true
	_peek_until = _elapsed + PEEK_SECONDS
	_peek_seen_at = -1.0


## The peek ends a beat after the player's eyes land on him: long enough to register
## that something was there, never long enough to be sure what.
func _update_peek() -> void:
	if _body == null or not is_instance_valid(_body) or not _body.visible:
		return
	if _elapsed >= _peek_until:
		_body.visible = false
		return
	if _is_world_point_visible_to_player(_body.global_position + Vector3(0.0, 1.4, 0.0), 0.0):
		if _peek_seen_at < 0.0:
			_peek_seen_at = _elapsed
			_threat_meter = maxf(0.0, _threat_meter - 0.4)
		elif _elapsed - _peek_seen_at > 0.22:
			_body.visible = false


func _emit_attack_cue() -> void:
	var stream = _pick_attack_stream()
	if stream == null:
		return
	var pos = _position_around_player(2.0, 4.6, false)
	_play_3d_stream(stream, pos + Vector3(0.0, 1.0, 0.0), -4.8, _rng.randf_range(0.96, 1.06))
	_footstep_bursts += 1


func _pick_presence_stream() -> AudioStream:
	var roll = _rng.randf()
	if roll < 0.46:
		return _distract_stream_a
	if roll < 0.82:
		return _distract_stream_b
	if roll < 0.92:
		return _shust_stream_1
	return _shust_stream_2


func _pick_attack_stream() -> AudioStream:
	var roll = _rng.randf()
	if roll < 0.38:
		return _shust_stream_2
	if roll < 0.72:
		return _distract_stream_b
	if roll < 0.90:
		return _distract_stream_a
	return _shust_stream_1


func _perform_attack() -> void:
	if _damage_callable.is_valid():
		_damage_callable.call(_damage_per_hit)
	_damage_hits += 1
	_enter_state(STATE_COOLDOWN)


func _track_player_motion(delta: float) -> void:
	if _player == null:
		return
	var dt = maxf(delta, 0.001)
	var pos = _player.global_position
	var yaw = _player.global_rotation.y
	if not _last_player_position_valid:
		_last_player_position = pos
		_last_player_yaw = yaw
		_last_player_position_valid = true
		_player_recent_speed = 0.0
		_player_recent_yaw_speed = 0.0
		return
	var planar_delta = Vector2(pos.x - _last_player_position.x, pos.z - _last_player_position.z).length()
	_player_recent_speed = planar_delta / dt
	var yaw_delta = absf(rad_to_deg(_shortest_angle(yaw - _last_player_yaw)))
	_player_recent_yaw_speed = yaw_delta / dt
	_last_player_position = pos
	_last_player_yaw = yaw


func _position_around_player(min_dist: float, max_dist: float, prefer_behind: bool) -> Vector3:
	if _player == null:
		return Vector3.ZERO
	var fwd = _player_forward_flat()
	var right = _player_right_flat()
	var dir = fwd
	if prefer_behind:
		var behind_angle = deg_to_rad(180.0 + _rng.randf_range(-58.0, 58.0))
		dir = fwd.rotated(Vector3.UP, behind_angle)
	else:
		var side_angle = deg_to_rad(_rng.randf_range(-120.0, 120.0))
		dir = fwd.rotated(Vector3.UP, side_angle)
	var side_jitter = right * _rng.randf_range(-0.8, 0.8)
	var raw = _player.global_position + ((dir.normalized() + side_jitter).normalized() * _rng.randf_range(min_dist, max_dist))
	var projected = _project_to_ground(raw)
	if _is_valid_world_point(projected):
		return projected
	return raw


func _project_to_ground(candidate: Vector3) -> Vector3:
	if _world_root == null or _world_root.get_world_3d() == null:
		return candidate
	var from = candidate + Vector3(0.0, 20.0, 0.0)
	var to = candidate + Vector3(0.0, -30.0, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var exclude: Array = []
	if _player != null and is_instance_valid(_player):
		exclude.append(_player.get_rid())
	query.exclude = exclude
	var hit = _world_root.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector3.INF
	var hit_pos_any: Variant = hit.get("position", null)
	if hit_pos_any is Vector3:
		return hit_pos_any as Vector3
	return Vector3.INF


func _is_world_point_visible_to_player(world_point: Vector3, fov_margin_deg: float) -> bool:
	var camera = _get_player_camera()
	if camera == null:
		return false
	var to_point = world_point - camera.global_position
	var distance = to_point.length()
	if distance <= 0.001:
		return true
	var dir = to_point / distance
	var camera_forward = (-camera.global_transform.basis.z).normalized()
	var half_fov = _camera_half_fov_deg() + fov_margin_deg
	var cos_threshold = cos(deg_to_rad(maxf(1.0, half_fov)))
	if camera_forward.dot(dir) < cos_threshold:
		return false

	if _world_root == null or _world_root.get_world_3d() == null:
		return true
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, world_point)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var exclude: Array = []
	if _player != null and is_instance_valid(_player):
		exclude.append(_player.get_rid())
	query.exclude = exclude
	var hit = _world_root.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	return false


func _get_player_light_level() -> float:
	if _player == null:
		return 0.0
	var sample = _player.global_position + Vector3(0.0, 1.2, 0.0)
	if _building_manager != null and _building_manager.has_method("get_light_level_at"):
		var level_any: Variant = _building_manager.call("get_light_level_at", sample)
		return clampf(float(level_any), 0.0, 1.0)
	return 0.0


func _is_player_flashlight_on() -> bool:
	if _player == null or not _player.has_method("is_flashlight_active"):
		return false
	var active_any: Variant = _player.call("is_flashlight_active")
	return bool(active_any)


func _apply_flashlight_blink(duration: float) -> void:
	if _player == null or not _player.has_method("set_flashlight_allowed"):
		return
	_flashlight_forced_off_until = maxf(_flashlight_forced_off_until, _elapsed + maxf(duration, 0.05))
	_flashlight_restore_pending = true
	_player.call("set_flashlight_allowed", false)


func _update_flashlight_gate() -> void:
	if not _flashlight_restore_pending:
		return
	if _player == null or not _player.has_method("set_flashlight_allowed"):
		_flashlight_restore_pending = false
		return
	if _elapsed < _flashlight_forced_off_until:
		_player.call("set_flashlight_allowed", false)
		return
	_restore_flashlight_if_possible()


func _restore_flashlight_if_possible() -> void:
	if _player != null and _player.has_method("set_flashlight_allowed"):
		var can_restore = true
		if _is_night_callable.is_valid():
			can_restore = bool(_is_night_callable.call())
		if can_restore:
			_player.call("set_flashlight_allowed", true)
	_flashlight_restore_pending = false


func _cleanup_scare_timestamps() -> void:
	var cutoff = _elapsed - 60.0
	while not scare_timestamps.is_empty() and scare_timestamps[0] < cutoff:
		scare_timestamps.remove_at(0)


func _detect_player_teleport() -> void:
	if _player == null:
		return
	var now_pos = _player.global_position
	if _last_player_position_valid and now_pos.distance_to(_last_player_position) >= TELEPORT_DESPAWN_THRESHOLD:
		_cue_watch_active = false
		_threat_meter = maxf(0.0, _threat_meter - 0.6)
	_last_player_position = now_pos
	_last_player_position_valid = true


func _player_forward_flat() -> Vector3:
	var camera = _get_player_camera()
	var forward = -_player.global_transform.basis.z
	if camera != null:
		forward = -camera.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return Vector3(0.0, 0.0, -1.0)
	return forward.normalized()


func _player_right_flat() -> Vector3:
	var right = _player_forward_flat().cross(Vector3.UP)
	if right.length_squared() < 0.0001:
		return Vector3(1.0, 0.0, 0.0)
	return right.normalized()


func _camera_half_fov_deg() -> float:
	var cam = _get_player_camera()
	if cam == null:
		return 44.0
	return maxf(8.0, cam.fov * 0.5)


func _get_player_camera() -> Camera3D:
	if _player == null:
		return null
	return _player.get_node_or_null("Head/Camera3D") as Camera3D


func _shortest_angle(value: float) -> float:
	return wrapf(value, -PI, PI)


func _is_valid_world_point(point: Vector3) -> bool:
	if is_nan(point.x) or is_nan(point.y) or is_nan(point.z):
		return false
	if is_inf(point.x) or is_inf(point.y) or is_inf(point.z):
		return false
	return true


func _schedule_audio_event(time_point: float, stream: AudioStream, world_pos: Vector3, volume_db: float, pitch_scale: float) -> void:
	if stream == null:
		return
	if _scheduled_audio_events.size() >= MAX_AUDIO_EVENTS:
		_scheduled_audio_events.remove_at(0)
	_scheduled_audio_events.append({
		"time": time_point,
		"stream": stream,
		"position": world_pos,
		"volume_db": volume_db,
		"pitch": pitch_scale,
	})


func _process_scheduled_audio_events() -> void:
	if _scheduled_audio_events.is_empty():
		return
	for i in range(_scheduled_audio_events.size() - 1, -1, -1):
		var event = _scheduled_audio_events[i]
		var trigger_time = float(event.get("time", 0.0))
		if _elapsed < trigger_time:
			continue
		var stream = event.get("stream", null) as AudioStream
		var pos_any: Variant = event.get("position", null)
		var pos = _player.global_position if _player != null else Vector3.ZERO
		if pos_any is Vector3:
			pos = pos_any as Vector3
		var vol = float(event.get("volume_db", -12.0))
		var pitch = clampf(float(event.get("pitch", 1.0)), 0.7, 1.6)
		_play_3d_stream(stream, pos, vol, pitch)
		_scheduled_audio_events.remove_at(i)


func _play_3d_stream(stream: AudioStream, world_pos: Vector3, volume_db: float, pitch_scale: float) -> void:
	if stream == null:
		return
	var parent: Node = _audio_root if _audio_root != null and is_instance_valid(_audio_root) else _world_root
	if parent == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.max_distance = 34.0
	player.unit_size = 2.0
	player.bus = "Master"
	parent.add_child(player)
	player.global_position = world_pos
	player.play()
	var length = maxf(0.4, stream.get_length() / maxf(pitch_scale, 0.05))
	var tree = parent.get_tree()
	if tree == null:
		return
	var cleanup_timer = tree.create_timer(length + 0.22)
	cleanup_timer.timeout.connect(func():
		if is_instance_valid(player):
			player.queue_free()
	)
