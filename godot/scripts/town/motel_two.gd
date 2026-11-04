extends RefCounted

## Number two, the hunters' room (motel_furnish.gd builds it, motel_view.gd keeps its door,
## bathroom, bed and night): twelve dollars and the stove works.
##   the stove    embers when you come in after dark, a log on them and it draws, the light
##                moving on the panelling; let it go out and only the pipe ticks;
##   the cuckoo   strikes the hours, and after midnight not always the right number; it runs
##                down if nobody pulls its chain;
##   the owl      on the gun cabinet, looks somewhere else whenever you were not looking;
##   the guns     locked; the glass rattles, and now and then rattles again without you;
##   the radio    the valve set on the table, slow to come up;
##   by itself    (what wakes you as the set does in four) the valves warming up in the dark.

const PLAN = preload("res://scripts/town/motel_plan.gd")
const K = preload("res://scripts/interior_kit.gd")
const FURN = preload("res://scripts/town/motel_furnish.gd")
const ROOMS = preload("res://scripts/town/motel_rooms.gd")
const SFX := "res://assets/sfx/"
const CAMP := "res://assets/textury/camp/"
## A log's seconds on the fire; the clock's seconds from a pull of the chain.
const LOG_SEC := 170.0
const WOUND_SEC := 600.0

var view                         # motel_view.gd
var room                         # town_room.gd
var parts: Dictionary
var fire := 0.0                  # 0 out .. 1 roaring
var wound := 1.0
var _t := 0.0
var _flame: MeshInstance3D
var _frames: Array = []
var _light: OmniLight3D
var _crackle: AudioStreamPlayer
var _ticks: AudioStreamPlayer
var _pipe_t := 25.0
var _owl: MeshInstance3D
var _turned := false
var _owl_t := 18.0
var _hour := -1
var _left := 0
var _call_t := 0.0
var _bird: MeshInstance3D
var _bird_at := Vector3.ZERO
var _rng := RandomNumberGenerator.new()


func _init(p_view, p_room) -> void:
	view = p_view
	room = p_room
	parts = view.parts
	_rng.randomize()


func radio_voice() -> String:
	return "tube"


func spots() -> Dictionary:
	var r := func(p: float, y: float) -> Vector3: return Vector3(deg_to_rad(p), deg_to_rad(y), 0.0)
	return {
		"aisle": {"at": Vector3(0.82, 1.6, 0.05), "rot": r.call(-8.0, 0.0)},
		"window": {"at": Vector3(0.68, 1.6, -1.4), "rot": r.call(-4.0, 0.0)},
		"radio": {"at": Vector3(0.6, 1.6, -1.12), "rot": r.call(-26.0, -52.0)},
		"stove": {"at": Vector3(0.05, 1.6, -1.1), "rot": r.call(-36.0, 90.0)},
		"guns": {"at": Vector3(0.45, 1.6, -0.4), "rot": r.call(-2.0, -90.0)},
		"cuckoo": {"at": Vector3(0.72, 1.6, 0.92), "rot": r.call(1.0, -90.0)},
		"bedfoot": {"at": Vector3(-0.55, 1.6, -0.12), "rot": r.call(-16.0, 180.0)},
	}


func ways() -> Array:
	return [["room", "cuckoo"], ["room", "aisle"], ["cuckoo", "aisle"], ["aisle", "window"], ["aisle", "radio"],
		["window", "radio"], ["aisle", "guns"], ["guns", "radio"], ["aisle", "bedfoot"], ["bedfoot", "stove"],
		["stove", "window"], ["stove", "guns"]]


func from_bed() -> Array:
	return ["phone", "lamps"]


func things(hour: float) -> void:
	var w := PLAN.ROOM_W
	var sa := FURN.STOVE_AT
	var sz := FURN.STOVE_SIZE
	room._hot_box("stove", sa + Vector3(sz.x * 0.5 + 0.03, sz.y * 0.5, 0), Vector3(0.1, sz.y, sz.z), [])
	if parts.get("guns") != null:
		room._hot_box("guns", Vector3(w * 0.5 - 0.1, 0.95, -0.4), Vector3(0.12, 1.85, 0.8), [parts["guns"]])
	_owl = parts.get("owl")
	if _owl != null:
		room._hot_box("owl", _owl.position + Vector3(0, 0.25, 0), Vector3(0.3, 0.5, 0.3), [_owl])
	var ck: MeshInstance3D = parts.get("cuckoo")
	if ck != null:
		room._hot_box("cuckoo", ck.position + Vector3(-0.04, 0.4, 0), Vector3(0.08, 0.8, 0.42), [ck])
		if ResourceLoader.exists(CAMP + "cuckoo_bird.png"):
			_bird_at = ck.position + Vector3(-0.03, 0.26, 0)
			_bird = K.cutout(room._root, "cuckoo_bird", ROOMS._sprite_size("cuckoo_bird", 0.1), _bird_at, -90.0, false, "CuckooBird")
			_bird.visible = false
	if parts.get("radio") != null:
		room._hot_box("radio", FURN.TABLE_AT + Vector3(0, 0.85, 0), Vector3(0.5, 0.32, 0.42), [parts["radio"]])
	room._hot_box("boar", Vector3(0.28, 0.03, -0.7), Vector3(1.6, 0.06, 0.85), [])
	# The fire behind the stove's little door.
	for i in 3:
		var path := CAMP + "stove_fire_%d.png" % i
		if ResourceLoader.exists(path):
			_frames.append(load(path))
	var fa: Vector3 = parts.get("flame_at", sa)
	if _frames.size() == 3:
		_flame = MeshInstance3D.new()
		_flame.name = "Flame"
		var q := QuadMesh.new()
		q.size = Vector2(0.46, 0.46)
		_flame.mesh = q
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.albedo_texture = _frames[0]
		_flame.material_override = m
		_flame.position = fa
		_flame.rotation.y = PI * 0.5
		_flame.set_meta("retro_skip", true)
		room._root.add_child(_flame)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.56, 0.26)
	_light.omni_range = 4.6
	_light.omni_attenuation = 1.2
	_light.shadow_enabled = true
	_light.position = fa + Vector3(0.45, 0.1, 0)
	room._root.add_child(_light)
	_crackle = view._player(-60.0)
	_ticks = view._player(-30.0)
	view._loop_on(_ticks, "motel/clock_tick.ogg", -29.0)
	# After dark Simek has lit it for you, and not much.
	fire = 0.38 if view._night(hour) else 0.0
	_hour = -1


func click(id: String) -> bool:
	match id:
		"stove":
			view._walker.go("stove", func(): _feed())
		"owl":
			view._walker.go("guns", func(): view._look_at("owl"))
		"guns":
			view._walker.go("guns", func():
				view._fx_play("motel/gun_rattle.mp3", -7.0)
				if _rng.randf() < 0.18 + 0.5 * view._low():
					room.get_tree().create_timer(_rng.randf_range(1.8, 3.2)).timeout.connect(func():
						if view._alive():
							view._play("motel/gun_rattle.mp3", -15.0)))
		"cuckoo":
			view._walker.go("cuckoo", func():
				wound = 1.0
				view._play("motel/cuckoo_wind.mp3", -8.0)
				view._loop_on(_ticks, "motel/clock_tick.ogg", -29.0))
		"radio":
			view._walker.go("radio", func(): view.radio.toggle())
		"boar":
			view._walker.go("aisle", func(): view._look_at("boar"))
		_:
			return false
	return true


func _feed() -> void:
	view._fx_play("motel/stove_door.mp3", -8.0)
	room.get_tree().create_timer(0.7).timeout.connect(func():
		if not view._alive():
			return
		view._play("motel/stove_log.mp3", -6.0)
		fire = minf(1.0, fire + 0.62))


func tick(delta: float) -> void:
	_t += delta
	_tick_fire(delta)
	_tick_owl(delta)
	_tick_cuckoo(delta)


func _tick_fire(delta: float) -> void:
	fire = maxf(0.0, fire - delta / LOG_SEC)
	var k := floorf(_t * 7.0)
	if fire <= 0.0:
		if _flame != null:
			_flame.visible = false
		_light.visible = false
		if _crackle.playing:
			_crackle.stop()
		_pipe_t -= delta
		if _pipe_t <= 0.0:
			_pipe_t = _rng.randf_range(30.0, 70.0)
			if not view.asleep:
				view._play("motel/stove_tick.mp3", -20.0)
		return
	var idx := 0
	if fire >= 0.55:
		idx = 1 + int(k) % 2
	elif fire >= 0.2:
		idx = int(k) % 2
	if _flame != null:
		_flame.visible = true
		(_flame.material_override as StandardMaterial3D).albedo_texture = _frames[idx]
	_light.visible = true
	_light.light_energy = (0.2 + fire * 1.15) * (0.84 + 0.16 * sin(k * 1.7))
	view._loop_on(_crackle, "motel/stove_fire.ogg", lerpf(-30.0, -17.0, fire))


## The owl looks somewhere else, whenever you were not looking.
func _tick_owl(delta: float) -> void:
	if _owl == null:
		return
	_owl_t -= delta
	if _owl_t > 0.0:
		return
	if room._cam.is_position_in_frustum(_owl.global_position + Vector3(0, 0.25, 0)):
		_owl_t = 0.6
		return
	_owl_t = _rng.randf_range(14.0, 48.0) * (1.0 - 0.6 * view._low())
	_set_owl(not _turned)


func _set_owl(on: bool) -> void:
	_turned = on
	var path := CAMP + ("stuffed_owl_turned.png" if on else "stuffed_owl.png")
	if _owl != null and ResourceLoader.exists(path):
		(_owl.material_override as StandardMaterial3D).albedo_texture = load(path)


## The hours from the wall, wrong after midnight the worse you are.
func _tick_cuckoo(delta: float) -> void:
	if wound > 0.0:
		wound = maxf(0.0, wound - delta / WOUND_SEC)
		if wound <= 0.0 and _ticks.playing:
			_ticks.stop()
	var hh := int(view._now()) % 24
	if _hour < 0:
		_hour = hh
	if hh != _hour:
		_hour = hh
		if wound > 0.0 and not view.asleep:
			_left = hh % 12 if hh % 12 != 0 else 12
			if hh < 5 and _rng.randf() < 0.25 + 0.6 * view._low():
				_left += _rng.randi_range(1, 3)
			_call_t = 0.6
			view._play("motel/cuckoo_door.mp3", -14.0)
			if _bird != null:
				_bird.visible = true
				_bird.position = _bird_at + Vector3(-0.07, 0, 0)
	if _left > 0:
		_call_t -= delta
		if _call_t <= 0.0:
			_call_t = 1.3
			_left -= 1
			view._play("motel/cuckoo.mp3", -9.0)
			if _bird != null:
				var tw: Tween = room.create_tween()
				tw.tween_property(_bird, "position:x", _bird_at.x - 0.11, 0.12)
				tw.tween_property(_bird, "position:x", _bird_at.x - 0.07, 0.2)
				if _left == 0:
					tw.tween_interval(0.6)
					tw.tween_callback(func():
						_bird.visible = false
						view._play("motel/cuckoo_door.mp3", -16.0))


## What in four is the set coming on by itself: the valves warming up in the dark.
func set_by_itself() -> void:
	view.radio.set_on(true, true)
	view._play("motel/tube_warm.mp3", -14.0)


func woken(_kind: String) -> void:
	_set_owl(true)


func morning(_hour_now: float) -> void:
	fire = 0.0
	_set_owl(_rng.randf() < 0.5)


func state() -> Array:
	return [int(fire * 5.0), _turned]


func take(st: Array, _quiet: bool) -> void:
	if st.size() < 2:
		return
	var f := float(st[0]) / 5.0
	if absf(f - fire) > 0.21:
		fire = f
	if bool(st[1]) != _turned:
		_set_owl(bool(st[1]))


func walked(_to: String) -> void:
	pass


func close() -> void:
	_frames.clear()
