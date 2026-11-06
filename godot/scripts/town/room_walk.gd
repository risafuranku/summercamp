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
var _lens: Array = []          # each leg's length
var _total := 0.0
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
	if to == here or not spots.has(to):
		return []
	var prev := {here: ""}
	var queue: Array = [here]
	while not queue.is_empty():
		var s: String = queue.pop_front()
		if s == to:
			break
		for w in ways:
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
	while c != here:
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
	_lens = []
	_total = 0.0
	for s in legs:
		var p := at_pos(str(s))
		_lens.append((_path.back() as Vector3).distance_to(p))
		_total += float(_lens.back())
		_path.append(p)
	here = to
	if on_go.is_valid():
		on_go.call(to)
	_from_rot = room._base_rot
	_end_rot = end_rot
	_then = then
	busy = true
	room._look.hold = true
	_t = 0.0
	if _steps.stream != null:
		_steps.play()
	var dur := clampf(_total / speed, 0.4, 9.0)
	_tw = room.create_tween()
	_tw.tween_method(_walk, 0.0, 1.0, dur)
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
	if Vector2(way.x, way.z).length() > 0.3:
		look = Vector3(deg_to_rad(-6.0) if absf(way.y) < 0.3 else at_rot(to).x, atan2(-way.x, -way.z), 0.0)
	go(to, Callable(), look)


## Can this floor's patch be clicked from where you are (not through a ceiling)?
func floor_near(id: String) -> bool:
	var n := str(_floor_of.get(id, id.trim_prefix("walk:").get_slice("#", 0)))
	if not spots.has(n):
		return true
	return absf(at_pos(n).y - room._cam.position.y) < 1.9


## Put at a spot at once (the room opened there, a debug step).
func put(name: String) -> void:
	here = name
	room._cam.position = at_pos(name)
	room._base_rot = at_rot(name)


func _walk(k: float) -> void:
	_t = k
	# Eased in and out over the whole way, an even pace between.
	var e := k * k * (3.0 - 2.0 * k) if _total < 1.2 else _even(k)
	var dist := e * _total
	var i := 0
	while i < _lens.size() - 1 and dist > float(_lens[i]):
		dist -= float(_lens[i])
		i += 1
	var a: Vector3 = _path[i]
	var b: Vector3 = _path[i + 1]
	var leg := maxf(0.001, float(_lens[i]))
	var at := a.lerp(b, clampf(dist / leg, 0.0, 1.0))
	# A step's bob, gone as you stop.
	at.y += sin(k * _total / speed * TAU * 1.8) * 0.016 * sin(k * PI)
	room._cam.position = at
	var way := b - a
	var way_yaw := atan2(-way.x, -way.z) if Vector2(way.x, way.z).length() > 0.01 else _end_rot.y
	# Turning to the way takes longer the further round it is (a half turn is not a flick).
	var turn := clampf(k / clampf(0.12 + 0.3 * absf(angle_difference(_from_rot.y, way_yaw)) / PI, 0.12, 0.42), 0.0, 1.0)
	var settle := clampf((k - 0.7) / 0.3, 0.0, 1.0)
	settle = settle * settle * (3.0 - 2.0 * settle)
	var yaw := lerp_angle(lerp_angle(_from_rot.y, way_yaw, turn), _end_rot.y, settle)
	var pitch := lerpf(lerpf(_from_rot.x, deg_to_rad(-5.0), turn), _end_rot.x, settle)
	room._base_rot = Vector3(pitch, yaw, 0.0)


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
