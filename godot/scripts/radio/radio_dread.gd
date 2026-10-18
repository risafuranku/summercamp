extends Node

## The reception radio knows how bad tonight is (DESIGN §2, "the radio").
##
## `dread` 0-1 comes from the NIGHT RISK lamps, the hour, what came tonight and how close
## it is. The worse it gets, the more of the night gets onto the frequency:
##   low      static creeping under the songs, the tape wobbling, a dropout too many;
##   raised   the song skips, the tape sags, another station bleeds through underneath;
##   high     the dial drifts off the song onto the OK 76 buzz, a bird or a dog or a knock
##            on the frequency, and between songs the transmitter reads its code words:
##            tonight's word names what is coming, then the guest count, plus one;
##   near     with something close, the programme drops to a dead carrier and a woman
##            reads one line, once a night.
## In the day the lamps only make the set a little sick: a skip, a sag, a ghost station.
##
## The song player stays building_interior's. This node owns the layers on top of it,
## the effects of the song bus, and tells the interior how to bend the song: its volume
## (`music_gain`), its pitch (`pitch_offset`, `wobble_scale`), its dropouts and skips.
## Sounds: res://assets/sfx/radio_dread/ (tools/gen_radio_dread.py).

const DIR := "res://assets/sfx/radio_dread/"
## The songs (and the interludes) play on their own bus, sent into the radio bus, so
## the set can be ruined without touching the static and the buzz on top.
const MUSIC_BUS := "RadioMusic"
const LAYER_BUS := "Radio"

## Tonight's code word, by enemy id (scripts/enemies/*_brain.gd get_enemy_id()).
const CODEWORDS := {
	"silent_man": "v_klobouk", "tourist": "v_turista", "girl": "v_holka", "whistler": "v_piskani",
	"child": "v_dite", "basket": "v_kosik", "stalker": "v_parohac",
}
const GENERAL_WORDS := ["v_jasna", "v_vera", "v_ponozky", "v_strasak"]
const NIGHT_CREATURES := ["s_nightjar", "s_owl", "s_dog", "s_crows", "s_bell", "s_frogs", "s_cuckoo"]
const NEAR_LINES := ["f_neotvirej", "f_vidime", "f_nedychejte"]
const TUNES := ["tune_a", "tune_b", "tune_c"]

## Presence: closer than NEAR_CLOSE is all the way near; farther than NEAR_FAR is nothing.
const NEAR_FAR := 24.0
const NEAR_CLOSE := 9.0
const DREAD_RISE_PER_SEC := 0.02
const DREAD_FALL_PER_SEC := 0.01
## The first night is quiet (main.QUIET_NIGHTS): the radio only frets.
const QUIET_NIGHT_CAP := 0.15
## Between two interludes at least this long, so the songs are still the station.
const INTERLUDE_COOLDOWN_SEC := 170.0

const LOWPASS_CLEAN_HZ := 4200.0
const LOWPASS_RUINED_HZ := 1500.0
const LOWPASS_DRIFT_HZ := 850.0

enum Ev { NONE, STUTTER, SAG, GHOST, DRIFT, CREATURE }

var dread: float = 0.0
## Linear gain the interior multiplies into the song (1 = untouched).
var music_gain: float = 1.0
## Added to the song's pitch_scale (tape sag); `wobble_scale` multiplies its wow/flutter.
var pitch_offset: float = 0.0
var wobble_scale: float = 1.0
## Debug: >= 0 pins dread (radio_dread_check, the shot driver, the demo).
var debug_override: float = -1.0
## The night director's nudge: added to the target for a while (it heard something).
var _nudge := 0.0
var _nudge_left := 0.0


func nudge(amount: float, seconds: float) -> void:
	_nudge = maxf(_nudge, amount)
	_nudge_left = maxf(_nudge_left, seconds)

var _rng := RandomNumberGenerator.new()
var _streams: Dictionary = {}
var _silence: Dictionary = {}
var _music: AudioStreamPlayer
var _tracks: Array = []
var _layers: Dictionary = {}
var _building: Node3D
var _power: float = 1.0
var _snapped: bool = false
var _near: float = 0.0
var _ctx: Dictionary = {}

var _event: int = Ev.NONE
var _event_t: float = 0.0
var _event_len: float = 0.0
var _event_step: float = 0.0
var _event_count: int = 0
var _event_value: float = 0.0
var _next_event_in: float = 30.0
var _music_target: float = 1.0
var _pitch_target: float = 0.0

var _interlude: AudioStream
var _interlude_plan: Array = []
var _interlude_t: float = 0.0
var _interlude_cooldown: float = 60.0
var _hushed: bool = false
var _hush_t: float = 0.0
var _near_line_night: int = -99
var _leak_night: int = -99
var _phantom_night: int = -99
var _phantom_left: float = 0.0
var _off_seconds: float = 0.0

var _fx_lowpass: AudioEffectLowPassFilter
var _fx_crush: AudioEffectDistortion
var _fx_echo: AudioEffectDelay


class Layer:
	var p2: AudioStreamPlayer
	var p3: AudioStreamPlayer3D
	var bus: String
	var target: float = 0.0
	var gain: float = 0.0
	var rate: float = 1.5
	var looped: bool = false
	var ignores_power: bool = false

	func playing() -> bool:
		return p2 != null and p2.playing


func _ready() -> void:
	_rng.randomize()
	ensure_music_bus()
	for id in ["static", "carrier", "buzz", "ghost", "voice", "fx"]:
		var l := Layer.new()
		l.bus = MUSIC_BUS if id == "ghost" else LAYER_BUS
		l.looped = id in ["static", "carrier", "buzz"]
		l.p2 = AudioStreamPlayer.new()
		l.p2.name = "Dread_" + id
		l.p2.bus = l.bus
		l.p2.volume_db = -80.0
		add_child(l.p2)
		_layers[id] = l
	(_layers["static"] as Layer).rate = 0.4
	(_layers["carrier"] as Layer).rate = 0.8
	(_layers["buzz"] as Layer).rate = 2.5
	(_layers["voice"] as Layer).rate = 6.0
	(_layers["fx"] as Layer).rate = 8.0
	(_layers["ghost"] as Layer).rate = 0.25


## The song bus: low pass (muffling), lo-fi distortion (bit depth), a ghost echo.
static func ensure_music_bus() -> void:
	var idx := AudioServer.get_bus_index(MUSIC_BUS)
	if idx == -1:
		idx = AudioServer.get_bus_count()
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, MUSIC_BUS)
	AudioServer.set_bus_send(idx, LAYER_BUS if AudioServer.get_bus_index(LAYER_BUS) != -1 else "Master")
	var has := {}
	for i in AudioServer.get_bus_effect_count(idx):
		has[AudioServer.get_bus_effect(idx, i).get_class()] = true
	if not has.has("AudioEffectLowPassFilter"):
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = LOWPASS_CLEAN_HZ
		lp.resonance = 0.6
		AudioServer.add_bus_effect(idx, lp)
	if not has.has("AudioEffectDistortion"):
		var crush := AudioEffectDistortion.new()
		crush.mode = AudioEffectDistortion.MODE_LOFI
		crush.drive = 0.0
		crush.keep_hf_hz = 16000.0
		AudioServer.add_bus_effect(idx, crush)
	if not has.has("AudioEffectDelay"):
		var echo := AudioEffectDelay.new()
		echo.dry = 1.0
		echo.tap1_active = true
		echo.tap1_delay_ms = 340.0
		echo.tap1_level_db = -60.0
		echo.tap2_active = false
		echo.feedback_active = true
		echo.feedback_delay_ms = 340.0
		echo.feedback_level_db = -60.0
		echo.feedback_lowpass = 1800.0
		AudioServer.add_bus_effect(idx, echo)


func _bind_bus_effects() -> void:
	var idx := AudioServer.get_bus_index(MUSIC_BUS)
	if idx == -1:
		return
	for i in AudioServer.get_bus_effect_count(idx):
		var fx := AudioServer.get_bus_effect(idx, i)
		if fx is AudioEffectLowPassFilter:
			_fx_lowpass = fx
		elif fx is AudioEffectDistortion:
			_fx_crush = fx
		elif fx is AudioEffectDelay:
			_fx_echo = fx


func bind_music(player: AudioStreamPlayer) -> void:
	_music = player


func set_tracks(streams: Array) -> void:
	_tracks = streams.duplicate()


func get_near() -> float:
	return _near


func is_interlude_playing() -> bool:
	return _interlude != null and _music != null and _music.playing and _music.stream == _interlude


# ── the dread number ─────────────────────────────────────────────────────────────

## How much the hour lets the lamps through: a little by day, rising through the evening,
## worst at three in the morning.
static func hour_phase(hours: float) -> float:
	var h := fposmod(hours, 24.0)
	if h >= 20.0:
		return lerpf(0.75, 0.9, (h - 20.0) / 4.0)
	if h < 3.0:
		return lerpf(0.9, 1.0, h / 3.0)
	if h < 6.0:
		return lerpf(1.0, 0.5, (h - 3.0) / 3.0)
	if h >= 17.0:
		return lerpf(0.3, 0.75, (h - 17.0) / 3.0)
	return 0.3


## ctx: risk 0-1 (NIGHT RISK level / 4), hours, night (bool), day, tonight (enemy ids
## running tonight), near 0-1.
static func compute_target(ctx: Dictionary) -> float:
	var risk := clampf(float(ctx.get("risk", 0.0)), 0.0, 1.0)
	var night := bool(ctx.get("night", false))
	var tonight: Array = ctx.get("tonight", [])
	var t := risk * hour_phase(float(ctx.get("hours", 12.0))) * 0.85
	if night:
		t += 0.06 + minf(0.3, 0.12 * tonight.size())
	t += float(ctx.get("near", 0.0)) * 0.35
	if int(ctx.get("day", 2)) <= 1:
		t = minf(t, QUIET_NIGHT_CAP)
	return clampf(t, 0.0, 1.0)


static func near_from_distance(d: float) -> float:
	if not is_finite(d):
		return 0.0
	return clampf((NEAR_FAR - d) / (NEAR_FAR - NEAR_CLOSE), 0.0, 1.0)


## Every frame from building_interior._update_radio_mix. inside_db/outside_db: the song's
## level in the office and at the reception from outside, before the radio's character;
## power_on: the set's switch; building: the reception (the outdoor layers sit there).
func update(delta: float, ctx: Dictionary, inside_db: float, outside_db: float, power_on: bool, building: Node3D) -> void:
	var dt := maxf(delta, 0.0)
	_ctx = ctx
	_building = building
	if _fx_lowpass == null:
		_bind_bus_effects()
	var near_target := near_from_distance(float(ctx.get("nearest", INF))) if bool(ctx.get("night", false)) else 0.0
	_near = move_toward(_near, near_target, (1.5 if near_target > _near else 0.3) * dt)
	ctx["near"] = _near
	var target := compute_target(ctx)
	if _nudge_left > 0.0:
		_nudge_left -= dt
		target = clampf(target + _nudge, 0.0, 1.0)
		if _nudge_left <= 0.0:
			_nudge = 0.0
	if debug_override >= 0.0:
		target = debug_override
		dread = target
	elif not _snapped:
		_snapped = true
		dread = target
	else:
		dread = move_toward(dread, target, (DREAD_RISE_PER_SEC if target > dread else DREAD_FALL_PER_SEC) * dt)

	_music_target = 1.0
	_pitch_target = 0.0
	_set_base_layers()
	_update_phantom(dt, power_on)
	if is_interlude_playing():
		_update_interlude(dt)
	elif _update_hush(dt):
		pass
	else:
		_update_events(dt)
	_interlude_cooldown = maxf(0.0, _interlude_cooldown - dt)

	music_gain = move_toward(music_gain, _music_target, 2.2 * dt)
	var pitch_rate := 0.12 if _pitch_target < pitch_offset else 1.2
	pitch_offset = move_toward(pitch_offset, _pitch_target, pitch_rate * dt)
	wobble_scale = 1.0 + 3.0 * dread
	_power = move_toward(_power, 1.0 if power_on else 0.0, 2.0 * dt)
	_apply_bus(dt)
	_mix_layers(dt, inside_db, outside_db)


## How often and how deep the interior's dropouts are (1 = as built).
func dropout_interval_scale() -> float:
	return lerpf(1.0, 0.22, dread)


func dropout_depth_scale() -> float:
	return lerpf(1.0, 3.2, dread)


# ── layers ───────────────────────────────────────────────────────────────────────

func _set_base_layers() -> void:
	(_layers["static"] as Layer).target = 0.012 + 0.2 * pow(dread, 1.3)
	(_layers["carrier"] as Layer).target = 0.0
	(_layers["buzz"] as Layer).target = 0.0


func _mix_layers(dt: float, inside_db: float, outside_db: float) -> void:
	for id in _layers:
		var l: Layer = _layers[id]
		if l.looped:
			if l.target > 0.001 and not l.playing():
				_start(l, _clip(id if id != "buzz" else "buzzer"), true)
			elif l.target <= 0.001 and l.gain <= 0.002 and l.playing():
				_stop(l)
		l.gain = move_toward(l.gain, l.target if l.playing() else 0.0, l.rate * dt)
		var power := 1.0 if (l.ignores_power and _phantom_left > 0.0) else _power
		var g := maxf(l.gain * power, 0.00001)
		l.p2.volume_db = inside_db + linear_to_db(g)
		_sync_outdoor(l, outside_db + linear_to_db(g))


func _sync_outdoor(l: Layer, db: float) -> void:
	if _building == null or not is_instance_valid(_building) or not _building.is_inside_tree():
		if l.p3 != null and is_instance_valid(l.p3) and l.p3.playing:
			l.p3.stop()
		return
	if l.p3 == null or not is_instance_valid(l.p3):
		l.p3 = AudioStreamPlayer3D.new()
		l.p3.name = l.p2.name + "_Outdoor"
		l.p3.bus = l.bus
		l.p3.unit_size = 4.0
		l.p3.max_distance = 75.0
		l.p3.attenuation_filter_cutoff_hz = 2600.0
		l.p3.attenuation_filter_db = -14.0
		l.p3.volume_db = -80.0
		_building.add_child(l.p3)
	elif l.p3.get_parent() != _building:
		l.p3.reparent(_building, false)
	l.p3.position = Vector3(0.0, 1.4, 0.0)
	l.p3.volume_db = db
	l.p3.pitch_scale = l.p2.pitch_scale
	if not l.p2.playing:
		if l.p3.playing:
			l.p3.stop()
		return
	if l.p3.stream != l.p2.stream or not l.p3.playing:
		l.p3.stream = l.p2.stream
		l.p3.play(l.p2.get_playback_position())


func _start(l: Layer, stream: AudioStream, from_anywhere: bool = false, pitch: float = 1.0) -> void:
	if stream == null:
		return
	l.p2.stream = stream
	l.p2.pitch_scale = pitch
	var at := 0.0
	if from_anywhere:
		at = _rng.randf_range(0.0, maxf(0.0, stream.get_length() - 0.5))
	l.p2.play(at)


func _stop(l: Layer) -> void:
	l.p2.stop()
	l.gain = 0.0
	if l.p3 != null and is_instance_valid(l.p3):
		l.p3.stop()


func _one_shot(layer_id: String, clip: String, gain: float) -> void:
	var l: Layer = _layers[layer_id]
	_start(l, _clip(clip))
	l.target = gain
	l.gain = gain


func _clip(id: String) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	var path := DIR + id + ".wav"
	var s: AudioStream = load(path) as AudioStream if ResourceLoader.exists(path) else null
	if s is AudioStreamWAV and id in ["static", "carrier", "buzzer"]:
		var w := (s as AudioStreamWAV).duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
		s = w
	_streams[id] = s
	return s


func _gap(seconds: float) -> AudioStream:
	var key := int(round(seconds * 10.0))
	if _silence.has(key):
		return _silence[key]
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 22050
	var bytes := PackedByteArray()
	bytes.resize(int(key / 10.0 * 22050.0) * 2)
	bytes.fill(0)
	w.data = bytes
	_silence[key] = w
	return w


# ── the song bus ─────────────────────────────────────────────────────────────────

func _apply_bus(_dt: float) -> void:
	if _fx_lowpass == null:
		return
	var cutoff := lerpf(LOWPASS_CLEAN_HZ, LOWPASS_RUINED_HZ, pow(dread, 1.2))
	if _event == Ev.DRIFT or _hushed:
		cutoff = LOWPASS_DRIFT_HZ
	_fx_lowpass.cutoff_hz = lerpf(_fx_lowpass.cutoff_hz, cutoff, 0.08)
	if _fx_crush != null:
		_fx_crush.drive = 0.42 * pow(dread, 1.6)
	if _fx_echo != null:
		var echo_db := lerpf(-60.0, -15.0, clampf((dread - 0.45) / 0.55, 0.0, 1.0))
		_fx_echo.tap1_level_db = echo_db
		_fx_echo.feedback_level_db = echo_db - 6.0


# ── what happens to the song ─────────────────────────────────────────────────────

func _update_events(dt: float) -> void:
	if _event == Ev.NONE:
		_next_event_in -= dt
		if _next_event_in <= 0.0:
			_next_event_in = lerpf(110.0, 16.0, dread) * _rng.randf_range(0.6, 1.4)
			_begin_event(_pick_event())
		return
	_event_t += dt
	match _event:
		Ev.STUTTER:
			if _music == null or not _music.playing or _music.stream is AudioStreamPlaylist:
				_end_event()
				return
			_event_step -= dt
			if _event_step <= 0.0:
				_event_step = _event_value + 0.02
				_music.seek(maxf(0.0, _music.get_playback_position() - _event_value))
				_event_count -= 1
			if _event_count <= 0:
				_end_event()
		Ev.SAG:
			if _event_t < _event_len:
				_pitch_target = -_event_value
			else:
				_end_event()
		Ev.GHOST:
			var g: Layer = _layers["ghost"]
			g.target = _event_value if _event_t < _event_len else 0.0
			if _event_t > _event_len + 4.0:
				_stop(g)
				_end_event()
		Ev.DRIFT:
			_music_target = 0.1
			var static_l: Layer = _layers["static"]
			static_l.target = maxf(static_l.target, 0.35)
			(_layers["buzz"] as Layer).target = 0.6 if _event_t > 1.2 and _event_t < _event_len - 1.0 else 0.0
			if _event_count == 1 and _event_t > _event_len * 0.45:
				_event_count = 0
				_drift_insert()
			if _event_t >= _event_len - 1.6 and _event_step > 0.0:
				_event_step = 0.0
				_one_shot("fx", TUNES[_rng.randi() % TUNES.size()], 0.7)
			if _event_t >= _event_len:
				_end_event()
		Ev.CREATURE:
			_music_target = 0.7
			if not (_layers["voice"] as Layer).playing():
				_end_event()


func _pick_event() -> int:
	if dread < 0.08:
		return Ev.NONE
	var night := bool(_ctx.get("night", false))
	var bag: Array = [[Ev.STUTTER, 1.0]]
	if dread > 0.2:
		bag.append([Ev.SAG, 1.0])
	if dread > 0.25 and _tracks.size() > 1:
		bag.append([Ev.GHOST, 1.2])
	if dread > 0.35 and night:
		bag.append([Ev.CREATURE, 0.8])
	if dread > 0.4 and night:
		bag.append([Ev.DRIFT, 1.5 * dread])
	var total := 0.0
	for e in bag:
		total += float(e[1])
	var r := _rng.randf() * total
	for e in bag:
		r -= float(e[1])
		if r <= 0.0:
			return int(e[0])
	return Ev.STUTTER


func _begin_event(ev: int) -> void:
	_event = ev
	_event_t = 0.0
	match ev:
		Ev.STUTTER:
			_event_count = _rng.randi_range(2, 3 + int(dread * 4.0))
			_event_value = _rng.randf_range(0.16, 0.3)
			_event_step = 0.0
		Ev.SAG:
			_event_value = _rng.randf_range(0.05, 0.08 + 0.1 * dread)
			_event_len = _rng.randf_range(1.6, 2.6 + 2.0 * dread)
		Ev.GHOST:
			var g: Layer = _layers["ghost"]
			var pick: AudioStream = _tracks[_rng.randi() % _tracks.size()]
			if _music != null and pick == _music.stream and _tracks.size() > 1:
				pick = _tracks[(_tracks.find(pick) + 1) % _tracks.size()]
			_start(g, pick, true, _rng.randf_range(0.72, 0.88))
			_event_value = lerpf(0.12, 0.32, dread)
			_event_len = _rng.randf_range(6.0, 12.0 + 10.0 * dread)
		Ev.DRIFT:
			_event_len = _rng.randf_range(6.0, 10.0 + 10.0 * dread)
			_event_count = 1 if _rng.randf() < 0.75 else 0
			_event_step = 1.0
			_one_shot("fx", TUNES[_rng.randi() % TUNES.size()], 0.7)
		Ev.CREATURE:
			_one_shot("voice", _pick_creature(), _rng.randf_range(0.35, 0.6))
		Ev.NONE:
			pass


func _end_event() -> void:
	_event = Ev.NONE


## Halfway through a drift: something on the frequency. Late and bad: a code word.
func _drift_insert() -> void:
	if dread > 0.65 and _rng.randf() < 0.5:
		_one_shot("voice", _pick_codeword(), 0.75)
	else:
		_one_shot("voice", _pick_creature(), 0.55)


func _pick_creature() -> String:
	var pool: Array = NIGHT_CREATURES.duplicate()
	var tonight: Array = _ctx.get("tonight", [])
	if "whistler" in tonight:
		pool.append_array(["s_whistle", "s_whistle"])
	if "child" in tonight:
		pool.append_array(["s_kids", "s_kids"])
	if dread > 0.7:
		pool.append_array(["s_knock", "s_breath"])
	return pool[_rng.randi() % pool.size()]


func _pick_codeword() -> String:
	var tonight: Array = _ctx.get("tonight", [])
	for id in tonight:
		if CODEWORDS.has(id) and _rng.randf() < 0.7:
			return CODEWORDS[id]
	return GENERAL_WORDS[_rng.randi() % GENERAL_WORDS.size()]


# ── something close ──────────────────────────────────────────────────────────────

func _update_hush(dt: float) -> bool:
	if not _hushed and _near > 0.55:
		_hushed = true
		_hush_t = 0.0
		_end_event()
		_stop(_layers["ghost"])
	elif _hushed and _near < 0.25:
		_hushed = false
		_one_shot("fx", TUNES[_rng.randi() % TUNES.size()], 0.6)
	if not _hushed:
		return false
	_hush_t += dt
	_music_target = 0.0
	(_layers["static"] as Layer).target = 0.06
	(_layers["carrier"] as Layer).target = 0.55
	var night_id := _night_id()
	if _hush_t > 3.5 and _near_line_night != night_id:
		_near_line_night = night_id
		_one_shot("voice", NEAR_LINES[_rng.randi() % NEAR_LINES.size()], 0.8)
	return true


func _night_id() -> int:
	var day := int(_ctx.get("day", 1))
	return day if float(_ctx.get("hours", 0.0)) >= 12.0 else day - 1


## Switched off, on a very bad night, the set still murmurs once: the buzz, and goodnight.
func _update_phantom(dt: float, power_on: bool) -> void:
	_off_seconds = 0.0 if power_on else _off_seconds + dt
	if _phantom_left > 0.0:
		_phantom_left -= dt
		(_layers["buzz"] as Layer).target = 0.3 if _phantom_left > 3.0 else 0.0
		if _phantom_left <= 3.0 and _phantom_left + dt > 3.0:
			_one_shot("voice", "f_dobrou", 0.5)
		if _phantom_left <= 0.0:
			for id in ["buzz", "voice"]:
				(_layers[id] as Layer).ignores_power = false
		return
	if power_on or not bool(_ctx.get("night", false)) or dread < 0.8 or _off_seconds < 25.0:
		return
	if _phantom_night == _night_id() or _rng.randf() > 0.02 * dt:
		return
	_phantom_night = _night_id()
	_phantom_left = 9.0
	for id in ["buzz", "voice"]:
		(_layers[id] as Layer).ignores_power = true


# ── the transmitter between songs ────────────────────────────────────────────────

## building_interior asks before each song. Returns the broadcast to play in the song's
## place (an AudioStreamPlaylist on the song player), or null for the next song.
func take_interlude() -> AudioStream:
	if _interlude_cooldown > 0.0 or not bool(_ctx.get("night", false)) or int(_ctx.get("day", 1)) < 2:
		return null
	var chance := clampf((dread - 0.45) * 1.4, 0.0, 0.75)
	if _rng.randf() >= chance:
		return null
	var built := build_interlude(_ctx, dread)
	_interlude = built.get("stream", null)
	_interlude_plan = built.get("plan", [])
	_interlude_desc = built.get("desc", [])
	_interlude_t = 0.0
	_interlude_cooldown = INTERLUDE_COOLDOWN_SEC * lerpf(1.4, 0.7, dread)
	return _interlude


## The broadcast as one playlist plus its plan ([start, end, kind] in seconds; kind buzz:
## the buzz alone, air: the open carrier, voice: someone reading, tune: the dial).
func build_interlude(ctx: Dictionary, level: float) -> Dictionary:
	var seq: Array = []
	var tune: String = TUNES[_rng.randi() % TUNES.size()]
	seq.append([_clip(tune), "tune"])
	seq.append([_gap(_rng.randf_range(3.0, 4.0 + 5.0 * level)), "buzz"])
	seq.append([_clip("v_callsign"), "voice"])
	seq.append([_gap(0.9), "air"])
	var hours := float(ctx.get("hours", 0.0))
	var words: Array = []
	if hours >= 2.5 and hours < 4.0:
		words = ["v_hlidac", "v_datum"]
	else:
		var saved := _ctx
		_ctx = ctx
		words.append(_pick_codeword())
		if level > 0.75 and _rng.randf() < 0.5:
			var second := _pick_codeword()
			if second != words[0]:
				words.append(second)
		_ctx = saved
	for w in words:
		seq.append([_clip(w), "voice"])
		seq.append([_gap(0.8), "air"])
	_append_numbers(seq, int(ctx.get("guests", 0)))
	var night_id := _night_id()
	if level > 0.6 and _rng.randf() < 0.35:
		seq.append([_clip("f_count"), "voice"])
		seq.append([_clip("v_zrusit"), "voice"])
		seq.append([_gap(0.7), "air"])
		seq.append([_clip("f_count2"), "voice"])
		seq.append([_clip("v_zrusit"), "voice"])
		seq.append([_gap(0.9), "air"])
	if level > 0.75 and _leak_night != night_id and _rng.randf() < 0.45:
		# Someone left the microphone open. It ends when they notice.
		_leak_night = night_id
		for item in [["l_a1", 0.5], ["s_chair", 0.3], ["l_b1", 0.6], ["l_a2", 0.2], ["s_cough", 0.4], ["l_b2", 0.0]]:
			seq.append([_clip(item[0]), "voice"])
			if float(item[1]) > 0.0:
				seq.append([_gap(item[1]), "air"])
		seq.append([_gap(1.6), "air"])
	else:
		seq.append([_clip("v_konec"), "voice"])
		seq.append([_gap(_rng.randf_range(2.0, 4.0)), "buzz"])
	seq.append([_clip(TUNES[_rng.randi() % TUNES.size()]), "tune"])
	var built := _assemble(seq)
	built["desc"] = _describe(seq)
	return built


## The pieces of a broadcast as one playlist and its plan.
func _assemble(seq: Array) -> Dictionary:
	var list: Array[AudioStream] = []
	var plan: Array = []
	var t := 0.0
	for item in seq:
		var s: AudioStream = item[0]
		if s == null or list.size() >= AudioStreamPlaylist.MAX_STREAMS:
			continue
		list.append(s)
		var len_s := s.get_length()
		plan.append([t, t + len_s, item[1]])
		t += len_s
	var playlist := AudioStreamPlaylist.new()
	playlist.loop = false
	playlist.fade_time = 0.0
	playlist.stream_count = list.size()
	for i in list.size():
		playlist.set_list_stream(i, list[i])
	return {"stream": playlist, "plan": plan, "length": t}


# -- co-op: the host's broadcast on the other machine's set too ---------------------

## The last broadcast as its pieces, for the other machine: [["c", clip id] or ["g",
## seconds], kind] (building_interior.coop_radio_state).
var _interlude_desc: Array = []


func interlude_desc() -> Array:
	return _interlude_desc


func _describe(seq: Array) -> Array:
	var out: Array = []
	for item in seq:
		var s: AudioStream = item[0]
		if s == null:
			continue
		var id = _streams.find_key(s)
		if id != null:
			out.append(["c", str(id), str(item[1])])
			continue
		var gap = _silence.find_key(s)
		if gap != null:
			out.append(["g", float(gap) / 10.0, str(item[1])])
	return out


## The other machine: the host's broadcast, built here from its pieces and taken as the
## one on air (its plan drives the buzz and the carrier as on the host's).
func coop_play_interlude(desc: Array) -> AudioStream:
	var seq: Array = []
	for d in desc:
		if d is Array and d.size() >= 3:
			seq.append([_clip(str(d[1])) if str(d[0]) == "c" else _gap(float(d[1])), str(d[2])])
	var built := _assemble(seq)
	_interlude = built.get("stream", null)
	_interlude_plan = built.get("plan", [])
	_interlude_desc = desc
	_interlude_t = 0.0
	return _interlude


## "Hostů N. Hostů N. Hostů N+1. Opakuji. Hostů N+1." Like the station's pips: one
## more than there are. Past twenty, a five-figure group read twice.
func _append_numbers(seq: Array, guests: int) -> void:
	if guests + 1 <= 20:
		for n in [guests, guests, guests + 1]:
			seq.append([_clip("v_hostu"), "voice"])
			seq.append([_clip("v_n%d" % n), "voice"])
			seq.append([_gap(0.55), "air"])
		seq.append([_clip("v_opakuji"), "voice"])
		seq.append([_gap(0.3), "air"])
		seq.append([_clip("v_hostu"), "voice"])
		seq.append([_clip("v_n%d" % (guests + 1)), "voice"])
		seq.append([_gap(0.9), "air"])
		return
	var group: Array = []
	for i in 5:
		group.append(_rng.randi_range(0, 9))
	for _r in 2:
		for d in group:
			seq.append([_clip("v_n%d" % d), "voice"])
			seq.append([_gap(0.25), "air"])
		seq.append([_gap(0.8), "air"])


func _update_interlude(dt: float) -> void:
	_interlude_t += dt * (_music.pitch_scale if _music != null else 1.0)
	var kind := "air"
	for p in _interlude_plan:
		if _interlude_t >= float(p[0]) and _interlude_t < float(p[1]):
			kind = str(p[2])
			break
	(_layers["buzz"] as Layer).target = 0.65 if kind == "buzz" else (0.2 if kind == "tune" else 0.0)
	(_layers["carrier"] as Layer).target = 0.5 if kind in ["air", "voice"] else 0.0
	(_layers["static"] as Layer).target = maxf((_layers["static"] as Layer).target, 0.14)
