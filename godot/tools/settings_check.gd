extends Node

## Headless check of the configuration in tabs (Richard 24. 11.: „udělat pořádný settings,
## rozdělený audio video etc“; scripts/ui/settings_rows.gd): every tab has its rows and every
## row a name and a value; music, the effects and the voices each turn their own channel down
## (the mixer's "Music" and "Sfx" buses, the "Voices" bus) and only theirs, and stay so in
## the settings file; the voices' bus is not one of the effects (the mixer leaves it on Master).
##
##   godot --headless --path godot res://tools/settings_check.tscn
##
## Run as a SCENE (GameSettings and its mixer). The checks run on their own APPDATA: the file
## written is not the player's.

const ROWS := preload("res://scripts/ui/settings_rows.gd")
const MIXER := preload("res://scripts/audio/mixer.gd")

var _failures: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	# The tabs and their rows.
	var ids: Array = []
	for t in ROWS.TABS:
		var rows: Array = ROWS.rows_of(str(t[0]))
		_expect(not rows.is_empty(), "tab %s has rows" % t[0])
		for r in rows:
			ids.append(str(r["id"]))
			_expect(str(r.get("name", "")) != "", "row %s has a name" % r["id"])
	for want in ["mode", "resolution", "volume", "music", "sfx", "voices", "mic", "mouse", "fov", "hints"]:
		_expect(ids.has(want), "a row for %s" % want)
	_expect(ids.size() == ROWS.ROW.size(), "every row in one tab (%d of %d)" % [ids.size(), ROWS.ROW.size()])

	# The voices' bus as voice.gd makes it, sent to Master: the mixer must leave it there.
	if AudioServer.get_bus_index("Voices") < 0:
		var vi := AudioServer.bus_count
		AudioServer.add_bus(vi)
		AudioServer.set_bus_name(vi, "Voices")
		AudioServer.set_bus_send(vi, "Master")
	await get_tree().create_timer(0.7).timeout
	_expect(AudioServer.get_bus_send(AudioServer.get_bus_index("Voices")) == &"Master", "the voices' bus stays on Master (%s)" % AudioServer.get_bus_send(AudioServer.get_bus_index("Voices")))

	# Each channel its own.
	GameSettings.set_channel_volume("music", 0.3, true)
	GameSettings.set_channel_volume("sfx", 1.0, true)
	GameSettings.set_channel_volume("voices", 0.5, true)
	_expect(_near(_db("Music"), linear_to_db(0.3)), "music at 30 pct (%.1f dB)" % _db("Music"))
	_expect(_near(_db("Sfx"), 0.0), "the effects untouched (%.1f dB)" % _db("Sfx"))
	_expect(_near(_db("Voices"), linear_to_db(0.5)), "the voices at 50 pct (%.1f dB)" % _db("Voices"))
	_expect(str(ROWS.value("music")["text"]) == "30%", "the music row says 30 pct (%s)" % ROWS.value("music")["text"])
	ROWS.change("music", -1)
	_expect(is_equal_approx(GameSettings.get_channel_volume("music"), 0.2), "a step down: 20 pct")
	GameSettings.set_channel_volume("sfx", 0.0, true)
	_expect(AudioServer.is_bus_mute(AudioServer.get_bus_index("Sfx")) and str(ROWS.value("sfx")["text"]) == "OFF", "the effects off: muted, OFF")
	# Kept: read back from the file.
	var cfg := ConfigFile.new()
	cfg.load(GameSettings.SETTINGS_PATH)
	_expect(is_equal_approx(float(cfg.get_value("audio", "music_volume", -1.0)), 0.2) and is_equal_approx(float(cfg.get_value("audio", "voices_volume", -1.0)), 0.5), "kept in the settings file")
	GameSettings.reset_defaults()
	_expect(is_equal_approx(GameSettings.get_channel_volume("music"), 1.0) and not AudioServer.is_bus_mute(AudioServer.get_bus_index("Sfx")), "the defaults: all full again")

	if _failures.is_empty():
		print("SETTINGS CHECK: PASS")
	else:
		for f in _failures:
			print("SETTINGS CHECK FAIL: " + f)
		print("SETTINGS CHECK: FAIL (%d)" % _failures.size())
	get_tree().quit()


func _db(bus: String) -> float:
	var i := AudioServer.get_bus_index(bus)
	return AudioServer.get_bus_volume_db(i) if i >= 0 else 999.0


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.2


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
