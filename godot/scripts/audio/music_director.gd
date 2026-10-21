extends Node

## The camp's own music, not the radio's (the user 21. 10.: "now and then, when you are
## walking about and it is time for a bigger score, the music comes in out of slow into
## its own tempo, and going out it slows down: it is a waltz, it goes round like a
## carousel; the feel of how music turns up in Don't Starve; think of co-op").
##
## The songs are godot/assets/music/<cue>.mp3, five minutes each, mapped by
## tools/audiogen/music_sections.py into music_cues.json: their bars, the sections where
## they change (a piece comes in at one of them, or at the song's own start) and where
## their own fade-out begins. Which song is the hour's and the weather's (_cue_for).
##
## Silence is the rule. After a while on your feet outside (walking, working: `_drive`),
## and some minutes after the last piece, a piece comes in: its player starts slow, at
## half its pitch, and runs up into its tempo as it fades in, a carousel getting going.
## It plays a stretch (a minute or three, to a section's end), or less: idle a while,
## the hour or the weather turning to another song, a door shut behind everyone, a
## presence at night (the insects going quiet, the night's director past UNEASE, the
## Whistler's guitar). Then, on a bar, it winds down: slower and lower until it stops.
##
## Co-op: the host chooses (from either warden's walking: the client sends whether it is
## out and about) and its piece plays on both machines, the same bars at the same time
## (coop_state / coop_take: the piece, where it came in, how far it is, going out). How
## loud it is here is this machine's own: indoors through the walls, asleep nothing, a
## presence near this warden silences it for them only.

const DIR := "res://assets/music/"
const CUES_JSON := "res://assets/music/music_cues.json"
const BUS := "WorldMusic"
const PARENT_BUS := "AmbientMusic"

const VOLUME_DB := -15.0
const SILENT_DB := -60.0
## The carousel getting going: from this pitch (and tempo) up to the song's own.
const SPIN_FROM := 0.5
const SPIN_UP_SEC := 4.5
## And running down: to this, then stopped.
const SPIN_TO := 0.28
const SPIN_DOWN_SEC := 5.5
## Seconds on your feet outside before it is time for music; it ebbs twice as slowly.
const DRIVE_FILL_SEC := 16.0
## Between two pieces.
const REST_MIN_SEC := 70.0
const REST_MAX_SEC := 190.0
## A piece's stretch (to the end of the section it reaches by then).
const STRETCH_MIN_SEC := 70.0
const STRETCH_MAX_SEC := 170.0
## Nobody on their feet outside this long: it goes out.
const IDLE_OUT_SEC := 30.0
## Faster than this (m/s) is on your feet.
const WALK_SPEED := 0.9
## Indoors the camp's music is heard through the walls.
const INDOORS_DB := -9.0
const INDOORS_LOWPASS_HZ := 900.0
const OPEN_LOWPASS_HZ := 20500.0
## A presence (main's insect hush) above this puts it out; the night's director past this.
const HUSH_OUT := 0.25
const DIRECTOR_OUT := 2   # NightDirector.State.UNEASE
## Out of step with the host by more than this (s), the other machine seeks back.
const DRIFT_SEC := 0.6

enum { OFF, UP, ON, DOWN }

var main: Node
var _cues: Dictionary = {}
var _streams: Dictionary = {}
var _player: AudioStreamPlayer
var _lowpass: AudioEffectLowPassFilter
var _rng := RandomNumberGenerator.new()

# The piece now (the same on both machines in co-op).
var _phase := OFF
var _phase_t := 0.0
var _cue := ""
var _n := 0                 # the piece's number (co-op: a new one starts it there)
var _came_in_at := 0.0      # where in the song it came in
var _out_at := 0.0          # the song's position it goes out at
var _going_out := false     # waiting for the bar to wind down on
var _last_starts: Dictionary = {}

# The host's choosing.
var _drive := 0.0
var _idle := 0.0
var _rest := 40.0
var _partner_out := false

# This machine's loudness.
var _local_db := 0.0
var _hz := OPEN_LOWPASS_HZ


func _ready() -> void:
	_rng.randomize()
	_load_cues()
	_ensure_bus()
	_player = AudioStreamPlayer.new()
	_player.name = "WorldMusic"
	_player.bus = BUS
	_player.volume_db = SILENT_DB
	add_child(_player)
	_player.finished.connect(_on_finished)


func has_music() -> bool:
	return not _cues.is_empty()


func _load_cues() -> void:
	var f := FileAccess.open(CUES_JSON, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary):
		return
	for name in d:
		if name == "title" or not ResourceLoader.exists(DIR + name + ".mp3"):
			continue
		_cues[name] = d[name]


func _stream(cue: String) -> AudioStream:
	if not _streams.has(cue):
		_streams[cue] = load(DIR + cue + ".mp3")
	return _streams[cue]


func _ensure_bus() -> void:
	var i := AudioServer.get_bus_index(BUS)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, BUS)
		var parent := PARENT_BUS if AudioServer.get_bus_index(PARENT_BUS) >= 0 else "Master"
		AudioServer.set_bus_send(i, parent)
		_lowpass = AudioEffectLowPassFilter.new()
		_lowpass.cutoff_hz = OPEN_LOWPASS_HZ
		AudioServer.add_bus_effect(i, _lowpass)
	else:
		for k in AudioServer.get_bus_effect_count(i):
			var fx := AudioServer.get_bus_effect(i, k)
			if fx is AudioEffectLowPassFilter:
				_lowpass = fx


# ── every frame ──────────────────────────────────────────────────────────────

func tick(delta: float) -> void:
	if main == null or _cues.is_empty():
		return
	# The AmbientMusic bus may be made after us (audio_manager): keep sending into it.
	var bi := AudioServer.get_bus_index(BUS)
	if bi >= 0 and AudioServer.get_bus_send(bi) != PARENT_BUS and AudioServer.get_bus_index(PARENT_BUS) >= 0:
		AudioServer.set_bus_send(bi, PARENT_BUS)
	if not bool(main.get("_gameplay_started")) or bool(main.get("_menu_mode")):
		if _phase != OFF:
			_stop()
		return
	if not Coop.is_client():
		_choose(delta)
	_play(delta)
	_mix(delta)


## The host's (or a lone warden's) choice: when a piece comes in, which, and when it goes.
func _choose(delta: float) -> void:
	var out_here := _out_and_about()
	var anyone := out_here or (Coop.is_host() and _partner_out)
	if anyone:
		_drive = minf(1.0, _drive + delta / DRIVE_FILL_SEC)
		_idle = 0.0
	else:
		_drive = maxf(0.0, _drive - delta / (DRIVE_FILL_SEC * 2.0))
		_idle += delta
	var want := _cue_for()
	var allowed := want != "" and _night_allows()
	if _phase == OFF:
		_rest -= delta
		if _rest <= 0.0 and _drive >= 1.0 and allowed and _anyone_outdoors():
			_start(want, _pick_start(want))
		return
	if _phase == DOWN or _going_out:
		return
	var pos := _player.get_playback_position()
	if want != _cue or not allowed or _idle > IDLE_OUT_SEC or pos >= _out_at:
		_going_out = true


func _start(cue: String, at: float) -> void:
	var c: Dictionary = _cues[cue]
	_n += 1
	_cue = cue
	_came_in_at = at
	_last_starts[cue] = at
	# Out at the first section starting after the stretch, before its own fade-out.
	var want := at + _rng.randf_range(STRETCH_MIN_SEC, STRETCH_MAX_SEC)
	_out_at = float(c.get("end", c.get("length", 300.0)))
	for s in c.get("sections", []):
		var t := float(s.get("t", 0.0))
		if t >= want:
			_out_at = minf(_out_at, t)
			break
	_begin(at)


func _begin(at: float) -> void:
	var s := _stream(_cue)
	if s == null:
		return
	if s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = false
	_player.stream = s
	_player.pitch_scale = SPIN_FROM
	_player.volume_db = SILENT_DB
	_player.play(at)
	_phase = UP
	_phase_t = 0.0
	_going_out = false


## Where it comes in: the song's own start now and then, else a section that is not the
## quiet end of it and not where it came in last time.
func _pick_start(cue: String) -> float:
	var c: Dictionary = _cues[cue]
	var end := float(c.get("end", 300.0))
	if _rng.randf() < 0.3 or not _last_starts.has(cue):
		return 0.0
	var pool: Array = []
	for s in c.get("sections", []):
		var t := float(s.get("t", 0.0))
		if t < end - STRETCH_MIN_SEC and float(s.get("db", 0.0)) > -8.0 and absf(t - float(_last_starts.get(cue, -999.0))) > 5.0:
			pool.append(t)
	return float(pool[_rng.randi() % pool.size()]) if not pool.is_empty() else 0.0


## The song for the hour and the weather ("" for none).
func _cue_for() -> String:
	var h := float(main.get("_time_of_day_hours"))
	var ws = main.get("weather_system")
	var w := int(ws.get("current_weather")) if ws != null else 0
	var pick := ""
	if w == 6:
		pick = "red"
	elif h >= 22.5 or h < 5.0:
		pick = "night"
	elif h >= 19.5:
		pick = "nightstart"
	elif w == 3 or w == 4 or w == 5:
		pick = "rain"
	elif h < 10.0:
		pick = "morning"
	elif h < 16.0:
		pick = "tycoon"
	else:
		pick = "golden"
	return pick if _cues.has(pick) else ""


## At night only while it is quiet: no presence felt, the night's director not past
## UNEASE, the Whistler not playing (his music is the only music when it plays).
func _night_allows() -> bool:
	if _hush() > HUSH_OUT:
		return false
	var dir = main.get("_director")
	var h := float(main.get("_time_of_day_hours"))
	if dir != null and (h >= 20.0 or h < 5.5) and int(dir.get("state")) > DIRECTOR_OUT:
		return false
	var brains = main.get("_enemy_brains")
	if brains is Array:
		for b in brains:
			if b == null or not is_instance_valid(b):
				continue
			var m = b.get("_music")
			if m is AudioStreamPlayer3D and (m as AudioStreamPlayer3D).playing:
				return false
	return true


func _hush() -> float:
	var am = main.get("_audio_manager")
	return float(am.get("_insect_hush")) if am != null and am.get("_insect_hush") != null else 0.0


## This warden is outside, on their feet.
func _out_and_about() -> bool:
	if _indoors():
		return false
	var p = main.get("_player")
	if p == null or not is_instance_valid(p) or not (p is CharacterBody3D):
		return false
	var v: Vector3 = (p as CharacterBody3D).velocity
	return Vector2(v.x, v.z).length() > WALK_SPEED


func _anyone_outdoors() -> bool:
	return not _indoors() or (Coop.is_host() and _partner_out)


func _indoors() -> bool:
	return main.has_method("_is_any_interior_open") and bool(main.call("_is_any_interior_open"))


func _asleep() -> bool:
	var im = main.get("_interior_manager")
	var bi = im.get("_building_interior") if im != null else null
	return bi != null and bi.has_method("_eyes_shut") and bool(bi.call("_eyes_shut"))


# ── the player ───────────────────────────────────────────────────────────────

func _play(delta: float) -> void:
	if _phase == OFF:
		return
	_phase_t += delta
	match _phase:
		UP:
			var k := clampf(_phase_t / SPIN_UP_SEC, 0.0, 1.0)
			# A motor taking up the load: quick at first, settling into the tempo.
			var e := 1.0 - pow(1.0 - k, 2.4)
			_player.pitch_scale = lerpf(SPIN_FROM, 1.0, e)
			_set_gain(e)
			if k >= 1.0:
				_phase = ON
				_phase_t = 0.0
		ON:
			_player.pitch_scale = 1.0
			_set_gain(1.0)
			if _going_out and _on_a_bar():
				_phase = DOWN
				_phase_t = 0.0
		DOWN:
			var k2 := clampf(_phase_t / SPIN_DOWN_SEC, 0.0, 1.0)
			# Running down: slow to let go, then sagging fast as it stops.
			_player.pitch_scale = lerpf(1.0, SPIN_TO, pow(k2, 1.6))
			_set_gain(pow(1.0 - k2, 1.3))
			if k2 >= 1.0:
				_stop()


var _gain := 0.0
func _set_gain(g: float) -> void:
	_gain = g


## On a bar line now (the next one is under a frame away), or none left to wait for.
func _on_a_bar() -> bool:
	var bars: Array = (_cues.get(_cue, {}) as Dictionary).get("bars", [])
	var pos := _player.get_playback_position()
	var step := get_process_delta_time() * _player.pitch_scale * 1.5
	for t in bars:
		var bt := float(t)
		if bt >= pos:
			return bt - pos <= step
	return true


func _stop() -> void:
	_player.stop()
	_phase = OFF
	_going_out = false
	_cue = ""
	_drive = 0.0
	_rest = _rng.randf_range(REST_MIN_SEC, REST_MAX_SEC)


func _on_finished() -> void:
	if _phase != OFF:
		_stop()


## How loud here: the piece's own fade, then this machine's (walls, sleep, a presence).
func _mix(delta: float) -> void:
	var target := 0.0
	var hz := OPEN_LOWPASS_HZ
	if _indoors():
		target = INDOORS_DB
		hz = INDOORS_LOWPASS_HZ
	if _asleep() or _hush() > HUSH_OUT:
		target = SILENT_DB
	_local_db = move_toward(_local_db, target, delta * 30.0)
	_hz = lerpf(_hz, hz, clampf(delta * 4.0, 0.0, 1.0))
	if _lowpass != null:
		_lowpass.cutoff_hz = _hz
	if _phase == OFF:
		return
	_player.volume_db = maxf(SILENT_DB, VOLUME_DB + linear_to_db(maxf(_gain, 0.0001)) + _local_db)


# ── co-op ────────────────────────────────────────────────────────────────────

## The host: the piece (main's coop sync "music"). The client: whether it is out and about.
func coop_state() -> Dictionary:
	if Coop.is_client():
		return {"out": _out_and_about()}
	var pos := _player.get_playback_position() if _phase != OFF else 0.0
	return {"n": _n if _phase != OFF else 0, "c": _cue, "at": _came_in_at, "out": _phase == DOWN or _going_out,
		"pos": floorf(pos / 4.0) * 4.0}


func coop_take(d: Dictionary) -> void:
	if not Coop.is_client():
		_partner_out = bool(d.get("out", false))
		return
	var n := int(d.get("n", 0))
	var cue := str(d.get("c", ""))
	if n == 0 or not _cues.has(cue):
		if _phase == UP or _phase == ON:
			_going_out = true
		return
	if n != _n:
		_n = n
		_cue = cue
		_came_in_at = float(d.get("at", 0.0))
		var pos := float(d.get("pos", 0.0))
		# Joined mid-way: straight in where the host is (still a carousel getting going).
		_begin(pos + 0.3 if pos > _came_in_at + 4.0 else _came_in_at)
		return
	if bool(d.get("out", false)) and _phase != DOWN:
		_going_out = true
	elif _phase == ON:
		var here := _player.get_playback_position()
		var there := float(d.get("pos", 0.0))
		if here < there - DRIFT_SEC or here > there + 4.0 + DRIFT_SEC:
			_player.seek(there + 0.3)


# ── debug ────────────────────────────────────────────────────────────────────

## Debug (tools, the content reel): a piece now (`cue` "" = the hour's), at `at` (-1 = picked).
func debug_play(cue: String = "", at: float = -1.0) -> void:
	if cue == "":
		cue = _cue_for()
	if not _cues.has(cue):
		return
	if _phase != OFF:
		_player.stop()
		_phase = OFF
	_idle = 0.0
	_drive = 1.0
	_start(cue, at if at >= 0.0 else _pick_start(cue))


func debug_out() -> void:
	if _phase == UP or _phase == ON:
		_going_out = true


func debug_text() -> String:
	return "%s %s pos %.1f pitch %.2f gain %.2f drive %.2f rest %.0f" % [
		_cue, ["off", "up", "on", "down"][_phase], _player.get_playback_position() if _phase != OFF else 0.0,
		_player.pitch_scale, _gain, _drive, _rest]
