extends CanvasLayer

## Inside the camp's bowling alley (InteriorManager module "bowling"; the hall in
## scripts/bowling/bowling_layout.gd, the lanes scripts/bowling/lane.gd): you come in by
## the door on the left and look down the hall to the lanes; a click takes you to the shoe
## counter, the snack bar, a lane (to watch from behind its bowler) or round the side into
## the pit behind the pins; S or the band at the bottom takes you back to the hall, and
## from the hall out of the door.
##
## Whoever the guest simulation has visiting the building is here: a party gets a lane
## and bowls, each in turn, real ten-pin (core/systems/bowling_rules.gd); with all four
## lanes taken they wait at a table. When their visit is over they go, and the lane
## stands empty.
##
## The pins after each ball: set up again by AUTO_SET seconds later for now (the boy in
## the pit you do not see); by hand in the pit, the hired pinsetter and the machine from
## the books come next.

signal request_close

const RETRO_RENDER = preload("res://scripts/retro_render.gd")
const INTERIOR_LOOK = preload("res://scripts/interior_look.gd")
const CAM_MOVE = preload("res://scripts/ui/cam_move.gd")
const LAYOUT = preload("res://scripts/bowling/bowling_layout.gd")
const LANE = preload("res://scripts/bowling/lane.gd")
const POSES = preload("res://scripts/attractions/poses.gd")
const SFX := "res://assets/sfx/bowling/"
const TIME_DAY: int = 0
const TIME_NIGHT: int = 2
const INTERIOR_RENDER_MIN_SIZE := Vector2i(960, 540)
const AUTO_SET := 2.4
const MOVE_SEC := 0.55
const GUEST_H := 1.72

var key := ""
var _is_open := false
var _viewport_container: SubViewportContainer
var _viewport: SubViewport
var _interior_camera: Camera3D
var _root: Node3D
var _env: Environment
var _built := {}
var _lanes: Array = []
var _look = INTERIOR_LOOK.new(75.0, 20.0, 34.0)
var _cam_base_rot := Vector3.ZERO
var _spot := "hall"
var _move: Tween
var _exit_hint: Control
var _time_state := TIME_DAY
var _daylight := 1.0
var _power := true
## visit -> party {visit, name, members: [...], lane (-1 waiting), table}
var _parties: Dictionary = {}
var _poll := 0.0
var _set_wait: Dictionary = {}      # lane index -> seconds until its pins are set
var _hall: AudioStreamPlayer
var _hum: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	layer = 56
	visible = false
	_build_viewport()
	_root = Node3D.new()
	_root.name = "BowlingHall"
	_viewport.add_child(_root)
	_built = LAYOUT.build(_root)
	for i in LAYOUT.LANES.size():
		var lane := LANE.new()
		_root.add_child(lane)
		lane.setup(i)
		_lanes.append(lane)
	_interior_camera = Camera3D.new()
	_interior_camera.fov = 62.0
	_interior_camera.near = 0.05
	_root.add_child(_interior_camera)
	_hall = _loop("hall_loop.mp3", -16.0)
	_hum = _loop("fluoro.mp3", -26.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_sync_viewport()


func _build_viewport() -> void:
	_viewport_container = SubViewportContainer.new()
	_viewport_container.name = "BowlingViewportContainer"
	_viewport_container.anchor_right = 1.0
	_viewport_container.anchor_bottom = 1.0
	_viewport_container.stretch = true
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_viewport_container)
	RETRO_RENDER.register(_viewport_container)
	_viewport = SubViewport.new()
	_viewport.name = "BowlingViewport"
	_viewport.own_world_3d = true
	_viewport.size = INTERIOR_RENDER_MIN_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.handle_input_locally = false
	_viewport_container.add_child(_viewport)
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.05, 0.05, 0.06)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.7, 0.74, 0.76)
	_env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = _env
	_viewport.add_child(we)


func _sync_viewport() -> void:
	if _viewport_container != null and _viewport_container.stretch:
		return


func _loop(file: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var path := SFX + file
	if ResourceLoader.exists(path):
		var s = load(path)
		if s is AudioStreamMP3:
			s = (s as AudioStreamMP3).duplicate()
			(s as AudioStreamMP3).loop = true
		p.stream = s
	p.volume_db = db
	add_child(p)
	return p


func is_open() -> bool:
	return _is_open


func set_time_state(state: int) -> void:
	_time_state = state
	_apply_light()


func set_daylight_profile(daylight_factor: float, _sun: Color, _ambient: Color, _energy: float) -> void:
	_daylight = clampf(daylight_factor, 0.0, 1.0)
	_apply_light()


func set_grid_power_available(on: bool) -> void:
	_power = on
	_apply_light()


func _apply_light() -> void:
	var tubes: Array = _built.get("tubes", [])
	for t in tubes:
		(t as StandardMaterial3D).emission_energy_multiplier = 1.6 if _power else 0.0
	for l in _built.get("lights", []):
		(l as Light3D).visible = _power
	var glass: StandardMaterial3D = _built.get("glass")
	if glass != null:
		glass.emission_energy_multiplier = 0.15 + 0.75 * _daylight
	if _env != null:
		_env.ambient_light_energy = (0.55 if _power else 0.08) + 0.15 * _daylight


## In by the door of the bowling alley at `p_key` ("x:y").
func open_bowling(p_key: String) -> void:
	if _viewport_container != null:
		RETRO_RENDER.apply_to(_viewport_container)
	key = p_key
	if _is_open:
		return
	_is_open = true
	visible = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_go("hall", true)
	_apply_light()
	_sync_guests(true)
	if _hall.stream != null:
		_hall.play(_rng.randf() * 4.0)
	if _hum.stream != null and _power:
		_hum.play()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func close_bowling() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_hall.stop()
	_hum.stop()
	for v in _parties.keys():
		_drop_party(v)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	request_close.emit()


func _process(delta: float) -> void:
	if not _is_open:
		return
	if _move == null or not _move.is_running():
		var offset: Vector3 = _look.update(delta, INTERIOR_LOOK.cursor_of(get_viewport()), INTERIOR_LOOK.turn_axis())
		_interior_camera.rotation = _cam_base_rot + offset
	if _exit_hint == null:
		_exit_hint = INTERIOR_LOOK.make_exit_hint(self, "Leave   [S]" if _spot == "hall" else "Back   [S]")
	INTERIOR_LOOK.update_exit_hint(_exit_hint, get_viewport(), delta)
	_poll -= delta
	if _poll <= 0.0:
		_poll = 1.0
		_sync_guests(false)
	_tick_pinsetting(delta)


func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	if INTERIOR_LOOK.is_exit_event(event, get_viewport()):
		get_viewport().set_input_as_handled()
		if _spot == "hall":
			close_bowling()
		else:
			_go("hall")
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var what := _clicked()
		if what != "":
			get_viewport().set_input_as_handled()
			if what.begins_with("lane"):
				_go(what)
			elif what in ["desk", "bufet", "pit"]:
				_go(what)


## What the cursor is on in the hall: the click box's name ("desk", "lane2"...), or "".
func _clicked() -> String:
	if _viewport == null or _interior_camera == null:
		return ""
	var c := INTERIOR_LOOK.cursor_of(get_viewport())
	if c.x < 0.0:
		return ""
	var at := c * Vector2(_viewport.size)
	var from := _interior_camera.project_ray_origin(at)
	var dir := _interior_camera.project_ray_normal(at)
	var space := _interior_camera.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 30.0)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return ""
	var col = hit.get("collider")
	return str((col as Node).get_meta("bowling_click", "")) if col is Node else ""


## The camera to `spot` ("hall", "desk", "bufet", "pit", "lane<i>").
func _go(spot: String, at_once := false) -> void:
	var s: Array = LAYOUT.lane_spot(int(spot.substr(4))) if spot.begins_with("lane") else LAYOUT.SPOTS.get(spot, LAYOUT.SPOTS["hall"])
	_spot = spot
	if _exit_hint != null:
		_exit_hint.queue_free()
		_exit_hint = null
	var rot := Vector3(deg_to_rad(float((s[1] as Vector3).x)), deg_to_rad(float((s[1] as Vector3).y)), 0.0)
	_look.reset()
	_cam_base_rot = rot
	if _move != null and _move.is_valid():
		_move.kill()
	if at_once:
		_interior_camera.position = s[0]
		_interior_camera.rotation = rot
		return
	_move = CAM_MOVE.move(self, _interior_camera, {"position": s[0], "rotation": rot}, MOVE_SEC)


# ── the guests ───────────────────────────────────────────────────────────────

## Who the simulation has visiting this building now (the whole guest records).
func _visitors() -> Array:
	var out: Array = []
	if GuestManager == null or key == "":
		return out
	var now: int = GuestManager._absolute_minutes(maxi(1, GuestManager._last_known_day), GuestManager._last_known_hour, GuestManager._last_known_minute)
	for g in GuestManager.get_guest_life_snapshot():
		var act: Dictionary = g.get("activity", {}) if g.get("activity", {}) is Dictionary else {}
		if str(act.get("kind", "")) != "visit" or str(act.get("target_key", "")) != key or bool(act.get("queued", false)):
			continue
		if int(act.get("arrive", now)) > now:
			continue
		out.append(g)
	return out


func _sync_guests(_first: bool) -> void:
	var seen := {}
	for g in _visitors():
		var act: Dictionary = g.get("activity", {})
		var visit := "%d@%d" % [int(g.get("id", 0)), int(act.get("start", 0))]
		seen[visit] = true
		if not _parties.has(visit):
			_parties[visit] = _make_party(g, visit)
	for v in _parties.keys():
		if not seen.has(v):
			_drop_party(v)
	# Free lanes to whoever waits longest.
	for v in _parties.keys():
		var p: Dictionary = _parties[v]
		if int(p["lane"]) >= 0:
			continue
		for lane in _lanes:
			if not lane.busy():
				p["lane"] = lane.index
				lane.take(p)
				break


func _make_party(g: Dictionary, visit: String) -> Dictionary:
	var arch := str(g.get("archetype", ""))
	var n: int = POSES.figure_count(arch, int(g.get("party_size", 1)))
	var base := str(g.get("sprite_path", ""))
	var full := str(g.get("name", "Guest"))
	var members: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(visit)
	for k in n:
		var node := Node3D.new()
		node.name = "Bowler"
		_root.add_child(node)
		var sprite := Sprite3D.new()
		sprite.name = "Sprite"
		if ResourceLoader.exists(base):
			sprite.texture = load(base)
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.shaded = true
		sprite.double_sided = true
		if sprite.texture != null:
			sprite.pixel_size = GUEST_H / float(sprite.texture.get_height())
			sprite.offset = Vector2(0, sprite.texture.get_height() * 0.5)
		node.add_child(sprite)
		var nm := full.split(" ")[0] if k == 0 else "%s %d" % [full.split(" ")[0], k + 1]
		members.append({"id": int(g.get("id", 0)), "name": nm, "base": base, "node": node, "sprite": sprite,
			"skill": clampf(float(LANE.SKILL.get(arch, 0.4)) + rng.randf_range(-0.15, 0.15), 0.05, 0.95), "balls": []})
	var p := {"visit": visit, "name": full, "members": members, "lane": -1}
	# In through the door, over to a table to wait for a lane.
	var t: Vector3 = LAYOUT.TABLES[_parties.size() % LAYOUT.TABLES.size()]
	for k in members.size():
		var m: Dictionary = members[k]
		var node: Node3D = m["node"]
		node.position = Vector3(LAYOUT.DOOR_X + (float(k) - 0.5) * 0.4, 0.0, LAYOUT.FRONT_Z - 0.4)
		POSES.set_pose(m["sprite"], base, "")
		var seat := t + Vector3((float(k) - 0.5) * 0.9, 0, 0.55 if k % 2 == 0 else -0.55)
		var tw := create_tween()
		tw.tween_interval(0.25 * k)
		tw.tween_property(node, "position", seat, node.position.distance_to(seat) / 1.1)
		tw.tween_callback(func() -> void:
			if is_instance_valid(node) and int(p.get("lane", -1)) < 0:
				POSES.set_pose(m["sprite"], base, "sit"))
	return p


func _drop_party(v: String) -> void:
	var p: Dictionary = _parties.get(v, {})
	_parties.erase(v)
	if p.is_empty():
		return
	var li := int(p.get("lane", -1))
	if li >= 0 and li < _lanes.size():
		_lanes[li].release()
		_set_wait.erase(li)
	# Out of the door they came in by.
	for k in (p.get("members", []) as Array).size():
		var m: Dictionary = p["members"][k]
		var node: Node3D = m.get("node")
		if node == null or not is_instance_valid(node):
			continue
		if not _is_open:
			node.queue_free()
			continue
		POSES.set_pose(m["sprite"], str(m.get("base", "")), "")
		var door := Vector3(LAYOUT.DOOR_X + (float(k) - 0.5) * 0.4, 0.0, LAYOUT.FRONT_Z - 0.2)
		var tw := create_tween()
		tw.tween_interval(0.3 * k)
		tw.tween_property(node, "position", door, node.position.distance_to(door) / 1.2)
		tw.tween_callback(node.queue_free)


# ── the pins between balls ───────────────────────────────────────────────────

## A lane whose pins wait is set up again AUTO_SET seconds after the ball (for now: by
## hand in the pit and the machine are to come).
func _tick_pinsetting(delta: float) -> void:
	for lane in _lanes:
		if lane.needs_set == "":
			_set_wait.erase(lane.index)
			continue
		if not _set_wait.has(lane.index):
			_set_wait[lane.index] = AUTO_SET
		_set_wait[lane.index] = float(_set_wait[lane.index]) - delta
		if float(_set_wait[lane.index]) <= 0.0:
			_set_wait.erase(lane.index)
			lane.set_pins()
