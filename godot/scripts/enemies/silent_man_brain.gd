extends "res://scripts/enemies/enemy_base.gd"
class_name SilentManBrain

## The Silent Man: a Quiet Guy guest of yours, turned for the night (DESIGN §5). His hat,
## his glasses, his shirt; where his mouth was, smooth skin. Rule: DO NOT STAND STILL IN
## THE DARK.
##
##   omen      far off, a man humming through a mouth that is sealed shut
##   approach  footsteps on the gravel behind you, every couple of seconds, each set a
##             little closer: a full step when you stand still, half when you walk;
##             running puts you ahead of him. Under a lamp he does not come nearer (a twig
##             now and then where the light ends). His joints crack; close, you hear him
##             breathe through his nose. Turn round and you may catch his silhouette
##             walking, stiff, arms dead at his sides.
##   test      the light: turn round and put light on him (torch or a lamp he stands in)
##             and his glasses flare, he flinches with a hand up, the skin over his mouth
##             bulges with a scream it cannot let out, your torch falters, and he backs
##             off into the dark in steps; the footsteps start again far behind you.
##   strike    at your back he whispers at your ear: about a second to turn round or get
##             away. If not, one of his catches (at your ear, over you from above, or he
##             turns you round to him); the skin over his mouth tears open; he bites.
##   kill      when that bite would be your last, he finishes it his way: the hands round
##             your throat, your neck turned round, or the mouth that opens over your face.
##
## He has a real position (the sprite stands there, lit only by your light), so the HUD
## face and the insects (threat_senses.gd) track the same place you hear.

const N := "res://assets/textury/npc/"
const GUEST := N + "host1.png"
const T_M1 := N + "sm_m1.png"
const T_M2 := N + "sm_m2.png"
const T_WALK := [N + "sm_walk_a.png", N + "sm_walk_b.png"]
const T_LIT := N + "sm_lit.png"
const T_FACE := N + "sm_face.png"
const T_TEAR := N + "sm_face_tear.png"
const T_UPSIDE := N + "sm_face_upside.png"
const T_HANDS := N + "sm_hands.png"
const T_OVER := N + "sm_over.png"
const SFX_STEPS := "res://assets/sfx/npc/silent_steps.mp3"
const SFX_STEP := "res://assets/sfx/npc/sm_step.mp3"
const SFX_WHISPER := "res://assets/sfx/npc/silent_whisper.mp3"
const SFX_TWIG := "res://assets/sfx/npc/twig_snap.mp3"
const SFX_HUM := "res://assets/sfx/npc/sm_hum.mp3"
const SFX_BREATH := "res://assets/sfx/npc/sm_breath.mp3"
const SFX_MMM := "res://assets/sfx/npc/sm_mmm.mp3"
const SFX_CREAK := "res://assets/sfx/npc/sm_creak.mp3"
const SFX_TEAR := "res://assets/sfx/npc/sm_tear.mp3"
const SFX_SNAP := "res://assets/sfx/npc/sm_snap.mp3"
const SFX_CHOKE := "res://assets/sfx/npc/sm_choke.mp3"
const SFX_BITE := "res://assets/sfx/npc/sm_bite.mp3"
const SFX_STING := "res://assets/sfx/npc/sm_sting.mp3"

const START_DIST := 14.0
const NECK_DIST := 1.6
const DARK_LIGHT := 0.35
const RUN_SPEED := 4.2
const HEIGHT := 1.82
const WALK_SECONDS := 0.55
const LIT_SECONDS := 0.9
const STRIKES := ["ear", "above", "turn"]
const KILLS := ["strangle", "snap", "bite"]

var _dist := START_DIST
var _step_gain := 1.6
var _step_interval := 2.2
var _grace := 1.2
var _damage := 16
var _next_step := 0.0
var _resume_at := 0.0
var _neck_until := -1.0
var _neck_from := Vector3.ZERO
var _last_player_pos := Vector3.INF
var _speed := 0.0
var _hits := 0
var _drive_offs := 0
var _peek_until := 0.0
## Seen: he flinches where the light found him and backs off till then, then is gone.
var _vanish_at := -1.0
var _shown_guest := false
var _tex := {}
var _hum: AudioStreamPlayer3D
var _breath: AudioStreamPlayer3D
var _walk_from := Vector3.ZERO
var _walk_to := Vector3.ZERO
var _walk_t := -1.0
var _back_dir := Vector3.ZERO
## A catch in progress: {kind, t, cues, kill, yaw0, roll0}.
var _seq := {}
var _last_strike := ""
var _last_kill := ""


func get_enemy_id() -> String:
	return "silent_man"


func _on_start() -> void:
	var t := float(_difficulty - 1) / 4.0
	_step_gain = lerpf(1.3, 2.2, t)
	_step_interval = lerpf(2.6, 1.6, t)
	_grace = lerpf(1.4, 1.0, t)
	_damage = int(lerpf(14.0, 24.0, t))
	for p in [GUEST, T_M1, T_M2, T_LIT, T_FACE, T_TEAR, T_UPSIDE, T_HANDS, T_OVER] + T_WALK:
		if ResourceLoader.exists(p):
			_tex[p] = load(p)
	_body = _make_body(GUEST, HEIGHT)
	_hum = _loop(SFX_HUM, -60.0)
	_breath = _loop(SFX_BREATH, -60.0)
	_reset_far(_rng.randf_range(3.0, 6.0))
	_peek_until = 0.0


## The night is over (dawn, death, the menu): nothing of a catch stays on the screen.
func _on_stop() -> void:
	_end_seq()
	var fx := _fx()
	if fx != null:
		fx.close_up_off()
		fx.set_black(0.0)
	if _player != null and is_instance_valid(_player):
		_player.set("flashlight_stutter", 0.0)
		if _player.has_method("set_controls_enabled"):
			_player.call("set_controls_enabled", true)


func _on_tick(dt: float) -> void:
	_track_speed(dt)
	if not _seq.is_empty():
		_update_seq(dt)
		return
	_update_walk(dt)
	_update_audio()
	if _vanish_at > 0.0:
		_update_lit(dt)
		return
	var head := _body.global_position + Vector3(0, HEIGHT * 0.86, 0)
	# Caught in the light: he flinches and backs off.
	if _elapsed >= _resume_at and _is_lit_and_seen(head):
		_driven_off()
		return
	if _neck_until > 0.0:
		_tick_neck()
		return
	if _elapsed < _resume_at:
		_body.visible = _elapsed < _peek_until
		return
	_body.visible = true
	if _elapsed >= _next_step:
		_next_step = _elapsed + _step_interval * _rng.randf_range(0.85, 1.15)
		_step()


# ── the approach ─────────────────────────────────────────────────────────────

func _step() -> void:
	var in_light := _lamp_light_at(_player_pos()) >= DARK_LIGHT
	if in_light:
		# He waits where the light ends; now and then a twig gives him away.
		if _rng.randf() < 0.35:
			_sound(SFX_TWIG, _body.global_position + Vector3(0, 0.2, 0), -4.0, _rng.randf_range(0.9, 1.1), 30.0)
		return
	if _speed > RUN_SPEED:
		_dist = minf(START_DIST, _dist + 1.0)
	elif _speed > 0.6:
		_dist -= _step_gain * 0.5
	else:
		_dist -= _step_gain
	_dist = maxf(NECK_DIST, _dist)
	_place_behind(_dist)
	var at := _walk_to + Vector3(0, 0.3, 0)
	_sound(SFX_STEPS, at, lerpf(-10.0, 0.0, 1.0 - _dist / START_DIST), _rng.randf_range(0.94, 1.04), 34.0)
	if _rng.randf() < 0.3:
		_sound(SFX_CREAK, at + Vector3(0, 1.2, 0), lerpf(-14.0, -2.0, 1.0 - _dist / START_DIST), _rng.randf_range(0.9, 1.1), 24.0)
	_announce("Footsteps on the gravel behind you. They stop when you stop.")
	if _dist <= NECK_DIST + 0.01:
		_neck_until = _elapsed + _grace
		_neck_from = _player_pos()
		_sound(SFX_WHISPER, _player_pos() + Vector3(0, 1.55, 0) - _forward_flat() * 0.35, 2.0, 1.0, 8.0)


## Right behind you: turn round or get away, now.
func _tick_neck() -> void:
	var head := _body.global_position + Vector3(0, HEIGHT * 0.86, 0)
	if _is_seen(head, 6.0) or _player_pos().distance_to(_neck_from) > 1.8:
		_neck_until = -1.0
		_driven_off()
		return
	if _elapsed >= _neck_until:
		_neck_until = -1.0
		_hits += 1
		_start_catch()


## Closes in on you along the line from where he stands, so turning round finds him;
## the way there is walked (stiffly, two frames), not jumped.
func _place_behind(dist: float) -> void:
	var from := _body.global_position
	var to := _player_pos()
	var dir := Vector3(from.x - to.x, 0.0, from.z - to.z)
	if dir.length_squared() < 0.01:
		dir = -_forward_flat()
	var p := _ground(to + dir.normalized() * dist)
	if p == Vector3.INF:
		return
	_walk_from = from
	_walk_to = p
	_walk_t = 0.0
	_set_tex(_look_for(dist))


## In steps, twelve a second: the stride frames while he walks, then the stage he is in.
func _update_walk(dt: float) -> void:
	if _walk_t < 0.0:
		return
	_walk_t += dt
	var k := clampf(_walk_t / WALK_SECONDS, 0.0, 1.0)
	var st := floorf(k * WALK_SECONDS * 12.0) / maxf(1.0, WALK_SECONDS * 12.0)
	_body.global_position = _walk_from.lerp(_walk_to, st)
	var frames: Array = T_WALK.filter(func(p): return _tex.has(p))
	if frames.size() == 2 and k < 1.0:
		_set_tex(frames[int(_walk_t * 6.0) % 2])
	if k >= 1.0:
		_walk_t = -1.0
		_body.global_position = _walk_to
		_set_tex(_look_for(_dist))


## The guest himself the first time he is seen from far; then mouthless; near, the long
## neck and arms.
func _look_for(dist: float) -> String:
	if not _shown_guest and dist > 9.0:
		return GUEST
	if dist < 6.0 and _tex.has(T_M2):
		return T_M2
	if _tex.has(T_M1):
		return T_M1
	return GUEST


func _set_tex(path: String) -> void:
	var tex: Texture2D = _tex.get(path)
	if tex == null or _body.texture == tex:
		return
	_body.texture = tex
	# One pixel scale for all of him (the guest's): a stage drawn taller stands taller.
	var guest: Texture2D = _tex.get(GUEST)
	_body.pixel_size = HEIGHT / float(guest.get_height() if guest != null else tex.get_height())
	_body.offset = Vector2(0.0, float(tex.get_height()) * 0.5)
	if path == GUEST:
		_shown_guest = true


func _update_audio() -> void:
	var d := _distance_to_player(_body.global_position)
	if _hum != null:
		_hum.global_position = _body.global_position + Vector3(0, 1.6, 0)
		_hum.volume_db = -60.0 if _elapsed < _resume_at else lerpf(-34.0, -14.0, clampf(1.0 - d / START_DIST, 0.0, 1.0))
	if _breath != null:
		_breath.global_position = _body.global_position + Vector3(0, 1.6, 0)
		_breath.volume_db = -60.0 if (d > 4.5 or _elapsed < _resume_at) else lerpf(-2.0, -22.0, d / 4.5)
	var fx := _fx()
	if fx != null and _elapsed >= _resume_at:
		fx.set_dread("silent_man", clampf(1.0 - _dist / START_DIST, 0.0, 1.0) * 0.8)


# ── the light ────────────────────────────────────────────────────────────────

## Found by the light: the glasses flare, the flinch, the scream behind the skin, the
## torch falters; then he backs off into the dark in steps and is gone.
func _driven_off() -> void:
	_drive_offs += 1
	_walk_t = -1.0
	_set_tex(T_LIT if _tex.has(T_LIT) else _look_for(_dist))
	var head := _body.global_position + Vector3(0, HEIGHT * 0.86, 0)
	_sound(SFX_MMM, head, 0.0, _rng.randf_range(0.92, 1.05), 36.0)
	var away := _body.global_position - _player_pos()
	away.y = 0.0
	_back_dir = away.normalized() if away.length_squared() > 0.01 else -_forward_flat()
	_walk_from = _body.global_position
	_vanish_at = _elapsed + LIT_SECONDS
	_player.set("flashlight_stutter", 1.0)
	var fx := _fx()
	if fx != null:
		fx.glitch(0.3, 0.4)
	_neck_until = -1.0


func _update_lit(_dt: float) -> void:
	_body.visible = true
	var left := _vanish_at - _elapsed
	var k := 1.0 - left / LIT_SECONDS
	# The torch comes back after a moment; his glasses flare in it for a few frames.
	if k > 0.12:
		_player.set("flashlight_stutter", 0.0)
	var fx := _fx()
	var cam := _camera()
	if fx != null and cam != null and k < 0.35:
		fx.set_eyes("silent_man", _body.global_position + Vector3(0, HEIGHT * 0.9, 0), cam, 1.0, 0.0, 0.05)
	# Backing off, in steps, after a beat of the flinch.
	if k > 0.35:
		var st := floorf((k - 0.35) / 0.65 * 7.0) / 7.0
		_body.global_position = _walk_from + _back_dir * 2.6 * st
		var frames: Array = T_WALK.filter(func(p): return _tex.has(p))
		if frames.size() == 2:
			_set_tex(frames[int(st * 7.0) % 2])
	if left <= 0.0:
		_vanish_at = -1.0
		_player.set("flashlight_stutter", 0.0)
		_reset_far(_rng.randf_range(4.0, 8.0))


func _reset_far(pause: float) -> void:
	_dist = START_DIST
	_resume_at = _elapsed + pause
	_next_step = _resume_at + _step_interval
	_walk_t = -1.0
	# Out of sight, somewhere behind you.
	var p := _point_from_player(_dist, 180.0 + _rng.randf_range(-50.0, 50.0))
	if p != Vector3.INF:
		_body.global_position = p
	_set_tex(_look_for(_dist))


# ── the catch and the kill ───────────────────────────────────────────────────

func _start_catch() -> void:
	var kill := _player_health() - _damage <= 0
	var pool: Array = (KILLS if kill else STRIKES).filter(func(k): return k != (_last_kill if kill else _last_strike))
	var kind: String = pool[_rng.randi() % pool.size()]
	if kill:
		_last_kill = kind
	else:
		_last_strike = kind
	var cam := _camera()
	_seq = {"kind": kind, "t": 0.0, "cues": {}, "kill": kill, "yaw0": _player.rotation.y, "roll0": cam.rotation.z if cam != null else 0.0, "pitch0": cam.rotation.x if cam != null else 0.0}
	if _player.has_method("set_controls_enabled"):
		_player.call("set_controls_enabled", false)
	_player.set("flashlight_stutter", 0.0)
	var fx := _fx()
	if fx != null:
		fx.freeze(0.08)
	_sound(SFX_STING, _player_pos() + Vector3(0, 1.5, 0), 3.0)


func _cue(at: float, id: String) -> bool:
	var cues: Dictionary = _seq["cues"]
	if float(_seq["t"]) >= at and not cues.has(id):
		cues[id] = true
		return true
	return false


func _ear(file: String, db: float, pitch: float = 1.0) -> void:
	_sound(file, _player_pos() + Vector3(0, 1.55, 0) - _forward_flat() * 0.3, db, pitch, 10.0)


func _hit_now() -> void:
	_hurt(_damage)
	claimed = true
	var fx := _fx()
	if fx != null:
		fx.red_flash(1.0)
		fx.glitch(1.0, 1.2)
		fx.tinnitus(4.5)


func _update_seq(dt: float) -> void:
	_seq["t"] = float(_seq["t"]) + dt
	var t: float = _seq["t"]
	var st := floorf(t * 12.0) / 12.0
	var fx := _fx()
	var cam := _camera()
	match str(_seq["kind"]):
		"ear":
			# Your head is pulled to the side: his face at your ear; the skin tears; the bite.
			if cam != null:
				cam.rotation.z = float(_seq["roll0"]) + 0.32 * clampf(st / 0.25, 0.0, 1.0)
			_player.rotation.y = float(_seq["yaw0"]) + deg_to_rad(75.0) * clampf(st / 0.25, 0.0, 1.0)
			if fx != null:
				if st < 0.7:
					fx.close_up(_t(T_FACE), lerpf(1.0, 1.25, st / 0.7), 1.0, 0.006, -0.25)
				elif st < 1.15:
					fx.close_up(_t(T_TEAR, T_FACE), lerpf(1.3, 1.9, (st - 0.7) / 0.45), 1.0, 0.02, -0.25)
			if _cue(0.25, "breath"):
				_ear(SFX_BREATH, 4.0)
			if _cue(0.62, "tear"):
				_ear(SFX_TEAR, 4.0)
			if _cue(1.0, "bite"):
				_ear(SFX_BITE, 6.0)
				_hit_now()
			_fade_out(fx, t, 1.15, 1.6)
		"above":
			# He leans over you from behind and above: his face upside down coming down.
			if fx != null:
				if st < 0.8:
					fx.close_up(_t(T_UPSIDE, T_FACE), lerpf(1.05, 1.3, st / 0.8), 1.0, 0.006, 0.0 if _tex.has(T_UPSIDE) else PI, Vector2(0.0, lerpf(-0.9, 0.0, clampf(st / 0.35, 0.0, 1.0))))
				elif st < 1.2:
					fx.close_up(_t(T_TEAR, T_FACE), lerpf(1.4, 2.0, (st - 0.8) / 0.4), 1.0, 0.022, PI)
			if _cue(0.1, "breath"):
				_ear(SFX_BREATH, 4.0, 0.9)
			if _cue(0.7, "tear"):
				_ear(SFX_TEAR, 5.0)
			if _cue(1.05, "bite"):
				_ear(SFX_BITE, 6.0)
				_hit_now()
			_fade_out(fx, t, 1.2, 1.7)
		"turn":
			# You are turned round to him, in three jerks; face to face; the skin tears.
			_player.rotation.y = float(_seq["yaw0"]) + PI * clampf(floorf(st / 0.08) / 3.0, 0.0, 1.0)
			if fx != null:
				if st < 0.3:
					pass
				elif st < 0.8:
					fx.close_up(_t(T_FACE), lerpf(1.1, 1.35, (st - 0.3) / 0.5), 1.0, 0.008)
				elif st < 1.2:
					fx.close_up(_t(T_TEAR, T_FACE), lerpf(1.4, 2.1, (st - 0.8) / 0.4), 1.0, 0.024)
			if _cue(0.3, "mmm"):
				_ear(SFX_MMM, 5.0)
			if _cue(0.75, "tear"):
				_ear(SFX_TEAR, 5.0)
			if _cue(1.05, "bite"):
				_ear(SFX_BITE, 6.0)
				_hit_now()
			_fade_out(fx, t, 1.2, 1.7)
		"strangle":
			# His hands come round from behind and close; the edges go dark; his face
			# presses close; the last thing, your own face small in his glasses.
			if fx != null:
				if st < 1.5:
					fx.close_up(_t(T_HANDS, T_FACE), lerpf(1.9, 1.0, st / 1.5), 1.0, 0.004 + 0.02 * st / 1.5)
					fx.set_dread("silent_man", 1.0)
				elif st < 3.0:
					fx.close_up(_t(T_FACE), lerpf(1.3, 2.4, (st - 1.5) / 1.5), 1.0, 0.02 * (1.0 - (st - 1.5) / 1.5))
					fx.set_black(clampf((st - 1.5) / 1.5, 0.0, 0.85))
			if _cue(0.1, "choke"):
				_ear(SFX_CHOKE, 6.0)
			if _cue(1.4, "breath"):
				_ear(SFX_BREATH, 6.0, 0.85)
			if cam != null:
				cam.rotation.x = float(_seq["pitch0"]) + 0.12 * clampf(st / 1.5, 0.0, 1.0)
			if _cue(3.0, "hit"):
				_hit_now()
			_fade_out(fx, t, 3.0, 3.6)
		"snap":
			# Hands on your head; it is turned round in steps; the crack; from the ground,
			# him standing over you.
			if fx != null and st < 0.6:
				fx.close_up(_t(T_HANDS, T_FACE), lerpf(1.6, 1.15, st / 0.6), 1.0, 0.012)
			var turn := clampf(floorf((st - 0.6) / 0.1) / 6.0, 0.0, 1.0)
			_player.rotation.y = float(_seq["yaw0"]) + PI * turn
			if _cue(0.6, "grind"):
				_ear(SFX_CHOKE, 0.0, 1.3)
			if _cue(1.2, "snap"):
				_ear(SFX_SNAP, 8.0)
				if fx != null:
					fx.red_flash(0.8)
					fx.glitch(0.9, 0.6)
			if cam != null and st >= 1.25:
				cam.rotation.z = float(_seq["roll0"]) + 1.45 * clampf((st - 1.25) / 0.25, 0.0, 1.0)
			if fx != null and st >= 1.5 and st < 2.9:
				fx.close_up(_t(T_OVER, T_FACE), 1.05, 1.0, 0.0, 0.0)
				fx.set_black(clampf((st - 2.0) / 0.9, 0.0, 0.8))
			if _cue(2.9, "hit"):
				_hit_now()
			_fade_out(fx, t, 2.9, 3.4)
		"bite":
			# The skin over his mouth opens over your face and it closes.
			if fx != null:
				if st < 0.5:
					fx.close_up(_t(T_FACE), lerpf(1.0, 1.4, st / 0.5), 1.0, 0.008)
				elif st < 1.3:
					fx.close_up(_t(T_TEAR, T_FACE), lerpf(1.5, 3.2, (st - 0.5) / 0.8), 1.0, 0.02 + 0.02 * (st - 0.5), 0.0, Vector2(0.0, -0.25 * (st - 0.5)))
			if _cue(0.45, "tear"):
				_ear(SFX_TEAR, 6.0, 0.9)
			if _cue(1.1, "bite"):
				_ear(SFX_BITE, 8.0, 0.9)
				if fx != null:
					fx.red_flash(1.0)
			if cam != null and st >= 1.3:
				# You go down.
				cam.rotation.x = float(_seq["pitch0"]) - 0.9 * clampf((st - 1.3) / 0.4, 0.0, 1.0)
				cam.rotation.z = float(_seq["roll0"]) + 0.6 * clampf((st - 1.3) / 0.4, 0.0, 1.0)
			if _cue(1.8, "hit"):
				_hit_now()
			_fade_out(fx, t, 1.3, 2.3)


## After the hit: black, then (a catch, not a kill) the world back, him gone for a while.
func _fade_out(fx, t: float, from: float, to: float) -> void:
	if fx != null and t >= from:
		if t >= from + 0.05:
			fx.close_up_off()
		fx.set_black(clampf((t - from) / 0.25, 0.0, 1.0))
	if t >= to:
		var kill: bool = _seq.get("kill", false)
		_end_seq()
		if not kill:
			_reset_far(_rng.randf_range(12.0, 18.0))


func _end_seq() -> void:
	if _seq.is_empty():
		return
	var cam := _camera()
	if cam != null and is_instance_valid(cam):
		cam.rotation.z = float(_seq["roll0"])
		cam.rotation.x = float(_seq["pitch0"])
	var kill: bool = _seq.get("kill", false)
	_seq = {}
	var fx := _fx()
	if fx != null:
		fx.close_up_off()
		fx.set_black(0.0 if not kill else 1.0)
	if _player != null and is_instance_valid(_player) and _player.has_method("set_controls_enabled") and not kill:
		_player.call("set_controls_enabled", true)


func _t(path: String, fallback: String = GUEST) -> Texture2D:
	return _tex.get(path, _tex.get(fallback, _tex.get(GUEST)))


# ── helpers ──────────────────────────────────────────────────────────────────

func _is_lit_and_seen(head: Vector3) -> bool:
	if not _is_seen(head, 0.0):
		return false
	return _in_flashlight(head) or _lamp_light_at(_body.global_position) >= DARK_LIGHT


func _track_speed(dt: float) -> void:
	var p := _player_pos()
	if _last_player_pos != Vector3.INF and dt > 0.0:
		var flat := Vector2(p.x - _last_player_pos.x, p.z - _last_player_pos.z).length() / dt
		_speed = lerpf(_speed, flat, clampf(dt * 6.0, 0.0, 1.0))
	_last_player_pos = p


func get_debug_snapshot() -> Dictionary:
	return {
		"distance": snappedf(_dist, 0.1),
		"neck": _neck_until > 0.0,
		"paused": _elapsed < _resume_at,
		"hits": _hits,
		"driven_off": _drive_offs,
		"player_speed": snappedf(_speed, 0.1),
		"catch": str(_seq.get("kind", "")),
	}
