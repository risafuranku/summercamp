extends "res://scripts/enemies/enemy_base.gd"

## The Whistler (Tramps; DESIGN §5a.3). The tramp turned: his hat and flannel, the
## guitar on his back, his mouth gone into a black horn like a megaphone's. He hears and
## does not see, and the night with him is musical chairs:
##   play     he plays the campfire song out in the dark and whistles it through the horn.
##            While he plays he does not listen: you may move. He creeps nearer song by
##            song. The music is thrown (from medium on): it comes from where he is not;
##            what is really him is the creak of a string, a twig, and, when the music
##            stops, his eyes, two pale slits where he really stands.
##   listen   the music stops dead in the middle of a bar (a hand on the strings). Now he
##            listens: running anywhere, walking on gravel, boards or in a puddle, gives
##            you away (walking on grass does not, unless you are near him). Heavy, a guest's voice calls
##            for help out of the dark to make you move.
##   rush     he heard you: boots through the grass, the guitar jangling, straight at
##            where you were; there he listens again. Under a lamp he stops at the edge
##            of its light and goes.
##   strike   at your back: the string round your neck, his horn at your ear.
##   fire     (medium on) a campfire burning out by the trees that nobody lit, him on a
##            log by it playing. Its light is not safe: go near and the fire dies and he
##            is behind you.
## Indoors he cannot reach you: his song under the window, then nothing.

const N := "res://assets/textury/npc/"
const SPRITE := N + "whistler_t1.png"
const SPRITE_SIT := N + "whistler_sit.png"
const FACE := N + "whistler_face.png"
const OLD := N + "enemy_whistler.png"
const S := "res://assets/sfx/npc/whistler/"
const SFX_PLAY := [S + "play_1.mp3", S + "play_2.mp3"]
const SFX_TUNE := "res://assets/sfx/npc/whistler_tune.mp3"
const SFX_TWIG := "res://assets/sfx/npc/twig_snap.mp3"
const SFX_CALLS := [S + "call_1.mp3", S + "call_2.mp3", S + "call_3.mp3"]
## The flames are the camp fire's own (materials/pixel_fire.gdshader).
const FIRE_SHADER = preload("res://materials/pixel_fire.gdshader")
const LAMP_SAFE := 0.22
const GIVE_UP_IN_LIGHT := 14.0
## How long he plays (s), how long he listens (s, light .. heavy), how far he hears (m).
const PLAY_SEC := Vector2(10.0, 17.0)
const LISTEN_SEC := Vector2(4.0, 7.0)
const HEAR_RANGE := 38.0
## What he hears (m/s of you): on grass and snow only a run; on gravel, boards and in
## puddles a walk.
const LOUD_SOFT := 3.6
const LOUD_HARD := 0.7
const HARD := ["gravel", "wood", "puddle", "path", "stone"]
const RUSH_SPEED := 6.8
const CREEP := 0.45
const NEAREST := 9.0
const REACH := 1.5
## This near he hears you walk on anything.
const HEAR_ALL := 10.0

var _phase := "rest"
var _phase_t := 0.0
var _pos := Vector3.INF
## Where his music comes from now (thrown, from medium on): the harness follows it.
var _source := Vector3.INF
var _heard_at := Vector3.INF
var _hit := 30
var _music: AudioStreamPlayer3D
var _tell_t := 3.0
var _lit_for := 0.0
var _last_pos := Vector3.INF
var _speed := 0.0
var _eyes_until := -1.0
var _tex_stand: Texture2D
var _tex_sit: Texture2D
var _face_tex: Texture2D
## The fire nobody lit (medium on): where, its light, its crackle; how long it has burned.
var _fire_at := Vector3.INF
var _fire_light: OmniLight3D
var _fire_root: Node3D
var _fire_sound: AudioStreamPlayer3D
var _fire_t := 0.0
var _fire_next := 40.0
## The strike (seconds into it, -1 none).
var _strike_t := -1.0
## Indoors: the next song under the window (wall clock).
var _in_next := -1.0
var _in_sound: AudioStreamPlayer


func get_enemy_id() -> String:
	return "whistler"


func _on_start() -> void:
	var t := float(_difficulty - 1) / 4.0
	_hit = int(lerpf(24.0, 42.0, t))
	_tex_stand = load(SPRITE if ResourceLoader.exists(SPRITE) else OLD)
	_tex_sit = load(SPRITE_SIT) if ResourceLoader.exists(SPRITE_SIT) else _tex_stand
	_face_tex = load(FACE) if ResourceLoader.exists(FACE) else null
	_body = _make_body(SPRITE if ResourceLoader.exists(SPRITE) else OLD, 2.05)
	_body.visible = false
	# Not on his body: where he really stands, a while after the music stops.
	_make_eyes("whistler", 1.75).set("anchor", null)
	_music = AudioStreamPlayer3D.new()
	_music.unit_size = 9.0
	_music.max_distance = 70.0
	_root.add_child(_music)
	_in_sound = AudioStreamPlayer.new()
	_in_sound.volume_db = -60.0
	_root.add_child(_in_sound)
	_fire_next = _rng.randf_range(25.0, 50.0)
	_enter("rest", _rng.randf_range(3.0, 6.0))
	# The night's screen made now (his face would not show at the first strike).
	_fx()


# ── the loop ─────────────────────────────────────────────────────────────────

func _enter(phase: String, seconds: float) -> void:
	_phase = phase
	_phase_t = seconds
	match phase:
		"play":
			if _pos == Vector3.INF:
				_relocate(20.0, 28.0)
			_source = _thrown_from(_pos)
			_music.stream = load(SFX_PLAY[_rng.randi() % SFX_PLAY.size()])
			_music.global_position = _source + Vector3(0, 1.4, 0)
			_music.volume_db = -2.0
			_music.play(_rng.randf_range(0.0, 3.0))
			_tell_t = _rng.randf_range(2.5, 5.0)
			_announce("Somebody is playing a guitar out in the trees, and whistling.")
		"listen":
			_music.stop()
			_sound(S + "mute.mp3", _source + Vector3(0, 1.2, 0), 0.0, 1.0, 60.0)
			# His eyes, where he really is.
			_eyes.set("point", _pos + Vector3(0, 1.75, 0))
			_eyes_until = _elapsed + _rng.randf_range(1.6, 2.6)
			if _difficulty >= 4 and _rng.randf() < 0.4:
				var p := _dark_point(14.0, 24.0, 60.0, 140.0)
				if p != Vector3.INF:
					_sound(SFX_CALLS[_rng.randi() % SFX_CALLS.size()], p + Vector3(0, 1.6, 0), 0.0, 1.0, 50.0)
		"rush":
			_music.stop()
			_sound(S + "rush.mp3", _pos + Vector3(0, 1.0, 0), 2.0, 1.0, 45.0)
		"rest":
			_music.stop()
			_body.visible = false
			_source = Vector3.INF


func _on_tick(dt: float) -> void:
	_track_speed(dt)
	_eyes.set("want", 1.0 if _elapsed < _eyes_until and _phase != "rush" else 0.0)
	if _strike_t >= 0.0:
		_tick_strike(dt)
		return
	_phase_t -= dt
	var player := _player_pos()
	var in_light := _lamp_light_at(player) > LAMP_SAFE
	_lit_for = _lit_for + dt if in_light else 0.0
	_tick_fire(dt)
	match _phase:
		"rest":
			if _phase_t <= 0.0:
				_pos = Vector3.INF
				_enter("play", _rng.randf_range(PLAY_SEC.x, PLAY_SEC.y))
		"play":
			# By his fire he sits in its light; else he is out in the dark, unseen.
			var by_fire := _fire_at != Vector3.INF
			_body.visible = by_fire
			# Song by song nearer, never nearer than NEAREST while he plays.
			var to := player - _pos
			to.y = 0.0
			if not by_fire and to.length() > NEAREST:
				var p := _ground(_pos + to.normalized() * CREEP * dt)
				if p != Vector3.INF:
					_pos = p
			_tell_t -= dt
			if _tell_t <= 0.0:
				_tell_t = _rng.randf_range(3.5, 6.5)
				_sound(S + "creak.mp3" if _rng.randf() < 0.6 else SFX_TWIG, _pos + Vector3(0, 1.0, 0), -6.0, _rng.randf_range(0.9, 1.1), 25.0)
			if _lit_for >= GIVE_UP_IN_LIGHT:
				_give_up()
			elif _phase_t <= 0.0:
				_enter("listen", _listen_seconds())
		"listen":
			if not in_light and _heard():
				_heard_at = player
				_enter("rush", 12.0)
			elif _phase_t <= 0.0:
				_enter("play", _rng.randf_range(PLAY_SEC.x, PLAY_SEC.y))
		"rush":
			_tick_rush(dt, player, in_light)


## Did he hear you: how fast you go on what, within his range.
func _heard() -> bool:
	if _distance_to_player(_pos) > HEAR_RANGE:
		return false
	var loud := LOUD_SOFT
	if _distance_to_player(_pos) < HEAR_ALL:
		loud = LOUD_HARD
	elif _player != null and _player.has_method("_surface_under") and str(_player.call("_surface_under")) in HARD:
		loud = LOUD_HARD
	return _speed > loud


func _listen_seconds() -> float:
	return lerpf(LISTEN_SEC.x, LISTEN_SEC.y, float(_difficulty - 1) / 4.0) * _rng.randf_range(0.85, 1.15)


## At where he heard you; there he listens again. At you: the strike. A lamp's light:
## he stops at its edge and goes.
func _tick_rush(dt: float, player: Vector3, in_light: bool) -> void:
	var target := _heard_at
	var to := target - _pos
	to.y = 0.0
	var me := _distance_to_player(_pos)
	if in_light and me < 7.0:
		_give_up()
		return
	if me <= REACH:
		_start_strike()
		return
	if to.length() < 0.8:
		# Where you were: he listens for you again.
		_enter("listen", _listen_seconds() * 0.7)
		return
	var p := _ground(_pos + to.normalized() * minf(RUSH_SPEED * dt, to.length()))
	if p != Vector3.INF:
		_pos = p
	_place_body(_pos)
	_body.texture = _tex_stand
	_body.visible = true
	# Still listening on the way: a noise turns him.
	if not in_light and _heard() and me < 18.0:
		_heard_at = player
	if _phase_t <= 0.0:
		_enter("listen", _listen_seconds())


func _give_up() -> void:
	_lit_for = 0.0
	_sound(S + "mute.mp3", (_source if _source != Vector3.INF else _pos) + Vector3(0, 1.2, 0), -4.0, 0.9, 50.0)
	_feed("The music stopped in the middle of the tune.")
	_pos = Vector3.INF
	_enter("rest", _rng.randf_range(35.0, 55.0))


# ── the strike ───────────────────────────────────────────────────────────────

## At your back: the string round your neck, his horn at your ear.
func _start_strike() -> void:
	_strike_t = 0.0
	_body.visible = false
	_sound_quarry(S + "garrote.mp3", _player_pos() + Vector3(0, 1.6, 0), 4.0, 1.0, 10.0)
	var fx := _fx()
	if fx != null:
		fx.freeze(0.1)
		if _face_tex != null:
			fx.close_up(_face_tex, 1.05, 1.0, 0.02)
		fx.glitch(0.8, 1.0)
		fx.tinnitus(3.0)


func _tick_strike(dt: float) -> void:
	_strike_t += dt
	var fx := _fx()
	if fx != null and _face_tex != null and _strike_t < 1.1:
		# His horn comes at you as the string tightens.
		fx.close_up(_face_tex, lerpf(1.05, 1.6, _strike_t / 1.1), 1.0, 0.02 + 0.03 * _strike_t)
	if _strike_t >= 1.1:
		_strike_t = -1.0
		if fx != null:
			fx.close_up_off()
			fx.red_flash(0.6)
		_hurt(_hit)
		claimed = true
		_feed("A string round your neck, and a whistle in your ear.")
		_pos = Vector3.INF
		_enter("rest", _rng.randf_range(40.0, 60.0))


# ── the fire nobody lit ──────────────────────────────────────────────────────

func _tick_fire(dt: float) -> void:
	if _difficulty < 3:
		return
	if _fire_at == Vector3.INF:
		_fire_next -= dt
		if _fire_next <= 0.0 and _phase == "rest":
			_light_fire()
		return
	_fire_t += dt
	if _fire_light != null:
		_fire_light.light_energy = 1.6 + 0.5 * sin(_elapsed * 9.0) * sin(_elapsed * 3.7)
	# Him on a log by it, playing, while you are not near.
	var near := _distance_to_player(_fire_at)
	if near < 7.0:
		# Not him: the fire dies, and he is behind you.
		_put_out()
		_pos = _ground(_player_pos() - _forward_flat() * 9.0)
		if _pos == Vector3.INF:
			_pos = _player_pos() - _forward_flat() * 9.0
		_heard_at = _player_pos()
		_enter("rush", 8.0)
		return
	if _fire_t > 70.0:
		_put_out()


func _light_fire() -> void:
	var p := _dark_point(24.0, 34.0, 0.0, 180.0)
	if p == Vector3.INF:
		_fire_next = 15.0
		return
	_fire_at = p
	_fire_t = 0.0
	_fire_root = Node3D.new()
	_root.add_child(_fire_root)
	_fire_root.global_position = p
	for f in [[Vector2(0.8, 1.05), Vector3(0, 0.52, 0), 0.0], [Vector2(0.55, 0.8), Vector3(0.07, 0.4, 0.05), 3.7]]:
		var fl := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = f[0]
		fl.mesh = q
		fl.position = f[1]
		fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := ShaderMaterial.new()
		m.shader = FIRE_SHADER
		m.set_shader_parameter("seed", float(f[2]))
		fl.material_override = m
		_fire_root.add_child(fl)
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color(1.0, 0.55, 0.22)
	_fire_light.omni_range = 7.0
	_fire_light.light_energy = 1.6
	_fire_root.add_child(_fire_light)
	_fire_light.position = Vector3(0, 0.9, 0)
	_fire_sound = _sound(S + "fire.mp3", p + Vector3(0, 0.4, 0), -4.0, 1.0, 40.0)
	if _fire_sound != null and _fire_sound.stream is AudioStreamMP3:
		(_fire_sound.stream as AudioStreamMP3).loop = true
	# He sits by it: the music from there, and him on the log in its light.
	_pos = p + Vector3(1.1, 0, 0)
	_place_body(_pos)
	_body.texture = _tex_sit
	_body.visible = true
	_enter("play", 60.0)
	_source = p
	_music.global_position = p + Vector3(0, 1.2, 0)


func _put_out() -> void:
	if _fire_root != null and is_instance_valid(_fire_root):
		_fire_root.queue_free()
	_fire_root = null
	_fire_light = null
	if _fire_sound != null and is_instance_valid(_fire_sound):
		_fire_sound.queue_free()
	_fire_sound = null
	_fire_at = Vector3.INF
	_fire_next = _rng.randf_range(60.0, 110.0)
	if _body != null and is_instance_valid(_body):
		_body.texture = _tex_stand
		_body.visible = false


# ── indoors ──────────────────────────────────────────────────────────────────

## The base ticks nothing while you are indoors: then his song is under the window now
## and then, quiet, and stops in the middle of a bar.
func tick(delta: float) -> void:
	if _night_active and _world_root != null and is_instance_valid(_world_root) and not _is_ready() and _quarry_indoors():
		_music.stop()
		var now := Time.get_ticks_msec() / 1000.0
		if _in_next < 0.0:
			_in_next = now + _rng.randf_range(15.0, 30.0)
		elif now >= _in_next and _fx() != null:
			_in_next = now + _rng.randf_range(40.0, 75.0)
			_in_sound.stream = load(SFX_PLAY[_rng.randi() % SFX_PLAY.size()])
			_in_sound.volume_db = -20.0
			_in_sound.play(_rng.randf_range(0.0, 4.0))
			get_tree_timer(_rng.randf_range(6.0, 9.0), func():
				if _in_sound != null and is_instance_valid(_in_sound):
					_in_sound.stop()
					_in_sound.stream = load(S + "mute.mp3")
					_in_sound.volume_db = -12.0
					_in_sound.play())
	super(delta)


func get_tree_timer(seconds: float, f: Callable) -> void:
	if _world_root == null or not _world_root.is_inside_tree():
		return
	_world_root.get_tree().create_timer(seconds).timeout.connect(f)


func _on_stop() -> void:
	_put_out()


# ── helpers ──────────────────────────────────────────────────────────────────

## Where the music seems to come from: him, or (from medium on) thrown to one side.
func _thrown_from(at: Vector3) -> Vector3:
	var throw := lerpf(0.0, 11.0, clampf(float(_difficulty - 2) / 3.0, 0.0, 1.0))
	if throw <= 0.5:
		return at
	var side := Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)).normalized()
	var p := _ground(at + side * throw)
	return p if p != Vector3.INF else at


func _relocate(near: float, far: float) -> void:
	_pos = _dark_point(near, far, 0.0, 150.0)
	if _pos == Vector3.INF:
		_pos = _point_from_player(far, 180.0)


## A spot in the dark `near`..`far` m from you, `from`..`to` degrees off your view.
func _dark_point(near: float, far: float, from_deg: float, to_deg: float) -> Vector3:
	for _i in 14:
		var a := _rng.randf_range(from_deg, to_deg) * (1.0 if _rng.randf() < 0.5 else -1.0)
		var p := _point_from_player(_rng.randf_range(near, far), a)
		if p != Vector3.INF and _lamp_light_at(p) < LAMP_SAFE:
			return p
	return Vector3.INF


func _track_speed(dt: float) -> void:
	var p := _player_pos()
	if _last_pos != Vector3.INF and dt > 0.0:
		var flat := Vector2(p.x - _last_pos.x, p.z - _last_pos.z).length() / dt
		_speed = lerpf(_speed, flat, clampf(dt * 8.0, 0.0, 1.0))
	_last_pos = p


func get_debug_snapshot() -> Dictionary:
	return {"phase": _phase, "speed": snappedf(_speed, 0.1), "dist": snappedf(_distance_to_player(_pos), 0.1) if _pos != Vector3.INF else -1.0,
		"fire": _fire_at != Vector3.INF}
