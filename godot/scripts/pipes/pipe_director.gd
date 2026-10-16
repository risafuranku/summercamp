extends RefCounted

## What lives in the camp sewer, and the hand that stages it (DESIGN §8). The pipe crawl
## (scripts/sewer_pipe_minigame.gd) owns the pipes, your movement, the map and the
## clamp; this decides what you hear and see of the thing, and when.
##
## Two layers:
##   - the thing itself is honest: it is at one junction of the network, it is blind and
##     goes to where it last heard you (boots, the clamp), light down a straight pipe
##     drives it back, and it can only take you from the junction next to you after it
##     has breathed at you. Every catch can be explained afterwards.
##   - the director plays with you around that: build-up (signs only), stalking (it comes
##     closer, the breathing, the torch flickers), one staged look at it (it crosses a
##     junction far ahead, it peeks round the next corner, it is crouched at the end of
##     your beam, it is behind you), then it backs off and leaves you alone for a while.
##     While nobody can see it, it may be somewhere else than you think: unseen, it is
##     moved to set the next scene up, never closer than its sounds have told you.
## How much of it you meet grows with the visits (the camp office keeps count):
##   1st time down: it never shows. Knocks answer your clamp from far off, the drip stops
##                  when you stop, something heavy moves through water far away; when
##                  you get back to the ladder there are wet hand prints on the rungs.
##   2nd time:      it is real but careful: glimpses, peeks, nothing closer than two
##                  junctions unless you make the clamp ring.
##   3rd and on:    the hunt.

const SFX := "res://assets/sfx/pipes/"
const SPRITE_CRAWL_A := "res://assets/textury/npc/pipe_crawl_a.png"
const SPRITE_CRAWL_B := "res://assets/textury/npc/pipe_crawl_b.png"
const SPRITE_PEEK := "res://assets/textury/npc/pipe_peek.png"
const BODY_HEIGHT := 0.82
const PEEK_HEIGHT := 1.1
const CRAWL_SPEED := 3.6
## Seconds between its moves while hunting a sound / wandering (night is quicker).
const HUNT_SEC := 2.8
const WANDER_SEC := 6.0
const NIGHT_MULT := 0.75
const LIGHT_SEC := 0.9
const DAMAGE := 30

enum { BUILD, STALK, PEAK, RELAX }

var host                          # the minigame
var visit := 1
var night := false
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
var _warned_t := 0.0               # how long it has breathed at you from next door
var _behind_t := 0.0
var _scene := {}                   # the staged look: {kind, t, ...}
var _clamp_clanks := 0
var _reply_t := -1.0
var _drip_mute_t := 0.0
var tension := 0.0
var flicker := 0.0                 # the torch stutters (0..1), the host reads it

var body: Sprite3D
var peek: Sprite3D
var _tex_a: Texture2D
var _tex_b: Texture2D
var _body_pos := Vector3.ZERO
var _body_to := Vector3.ZERO
var _anim_t := 0.0
var _breath: AudioStreamPlayer
var _hum: AudioStreamPlayer


func start(host_node, visit_number: int, at_night: bool, seed_value: int) -> void:
	host = host_node
	visit = maxi(1, visit_number)
	night = at_night
	rng.seed = seed_value
	_phase = BUILD
	_phase_t = 0.0
	_phase_len = rng.randf_range(16.0, 26.0)
	_sign_t = rng.randf_range(5.0, 9.0)
	_noise_at = Vector2i(-1, -1)
	_scene = {}
	_clamp_clanks = 0
	_reply_t = -1.0
	tension = 0.0
	flicker = 0.0
	_warned_t = 0.0
	_build_nodes()
	node = _far_node(host._entry, 4)
	_body_pos = _floor(node)
	_body_to = _body_pos
	body.visible = false
	peek.visible = false


func stop() -> void:
	if _breath != null:
		_breath.stop()
	if _hum != null:
		_hum.stop()


## Whether the thing is down here at all this time.
func is_real() -> bool:
	return visit >= 2


func _build_nodes() -> void:
	_tex_a = load(SPRITE_CRAWL_A) if ResourceLoader.exists(SPRITE_CRAWL_A) else null
	_tex_b = load(SPRITE_CRAWL_B) if ResourceLoader.exists(SPRITE_CRAWL_B) else null
	body = _sprite(_tex_a, BODY_HEIGHT)
	peek = _sprite(load(SPRITE_PEEK) if ResourceLoader.exists(SPRITE_PEEK) else null, PEEK_HEIGHT)
	if _breath == null:
		_breath = _loop(SFX + "breath.mp3")
		_hum = _loop(SFX + "hum.mp3")
	_breath.volume_db = -60.0
	_hum.volume_db = -24.0
	_hum.play()


func _sprite(tex: Texture2D, height: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = true
	s.double_sided = true
	if tex != null:
		s.pixel_size = height / float(tex.get_height())
		s.offset = Vector2(0.0, tex.get_height() * 0.5)
	host._geo.add_child(s)
	return s


func _loop(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	if ResourceLoader.exists(path):
		var s = load(path)
		if s is AudioStreamMP3:
			s = (s as AudioStreamMP3).duplicate()
			s.loop = true
		p.stream = s
	host.add_child(p)
	return p


# ── what the host tells it ───────────────────────────────────────────────────

## A sound you made at a junction: 1 a step, 2 the clamp ringing.
func heard(at: Vector2i, loud: int) -> void:
	if loud >= _noise_loud or _noise_at.x < 0:
		_noise_at = at
		_noise_loud = loud
	if loud >= 2:
		_clamp_clanks += 1
		# Something answers the clamp, from far off, a moment later.
		if _clamp_clanks % 3 == 0 and _reply_t < 0.0 and rng.randf() < (0.8 if visit == 1 else 0.45):
			_reply_t = rng.randf_range(1.2, 2.4)


## You have stopped making any noise (standing at a junction).
func is_drip_muted() -> bool:
	return _drip_mute_t > 0.0


# ── per frame ─────────────────────────────────────────────────────────────────

func tick(delta: float) -> void:
	_phase_t += delta
	_drip_mute_t = maxf(0.0, _drip_mute_t - delta)
	flicker = maxf(0.0, flicker - delta * 1.5)
	if _reply_t >= 0.0:
		_reply_t -= delta
		if _reply_t < 0.0:
			_sound_at("knock.mp3", _far_node(host._node, 3), -2.0)
	_sign_t -= delta
	if _sign_t <= 0.0 and _scene.is_empty():
		_sign_t = rng.randf_range(7.0, 14.0) * (0.8 if night else 1.0)
		if _phase == BUILD or _phase == RELAX or not is_real():
			_sign()
	if not is_real():
		body.visible = false
		peek.visible = false
		_breath.volume_db = -60.0
		return
	var d := _dist()
	tension = clampf(tension + delta * (0.08 if d <= 2 else -0.04), 0.0, 1.0)
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
			if _phase_t >= 26.0 or (d <= 3 and _phase_t >= 6.0 and rng.randf() < 0.02):
				_enter_phase(PEAK)
		PEAK:
			if _scene.is_empty() and _phase_t >= 1.0:
				if not _stage_scene():
					if _phase_t >= 12.0:
						_enter_phase(RELAX)
		RELAX:
			if _phase_t >= _phase_len:
				_enter_phase(BUILD)


func _enter_phase(p: int) -> void:
	_phase = p
	_phase_t = 0.0
	match p:
		BUILD:
			_phase_len = rng.randf_range(12.0, 22.0) * (0.75 if night else 1.0)
		RELAX:
			_phase_len = rng.randf_range(14.0, 24.0)
			_noise_at = Vector2i(-1, -1)
			# It goes away for a while: the splash of it leaving, far off.
			var away := _far_node(host._node, 4)
			if not _seen():
				node = away
				_body_pos = _floor(node)
				_body_to = _body_pos
			_sound_at("splash_far.mp3", node, -6.0)


# ── the honest thing: moving, light, the catch ────────────────────────────────

func _update_movement(delta: float, d: int) -> void:
	_move_t += delta
	var hunting := _noise_at.x >= 0
	var wait := (HUNT_SEC if hunting else WANDER_SEC) * (NIGHT_MULT if night else 1.0)
	if _phase == STALK:
		wait *= 0.8
	if _move_t < wait:
		return
	_move_t = 0.0
	var step := node
	var min_dist := 1
	if _phase == BUILD:
		min_dist = 3
	elif _phase == RELAX:
		min_dist = 4
	elif visit == 2 and _noise_loud < 2:
		min_dist = 2
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
		# Into you: only after it has breathed at you from next door long enough.
		if _warned_t >= 1.8:
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
	if rng.randf() < 0.35:
		_sound_at("crawl.mp3", node, -8.0)


## Next door and breathing at you: after a fair warning it comes the last junction.
func _update_breath(d: int, delta: float) -> void:
	var db := -60.0
	if d <= 1:
		db = -1.0
	elif d == 2:
		db = -13.0
	elif d == 3:
		db = -25.0
	_breath.volume_db = lerpf(_breath.volume_db, db, clampf(delta * 3.0, 0.0, 1.0))
	if db > -50.0 and not _breath.playing:
		_breath.play()
	if d <= 1:
		if _warned_t == 0.0:
			host._set_status("Breathing. Wet, right next to you.")
		_warned_t += delta
		flicker = maxf(flicker, 0.35)
		# A step into you is the last thing it does.
		if _warned_t >= 2.6 and _scene.is_empty() and not (host._moving):
			_move_t = 999.0
			_noise_at = host._node
			_noise_loud = 3
	else:
		_warned_t = 0.0


## The torch on it down a straight pipe: you see it, it flinches, it scrambles off.
func _update_light(delta: float, d: int) -> void:
	if _seen():
		body.visible = true
		_lit_t += delta
		if _lit_t >= LIGHT_SEC:
			_lit_t = 0.0
			_flinch()
	else:
		_lit_t = 0.0
		body.visible = d <= 5 and _in_beam_line(node)


func _seen() -> bool:
	return host._flashlight.visible and _in_beam_line(node)


## Whether `c` is straight ahead down the pipe you face (or behind, while you look back).
func _in_beam_line(c: Vector2i) -> bool:
	if host._moving:
		return false
	var facing: int = host._facing
	if host.glancing:
		facing = (facing + 2) % 4
	var at: Vector2i = host._node
	for i in 6:
		if not host._links[at].has(facing):
			return false
		at = at + host.DIRS[facing]
		if at == c:
			return true
	return false


func _flinch() -> void:
	_sound_at("hiss.mp3", node, 0.0)
	host._set_status("It folds away from the light.")
	_retreat(2)
	tension = minf(1.0, tension + 0.25)
	if _phase == STALK or _phase == PEAK:
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
	_body_to = _floor(node)
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
	if host._moving or host._at_leak:
		return false
	var ahead: Array = _line_ahead()
	var kinds: Array = ["stand", "crossing", "peek"]
	if visit >= 3:
		kinds.append("behind")
	if visit == 2:
		kinds = ["crossing", "peek", "stand"]
	kinds.shuffle()
	for k in kinds:
		match k:
			"crossing":
				# A junction 2-4 ahead that has side arms: it goes across it.
				for i in range(1, ahead.size()):
					var j: Vector2i = ahead[i]
					if i >= 2 and _side_arms(j).size() >= 1 and _unseen_teleport_ok(j):
						var arms := _side_arms(j)
						var from_dir: int = arms[rng.randi() % arms.size()]
						node = j
						_scene = {"kind": "crossing", "t": 0.0, "at": j, "dir": from_dir}
						_sound_at("splash_far.mp3", j, -4.0)
						return true
			"peek":
				if ahead.size() >= 2:
					var j2: Vector2i = ahead[1] if ahead.size() > 1 else ahead[0]
					var arms2 := _side_arms(j2)
					if not arms2.is_empty() and _unseen_teleport_ok(j2):
						var side: int = arms2[rng.randi() % arms2.size()]
						node = j2 + host.DIRS[side]
						_scene = {"kind": "peek", "t": 0.0, "at": j2, "dir": side, "lit": 0.0}
						return true
			"stand":
				if ahead.size() >= 3:
					var j3: Vector2i = ahead[mini(ahead.size() - 1, rng.randi_range(2, 3))]
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
					_sound_at("scrape.mp3", bn, 2.0)
					host._set_status("Behind you. Something scraping along the wall.")
					return true
	return false


## The junctions straight ahead of you (index 0 = the next one), up to the first wall.
func _line_ahead() -> Array:
	var out: Array = []
	var at: Vector2i = host._node
	for i in 6:
		if not host._links[at].has(host._facing):
			break
		at = at + host.DIRS[host._facing]
		out.append(at)
	return out


func _side_arms(j: Vector2i) -> Array:
	var out: Array = []
	for d in host._links[j]:
		if d != host._facing and d != (int(host._facing) + 2) % 4:
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
		return
	_scene["t"] = float(_scene["t"]) + delta
	var t: float = _scene["t"]
	match str(_scene["kind"]):
		"crossing":
			# Across the junction from one side arm to the other, in the dark or in your
			# beam; quick, low, gone.
			var j: Vector2i = _scene["at"]
			var dir: Vector3 = Vector3(host.DIRS[int(_scene["dir"])].x, 0, host.DIRS[int(_scene["dir"])].y)
			var k := clampf(t / 0.7, 0.0, 1.0)
			_body_pos = _floor(j) + dir * lerpf(1.3, -1.3, k)
			_body_to = _body_pos
			body.visible = k < 1.0
			if t >= 0.75:
				node = j + host.DIRS[(int(_scene["dir"]) + 2) % 4] if host._links[j].has((int(_scene["dir"]) + 2) % 4) else j
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
			var out_k := clampf(t / 0.4, 0.0, 1.0)
			peek.position = _floor(j2) + side * lerpf(0.95, 0.62, out_k) + Vector3(0, 0.05, 0)
			var lit: bool = host._flashlight.visible and _in_beam_line(j2)
			if lit:
				_scene["lit"] = float(_scene["lit"]) + delta
			if float(_scene["lit"]) >= 0.5 or t >= 5.0:
				_sound_at("hiss.mp3", j2, -2.0)
				peek.visible = false
				_scene = {}
				_retreat(1)
				_enter_phase(RELAX)
		"stand":
			body.visible = true
			var lit2: bool = host._flashlight.visible and _in_beam_line(node)
			if lit2:
				_scene["lit"] = float(_scene["lit"]) + delta
				# The torch gives out for a moment, as if it knew.
				if float(_scene["lit"]) >= 1.0:
					flicker = 1.0
				if float(_scene["lit"]) >= 1.25:
					body.visible = false
					_scene = {}
					_retreat(3)
					_enter_phase(RELAX)
			elif t >= 3.0:
				# In the dark it comes on: one junction closer, then it is the hunt again.
				_move_to(host._next_step_toward(node, host._node))
				_scene = {}
		"behind":
			flicker = maxf(flicker, 0.5)
			body.visible = host.glancing
			if host.glancing and host._flashlight.visible:
				_scene = {}
				_flinch()
			elif t >= 4.5:
				_scene = {}
				host.caught_by_thing()
				_after_catch()


func _side_is_left(dir: int) -> bool:
	return dir == (int(host._facing) + 3) % 4


# ── signs ─────────────────────────────────────────────────────────────────────

## Something small and wrong, far enough off to doubt.
func _sign() -> void:
	var pool := ["knock", "drip_stop", "splash", "hum", "rat"]
	if visit == 1:
		pool.append("knock")
	var pick: String = pool[rng.randi() % pool.size()]
	match pick:
		"knock":
			_sound_at("knock.mp3", _far_node(host._node, 3), -4.0)
		"drip_stop":
			_drip_mute_t = rng.randf_range(4.0, 7.0)
		"splash":
			_sound_at("splash_far.mp3", _far_node(host._node, 3), -8.0)
		"hum":
			_hum.volume_db = -14.0
			host.create_tween().tween_property(_hum, "volume_db", -24.0, 5.0)
		"rat":
			_sound_at("rat.mp3", host._node, -6.0)


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
	return host._world_pos(c) + Vector3(0, -host.EYE_Y + 0.06, 0)


func _animate_body(delta: float) -> void:
	_anim_t += delta
	var moving := _body_pos.distance_to(_body_to) > 0.02
	if moving:
		_body_pos = _body_pos.move_toward(_body_to, CRAWL_SPEED * delta)
	body.position = _body_pos
	# Two crawl frames at 6 a second while it moves (or the one, mirrored).
	var f := int(floorf(_anim_t * 6.0)) % 2
	if moving:
		if _tex_b != null:
			body.texture = _tex_a if f == 0 else _tex_b
		else:
			body.flip_h = f == 1


func _sound_at(file: String, c: Vector2i, db: float) -> void:
	if not ResourceLoader.exists(SFX + file):
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = load(SFX + file)
	p.volume_db = db
	p.max_distance = 26.0
	p.unit_size = 4.0
	host._geo.add_child(p)
	p.position = host._world_pos(c)
	p.play()
	p.finished.connect(p.queue_free)
