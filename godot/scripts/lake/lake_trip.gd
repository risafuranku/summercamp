extends Node

## Across the lake in Mr Hruby's rowing boat (tied up by the camp jetty, scripts/camp_lake.gd;
## the boat itself, its hull, oars, lantern, water and sounds: scripts/lake/boat_rig.gd).
## The user, 21. 10.: "totálně polishnout lodičku, single i coop".
##
## E at the boat: you climb down into it and sit on the aft thwart facing the bow, the
## oars come up into the rowlocks. W pushes both oars through a stroke, and held, stroke
## after stroke in a rhythm: the boat surges on each and glides between. S backs water.
## A and D push one oar and back the other, the boat turns on the spot; with W one oar
## rests and it turns as it goes. The mouse looks round from the seat (the hands drop
## out of the view when you look away). The swell, the wind and the strokes rock the
## boat; it knocks off the shore and the jetties; near a jetty it comes alongside by
## itself and you climb out (E gets you out again before you have pushed off).
##
## The far shore is a place to stand and look, like an interior (restricted look, the
## cursor): the keeper's boathouse (his logbook on the table inside the door, a close-up),
## the end of his jetty to fish from, the boat to row back. The camp across the water,
## its lamps at night. Nothing you must do there.
##
## Fishing: click the end of the jetty to cast, wait for the float to go under, click
## then. Carp and pike go to the camp kitchen for a few dollars; sometimes it is not a fish.
## At night the crossing is not empty (scripts/lake/night_row.gd decides what happens).
##
## Co-op: one boat for two. The other warden sees you row it (their boat goes where yours
## does and its oars stroke as yours: coop_state "boat" and "rp"); they climb into the bow
## and ride with you face to face, go ashore with you and come back with you.

const INTERIOR_LOOK = preload("res://scripts/interior_look.gd")
const HOVER_GLINT = preload("res://scripts/ui/hover_glint.gd")
const LOGBOOK = preload("res://scripts/lake/logbook_closeup.gd")
const NIGHT_ROW = preload("res://scripts/lake/night_row.gd")
const BOAT_RIG = preload("res://scripts/lake/boat_rig.gd")
const CAM_MOVE = preload("res://scripts/ui/cam_move.gd")
const HANDS = preload("res://scripts/ui/hands.gd")
const OARS := "res://assets/textury/hands/oars.png"
const SFX := "res://assets/sfx/lake/"
## The fastest the boat goes (m/s), for whoever asks.
const MAX_SPEED := 2.8
## An oar at the height of its drive pushes the boat this hard (m/s^2); backing water
## pushes less. The water holds it back (along the hull, and much more sideways), and its
## turn.
const OAR_PUSH := 2.4
const BACK_PUSH := 0.6
const DRAG_LIN := 0.25
const DRAG_QUAD := 0.12
const SLIP_DRAG := 3.0
const TURN_PUSH := 0.95
const TURN_DRAG := 2.0
## How hard the wind pushes the boat along (m/s^2 at a gale).
const WIND_PUSH := 0.07
## Looking round from the seat (degrees): the rower, and the one in the bow.
const LOOK_YAW := 115.0
const LOOK_YAW_BOW := 150.0
const LOOK_UP := 38.0
const LOOK_DOWN := 58.0
const FOV := 68.0
## Into the seat and out of it, onto a jetty and down from it (seconds).
const BOARD_SEC := 0.8
## Where the second one stands on the keeper's jetty (from the rower's place there).
const FAR_MATE := Vector3(0.3, 0.0, 2.4)
## Near enough to the camp's berth to climb out before you have pushed off (m).
const STEP_OUT_NEAR := 3.0

enum { NONE, ROWING, FAR_SHORE, PASSENGER, LEAVING }

var _main: Node
var _lake
var _state := NONE
var _cam: Camera3D
var _prev_cam: Camera3D
## The boat under you: speed along its bow and sideways (m/s), heading and turn (rad,
## rad/s), its surge (m/s^2).
var _speed := 0.0
var _slip := 0.0
var _yaw := 0.0
var _yaw_rate := 0.0
var _accel := 0.0
## Each oar (0 the left, the boat's +X; 1 the right): its stroke phase (< 0 at rest) and
## whether it drives (1) or backs (-1).
var _oar_u := [-1.0, -1.0]
var _oar_dir := [1, 1]
var _dest := ""             # "far" or "camp"
var _docking := false
## Out on the water once (well off the camp jetty): rowing back to it ties up there,
## whichever way the trip was meant to go (pushed off and thought better of it, you could
## not get out again: playtest 18. 10.).
var _left_home := false
## The same for the keeper's jetty: pushed off from it, you come alongside it again only
## once you have been out (it took you straight back to it, so the far shore could not
## be left by boat at all).
var _left_far := true
var _bump_cd := 0.0
var _trip_t := 0.0
var _idle_t := 0.0
## Your head on the seat (radians, from looking straight down the boat).
var _head_yaw := 0.0
var _head_pitch := 0.0
var _moving := false
var _cam_tw: Tween
var _overlay: CanvasLayer
var _hand: Array = []       # the two hands on the oars: [left, right] TextureRects
var _hands_up := 0.0
var _hands_acc := 0.0
var _split := 242
var _lap: AudioStreamPlayer
var _one: AudioStreamPlayer
var _look = INTERIOR_LOOK.new(150.0, 25.0, 30.0)
var _base_rot := Vector3.ZERO
var _glint = HOVER_GLINT.new()
var _hot: Dictionary = {}
var _hover := ""
var _logbook
var _fish_state := ""       # "", "waiting", "bite", "show"
var _fish_t := 0.0
var _float: MeshInstance3D
var _catch := {}
var _catch_card: TextureRect
var _caught_today := 0
var _rng := RandomNumberGenerator.new()
var _night


func setup(main_node: Node) -> void:
	_main = main_node
	_night = NIGHT_ROW.new(self)
	_rng.randomize()


func is_active() -> bool:
	return _state != NONE


func _lake_node():
	if _lake == null or not is_instance_valid(_lake):
		_lake = get_tree().root.find_child("CampLake", true, false)
	return _lake


## The boat's rig (scripts/lake/boat_rig.gd), made on the boat the first time it is there.
func _rig():
	var lake = _lake_node()
	if lake == null or lake.boat == null or not is_instance_valid(lake.boat):
		return null
	var rig = (lake.boat as Node).get_node_or_null("BoatRig")
	if rig == null:
		rig = BOAT_RIG.new()
		rig.setup(lake.boat, lake)
		(lake.boat as Node).add_child(rig)
	return rig


func _player() -> Node3D:
	return _main.get("_player") as Node3D


func _player_cam() -> Camera3D:
	var p := _player()
	return p.get_node_or_null("Head/Camera3D") as Camera3D if p != null else null


func _near_boat() -> bool:
	var lake = _lake_node()
	var p := _player()
	if lake == null or p == null or lake.boat == null:
		return false
	return p.global_position.distance_to(lake.boat.global_position) < 3.0


func hint() -> String:
	if _state == NONE and _near_boat() and not _coop_boat_away:
		return "[E] Take the boat across"
	if _state == NONE and _can_join():
		return "[E] Get in with %s" % Coop.name_of(_rower_id)
	return ""


## What the HUD says while you are in the boat: the oars at first and when you sit idle,
## the way out while you are still by the camp jetty.
func active_hint() -> String:
	if _moving:
		return ""
	match _state:
		ROWING:
			if _docking:
				return ""
			var keys := tr("W row  -  A / D turn  -  S back water")
			if _can_step_out():
				return tr("[E] Get out") + "    " + keys
			if _trip_t < 9.0 or _idle_t > 5.0:
				return keys
		PASSENGER:
			if _by_camp_jetty():
				return tr("[E] Get out")
	return ""


func try_interact() -> bool:
	if _state == ROWING:
		if _can_step_out():
			_dest = "camp"
			_arrive()
		return true
	if _state == PASSENGER:
		if _by_camp_jetty():
			_get_out()
			return true
		return true
	if _state != NONE:
		return false
	if _can_join():
		_start_passenger()
		return true
	if not _near_boat() or _coop_boat_away:
		return false
	_start_rowing("far")
	return true


# ── into the boat, out of it ─────────────────────────────────────────────────

func _start_rowing(dest: String) -> void:
	var lake = _lake_node()
	var rig = _rig()
	if lake == null or rig == null:
		return
	_dest = dest
	_docking = false
	_left_home = dest == "camp"
	_left_far = dest != "camp"
	_speed = 0.0
	_slip = 0.0
	_yaw_rate = 0.0
	_accel = 0.0
	_oar_u = [-1.0, -1.0]
	_trip_t = 0.0
	_idle_t = 0.0
	_end_far_shore()
	var boat: Node3D = lake.boat
	_yaw = boat.rotation.y
	_take_camera(rig)
	_head_yaw = 0.0
	_head_pitch = deg_to_rad(-9.0)
	var p := _player()
	if p != null and p.has_method("set_controls_enabled"):
		p.set_controls_enabled(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_ensure_overlay()
	_overlay.visible = true
	_set_hands_visible(true)
	_hands_up = 0.0
	_lap.volume_db = -10.0
	_lap.play()
	var from_shore := _state == NONE
	_state = ROWING
	rig.set_manned(true)
	# Your weight going in: the boat dips and rolls under you.
	rig.kick(0.16 if _rng.randf() < 0.5 else -0.16, 0.05, -0.22)
	rig.play_sound("step_in.mp3" if ResourceLoader.exists(SFX + "step_in.mp3") else "bump.mp3", -1.0)
	var hh := float(_main.get("_time_of_day_hours"))
	_night.begin(hh >= 20.5 or hh < 5.0)
	_move_cam(_seat_view(), BOARD_SEC if from_shore else BOARD_SEC * 1.1, Callable())


## The camera for the boat: made the first time (where your own eyes are), after that the
## same one moved on; under the hull, so it rides the swell with you.
func _take_camera(rig) -> void:
	if _cam == null or not is_instance_valid(_cam):
		_cam = Camera3D.new()
		_cam.name = "BoatCamera"
		_cam.fov = FOV
		_cam.near = 0.05
		_cam.far = 400.0
		rig.hull.add_child(_cam)
		var pc := _player_cam()
		if pc != null:
			_cam.global_transform = pc.global_transform
			_prev_cam = pc
		else:
			_cam.transform = _seat_view()
	elif _cam.get_parent() != rig.hull:
		_cam.reparent(rig.hull, true)
	if _prev_cam == null:
		_prev_cam = _player_cam()
	_cam.current = true


## The camera from where it is to `to` (in its parent's space) in `secs`, eased; then `done`.
func _move_cam(to: Transform3D, secs: float, done: Callable) -> void:
	if _cam_tw != null and _cam_tw.is_valid():
		_cam_tw.kill()
	var from := _cam.transform
	_moving = true
	_cam_tw = create_tween()
	_cam_tw.tween_method(func(f: float) -> void:
		if _cam != null and is_instance_valid(_cam):
			_cam.transform = from.interpolate_with(to, f), 0.0, 1.0, secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tw.tween_callback(func() -> void:
		_moving = false
		if done.is_valid():
			done.call())
	CAM_MOVE.hold(self, _cam_tw)


## The rower's eyes on the aft thwart: down the boat to the bow, your head where you have
## turned it, leaning into the stroke, the swell's roll half taken out by the neck.
func _seat_view() -> Transform3D:
	var lean := 0.0
	for side in 2:
		var u := float(_oar_u[side])
		if u >= 0.0 and u < BOAT_RIG.RELEASE:
			lean = maxf(lean, sin(PI * u / BOAT_RIG.RELEASE) * float(_oar_dir[side]))
	var roll := 0.0
	var rig = _rig()
	if rig != null and rig.hull != null:
		var hr: Vector3 = rig.hull.rotation
		roll = -(hr.z * cos(_head_yaw) - hr.x * sin(_head_yaw)) * 0.5
	var b := Basis.from_euler(Vector3(_head_pitch - lean * 0.03, PI + _head_yaw, roll))
	return Transform3D(b, BOAT_RIG.ROWER_EYE + Vector3(0.0, -lean * 0.02, lean * 0.07))


func _bow_view() -> Transform3D:
	var roll := 0.0
	var rig = _rig()
	if rig != null and rig.hull != null:
		var hr: Vector3 = rig.hull.rotation
		roll = -(-hr.z * cos(_head_yaw) + hr.x * sin(_head_yaw)) * 0.5
	return Transform3D(Basis.from_euler(Vector3(_head_pitch, _head_yaw, roll)), BOAT_RIG.BOW_EYE)


## By the camp's berth and not yet out on the water: you may climb out again.
func _can_step_out() -> bool:
	if _state != ROWING or _left_home or _docking or _moving:
		return false
	return _by_camp_jetty()


func _by_camp_jetty() -> bool:
	var lake = _lake_node()
	if lake == null or lake.boat == null:
		return false
	var b: Vector3 = (lake.boat as Node3D).global_position
	return Vector2(b.x, b.z).distance_to(Vector2(lake.boat_home.origin.x, lake.boat_home.origin.z)) < STEP_OUT_NEAR


func _process(delta: float) -> void:
	var rig = _rig()
	if rig == null:
		return
	match _state:
		ROWING:
			_update_rowing(delta)
		FAR_SHORE:
			_update_far_shore(delta)
		PASSENGER:
			_update_passenger(delta)
		LEAVING:
			_update_leaving(delta)
	if _overlay != null and _overlay.visible:
		_update_hands(clampf(delta, 0.0, 0.1))
	_mirror_tick(delta)
	_update_lantern()


# ── rowing ────────────────────────────────────────────────────────────────────

func _update_rowing(delta: float) -> void:
	var lake = _lake_node()
	var rig = _rig()
	if lake == null or rig == null:
		return
	var boat: Node3D = lake.boat
	var dt := clampf(delta, 0.0, 0.1)
	_trip_t += dt
	_bump_cd -= dt
	var cmd := [0, 0] if (_docking or _moving) else _steer()
	var push := _advance_oars(dt, cmd)
	if cmd[0] == 0 and cmd[1] == 0:
		_idle_t += dt
	else:
		_idle_t = 0.0
	if _docking:
		_dock(dt, lake, boat)
	else:
		_row(dt, push, lake, boat)
	if _state != ROWING:
		return
	for side in 2:
		rig.set_oar(side, float(_oar_u[side]), int(_oar_dir[side]))
	rig.set_motion(_speed, _yaw_rate, _accel)
	if not _moving:
		_cam.transform = _seat_view()
	_night.tick(delta, float(_oar_u[0]) >= 0.0 or float(_oar_u[1]) >= 0.0, _docking)


## What the keys ask of the two oars: 1 push (drive on), -1 pull (back water), 0 rest.
## A turns to the left: the right oar drives, the left backs; with W only the right one
## rows. [left, right].
func _steer() -> Array:
	var w := Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
	var s := Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)
	var a := Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
	var d := Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)
	if a and d:
		a = false
		d = false
	if w and not s:
		if a:
			return [0, 1]
		if d:
			return [1, 0]
		return [1, 1]
	if s and not w:
		if a:
			return [-1, 0]
		if d:
			return [0, -1]
		return [-1, -1]
	if a:
		return [-1, 1]
	if d:
		return [1, -1]
	return [0, 0]


## Each oar on through its stroke: a stroke once begun is finished; another follows while
## its key is held. Returns how hard each pushes the boat now [left, right] (m/s^2, + on).
func _advance_oars(dt: float, cmd: Array) -> Array:
	var push := [0.0, 0.0]
	for side in 2:
		var u := float(_oar_u[side])
		var c := int(cmd[side])
		if u < 0.0:
			if c != 0:
				u = 0.0
				_oar_dir[side] = c
		else:
			u += dt / BOAT_RIG.PERIOD
			if u >= 1.0:
				if c != 0:
					u -= 1.0
					_oar_dir[side] = c
				else:
					u = -1.0
		_oar_u[side] = u
		if u >= 0.0 and u < BOAT_RIG.RELEASE:
			var f := sin(PI * u / BOAT_RIG.RELEASE) * OAR_PUSH
			push[side] = f if int(_oar_dir[side]) > 0 else -f * BACK_PUSH
	return push


func _row(dt: float, push: Array, lake, boat: Node3D) -> void:
	var heading := Vector2(sin(_yaw), cos(_yaw))
	var side_v := Vector2(cos(_yaw), -sin(_yaw))
	var wind := _wind_push()
	var drag := DRAG_LIN * _speed + DRAG_QUAD * _speed * absf(_speed)
	_accel = float(push[0]) + float(push[1]) - drag + wind.dot(heading)
	_speed = clampf(_speed + _accel * dt, -1.4, MAX_SPEED)
	_slip += (wind.dot(side_v) - SLIP_DRAG * _slip) * dt
	# The right oar (the boat's -X) driving swings the bow to the left (+yaw).
	_yaw_rate += ((float(push[1]) - float(push[0])) * TURN_PUSH - TURN_DRAG * _yaw_rate) * dt
	var was_yaw := _yaw
	_yaw += _yaw_rate * dt
	var v := heading * _speed + side_v * _slip
	var next := boat.global_position + Vector3(v.x, 0.0, v.y) * dt
	if _blocked(lake, next, _yaw):
		_yaw = was_yaw
		if _blocked(lake, boat.global_position, _yaw):
			# Wedged (turned into it): let it go where it is.
			boat.global_position = next
		_bump(v)
	else:
		boat.global_position = next
	boat.rotation = Vector3(0.0, _yaw, 0.0)
	# Whichever jetty you come up to: the keeper's, or the camp's once you have been out.
	var at2 := Vector2(boat.global_position.x, boat.global_position.z)
	var home: Vector3 = lake.boat_home.origin
	var home_d := at2.distance_to(Vector2(home.x, home.z))
	if home_d > 6.5:
		_left_home = true
	var far: Vector3 = lake.far_jetty_end
	var far_d := at2.distance_to(Vector2(far.x + 1.4, far.z))
	if far_d > 6.5:
		_left_far = true
	if _left_far and far_d < 4.2:
		_dest = "far"
		_docking = true
	elif _left_home and home_d < 4.2:
		_dest = "camp"
		_docking = true


## The wind on the boat (m/s^2 in world x, z): it drifts while you sit idle.
func _wind_push() -> Vector2:
	var wv = _main.get("_weather_visuals") if _main != null else null
	if wv == null:
		return Vector2.ZERO
	var dir = wv.get("wind_dir")
	var now = wv.get("_wind_now")
	if not (dir is Vector2) or now == null:
		return Vector2.ZERO
	return (dir as Vector2).normalized() * WIND_PUSH * clampf(float(now), 0.0, 1.8)


## The bow, the stern or the middle on the shore or a jetty.
func _blocked(lake, at: Vector3, yaw: float) -> bool:
	var fwd := Vector2(sin(yaw), cos(yaw))
	for k in [-1.15, 0.0, 1.15]:
		var p := Vector2(at.x, at.z) + fwd * float(k)
		if not Geometry2D.is_point_in_polygon(p, lake.water_poly):
			return true
		for r in lake.get("jetty_rects"):
			if (r as Rect2).has_point(p):
				return true
	return false


## Into the shore or a jetty: a knock back, a jolt, the sound by how hard.
func _bump(v: Vector2) -> void:
	var impact := v.length()
	_speed = -_speed * 0.3
	_slip = -_slip * 0.3
	_yaw_rate *= 0.4
	if impact > 0.15 and _bump_cd <= 0.0:
		_bump_cd = 0.5
		var rig = _rig()
		if rig != null:
			rig.play_sound("bump.mp3", lerpf(-16.0, -2.0, clampf(impact / 2.5, 0.0, 1.0)), _rng.randf_range(0.9, 1.08))
			rig.kick(_rng.randf_range(-0.12, 0.12) * impact, 0.16 * impact, 0.06)


## Alongside by itself: in to the berth, slowing, turned to lie along the jetty.
func _dock(dt: float, lake, boat: Node3D) -> void:
	var berth := _berth(lake, _dest)
	var to := berth.origin - boat.global_position
	to.y = 0.0
	var d := to.length()
	var step := minf(d, clampf(d * 1.1, 0.22, 1.3) * dt)
	if d > 0.0005:
		boat.global_position += to / d * step
	var by := berth.basis.get_euler().y
	var was := _yaw
	_yaw = lerp_angle(_yaw, by, 1.0 - exp(-2.4 * dt))
	_yaw_rate = angle_difference(was, _yaw) / maxf(dt, 0.001)
	_speed = (step / maxf(dt, 0.001)) * (to.normalized().dot(Vector3(sin(_yaw), 0.0, cos(_yaw))) if d > 0.0005 else 0.0)
	_accel = 0.0
	boat.rotation = Vector3(0.0, _yaw, 0.0)
	if d < 0.03 and absf(angle_difference(_yaw, by)) < 0.03:
		boat.global_position = Vector3(berth.origin.x, boat.global_position.y, berth.origin.z)
		_arrive()


## Where the boat lies tied up: by the camp jetty, or off the end of the keeper's.
func _berth(lake, dest: String) -> Transform3D:
	var home: Transform3D = lake.boat_home
	if dest == "far":
		var far: Vector3 = lake.far_jetty_end
		return Transform3D(Basis(), Vector3(far.x + 1.4, home.origin.y, far.z))
	return home


func _arrive() -> void:
	_night.end()
	_docking = false
	_speed = 0.0
	_slip = 0.0
	_yaw_rate = 0.0
	_oar_u = [-1.0, -1.0]
	_set_hands_visible(false)
	var rig = _rig()
	if rig != null:
		rig.set_motion(0.0, 0.0, 0.0)
		rig.play_sound("rope.mp3" if ResourceLoader.exists(SFX + "rope.mp3") else "bump.mp3", -3.0)
		rig.kick(0.05, -0.06, 0.0)
	if _dest == "far":
		_begin_far_shore()
	else:
		_get_out()


## Out of the boat onto the camp jetty: up out of the seat to your own eyes, facing the
## camp; the boat tied up at its berth.
func _get_out() -> void:
	var lake = _lake_node()
	var rig = _rig()
	_night.end()
	if lake == null or rig == null or _cam == null:
		_finish_trip()
		return
	if not _passenger:
		rig.set_manned(false)
	rig.kick(-0.12, 0.04, 0.12)
	rig.play_sound("step_out.mp3" if ResourceLoader.exists(SFX + "step_out.mp3") else "bump.mp3", -2.0)
	_set_hands_visible(false)
	_state = LEAVING
	var p := _player()
	var pc := _player_cam()
	if p == null or pc == null:
		_finish_trip()
		return
	# Up on the jetty beside the boat, turned to the camp.
	p.rotation.y = 0.0
	var to_world := pc.global_transform
	_cam.reparent(lake, true)
	var to: Transform3D = (lake as Node3D).global_transform.affine_inverse() * to_world
	_move_cam(to, BOARD_SEC, _finish_trip)


## Climbing out: the boat drifts the last bit in to its berth (you may have got out
## before it was quite there).
func _update_leaving(delta: float) -> void:
	if _passenger:
		return
	var lake = _lake_node()
	var rig = _rig()
	if lake == null or rig == null:
		return
	var boat := lake.boat as Node3D
	var home: Transform3D = lake.boat_home
	var k := 1.0 - exp(-3.0 * clampf(delta, 0.0, 0.1))
	boat.global_position = boat.global_position.lerp(home.origin, k)
	boat.rotation = Vector3(0.0, lerp_angle(boat.rotation.y, home.basis.get_euler().y, k), 0.0)
	rig.set_motion(0.0, 0.0, 0.0)


func _finish_trip() -> void:
	var lake = _lake_node()
	var rig = _rig()
	# A passenger leaves the boat where the other warden has it.
	if lake != null and lake.boat != null and not _passenger:
		lake.boat.transform = lake.boat_home
		if rig != null:
			rig.set_manned(false)
			rig.set_motion(0.0, 0.0, 0.0)
	_passenger = false
	if _cam_tw != null and _cam_tw.is_valid():
		_cam_tw.kill()
	_moving = false
	if _lap != null:
		_lap.stop()
	if _overlay != null:
		_overlay.visible = false
	_state = NONE
	var pc := _player_cam()
	if pc != null:
		pc.current = true
	elif _prev_cam != null and is_instance_valid(_prev_cam):
		_prev_cam.current = true
	_prev_cam = null
	var p := _player()
	if p != null and p.has_method("set_controls_enabled"):
		p.set_controls_enabled(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


# ── the far shore ─────────────────────────────────────────────────────────────

## Up out of the boat onto the keeper's jetty: the camera leaves the boat.
func _begin_far_shore() -> void:
	var lake = _lake_node()
	var rig = _rig()
	_state = FAR_SHORE
	if _lap != null:
		_lap.volume_db = -20.0
	if rig != null and not _passenger:
		rig.set_manned(false)
	_set_hands_visible(false)
	# Facing the boathouse (north, +Z); turn round for the camp across the water.
	_base_rot = Vector3(deg_to_rad(-6.0), PI, 0.0)
	_look.reset()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_build_hot()
	_update_lantern()
	var h := float(_main.get("_time_of_day_hours"))
	lake.set_hut_lit((h >= 22.0 or h < 4.0) and _rng.randf() < 0.18)
	var to_world := Transform3D(Basis.from_euler(_base_rot), _far_spot())
	if _cam == null or not is_instance_valid(_cam):
		return
	_cam.reparent(lake, true)
	_move_cam((lake as Node3D).global_transform.affine_inverse() * to_world, BOARD_SEC, Callable())


## Where you stand on the keeper's jetty: at its end, or (in the bow with the other one)
## a little further along it.
func _far_spot() -> Vector3:
	var lake = _lake_node()
	var v: Vector3 = lake.far_view if lake != null else Vector3.ZERO
	return v + FAR_MATE if _passenger else v


func _end_far_shore() -> void:
	_glint.clear()
	_end_fishing()


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
	if _moving or _cam == null:
		return
	var offset: Vector3 = _look.update(delta, INTERIOR_LOOK.cursor_of(get_viewport()), INTERIOR_LOOK.key_axis())
	_cam.rotation = _base_rot + offset
	_update_fishing(delta)
	# What is under the cursor: things on screen within a few degrees of the ray. The
	# world is drawn small and scaled up (retro render): the ray is cast in the camera's
	# own viewport, so the window's mouse is scaled into it (with window pixels only the
	# top-left of the screen ever hit anything and the far shore could not be left).
	var m := _mouse_in_cam_viewport()
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


func _mouse_in_cam_viewport() -> Vector2:
	var vp := get_viewport()
	var m := vp.get_mouse_position()
	var cam_vp := _cam.get_viewport() if _cam != null else null
	if cam_vp == null or cam_vp == vp:
		return m
	var win := vp.get_visible_rect().size
	var own := cam_vp.get_visible_rect().size
	if win.x <= 0.0 or win.y <= 0.0:
		return m
	return m * own / win


## The pause menu's "Row back to camp": home at once, by day or night.
func return_home() -> void:
	if _state == NONE:
		return
	_night.end()
	_end_far_shore()
	_finish_trip()


## _input, not _unhandled_input: the game view's container takes every mouse button,
## so a click never came through to here and the far shore could not be left.
func _input(event: InputEvent) -> void:
	if _state == ROWING or _state == PASSENGER:
		if event is InputEventMouseMotion and not _moving and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			_look_round((event as InputEventMouseMotion).relative)
		if _state == PASSENGER:
			# By the camp jetty a passenger may step out (S or the right button too).
			var out: bool = (event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_S) \
				or (event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT)
			if out and _by_camp_jetty() and not _moving:
				_get_out()
				get_viewport().set_input_as_handled()
		return
	if _state != FAR_SHORE or _moving:
		return
	if _logbook != null and _logbook.visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		match _hover:
			"boat":
				if _passenger:
					_say("%s has the oars: wait for them." % Coop.name_of(_rower_id))
				else:
					_start_rowing("camp")
			"hut":
				_open_logbook()
			"rod", "water":
				_fish_click()
		get_viewport().set_input_as_handled()


## The mouse turns your head on the seat, as it does on your feet.
func _look_round(rel: Vector2) -> void:
	var sens := 0.0012
	var p := _player()
	if p != null and p.get("mouse_sensitivity") != null:
		sens = float(p.get("mouse_sensitivity"))
	var scale := 2.0
	var invert := false
	if GameSettings != null:
		scale *= GameSettings.get_mouse_sensitivity()
		invert = GameSettings.get_invert_mouse_y()
	var lim := deg_to_rad(LOOK_YAW_BOW if _state == PASSENGER else LOOK_YAW)
	_head_yaw = clampf(_head_yaw - rel.x * sens * scale, -lim, lim)
	var dy := rel.y * (-1.0 if invert else 1.0)
	_head_pitch = clampf(_head_pitch - dy * sens * scale * 0.85, -deg_to_rad(LOOK_DOWN), deg_to_rad(LOOK_UP))


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
	if money > 0 and Coop.is_client():
		# Co-op: the till is the host's.
		Coop.send_request("money", [money])
		_caught_today += 1
	elif money > 0 and CoreRoot != null and CoreRoot.actions != null:
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


## After dark the boat's storm lantern burns while the boat is out (yours, the other
## warden's) or somebody is in it; your hands on the oars catch its light.
func _update_lantern() -> void:
	var rig = _rig()
	if rig == null or _main == null:
		return
	var h := float(_main.get("_time_of_day_hours")) if _main.get("_time_of_day_hours") != null else 12.0
	var dark := h >= 19.25 or h < 6.0
	var out := _state != NONE or _coop_boat_away
	rig.set_lantern(dark and out)
	if dark and (_state == ROWING or _state == PASSENGER):
		var hands = HANDS.of(self)
		if hands != null:
			hands.glow("boat_lantern", Color(0.24, 0.16, 0.08))


# ── the hands on the oars ────────────────────────────────────────────────────

func _ensure_overlay() -> void:
	if _overlay != null:
		return
	_overlay = CanvasLayer.new()
	_overlay.layer = 60
	add_child(_overlay)
	# The night's hand over the gunwale (night_row.gd) and the catch's card go on it too.
	var tex: Texture2D = load(OARS) if ResourceLoader.exists(OARS) else null
	_measure_shafts(tex)
	_split = _split_column(tex)
	var hands = HANDS.of(self)
	for side in 2:
		var r := TextureRect.new()
		r.name = "Hand%d" % side
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if tex != null:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(0, 0, _split, tex.get_height()) if side == 0 else Rect2(_split, 0, tex.get_width() - _split, tex.get_height())
			r.texture = at
		if hands != null:
			r.material = hands.material
		# The oar runs on out of the picture (the sprite cut it off square at its side).
		var shaft := Control.new()
		shaft.name = "Shaft"
		shaft.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shaft.show_behind_parent = true
		shaft.use_parent_material = true
		var s := side
		shaft.draw.connect(func(): _draw_shaft(shaft, s, tex))
		r.add_child(shaft)
		_overlay.add_child(r)
		_hand.append(r)
	_catch_card = TextureRect.new()
	_catch_card.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_catch_card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_catch_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_catch_card.visible = false
	_overlay.add_child(_catch_card)
	_lap = AudioStreamPlayer.new()
	var lp := SFX + "lap.mp3"
	if ResourceLoader.exists(lp):
		var st := (load(lp) as AudioStreamMP3).duplicate() as AudioStreamMP3
		st.loop = true
		_lap.stream = st
	_lap.volume_db = -10.0
	add_child(_lap)
	_one = AudioStreamPlayer.new()
	add_child(_one)


func _set_hands_visible(on: bool) -> void:
	for h in _hand:
		(h as Control).set_meta("want", on)


## The empty column between the two hands in the picture (the gloves are cut apart there).
static func _split_column(tex: Texture2D) -> int:
	if tex == null:
		return 242
	var img := tex.get_image()
	if img == null:
		return tex.get_width() / 2
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var best := w / 2
	for off in range(0, w / 3):
		for x in [w / 2 - off, w / 2 + off]:
			var empty := true
			for y in img.get_height():
				if img.get_pixel(x, y).a > 0.1:
					empty = false
					break
			if empty:
				return x
	return best


## Where each oar leaves the sprite: the shaft's rows in the edge column and how it
## slopes per pixel outward (sprite pixels), for the left and the right.
var _shafts := [Vector3(-1, -1, 0), Vector3(-1, -1, 0)]


func _measure_shafts(tex: Texture2D) -> void:
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		return
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	for side in 2:
		var edge := 0 if side == 0 else w - 1
		var inner := 16 if side == 0 else w - 17
		var a := _shaft_rows(img, edge)
		var b := _shaft_rows(img, inner)
		if a.x < 0.0 or b.x < 0.0:
			continue
		_shafts[side] = Vector3(a.x, a.y, ((a.x + a.y) - (b.x + b.y)) * 0.5 / 16.0)


## The wooden rows in one column (not the grey sleeve): first and last.
static func _shaft_rows(img: Image, x: int) -> Vector2:
	var lo := -1
	var hi := -1
	for y in img.get_height():
		var c := img.get_pixel(x, y)
		if c.a > 0.5 and c.r - c.b > 0.1:
			if lo < 0:
				lo = y
			hi = y
	return Vector2(lo, hi)


## One oar's shaft from the hand's outer edge to the side of the screen, sloping as the
## oar swings in its rowlock.
func _draw_shaft(c: Control, side: int, tex: Texture2D) -> void:
	var r := c.get_parent() as TextureRect
	if r == null or tex == null:
		return
	var sh: Vector3 = _shafts[side]
	if sh.x < 0.0:
		return
	var src_h := float(tex.get_height())
	var k := r.size.y / src_h
	var u := float(_oar_u[side])
	var slope := sh.z + (0.0 if u < 0.0 else (BOAT_RIG.stroke_pose(u, int(_oar_dir[side])).x / 34.0) * 0.12)
	var src_x := 0.0 if side == 0 else float(tex.get_width() - 1)
	var rows := sh.y - sh.x + 1.0
	var vp := get_viewport().get_visible_rect().size
	var reach := int(ceil(((r.position.x if side == 0 else vp.x - r.position.x - r.size.x) + 8.0) / maxf(k, 0.01)))
	for i in range(1, reach + 1):
		var x := -float(i) * k if side == 0 else r.size.x + float(i - 1) * k
		var y := (sh.x + slope * float(i)) * k
		if y > r.size.y * 1.6:
			break
		c.draw_texture_rect_region(tex, Rect2(x, y, k, rows * k), Rect2(src_x, sh.x, 1, rows))


## The hands on the oars, twelve pictures a second like every hand in the game: each pushed
## away up the screen through its drive and brought back down to you on the recovery
## (backing water the other way round); resting on the oars when the boat glides; down out
## of the view when you look away or climb in and out.
func _update_hands(dt: float) -> void:
	if _hand.is_empty():
		return
	var want_up := 1.0
	if _moving or _state != ROWING or absf(_head_yaw) > deg_to_rad(48.0) or _head_pitch < deg_to_rad(-27.0) or _head_pitch > deg_to_rad(26.0):
		want_up = 0.0
	for h in _hand:
		if not bool((h as Control).get_meta("want", true)):
			want_up = 0.0
	_hands_up = move_toward(_hands_up, want_up, dt / 0.3)
	_hands_acc += dt
	if _hands_acc < 1.0 / 12.0:
		return
	_hands_acc = 0.0
	var vp := get_viewport().get_visible_rect().size
	var tex: Texture2D = (_hand[0] as TextureRect).texture.atlas if (_hand[0] as TextureRect).texture is AtlasTexture else null
	if tex == null:
		return
	# Half the screen's width at most (playtest 2026-10-17: the hands on the oars were
	# far too big, 4x at 1080p, filling most of the view).
	var k := float(maxi(1, int(round(vp.y / 560.0))))
	var hud = _main.get("_hud_manager") if _main != null else null
	var bar := float(hud.get_bar_height_px()) if hud != null and hud.has_method("get_bar_height_px") else 0.0
	var full := Vector2(tex.get_size()) * k
	var x0 := floorf((vp.x - full.x) * 0.5)
	var y0 := floorf(vp.y - bar - full.y * 0.78)
	var drop := (1.0 - smoothstep(0.0, 1.0, _hands_up)) * full.y * 1.05
	for side in 2:
		var r := _hand[side] as TextureRect
		r.visible = _hands_up > 0.01
		var o := _hand_offset(float(_oar_u[side]), int(_oar_dir[side]))
		var out := -1.0 if side == 0 else 1.0
		var reg: Rect2 = (r.texture as AtlasTexture).region
		var sz := (reg.size * k * o.z).floor()
		var base_x := x0 + reg.position.x * k
		# Scaled about the hand's middle, moved out or in and up or down.
		var pos := Vector2(base_x + (reg.size.x * k - sz.x) * 0.5 + o.x * out * k, y0 + (reg.size.y * k - sz.y) * 0.5 + o.y * k + drop)
		r.position = pos.floor()
		r.size = sz
		var sh := r.get_node_or_null("Shaft") as Control
		if sh != null:
			sh.size = r.size
			sh.queue_redraw()
	if _catch_card != null:
		_catch_card.size = Vector2(160, 160) * k
		_catch_card.position = ((vp - _catch_card.size) * 0.5).floor()


## A hand's place in its stroke (sprite pixels and a scale): out to the side (+), down
## (+), how big. Close to you and low at the catch, pushed up and away at the finish.
static func _hand_offset(u: float, dir: int) -> Vector3:
	if u < 0.0:
		return Vector3(1.0, 8.0, 1.0)
	var near := Vector3(5.0, 15.0, 1.05)
	var far := Vector3(-4.0, -17.0, 0.93)
	if dir < 0:
		var t := near
		near = far
		far = t
	if u < BOAT_RIG.RELEASE:
		return near.lerp(far, smoothstep(0.0, 1.0, u / BOAT_RIG.RELEASE))
	if u < BOAT_RIG.RECOVER:
		return far
	return far.lerp(near, smoothstep(0.0, 1.0, (u - BOAT_RIG.RECOVER) / (1.0 - BOAT_RIG.RECOVER)))


# ── for the night (night_row.gd) ─────────────────────────────────────────────

func _boat() -> Node3D:
	var lake = _lake_node()
	return lake.boat if lake != null else null


## The boat tips over to one side and rights itself.
func _lurch(z: float) -> void:
	var rig = _rig()
	if rig != null:
		rig.kick(z * 7.0, -absf(z) * 1.5, -0.05)


func _fog_density() -> float:
	var wv = _main.get("_weather_visuals")
	return float(wv.get("fog_boost")) if wv != null and wv.get("fog_boost") != null else 0.0


func _set_fog_density(v: float) -> void:
	var wv = _main.get("_weather_visuals")
	if wv != null:
		wv.set("fog_boost", v)


func _light_boathouse() -> void:
	var lake = _lake_node()
	if lake != null and lake.get("hut_window") != null:
		lake.hut_window.visible = true


func _play(file: String, db: float) -> void:
	if _one != null and ResourceLoader.exists(SFX + file):
		_one.stream = load(SFX + file)
		_one.volume_db = db
		_one.play()


func _say(text: String) -> void:
	var hud = _main.get("_hud_manager")
	if hud != null:
		hud.push_status(text, 1)


# ── co-op: one boat for two wardens (scripts/coop/coop.gd) ───────────────────

## The other warden has the boat (rowing, or tied up at the keeper's jetty): it is where
## they have it on this machine too, and not yours to take.
var _coop_boat_away := false


## Riding in the other warden's boat (they row, you sit in the bow facing them); across
## with them, ashore with them, back with them.
var _passenger := false
var _partner_ashore := false
var _partner_rowing := false
## Where the other warden's boat is to be (its transform as they sent it), and their oars
## [left phase, right phase, left way, right way] with when they came.
var _mirror_target = null
var _remote_rp: Array = []
var _remote_rp_at := 0.0


## The other warden is in the boat and it is still by the camp jetty, you beside it.
func _can_join() -> bool:
	if not _coop_boat_away or not _partner_rowing or not Coop.is_active():
		return false
	# One oarsman, one in the bow: the boat holds two.
	for id in Coop.others():
		if Coop.state_of(id).has("ride"):
			return false
	var lake = _lake_node()
	var p := _player()
	if lake == null or p == null or lake.boat == null:
		return false
	var b: Vector3 = (lake.boat as Node3D).global_position
	return p.global_position.distance_to(b) < 4.0 and b.distance_to(lake.boat_home.origin) < 8.0


func _start_passenger() -> void:
	var lake = _lake_node()
	var rig = _rig()
	if lake == null or rig == null:
		return
	var from_shore := _state == NONE
	_passenger = true
	_end_far_shore()
	_take_camera(rig)
	_head_yaw = 0.0
	_head_pitch = deg_to_rad(-4.0)
	var p := _player()
	if p != null and p.has_method("set_controls_enabled"):
		p.set_controls_enabled(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_ensure_overlay()
	_overlay.visible = true
	_set_hands_visible(false)
	for h in _hand:
		(h as Control).visible = false
	_lap.volume_db = -14.0
	_lap.play()
	_state = PASSENGER
	rig.kick(0.12 if _rng.randf() < 0.5 else -0.12, -0.05, -0.18)
	rig.play_sound("step_in.mp3" if ResourceLoader.exists(SFX + "step_in.mp3") else "bump.mp3", -2.0)
	if from_shore:
		_say("You climb into the bow. %s rows." % Coop.name_of(_rower_id))
	_move_cam(_bow_view(), BOARD_SEC, Callable())


func _update_passenger(_delta: float) -> void:
	if not _moving and _cam != null:
		_cam.transform = _bow_view()


## Where you are on the lake, for the other machine: {boat: the boat's transform, rp: its
## oars} while you row, {ride: the boat} in the bow of theirs, {shore: where you stand,
## boat_at: the boat tied up} on the keeper's side, {} when you are not on the trip.
func coop_state() -> Dictionary:
	var lake = _lake_node()
	if lake == null or lake.boat == null or _state == NONE or _state == LEAVING:
		return {}
	if _state == ROWING:
		return {"boat": (lake.boat as Node3D).global_transform,
			"rp": [snappedf(float(_oar_u[0]), 0.001), snappedf(float(_oar_u[1]), 0.001), int(_oar_dir[0]), int(_oar_dir[1])]}
	if _state == PASSENGER:
		return {"ride": (lake.boat as Node3D).global_transform}
	var shore := _far_spot() - Vector3(0.0, 1.45, 0.0)
	if _passenger:
		# Beside them on the jetty, the boat theirs.
		return {"shore": shore}
	return {"shore": shore, "boat_at": (lake.boat as Node3D).global_transform, "fish": _fish_state != ""}


## The other warden's boat: where they have it (`xf`), or back at the camp jetty
## (null) when they are home again; `ashore`: they are up on the keeper's jetty; `rp`
## their oars. Not while you row it; a passenger follows them in and out of it.
## Who of the others has the boat (peer id, 0 nobody).
var _rower_id := 0


func coop_mirror_boat(xf, ashore := false, rower := 0, rp = []) -> void:
	_rower_id = rower
	_partner_rowing = xf is Transform3D and not ashore
	_partner_ashore = xf is Transform3D and ashore
	if rp is Array and (rp as Array).size() >= 4:
		_remote_rp = (rp as Array).duplicate()
		_remote_rp_at = Time.get_ticks_msec() / 1000.0
	elif not _partner_rowing:
		_remote_rp = []
	if _passenger:
		if xf is Transform3D:
			_mirror_target = xf
		if not (xf is Transform3D):
			# Home (or gone home some other way): you get out at the camp jetty with them.
			_mirror_target = null
			_end_far_shore()
			if _state == PASSENGER and not _moving:
				_get_out()
			elif _state != LEAVING:
				_finish_trip()
		elif ashore and _state == PASSENGER:
			_begin_far_shore()
		elif not ashore and _state == FAR_SHORE:
			_start_passenger()
		return
	if _state != NONE:
		return
	var lake = _lake_node()
	if lake == null or lake.boat == null:
		return
	if xf is Transform3D:
		_mirror_target = xf
		_coop_boat_away = true
	elif _coop_boat_away:
		_mirror_target = null
		(lake.boat as Node3D).transform = lake.boat_home
		var rig = _rig()
		if rig != null:
			rig.set_manned(false)
			rig.set_motion(0.0, 0.0, 0.0)
		_coop_boat_away = false


## The other warden's boat on this machine: eased to where they have it (their states come
## a dozen times a second), their oars stroking from the phases they sent, carried on by
## the clock since.
func _mirror_tick(delta: float) -> void:
	if _state == ROWING or not (_mirror_target is Transform3D):
		return
	if not (_coop_boat_away or _passenger):
		return
	var lake = _lake_node()
	var rig = _rig()
	if lake == null or rig == null:
		return
	var boat := lake.boat as Node3D
	var t: Transform3D = _mirror_target
	var k := 1.0 - exp(-10.0 * clampf(delta, 0.0, 0.1))
	var prev := boat.global_position
	var p := prev.lerp(t.origin, k)
	if p.distance_to(t.origin) > 8.0:
		p = t.origin
	boat.global_position = p
	var y := lerp_angle(boat.rotation.y, t.basis.get_euler().y, k)
	var dy := angle_difference(boat.rotation.y, y)
	boat.rotation = Vector3(0.0, y, 0.0)
	rig.set_manned(_partner_rowing)
	var age := Time.get_ticks_msec() / 1000.0 - _remote_rp_at
	for side in 2:
		var u := float(_remote_rp[side]) if _remote_rp.size() >= 4 else -1.0
		if u >= 0.0:
			u = fposmod(u + age / BOAT_RIG.PERIOD, 1.0)
		var d := int(_remote_rp[side + 2]) if _remote_rp.size() >= 4 else 1
		rig.set_oar(side, u if _partner_rowing else -1.0, d)
	var dt := maxf(delta, 0.001)
	var v := (p - prev) / dt
	rig.set_motion(v.dot(Vector3(sin(y), 0.0, cos(y))), dy / dt, 0.0)
