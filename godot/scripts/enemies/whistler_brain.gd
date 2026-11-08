extends "res://scripts/enemies/enemy_base.gd"

## The Whistler (Tramps; DESIGN §5a.3). The tramp turned: his hat and flannel, the
## guitar on his back, his mouth gone into a black horn like a megaphone's. He hears and
## does not see, and the rule is one line (the user 7. 11.: "when you hear his whistling you
## must not move, and ideally hide somewhere indoors"; he used to listen in the silence):
##   whistle  ("play") he plays the campfire song out in the dark and whistles it through the
##            horn, and while it sounds he is listening: move and he has you. The first notes
##            come up out of nothing: that is your time to stop. Stand still and he only
##            comes nearer, a song at a time, a shape in the dark from close by.
##   hitch    (Richard 8. 11.: "absolutní polish ve stylu holky, tichomě") a shuffle while he
##            listens, slower than a step, and his song falters: the music gone in the
##            middle of a note, his slits open where he stands, nothing. Stand, and he plays
##            on; a shuffle more, or a step, and he has heard you. Once a song.
##   hush     while he listens the camp holds its breath with you: the outdoors go down,
##            your heart comes up in your ears, your own steps are loud
##            (nightmare_fx.set_hush). Crouched you still make a step's noise, on your
##            belly an inch is a shuffle.
##   quiet    ("gap") a hand flat on the strings: the music stops dead, a moment of nothing
##            at all, then your breath out and the camp back; his eyes a moment, two pale
##            slits where he stands. Now you can move: go, get indoors.
##   rush     he heard you: boots through the grass, the guitar jangling, straight at
##            where you were; there he whistles again. Under a lamp he stops at the edge
##            of its light and goes.
##   lean     ("lean") after his third song, if you stood through them all: he walks right up
##            to you and whistles into your ear. Stand it out and he goes; move and he has you.
##   strike   at your back, in steps (as the Girl's): the string round your throat, your head
##            pulled back to the sky, choking; his horn comes round to your ear and the tune
##            is whistled into it; the cut, down, black, coming to on the ground with his
##            song going off. When it would be the last, the string only tightens. The first
##            in a camp lets you go: the tune in your ear, the string loose, him gone.
##   fire     (medium on) a campfire burning out by the trees that nobody lit, him on a
##            log by it playing. Its light is not safe: go near and the fire dies and he
##            is behind you.
##   Heavy, a guest's voice calls for help out of the dark in the middle of a song, to make
##   you move. Indoors he cannot reach you: out there by your window playing (seen through it
##   while the curtain is open), through the walls; walk about the room while he plays and the
##   song stops dead, and a moment later his horn is at the wall whistling in. Hidden long in
##   his night, he plays to a Tramp's tent instead (a guest's night). When you come out he
##   has gone off for a while.
## From eight sides (npc/sets/whistler_s1, tools/artgen figure_prompts WHISTLER): standing,
## the creep while he plays, the run.

const FIGURE = preload("res://scripts/figures/doom_figure.gd")
const WORLD_SOUNDS = preload("res://scripts/ambient/world_sounds.gd")
const N := "res://assets/textury/npc/"
const SPRITE := N + "whistler_t1.png"
const SPRITE_SIT := N + "whistler_sit.png"
const FACE := N + "whistler_face.png"
## His hands and the string across the bottom of your view (Grok whistler_garrote).
const GARROTE := N + "whistler_garrote.png"
const OLD := N + "enemy_whistler.png"
const SET := "whistler_s1"
const HEIGHT_M := 2.05
const S := "res://assets/sfx/npc/whistler/"
const SFX_PLAY := [S + "play_1.mp3", S + "play_2.mp3"]
const SFX_MUTE := S + "mute.mp3"
const SFX_CREAK := S + "creak.mp3"
const SFX_RUSH := S + "rush.mp3"
const SFX_GARROTE := S + "garrote.mp3"
const SFX_FIRE := S + "fire.mp3"
const SFX_TWIG := "res://assets/sfx/npc/twig_snap.mp3"
const SFX_CALLS := [S + "call_1.mp3", S + "call_2.mp3", S + "call_3.mp3"]
## The strike's: his tune whistled through the horn at your ear, your choking, the cut.
const SFX_TUNE := "res://assets/sfx/npc/whistler_tune.mp3"
const SFX_CHOKE := "res://assets/sfx/npc/sm_choke.mp3"
const SFX_CUT := "res://assets/sfx/npc/sm_tear.mp3"
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
## Faster than this (m/s, your moving as he hears it) is a step, whatever you walk on.
const STILL := 0.6
## More than standing and less than a step: a shuffle, the hitch.
const NUDGE := 0.22
const HITCH_SEC := Vector2(1.1, 1.6)
## How much of your moving he hears by how you go (player_controller.stance: on your feet,
## crouched, on your belly; the steps' own gains are 0, -7 and -12 dB).
const STANCE_NOISE := [1.0, 0.75, 0.3]
## The hush while he listens: at the edge of his hearing .. at your ear.
const HUSH := Vector2(0.55, 1.0)
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
## The strike (s): all of it, the kill's, and when the string cuts.
const STRIKE_SEC := 4.3
const KILL_SEC := 4.4
const CUT_AT := 2.55
## Indoors: between his songs at your window (s), how long one is, how far out he stands
## (m); hidden this long in his night (s), a Tramp's night goes instead.
const IN_EVERY := Vector2(40.0, 70.0)
const IN_SONG := Vector2(7.0, 10.0)
const IN_WINDOW_M := Vector2(7.0, 12.0)
const IN_DB := -13.0
const HIDE_COST_SEC := 80.0

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
var _garrote: Texture2D
var _sitting := false
## From eight sides: the set, which way he faces, the view shown, the frames by the ground.
var _fig: Dictionary = {}
var _fig_yaw := 0.0
var _fig_sector := 0
var _fig_anim := "stand"
var _fig_dist := 0.0
var _atlas: Dictionary = {}
var _sfx_cache: Array = []
## The fire nobody lit (medium on): where, its light, its crackle; how long it has burned.
var _fire_at := Vector3.INF
var _fire_light: OmniLight3D
var _fire_root: Node3D
var _fire_sound: AudioStreamPlayer3D
var _fire_t := 0.0
var _fire_next := 40.0
## The strike: {t, cues, kill, lesson, side, pitch0, roll0}; empty when none.
var _strike := {}
## The hitch: seconds of it left; had one this song.
var _hitch_t := 0.0
var _hitched := false
## Indoors: the next song at your window (wall clock), when this one stops, the window he is
## at (-1 none), whether he heard you in there this song; your time hidden in his night.
var _in_next := -1.0
var _in_until := -1.0
var _in_win := -1
var _in_heard := false
## His slits out there after his song stopped, till then (s of the night; -1 none).
var _in_eyes_until := -1.0
var _in_sound: AudioStreamPlayer
var _hidden_for := 0.0
var _cost_paid := false
## The song's first notes: what is left of them, how long they were; the next song's, when set.
var _grace := 0.0
var _grace_from := 0.0
var _grace_next := -1.0
## Songs you stood through; a voice calling in this one (seconds to go, -1 none).
var _songs := 0
var _call_in := -1.0
var _lean_side := Vector3.RIGHT
var _leaned := false
## His tune whistled at your ear, while it lasts.
var _tune: AudioStreamPlayer3D
var _leave_t := 0.0


func get_enemy_id() -> String:
	return "whistler"


func _on_start() -> void:
	var t := float(_difficulty - 1) / 4.0
	_hit = int(lerpf(24.0, 42.0, t))
	_tex_stand = load(SPRITE if ResourceLoader.exists(SPRITE) else OLD)
	_tex_sit = load(SPRITE_SIT) if ResourceLoader.exists(SPRITE_SIT) else _tex_stand
	_face_tex = load(FACE) if ResourceLoader.exists(FACE) else null
	_garrote = load(GARROTE) if ResourceLoader.exists(GARROTE) else null
	_fig = FIGURE.set_of(SET)
	_body = _make_body(SPRITE if ResourceLoader.exists(SPRITE) else OLD, HEIGHT_M)
	_body.visible = false
	# Every sound of his now, not off the disk at the first strike.
	var consts: Dictionary = get_script().get_script_constant_map()
	for k in consts:
		var v = consts[k]
		var paths: Array = v if v is Array else [v]
		for pth in paths:
			if pth is String and (pth as String).begins_with("res://assets/sfx/") and ResourceLoader.exists(pth):
				_sfx_cache.append(load(pth))
	# Not on his body: where he really stands, a while after the music stops.
	_make_eyes("whistler", 1.75).set("anchor", null)
	_music = AudioStreamPlayer3D.new()
	_music.unit_size = 9.0
	_music.max_distance = 70.0
	# Stopped dead is stopped dead on the other machines too (coop_night: not played out).
	_music.set_meta("coop_cut", true)
	_root.add_child(_music)
	_in_sound = AudioStreamPlayer.new()
	_in_sound.volume_db = -60.0
	_in_sound.bus = WORLD_SOUNDS.wall_bus("Master")
	_root.add_child(_in_sound)
	_fire_next = _rng.randf_range(25.0, 50.0)
	_enter("rest", _rng.randf_range(3.0, 6.0))
	# The night's screen made now (his face would not show at the first strike).
	_fx()


# ── the loop ─────────────────────────────────────────────────────────────────

func _enter(phase: String, seconds: float) -> void:
	var was := _phase
	_phase = phase
	_phase_t = seconds
	_hitch_t = 0.0
	match phase:
		"play":
			if _fire_at == Vector3.INF and (_pos == Vector3.INF or _distance_to_player(_pos) > LOST_YOU):
				_relocate(20.0, 28.0)
			_source = _pos
			_hitched = false
			_grace_from = _grace_next if _grace_next >= 0.0 else lerpf(WARN_SEC.x, WARN_SEC.y, float(_difficulty - 1) / 4.0)
			_grace_next = -1.0
			_grace = _grace_from
			_start_song(_music, _rng.randf_range(0.0, 3.0))
			_music.global_position = _source + Vector3(0, 1.4, 0)
			_music.volume_db = WARN_DB
			_tell_t = _rng.randf_range(2.5, 5.0)
			_call_in = seconds * _rng.randf_range(0.3, 0.6) if _difficulty >= 4 and _rng.randf() < 0.4 else -1.0
		"gap":
			_music.stop()
			_sound(SFX_MUTE, _pos + Vector3(0, 1.2, 0), 0.0, 1.0, 60.0)
			# You stood through it: the stop is a moment of nothing, then your breath.
			if was == "play" or was == "lean":
				_release_hush()
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
			_leaned = false
			if not _music.playing:
				_start_song(_music, _rng.randf_range(0.0, 3.0))
			_music.volume_db = SONG_DB
		"rush":
			_music.stop()
			_sound(SFX_RUSH, _pos + Vector3(0, 1.0, 0), 2.0, 1.0, 45.0)
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


## Round and round: a song runs 14 s, he plays up to 14: it must not run out by itself and
## leave you standing for nothing. (Looped on the cached one itself: a copy has no path, and
## co-op mirrors a sound by its path.)
func _start_song(p: Node, from: float) -> void:
	var song := load(SFX_PLAY[_rng.randi() % SFX_PLAY.size()]) as AudioStream
	if song is AudioStreamMP3 and not (song as AudioStreamMP3).loop:
		(song as AudioStreamMP3).loop = true
	p.set("stream", song)
	p.call("play", from)


func _on_tick(dt: float) -> void:
	_track_speed(dt)
	# His rush has its beat (chase_music.gd); where he gets to it stops dead and he listens,
	# and at your back, the string round your neck, so does it.
	var cfx := _fx()
	if cfx != null and cfx.has_method("set_chase"):
		var striking := not _strike.is_empty()
		cfx.set_chase("whistler", -1.0 if striking or _phase == "play" or _phase == "gap" else (1.0 if _phase == "rush" else 0.0))
	_eyes.set("want", 1.0 if _elapsed < _eyes_until and _phase != "rush" else 0.0)
	if not _strike.is_empty():
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
	_strings()
	if _body.visible and not _sitting:
		_show_fig()


func _song_seconds() -> float:
	return _rng.randf_range(SONG_SEC.x, SONG_SEC.y)


func _quiet_seconds() -> float:
	return lerpf(QUIET_SEC.x, QUIET_SEC.y, float(_difficulty - 1) / 4.0) * _rng.randf_range(0.85, 1.15)


## His song: nearer as it goes, and he is listening.
func _tick_play(dt: float, player: Vector3, in_light: bool) -> void:
	var by_fire := _fire_at != Vector3.INF
	_grace = maxf(0.0, _grace - dt)
	var me := _distance_to_player(_pos)
	var listening := _grace <= 0.0 and not in_light and me <= HEAR_RANGE
	# The hitch: the song gone in the middle of a note, his slits, and nothing.
	if _hitch_t > 0.0:
		_hitch_t -= dt
		_hush(1.0)
		if listening and _noise() > NUDGE:
			_heard_at = player
			_enter("rush", 12.0)
			return
		if _hitch_t <= 0.0:
			_music.volume_db = SONG_DB
		return
	_music.volume_db = lerpf(SONG_DB, WARN_DB, _grace / _grace_from) if _grace_from > 0.0 else SONG_DB
	# Back out of a door: he has been playing on.
	if not _music.playing:
		_start_song(_music, _rng.randf_range(0.0, 3.0))
	var to := player - _pos
	to.y = 0.0
	var hold: float = NEAR_BY_SONG[mini(_songs, NEAR_BY_SONG.size() - 1)]
	if not by_fire and to.length() > hold:
		var step := CREEP * dt
		var p := _floor_at(_pos + _clear_dir(_pos, to.normalized()) * step)
		if p != Vector3.INF:
			var was := _pos
			_pos = p
			if _body.visible:
				_place_body(_pos)
				_walked(_pos - was)
	elif _body.visible and not by_fire:
		_stand_toward(player)
	_source = _pos
	_music.global_position = _pos + Vector3(0, 1.4, 0)
	_show_near(to.length(), by_fire)
	# The hush comes up with his first notes (they are your time to stop) and is all there
	# once he listens; the nearer, the deeper.
	var near := clampf(1.0 - me / HEAR_RANGE, 0.0, 1.0)
	if listening:
		_hush(lerpf(HUSH.x, HUSH.y, near))
	elif not in_light and me <= HEAR_RANGE and _grace_from > 0.0:
		_hush(HUSH.x * (1.0 - _grace / _grace_from))
	_tell_t -= dt
	if _tell_t <= 0.0:
		_tell_t = _rng.randf_range(3.5, 6.5)
		_sound(SFX_CREAK if _rng.randf() < 0.6 else SFX_TWIG, _pos + Vector3(0, 1.0, 0), -6.0, _rng.randf_range(0.9, 1.1), 25.0)
	if _call_in >= 0.0:
		_call_in -= dt
		if _call_in < 0.0:
			var c := _dark_point(14.0, 24.0, 60.0, 140.0)
			if c != Vector3.INF:
				_sound(SFX_CALLS[_rng.randi() % SFX_CALLS.size()], c + Vector3(0, 1.6, 0), 0.0, 1.0, 50.0)
	var noise := _noise()
	if listening and noise > STILL:
		_heard_at = player
		_enter("rush", 12.0)
	elif listening and noise > NUDGE and not _hitched:
		_start_hitch()
	elif _lit_for >= GIVE_UP_IN_LIGHT:
		_give_up()
	elif _phase_t <= 0.0:
		_songs += 1
		_enter("gap", _quiet_seconds())


## His strings over your picture from where he is (nightmare_fx.set_mark "strings"; Richard 8.
## 11.: "audiovizuály na úrovni pískače/holky"): up with his first notes, trembling with
## the song, dead still in the falter, jangling at a run; follow them and you know where he is.
## The song stopped dead takes them with it.
func _strings() -> void:
	if _pos == Vector3.INF or _phase == "rest" or _phase == "gap":
		return
	var fx := _fx()
	if fx == null or not fx.has_method("set_mark"):
		return
	var me := _distance_to_player(_pos)
	if me > HEAR_RANGE:
		return
	var near := clampf(1.0 - me / HEAR_RANGE, 0.0, 1.0)
	var level := 0.3 + 0.7 * near
	var vib := 0.3 + 0.4 * near
	match _phase:
		"play":
			if _grace_from > 0.0:
				level *= 1.0 - 0.7 * (_grace / _grace_from)
			if _hitch_t > 0.0:
				vib = 0.0
		"lean":
			level = 1.0
			vib = 0.7
		"rush":
			level = 0.9
			vib = 1.0
	fx.set_mark("strings", _pos + Vector3(0, 1.4, 0), _camera(), level, vib)


## A shuffle: the song falters (the music down to nothing, as it goes to the other
## machines: a pause would not), his slits open where he stands, and he listens.
func _start_hitch() -> void:
	_hitched = true
	_hitch_t = _rng.randf_range(HITCH_SEC.x, HITCH_SEC.y)
	_music.volume_db = -80.0
	_eyes.set("point", _pos + Vector3(0, 1.75, 0))
	_eyes_until = _elapsed + _hitch_t
	var fx := _fx()
	if fx != null and fx.has_method("mark_jolt"):
		fx.mark_jolt("strings", 1.0)
	if _body.visible and not _sitting:
		_stand_toward(_player_pos())


## Would he hear you now: listening (past the first notes, in earshot) and you moving.
func _heard() -> bool:
	return _grace <= 0.0 and _distance_to_player(_pos) <= HEAR_RANGE and _noise() > STILL


## How much of your moving he hears now (m/s): your speed by how you go.
func _noise() -> float:
	var stance := 0
	var speed := _speed
	var peer := _quarry_peer()
	if peer != 0:
		var st: Dictionary = Coop.state_of(peer)
		speed = float(st.get("v", 0.0)) if not (st.get("v") is Vector2 or st.get("v") is Vector3) else Vector2(st["v"].x, st["v"].y if st["v"] is Vector2 else st["v"].z).length()
		stance = 2 if str(st.get("act", "")) == "prone" else (1 if str(st.get("act", "")) == "crouch" else 0)
	elif _player != null and _player.get("stance") != null:
		stance = clampi(int(_player.get("stance")), 0, 2)
	return speed * float(STANCE_NOISE[stance])


func _hush(level: float) -> void:
	var fx := _fx()
	if fx != null and fx.has_method("set_hush"):
		fx.set_hush("whistler", level)


func _release_hush() -> void:
	var fx := _fx()
	if fx != null and fx.has_method("hush_release"):
		fx.hush_release(0.12)


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
			_pose_stand()
			_place_body(_pos)
			_stand_toward(_player_pos())


## Right up to you, whistling in your ear: you stand it out, or you do not.
func _tick_lean(dt: float, player: Vector3, in_light: bool) -> void:
	var to := player + _lean_side * LEAN_M - _pos
	to.y = 0.0
	var step := minf(LEAN_WALK * dt, to.length())
	if step > 0.001:
		var p := _floor_at(_pos + to.normalized() * step)
		if p != Vector3.INF:
			var was := _pos
			_pos = p
			_pose_stand()
			_place_body(_pos)
			_walked(_pos - was)
	else:
		_stand_toward(player)
	_body.visible = true
	_source = _pos
	_music.global_position = _pos + Vector3(0, 1.4, 0)
	var me := _distance_to_player(_pos)
	_hush(1.0)
	# At your ear: the tune whistled into it from his side, and you stand it.
	if not _leaned and me <= LEAN_M + 0.5:
		_leaned = true
		_ear_whistle(-6.0, 1.0)
		var fx := _fx()
		if fx != null:
			fx.tinnitus(2.4)
	if not in_light and _noise() > STILL:
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
		_sound(SFX_MUTE, _pos + Vector3(0, 1.2, 0), 2.0, 1.0, 30.0)
		_release_hush()
		_stop_tune()
		_enter("rest", _rng.randf_range(45.0, 70.0))


## His tune through the horn at your ear, on the side he is at.
func _ear_whistle(db: float, pitch: float) -> void:
	var side := _pos - _player_pos()
	side.y = 0.0
	side = side.normalized() if side.length() > 0.05 else _forward_flat().cross(Vector3.UP)
	_stop_tune()
	_tune = _sound_quarry(SFX_TUNE, _player_pos() + Vector3(0, 1.55, 0) + side * 0.25, db, pitch, 8.0)
	_near_you(_tune)


## The tune in your ear stopped (its file runs 7 s; the moment it is over it is over).
func _stop_tune() -> void:
	if _tune != null and is_instance_valid(_tune):
		_tune.stop()
		_tune.queue_free()
	_tune = null


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
		var was := _pos
		_pos = p
		_pose_stand()
		_place_body(_pos)
		_walked(_pos - was, true)
	_body.visible = true
	# Still listening on the way: a noise turns him.
	if not in_light and _noise() > STILL and me < 18.0:
		_heard_at = player
	if _phase_t <= 0.0:
		_grace_next = WARN_AFTER_RUSH
		_enter("play", _song_seconds() * 0.7)


func _give_up() -> void:
	_lit_for = 0.0
	_sound(SFX_MUTE, _pos + Vector3(0, 1.2, 0), -4.0, 0.9, 50.0)
	_release_hush()
	_enter("rest", _rng.randf_range(35.0, 55.0))


# ── the strike ───────────────────────────────────────────────────────────────

## At your back: the string round your throat. In steps, as the Girl's (DESIGN §5a.3).
func _start_strike() -> void:
	var lesson := not _met()
	var kill := not lesson and _player_health() - _hit <= 0
	var cam := _camera()
	_strike = {"t": 0.0, "cues": {}, "kill": kill, "lesson": lesson, "side": -1.0 if _rng.randf() < 0.5 else 1.0,
		"pitch0": cam.rotation.x if cam != null else 0.0, "roll0": cam.rotation.z if cam != null else 0.0}
	_mark_met()
	_music.stop()
	_body.visible = false
	_view_begin()
	if _quarry_peer() == 0 and _player.has_method("set_controls_enabled"):
		_player.call("set_controls_enabled", false)
	_ear(SFX_GARROTE, 2.0)
	var fx := _fx()
	if fx != null:
		fx.freeze(0.08)
		fx.glitch(0.5, 0.4)


func _cue(at: float, id: String) -> bool:
	var cues: Dictionary = _strike["cues"]
	if float(_strike["t"]) >= at and not cues.has(id):
		cues[id] = true
		return true
	return false


func _ear(file: String, db: float, pitch: float = 1.0) -> void:
	_near_you(_sound_quarry(file, _player_pos() + Vector3(0, 1.55, 0) - _forward_flat() * 0.25, db, pitch, 8.0))


## A sound at you at the gain written (its nearness would add 20 dB: the Girl's _near_you).
func _near_you(p: AudioStreamPlayer3D) -> void:
	var cam := _camera()
	if p != null and cam != null:
		p.unit_size = maxf(0.05, cam.global_position.distance_to(p.global_position))


func _tick_strike(dt: float) -> void:
	_strike["t"] = float(_strike["t"]) + dt
	var t: float = _strike["t"]
	# Twelve steps a second, as every strike of the night.
	var st := floorf(t * 12.0) / 12.0
	var kill: bool = _strike["kill"]
	var lesson: bool = _strike["lesson"]
	var side: float = _strike["side"]
	var p0: float = _strike["pitch0"]
	var r0: float = _strike["roll0"]
	var fx := _fx()
	if fx != null:
		fx.set_dread("whistler", 1.0)
		# Not the full tunnel while his face is there: it would eat the art (the Girl's too).
		fx.set_presence("whistler", 0.75 if st < 1.5 else (0.45 if st < CUT_AT + 0.6 else 0.3))
	# Yanked back: the string from behind, your head pulled up to the sky.
	if st < 0.34:
		var k := st / 0.34
		_set_pitch(p0 + 0.42 * k)
		_set_roll(r0 + 0.05 * side * k)
		if fx != null and _garrote != null:
			fx.overlay(_garrote, 1.0, 0.02, Vector2(0.0, lerpf(0.45, 0.06, k)))
		if _cue(0.08, "choke"):
			_ear(SFX_CHOKE, -1.0)
	# The string tightening: your head held back, your hands at it, the edges going.
	elif st < 1.5:
		var k := (st - 0.34) / 1.16
		_set_pitch(p0 + 0.42 + 0.035 * sin(st * 31.0))
		_set_roll(r0 + 0.05 * side + 0.03 * sin(st * 23.0))
		if fx != null:
			if _garrote != null:
				fx.overlay(_garrote, 1.0 + 0.04 * k, 0.012, Vector2(0.0, 0.06 - 0.03 * k))
			fx.set_black(0.12 + 0.2 * k)
		if _cue(0.5, "creak"):
			_ear(SFX_CREAK, 0.0, 0.92)
	# His horn round to your ear from the side he is on; the tune whistled into it.
	elif st < CUT_AT:
		var k := (st - 1.5) / (CUT_AT - 1.5)
		_set_pitch(p0 + 0.4 + 0.02 * sin(st * 41.0))
		if fx != null:
			if _face_tex != null:
				fx.close_up(_face_tex, lerpf(0.85, 1.3, k), 1.0, 0.008 + 0.02 * k, side * lerpf(0.32, 0.12, k), Vector2(side * lerpf(0.78, 0.3, k), 0.06))
			if _garrote != null:
				fx.overlay(_garrote, 1.04, 0.016, Vector2(0.0, 0.03))
			fx.set_black(lerpf(0.32, 0.1, minf(k * 3.0, 1.0)))
		if _cue(1.8, "whistle"):
			_ear_whistle(1.5, 1.12)
			if fx != null:
				fx.tinnitus(2.8)
				fx.glitch(0.6, 0.6)
	elif lesson:
		# The first in a camp: the string loose, the tune in your ear, and he is gone.
		var k := clampf((st - CUT_AT) / 0.9, 0.0, 1.0)
		if _cue(CUT_AT, "loose"):
			_stop_tune()
			_ear(SFX_MUTE, 0.0, 0.85)
			if fx != null:
				fx.close_up_off()
				fx.glitch(0.7, 0.7)
		_set_pitch(p0 + lerpf(0.4, -0.3, minf(k * 2.0, 1.0)) + 0.3 * maxf(0.0, k * 2.0 - 1.0))
		_set_roll(r0 + side * 0.12 * (1.0 - k))
		if fx != null:
			fx.set_black(0.32 * (1.0 - k))
		if t >= CUT_AT + 0.9:
			_end_strike()
			_pos = Vector3.INF
			_enter("rest", _rng.randf_range(50.0, 70.0))
	elif kill:
		# The last: the string only tightens; the tune goes on in your ear as it all goes dark.
		var k := clampf((st - CUT_AT) / (KILL_SEC - CUT_AT), 0.0, 1.0)
		_set_pitch(p0 + 0.4 + 0.05 * k + 0.02 * sin(st * 47.0))
		if fx != null:
			if _face_tex != null:
				fx.close_up(_face_tex, lerpf(1.3, 1.9, k), 1.0, 0.02, side * 0.12, Vector2(side * lerpf(0.3, 0.15, k), 0.06))
			if _garrote != null:
				fx.overlay(_garrote, 1.04 + 0.06 * k, 0.02, Vector2(0.0, 0.03 - 0.04 * k))
			fx.set_black(lerpf(0.1, 1.0, k * k))
		if _cue(CUT_AT, "tighter"):
			_ear(SFX_CREAK, 2.0, 0.8)
			_ear(SFX_CHOKE, 1.0, 0.85)
		if t >= KILL_SEC:
			# Black and held first: the end of you takes it from there.
			_end_strike(true)
			_hurt(_hit)
	else:
		# The cut; down in the grass; black; coming to with his song going off.
		if _cue(CUT_AT, "cut"):
			_stop_tune()
			_ear(SFX_CUT, 1.0, 0.9)
			_ear(SFX_MUTE, -2.0, 1.2)
			_hurt(_hit)
			claimed = true
			if fx != null:
				fx.close_up_off()
				fx.red_flash(0.5)
				fx.blood(0.6, Vector2(0.5, 0.82))
		# (That can be the end of you, and of the night with it.)
		if not _night_active:
			return
		if st < 3.0:
			var k := (st - CUT_AT) / (3.0 - CUT_AT)
			_set_pitch(p0 + lerpf(0.4, -0.85, k))
			_set_roll(r0 + side * 0.5 * k)
			if fx != null:
				fx.set_black(lerpf(0.1, 0.6, k))
		elif st < 3.55:
			if fx != null:
				fx.set_black(1.0)
			if _cue(3.2, "away"):
				_pos = _stand(_player_pos() - _forward_flat() * 22.0)
				if _pos != Vector3.INF:
					_start_song(_music, _rng.randf_range(0.0, 3.0))
					_music.global_position = _pos + Vector3(0, 1.4, 0)
					_music.volume_db = -10.0
		else:
			var k := clampf(floorf((st - 3.55) / (STRIKE_SEC - 3.55) * 6.0) / 6.0, 0.0, 1.0)
			_set_pitch(p0 - 0.85 * (1.0 - k))
			_set_roll(r0 + side * 0.5 * (1.0 - k))
			if fx != null:
				fx.set_black(1.0 - k)
			_music.volume_db = lerpf(-10.0, -30.0, k)
		if t >= STRIKE_SEC:
			_music.stop()
			_end_strike()
			_pos = Vector3.INF
			_enter("rest", _rng.randf_range(40.0, 60.0))


func _end_strike(kill := false) -> void:
	if _strike.is_empty():
		return
	_stop_tune()
	var p0: float = _strike["pitch0"]
	var r0: float = _strike["roll0"]
	_strike = {}
	var fx := _fx()
	if fx != null:
		fx.close_up_off()
		fx.overlay_off()
		fx.set_black(1.0 if kill else 0.0)
	if kill:
		return
	if _player != null and is_instance_valid(_player):
		_set_pitch(p0)
		_set_roll(r0)
	_view_end()
	if _quarry_peer() == 0 and _player != null and is_instance_valid(_player) and _player.has_method("set_controls_enabled"):
		_player.call("set_controls_enabled", true)


func holds_player() -> bool:
	return not _strike.is_empty() and _quarry_peer() == 0


## Has he had a warden of this camp once (the first lets you go)? (No director, no camp to
## remember it: a harness.)
func _met() -> bool:
	var d = _director()
	if d == null or not (d.get("ever") is Dictionary):
		return true
	return bool((d.get("ever") as Dictionary).get("whistler_met", false))


func _mark_met() -> void:
	var d = _director()
	if d != null and d.get("ever") is Dictionary:
		(d.get("ever") as Dictionary)["whistler_met"] = true


func _director():
	var scene := _world_root.get_tree().current_scene if _world_root != null and _world_root.is_inside_tree() else null
	return scene.get("_director") if scene != null else null


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
	_fire_sound = _sound(SFX_FIRE, p + Vector3(0, 0.4, 0), -4.0, 1.0, 40.0)
	if _fire_sound != null and _fire_sound.stream is AudioStreamMP3:
		(_fire_sound.stream as AudioStreamMP3).loop = true
	# He sits by it: the music from there, and him on the log in its light.
	_pos = p + Vector3(1.1, 0, 0)
	_place_body(_pos)
	_pose_sit()
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
		_pose_stand()
		_body.visible = false


# ── his picture ──────────────────────────────────────────────────────────────

## Sat on the log by his fire: its own picture, its feet on the ground (at the standing
## one's offset he hung 20 cm over the log).
func _pose_sit() -> void:
	_sitting = true
	_body.scale = Vector3.ONE
	_body.flip_h = false
	_body.texture = _tex_sit
	if _tex_sit != null:
		_body.pixel_size = HEIGHT_M / float(_tex_stand.get_height()) if _tex_stand != null else _body.pixel_size
		_body.offset = Vector2(0.0, float(_tex_sit.get_height()) * 0.5)


func _pose_stand() -> void:
	if not _sitting and _body.texture != null and (not _fig.is_empty() or _body.texture == _tex_stand):
		return
	_sitting = false
	if _fig.is_empty():
		_body.texture = _tex_stand
		if _tex_stand != null:
			_body.pixel_size = HEIGHT_M / float(_tex_stand.get_height())
			_body.offset = Vector2(0.0, float(_tex_stand.get_height()) * 0.5)
	else:
		_fig_anim = "stand"
		_show_fig()


## Where he went this tick (`step`, at a run or not): from eight sides, the frames by the
## ground covered; without his set, the one picture swung at each step.
func _walked(step: Vector3, run := false) -> void:
	var flat := Vector2(step.x, step.z).length()
	if _fig.is_empty():
		if flat > 0.0:
			_stride(flat)
		return
	if flat > 0.0005:
		_fig_yaw = atan2(-step.x, -step.z)
		var a := "run" if run else "walk"
		if a != _fig_anim:
			_fig_anim = a
			_fig_dist = 0.0
		_fig_dist += flat
	else:
		_fig_anim = "stand"
	_show_fig()


## Standing, turned toward `p` (he listens with his whole body).
func _stand_toward(p: Vector3) -> void:
	if _fig.is_empty() or _pos == Vector3.INF:
		return
	var d := p - _pos
	if Vector2(d.x, d.z).length() > 0.05:
		_fig_yaw = atan2(-d.x, -d.z)
	_fig_anim = "stand"
	_show_fig()


## The view of him from where you look, as an atlas region (co-op mirrors AtlasTextures).
func _show_fig() -> void:
	if _fig.is_empty() or _sitting or _body == null:
		return
	var cam := _camera()
	var eye: Vector3 = cam.global_position if cam != null else _player_pos() + Vector3(0, 1.6, 0)
	_fig_sector = FIGURE.sector_for(_body.global_position, _fig_yaw, eye, _fig_sector)
	var view := absi(_fig_sector)
	var flip := _fig_sector < 0
	var anims: Dictionary = _fig.get("anims", {})
	var n := 1
	for v in anims.get(_fig_anim, []):
		n = maxi(n, (v as Array).size())
	var frame := int(_fig_dist / float(FIGURE.STRIDE.get(_fig_anim, 1.0))) % n if FIGURE.STRIDE.has(_fig_anim) else 0
	var fr = FIGURE._frame_of(anims, _fig_anim, view, frame)
	if fr == null:
		fr = FIGURE._frame_of(anims, "stand", view, 0)
	if fr == null:
		fr = FIGURE._frame_of(anims, "stand", 0, 0)
	if fr == null:
		return
	var key := str(fr)
	var at: AtlasTexture = _atlas.get(key)
	if at == null:
		at = AtlasTexture.new()
		at.atlas = _fig.get("tex")
		at.region = Rect2(float(fr[0]), float(fr[1]), float(fr[2]), float(fr[3]))
		_atlas[key] = at
	_body.scale = Vector3.ONE
	_body.texture = at
	_body.pixel_size = HEIGHT_M / float(_fig.get("h", 150))
	_body.flip_h = flip
	var w := float(fr[2])
	var hh := float(fr[3])
	var ox := w * 0.5 - float(fr[4])
	_body.offset = Vector2(-ox if flip else ox, float(fr[5]) - hh * 0.5)


## Going: back from you into the dark, gone once you have looked away or he is far enough.
func _tick_leave(dt: float, player: Vector3) -> void:
	if not _body.visible or _pos == Vector3.INF or _fire_at != Vector3.INF:
		return
	_leave_t -= dt
	var away := _pos - player
	away.y = 0.0
	var p := _floor_at(_pos + away.normalized() * 2.4 * dt)
	if p != Vector3.INF:
		var was := _pos
		_pos = p
		_place_body(_pos)
		_walked(_pos - was)
	if _leave_t <= 0.0 or not _is_seen(_pos + Vector3(0, 1.2, 0)):
		_body.visible = false


# ── indoors ──────────────────────────────────────────────────────────────────

## The base ticks nothing while you are indoors: then he is out there by your window now and
## then playing (through the walls), and he hears you in there.
func tick(delta: float) -> void:
	var not_here: bool = _night_active and _world_root != null and is_instance_valid(_world_root) and not _is_ready()
	if not_here:
		_music.stop()
		if not _strike.is_empty():
			# (Gone in while he had you: nothing of it left on the screen.)
			_end_strike()
	if not_here and _quarry_indoors():
		_tick_indoors(delta)
	elif _in_until > 0.0:
		_stop_in(false)
	super(delta)
	# At your window: seen through it (the base hides him in a room), his slits when the song
	# has stopped.
	if _night_active and not_here and _in_win >= 0 and _body != null:
		_body.visible = true
		_eyes.set("want", 1.0 if _elapsed < _eyes_until else 0.0)
		_tick_eyes(delta)


func _tick_indoors(delta: float) -> void:
	_hidden_for += delta
	# Hidden long in his night: he plays to a Tramp's tent instead.
	if not _cost_paid and _hidden_for >= HIDE_COST_SEC:
		_cost_paid = true
		_play_to_guest()
	var now := _elapsed
	if _in_until > 0.0:
		_tick_in_song(delta)
		return
	if _in_eyes_until > 0.0 and now >= _in_eyes_until:
		_hide_at_window()
	if _in_next < 0.0:
		_in_next = now + _rng.randf_range(15.0, 30.0)
	elif now >= _in_next and _fx() != null:
		_in_next = now + _rng.randf_range(IN_EVERY.x, IN_EVERY.y)
		_start_in_song()


## His song at your window: him out there by one with its curtain open (seen through it), or
## only through the walls.
func _start_in_song(prefer := -1) -> void:
	_in_until = _elapsed + _rng.randf_range(IN_SONG.x, IN_SONG.y)
	_in_heard = false
	_in_win = -1
	var wins := _room_windows()
	var order: Array = range(wins.size())
	order.shuffle()
	if prefer >= 0 and prefer < wins.size():
		order.erase(prefer)
		order.push_front(prefer)
	for i in order:
		var w: Dictionary = wins[i]
		if float(w.get("open", 1.0)) < 0.35:
			continue
		var out: Vector3 = w["out"]
		out.y = 0.0
		if out.length() < 0.1:
			continue
		var p := _stand((w["pos"] as Vector3) + out.normalized().rotated(Vector3.UP, _rng.randf_range(-0.25, 0.25)) * _rng.randf_range(IN_WINDOW_M.x, IN_WINDOW_M.y))
		if p == Vector3.INF or _lamp_light_at(p) > LAMP_SAFE:
			continue
		_in_win = i
		_pos = p
		_place_body(p)
		_pose_stand()
		_fig_yaw = atan2(out.x, out.z)
		_fig_anim = "stand"
		if _eyes != null:
			_eyes.set("view_from", w.get("view", (w["pos"] as Vector3) - out.normalized() * 1.5))
		break
	_room_song(true)


func _tick_in_song(_delta: float) -> void:
	# The curtain drawn on him: behind it he is gone (the song goes on through the wall).
	if _in_win >= 0:
		var wins := _room_windows()
		if _in_win >= wins.size() or float((wins[_in_win] as Dictionary).get("open", 1.0)) < 0.35:
			_hide_at_window()
		else:
			_show_fig()
	# He hears you walk about in there: the song stops dead, and a moment later he is at the
	# glass, his horn to it, whistling in (his slits there for it).
	if not _in_heard and _noise() > STILL:
		_in_heard = true
		_room_song(false)
		_room_2d(SFX_MUTE, -6.0, 1.0, true)
		var wait := _rng.randf_range(1.4, 2.2)
		get_tree_timer(wait, func():
			if not _night_active or not _quarry_indoors():
				return
			_to_the_glass()
			_room_song(true, SFX_TUNE, -4.0, 1.18, false)
			var fx := _fx()
			if fx != null:
				fx.tinnitus(1.8)
			get_tree_timer(2.6, func():
				if _night_active:
					_room_song(false)))
		_in_until = _elapsed + wait + 2.6
		return
	if _elapsed >= _in_until:
		_stop_in(not _in_heard)


## Right at the glass of the window he played by, facing in.
func _to_the_glass() -> void:
	var wins := _room_windows()
	if _in_win < 0 or _in_win >= wins.size():
		return
	var w: Dictionary = wins[_in_win]
	var out: Vector3 = w["out"]
	out.y = 0.0
	var p := _stand((w["pos"] as Vector3) + out.normalized() * 0.9)
	if p == Vector3.INF:
		return
	_pos = p
	_place_body(p)
	_fig_yaw = atan2(out.x, out.z)
	_fig_anim = "stand"
	_eyes.set("point", p + Vector3(0, 1.75, 0))
	_eyes_until = _elapsed + 2.6


## His song over: stopped dead through the wall (`mute`), and out there by the window his
## slits a moment where he stands; or gone at once.
func _stop_in(mute: bool) -> void:
	var playing := _in_until > 0.0
	if mute and playing:
		_room_2d(SFX_MUTE, -12.0, 1.0, true)
	_room_song(false)
	_in_until = -1.0
	if mute and playing and _in_win >= 0 and _pos != Vector3.INF:
		_eyes.set("point", _pos + Vector3(0, 1.75, 0))
		_eyes_until = _elapsed + _rng.randf_range(1.6, 2.6)
		_in_eyes_until = _eyes_until
		return
	_hide_at_window()


func _hide_at_window() -> void:
	_in_win = -1
	_in_eyes_until = -1.0
	if _body != null:
		_body.visible = false
	if _eyes != null:
		_eyes.set("view_from", Vector3.INF)


## His song through the walls (or `file`, not through them when `wall` is false: his tune at the
## glass), on the machine of the warden he hunts (on another, keyed so it can be stopped dead).
func _room_song(on: bool, file := "", db := IN_DB, pitch := 1.0, wall := true) -> void:
	var peer := _quarry_peer()
	if peer != 0:
		var fx := _fx()
		if fx != null:
			if on:
				fx.call("play_2d", file if file != "" else SFX_PLAY[_rng.randi() % SFX_PLAY.size()], db, pitch, wall, "whistler_song")
			else:
				fx.call("stop_2d", "whistler_song")
		return
	if on and file == "":
		_in_sound.bus = WORLD_SOUNDS.wall_bus("Master")
		_in_sound.pitch_scale = 1.0
		_start_song(_in_sound, _rng.randf_range(0.0, 4.0))
		_in_sound.volume_db = IN_DB
	elif on:
		_in_sound.bus = WORLD_SOUNDS.wall_bus("Master") if wall else "Master"
		_in_sound.stream = load(file)
		_in_sound.pitch_scale = pitch
		_in_sound.volume_db = db
		_in_sound.play()
	elif _in_sound != null:
		_in_sound.stop()


## A sound in the room with them (`wall`: from out there, through the walls).
func _room_2d(file: String, db: float, pitch: float, wall: bool) -> void:
	if _play_2d_remote(file, db, pitch, wall):
		return
	if not ResourceLoader.exists(file):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(file)
	p.volume_db = db
	p.pitch_scale = pitch
	if wall:
		p.bus = WORLD_SOUNDS.wall_bus("Master")
	_root.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## The night you hid from him: a Tramp's (or anyone's) is played to instead.
func _play_to_guest() -> void:
	var state = CoreRoot.get_state() if CoreRoot != null else null
	if state == null or GuestManager == null:
		return
	var pick := {}
	for g in state.guests:
		if g is Dictionary and str(g.get("status", "")) in ["active", "sleep"]:
			pick = g
			if str(g.get("archetype", "")) == "tramp":
				break
	if pick.is_empty():
		return
	GuestManager.apply_guest_event(int(pick.get("id", -1)), -16.0, "Someone played the guitar outside our tent all night. When I turned over, he stopped. He was listening to me breathe.")


func get_tree_timer(seconds: float, f: Callable) -> void:
	if _world_root == null or not _world_root.is_inside_tree():
		return
	_world_root.get_tree().create_timer(seconds).timeout.connect(f)


func _on_stop() -> void:
	_put_out()
	# (The night over with the string round your neck: his face stayed on the screen.)
	if not _strike.is_empty():
		_end_strike()
	if _in_until > 0.0:
		_room_song(false)
		_in_until = -1.0


## Back out of a door: he has lost you, he does not wait at it (whatever he was at when you went
## in: stepping out into the middle of a song would be the end of you for going where you should).
func _on_back() -> void:
	# (Under the window was under the window: it played on for nine seconds out in the camp.)
	_in_sound.stop()
	_hide_at_window()
	if _phase != "rest":
		_pos = Vector3.INF
		_enter("rest", _rng.randf_range(12.0, 22.0))


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
		"fire": _fire_at != Vector3.INF, "hitch": _hitch_t > 0.0, "strike": not _strike.is_empty(), "window": _in_win}
