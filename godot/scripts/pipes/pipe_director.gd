extends RefCounted

## The raccoon in the camp sewer (DESIGN §8). It is why you are down here: a sewer only
## breaks because it chewed through the pipes, so whenever you climb down, it is there.
## The pipe crawl (scripts/sewer_pipe_minigame.gd) owns the pipes, your crawl, the map,
## the clamp and the catch; this is the animal and what it gets up to.
##
## How far it goes is the night's pressure on the camp (omens.pressure) when you climbed
## down, as a level (mischief_level):
##   1  mischief: one hole. Chittering far off, claws over the crown, the drip stopping,
##      its eyes at the end of your beam, blinking out; trails of its guts along the
##      floor. It never comes near; its little wet hand prints are on the ladder after.
##   2  two holes and a snare of guts across a pipe you will want (seen from the
##      junction, glistening in the beam: go round, or crawl in and tear free while it
##      comes for the noise and bites). It shows itself: standing upright at the end of
##      the beam, a face round the next corner, across a junction dragging its belly. It
##      copies your crawl from behind, and hisses like a hole from a dead end.
##   3  three holes, two snares, and the hunt: blind, it goes to your last noise a
##      junction at a time; from next door it chitters at you, and after that warning it
##      takes you (the crawl plays one of its catches). Torchlight down a straight pipe
##      makes it rear up and burst: the guts spill out of it and it is gone for a while.
## Every catch can be explained afterwards (the chittering next door, the light off it).

const SFX := "res://assets/sfx/pipes/"
## The raccoon is the original art (assets/textury/npc/racoon*.png, brought in with one
## framing by tools/artgen/black_frames.py): rac_0 standing, rac_1..9 the guts letting go.
const SPR_STAND := "res://assets/textury/pipes/rac/rac_0.png"
const SPR_CRAWL := "res://assets/textury/pipes/rac/rac_0.png"
const SPR_PEEK := "res://assets/textury/pipes/rac/rac_0.png"
const SPR_CRAWL_B := "res://assets/textury/pipes/rac/rac_spell.png"
const SPR_TWITCH := "res://assets/textury/pipes/rac/rac_spell.png"
## Lit too long, its belly opens in three frames and lets go.
const SPR_BELLY := ["res://assets/textury/pipes/rac/rac_1.png", "res://assets/textury/pipes/rac/rac_2.png", "res://assets/textury/pipes/rac/rac_3.png", "res://assets/textury/pipes/rac/rac_4.png", "res://assets/textury/pipes/rac/rac_5.png", "res://assets/textury/pipes/rac/rac_6.png", "res://assets/textury/pipes/rac/rac_7.png", "res://assets/textury/pipes/rac/rac_8.png", "res://assets/textury/pipes/rac/rac_9.png"]
const BURST_FRAME := 1.0 / 12.0
const SPR_FALLBACK := "res://assets/textury/npc/pipe_thing_close.png"
const GUTS_PILE := "res://assets/textury/pipes/rac/rac_hpile.png"
const GUTS_TRAIL := "res://assets/textury/pipes/rac/rac_hblood.png"
const GUTS_SPLAT := "res://assets/textury/pipes/rac/rac_hblood.png"
## The pipes are 80 cm across: upright, it fills them, hunched under the crown.
## The frames share one canvas (73 px, the raccoon 64 of it): ~0.6 m of raccoon.
const STAND_H := 0.68
const CRAWL_H := 0.68
const PEEK_H := 0.68
const CRAWL_SPEED := 4.4
## Seconds between its moves while hunting a sound / wandering (night is quicker).
const HUNT_SEC := 2.3
const WANDER_SEC := 5.0
const NIGHT_MULT := 0.8
const LIGHT_SEC := 0.8
const DAMAGE := 34
const BITE := 12

enum { BUILD, STALK, PEAK, RELAX }

var host                           # the crawl
var visit := 1
var night := false
var level := 1
var rng := RandomNumberGenerator.new()

var node := Vector2i(-1, -1)       # where it is
var _noise_at := Vector2i(-1, -1)
var _noise_loud := 0
var _move_t := 0.0
var _phase := BUILD
var _phase_t := 0.0
var _phase_len := 20.0
var _sign_t := 6.0
var _lit_t := 0.0
var _warned_t := 0.0               # how long it has chittered at you from next door
var _scene := {}                   # the staged look: {kind, t, ...}
var _drip_mute_t := 0.0
var _echo_left := 0
var _lure: AudioStreamPlayer3D
var _lure_t := 0.0
var _chitter_t := 0.0
var _bite_t := 0.0
var _traps := {}                   # "a|b" -> {a, b, pile, sprung, done}
var tension := 0.0
var flicker := 0.0                 # the torch stutters (0..1), the host reads it

var body: Sprite3D
var peek: Sprite3D
var eyes: Sprite3D
var _tex_stand: Texture2D
var _tex_crawl: Texture2D
var _tex_crawl_b: Texture2D
var _tex_twitch: Texture2D
var _belly: Array = []
var _burst := -1.0                 # time into the belly opening, -1 none
var _twitch_t := 2.0
var _body_pos := Vector3.ZERO
var _body_to := Vector3.ZERO
var _standing := false
var _anim_t := 0.0
var _breath: AudioStreamPlayer
var _hum: AudioStreamPlayer


## The night's pressure (omens.pressure) as how far it goes down there, 1-3. Night adds
## one; the first time down it stops at two.
static func mischief_level(pressure: float, at_night: bool, visit_number: int) -> int:
	var l := 1
	if pressure >= 1.6:
		l = 2
	if pressure >= 3.2:
		l = 3
	if at_night:
		l += 1
	if visit_number <= 1:
		l = mini(l, 2)
	return clampi(l, 1, 3)


## A rough blob in one colour, for art not made yet (and its guts until it is).
static func blob_texture(c: Color, seed_value: int) -> ImageTexture:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for _i in 9:
		var cx := r.randf_range(9.0, 23.0)
		var cy := r.randf_range(9.0, 23.0)
		var rad := r.randf_range(3.0, 8.0)
		for y in 32:
			for x in 32:
				if Vector2(x - cx, y - cy).length() < rad:
					var k := r.randf_range(0.7, 1.15)
					img.set_pixel(x, y, Color(c.r * k, c.g * k, c.b * k, 1.0))
	return ImageTexture.create_from_image(img)


func start(host_node, visit_number: int, at_night: bool, seed_value: int) -> void:
	host = host_node
	visit = maxi(1, visit_number)
	night = at_night
	level = clampi(int(host.raccoon_level), 1, 3)
	rng.seed = seed_value
	_phase = BUILD
	_phase_t = 0.0
	_phase_len = rng.randf_range(14.0, 24.0) / (1.0 + 0.25 * float(level - 1))
	_sign_t = rng.randf_range(3.0, 6.0)
	_noise_at = Vector2i(-1, -1)
	_scene = {}
	tension = 0.0
	flicker = 0.0
	_warned_t = 0.0
	_echo_left = 0
	_traps.clear()
	_burst = -1.0
	_build_nodes()
	node = _far_node(host._entry, 4)
	_body_pos = _floor(node)
	_body_to = _body_pos
	body.visible = false
	peek.visible = false
	eyes.visible = false
	_lay_trails()
	if level >= 2:
		_lay_traps(1 if level == 2 else 2)


func stop() -> void:
	for p in [_breath, _hum, _lure]:
		if p != null and is_instance_valid(p):
			p.stop()


## It is always down here (it made the holes).
func is_real() -> bool:
	return true


## Its little wet hands on the ladder when you get back: the low nights, when it never
## showed itself.
func leaves_prints() -> bool:
	return level == 1


func _build_nodes() -> void:
	var fb: Texture2D = load(SPR_FALLBACK) if ResourceLoader.exists(SPR_FALLBACK) else null
	_tex_stand = load(SPR_STAND) if ResourceLoader.exists(SPR_STAND) else fb
	_tex_crawl = load(SPR_CRAWL) if ResourceLoader.exists(SPR_CRAWL) else fb
	_tex_crawl_b = load(SPR_CRAWL_B) if ResourceLoader.exists(SPR_CRAWL_B) else null
	_tex_twitch = load(SPR_TWITCH) if ResourceLoader.exists(SPR_TWITCH) else null
	_belly.clear()
	for path in SPR_BELLY:
		if ResourceLoader.exists(path):
			_belly.append(load(path))
	if _belly.is_empty():
		_belly.append(_tex_stand)
	body = _sprite(_tex_crawl, CRAWL_H)
	peek = _sprite(load(SPR_PEEK) if ResourceLoader.exists(SPR_PEEK) else fb, PEEK_H)
	# Two white dots and nothing else: its eyes in your light, far down a pipe.
	var img := Image.create(7, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in [0, 1, 5, 6]:
		for y in 2:
			img.set_pixel(x, y, Color(0.95, 0.93, 0.8))
	eyes = Sprite3D.new()
	eyes.texture = ImageTexture.create_from_image(img)
	eyes.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	eyes.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	eyes.shaded = false
	eyes.pixel_size = 0.016
	host._geo.add_child(eyes)
	if _breath == null:
		_breath = _loop(SFX + "breath.mp3")
		_hum = _loop(SFX + "hum.mp3")
	_breath.volume_db = -60.0
	_hum.volume_db = -24.0
	_hum.play()


func _sprite(tex: Texture2D, height: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = true
	s.double_sided = true
	_set_tex(s, tex, height)
	host._geo.add_child(s)
	return s


func _set_tex(s: Sprite3D, tex: Texture2D, height: float) -> void:
	s.texture = tex
	if tex != null:
		s.pixel_size = height / float(tex.get_height())
		s.offset = Vector2(0.0, tex.get_height() * 0.5)


func _loop(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = host.audio_bus()
	if ResourceLoader.exists(path):
		var s = load(path)
		if s is AudioStreamMP3:
			s = (s as AudioStreamMP3).duplicate()
			s.loop = true
		p.stream = s
	host.add_child(p)
	return p


# ── its leavings: trails and snares ─────────────────────────────────────────────

## Where it has dragged itself: a walk from its den, guts along the floor of each pipe.
func _lay_trails() -> void:
	var at := node
	for _i in 3 + level * 2:
		var opts: Array = host._links[at]
		if opts.is_empty():
			break
		var nxt: Vector2i = at + host.DIRS[opts[rng.randi() % opts.size()]]
		_floor_decal(host._edge_mid(at, nxt), at, nxt, _tex(GUTS_TRAIL, Color(0.30, 0.04, 0.04)), Vector2(0.42, 1.4))
		if rng.randf() < 0.4:
			_wall_splat(host._edge_mid(at, nxt), at, nxt)
		at = nxt


## Its snares: a heap of its own guts across a pipe, on the way to a hole if it can.
func _lay_traps(n: int) -> void:
	var cands: Array = []
	var dist_entry: Dictionary = host._distances_from(host._entry)
	for e in host._edges():
		if e[0] == host._entry or e[1] == host._entry or host._leak_index(e[0], e[1]) >= 0:
			continue
		# Pipes on the way from the ladder to a hole first.
		var on_way := 0.0
		for l in host._leaks:
			var dl: Dictionary = host._distances_from(l["a"])
			var via := int(dist_entry.get(e[0], 99)) + 1 + int(dl.get(e[1], 99))
			var via2 := int(dist_entry.get(e[1], 99)) + 1 + int(dl.get(e[0], 99))
			if mini(via, via2) <= int(dist_entry.get(l["a"], 99)) + 1:
				on_way += 1.0
		cands.append({"e": e, "w": on_way + rng.randf()})
	cands.sort_custom(func(x, y): return float(x["w"]) > float(y["w"]))
	for i in mini(n, cands.size()):
		var e: Array = cands[i]["e"]
		var mid: Vector3 = host._edge_mid(e[0], e[1])
		var pile := _sprite(_tex(GUTS_PILE, Color(0.30, 0.10, 0.10)), 0.46)
		pile.position = Vector3(mid.x, _floor_y() - 0.04, mid.z)
		_floor_decal(mid, e[0], e[1], _tex(GUTS_TRAIL, Color(0.30, 0.04, 0.04)), Vector2(0.5, 1.0))
		_wall_splat(mid, e[0], e[1])
		_traps[_key(e[0], e[1])] = {"a": e[0], "b": e[1], "pile": pile, "sprung": false, "done": false}


func is_trap(a: Vector2i, b: Vector2i) -> bool:
	var t = _traps.get(_key(a, b))
	return t != null and not bool(t["done"])


func spring_trap(a: Vector2i, b: Vector2i) -> void:
	var t = _traps.get(_key(a, b))
	if t == null:
		return
	t["sprung"] = true
	tension = minf(1.0, tension + 0.35)
	_bite_t = 0.0
	# It heard that; it is coming, whatever level it is.
	_noise_at = a
	_noise_loud = 3
	if _phase == BUILD or _phase == RELAX:
		_enter_phase(STALK)
	_sound_at("rac_giggle.mp3", _far_node(host._node, 2), -4.0)


func trap_done(a: Vector2i, b: Vector2i) -> void:
	var t = _traps.get(_key(a, b))
	if t == null:
		return
	t["done"] = true
	var pile: Sprite3D = t["pile"]
	pile.scale = Vector3(1.4, 0.35, 1.0)


func _key(a: Vector2i, b: Vector2i) -> String:
	var lo := a if (a.x < b.x or (a.x == b.x and a.y < b.y)) else b
	var hi := b if lo == a else a
	return "%d,%d|%d,%d" % [lo.x, lo.y, hi.x, hi.y]


func _tex(path: String, fallback: Color) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return blob_texture(fallback, path.hash())


## Just above the trickle along the invert.
func _floor_y() -> float:
	return 0.045


func _floor_decal(mid: Vector3, a: Vector2i, b: Vector2i, tex: Texture2D, size: Vector2) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = size
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 0.15
	m.metallic_specular = 0.9
	mi.material_override = m
	mi.position = Vector3(mid.x, _floor_y() + 0.004, mid.z) + _along(a, b) * rng.randf_range(-0.7, 0.7)
	mi.rotation.y = atan2(_along(a, b).x, _along(a, b).z) + rng.randf_range(-0.15, 0.15)
	host._geo.add_child(mi)


func _wall_splat(mid: Vector3, a: Vector2i, b: Vector2i) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	var sz := rng.randf_range(0.3, 0.55)
	q.size = Vector2(sz, sz)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex(GUTS_SPLAT, Color(0.32, 0.03, 0.03))
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 0.2
	mi.material_override = m
	var al := _along(a, b)
	var side := Vector3(al.z, 0, -al.x) * (1.0 if rng.randf() < 0.5 else -1.0)
	var centre := Vector3(mid.x, host.PIPE_R * 0.9, mid.z) + al * rng.randf_range(-1.0, 1.0)
	mi.position = centre + side * (host.PIPE_R * 0.9) + Vector3(0, rng.randf_range(-0.15, 0.2), 0)
	host._geo.add_child(mi)
	mi.look_at(centre, Vector3.UP)
	mi.rotate_object_local(Vector3.UP, PI)
	mi.rotate_object_local(Vector3.FORWARD, rng.randf_range(-PI, PI))


func _along(a: Vector2i, b: Vector2i) -> Vector3:
	return Vector3(float(b.x - a.x), 0, float(b.y - a.y)).normalized()


## Its guts let go where it stands: the heap, the walls round it, the splat.
func _burst_at(c: Vector2i) -> void:
	var p := _floor(c)
	var pile := _sprite(_tex(GUTS_PILE, Color(0.30, 0.10, 0.10)), 0.32)
	pile.position = p + Vector3(0, -0.03, 0)
	for d in host._links[c]:
		var n: Vector2i = c + host.DIRS[d]
		_wall_splat(host._world_pos(c).lerp(host._world_pos(n), 0.18), c, n)
		_floor_decal(host._world_pos(c).lerp(host._world_pos(n), 0.25), c, n, _tex(GUTS_TRAIL, Color(0.30, 0.04, 0.04)), Vector2(0.4, 0.8))
	_sound_at("rac_splat.mp3", c, 2.0)


# ── what the host tells it ───────────────────────────────────────────────────

## A sound you made at a junction: 1 a crawl or a turn of the head, 2 the clamp ringing
## or tearing at a snare.
func heard(at: Vector2i, loud: int) -> void:
	if loud >= _noise_loud or _noise_at.x < 0:
		_noise_at = at
		_noise_loud = loud
	if loud >= 2 and level == 1 and rng.randf() < 0.3:
		# It answers the clamp from far off, the low nights: claws on the crown.
		_sound_at("rac_scurry.mp3", _far_node(host._node, 2), -6.0)


## Each pull you make: some nights something behind you makes it too, a moment later.
func on_pull() -> void:
	if _echo_left > 0:
		_echo_left -= 1
		var back: int = (int(host._facing) + 2) % 4
		var at: Vector2i = host._node
		if host._links[at].has(back):
			at = at + host.DIRS[back]
		var p := _sound_at("echo_pull.mp3", at, -5.0)
		if p != null:
			p.pitch_scale = rng.randf_range(0.95, 1.08)


## You have stopped making any noise (standing at a junction).
func is_drip_muted() -> bool:
	return _drip_mute_t > 0.0


# ── per frame ─────────────────────────────────────────────────────────────────

func tick(delta: float) -> void:
	_phase_t += delta
	_drip_mute_t = maxf(0.0, _drip_mute_t - delta)
	flicker = maxf(0.0, flicker - delta * 1.5)
	_update_lure(delta)
	_sign_t -= delta
	if _sign_t <= 0.0 and _scene.is_empty():
		_sign_t = rng.randf_range(6.0, 12.0) * (0.8 if night else 1.0) / (1.0 + 0.2 * float(level - 1))
		_sign()
	var d := _dist()
	tension = clampf(tension + delta * (0.09 if d <= 2 else -0.03), 0.0, 1.0)
	if _burst >= 0.0:
		_update_breath(d, delta)
		_animate_body(delta)
		return
	if level == 1:
		# The low nights it only watches and makes its noises: the eyes, nothing closer.
		_update_scene(delta)
		_update_breath(d, delta)
		_animate_body(delta)
		return
	_update_phase(d)
	_update_scene(delta)
	if _scene.is_empty():
		_update_light(delta, d)
		_update_movement(delta, d)
	_update_breath(d, delta)
	_animate_body(delta)


func _dist() -> int:
	return int(host._distances_from(host._node).get(node, 99))


func _update_phase(d: int) -> void:
	match _phase:
		BUILD:
			if _phase_t >= _phase_len:
				_enter_phase(STALK)
		STALK:
			if _phase_t >= 22.0 or (d <= 3 and _phase_t >= 5.0 and rng.randf() < 0.02):
				_enter_phase(PEAK)
		PEAK:
			if _scene.is_empty() and _phase_t >= 1.0:
				if not _stage_scene():
					if _phase_t >= 10.0:
						_enter_phase(RELAX)
		RELAX:
			if _phase_t >= _phase_len:
				_enter_phase(BUILD)


func _enter_phase(p: int) -> void:
	_phase = p
	_phase_t = 0.0
	match p:
		BUILD:
			_phase_len = rng.randf_range(10.0, 20.0) * (0.75 if night else 1.0) / (1.0 + 0.25 * float(level - 1))
		RELAX:
			_phase_len = rng.randf_range(12.0, 22.0) / (1.0 + 0.2 * float(level - 1))
			_noise_at = Vector2i(-1, -1)
			var away := _far_node(host._node, 4)
			if not body.visible:
				node = away
				_body_pos = _floor(node)
				_body_to = _body_pos
			_sound_at("rac_scurry.mp3", node, -8.0)


# ── the honest animal: moving, light, the catch ─────────────────────────────────

func _update_movement(delta: float, d: int) -> void:
	_move_t += delta
	var hunting: bool = _noise_at.x >= 0 and (level >= 3 or bool(host._stuck))
	var wait := (HUNT_SEC if hunting else WANDER_SEC) * (NIGHT_MULT if night else 1.0)
	if _phase == STALK:
		wait *= 0.8
	if host._stuck:
		wait *= 0.6
	if _move_t < wait:
		return
	_move_t = 0.0
	var step := node
	# Level 2 keeps its distance unless you are caught in its snare.
	var min_dist := 1 if (level >= 3 or host._stuck) else 2
	if _phase == BUILD:
		min_dist = maxi(min_dist, 3)
	elif _phase == RELAX:
		min_dist = 4
	if hunting:
		step = host._next_step_toward(node, _noise_at)
		if step == node:
			_noise_at = Vector2i(-1, -1)
			_noise_loud = 0
	elif _phase == STALK:
		step = host._next_step_toward(node, host._node)
	else:
		var opts: Array = host._links[node]
		if not opts.is_empty():
			step = node + host.DIRS[opts[rng.randi() % opts.size()]]
	if step == node:
		return
	var nd := int(host._distances_from(host._node).get(step, 99))
	if nd == 0 or (host._moving and step == host._move_target_node):
		if host._stuck:
			# Stuck in the snare: it bites at you and is off again (the snare's price).
			if _warned_t >= 1.2:
				_warned_t = 0.0
				host.bitten(BITE)
				_enter_phase(RELAX)
			return
		if level >= 3 and _warned_t >= 1.8:
			_warned_t = 0.0
			host.caught_by_thing()
			_after_catch()
		return
	if nd < min_dist:
		return
	_move_to(step)


func _move_to(step: Vector2i) -> void:
	node = step
	_body_to = _floor(node)
	if rng.randf() < 0.4:
		_sound_at("rac_scurry.mp3", node, -9.0)


## Next door: the chittering, wet and quick. After that warning it comes.
func _update_breath(d: int, delta: float) -> void:
	var db := -60.0
	if level >= 2:
		if d <= 1:
			db = -3.0
		elif d == 2:
			db = -15.0
	_breath.volume_db = lerpf(_breath.volume_db, db, clampf(delta * 3.0, 0.0, 1.0))
	if db > -50.0 and not _breath.playing:
		_breath.play()
	if d <= 1 and level >= 2:
		_chitter_t -= delta
		if _chitter_t <= 0.0:
			_chitter_t = rng.randf_range(1.0, 1.8)
			_sound_at("rac_chitter.mp3", node, -6.0)
		_warned_t += delta
		flicker = maxf(flicker, 0.35)
		if _warned_t >= 2.4 and _scene.is_empty() and not host._moving and level >= 3:
			_move_t = 999.0
			_noise_at = host._node
			_noise_loud = 3
	else:
		_warned_t = 0.0


## The torch on it down a straight pipe: it rears up, holds still, and bursts.
func _update_light(delta: float, d: int) -> void:
	if _seen():
		body.visible = true
		_lit_t += delta
		_standing = true
		if _lit_t >= LIGHT_SEC:
			_lit_t = 0.0
			_flinch()
	else:
		_lit_t = 0.0
		_standing = false
		body.visible = d <= 5 and _in_beam_line(node)


func _seen() -> bool:
	return host._flashlight.visible and _in_beam_line(node)


## Whether `c` is down the pipe your torch points along (ahead, into the side pipe you
## look into, or back over your shoulder).
func _in_beam_line(c: Vector2i) -> bool:
	if host._moving or host._turning:
		return false
	var facing: int = host.beam_dir()
	var at: Vector2i = host._node
	for i in 6:
		if not host._links[at].has(facing):
			return false
		at = at + host.DIRS[facing]
		if at == c:
			return true
	return false


## Too long in your light: it stands, holds, and its belly opens (three frames), then it
## lets its guts go and is off into the dark.
func _flinch() -> void:
	if _burst >= 0.0:
		return
	_sound_at("rac_screech.mp3", node, 0.0)
	_scene = {}
	_burst = 0.0
	_standing = true
	body.visible = true
	_body_to = _body_pos
	tension = minf(1.0, tension + 0.25)


func _finish_burst() -> void:
	_burst = -1.0
	_burst_at(node)
	flicker = 1.0
	body.visible = false
	_standing = false
	_retreat(3)
	if _phase == STALK or _phase == PEAK or _phase == BUILD:
		_enter_phase(RELAX)


func _retreat(steps: int) -> void:
	for _i in steps:
		var dist: Dictionary = host._distances_from(host._node)
		var best := node
		var best_d := int(dist.get(node, 0))
		for dd in host._links[node]:
			var n: Vector2i = node + host.DIRS[dd]
			if int(dist.get(n, 0)) > best_d and n != host._node:
				best_d = int(dist[n])
				best = n
		if best != node:
			node = best
	_body_pos = _floor(node)
	_body_to = _body_pos
	_noise_at = Vector2i(-1, -1)
	_noise_loud = 0


func _after_catch() -> void:
	node = _far_node(host._entry, 4)
	_body_pos = _floor(node)
	_body_to = _body_pos
	body.visible = false
	_enter_phase(RELAX)


# ── the staged looks ─────────────────────────────────────────────────────────

## Tries to set up one look at it that fits where you are. True if one started.
func _stage_scene() -> bool:
	if host._moving or host._at_leak or host._stuck:
		return false
	var ahead: Array = _line_ahead()
	var kinds: Array = ["stand", "crossing", "peek", "eyes"]
	if level >= 3:
		kinds.append("behind")
	kinds.shuffle()
	for k in kinds:
		if _try_scene(k, ahead):
			return true
	return false


func _try_scene(k: String, ahead: Array) -> bool:
	match k:
		"eyes":
			if ahead.size() >= 2:
				var j: Vector2i = ahead[mini(ahead.size() - 1, rng.randi_range(1, 3))]
				_scene = {"kind": "eyes", "t": 0.0, "at": j, "len": rng.randf_range(1.6, 3.2)}
				return true
		"crossing":
			# Across a junction ahead that has side arms, low, dragging its belly.
			for i in range(1, ahead.size()):
				var j: Vector2i = ahead[i]
				if _side_arms(j).size() >= 1 and _unseen_teleport_ok(j):
					var arms := _side_arms(j)
					node = j
					_scene = {"kind": "crossing", "t": 0.0, "at": j, "dir": arms[rng.randi() % arms.size()]}
					_sound_at("rac_scurry.mp3", j, -3.0)
					return true
		"peek":
			if ahead.size() >= 2:
				var j2: Vector2i = ahead[1]
				var arms2 := _side_arms(j2)
				if not arms2.is_empty() and _unseen_teleport_ok(j2):
					var side: int = arms2[rng.randi() % arms2.size()]
					node = j2 + host.DIRS[side]
					_scene = {"kind": "peek", "t": 0.0, "at": j2, "dir": side, "lit": 0.0}
					return true
		"stand":
			if ahead.size() >= 2:
				var j3: Vector2i = ahead[mini(ahead.size() - 1, rng.randi_range(1, 3))]
				if _unseen_teleport_ok(j3):
					node = j3
					_body_pos = _floor(node)
					_body_to = _body_pos
					_scene = {"kind": "stand", "t": 0.0, "lit": 0.0}
					return true
		"behind":
			var back: int = (int(host._facing) + 2) % 4
			if host._links[host._node].has(back):
				var bn: Vector2i = host._node + host.DIRS[back]
				node = bn
				_body_pos = _floor(node)
				_body_to = _body_pos
				_scene = {"kind": "behind", "t": 0.0}
				_sound_at("rac_giggle.mp3", bn, 0.0)
				return true
		"lure":
			pass
	return false


## The junctions straight ahead of you (index 0 = the next one), up to the first wall.
func _line_ahead() -> Array:
	var out: Array = []
	var at: Vector2i = host._node
	var facing: int = host.beam_dir()
	for i in 6:
		if not host._links[at].has(facing):
			break
		at = at + host.DIRS[facing]
		out.append(at)
	return out


func _side_arms(j: Vector2i) -> Array:
	var f: int = host.beam_dir()
	var out: Array = []
	for d in host._links[j]:
		if d != f and d != (f + 2) % 4:
			out.append(d)
	return out


## It may be put somewhere unseen if that is no closer than it has told you it was.
func _unseen_teleport_ok(c: Vector2i) -> bool:
	if body.visible:
		return false
	var dist: Dictionary = host._distances_from(host._node)
	return int(dist.get(c, 0)) >= 2 or _dist() <= 2


func _update_scene(delta: float) -> void:
	if _scene.is_empty():
		peek.visible = false
		eyes.visible = false
		return
	_scene["t"] = float(_scene["t"]) + delta
	var t: float = _scene["t"]
	match str(_scene["kind"]):
		"eyes":
			# Two dots down the pipe, at the edge of the beam. They blink, once, and go.
			var j: Vector2i = _scene["at"]
			eyes.position = _floor(j) + Vector3(0, 0.2, 0)
			var blink := fmod(t, 1.7) > 1.55
			eyes.visible = not blink and not host._moving
			if t >= float(_scene["len"]) or host._moving:
				eyes.visible = false
				_scene = {}
				if level >= 2:
					_enter_phase(RELAX)
		"crossing":
			var j: Vector2i = _scene["at"]
			var dir: Vector3 = Vector3(host.DIRS[int(_scene["dir"])].x, 0, host.DIRS[int(_scene["dir"])].y)
			var k := clampf(t / 0.8, 0.0, 1.0)
			_body_pos = _floor(j) + dir * lerpf(1.1, -1.1, k)
			_body_to = _body_pos
			_standing = false
			body.visible = k < 1.0
			if t >= 0.85:
				var other: int = (int(_scene["dir"]) + 2) % 4
				_floor_decal(host._world_pos(j), j, j + host.DIRS[other], _tex(GUTS_TRAIL, Color(0.30, 0.04, 0.04)), Vector2(0.42, 1.2))
				node = j + host.DIRS[other] if host._links[j].has(other) else j
				_body_pos = _floor(node)
				_body_to = _body_pos
				body.visible = false
				_scene = {}
				_enter_phase(RELAX)
		"peek":
			var j2: Vector2i = _scene["at"]
			var side := Vector3(host.DIRS[int(_scene["dir"])].x, 0, host.DIRS[int(_scene["dir"])].y)
			peek.visible = true
			peek.flip_h = _side_is_left(int(_scene["dir"]))
			var out_k := clampf(t / 0.6, 0.0, 1.0)
			peek.position = _floor(j2) + side * lerpf(0.9, 0.55, out_k)
			var lit: bool = host._flashlight.visible and _in_beam_line(j2)
			if lit:
				_scene["lit"] = float(_scene["lit"]) + delta
			if float(_scene["lit"]) >= 0.6 or t >= 5.0:
				_sound_at("rac_screech.mp3", j2, -2.0)
				peek.visible = false
				_scene = {}
				_retreat(1)
				_enter_phase(RELAX)
		"stand":
			# Upright at the end of your beam, arms down, still. In the light it holds,
			# then lets go of its guts and is gone. In the dark it comes one closer.
			body.visible = true
			_standing = true
			var lit2: bool = host._flashlight.visible and _in_beam_line(node)
			if lit2:
				_scene["lit"] = float(_scene["lit"]) + delta
				if float(_scene["lit"]) >= 0.9:
					flicker = 1.0
				if float(_scene["lit"]) >= 1.3:
					_scene = {}
					_flinch()
			elif t >= 3.0:
				_standing = false
				_move_to(host._next_step_toward(node, host._node))
				_scene = {}
		"behind":
			flicker = maxf(flicker, 0.5)
			_standing = true
			body.visible = host.glancing
			if host.glancing and host._flashlight.visible:
				_scene = {}
				_flinch()
			elif t >= 4.5:
				_scene = {}
				host.caught_by_thing()
				_after_catch()


func _side_is_left(dir: int) -> bool:
	return dir == (int(host.beam_dir()) + 3) % 4


# ── its mischief ─────────────────────────────────────────────────────────────

## Something small and wrong, far enough off to doubt; more and worse the higher it is.
func _sign() -> void:
	var pool := ["chitter", "scurry", "drip_stop", "hum", "rummage", "eyes"]
	if level >= 2:
		pool.append_array(["echo", "lure", "giggle"])
	var pick: String = pool[rng.randi() % pool.size()]
	match pick:
		"chitter":
			_sound_at("rac_chitter.mp3", _far_node(host._node, 3), -6.0)
		"scurry":
			# Claws over the crown, close, along a pipe beside yours.
			_sound_at("rac_scurry.mp3", _far_node(host._node, 1), -4.0)
		"drip_stop":
			_drip_mute_t = rng.randf_range(4.0, 7.0)
		"hum":
			_hum.volume_db = -14.0
			host.create_tween().tween_property(_hum, "volume_db", -24.0, 5.0)
		"rummage":
			_sound_at("rac_chew.mp3", _far_node(host._node, 3), -8.0)
		"eyes":
			if _scene.is_empty():
				_try_scene("eyes", _line_ahead())
		"echo":
			_echo_left = rng.randi_range(3, 5)
		"giggle":
			_sound_at("rac_giggle.mp3", _far_node(host._node, 2), -6.0)
		"lure":
			_start_lure()


## It hisses like a hole from a pipe where there is none: follow the sound and it is a
## dead end (follow the water, not the noise).
func _start_lure() -> void:
	if _lure_t > 0.0 or host._fixed:
		return
	var at := _far_node(host._node, 2)
	if _lure == null:
		_lure = AudioStreamPlayer3D.new()
		_lure.bus = host.audio_bus()
		if ResourceLoader.exists(host.SFX_LEAK):
			var s := (load(host.SFX_LEAK) as AudioStream).duplicate()
			if s is AudioStreamMP3:
				(s as AudioStreamMP3).loop = true
			_lure.stream = s
		_lure.max_distance = 14.0
		host._geo.add_child(_lure)
	_lure.position = host._world_pos(at) + Vector3(0, 0.4, 0)
	_lure.volume_db = 1.0
	_lure.play()
	_lure_t = rng.randf_range(6.0, 10.0)


func _update_lure(delta: float) -> void:
	if _lure_t <= 0.0:
		return
	_lure_t -= delta
	if _lure_t <= 0.0 and _lure != null:
		_lure.stop()
		_sound_at("rac_giggle.mp3", _far_node(host._node, 2), -8.0)


# ── helpers ───────────────────────────────────────────────────────────────────

func _far_node(from: Vector2i, at_least: int) -> Vector2i:
	var dist: Dictionary = host._distances_from(from)
	var cands: Array = []
	var best := from
	var best_d := -1
	for c in dist.keys():
		var dd := int(dist[c])
		if dd >= at_least:
			cands.append(c)
		if dd > best_d:
			best_d = dd
			best = c
	if cands.is_empty():
		return best
	return cands[rng.randi() % cands.size()]


func _floor(c: Vector2i) -> Vector3:
	return host._world_pos(c) + Vector3(0, -host.EYE_Y, 0)


func _animate_body(delta: float) -> void:
	_anim_t += delta
	var moving := _body_pos.distance_to(_body_to) > 0.02
	if moving:
		_body_pos = _body_pos.move_toward(_body_to, CRAWL_SPEED * delta)
	body.position = _body_pos
	var want: Texture2D = _tex_crawl
	var h := CRAWL_H
	if _burst >= 0.0:
		_burst += delta
		var i := mini(int(_burst / BURST_FRAME), _belly.size() - 1)
		want = _belly[i]
		h = STAND_H
		if _burst >= BURST_FRAME * float(_belly.size()) + 0.35:
			_finish_burst()
			return
	elif _standing:
		want = _tex_stand
		h = STAND_H
		# Now and then the head goes over onto its shoulder for a moment.
		_twitch_t -= delta
		if _tex_twitch != null and _twitch_t < 0.17:
			want = _tex_twitch
			if _twitch_t <= 0.0:
				_twitch_t = rng.randf_range(1.2, 2.6)
	elif moving:
		# Crawling: the two steps of it, in steps (mirrored if there is only the one).
		var f := int(floorf(_anim_t * 8.0)) % 2
		if _tex_crawl_b != null:
			want = _tex_crawl if f == 0 else _tex_crawl_b
			body.flip_h = false
		else:
			body.flip_h = f == 1
	if body.texture != want:
		_set_tex(body, want, h)


func _sound_at(file: String, c: Vector2i, db: float) -> AudioStreamPlayer3D:
	if not ResourceLoader.exists(SFX + file):
		return null
	var p := AudioStreamPlayer3D.new()
	p.bus = host.audio_bus()
	p.stream = load(SFX + file)
	p.volume_db = db
	p.max_distance = 26.0
	p.unit_size = 4.0
	host._geo.add_child(p)
	p.position = host._world_pos(c)
	p.play()
	p.finished.connect(p.queue_free)
	return p
