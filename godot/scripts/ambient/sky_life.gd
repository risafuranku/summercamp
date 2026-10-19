extends Node3D

## Life in the air round you, outdoors, as Build sprites moved in steps (12 a second):
##   - by day, now and then a flock of small birds goes over high up, wings beating in
##     two frames, now and then one gliding; a rush of wings as they pass;
##   - at dusk crows go over to their roost, bigger, slower, cawing;
##   - after dark bats flit round the nearest lit lamp (or above you), and moths dance
##     round every lit lamp near you;
##   - at night an owl sits on one of the trees near you (Grok sprite), hoots now and
##     then, its eyes catching the light in the dark; come too close and it is gone.
## It follows the player wherever they are (the camp, the road, Lesna). Not while you are
## in a room. Made by InteriorManager.setup() in the camp's world.

const FPS := 12.0
const SFX := "res://assets/sfx/life/"

var player_getter: Callable
## Callable() -> bool: you are in a room / close-up (the sky waits).
var indoors: Callable

var _rng := RandomNumberGenerator.new()
var _tex: Dictionary = {}
var _flocks: Array = []          # {birds: [{sprite, off, phase}], from, dir, t, length, speed, kind}
var _next_flock := 25.0
var _bats: Array = []            # {sprite, a, r, h, phase}
var _moths: Array = []           # {sprite, lamp}
var _tick := 0.0
var _acc := 0.0
var _lamp_poll := 0.0
var _lamps: Array = []
var _audio: AudioStreamPlayer3D
const OWL_TEX := "res://assets/textury/world/owl.png"
## The birds, crows, bats and moths (Grok, two wing beats each): assets/textury/world/sky_*.png.
const SKY_TEX := "res://assets/textury/world/sky_%s.png"
const OWL_EYES := "res://assets/textury/world/owl_eyes.png"
var _owl: Sprite3D
var _owl_eyes: Sprite3D
var _owl_snd: AudioStreamPlayer3D
var _owl_t := 8.0
var _owl_hoot := 20.0


func _ready() -> void:
	name = "SkyLife"
	_rng.randomize()
	for k in ["bird_up", "bird_down", "crow_up", "crow_down", "bat_up", "bat_down", "moth"]:
		var path := SKY_TEX % k
		_tex[k] = load(path) if ResourceLoader.exists(path) else null
	_audio = AudioStreamPlayer3D.new()
	_audio.unit_size = 20.0
	_audio.max_distance = 160.0
	add_child(_audio)


## A creature `width` metres across, wings spread (its picture however many pixels wide).
func _sprite(tex_key: String, width: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = _tex[tex_key]
	s.pixel_size = width / float(maxi(1, s.texture.get_width())) if s.texture != null else 0.1
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = false
	s.double_sided = true
	add_child(s)
	return s


func _player() -> Node3D:
	return player_getter.call() as Node3D if player_getter.is_valid() else null


func _hour() -> float:
	var main := get_tree().current_scene
	return float(main.get("_time_of_day_hours")) if main != null and main.get("_time_of_day_hours") != null else 12.0


func _process(delta: float) -> void:
	var p := _player()
	var inside: bool = indoors.is_valid() and bool(indoors.call())
	visible = p != null and not inside
	if not visible:
		return
	_tick += delta
	var h := _hour()
	var night := h >= 20.4 or h < 5.4
	var dusk := h >= 18.2 and h < 20.4
	# Flocks by day, crows at dusk.
	_next_flock -= delta
	if _next_flock <= 0.0 and not night:
		_next_flock = _rng.randf_range(35.0, 110.0) if not dusk else _rng.randf_range(20.0, 50.0)
		_spawn_flock(p.global_position, "crow" if dusk else "bird")
	_update_flocks(delta)
	_acc += delta
	if _acc < 1.0 / FPS:
		return
	_acc = 0.0
	_update_bats(p.global_position, night)
	_update_moths(p.global_position, night)
	_update_owl(p.global_position, night, 1.0 / FPS)


# ── the owl ──────────────────────────────────────────────────────────────────

func _update_owl(at: Vector3, night: bool, dt: float) -> void:
	if not ResourceLoader.exists(OWL_TEX):
		return
	if _owl == null:
		_owl = Sprite3D.new()
		_owl.texture = load(OWL_TEX)
		_owl.pixel_size = 0.009
		_owl.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		_owl.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_owl.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		_owl.shaded = true
		_owl.visible = false
		add_child(_owl)
		if ResourceLoader.exists(OWL_EYES):
			_owl_eyes = Sprite3D.new()
			_owl_eyes.texture = load(OWL_EYES)
			_owl_eyes.pixel_size = 0.0035
			_owl_eyes.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			_owl_eyes.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			_owl_eyes.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			_owl_eyes.shaded = false
			_owl_eyes.modulate = Color(1.4, 1.2, 0.8)
			_owl_eyes.no_depth_test = false
			_owl.add_child(_owl_eyes)
		_owl_snd = AudioStreamPlayer3D.new()
		if ResourceLoader.exists(SFX + "owl_hoot.mp3"):
			_owl_snd.stream = load(SFX + "owl_hoot.mp3")
		_owl_snd.volume_db = -6.0
		_owl_snd.unit_size = 8.0
		_owl_snd.max_distance = 90.0
		add_child(_owl_snd)
	if not night:
		_owl.visible = false
		return
	# Too close: it is off (a rush of wings), and sits somewhere else a while later.
	if _owl.visible and Vector2(_owl.global_position.x - at.x, _owl.global_position.z - at.z).length() < 6.0:
		_owl.visible = false
		_owl_t = _rng.randf_range(20.0, 45.0)
		if _audio != null and ResourceLoader.exists(SFX + "flock_over.mp3"):
			_audio.stream = load(SFX + "flock_over.mp3")
			_audio.global_position = _owl.global_position
			_audio.volume_db = -14.0
			_audio.play()
	if not _owl.visible:
		_owl_t -= dt
		if _owl_t <= 0.0:
			_owl_t = 999.0
			_perch(at)
		return
	if _owl_eyes != null:
		# The eyes, a little in front of the face; they blink.
		_owl_eyes.position = Vector3(0, 0.31, 0.04)
		_owl_eyes.visible = fmod(_tick, 6.0) > 0.25
	_owl_hoot -= dt
	if _owl_hoot <= 0.0:
		_owl_hoot = _rng.randf_range(18.0, 50.0)
		_owl_snd.global_position = _owl.global_position
		if _owl_snd.stream != null:
			_owl_snd.play()
	# Gone far behind you: it moves on with you.
	if Vector2(_owl.global_position.x - at.x, _owl.global_position.z - at.z).length() > 45.0:
		_owl.visible = false
		_owl_t = _rng.randf_range(10.0, 30.0)


## A camp tree 12-35 m off, on the side of its crown, about three metres up.
func _perch(at: Vector3) -> void:
	var best: Node3D = null
	for t in get_tree().get_nodes_in_group("trees"):
		var n := t as Node3D
		if n == null or n.is_in_group("corn"):
			continue
		var d := Vector2(n.global_position.x - at.x, n.global_position.z - at.z).length()
		if d > 12.0 and d < 35.0 and _rng.randf() < 0.3:
			best = n
			break
	if best == null:
		_owl_t = _rng.randf_range(15.0, 30.0)
		return
	var side := Vector3(at.x - best.global_position.x, 0, at.z - best.global_position.z).normalized()
	_owl.global_position = best.global_position + side * 0.9 + Vector3(0, 3.0 + _rng.randf_range(-0.4, 0.6), 0)
	_owl.visible = true
	_owl_hoot = _rng.randf_range(3.0, 12.0)


# ── flocks ───────────────────────────────────────────────────────────────────

func _spawn_flock(around: Vector3, kind: String) -> void:
	var ang := _rng.randf() * TAU
	var dir := Vector3(cos(ang), 0, sin(ang))
	var side := Vector3(-dir.z, 0, dir.x)
	var length := 260.0
	var from := around - dir * length * 0.5 + side * _rng.randf_range(-40.0, 40.0)
	var n := _rng.randi_range(4, 9) if kind == "bird" else _rng.randi_range(2, 5)
	var height := _rng.randf_range(16.0, 24.0) if kind == "bird" else _rng.randf_range(13.0, 20.0)
	var birds: Array = []
	for i in n:
		var off := Vector3(-float(i / 2 + 1) * _rng.randf_range(2.6, 4.2), _rng.randf_range(-1.5, 1.5), (1.0 if i % 2 == 0 else -1.0) * float(i / 2 + 1) * _rng.randf_range(2.2, 3.6))
		if i == 0:
			off = Vector3.ZERO
		# Big for real birds: drawn small and scaled up, anything smaller is a speck.
		var s := _sprite(kind + "_up", 1.28 if kind == "bird" else 2.4)
		birds.append({"sprite": s, "off": off, "phase": _rng.randi_range(0, 5)})
	var speed := _rng.randf_range(11.0, 15.0) if kind == "bird" else _rng.randf_range(7.0, 9.0)
	_flocks.append({"birds": birds, "from": from + Vector3(0, height, 0), "dir": dir, "side": side, "t": 0.0, "length": length, "speed": speed, "kind": kind, "heard": false})


func _update_flocks(delta: float) -> void:
	var step := floorf(_tick * FPS)
	for f in _flocks:
		f["t"] = float(f["t"]) + delta
		var dist := float(f["t"]) * float(f["speed"])
		var dir: Vector3 = f["dir"]
		var side: Vector3 = f["side"]
		var lead: Vector3 = (f["from"] as Vector3) + dir * dist
		for b in f["birds"]:
			var s: Sprite3D = b["sprite"]
			var off: Vector3 = b["off"]
			# A gentle wave in the formation, in steps.
			var wave := sin(step * 0.15 + float(b["phase"])) * 0.6
			s.position = lead + dir * off.x + side * (off.z + wave) + Vector3(0, off.y, 0)
			# Beat, beat, glide.
			var kind := str(f["kind"])
			var beat := (int(step) + int(b["phase"])) % (6 if kind == "bird" else 8)
			s.texture = _tex[kind + ("_down" if beat < (2 if kind == "bird" else 3) else "_up")]
		if not bool(f["heard"]) and dist > float(f["length"]) * 0.4:
			f["heard"] = true
			_audio.stream = load(SFX + ("crows_over.mp3" if str(f["kind"]) == "crow" else "flock_over.mp3"))
			_audio.volume_db = -10.0 if str(f["kind"]) == "bird" else -6.0
			_audio.global_position = lead
			_audio.play()
		if dist > float(f["length"]):
			for b in f["birds"]:
				(b["sprite"] as Node).queue_free()
			f["done"] = true
	_flocks = _flocks.filter(func(f): return not f.has("done"))


# ── after dark ───────────────────────────────────────────────────────────────

func _lit_lamps(around: Vector3) -> Array:
	_lamp_poll -= 1.0 / FPS
	if _lamp_poll > 0.0:
		return _lamps
	_lamp_poll = 1.0
	_lamps = []
	for lamp in get_tree().get_nodes_in_group("lamp_posts"):
		var l := lamp as Node3D
		if l == null or not l.is_inside_tree():
			continue
		var bulb: Light3D = null
		for c in l.get_children():
			if c is SpotLight3D:
				bulb = c
				break
		if bulb == null or not bulb.is_visible_in_tree() or bulb.light_energy <= 0.05:
			continue
		if bulb.global_position.distance_to(around) < 32.0:
			_lamps.append(bulb.global_position)
		if _lamps.size() >= 6:
			break
	return _lamps


func _update_bats(around: Vector3, night: bool) -> void:
	var want := 3 if night else 0
	while _bats.size() < want:
		_bats.append({"sprite": _sprite("bat_up", 0.75), "a": _rng.randf() * TAU, "r": _rng.randf_range(3.0, 7.0), "h": _rng.randf_range(5.0, 9.0), "phase": _rng.randi_range(0, 3), "jit": Vector3.ZERO})
	while _bats.size() > want:
		(_bats.pop_back()["sprite"] as Node).queue_free()
	if _bats.is_empty():
		return
	var lamps := _lit_lamps(around)
	var centre := around + Vector3(0, 2.0, 0)
	if not lamps.is_empty():
		centre = lamps[0]
	var step := int(floorf(_tick * FPS))
	for b in _bats:
		# Erratic: the circle turns, and every few steps a jink.
		b["a"] = float(b["a"]) + _rng.randf_range(0.18, 0.42)
		if step % 3 == 0:
			b["jit"] = Vector3(_rng.randf_range(-1.2, 1.2), _rng.randf_range(-0.8, 0.8), _rng.randf_range(-1.2, 1.2))
		var a := float(b["a"])
		var s: Sprite3D = b["sprite"]
		s.position = centre + Vector3(cos(a) * float(b["r"]), float(b["h"]) - 4.0 + sin(a * 2.3) * 1.2, sin(a) * float(b["r"])) + (b["jit"] as Vector3)
		s.texture = _tex["bat_down" if (step + int(b["phase"])) % 2 == 0 else "bat_up"]


func _update_moths(around: Vector3, night: bool) -> void:
	var lamps: Array = _lit_lamps(around) if night else []
	var want := lamps.size() * 4
	while _moths.size() < want:
		_moths.append({"sprite": _sprite("moth", 0.09), "o": Vector3.ZERO})
	while _moths.size() > want:
		(_moths.pop_back()["sprite"] as Node).queue_free()
	for i in _moths.size():
		var m: Dictionary = _moths[i]
		var bulb: Vector3 = lamps[i / 4]
		# Round and round the bulb, a twitch at a time.
		var o: Vector3 = m["o"]
		o += Vector3(_rng.randf_range(-0.12, 0.12), _rng.randf_range(-0.1, 0.1), _rng.randf_range(-0.12, 0.12))
		if o.length() > 0.55:
			o = o.normalized() * 0.4
		m["o"] = o
		(m["sprite"] as Sprite3D).position = bulb + Vector3(0, -0.25, 0) + o
