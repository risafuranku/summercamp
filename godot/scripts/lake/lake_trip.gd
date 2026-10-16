extends Node

## Across the lake in Mr Hruby's rowing boat (the boat at the end of the camp jetty,
## scripts/camp_lake.gd). E at the boat to get in; W pulls a stroke (the gloved hands on
## the oars, a Build-engine sprite), A/D turn; the boat glides between strokes. Near a
## jetty it comes alongside by itself.
##
## The far shore is a place to stand and look, like an interior (restricted look, the
## cursor): the keeper's boathouse (his logbook on the table inside the door, a close-up),
## the end of his jetty to fish from, the boat to row back. The camp across the water,
## its lamps at night. Nothing you must do there.
##
## Fishing: click the end of the jetty to cast, wait for the float to go under, click
## then. Carp and pike go to the camp kitchen for a few dollars; sometimes it is not a fish.
## At night, once in a while, something passes under the boat.

const INTERIOR_LOOK = preload("res://scripts/interior_look.gd")
const HOVER_GLINT = preload("res://scripts/ui/hover_glint.gd")
const LOGBOOK = preload("res://scripts/lake/logbook_closeup.gd")
const OARS := "res://assets/textury/hands/oars.png"
const SFX := "res://assets/sfx/lake/"
const MAX_SPEED := 2.8
const STROKE := 0.95
const DRAG := 0.32
const TURN := 0.9

enum { NONE, ROWING, FAR_SHORE }

var _main: Node
var _lake
var _state := NONE
var _cam: Camera3D
var _prev_cam: Camera3D
var _speed := 0.0
var _yaw := 0.0
var _stroke_t := -1.0
var _dest := ""             # "far" or "camp"
var _docking := false
var _overlay: CanvasLayer
var _hands: TextureRect
var _lap: AudioStreamPlayer
var _one: AudioStreamPlayer
var _look = INTERIOR_LOOK.new(150.0, 25.0, 30.0)
var _base_rot := Vector3.ZERO
var _glint = HOVER_GLINT.new()
var _hot: Dictionary = {}
var _hover := ""
var _logbook
var _under_done := false
var _fish_state := ""       # "", "waiting", "bite", "show"
var _fish_t := 0.0
var _float: MeshInstance3D
var _catch := {}
var _catch_card: TextureRect
var _caught_today := 0
var _rng := RandomNumberGenerator.new()


func setup(main_node: Node) -> void:
	_main = main_node
	_rng.randomize()


func is_active() -> bool:
	return _state != NONE


func _lake_node():
	if _lake == null or not is_instance_valid(_lake):
		_lake = get_tree().root.find_child("CampLake", true, false)
	return _lake


func _player() -> Node3D:
	return _main.get("_player") as Node3D


func _near_boat() -> bool:
	var lake = _lake_node()
	var p := _player()
	if lake == null or p == null or lake.boat == null:
		return false
	return p.global_position.distance_to(lake.boat.global_position) < 3.0


func hint() -> String:
	if _state == NONE and _near_boat():
		return "[E] Take the boat across"
	return ""


func try_interact() -> bool:
	if _state != NONE or not _near_boat():
		return false
	_start_rowing("far")
	return true


# ── rowing ────────────────────────────────────────────────────────────────────

func _start_rowing(dest: String) -> void:
	var lake = _lake_node()
	if lake == null:
		return
	_dest = dest
	_docking = false
	_speed = 0.0
	_under_done = false
	_end_far_shore()
	if _cam == null:
		_cam = Camera3D.new()
		_cam.fov = 66.0
		_cam.near = 0.05
		_cam.far = 400.0
		lake.boat.add_child(_cam)
		_cam.position = Vector3(0.0, 1.05, 0.35)
		# The bow is the boat's +Z: face it (you row facing the way you go, for play).
		_cam.rotation = Vector3(0.0, PI, 0.0)
	_prev_cam = get_viewport().get_camera_3d() if _prev_cam == null else _prev_cam
	_cam.current = true
	_update_lantern()
	_yaw = lake.boat.rotation.y
	if dest == "far":
		# Push off from the camp jetty, the bow out onto the lake (north, +Z).
		_yaw = 0.0
	var p := _player()
	if p != null and p.has_method("set_controls_enabled"):
		p.set_controls_enabled(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_ensure_overlay()
	_overlay.visible = true
	_hands.visible = true
	_lap.play()
	_state = ROWING
	_play("bump.mp3", -6.0)


func _process(delta: float) -> void:
	match _state:
		ROWING:
			_update_rowing(delta)
		FAR_SHORE:
			_update_far_shore(delta)


func _update_rowing(delta: float) -> void:
	var lake = _lake_node()
	if lake == null:
		return
	var boat: Node3D = lake.boat
	if not _docking:
		if Input.is_physical_key_pressed(KEY_W) and _stroke_t < 0.0:
			_stroke_t = 0.0
			_speed = minf(MAX_SPEED, _speed + STROKE)
			_play("stroke.mp3", -4.0)
		var turn := 0.0
		if Input.is_physical_key_pressed(KEY_A):
			turn += 1.0
		if Input.is_physical_key_pressed(KEY_D):
			turn -= 1.0
		_yaw += turn * TURN * delta * (0.4 + _speed / MAX_SPEED)
	_speed = maxf(0.0, _speed - DRAG * delta * (1.0 + _speed))
	if _stroke_t >= 0.0:
		_stroke_t += delta
		if _stroke_t >= 0.85:
			_stroke_t = -1.0
	var fwd := Vector3(sin(_yaw), 0.0, cos(_yaw))
	var target: Vector3 = lake.far_jetty_end if _dest == "far" else lake.boat_home.origin
	if not _docking and Vector2(boat.global_position.x, boat.global_position.z).distance_to(Vector2(target.x, target.z)) < 4.5:
		_docking = true
		_play("bump.mp3", -2.0)
	if _docking:
		# Alongside by itself: drift to the jetty and stop.
		var to := Vector3(target.x + 1.4, boat.global_position.y, target.z)
		boat.global_position = boat.global_position.move_toward(to, delta * 1.2)
		_yaw = lerp_angle(_yaw, PI if _dest == "camp" else 0.0, delta * 1.5)
		if boat.global_position.distance_to(to) < 0.05:
			_arrive()
	else:
		var next := boat.global_position + fwd * _speed * delta
		if Geometry2D.is_point_in_polygon(Vector2(next.x, next.z), lake.water_poly):
			boat.global_position = next
		else:
			_speed = 0.0
			_play("bump.mp3", -8.0)
	boat.rotation.y = _yaw
	# The boat rocks with the strokes, in steps.
	var rock := sin(floorf(Time.get_ticks_msec() / 125.0) * 0.4) * 0.012 + (0.03 if _stroke_t >= 0.0 and _stroke_t < 0.4 else 0.0)
	boat.rotation.x = rock
	_update_hands()
	_maybe_under(delta)


## Once a trip, at night, a long scrape along the bottom of the boat.
func _maybe_under(delta: float) -> void:
	var h := float(_main.get("_time_of_day_hours"))
	var night := h >= 21.0 or h < 5.0
	if _under_done or not night or _docking:
		return
	if _rng.randf() < delta * 0.03:
		_under_done = true
		_play("under.mp3", 0.0)
		_speed *= 0.3
		var lake = _lake_node()
		var tw := create_tween()
		tw.tween_property(lake.boat, "rotation:z", 0.08, 0.4)
		tw.tween_property(lake.boat, "rotation:z", -0.05, 0.5)
		tw.tween_property(lake.boat, "rotation:z", 0.0, 0.8)
		_say("Something long passes under the boat. Then nothing.")


func _arrive() -> void:
	_docking = false
	_stroke_t = -1.0
	_hands.visible = false
	if _dest == "far":
		_begin_far_shore()
	else:
		_finish_trip()


func _finish_trip() -> void:
	var lake = _lake_node()
	if lake != null and lake.boat != null:
		lake.boat.transform = lake.boat_home
	_lap.stop()
	_overlay.visible = false
	_state = NONE
	if _prev_cam != null and is_instance_valid(_prev_cam):
		_prev_cam.current = true
	_prev_cam = null
	var p := _player()
	if p != null and p.has_method("set_controls_enabled"):
		p.set_controls_enabled(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


# ── the far shore ─────────────────────────────────────────────────────────────

func _begin_far_shore() -> void:
	var lake = _lake_node()
	_state = FAR_SHORE
	_lap.volume_db = -20.0
	# Up on the keeper's jetty: the camera leaves the boat.
	_cam.reparent(lake)
	_cam.global_position = lake.far_view
	# Facing the boathouse (north, +Z); turn round for the camp across the water.
	_cam.rotation = Vector3(deg_to_rad(-6.0), PI, 0.0)
	_base_rot = _cam.rotation
	_look.reset()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_hot()
	_update_lantern()
	var h := float(_main.get("_time_of_day_hours"))
	lake.set_hut_lit((h >= 22.0 or h < 4.0) and _rng.randf() < 0.18)


func _end_far_shore() -> void:
	_glint.clear()
	_end_fishing()
	var lake = _lake_node()
	if _cam != null and lake != null and _cam.get_parent() != lake.boat:
		_cam.reparent(lake.boat)
		_cam.position = Vector3(0.0, 1.05, 0.35)
		_cam.rotation = Vector3(0.0, PI, 0.0)


func _build_hot() -> void:
	if not _hot.is_empty():
		return
	var lake = _lake_node()
	var root: Node3D = lake.get_node_or_null("FarShore")
	if root == null:
		return
	var hut := root.get_node_or_null("HutDoor")
	_hot["hut"] = {"node": hut, "meshes": [hut, root.get_node_or_null("HutDark")]}
	_hot["rod"] = {"node": root.get_node_or_null("Rod"), "meshes": [root.get_node_or_null("Rod")]}
	_hot["boat"] = {"node": lake.boat, "meshes": [lake.boat]}


func _update_far_shore(delta: float) -> void:
	if _logbook != null and _logbook.visible:
		return
	var offset: Vector3 = _look.update(delta, INTERIOR_LOOK.cursor_of(get_viewport()), INTERIOR_LOOK.key_axis())
	_cam.rotation = _base_rot + offset
	_update_fishing(delta)
	# What is under the cursor: things on screen within a few degrees of the ray.
	var m := get_viewport().get_mouse_position()
	var ray_o := _cam.project_ray_origin(m)
	var ray_d := _cam.project_ray_normal(m)
	_hover = ""
	var best := 0.985
	for id in _hot.keys():
		var n = _hot[id]["node"]
		if n == null or not is_instance_valid(n):
			continue
		var to: Vector3 = ((n as Node3D).global_position + Vector3(0, 0.6, 0)) - ray_o
		var dot := to.normalized().dot(ray_d)
		if dot > best and to.length() < 14.0:
			best = dot
			_hover = id
	# The water off the end of the jetty: fishing.
	var lake = _lake_node()
	if _hover == "" and _fish_state == "" and ray_d.y < -0.05:
		var t: float = (float(lake.WATER_Y) - ray_o.y) / ray_d.y
		var hit: Vector3 = ray_o + ray_d * t
		if t > 2.0 and t < 14.0 and hit.z < lake.far_jetty_end.z - 0.5:
			_hover = "water"
	if _fish_state == "bite":
		_hover = "water"
	if _hover != "":
		HandCursor.want(HandCursor.POINT)
		_glint.show_on(_hot[_hover]["meshes"] if _hot.has(_hover) else [])
	else:
		_glint.clear()


func _unhandled_input(event: InputEvent) -> void:
	if _state == ROWING:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
		return
	if _state != FAR_SHORE:
		return
	if _logbook != null and _logbook.visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		match _hover:
			"boat":
				_start_rowing("camp")
			"hut":
				_open_logbook()
			"rod", "water":
				_fish_click()
		get_viewport().set_input_as_handled()


func _open_logbook() -> void:
	if _logbook == null:
		_logbook = LOGBOOK.new()
		add_child(_logbook)
	_glint.clear()
	_logbook.open_view()


# ── fishing ───────────────────────────────────────────────────────────────────

func _fish_click() -> void:
	match _fish_state:
		"":
			_cast()
		"waiting":
			# Too early: the float comes back empty.
			_end_fishing()
			_say("Too soon. You reel in an empty hook.")
		"bite":
			_land()
		"show":
			_end_fishing()


func _cast() -> void:
	var lake = _lake_node()
	_fish_state = "waiting"
	_fish_t = _rng.randf_range(4.0, 12.0)
	_play("cast.mp3", -4.0)
	if _float == null:
		_float = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.06
		sm.height = 0.16
		sm.radial_segments = 6
		sm.rings = 3
		_float.mesh = sm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.9, 0.2, 0.1)
		m.emission_enabled = true
		m.emission = Color(0.5, 0.08, 0.04)
		_float.material_override = m
		lake.add_child(_float)
	var fwd := -_cam.global_transform.basis.z
	fwd.y = 0.0
	_float.global_position = lake.far_jetty_end + fwd.normalized() * 6.0 + Vector3(0, lake.WATER_Y + 0.02 - lake.far_jetty_end.y, 0)
	_float.visible = true


func _update_fishing(delta: float) -> void:
	if _fish_state == "" or _float == null:
		return
	_fish_t -= delta
	var bob := floorf(Time.get_ticks_msec() / 160.0)
	match _fish_state:
		"waiting":
			_float.position.y = _lake_node().WATER_Y + 0.02 + sin(bob * 0.7) * 0.01
			if _fish_t <= 0.0:
				_fish_state = "bite"
				_fish_t = 0.9
				_play("bite.mp3", -2.0)
		"bite":
			_float.position.y = _lake_node().WATER_Y - 0.06
			if _fish_t <= 0.0:
				_fish_state = ""
				_float.visible = false
				_say("It took the bait and went. The float bobs back up, empty.")


func _land() -> void:
	_play("reel.mp3", -3.0)
	_float.visible = false
	_fish_state = "show"
	var roll := _rng.randf()
	var h := float(_main.get("_time_of_day_hours"))
	var night := h >= 21.0 or h < 5.0
	if roll < 0.45:
		_catch = {"tex": "res://assets/textury/lake/carp.png", "text": "A carp, two kilos. The kitchen will have it: +$6.", "money": 6}
	elif roll < 0.75:
		_catch = {"tex": "res://assets/textury/lake/pike.png", "text": "A pike, all teeth. The kitchen will have it: +$10.", "money": 10}
	elif roll < 0.92 or not night:
		_catch = {"tex": "", "text": "Weed and an old boot lace. Nothing.", "money": 0}
	else:
		_catch = {"tex": "res://assets/textury/pipes/red_shoe.png", "text": "A red shoe, a lady's, full of mud. Like the one in the pipes. The left one.", "money": 0}
	var money := int(_catch.get("money", 0))
	if money > 0 and CoreRoot != null and CoreRoot.actions != null:
		CoreRoot.actions.add_money(money)
		_caught_today += 1
	_say(str(_catch["text"]))
	_ensure_overlay()
	var path := str(_catch.get("tex", ""))
	_catch_card.texture = load(path) if path != "" and ResourceLoader.exists(path) else null
	_catch_card.visible = _catch_card.texture != null
	get_tree().create_timer(2.6).timeout.connect(func():
		if _fish_state == "show":
			_end_fishing()
	)


func _end_fishing() -> void:
	_fish_state = ""
	if _float != null:
		_float.visible = false
	if _catch_card != null:
		_catch_card.visible = false


var _lantern: OmniLight3D


## After dark the boat's paraffin lantern goes with you: a warm ring a few metres round.
func _update_lantern() -> void:
	if _cam == null:
		return
	if _lantern == null:
		_lantern = OmniLight3D.new()
		_lantern.light_color = Color(1.0, 0.72, 0.4)
		_lantern.light_energy = 1.1
		_lantern.omni_range = 9.0
		_lantern.omni_attenuation = 1.4
		_lantern.position = Vector3(0.35, -0.3, 0.2)
		_cam.add_child(_lantern)
	var h := float(_main.get("_time_of_day_hours"))
	_lantern.visible = h >= 19.5 or h < 6.0


# ── overlay, sound ────────────────────────────────────────────────────────────

func _ensure_overlay() -> void:
	if _overlay != null:
		return
	_overlay = CanvasLayer.new()
	_overlay.layer = 60
	add_child(_overlay)
	_hands = TextureRect.new()
	_hands.texture = load(OARS) if ResourceLoader.exists(OARS) else null
	_hands.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hands.stretch_mode = TextureRect.STRETCH_SCALE
	_hands.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_hands)
	_catch_card = TextureRect.new()
	_catch_card.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_catch_card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_catch_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_catch_card.visible = false
	_overlay.add_child(_catch_card)
	_lap = AudioStreamPlayer.new()
	var lp := SFX + "lap.mp3"
	if ResourceLoader.exists(lp):
		var s := (load(lp) as AudioStreamMP3).duplicate() as AudioStreamMP3
		s.loop = true
		_lap.stream = s
	_lap.volume_db = -10.0
	add_child(_lap)
	_one = AudioStreamPlayer.new()
	add_child(_one)


## The hands on the oars: pulled back and down on a stroke, forward again, in steps.
func _update_hands() -> void:
	if _hands == null or _hands.texture == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var k := float(maxi(1, int(round(vp.y / 300.0))))
	_hands.size = _hands.texture.get_size() * k
	var phase := 0.0
	if _stroke_t >= 0.0:
		phase = [0.0, 0.5, 1.0, 1.0, 0.6, 0.2][clampi(int(_stroke_t / 0.85 * 6.0), 0, 5)]
	_hands.position = Vector2((vp.x - _hands.size.x) * 0.5, vp.y - _hands.size.y * 0.8 + phase * 26.0 * k).floor()
	_hands.scale = Vector2.ONE * (1.0 - phase * 0.06)
	_hands.pivot_offset = _hands.size * 0.5
	if _catch_card != null:
		_catch_card.size = Vector2(160, 160) * k
		_catch_card.position = ((vp - _catch_card.size) * 0.5).floor()


func _play(file: String, db: float) -> void:
	if _one != null and ResourceLoader.exists(SFX + file):
		_one.stream = load(SFX + file)
		_one.volume_db = db
		_one.play()


func _say(text: String) -> void:
	var hud = _main.get("_hud_manager")
	if hud != null:
		hud.push_status(text, 1)
