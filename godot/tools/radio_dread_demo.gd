extends SceneTree

## A listening demo of the radio going wrong: one song through the radio buses while
## dread climbs, with each stage forced in turn (skip, sag, ghost station, drift with a
## code word, a bird on the frequency, a full broadcast, something close).
## Record it with the Movie Maker (the audio lands in the AVI):
##   godot --path godot --resolution 160x120 --fixed-fps 30 --write-movie demo.avi --script res://tools/radio_dread_demo.gd
## Optional: -- --song=res://assets/sfx/radio/<file>.mp3

const DREAD = preload("res://scripts/radio/radio_dread.gd")

var _r
var _music: AudioStreamPlayer
var _t := 0.0
var _done: Dictionary = {}
var _ctx := {"night": true, "hours": 23.5, "day": 4, "tonight": ["girl"], "guests": 7, "risk": 0.0, "nearest": INF}

## [at second, dread, action]
const SCRIPT_STEPS := [
	[0.0, 0.05, ""], [14.0, 0.4, ""], [18.0, 0.4, "stutter"], [26.0, 0.45, "sag"], [34.0, 0.5, "ghost"],
	[52.0, 0.75, "drift"], [72.0, 0.8, "creature"], [82.0, 0.9, "interlude"], [134.0, 0.9, "near"],
	[150.0, 0.9, "far"], [162.0, 0.9, "end"],
]


func _initialize() -> void:
	var radio := AudioServer.get_bus_index("Radio")
	if radio == -1:
		radio = AudioServer.get_bus_count()
		AudioServer.add_bus(radio)
		AudioServer.set_bus_name(radio, "Radio")
		var hp := AudioEffectHighPassFilter.new()
		hp.cutoff_hz = 175.0
		AudioServer.add_bus_effect(radio, hp)
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 4050.0
		AudioServer.add_bus_effect(radio, lp)
	_r = DREAD.new()
	root.add_child(_r)
	_music = AudioStreamPlayer.new()
	_music.bus = DREAD.MUSIC_BUS
	root.add_child(_music)
	var song := "res://assets/sfx/radio/prostri_song.mp3"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--song="):
			song = a.substr(7)
	_music.stream = load(song)
	_music.call_deferred("play")
	_r.bind_music(_music)
	_r.set_tracks([load("res://assets/sfx/radio/night_tatinek.mp3"), load("res://assets/sfx/radio/cervenydest_song.mp3")])
	_r._next_event_in = 9999.0


func _process(delta: float) -> bool:
	_t += delta
	var level := 0.0
	for step in SCRIPT_STEPS:
		if _t >= float(step[0]):
			level = float(step[1])
			var action: String = step[2]
			if action != "" and not _done.has(action):
				_done[action] = true
				_act(action)
	_r.debug_override = level
	_r._next_event_in = 9999.0
	_music.pitch_scale = clampf(0.97 + sin(_t * TAU * 0.34) * 0.005 * _r.wobble_scale + _r.pitch_offset, 0.72, 1.03)
	_music.volume_db = -6.0 + linear_to_db(maxf(_r.music_gain, 0.0001))
	_r.update(delta, _ctx.duplicate(), -6.0, -80.0, true, null)
	if not _music.playing and not _done.has("end"):
		_music.stream = load("res://assets/sfx/radio/prostri_song.mp3")
		_music.play(60.0)
	return _done.has("end") and _t > 163.0


func _act(action: String) -> void:
	print("%6.1f s  %s" % [_t, action])
	match action:
		"stutter":
			_r._begin_event(DREAD.Ev.STUTTER)
		"sag":
			_r._begin_event(DREAD.Ev.SAG)
		"ghost":
			_r._begin_event(DREAD.Ev.GHOST)
		"drift":
			_r._ctx = _ctx
			_r._begin_event(DREAD.Ev.DRIFT)
			_r._event_count = 1
			_r._event_len = 16.0
		"creature":
			_r._ctx = _ctx
			_r._begin_event(DREAD.Ev.CREATURE)
		"interlude":
			var built: Dictionary = _r.build_interlude(_ctx, 0.9)
			_r._interlude = built["stream"]
			_r._interlude_plan = built["plan"]
			_r._interlude_t = 0.0
			_music.stream = built["stream"]
			_music.play()
			print("         broadcast %.0f s" % float(built["length"]))
		"near":
			_music.stream = load("res://assets/sfx/radio/cervenydest_song.mp3")
			_music.play(20.0)
			_ctx["nearest"] = 4.0
		"far":
			_ctx["nearest"] = INF
