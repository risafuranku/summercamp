extends SceneTree

## A listening demo of the song at the end of the world (scripts/audio/caretaker.gd) and of
## the radio going the same way (scripts/radio/radio_dread.gd). Record it with the Movie
## Maker (the audio lands in the AVI):
##   godot --path godot --resolution 160x120 --fixed-fps 30 --write-movie demo.avi --script res://tools/caretaker_demo.gd -- --part=hide
##   ... -- --part=radio --song=res://assets/sfx/radio/goodvibes_song.mp3
## hide: hidden with no set near, from nothing to the end, 100 s.
## radio: one song through the radio's buses while the night climbs to its worst, 120 s.

const DREAD = preload("res://scripts/radio/radio_dread.gd")
const CARE = preload("res://scripts/audio/caretaker.gd")

var _r
var _c
var _music: AudioStreamPlayer
var _t := 0.0
var _part := "hide"
var _len := 100.0
var _ctx := {"night": true, "hours": 23.5, "day": 4, "tonight": ["girl"], "guests": 7, "risk": 0.0, "nearest": INF}


func _initialize() -> void:
	var song := "res://assets/sfx/radio/goodvibes_song.mp3"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--part="):
			_part = a.substr(7)
		elif a.begins_with("--song="):
			song = a.substr(7)
	if _part == "hide":
		_c = CARE.new()
		root.add_child(_c)
		_c.debug_level = 1.0
		return
	_len = 120.0
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
	_music.stream = load(song)
	_music.call_deferred("play")
	_r.bind_music(_music)
	_r.set_tracks([load("res://assets/sfx/radio/night_motif.mp3"), load("res://assets/sfx/radio/night_tatinek.mp3")])


func _process(delta: float) -> bool:
	_t += delta
	if _c != null:
		_c.tick(delta)
	if _r != null:
		_r.debug_override = lerpf(0.15, 1.0, clampf(_t / (_len * 0.75), 0.0, 1.0))
		_r.update(delta, _ctx, -6.0, -80.0, true, null)
		_music.pitch_scale = 1.0 + _r.pitch_offset
		_music.volume_db = -6.0 + linear_to_db(maxf(_r.music_gain, 0.0001))
		if not _music.playing:
			_music.play()
	return _t >= _len
