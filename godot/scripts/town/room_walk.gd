extends RefCounted

## Walking in a place's room (town_room.gd), the way a point-and-click adventure walks you
## to what you clicked (the user, 4. 11.: "it should feel like a clicking horror adventure"):
## the eye goes on foot from spot to spot along the room's ways, at a walker's pace with
## a step's bob and the footsteps, turned along the way and, coming up to the last spot,
## to what it went there for; then the thing is done. Clicks wait till you are there.
##
##   spots  name -> {"at": the eye (room space), "rot": the look there (pitch, yaw, 0)}
##   ways   [[a, b], ...]: the spots you can walk straight between (both ways).

var room
var spots: Dictionary = {}
var ways: Array = []
var here := ""
var busy := false
var speed := 1.15
var _steps: AudioStreamPlayer
var _path: Array = []          # eye positions, the start first
## The way as it is walked: the spots' straight lines with their corners rounded off, points
## a few cm apart, and how far along each one is (the user 9. 11.: "the motel's movement as
## in the chapel, it is really terrible"; the chapel's ways are straight, the motel's turn
## corners and the view jumped 90 degrees in a frame at each).
var _curve: Array = []
var _dist: Array = []
var _total := 0.0
var _dur := 1.0
## What the head does on the way: where it faces (no jump at a corner, whatever the way
## does), where the way ahead lies, and how long it turns before the feet set off.
var _yaw := 0.0
var _pitch := 0.0
var _way_yaw := 0.0
var _lead := 0.0
var _from_rot := Vector3.ZERO
var _end_rot := Vector3.ZERO
var _then: Callable
var _t := 0.0
var _tw: Tween
## The floor's lit places (floor_spots): walked to by a click, "walk:<spot>".
var _floor: Dictionary = {}
## Each patch's own spot (a stair's patch walks you elsewhere, but stands where it stands).
var _floor_of: Dictionary = {}
const EYE := 1.6
## A corner's radius on the way, at most (and under half of the shorter leg's length).
const CORNER := 0.55
const CORNER_STEPS := 8
## How far ahead along the way the head already looks.
const LOOK_AHEAD := 0.65
## The head turning to the way: how fast it closes on it, and its top speed.
const TURN_RATE := 7.0
const TURN_DEG := 240.0
## Over the last of the way the head comes round to what you went there for (metres).
const SETTLE_M := 1.05
## A turn behind you: the head goes first, the feet after it (from this angle on, at most).
const LEAD_FROM_DEG := 70.0
const LEAD_SEC := 0.32
## Told where you set off to (co-op: the other wardens see you go).
var on_go: Callable


func _init(p_room, p_spots: Dictionary, p_ways: Array, start: String, steps_path := "res://assets/sfx/rooms/steps_wood.mp3", steps_db := -15.0) -> void:
	room = p_room
	spots = p_spots
	ways = p_ways
	here = start
	_steps = AudioStreamPlayer.new()
	_steps.volume_db = steps_db
	if ResourceLoader.exists(steps_path):
		var s = load(steps_path)
		if s is AudioStreamMP3:
			s = (s as AudioStreamMP3).duplicate()
			s.loop = true
		_steps.stream = s
	room.add_child(_steps)
	room.walker = self
	# All the way round (the user 6. 11.: "I cannot turn to the side for ever, I run into a
	# stop"): Liblice's rooms you walk about in are not a desk.
	room._look.yaw_limit_deg = 180.0


func at_rot(name: String) -> Vector3:
	return (spots.get(name, {}) as Dictionary).get("rot", Vector3.ZERO)


func at_pos(name: String) -> Vector3:
	return (spots.get(name, {}) as Dictionary).get("at", Vector3.ZERO)


## The spots from here to `to` along the ways (here not in it); [to] if no way leads there.
func path_to(to: String) -> Array:
	return route(spots, ways, here, to)


## The same for anybody (the other wardens' figures: a walker made for that took the room's
## place as ITS walker, its steps freed: every click on the floor in co-op was an error after
## the other warden had gone anywhere).
static func route(p_spots: Dictionary, p_ways: Array, from: String, to: String) -> Array:
	if to == from or not p_spots.has(to):
		return []
	var prev := {from: ""}
	var queue: Array = [from]
	while not queue.is_empty():
		var s: String = queue.pop_front()
		if s == to:
			break
		for w in p_ways:
			var nb := ""
			if str(w[0]) == s:
				nb = str(w[1])
			elif str(w[1]) == s:
				nb = str(w[0])
			if nb != "" and not prev.has(nb):
				prev[nb] = s
				queue.append(nb)
	if not prev.has(to):
		return [to]
	var out: Array = []
	var c := to
	while c != from:
		out.push_front(c)
		c = str(prev[c])
	return out


## On foot to spot `to`, then `then`. `look` (pitch, yaw, 0) turns you at the end to what
## you went for instead of the spot's own look.
## From where you are looking (the user 6. 11.: "whenever I click somewhere the figure
## turns, and the turned look on top of it: it tears the picture"): the head's turn is taken
## into the base first, then the walk turns from there, the short way round, the head held.
func go(to: String, then := Callable(), look = null) -> void:
	if busy:
		return
	_take_look()
	var legs := path_to(to)
	var end_rot: Vector3 = look if look != null else at_rot(to)
	if legs.is_empty():
		_turn(end_rot, then)
		return
	_path = [room._cam.position]
	for s in legs:
		_path.append(at_pos(str(s)))
	_round_corners()
	here = to
	if on_go.is_valid():
		on_go.call(to)
	_from_rot = room._base_rot
	_end_rot = end_rot
	_then = then
	busy = true
	room._look.hold = true
	_t = 0.0
	_yaw = _from_rot.y
	_pitch = _from_rot.x
	_way_yaw = _ahead_yaw(0.0, _end_rot.y)
	_lead = LEAD_SEC * clampf((absf(rad_to_deg(angle_difference(_yaw, _way_yaw))) - LEAD_FROM_DEG) / (180.0 - LEAD_FROM_DEG), 0.0, 1.0)
	if _steps.stream != null:
		_steps.play()
	_dur = clampf(_total / speed, 0.4, 9.0) + _lead
	_tw = room.create_tween()
	_tw.tween_method(_walk, 0.0, 1.0, _dur)
	_tw.tween_callback(_arrive)


## Just turned where you stand (to what you clicked), the short way round.
func _turn(rot: Vector3, then: Callable) -> void:
	busy = true
	room._look.hold = true
	var from: Vector3 = room._base_rot
	_tw = room.create_tween()
	_tw.tween_method(func(k: float):
		var e := k * k * (3.0 - 2.0 * k)
		room._base_rot = Vector3(lerpf(from.x, rot.x, e), lerp_angle(from.y, rot.y, e), 0.0), 0.0, 1.0, 0.45)
	_tw.tween_callback(func():
		busy = false
		room._look.hold = false
		if then.is_valid():
			then.call())


## The head's own turn taken into where you face: the picture does not move.
func _take_look() -> void:
	var lk = room._look
	room._base_rot = Vector3(clampf(room._base_rot.x + deg_to_rad(lk.pitch_deg), deg_to_rad(-60.0), deg_to_rad(60.0)), wrapf(room._base_rot.y + deg_to_rad(lk.yaw_deg), -PI, PI), 0.0)
	lk.yaw_deg = 0.0
	lk.pitch_deg = 0.0


## The places on the floor you walk to by clicking them (the user 6. 11.: "click hover-lit
## places, on the floor in front of the doors, up the stairs"): under each spot named, a
## patch of floor that lights up under the pointer like any thing. `stairs`: spot -> the
## spot a click on its patch walks to instead (a stair's patch takes you up or down).
func floor_spots(names: Array, size := Vector2(0.9, 0.9), stairs := {}) -> void:
	for n in names:
		if not spots.has(n):
			continue
		var at := at_pos(str(n))
		var floor_y := at.y - EYE
		var q := QuadMesh.new()
		q.size = size
		q.orientation = PlaneMesh.FACE_Y
		var mi := MeshInstance3D.new()
		mi.name = "Floor_" + str(n)
		mi.mesh = q
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1, 1, 1, 0)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(at.x, floor_y + 0.03, at.z)
		room._root.add_child(mi)
		var id := "walk:" + str(stairs.get(n, n))
		if room._hot.has(id):
			id += "#" + str(n)
		room._hot_box(id, Vector3(at.x, floor_y + 0.04, at.z), Vector3(size.x, 0.08, size.y), [mi])
		_floor[n] = mi
		_floor_of[id] = str(n)


## A lit place on the floor clicked: on foot there, looking the way you went.
func go_floor(to: String) -> void:
	to = to.get_slice("#", 0)
	if busy or to == here or not spots.has(to):
		return
	_take_look()
	var legs := path_to(to)
	var last: Vector3 = at_pos(str(legs[legs.size() - 2])) if legs.size() > 1 else (room._cam.position as Vector3)
	var way: Vector3 = at_pos(to) - last
	var look = null
	# Over a last step of any length you go on looking the way you came; a short one at a
	# stair's head turns you to the spot's own look (not at the corner it points to).
	if Vector2(way.x, way.z).length() > 1.0:
		look = Vector3(deg_to_rad(-6.0) if absf(way.y) < 0.3 else at_rot(to).x, atan2(-way.x, -way.z), 0.0)
	go(to, Callable(), look)


## Can this floor's patch be clicked from where you are (not through a ceiling)?
func floor_near(id: String) -> bool:
	var n := str(_floor_of.get(id, id.trim_prefix("walk:").get_slice("#", 0)))
	if not spots.has(n):
		return true
	return absf(at_pos(n).y - room._cam.position.y) < 1.9


## Put at a spot at once (the room opened there, a debug step). `rot` where you face if not
## the spot's own look: a spot's look is for walking up to it, and coming in through a door
## you face the way you were going, not the door behind you (the user 9. 11.: "I go back
## through to the reception and all at once I am facing backwards").
func put(name: String, rot = null) -> void:
	here = name
	room._cam.position = at_pos(name)
	room._base_rot = rot if rot != null else at_rot(name)


## The spots' straight lines (`_path`) as they are walked: each corner cut by a curve.
func _round_corners() -> void:
	_curve = [_path[0]]
	for i in range(1, _path.size() - 1):
		var a: Vector3 = _path[i - 1]
		var c: Vector3 = _path[i]
		var b: Vector3 = _path[i + 1]
		var r := minf(CORNER, minf(a.distance_to(c), c.distance_to(b)) * 0.45)
		var p0 := c + (a - c).normalized() * r
		var p1 := c + (b - c).normalized() * r
		for s in CORNER_STEPS + 1:
			var u := float(s) / float(CORNER_STEPS)
			_curve.append(p0.lerp(c, u).lerp(c.lerp(p1, u), u))
	_curve.append(_path.back())
	_dist = [0.0]
	for j in range(1, _curve.size()):
		_dist.append(float(_dist[j - 1]) + (_curve[j] as Vector3).distance_to(_curve[j - 1]))
	_total = float(_dist.back())


## Where you are `d` metres along the way.
func _point(d: float) -> Vector3:
	var i := clampi(_dist.bsearch(d), 1, _dist.size() - 1)
	var from: float = _dist[i - 1]
	var leg := maxf(0.0001, float(_dist[i]) - from)
	return (_curve[i - 1] as Vector3).lerp(_curve[i], clampf((d - from) / leg, 0.0, 1.0))


## Which way the way lies from `d` metres along it, `or_else` when it is at its end.
func _ahead_yaw(d: float, or_else: float) -> float:
	var ahead := _point(minf(d + LOOK_AHEAD, _total)) - _point(d)
	return atan2(-ahead.x, -ahead.z) if Vector2(ahead.x, ahead.z).length() > 0.02 else or_else


func _walk(k: float) -> void:
	var dt := maxf(0.0, k - _t) * _dur
	_t = k
	# The feet set off once the head has gone first (a turn behind you), then eased in and
	# out over the whole way, an even pace between.
	var f := clampf((k * _dur - _lead) / maxf(0.001, _dur - _lead), 0.0, 1.0)
	var e := f * f * (3.0 - 2.0 * f) if _total < 1.2 else _even(f)
	var dist := e * _total
	var at := _point(dist)
	# A step's bob, gone as you stop.
	at.y += sin(f * _total / speed * TAU * 1.8) * 0.016 * sin(f * PI)
	room._cam.position = at
	# The head follows the way a little ahead of the feet, at a head's pace, so a corner is
	# a turn and never a jump; over the last of the way it comes round to what you came for.
	_way_yaw = _ahead_yaw(dist, _way_yaw)
	var rate := 1.0 - exp(-TURN_RATE * dt)
	var limit := deg_to_rad(TURN_DEG) * dt
	_yaw += clampf(angle_difference(_yaw, _way_yaw) * rate, -limit, limit)
	var ahead := _point(minf(dist + LOOK_AHEAD, _total)) - at
	var slope := atan2(ahead.y, maxf(0.05, Vector2(ahead.x, ahead.z).length())) * 0.45
	_pitch += (deg_to_rad(-5.0) + slope - _pitch) * rate
	var settle := 1.0 - clampf((_total - dist) / maxf(0.05, minf(SETTLE_M, _total * 0.6)), 0.0, 1.0)
	settle = settle * settle * (3.0 - 2.0 * settle)
	room._base_rot = Vector3(lerpf(_pitch, _end_rot.x, settle), lerp_angle(_yaw, _end_rot.y, settle), 0.0)


## Smooth start and stop (the first and last fifth), even between.
static func _even(k: float) -> float:
	var a := 0.2
	if k < a:
		return k * k / (2.0 * a * (1.0 - a))
	if k > 1.0 - a:
		var r := 1.0 - k
		return 1.0 - r * r / (2.0 * a * (1.0 - a))
	return (k - a * 0.5) / (1.0 - a)


func _arrive() -> void:
	busy = false
	room._look.hold = false
	_steps.stop()
	room._cam.position = _path.back()
	room._base_rot = _end_rot
	if _then.is_valid():
		var t := _then
		_then = Callable()
		t.call()


func stop() -> void:
	busy = false
	if room != null and room.get("_look") != null:
		room._look.hold = false
	if _tw != null and _tw.is_valid():
		_tw.kill()
	if _steps != null and is_instance_valid(_steps):
		_steps.stop()


func free_all() -> void:
	if _steps != null and is_instance_valid(_steps):
		_steps.queue_free()
