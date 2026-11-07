extends "res://scripts/enemies/enemy_base.gd"

## The Whistler (Tramps; DESIGN §5a.3). The tramp turned: his hat and flannel, the
## guitar on his back, his mouth gone into a black horn like a megaphone's. He hears and
## does not see, and the rule is one line (the user 7. 11.: "when you hear his whistling you
## must not move, and ideally hide somewhere indoors"; he used to listen in the silence):
##   whistle  ("play") he plays the campfire song out in the dark and whistles it through the
##            horn, and while it sounds he is listening: move and he has you. The first notes
##            come up out of nothing: that is your time to stop. Stand still and he only
##            comes nearer, a song at a time, a shape in the dark from close by.
##   quiet    ("gap") a hand flat on the strings: the music stops dead, his eyes a moment,
##            two pale slits where he stands. Now you can move: go, get indoors.
##   rush     he heard you: boots through the grass, the guitar jangling, straight at
##            where you were; there he whistles again. Under a lamp he stops at the edge
##            of its light and goes.
##   lean     ("lean") after his third song, if you stood through them all: he walks right up
##            to you and whistles into your ear. Stand it out and he goes; move and he has you.
##   strike   at your back: the string round your neck, his horn at your ear.
##   fire     (medium on) a campfire burning out by the trees that nobody lit, him on a
##            log by it playing. Its light is not safe: go near and the fire dies and he
##            is behind you.
##   Heavy, a guest's voice calls for help out of the dark in the middle of a song, to make
##   you move. Indoors he cannot reach you: his song under the window, then nothing, and when
##   you come out he has gone off for a while.

const N := "res://assets/textury/npc/"
const SPRITE := N + "whistler_t1.png"
const SPRITE_SIT := N + "whistler_sit.png"
const FACE := N + "whistler_face.png"
const OLD := N + "enemy_whistler.png"
const S := "res://assets/sfx/npc/whistler/"
const SFX_PLAY := [S + "play_1.mp3", S + "play_2.mp3"]
const SFX_TWIG := "res://assets/sfx/npc/twig_snap.mp3"
const SFX_CALLS := [S + "call_1.mp3", S + "call_2.mp3", S + "call_3.mp3"]
## The flames are the camp fire's own (materials/pixel_fire.gdshader).
const FIRE_SHADER = preload("res://materials/pixel_fire.gdshader")
const LAMP_SAFE := 0.22
const GIVE_UP_IN_LIGHT := 14.0
## How long a song is (s), the quiet between songs (s, light .. heavy), how far he hears (m).
const SONG_SEC := Vector2(9.0, 14.0)
const QUIET_SEC := Vector2(24.0, 13.0)
const HEAR_RANGE := 38.0
## The first notes coming up, when he is not yet listening (s, light .. heavy), after a rush.
const WARN_SEC := Vector2(2.0, 1.2)
const WARN_AFTER_RUSH := 0.7
const WARN_DB := -16.0
const SONG_DB := -2.0
## Faster than this (m/s) is moving, whatever you walk on.
const STILL := 0.6
const RUSH_SPEED := 6.8
## Too far behind you at the start of a song, he has come round through the dark.
const LOST_YOU := 32.0
## Songs before he comes right up to you, how near each lets him get, how close he leans.
const LEAN_AFTER := 3
const NEAR_BY_SONG := [12.0, 8.0, 5.0]
const LEAN_M := 1.5
const LEAN_SEC := 6.0
const LEAN_WALK := 1.5
## From this near you can make him out in the dark.
const SEEN_M := 16.0
## At most this long backing off in your sight before he is simply not there.
const LEAVE_SEC := 6.0
const CREEP := 0.9
const REACH := 1.5

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
## The song's first notes: what is left of them, how long they were; the next song's, when set.
var _grace := 0.0
var _grace_from := 0.0
var _grace_next := -1.0
## Songs you stood through; a voice calling in this one (seconds to go, -1 none).
var _songs := 0
var _call_in := -1.0
var _lean_side := Vector3.RIGHT


var _leave_t := 0.0


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
			if _fire_at == Vector3.INF and (_pos == Vector3.INF or _distance_to_player(_pos) > LOST_YOU):
				_relocate(20.0, 28.0)
			_source = _pos
			_grace_from = _grace_next if _grace_next >= 0.0 else lerpf(WARN_SEC.x, WARN_SEC.y, float(_difficulty - 1) / 4.0)
			_grace_next = -1.0
			_grace = _grace_from
			# Round and round: a song runs 14 s, he plays up to 14: it must not run out by itself
			# and leave you standing for nothing.
			var song := load(SFX_PLAY[_rng.randi() % SFX_PLAY.size()]) as AudioStream
			if song is AudioStreamMP3:
				(song as AudioStreamMP3).loop = true
			_music.stream = song
			_music.global_position = _source + Vector3(0, 1.4, 0)
			_music.volume_db = WARN_DB
			_music.play(_rng.randf_range(0.0, 3.0))
			_tell_t = _rng.randf_range(2.5, 5.0)
			_call_in = seconds * _rng.randf_range(0.3, 0.6) if _difficulty >= 4 and _rng.randf() < 0.4 else -1.0
		"gap":
			_music.stop()
			_sound(S + "mute.mp3", _pos + Vector3(0, 1.2, 0), 0.0, 1.0, 60.0)
			# His eyes, where he stands.
			_eyes.set("point", _pos + Vector3(0, 1.75, 0))
			_eyes_until = _elapsed + _rng.randf_range(1.6, 2.6)
			if _body != null and _body.visible and _fire_at == Vector3.INF:
				_leave_t = 3.0
		"lean":
			# On the side he comes from, a little round you: not through you to get behind you.
			var from := _pos - _player_pos()
			from.y = 0.0
			_lean_side = from.normalized().rotated(Vector3.UP, 0.7 if _rng.randf() < 0.5 else -0.7) if from.length() > 0.1 else -_forward_flat()
			_grace = 0.0
			if not _music.playing:
				_music.stream = load(SFX_PLAY[_rng.randi() % SFX_PLAY.size()]) as AudioStream
				if _music.stream is AudioStreamMP3:
					(_music.stream as AudioStreamMP3).loop = true
				_music.play(_rng.randf_range(0.0, 3.0))
			_music.volume_db = SONG_DB
		"rush":
			_music.stop()
			_sound(S + "rush.mp3", _pos + Vector3(0, 1.0, 0), 2.0, 1.0, 45.0)
		"rest":
			_music.stop()
			_songs = 0
			# (Not out like a light before your eyes: he goes back into the dark, _tick_leave.)
			if _fire_at != Vector3.INF:
				pass
			elif _body != null and _body.visible and _pos != Vector3.INF and _is_seen(_pos + Vector3(0, 1.2, 0)):
				_leave_t = LEAVE_SEC
			elif _body != null:
				_body.visible = false
			_source = Vector3.INF


func _on_tick(dt: float) -> void:
	_track_speed(dt)
	# His rush has its beat (chase_music.gd); where he gets to it stops dead and he listens,
	# and at your back, the string round your neck, so does it.
	var cfx := _fx()
	if cfx != null and cfx.has_method("set_chase"):
		var strike := _strike_t >= 0.0
		cfx.set_chase("whistler", -1.0 if strike or _phase == "play" or _phase == "gap" else (1.0 if _phase == "rush" else 0.0))
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
			_tick_leave(dt, player)
			if _phase_t <= 0.0:
				if _fire_at == Vector3.INF:
					_pos = Vector3.INF
				_enter("play", _song_seconds())
		"gap":
			_tick_leave(dt, player)
			if _phase_t <= 0.0:
				if _songs >= LEAN_AFTER and not in_light and _fire_at == Vector3.INF:
					_enter("lean", LEAN_SEC)
				else:
					_enter("play", _song_seconds())
		"play":
			_tick_play(dt, player, in_light)
		"lean":
			_tick_lean(dt, player, in_light)
		"rush":
			_tick_rush(dt, player, in_light)


func _song_seconds() -> float:
	return _rng.randf_range(SONG_SEC.x, SONG_SEC.y)


func _quiet_seconds() -> float:
	return lerpf(QUIET_SEC.x, QUIET_SEC.y, float(_difficulty - 1) / 4.0) * _rng.randf_range(0.85, 1.15)


## His song: nearer as it goes, and he is listening.
func _tick_play(dt: float, player: Vector3, in_light: bool) -> void:
	var by_fire := _fire_at != Vector3.INF
	_grace = maxf(0.0, _grace - dt)
	_music.volume_db = lerpf(SONG_DB, WARN_DB, _grace / _grace_from) if _grace_from > 0.0 else SONG_DB
	# Back out of a door: he has been playing on.
	if not _music.playing:
		_music.play(_rng.randf_range(0.0, 3.0))
	var to := player - _pos
	to.y = 0.0
	var hold: float = NEAR_BY_SONG[mini(_songs, NEAR_BY_SONG.size() - 1)]
	if not by_fire and to.length() > hold:
		var step := CREEP * dt
		var p := _floor_at(_pos + _clear_dir(_pos, to.normalized()) * step)
		if p != Vector3.INF:
			_pos = p
		if _body.visible:
			_place_body(_pos)
			_stride(step)
	_source = _pos
	_music.global_position = _pos + Vector3(0, 1.4, 0)
	_show_near(to.length(), by_fire)
	_tell_t -= dt
	if _tell_t <= 0.0:
		_tell_t = _rng.randf_range(3.5, 6.5)
		_sound(S + "creak.mp3" if _rng.randf() < 0.6 else SFX_TWIG, _pos + Vector3(0, 1.0, 0), -6.0, _rng.randf_range(0.9, 1.1), 25.0)
	if _call_in >= 0.0:
		_call_in -= dt
		if _call_in < 0.0:
			var c := _dark_point(14.0, 24.0, 60.0, 140.0)
			if c != Vector3.INF:
				_sound(SFX_CALLS[_rng.randi() % SFX_CALLS.size()], c + Vector3(0, 1.6, 0), 0.0, 1.0, 50.0)
	if not in_light and _heard():
		_heard_at = player
		_enter("rush", 12.0)
	elif _lit_for >= GIVE_UP_IN_LIGHT:
		_give_up()
	elif _phase_t <= 0.0:
		_songs += 1
		_enter("gap", _quiet_seconds())


## A shape in the dark from close by; he never comes or goes before your eyes (by his fire he
## sits in its light).
func _show_near(me: float, by_fire: bool) -> void:
	if by_fire:
		_body.visible = true
		return
	var want := me < SEEN_M
	if want != _body.visible and not _is_seen(_pos + Vector3(0, 1.2, 0)):
		_body.visible = want
		if want:
			_pose(_tex_stand)
			_place_body(_pos)


## Right up to you, whistling in your ear: you stand it out, or you do not.
func _tick_lean(dt: float, player: Vector3, in_light: bool) -> void:
	var to := player + _lean_side * LEAN_M - _pos
	to.y = 0.0
	var step := minf(LEAN_WALK * dt, to.length())
	if step > 0.001:
		var p := _floor_at(_pos + to.normalized() * step)
		if p != Vector3.INF:
			_pos = p
		_pose(_tex_stand)
		_place_body(_pos)
		_stride(step)
	_body.visible = true
	_source = _pos
	_music.global_position = _pos + Vector3(0, 1.4, 0)
	var me := _distance_to_player(_pos)
	if not in_light and _heard():
		if me <= REACH + 0.6:
			_start_strike()
		else:
			_heard_at = player
			_enter("rush", 12.0)
	elif in_light:
		_give_up()
	elif _phase_t <= 0.0 and me <= LEAN_M + 0.5:
		var fx := _fx()
		if fx != null:
			fx.tinnitus(1.5)
		_sound(S + "mute.mp3", _pos + Vector3(0, 1.2, 0), 2.0, 1.0, 30.0)
		_enter("rest", _rng.randf_range(45.0, 70.0))


## Did he hear you: you moved, in earshot, past the song's first notes.
func _heard() -> bool:
	return _grace <= 0.0 and _distance_to_player(_pos) <= HEAR_RANGE and _speed > STILL


## At where he heard you; there he whistles again. At you: the strike. A lamp's light:
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
		# Where you were: the song again, and you had better be standing.
		_grace_next = WARN_AFTER_RUSH
		_enter("play", _song_seconds() * 0.7)
		return
	var step := minf(RUSH_SPEED * dt, to.length())
	var p := _floor_at(_pos + _clear_dir(_pos, to.normalized()) * step)
	if p != Vector3.INF:
		p.y = minf(p.y, _pos.y + 0.2)
		_pos = p
	_place_body(_pos)
	_pose(_tex_stand)
	_body.visible = true
	_stride(step)
	# Still listening on the way: a noise turns him.
	if not in_light and _speed > STILL and me < 18.0:
		_heard_at = player
	if _phase_t <= 0.0:
		_grace_next = WARN_AFTER_RUSH
		_enter("play", _song_seconds() * 0.7)


func _give_up() -> void:
	_lit_for = 0.0
	_sound(S + "mute.mp3", _pos + Vector3(0, 1.2, 0), -4.0, 0.9, 50.0)
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
		# (That can be the end of you, and of the night and his body with it.)
		if not _night_active:
			return
		claimed = true
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
		_pos = _stand(_player_pos() - _forward_flat() * 9.0)
		if _pos == Vector3.INF:
			_pos = _player_pos() - _forward_flat() * 9.0
		_heard_at = _player_pos()
		_enter("rush", 8.0)
		return
	# (Burnt down when you are not looking at it, or long after.)
	if _fire_t > 70.0 and (_fire_t > 200.0 or not _is_seen(_fire_at + Vector3(0, 0.6, 0))):
		_put_out()


func _light_fire() -> void:
	# Out of your sight: a fire does not come out of nothing in front of you.
	var p := _dark_point(24.0, 34.0, 70.0, 180.0)
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
	_pose(_tex_sit)
	_body.visible = true
	_enter("play", _song_seconds())
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
		_pose(_tex_stand)
		_body.visible = false


## Sat or stood: the picture and its feet on the ground (at the standing one's offset he hung
## 20 cm over the log).
func _pose(t: Texture2D) -> void:
	_body.texture = t
	if t != null:
		_body.offset = Vector2(0.0, float(t.get_height()) * 0.5)


## Going: back from you into the dark, gone once you have looked away or he is far enough.
func _tick_leave(dt: float, player: Vector3) -> void:
	if not _body.visible or _pos == Vector3.INF or _fire_at != Vector3.INF:
		return
	_leave_t -= dt
	var away := _pos - player
	away.y = 0.0
	var p := _floor_at(_pos + away.normalized() * 2.4 * dt)
	if p != Vector3.INF:
		_pos = p
	_place_body(_pos)
	_stride(2.4 * dt, 0.8)
	if _leave_t <= 0.0 or not _is_seen(_pos + Vector3(0, 1.2, 0)):
		_body.visible = false


# ── indoors ──────────────────────────────────────────────────────────────────

## The base ticks nothing while you are indoors: then his song is under the window now
## and then, quiet, and stops in the middle of a bar.
func tick(delta: float) -> void:
	var not_here: bool = _night_active and _world_root != null and is_instance_valid(_world_root) and not _is_ready()
	if not_here:
		_music.stop()
	if not_here and _quarry_indoors():
		var now := _elapsed
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
	# (The night over with the string round your neck: his face stayed on the screen.)
	if _strike_t >= 0.0:
		_strike_t = -1.0
		var fx := _fx()
		if fx != null:
			fx.close_up_off()


## Back out of a door: he has lost you, he does not wait at it (whatever he was at when you went
## in: stepping out into the middle of a song would be the end of you for going where you should).
func _on_back() -> void:
	# (Under the window was under the window: it played on for nine seconds out in the camp.)
	_in_sound.stop()
	if _phase != "rest":
		_pos = Vector3.INF
		_enter("rest", _rng.randf_range(12.0, 22.0))


func holds_player() -> bool:
	return _strike_t >= 0.0 and _quarry_peer() == 0


# ── helpers ──────────────────────────────────────────────────────────────────

func _relocate(near: float, far: float) -> void:
	_pos = _dark_point(near, far, 0.0, 150.0)
	if _pos == Vector3.INF:
		# (Your back to the lake or a wall: some other side of you.)
		for a: float in [180.0, 120.0, -120.0, 60.0, -60.0, 0.0]:
			_pos = _point_from_player(far, a)
			if _pos != Vector3.INF:
				return
		_pos = _player_pos() - _forward_flat() * far


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
