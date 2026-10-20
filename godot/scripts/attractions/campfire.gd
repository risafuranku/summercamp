extends Node3D

## The camp's bonfire, alive (a child of the bonfire structure, built by
## building_models._bonfire). It burns on `fuel`:
##   - the evening (18:00-01:00): when guests sit at it and it is cold, one of them gets a
##     small fire going; you can put logs on from the woodpile (E: main -> attraction_play),
##     each one flies in, the fire flares, sparks burst out and it burns bigger for a while;
##   - it burns down by itself (a log lasts about two game hours), to embers, and by
##     morning there is a grey bed of ash with a thread of smoke; the woodpile is full again.
## Everything is stepped (flames 12 frames a second, the light 10, sparks and smoke in
## steps), like a 1996 sprite fire. The flame is materials/pixel_fire.gdshader on three
## fixed-Y quads, the bed materials/fire_embers.gdshader, the smoke Grok puffs
## (camp/fire_smoke.png) through materials/fire_smoke.gdshader, see-through in Build's steps.

const FIRE_SHADER = preload("res://materials/pixel_fire.gdshader")
const POSES = preload("res://scripts/attractions/poses.gd")
const SFX_SIZZLE := "res://assets/sfx/life/sausage_sizzle.mp3"
const SMOKE_SHADER = preload("res://materials/fire_smoke.gdshader")
const SMOKE_TEX := "res://assets/textury/camp/fire_smoke.png"
const SFX_CRACKLE := "res://assets/sfx/life/fire_crackle.mp3"
const SFX_LOG := "res://assets/sfx/life/fire_log.mp3"
const SFX_POP := "res://assets/sfx/life/fire_pop.mp3"
const STEP := 0.1
## Fuel burnt per game hour; a log adds LOG_FUEL.
const BURN_PER_HOUR := 0.32
const LOG_FUEL := 0.42
const MAX_FUEL := 1.45
## What the guests light when they come to a cold fire in the evening.
const GUEST_FIRE := 0.55
const WOODPILE_LOGS := 8

var fuel := 0.0
## Last night's heat left in the ashes (glows a little, smokes).
var embers := 0.0
var logs_left := WOODPILE_LOGS
var guests_here := 0

var _flames: Array[MeshInstance3D] = []
var _flame_mats: Array[ShaderMaterial] = []
var _flame_rest: Array[Vector3] = []
var _bed: MeshInstance3D
var _bed_mat: ShaderMaterial
var _light: OmniLight3D
var _pile: Array[Node3D] = []
var _burning: Array[MeshInstance3D] = []
var _crackle: AudioStreamPlayer3D
var _pops: AudioStreamPlayer3D
var _sparks: Array = []           # {node, v, life, max}
var _smoke: Array = []            # {node, mat, v, life, max, grow}
var _smoke_tex: Texture2D
var _spark_mats: Array[StandardMaterial3D] = []
var _flare := 0.0
var _acc := 0.0
var _hour := 12.0
var _last_hour := -1.0
var _day := -1
var _rng := RandomNumberGenerator.new()
var _wind := 0.0
## People on the benches: member key (guest id * 10 + member) -> seat index; when each
## was last placed (keys not seen for a second have left); their sausage sticks.
var _seats: Array = []
var _seat_of: Dictionary = {}
var _seen: Dictionary = {}
var _sticks: Dictionary = {}
var _clock := 0.0
var _sizzle: AudioStreamPlayer3D
var _stick_mat: StandardMaterial3D


func _ready() -> void:
	_rng.randomize()
	add_to_group("campfire")
	add_to_group("attraction")
	# The model adds the benches and the woodpile after this node: gather once it is done.
	_setup.call_deferred()


func _setup() -> void:
	var r := get_parent()
	for c in r.get_children():
		if c is MeshInstance3D and str(c.name).begins_with("FireFlame"):
			_flames.append(c)
			_flame_rest.append(c.scale)
			var sm := ShaderMaterial.new()
			sm.shader = FIRE_SHADER
			sm.set_shader_parameter("seed", float(_flames.size()) * 1.37 + _rng.randf() * 10.0)
			c.material_override = sm
			_flame_mats.append(sm)
		elif c is MeshInstance3D and str(c.name) == "EmberBed":
			_bed = c
			_bed_mat = c.material_override as ShaderMaterial
		elif c is OmniLight3D:
			_light = c
		elif c is Node3D and str(c.name).begins_with("PileLog"):
			_pile.append(c)
		elif c is MeshInstance3D and str(c.name).begins_with("FireLog"):
			_burning.append(c)
	for col in [Color(1.0, 0.92, 0.5), Color(1.0, 0.62, 0.18), Color(0.86, 0.26, 0.06)]:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = col
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_spark_mats.append(m)
	_crackle = _sound(SFX_CRACKLE, -30.0, 16.0)
	_loop(_crackle)
	_pops = _sound(SFX_POP, -8.0, 22.0)
	_sizzle = _sound(SFX_SIZZLE, -14.0, 9.0)
	_loop(_sizzle)
	_seats = seats()
	_stick_mat = StandardMaterial3D.new()
	_stick_mat.albedo_color = Color(0.46, 0.34, 0.22)
	if EventBus.has_signal("time_tick") and not EventBus.time_tick.is_connected(_on_time_tick):
		EventBus.time_tick.connect(_on_time_tick)
	_wind = _rng.randf_range(-0.06, 0.06)
	_apply(true)


func _sound(path: String, db: float, dist: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.volume_db = db
	p.max_distance = dist
	p.unit_size = 3.0
	p.position = Vector3(0, 0.5, 0)
	add_child(p)
	if ResourceLoader.exists(path):
		p.stream = load(path)
	return p


func _loop(p: AudioStreamPlayer3D) -> void:
	if p.stream is AudioStreamMP3:
		(p.stream as AudioStreamMP3).loop = true


func _on_time_tick(hour: int, minute: int) -> void:
	var h := float(hour) + float(minute) / 60.0
	if _last_hour >= 0.0:
		var dh := h - _last_hour
		if dh < 0.0:
			dh += 24.0
		if dh > 0.0:
			_burn(minf(dh, 24.0), dh < 3.0)
	_last_hour = h
	_hour = h
	# Morning: the pile is stacked again (the ash is still there).
	var st = CoreRoot.get_state() if CoreRoot != null else null
	var day := int(st.day) if st != null else 0
	if day != _day:
		if _day >= 0 and h >= 6.0:
			logs_left = WOODPILE_LOGS
			for p in _pile:
				p.visible = true
		_day = day


func _burn(hours: float, live := true) -> void:
	var before := fuel
	fuel = maxf(0.0, fuel - BURN_PER_HOUR * hours)
	if before > 0.05:
		embers = clampf(embers + hours * 0.08, 0.0, 0.45)
	else:
		embers = maxf(0.0, embers - hours * 0.035)
	# Guests at a cold fire in the evening light one.
	if live and guests_here > 0 and fuel < 0.12 and is_evening():
		fuel = GUEST_FIRE


func is_evening() -> bool:
	return _hour >= 18.0 or _hour < 1.0


func is_lit() -> bool:
	return fuel > 0.06


## E with the woodpile in reach: a log on the fire. False when the pile is empty.
func add_log() -> bool:
	if logs_left <= 0:
		return false
	logs_left -= 1
	_throw_log()
	return true


func _throw_log() -> void:
	var idx := clampi(logs_left, 0, _pile.size() - 1)
	var from: Vector3 = _pile[idx].global_position if not _pile.is_empty() else global_position + Vector3(1.4, 0.3, 0)
	if idx < _pile.size():
		_pile[idx].visible = false
	var log := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.07
	c.bottom_radius = 0.07
	c.height = 0.62
	c.radial_segments = 6
	log.mesh = c
	log.material_override = (_pile[idx].get_child(0) as MeshInstance3D).material_override if not _pile.is_empty() and _pile[idx].get_child_count() > 0 else null
	get_parent().add_child(log)
	log.global_position = from
	var to := global_position + Vector3(_rng.randf_range(-0.12, 0.12), 0.32, _rng.randf_range(-0.12, 0.12))
	var mid := from.lerp(to, 0.5) + Vector3(0, 0.9, 0)
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var a := from.lerp(mid, t)
		var b := mid.lerp(to, t)
		log.global_position = a.lerp(b, t)
		log.rotation = Vector3(t * 5.0, t * 2.0, PI * 0.5 + t * 3.0), 0.0, 1.0, 0.55)
	tw.tween_callback(func():
		log.queue_free()
		fuel = minf(MAX_FUEL, fuel + LOG_FUEL)
		_flare = 1.0
		_burst(26)
		_puff(4, 1.4)
		_play(SFX_LOG, -2.0)
	)


func _play(path: String, db: float) -> void:
	if ResourceLoader.exists(path):
		_pops.stream = load(path)
		_pops.volume_db = db
		_pops.pitch_scale = _rng.randf_range(0.9, 1.1)
		_pops.play()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_clock += delta
	_acc += delta
	_flare = maxf(0.0, _flare - delta * 0.7)
	if _acc < STEP:
		return
	_acc = 0.0
	_apply(false)
	_step_sparks()
	_step_smoke()
	_free_left_seats()


func _apply(_first: bool) -> void:
	var lit := is_lit()
	var power := fuel + _flare * 0.5
	for i in _flames.size():
		var f := _flames[i]
		f.visible = lit
		if not lit:
			continue
		var rest := _flame_rest[i]
		var grow := clampf(0.45 + power * 0.62, 0.3, 1.5)
		f.scale = Vector3(rest.x * (0.8 + 0.25 * grow), rest.y * grow, rest.z)
		_flame_mats[i].set_shader_parameter("intensity", clampf(0.55 + power * 0.55, 0.3, 1.5))
		_flame_mats[i].set_shader_parameter("flare", _flare)
		_flame_mats[i].set_shader_parameter("wind", _wind)
	if _bed_mat != null:
		_bed_mat.set_shader_parameter("heat", clampf(fuel * 1.1 + embers + _flare * 0.3, 0.0, 1.4))
	if _light != null:
		_light.visible = lit or embers > 0.12
		var base := 0.6 + power * 2.3 if lit else embers * 0.9
		_light.light_energy = base * _rng.randf_range(0.84, 1.1)
		_light.omni_range = 4.0 + power * 5.0 if lit else 2.2
	for i in _burning.size():
		_burning[i].visible = lit or embers > 0.05
	if _crackle != null and _crackle.stream != null:
		var want := lit
		if want and not _crackle.playing:
			_crackle.play()
		elif not want and _crackle.playing:
			_crackle.stop()
		_crackle.volume_db = lerpf(-22.0, -4.0, clampf(power, 0.0, 1.2) / 1.2)
	if lit and _rng.randf() < 0.025 * power:
		_play(SFX_POP, -10.0)
	# Sparks climb out of a fire; smoke from it, more from a dying one.
	if lit and _rng.randf() < 0.35 + 0.45 * power:
		_burst(1 + int(power * 1.5))
	var smoke_p := 0.0
	if lit:
		smoke_p = 0.1 + 0.2 * clampf(0.6 - fuel, 0.0, 0.6)
	elif embers > 0.04:
		smoke_p = 0.06 + embers * 0.3
	if _rng.randf() < smoke_p:
		_puff(1, 1.0 if lit else 0.6)


func _burst(n: int) -> void:
	for i in n:
		if _sparks.size() > 60:
			return
		var s := MeshInstance3D.new()
		var q := QuadMesh.new()
		var sz := _rng.randf_range(0.018, 0.036)
		q.size = Vector2(sz, sz)
		s.mesh = q
		s.material_override = _spark_mats[0]
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(s)
		s.position = Vector3(_rng.randf_range(-0.2, 0.2), 0.45 + _rng.randf() * 0.3, _rng.randf_range(-0.2, 0.2))
		var up := _rng.randf_range(0.08, 0.2) * (1.0 + _flare)
		var life := _rng.randi_range(6, 16)
		_sparks.append({"node": s, "v": Vector3(_rng.randf_range(-0.04, 0.04) + _wind * 0.4, up, _rng.randf_range(-0.04, 0.04)), "life": life, "max": life})


func _step_sparks() -> void:
	for sp in _sparks:
		var n: MeshInstance3D = sp["node"]
		var v: Vector3 = sp["v"]
		v.x += _rng.randf_range(-0.025, 0.025)
		v.z += _rng.randf_range(-0.025, 0.025)
		v.y *= 0.93
		sp["v"] = v
		n.position += v
		sp["life"] = int(sp["life"]) - 1
		var k := float(sp["life"]) / float(sp["max"])
		n.material_override = _spark_mats[0] if k > 0.66 else (_spark_mats[1] if k > 0.33 else _spark_mats[2])
		if int(sp["life"]) <= 0:
			n.queue_free()
	_sparks = _sparks.filter(func(sp): return int(sp["life"]) > 0)


func _puff(n: int, size: float) -> void:
	for i in n:
		if _smoke.size() > 24:
			return
		var s := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.36, 0.36) * size
		s.mesh = q
		var m := ShaderMaterial.new()
		m.shader = SMOKE_SHADER
		m.set_shader_parameter("seed", _rng.randf() * 100.0)
		if _smoke_tex == null and ResourceLoader.exists(SMOKE_TEX):
			_smoke_tex = load(SMOKE_TEX)
		m.set_shader_parameter("puff", _smoke_tex)
		# Smoke is only as bright as the sky behind it: grey by day, near black at night.
		var day := clampf(1.0 - absf(_hour - 13.0) / 6.5, 0.0, 1.0)
		var grey := _rng.randf_range(0.42, 0.6) * lerpf(0.28, 1.0, day)
		var col := Color(grey, grey * 0.98, grey * 0.95)
		# In the dark, lit from under by the flames.
		if is_lit():
			col += Color(0.3, 0.14, 0.05) * (1.0 - day)
		m.set_shader_parameter("color", col)
		s.material_override = m
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(s)
		s.position = Vector3(_rng.randf_range(-0.12, 0.12), 0.9 if is_lit() else 0.2, _rng.randf_range(-0.12, 0.12))
		var life := _rng.randi_range(16, 28)
		_smoke.append({"node": s, "mat": m, "v": Vector3(_wind * 0.5 + _rng.randf_range(-0.01, 0.01), _rng.randf_range(0.05, 0.08), _rng.randf_range(-0.01, 0.01)), "life": life, "max": life})


func _step_smoke() -> void:
	for sm in _smoke:
		var n: MeshInstance3D = sm["node"]
		n.position += sm["v"]
		n.scale *= 1.045
		sm["life"] = int(sm["life"]) - 1
		(sm["mat"] as ShaderMaterial).set_shader_parameter("fade", clampf(float(sm["life"]) / float(sm["max"]), 0.0, 1.0) * 0.6)
		if int(sm["life"]) <= 0:
			n.queue_free()
	_smoke = _smoke.filter(func(sm): return int(sm["life"]) > 0)


## Where people sit round it: [{pos (global), yaw}] on the log benches.
func seats() -> Array:
	var out: Array = []
	for c in get_parent().get_children():
		if c is Node3D and c.has_meta("seat"):
			for p in (c.get_meta("seat") as Array):
				out.append({"pos": (c as Node3D).global_transform * (p as Vector3), "look": global_position})
	return out


# ── people round the fire (guest_agents -> pose_member) ──────────────────────

func covers_tile(tile: Vector2i) -> bool:
	var r: Node = get_parent()
	while r != null and not r.has_meta("grid_origin"):
		r = r.get_parent()
	if r == null:
		return false
	var o: Vector2i = r.get_meta("grid_origin")
	var fp_any = r.get_meta("grid_footprint", Vector2i.ONE)
	var fp: Vector2i = fp_any if fp_any is Vector2i else Vector2i.ONE
	return tile.x >= o.x and tile.y >= o.y and tile.x < o.x + fp.x and tile.y < o.y + fp.y


## A guest of a visiting party: on a bench seat facing the fire, mostly just sitting,
## now and then a pull of beer; with the fire going a sausage on a stick out over the
## coals; a tramp plays the guitar in the evening. False when every seat is taken
## (they stand about as before).
func pose_member(guest_id: int, i: int, _n: int, member: Node3D, sprite: Sprite3D, info: Dictionary, t: float) -> bool:
	if _seats.is_empty():
		_seats = seats()
		if _seats.is_empty():
			return false
	var key := guest_id * 10 + i
	if not _seat_of.has(key):
		var taken := _seat_of.values()
		var free := -1
		# Spread round the circle: the seat furthest from the ones taken.
		for k in _seats.size():
			var idx := (k * 3 + guest_id) % _seats.size()
			if not taken.has(idx):
				free = idx
				break
		if free < 0:
			return false
		_seat_of[key] = free
	_seen[key] = _clock
	var seat: Dictionary = _seats[int(_seat_of[key])]
	var sp: Vector3 = seat["pos"]
	var to_fire := global_position - sp
	to_fire.y = 0.0
	var dir := to_fire.normalized()
	member.global_position = Vector3(sp.x, global_position.y, sp.z) + dir * 0.16
	member.set_meta("marker_drop", -0.42)
	var arche := str(info.get("archetype", ""))
	var base := str(info.get("sprite_path", ""))
	var pose := "sit"
	var beat := floorf(t * 8.0) / 8.0
	if key < 0:
		# A warden: sat, the sausage out only when they hold it out (warden_press).
		pass
	elif arche == "tramp" and is_lit() and i == 0:
		pose = "guitar"
	elif fmod(beat + float(key) * 3.1, 11.0) < 1.8:
		pose = "drink"
	POSES.set_pose(sprite, base, pose)
	if sprite != null:
		# Strumming: a little bob on the beat; everyone else sways a touch.
		sprite.position.y = (0.012 if int(beat * 4.0) % 2 == 0 else 0.0) if pose == "guitar" else 0.0
	_stick_for(key, member.global_position, dir, pose == "sit" and is_lit() and (key >= 0 or bool(_roast.get(key, false))), t)
	return true


func _stick_for(key: int, at: Vector3, dir: Vector3, out: bool, t: float) -> void:
	var st: Dictionary = _sticks.get(key, {})
	if st.is_empty():
		if not out:
			return
		var n := Node3D.new()
		n.name = "Stick%d" % key
		add_child(n)
		var rod := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.014, 0.014, 1.15)
		rod.mesh = b
		rod.material_override = _stick_mat
		rod.position = Vector3(0, 0, -0.575)
		n.add_child(rod)
		var sausage := MeshInstance3D.new()
		var c := CapsuleMesh.new()
		c.radius = 0.024
		c.height = 0.15
		c.radial_segments = 6
		c.rings = 2
		sausage.mesh = c
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.78, 0.38, 0.3)
		sausage.material_override = sm
		sausage.rotation.x = PI * 0.5
		sausage.position = Vector3(0, 0, -1.08)
		n.add_child(sausage)
		st = {"node": n, "mat": sm, "cook": 0.0}
		_sticks[key] = st
	var node: Node3D = st["node"]
	node.visible = out
	if not out:
		return
	# Held at the hands, reaching down over the coals, turned now and then.
	var hand := at + Vector3(0, 0.62, 0) + dir * 0.12
	node.global_position = hand
	var tip := global_position + Vector3(0, 0.3, 0) - dir * 0.15
	node.look_at(tip, Vector3.UP)
	node.rotate_object_local(Vector3(0, 0, 1), floorf(t * 2.0) * 0.9)
	st["cook"] = minf(1.0, float(st["cook"]) + 0.0016)
	var k := float(st["cook"])
	(st["mat"] as StandardMaterial3D).albedo_color = Color(0.78, 0.38, 0.3).lerp(Color(0.42, 0.18, 0.1), k)


func _free_left_seats() -> void:
	var gone: Array = []
	for key in _seen.keys():
		if _clock - float(_seen[key]) > 1.0:
			gone.append(key)
	for key in gone:
		_seen.erase(key)
		_seat_of.erase(key)
		var st: Dictionary = _sticks.get(key, {})
		if not st.is_empty():
			(st["node"] as Node).queue_free()
			_sticks.erase(key)
	# Guests (a warden alone does not light it: they put a log on).
	guests_here = _seen.keys().filter(func(k): return int(k) >= 0).size()
	var roasting := false
	for st in _sticks.values():
		if (st["node"] as Node3D).visible:
			roasting = true
	if _sizzle != null and _sizzle.stream != null:
		if roasting and not _sizzle.playing:
			_sizzle.play()
		elif not roasting and _sizzle.playing:
			_sizzle.stop()


# ── a warden by the fire (scripts/attractions/warden_play.gd) ────────────────

## Warden key -> their sausage held out over the coals.
var _roast: Dictionary = {}


## By the woodpile: a log on; near the fire: a seat.
func warden_offer(at: Vector3) -> Dictionary:
	var pile := pile_position()
	var dp := Vector2(at.x - pile.x, at.z - pile.z).length()
	var df := Vector2(at.x - global_position.x, at.z - global_position.z).length()
	if dp < 1.5 and logs_left > 0 and dp < df:
		return {"verb": "Put a log on", "act": "log", "d": dp}
	if df < 3.4:
		return {"verb": "Sit by the fire", "act": "join", "d": df}
	return {}


## The free seat nearest to `at`.
func warden_join(key: int, at: Vector3) -> bool:
	if _seats.is_empty():
		_seats = seats()
	var taken := _seat_of.values()
	var best := -1
	for idx in _seats.size():
		if taken.has(idx):
			continue
		var p: Vector3 = _seats[idx]["pos"]
		if best < 0 or p.distance_to(at) < (_seats[best]["pos"] as Vector3).distance_to(at):
			best = idx
	if best < 0:
		return false
	_seat_of[key] = best
	_seen[key] = _clock
	return true


func warden_slot(key: int) -> int:
	return int(_seat_of.get(key, -1))


## The other machine's warden: on the seat they have there (a guest in it moves up).
func warden_force(key: int, slot: int, x: Dictionary) -> void:
	_roast[key] = bool(x.get("ro", false))
	if slot < 0 or slot >= _seats.size() or int(_seat_of.get(key, -1)) == slot:
		return
	for k in _seat_of.keys():
		if int(_seat_of[k]) == slot and k != key:
			_seat_of.erase(k)
			var st: Dictionary = _sticks.get(k, {})
			if not st.is_empty():
				(st["node"] as Node).queue_free()
				_sticks.erase(k)
	_seat_of[key] = slot
	_seen[key] = _clock


func warden_extra(key: int) -> Dictionary:
	return {"ro": bool(_roast.get(key, false))}


func warden_leave(key: int) -> void:
	_seat_of.erase(key)
	_seen.erase(key)
	_roast.erase(key)
	var st: Dictionary = _sticks.get(key, {})
	if not st.is_empty():
		(st["node"] as Node).queue_free()
		_sticks.erase(key)


func warden_focus(_key: int) -> Vector3:
	return global_position + Vector3(0.0, 0.35, 0.0)


## LMB: the sausage out over the coals; done, eaten ("eat"); not yet, pulled back.
func warden_press(key: int) -> String:
	if not is_lit():
		return ""
	var st: Dictionary = _sticks.get(key, {})
	if bool(_roast.get(key, false)) and not st.is_empty() and float(st["cook"]) >= 1.0:
		_roast[key] = false
		(st["node"] as Node).queue_free()
		_sticks.erase(key)
		return "eat"
	_roast[key] = not bool(_roast.get(key, false))
	return "roast" if _roast[key] else ""


func warden_hint(key: int) -> String:
	if not is_lit():
		return "[E] Put a log on" if logs_left > 0 else ""
	var st: Dictionary = _sticks.get(key, {})
	if bool(_roast.get(key, false)) and not st.is_empty() and float(st["cook"]) >= 1.0:
		return "[LMB] Eat it"
	return "" if bool(_roast.get(key, false)) else "[LMB] A sausage   [Q] Guitar"


## Where the woodpile is (for E): global.
func pile_position() -> Vector3:
	var n := get_parent().get_node_or_null("Woodpile") as Node3D
	return n.global_position if n != null else global_position


func export_state() -> Dictionary:
	return {"fuel": fuel, "embers": embers, "logs": logs_left}


## Co-op, the other machine: the host's fire as it burns there (the logs still flying
## in here are left to land; the pile as the host's).
func coop_take_state(d: Dictionary) -> void:
	fuel = clampf(float(d.get("fuel", fuel)), 0.0, MAX_FUEL)
	embers = clampf(float(d.get("embers", embers)), 0.0, 1.0)
	var logs := clampi(int(d.get("logs", logs_left)), 0, WOODPILE_LOGS)
	if logs != logs_left:
		logs_left = logs
		for i in _pile.size():
			_pile[i].visible = i < logs_left


func import_state(d: Dictionary) -> void:
	fuel = clampf(float(d.get("fuel", 0.0)), 0.0, MAX_FUEL)
	embers = clampf(float(d.get("embers", 0.0)), 0.0, 1.0)
	logs_left = clampi(int(d.get("logs", WOODPILE_LOGS)), 0, WOODPILE_LOGS)
	for i in _pile.size():
		_pile[i].visible = i < logs_left
	_apply(true)
