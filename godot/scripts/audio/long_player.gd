extends AudioStreamPlayer

## A long track (the night's insects, the day's ambience, the wind and the rain, the camp's music)
## played by the browser on the web, not by Godot's mixer (the user 16. 11.: "it stutters like hell
## and the sound runs badly"). On the web the engine has one thread and mixes in it: every long
## frame was a gap in the sound. The browser plays these from an <audio> element on its own thread
## (`web/stream-audio.js`, `window.__ccStream`), streamed from the page's assets or from the
## browser's storage once UNDO.games has kept them; they are not in the game's pack at all
## (`tools/web/export.mjs` LONG_TRACKS).
##
## To everything else it is an AudioStreamPlayer: it plays a silent stream, so `play(at)`, `stop()`,
## `playing`, `get_playback_position()`, `volume_db`, `pitch_scale` (the music's carousel, the pitch
## going with the tempo), `bus`, tweens and the `finished` signal behave as before. Each frame it
## follows the silent player: started, stopped, moved (a jump in its position), and its loudness
## and low-pass worked out down its bus chain to Master the way the mixer would (volumes, mutes,
## low-pass filters; other effects are not followed). The page paused (tree paused) pauses it.
## Off the web (and for a track the page does not serve) `make` returns null and the caller makes
## its usual player.
##   var p := LONG_PLAYER.make("res://assets/sfx/cricketi.mp3", true)

const SILENCE_SEC := 1800.0
const SILENCE_RATE := 1000

static var _silence: AudioStreamWAV
static var _count := 0

## The res:// path of the track.
var track := ""
## Whether the track loops (a song plays once and ends the player).
var loops := false
var _id := ""
var _on := false
var _pos := 0.0
var _sent := ""
var _check := 0.0


## Does the page serve `res_path` as a long track? (Web only.)
static func available(res_path: String) -> bool:
	if not OS.has_feature("web") or res_path == "":
		return false
	return bool(JavaScriptBridge.eval("!!(window.__ccStream && window.__ccStream.has(%s))" % JSON.stringify(res_path), true))


## A player for `res_path` played by the browser, or null where it is not (the caller makes its own).
static func make(res_path: String, loop: bool) -> AudioStreamPlayer:
	if not available(res_path):
		return null
	var p = load("res://scripts/audio/long_player.gd").new()
	p.track = res_path
	p.loops = loop
	return p


static func _silent_stream() -> AudioStreamWAV:
	if _silence == null:
		_silence = AudioStreamWAV.new()
		_silence.format = AudioStreamWAV.FORMAT_8_BITS
		_silence.mix_rate = SILENCE_RATE
		_silence.stereo = false
		var data := PackedByteArray()
		data.resize(int(SILENCE_SEC * SILENCE_RATE))
		data.fill(0)
		_silence.data = data
		_silence.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_silence.loop_end = data.size()
	return _silence


func _init() -> void:
	_count += 1
	_id = "lp%d" % _count
	stream = _silent_stream()


func _exit_tree() -> void:
	if _on:
		_js("stop('%s')" % _id)
		_on = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and _on:
		_js("pause('%s', true)" % _id)
	elif what == NOTIFICATION_UNPAUSED and _on:
		_js("pause('%s', false)" % _id)


func _process(delta: float) -> void:
	var now := playing and not stream_paused
	var pos := get_playback_position() if now else 0.0
	if now and not _on:
		_js("play('%s', %s, %f, %s)" % [_id, JSON.stringify(track), pos, "true" if loops else "false"])
		_sent = ""
	elif not now and _on:
		_js("stop('%s')" % _id)
	elif now and absf(pos - (_pos + delta * pitch_scale)) > 0.5:
		# play(at) while already playing: the silent player moved, the track follows
		_js("seek('%s', %f)" % [_id, pos])
	_on = now
	_pos = pos
	if not now:
		return
	var chain := _chain()
	var state := "%.4f,%.0f,%.3f" % [db_to_linear(volume_db + chain.x) if chain.x > -79.0 else 0.0, chain.y, pitch_scale]
	if state != _sent:
		_sent = state
		_js("set('%s', %s)" % [_id, state])
	if not loops:
		_check += delta
		if _check >= 0.25:
			_check = 0.0
			if bool(JavaScriptBridge.eval("window.__ccStream.ended('%s')" % _id, true)):
				_on = false
				stop()
				finished.emit()


## (volume in dB down the bus chain to Master, the lowest low-pass cutoff on the way).
func _chain() -> Vector2:
	var db := 0.0
	var cutoff := 22050.0
	var i := AudioServer.get_bus_index(bus)
	var guard := 0
	while i >= 0 and guard < 16:
		guard += 1
		if AudioServer.is_bus_mute(i):
			return Vector2(-80.0, cutoff)
		db += AudioServer.get_bus_volume_db(i)
		for e in AudioServer.get_bus_effect_count(i):
			if not AudioServer.is_bus_effect_enabled(i, e):
				continue
			var fx := AudioServer.get_bus_effect(i, e)
			if fx is AudioEffectLowPassFilter:
				cutoff = minf(cutoff, (fx as AudioEffectLowPassFilter).cutoff_hz)
			elif fx is AudioEffectAmplify:
				db += (fx as AudioEffectAmplify).volume_db
		if i == 0:
			break
		i = AudioServer.get_bus_index(AudioServer.get_bus_send(i))
	return Vector2(db, cutoff)


func _js(call: String) -> void:
	JavaScriptBridge.eval("window.__ccStream && window.__ccStream.%s" % call, true)
