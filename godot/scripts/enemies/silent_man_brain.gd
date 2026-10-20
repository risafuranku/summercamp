extends "res://scripts/enemies/enemy_base.gd"
class_name SilentManBrain

## The Silent Man: a Quiet Guy guest of yours, turned for the night (DESIGN §5). His hat,
## his glasses, his shirt; where his mouth was, smooth skin. Rule: DO NOT STAND STILL IN
## THE DARK.
##
## He is the camp's nuisance more than its killer (playtest 18. 10.): light always beats
## him. What he does is be there, round the corner, every time you leave the light.
##
##   lurk      while you are in light (a lamp) or indoors he waits in the dark round a
##             corner 7-13 m off, somewhere you cannot see from where you stand: a man
##             humming through a mouth that is sealed shut. Now and then he leans out
##             past the corner for a moment. Come out of a building and he is round the
##             corner by its door.
##   approach  step out of the light and THE HUMMING STOPS: he is coming. He only moves
##             while you are not looking his way. Walking, his steps fall half a beat
##             after yours (you lose them in your own); stop, and there is one step more
##             after you stopped. Standing still in the dark he comes on slow careful
##             steps, closer each time; running puts you ahead of him. Close, cloth
##             rustling and breath through the nose. Turn round and you may catch him
##             mid-stride, frozen there.
##   test      the light: put light on him (torch or a lamp he stands in) and his glasses
##             flare, a sharp breath, and he comes apart into the dark, a dither of game
##             pixels going back a step, a little dark ash going up; then a new corner.
##   strike    at your back he whispers at your ear: about a second to turn round or get
##             away. If not, one of his catches (at your ear, over you from above, or he
##             turns you round to him); the skin over his mouth tears open; he bites.
##   kill      when that bite would be your last, he finishes it his way: the hands round
##             your throat, your neck turned round, or the mouth that opens over your face.
##
## He has a real position (the sprite stands there, lit only by your light), so the HUD
## face and the insects (threat_senses.gd) track the same place you hear.
##
## The sixth sense (playtest 20. 10.: "the longer he gets to come on in one go, the more
## the game must tell you, by picture and by sound, that something is wrong"): a pressure
## builds while you are out in the dark and he is coming, faster the closer he is, and
## drains in the light. It is what you feel (nightmare_fx.set_presence): a drone in the
## ears that climbs, your heart, slow and then fast, the picture's edges closing in, the
## torch catching and stuttering in your hand. At your neck: his breath, cloth, the
## frame stops for a beat, his hands coming over your shoulder from the side he is on,
## and he holds you (you move at half speed): turn round, or get away.
##
## The first time (the first in this camp, never scripted to a place): when you first
## step out of the light the humming stops and he is there in front of you, at the edge
## of the light, caught mid-stride; look at him and he goes. The first time he reaches
## your neck he does not bite: he turns you round to him, face to face, the skin over his
## mouth pulling, and comes apart into the dark. "Turn round. Put a light on him."
##
## Indoors he does not hurt you (an indoor hunter is another kind of thing): he wants you
## out. Through the wall, the humming; three knocks, then a fourth after you stop
## listening; the handle tried; a hand brushing along the outside wall, following you;
## a tap at the window. Stay in long enough and he goes to your guests instead: a tent
## zip somewhere in the camp, slowly; the guest is not right in the morning.
## In co-op only the warden he hunts feels any of it; the other's torch drives him off
## too (the counter for two: watch each other's backs).

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
const SFX_VANISH := "res://assets/sfx/npc/sm_vanish.mp3"
const SFX_RUSTLE := "res://assets/sfx/npc/sm_rustle.mp3"
const SFX_SOFTSTEP := "res://assets/sfx/npc/sm_softstep.mp3"

const START_DIST := 14.0
const NECK_DIST := 1.6
const DARK_LIGHT := 0.35
const RUN_SPEED := 4.2
const HEIGHT := 1.82
const WALK_SECONDS := 0.55
const LIT_SECONDS := 0.9
const STRIKES := ["ear", "above", "turn"]
## Lurking: how far off, and how dark the spot must be.
const LURK_DIST := Vector2(7.0, 13.0)
const LURK_DARK := 0.15
const DISSOLVE_FRAMES := 6
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
var _lurking := false
var _lurk_spot := Vector3.INF
var _peek_spot := Vector3.INF
var _peek_next := 6.0
var _peek_t := 0.0
var _away := false
var _was_moving := false
var _extra_step_at := -1.0
var _rustle_next := 3.0
var _dissolve := {}                # texture -> Array of ImageTexture (more gone each frame)
var _ash: GPUParticles3D
var _last_kill := ""
## The sixth sense: 0..1, built in the dark while he comes, drained in the light.
var _press := 0.0
var _stutter_next := 2.0
## His hands at your shoulder, from this side (1 right, -1 left), while he holds you.
var _hold_side := 1.0
## The first meeting in this camp: the reveal at the edge of the light, the lesson catch.
var _first := false
var _revealed := false
var _reveal_t := -1.0
var _reveal_seen := 0.0
var _lesson := false
## Indoors: what he does to get you out, in order, and when the next.
var _lure_next := -1.0
var _lure_n := 0
var _indoors := false
var _sound2d: AudioStreamPlayer


func get_enemy_id() -> String:
	return "silent_man"


func _on_start() -> void:
	var t := float(_difficulty - 1) / 4.0
	_step_gain = lerpf(1.3, 2.2, t)
	_step_interval = lerpf(2.6, 1.6, t)
	_grace = lerpf(1.4, 1.0, t)
	_damage = int(lerpf(14.0, 24.0, t))
	# Each piece of art by its first name; the body-horror round (sm2_*) wins where it is
	# there (playtest 18. 10.: the first round was "not disgusting enough").
	for p in [GUEST, T_M1, T_M2, T_LIT, T_FACE, T_TEAR, T_UPSIDE, T_HANDS, T_OVER] + T_WALK:
		for alt in [p.replace("/sm_", "/sm2_"), p]:
			if ResourceLoader.exists(alt):
				_tex[p] = load(alt)
				break
	_body = _make_body(GUEST, HEIGHT)
	_hum = _loop(SFX_HUM, -60.0)
	_breath = _loop(SFX_BREATH, -60.0)
	_reset_far(_rng.randf_range(3.0, 6.0))
	_peek_until = 0.0
	_first = not _met()
	_sound2d = AudioStreamPlayer.new()
	_root.add_child(_sound2d)


## The night is over (dawn, death, the menu): nothing of a catch stays on the screen.
## The base ticks nothing while you are indoors (or it is not night); back out, he is
## round the corner by the door you came out of.
func tick(delta: float) -> void:
	if _night_active and _seq.is_empty():
		var ready := _is_ready()
		if not ready:
			_away = true
			_end_hold()
			_tick_indoors(delta)
		elif _away:
			_away = false
			_indoors = false
			_on_return()
	super(delta)


func _on_return() -> void:
	_neck_until = -1.0
	_vanish_at = -1.0
	_walk_t = -1.0
	_dist = START_DIST
	_resume_at = _elapsed + _rng.randf_range(1.5, 3.0)
	_next_step = _resume_at + _step_interval
	_choose_lurk()


func _on_stop() -> void:
	_end_seq()
	_end_hold()
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
	_update_audio(dt)
	_update_presence(dt)
	if _reveal_t >= 0.0:
		_update_reveal(dt)
		return
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
		_body.visible = _lurking or _elapsed < _peek_until
		return
	_body.visible = true
	if _lamp_light_at(_player_pos()) >= DARK_LIGHT:
		_update_lurk(dt)
		return
	if _lurking and _first and not _revealed and _start_reveal():
		return
	if _lurking:
		# Out of the light: the humming stops. He is coming.
		_lurking = false
		_dist = minf(START_DIST, maxf(NECK_DIST + 2.0, _distance_to_player(_body.global_position)))
		_next_step = _elapsed + _rng.randf_range(0.8, 1.6)
	_update_footfall(dt)
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
	# He only moves while you are not looking his way.
	if _is_seen(_body.global_position + Vector3(0, HEIGHT * 0.7, 0), 4.0) and _dist > NECK_DIST + 0.5:
		return
	var walking := _speed > 0.6
	if _speed > RUN_SPEED:
		_dist = minf(START_DIST, _dist + 1.0)
	elif walking:
		_dist -= _step_gain * 0.5
	else:
		_dist -= _step_gain
	_dist = maxf(NECK_DIST, _dist)
	_place_behind(_dist)
	var at := _walk_to + Vector3(0, 0.3, 0)
	if walking:
		# Half a beat after your own steps: lost in them.
		get_tree_timer(0.25, func(): _sound(SFX_SOFTSTEP, at, lerpf(-16.0, -6.0, 1.0 - _dist / START_DIST), _rng.randf_range(0.9, 1.05), 26.0))
	else:
		_sound(SFX_STEPS, at, lerpf(-10.0, 0.0, 1.0 - _dist / START_DIST), _rng.randf_range(0.94, 1.04), 34.0)
	if _rng.randf() < 0.3:
		_sound(SFX_CREAK, at + Vector3(0, 1.2, 0), lerpf(-14.0, -2.0, 1.0 - _dist / START_DIST), _rng.randf_range(0.9, 1.1), 24.0)
	_announce("Footsteps on the gravel behind you. They stop when you stop.")
	if _dist <= NECK_DIST + 0.01:
		# The first time he gives you longer: it is how the rule is learnt.
		_neck_until = _elapsed + _grace * (1.7 if _first else 1.0)
		_neck_from = _player_pos()
		_sound(SFX_WHISPER, _player_pos() + Vector3(0, 1.55, 0) - _forward_flat() * 0.35, 2.0, 1.0, 8.0)
		_start_hold()


func get_tree_timer(seconds: float, f: Callable) -> void:
	if _root != null and _root.is_inside_tree():
		_root.get_tree().create_timer(seconds).timeout.connect(f)


## Your footfall and his: stop walking, and there is one step more after you stopped (his
## signature); close, his clothes, his breath.
func _update_footfall(dt: float) -> void:
	var moving := _speed > 0.6
	if _was_moving and _speed < 0.25 and _extra_step_at < 0.0:
		_extra_step_at = _elapsed + _rng.randf_range(0.3, 0.5)
	_was_moving = moving if moving else (_was_moving and _speed >= 0.25)
	if _extra_step_at > 0.0 and _elapsed >= _extra_step_at:
		_extra_step_at = -1.0
		if not _is_seen(_body.global_position + Vector3(0, HEIGHT * 0.7, 0), 4.0):
			_dist = maxf(NECK_DIST + 0.3, _dist - 0.5)
			_place_behind(_dist)
			_sound(SFX_STEP, _walk_to + Vector3(0, 0.3, 0), lerpf(-8.0, 2.0, 1.0 - _dist / START_DIST), _rng.randf_range(0.95, 1.03), 30.0)
	if _dist < 5.0:
		_rustle_next -= dt
		if _rustle_next <= 0.0:
			_rustle_next = _rng.randf_range(2.5, 5.0)
			_sound(SFX_RUSTLE, _body.global_position + Vector3(0, 1.2, 0), lerpf(-4.0, -14.0, _dist / 5.0), _rng.randf_range(0.9, 1.1), 14.0)


# ── the lurk ─────────────────────────────────────────────────────────────────

## A dark spot round a corner from you: hidden from where you stand, a step aside from a
## place you could see (so he can lean out), behind or beside you rather than ahead.
func _choose_lurk() -> void:
	var cam := _camera()
	if cam == null:
		return
	var best := -1.0
	var best_p := Vector3.INF
	var best_peek := Vector3.INF
	for _i in 28:
		var ang := _rng.randf_range(0.0, 360.0)
		var p := _point_from_player(_rng.randf_range(LURK_DIST.x, LURK_DIST.y), ang)
		if p == Vector3.INF or _lamp_light_at(p) > LURK_DARK:
			continue
		var head := p + Vector3(0, HEIGHT * 0.8, 0)
		if not _ray_blocked(cam.global_position, head):
			continue
		var score := 1.0 + (0.5 if absf(wrapf(ang, -180.0, 180.0)) > 90.0 else 0.0)
		var to := (p - _player_pos())
		to.y = 0.0
		var side := to.normalized().cross(Vector3.UP)
		var peek := Vector3.INF
		for sgn in [1.0, -1.0]:
			var q := _ground(p + side * sgn * 0.8)
			if q != Vector3.INF and not _ray_blocked(cam.global_position, q + Vector3(0, HEIGHT * 0.8, 0)):
				peek = q
				score += 1.0
				break
		if score > best:
			best = score
			best_p = p
			best_peek = peek
	if best_p == Vector3.INF:
		_lurking = false
		return
	_lurking = true
	_lurk_spot = best_p
	_peek_spot = best_peek
	_peek_t = 0.0
	_peek_next = _rng.randf_range(5.0, 9.0)
	_body.global_position = best_p
	_body.visible = true
	_set_tex(_look_for(LURK_DIST.y))


## While you are in the light: he hums round his corner; now and then he leans out past
## it for a moment and back.
func _update_lurk(dt: float) -> void:
	if not _lurking or _lurk_spot == Vector3.INF or _distance_to_player(_lurk_spot) > LURK_DIST.y + 4.0:
		_choose_lurk()
		if not _lurking:
			return
	if _peek_t > 0.0:
		_peek_t -= dt
		if _peek_t <= 0.0:
			_body.global_position = _lurk_spot
		return
	_peek_next -= dt
	if _peek_next <= 0.0 and _peek_spot != Vector3.INF:
		_peek_next = _rng.randf_range(6.0, 11.0)
		_peek_t = _rng.randf_range(0.9, 1.5)
		_body.global_position = _peek_spot
		_sound(SFX_RUSTLE, _peek_spot + Vector3(0, 1.2, 0), -14.0, _rng.randf_range(0.9, 1.1), 20.0)


## Right behind you: turn round or get away, now.
func _tick_neck() -> void:
	var head := _body.global_position + Vector3(0, HEIGHT * 0.86, 0)
	if _is_seen(head, 6.0) or _player_pos().distance_to(_neck_from) > 1.8:
		_neck_until = -1.0
		_end_hold()
		_mark_met()
		_driven_off()
		return
	_update_hold()
	if _elapsed >= _neck_until:
		_neck_until = -1.0
		_end_hold()
		if _first:
			# The lesson: he turns you round to him and lets you see. No bite this time.
			_lesson = true
			_mark_met()
			_start_catch("turn")
			return
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


func _update_audio(dt: float) -> void:
	var d := _distance_to_player(_body.global_position)
	if _hum != null:
		_hum.global_position = _body.global_position + Vector3(0, 1.6, 0)
		# He hums only while he waits for you in the dark round his corner.
		var want := lerpf(-30.0, -12.0, clampf(1.0 - d / (LURK_DIST.y + 4.0), 0.0, 1.0)) if _lurking else -60.0
		_hum.volume_db = move_toward(_hum.volume_db, want, (60.0 if want < _hum.volume_db else 20.0) * dt)
	if _breath != null:
		_breath.global_position = _body.global_position + Vector3(0, 1.6, 0)
		_breath.volume_db = -60.0 if (d > 4.5 or _elapsed < _resume_at) else lerpf(-2.0, -22.0, d / 4.5)
	var fx := _fx()
	if fx != null and _elapsed >= _resume_at:
		fx.set_dread("silent_man", clampf(1.0 - _dist / START_DIST, 0.0, 1.0) * 0.8)


# ── the light ────────────────────────────────────────────────────────────────

## Found by the light: the glasses flare, a sharp breath, and he comes apart into the dark:
## a dither of game pixels in six steps (twelve a second) going back a step, a little
## dark ash going up. Then a new corner.
func _driven_off() -> void:
	_drive_offs += 1
	_end_hold()
	_press = maxf(0.0, _press - 0.45)
	_walk_t = -1.0
	_lurking = false
	if _tex.has(T_LIT):
		_set_tex(T_LIT)
	var head := _body.global_position + Vector3(0, HEIGHT * 0.86, 0)
	_sound(SFX_VANISH, head, 2.0, _rng.randf_range(0.95, 1.05), 30.0)
	var away := _body.global_position - _player_pos()
	away.y = 0.0
	_back_dir = away.normalized() if away.length_squared() > 0.01 else -_forward_flat()
	_walk_from = _body.global_position
	_vanish_at = _elapsed + LIT_SECONDS
	_player.set("flashlight_stutter", 1.0)
	_neck_until = -1.0
	_dissolve_base = _body.texture
	_puff_ash()


var _dissolve_base: Texture2D


func _update_lit(_dt: float) -> void:
	_body.visible = true
	var left := _vanish_at - _elapsed
	var k := clampf(1.0 - left / LIT_SECONDS, 0.0, 1.0)
	if k > 0.1:
		_player.set("flashlight_stutter", 0.0)
	var fx := _fx()
	var cam := _camera()
	if fx != null and cam != null and k < 0.25:
		fx.set_eyes("silent_man", _body.global_position + Vector3(0, HEIGHT * 0.9, 0), cam, 1.0, 0.0, 0.05)
	# After the flare: the dither takes him, a frame at a time, as he goes back a step.
	if k > 0.15 and _dissolve_base != null:
		var frames: Array = _dissolve_frames(_dissolve_base)
		var i := clampi(int((k - 0.15) / 0.85 * float(DISSOLVE_FRAMES + 1)), 0, DISSOLVE_FRAMES)
		if i >= DISSOLVE_FRAMES:
			_body.visible = false
		else:
			_body.texture = frames[i]
		_body.global_position = _walk_from + _back_dir * 0.5 * floorf((k - 0.15) / 0.85 * 6.0) / 6.0
	if left <= 0.0:
		_vanish_at = -1.0
		_player.set("flashlight_stutter", 0.0)
		_body.texture = null
		_body.texture = _dissolve_base
		_reset_far(_rng.randf_range(4.0, 8.0))


## The art going to nothing in an ordered dither (whole pixels, darker as it goes), made
## once per picture.
func _dissolve_frames(tex: Texture2D) -> Array:
	if _dissolve.has(tex):
		return _dissolve[tex]
	var out: Array = []
	var img := tex.get_image()
	if img != null:
		img = img.duplicate()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		var bayer := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
		for f in DISSOLVE_FRAMES:
			var cut := float(f + 1) / float(DISSOLVE_FRAMES + 1)
			var im: Image = img.duplicate()
			for y in im.get_height():
				for x in im.get_width():
					var c: Color = im.get_pixel(x, y)
					if c.a <= 0.0:
						continue
					if (float(bayer[(x & 3) + (y & 3) * 4]) + 0.5) / 16.0 < cut:
						im.set_pixel(x, y, Color(0, 0, 0, 0))
					else:
						im.set_pixel(x, y, Color(c.r * (1.0 - cut * 0.6), c.g * (1.0 - cut * 0.6), c.b * (1.0 - cut * 0.6), c.a))
			out.append(ImageTexture.create_from_image(im))
	_dissolve[tex] = out
	return out


## A little dark ash going up off him as he goes.
func _puff_ash() -> void:
	if _ash == null:
		_ash = GPUParticles3D.new()
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(0.25, 0.85, 0.1)
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 35.0
		pm.initial_velocity_min = 0.15
		pm.initial_velocity_max = 0.5
		pm.gravity = Vector3(0, 0.35, 0)
		pm.damping_min = 0.4
		pm.damping_max = 0.8
		_ash.process_material = pm
		var q := QuadMesh.new()
		q.size = Vector2(0.035, 0.035)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.05, 0.045, 0.04, 0.9)
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		q.material = m
		_ash.draw_pass_1 = q
		_ash.amount = 40
		_ash.lifetime = 1.4
		_ash.one_shot = true
		_ash.explosiveness = 0.5
		_root.add_child(_ash)
	_ash.global_position = _body.global_position + Vector3(0, HEIGHT * 0.5, 0)
	_ash.restart()
	_ash.emitting = true


func _reset_far(pause: float) -> void:
	_lurking = false
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

func _start_catch(forced := "") -> void:
	var kill := forced == "" and _player_health() - _damage <= 0
	var pool: Array = (KILLS if kill else STRIKES).filter(func(k): return k != (_last_kill if kill else _last_strike))
	var kind: String = forced if forced != "" else pool[_rng.randi() % pool.size()]
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
	var fx := _fx()
	if _lesson:
		# He has shown you his face. That is all, this once.
		if fx != null:
			fx.glitch(0.8, 0.9)
			fx.tinnitus(3.0)
		return
	_hurt(_damage)
	claimed = true
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
		if _lesson:
			_lesson = false
			_first = false
			_feed("He was right behind you. Turn round. Put a light on him.")
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


# ── the sixth sense ──────────────────────────────────────────────────────────

## What you feel: built while you are in the dark and he is coming (faster the closer he
## is), drained in the light. Lurking near while you stand in the light, a little of it:
## the light is safe, and you still feel watched.
func _update_presence(dt: float) -> void:
	var fx := _fx()
	var in_light := _lamp_light_at(_player_pos()) >= DARK_LIGHT
	var hunting := not _lurking and _vanish_at < 0.0 and _elapsed >= _resume_at and not in_light
	var close := clampf(1.0 - (_dist - NECK_DIST) / (START_DIST - NECK_DIST), 0.0, 1.0)
	if hunting:
		_press = minf(1.0, _press + dt * (0.025 + 0.11 * close))
	else:
		_press = maxf(0.0, _press - dt * (0.3 if in_light else 0.12))
	var level := maxf(close * close * 0.85, _press * 0.9) if hunting else _press * 0.6
	if _lurking and in_light:
		level = maxf(level, 0.12 * clampf(1.0 - _distance_to_player(_body.global_position) / (LURK_DIST.y + 4.0), 0.0, 1.0) * 2.0)
	if _neck_until > 0.0:
		level = 1.0
	if fx != null:
		fx.set_presence("silent_man", level)
	# The torch in your hand catches and stutters as it gets bad.
	if level > 0.55 and _player != null:
		_stutter_next -= dt
		if _stutter_next <= 0.0:
			_stutter_next = _rng.randf_range(1.2, 3.5) * (1.6 - level)
			_player.set("flashlight_stutter", 0.5 + 0.5 * level)
			get_tree_timer(_rng.randf_range(0.08, 0.2), func():
				if _player != null and is_instance_valid(_player) and _vanish_at < 0.0:
					_player.set("flashlight_stutter", 0.0))


## His hands come over your shoulder from the side he is on; he holds you back.
func _start_hold() -> void:
	var cam := _camera()
	if cam != null:
		var right := cam.global_transform.basis.x
		var to := _body.global_position - cam.global_position
		_hold_side = 1.0 if right.dot(to) >= 0.0 else -1.0
	var fx := _fx()
	if fx != null:
		fx.freeze(0.06)
	_ear(SFX_BREATH, 3.0, 0.95)
	_sound(SFX_RUSTLE, _player_pos() + Vector3(0, 1.3, 0) - _forward_flat() * 0.4, 0.0, 1.0, 6.0)
	if "held_speed_mult" in _player:
		_player.set("held_speed_mult", 0.5)


func _update_hold() -> void:
	var fx := _fx()
	if fx == null:
		return
	var k := clampf(1.0 - (_neck_until - _elapsed) / maxf(0.1, _grace), 0.0, 1.0)
	var st := floorf(k * 8.0) / 8.0
	fx.close_up(_t(T_HANDS, T_FACE), lerpf(0.75, 1.0, st), 1.0, 0.003 + 0.006 * st, -0.35 * _hold_side, Vector2(_hold_side * lerpf(0.62, 0.34, st), lerpf(0.5, 0.28, st)))
	fx.set_dread("silent_man", 1.0)


func _end_hold() -> void:
	if _player != null and is_instance_valid(_player) and "held_speed_mult" in _player:
		_player.set("held_speed_mult", 1.0)
	if _neck_until > 0.0 or not _seq.is_empty():
		return
	var fx := _fx()
	if fx != null:
		fx.close_up_off()


# ── the first meeting ────────────────────────────────────────────────────────

func _met() -> bool:
	var d = _director()
	if d == null or not (d.get("ever") is Dictionary):
		return false
	return bool((d.get("ever") as Dictionary).get("silent_man_met", false))


func _mark_met() -> void:
	var d = _director()
	if d != null and d.get("ever") is Dictionary:
		(d.get("ever") as Dictionary)["silent_man_met"] = true


func _director():
	var scene := _world_root.get_tree().current_scene if _world_root != null and _world_root.is_inside_tree() else null
	return scene.get("_director") if scene != null else null


## The first step out of the light: the humming stops, and he is there in front of you
## at the edge of it, caught mid-stride. False when there is no such spot.
func _start_reveal() -> bool:
	var cam := _camera()
	if cam == null:
		return false
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	for _i in 12:
		var ang := deg_to_rad(_rng.randf_range(-22.0, 22.0))
		var dir := fwd.rotated(Vector3.UP, ang)
		var p := _ground(_player_pos() + dir * _rng.randf_range(8.0, 11.0))
		if p == Vector3.INF or _lamp_light_at(p) > DARK_LIGHT:
			continue
		if _ray_blocked(cam.global_position, p + Vector3(0, HEIGHT * 0.8, 0)):
			continue
		_revealed = true
		_lurking = false
		_body.global_position = p
		_body.visible = true
		var frames: Array = T_WALK.filter(func(q): return _tex.has(q))
		_set_tex(frames[0] if not frames.is_empty() else _look_for(9.0))
		_reveal_t = 0.0
		_reveal_seen = 0.0
		_sound(SFX_STEP, p + Vector3(0, 0.3, 0), -2.0, 0.92, 30.0)
		_announce("Footsteps on the gravel behind you. They stop when you stop.")
		return true
	return false


## Held there: look at him and he goes (the glasses, the dither); look away and he is not
## there when you look back. Either way the hunt then starts from behind you.
func _update_reveal(dt: float) -> void:
	_reveal_t += dt
	var head := _body.global_position + Vector3(0, HEIGHT * 0.86, 0)
	var fx := _fx()
	if fx != null:
		fx.set_presence("silent_man", 0.45)
	if _is_seen(head, 2.0):
		_reveal_seen += dt
		if _reveal_seen >= 0.55:
			_reveal_t = -1.0
			_sound(SFX_HUM, head, -10.0, 0.8, 20.0)
			_driven_off()
			_drive_offs -= 1
			return
	if _reveal_t >= 4.0 or (_reveal_seen > 0.0 and not _is_seen(head, 2.0)):
		_reveal_t = -1.0
		_body.visible = false
		_reset_far(_rng.randf_range(2.0, 4.0))


# ── indoors: getting you out ─────────────────────────────────────────────────

## While you are inside at night he cannot reach you, and he knows where you are. In
## order, with a pause between: the humming through the wall, the knocks, the handle,
## the brushing along the outside wall, a tap at the window; after that he goes to a
## guest instead.
func _tick_indoors(delta: float) -> void:
	if not _night_active or not _indoors_now():
		_indoors = false
		return
	if not _indoors:
		_indoors = true
		_lure_n = 0
		_lure_next = _wall_clock() + _rng.randf_range(10.0, 16.0)
	if _wall_clock() < _lure_next:
		return
	_lure_next = _wall_clock() + _rng.randf_range(16.0, 28.0)
	# Only the one he hunts hears it (co-op).
	if _fx() == null:
		return
	_lure(_lure_n)
	_lure_n += 1


## Seconds while indoors (the base's _elapsed does not run while it cannot act).
func _wall_clock() -> float:
	return Time.get_ticks_msec() / 1000.0


func _indoors_now() -> bool:
	var scene := _world_root.get_tree().current_scene if _world_root != null and _world_root.is_inside_tree() else null
	if scene == null:
		return false
	var night: bool = scene.has_method("_is_enemy_night_active") and bool(scene.call("_is_enemy_night_active"))
	var inside: bool = scene.has_method("_is_any_interior_open") and bool(scene.call("_is_any_interior_open"))
	return night and inside


func _lure(n: int) -> void:
	var scene := _world_root.get_tree().current_scene
	var fxd = scene.get("_director_fx") if scene != null else null
	var im = scene.get("_interior_manager") if scene != null else null
	var bi = im.get("_building_interior") if im != null else null
	var office: bool = bi != null and bool(bi.get("visible"))
	match n % 6:
		0:
			_room_2d(SFX_HUM, -14.0, 0.9)
			_feed("Humming, through the wall. It stops.")
		1:
			if office and fxd != null:
				fxd.run("knock", {})
			else:
				_room_2d("res://assets/sfx/director/knock.mp3", -4.0)
			# The fourth knock, after you have stopped listening.
			get_tree_timer(_rng.randf_range(5.0, 8.0), func():
				if _indoors and _fx() != null:
					_room_2d("res://assets/sfx/director/knock.mp3", -9.0, 0.9))
		2:
			if office and fxd != null:
				fxd.run("handle", {})
			else:
				_room_2d("res://assets/sfx/director/handle.mp3", -3.0)
		3:
			_room_2d("res://assets/sfx/director/wall_brush.mp3", -6.0)
			get_tree_timer(2.2, func():
				if _indoors and _fx() != null:
					_room_2d("res://assets/sfx/director/wall_brush.mp3", -9.0, 0.95))
		4:
			if office and fxd != null:
				fxd.run("figure_window", {})
			else:
				_room_2d("res://assets/sfx/director/window_tap.mp3", -4.0)
		_:
			_visit_guest()


func _room_2d(file: String, db: float, pitch: float = 1.0) -> void:
	if _sound2d == null or not ResourceLoader.exists(file):
		return
	_sound2d.stream = load(file)
	_sound2d.volume_db = db
	_sound2d.pitch_scale = pitch
	_sound2d.play()


## Hide long enough and it is somebody else: a guest's night goes wrong.
func _visit_guest() -> void:
	var state = CoreRoot.get_state() if CoreRoot != null else null
	if state == null or GuestManager == null:
		return
	var pick := {}
	for g in state.guests:
		if g is Dictionary and str(g.get("status", "")) in ["active", "sleep"]:
			pick = g
			if str(g.get("archetype", "")) == "quiet_guy":
				break
	if pick.is_empty():
		_room_2d(SFX_HUM, -10.0, 0.75)
		return
	_room_2d("res://assets/sfx/director/wall_brush.mp3", -16.0, 0.8)
	GuestManager.apply_guest_event(int(pick.get("id", -1)), -18.0, "Someone stood at my tent all night. I did not open it.")
	_feed("Somewhere in the camp a tent zip goes, slowly. Then nothing.")


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
		"press": snappedf(_press, 0.01),
		"first": _first,
		"lure": _lure_n,
	}
