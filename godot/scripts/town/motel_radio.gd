extends RefCounted

## The radio in a room of the Liblice motel (the user, 4. 11.: "a radio you can turn on, like
## at the reception"): the same station as the camp's, on whatever the room has. The clock
## radio in four, a valve set that takes its time warming up in two, the radiogram with its
## worn needle in nine, Mr Hora's transistor that never quite holds the station in eleven.
## The jingle, a song, an advert, a song; after midnight the night's own pieces, and when
## you are not well what you would rather not hear.
##
## Co-op: whoever is in the room hears one programme: the switch and the piece go in the
## room's state (motel_view.gd), the host says what comes next.

const DIR := "res://assets/sfx/radio/"
const SFX := "res://assets/sfx/"
const SONGS := ["autobusnula_song", "cervenydest_song", "chladnicka_song", "jahody_song", "lekar_song",
	"letnikupon_song", "mysizavod_song", "nechodven_song", "prostri_song", "regaly_song",
	"sedmynemastin_song", "song_automat", "song_infravrany", "song_radiovomitce", "vodadoma_song",
	"zenasadra_song", "goodvibes_song", "pridejsi_song", "plesvalcik_song", "plesfoxtrot_song", "plestango_song"]
const ADS := ["reklamadechovka", "reklamajar", "reklamakomar", "reklamalimo", "rodinnyreset_jingle"]
const NIGHT := ["night_babicka", "night_tatinek", "night_vypinac", "night_motif", "night_tancovacka2",
	"night_hajejdadej", "night_pocitanihostu", "night_tosebudejist", "night_tosebudejistzena",
	"night_care_valcik", "night_care_foxtrot", "night_care_tango", "night_care_tancovacka"]
const LOW := ["vodadoma_eerie", "song_cursedinfravrany", "teror_spravce", "teror_care_valcik",
	"teror_care_foxtrot", "teror_care_tango", "teror_care_motif", "teror_care_tancovacka", "teror_care_goodvibes"]
## And when you are really not well, at night: the worst (the radio's peklo_ tier).
const HELL := ["peklo_kolena", "peklo_valcik", "peklo_chaos", "peklo_chaosrytmus", "peklo_care_valcik",
	"peklo_care_foxtrot", "peklo_care_tango", "peklo_care_motif"]
const JINGLE := "signalplus_jingle"
## What each set sounds like: its level, how slow its tape of the world runs, how long it
## takes to come up, what is under the programme.
const VOICES := {
	"clock": {"db": -15.0, "pitch": 0.99, "warm": 0.0, "under": "", "under_db": -40.0, "on": "radio/radio_on.wav"},
	"tube": {"db": -13.0, "pitch": 0.97, "warm": 2.4, "under": "radio/nightnoise.mp3", "under_db": -33.0, "on": "motel/tube_warm.mp3"},
	"gram": {"db": -12.5, "pitch": 0.985, "warm": 0.9, "under": "motel/record_crackle.ogg", "under_db": -22.0, "on": "motel/radiogram_lid.mp3"},
	"portable": {"db": -16.0, "pitch": 1.0, "warm": 1.4, "under": "radio/nightnoise.mp3", "under_db": -25.0, "on": "motel/radio_tune.mp3"},
}

var view                         # motel_view.gd
var room                         # town_room.gd
var voice: Dictionary = {}
var on := false
## The piece on air (a file under DIR, without its extension).
var piece := ""
var _p: AudioStreamPlayer
var _under: AudioStreamPlayer
var _warm := -1.0
var _step := 0
var _rng := RandomNumberGenerator.new()
var _sent := ""


func _init(p_view, p_room, kind: String) -> void:
	view = p_view
	room = p_room
	voice = VOICES.get(kind, VOICES["clock"])
	_rng.randomize()
	_step = _rng.randi_range(0, 3)
	_p = AudioStreamPlayer.new()
	_p.bus = &"RadioMusic" if AudioServer.get_bus_index(&"RadioMusic") >= 0 else &"Master"
	_p.pitch_scale = float(voice["pitch"])
	room.add_child(_p)
	_under = AudioStreamPlayer.new()
	_under.volume_db = float(voice["under_db"])
	room.add_child(_under)


func toggle() -> void:
	set_on(not on)


## The switch. `by_itself`: nobody touched it (it comes up with no click of a hand).
func set_on(v: bool, by_itself := false) -> void:
	if v == on:
		return
	on = v
	if on:
		if not by_itself:
			view._play(str(voice["on"]), -9.0)
		_warm = float(voice["warm"])
		_under_on()
		if not Coop.is_client():
			_next()
		return
	view._play("radio/radio_off.wav", -10.0)
	_p.stop()
	_under.stop()
	piece = ""


func _under_on() -> void:
	var path := str(voice["under"])
	if path == "" or not ResourceLoader.exists(SFX + path):
		return
	if _under.stream == null:
		var s = load(SFX + path)
		if s is AudioStreamMP3:
			s = (s as AudioStreamMP3).duplicate()
			s.loop = true
		elif s is AudioStreamOggVorbis:
			s = (s as AudioStreamOggVorbis).duplicate()
			s.loop = true
		_under.stream = s
	if not _under.playing:
		_under.play()


func tick(delta: float) -> void:
	if not on:
		return
	var db := float(voice["db"])
	if _warm > 0.0:
		_warm -= delta
		var k := clampf(1.0 - _warm / maxf(0.1, float(voice["warm"])), 0.0, 1.0)
		_p.volume_db = lerpf(-46.0, db, k * k)
	else:
		_p.volume_db = db
	if not _p.playing and not Coop.is_client():
		_next()


## The next piece on air: the station's own round, the night's, yours.
func _next() -> void:
	_step += 1
	var h: float = view._now()
	var low: float = view._low()
	var night := h >= 23.0 or h < 4.5
	var pick := JINGLE
	match _step % 4:
		1, 3:
			pick = str(SONGS[_rng.randi_range(0, SONGS.size() - 1)])
			if night and _rng.randf() < 0.45:
				pick = str(NIGHT[_rng.randi_range(0, NIGHT.size() - 1)])
			if _rng.randf() < 0.5 * low:
				pick = str(LOW[_rng.randi_range(0, LOW.size() - 1)])
			if night and low > 0.6 and _rng.randf() < (low - 0.6) * 1.5:
				pick = str(HELL[_rng.randi_range(0, HELL.size() - 1)])
		2:
			pick = str(ADS[_rng.randi_range(0, ADS.size() - 1)])
	_play_piece(pick, 0.0)


func _play_piece(name: String, at: float) -> void:
	var path := DIR + name + ".mp3"
	if not ResourceLoader.exists(path):
		return
	piece = name
	_p.stream = load(path)
	_p.volume_db = float(voice["db"]) if _warm <= 0.0 else -46.0
	_p.play(at)


## For the room's state: the switch, the piece, where in it.
func state() -> Array:
	return [on, piece, floorf(_p.get_playback_position()) if _p.playing else 0.0]


## From the other warden (or the room as you left it).
func take(st: Array, quiet := false) -> void:
	if st.size() < 3:
		return
	var want := bool(st[0])
	if want != on:
		if quiet:
			on = want
			if not on:
				_p.stop()
				_under.stop()
			else:
				_warm = -1.0
				_under_on()
		else:
			set_on(want)
	if on and str(st[1]) != "" and str(st[1]) != piece:
		_play_piece(str(st[1]), float(st[2]))
	elif on and not _p.playing and str(st[1]) != "":
		_play_piece(str(st[1]), float(st[2]))


func free_all() -> void:
	for nd in [_p, _under]:
		if nd != null and is_instance_valid(nd):
			(nd as Node).queue_free()
