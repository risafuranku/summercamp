extends Node

## The camp's PA (Richard 24. 11., docs/audio.md "Rozhodnutí 24. 11.: amplióny s rádiem"):
## the poles built in Builder ("pa_pole", group "pa_poles", building_models._pa_pole) play
## what the reception's radio plays (building_interior.pa_feed: the same song at the same
## place in it), through an old village PA's horns (the "PA" bus: narrow, overdriven, the
## slap of it off the trees), in the background. The three poles nearest you sound, the rest
## wait. At night, now and then, the horns drift off by themselves to a station nobody tuned
## (static, a voice, a music box), on every machine at the same minute (the night's draw is
## seeded by its date), and back: only sound, nothing happens to anybody.
##
## The guests' side (fun near a pole, the light sleepers after ten) is guest_life's
## (core/systems/pa_rules.gd), told by GuestManager.set_camp_pa_on when the set goes on or
## off. The megaphone comes out of the horns too (coop/voice.gd: `nearest_horn`).
## main makes it and ticks it.

const INSTANCE := preload("res://scripts/instance/instance.gd")
const PA := preload("res://core/systems/pa_rules.gd")
const RADIO_DREAD := preload("res://scripts/radio/radio_dread.gd")
const BUS := "PA"
## Where the horns are on the pole (its picture is 7.5 m tall, the horns near the top).
const HORN_Y := 6.7
## The horns' loudness: at the foot of a pole the radio is there but under your thoughts.
const BASE_DB := -10.0
const UNIT := 7.0
const SILENT_DB := -80.0
const FADE_DB_PER_SEC := 30.0
## The poles that sound at once (the nearest to you): every horn decodes its own song.
const NEAREST := 3
## Further off than the drift's carry nothing is played.
const DRIFT_FROM_MIN := 23 * 60
const DRIFT_TO_MIN := 28 * 60
const DRIFTS_A_NIGHT := Vector2i(2, 4)
const STATIC := "res://assets/sfx/radio/nightnoise.mp3"
## What the horns drift onto: a voice counting, a music box, a lullaby, the warden's own
## terror song, the water's eerie one, the night's motif (all the camp's own, heard elsewhere
## from the reception's set when the night goes wrong).
const DRIFTS := [
	"res://assets/sfx/radio/night_pocitanihostu.mp3",
	"res://assets/sfx/uncanny/station_intro.mp3",
	"res://assets/sfx/radio/night_hajejdadej.mp3",
	"res://assets/sfx/radio/teror_spravce.mp3",
	"res://assets/sfx/radio/vodadoma_eerie.mp3",
	"res://assets/sfx/radio/night_motif.mp3",
]
const DRIFT_SEC := Vector2(7.0, 13.0)
const DRIFT_DB := -8.0
const STATIC_DB := -14.0

var main: Node

## Per pole (instance id): {pole, radio, drift, noise} (AudioStreamPlayer3D each).
var _horns: Dictionary = {}
var _on_air := false
var _told := false
var _poll := 0.0
var _poles: Array = []
## The night's drifts: the night's date, [[minute, path, offset 0-1, seconds]], the ones done.
var _night := -1
var _plan: Array = []
var _done: Dictionary = {}
## A drift playing now: seconds left of it, its length, its path.
var _drift_left := 0.0
var _drift_len := 0.0
var _drift_path := ""
var _drift_at := 0.0


func _ready() -> void:
	_ensure_bus()
	for p in [STATIC] + DRIFTS:
		if ResourceLoader.exists(p):
			ResourceLoader.load_threaded_request(p)


## The PA bus: an old horn speaker's narrow band, its crunch, the slap off the forest, into
## the radio's songs (the music channel, the night's moods of the set).
func _ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS) >= 0:
		return
	var i := AudioServer.bus_count
	AudioServer.add_bus(i)
	AudioServer.set_bus_name(i, BUS)
	AudioServer.set_bus_send(i, RADIO_DREAD.MUSIC_BUS if AudioServer.get_bus_index(RADIO_DREAD.MUSIC_BUS) >= 0 else "Master")
	var hp := AudioEffectHighPassFilter.new()
	hp.cutoff_hz = 480.0
	AudioServer.add_bus_effect(i, hp)
	var crunch := AudioEffectDistortion.new()
	crunch.mode = AudioEffectDistortion.MODE_OVERDRIVE
	crunch.drive = 0.42
	crunch.pre_gain = 4.0
	crunch.post_gain = -7.0
	crunch.keep_hf_hz = 5000.0
	AudioServer.add_bus_effect(i, crunch)
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 3300.0
	AudioServer.add_bus_effect(i, lp)
	var slap := AudioEffectDelay.new()
	slap.dry = 1.0
	slap.tap1_active = true
	slap.tap1_delay_ms = 190.0
	slap.tap1_level_db = -11.0
	slap.tap2_active = true
	slap.tap2_delay_ms = 410.0
	slap.tap2_level_db = -19.0
	slap.feedback_active = false
	AudioServer.add_bus_effect(i, slap)


## The reception's set going out now (on, and the camp's power with it).
func on_air() -> bool:
	return _on_air


## The horn nearest to `at` (a pole of this camp's, its horns' height), or Vector3.INF.
func nearest_horn(at: Vector3) -> Vector3:
	var best := Vector3.INF
	var bd := INF
	for p in _poles:
		if not is_instance_valid(p):
			continue
		var h: Vector3 = (p as Node3D).global_position + Vector3(0, HORN_Y, 0)
		var d := h.distance_squared_to(at)
		if d < bd:
			bd = d
			best = h
	return best


## The horns of every pole of this camp (coop/voice.gd: the guests near them hear the
## megaphone too).
func horns() -> Array:
	var out: Array = []
	for p in _poles:
		if is_instance_valid(p):
			out.append((p as Node3D).global_position + Vector3(0, HORN_Y, 0))
	return out


func tick(delta: float) -> void:
	# Not on the title's camp behind the menu.
	if main == null or main.get("_gameplay_started") != true or main.get("_menu_mode") == true:
		if not _horns.is_empty():
			_clear()
		return
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.5
		_poles = _camp_poles()
	var feed := _feed()
	var on := bool(feed.get("on", false)) and not _poles.is_empty()
	if on != _on_air or not _told:
		_on_air = on
		_told = true
		var gm = INSTANCE.guests(self) if main != null else null
		if gm != null and gm.has_method("set_camp_pa_on"):
			gm.set_camp_pa_on(bool(feed.get("on", false)))
	if _poles.is_empty():
		if not _horns.is_empty():
			_clear()
		return
	_tick_drift(delta, feed)
	var ear := _ear()
	var near := _poles.duplicate()
	near.sort_custom(func(a, b) -> bool: return (a as Node3D).global_position.distance_squared_to(ear) < (b as Node3D).global_position.distance_squared_to(ear))
	near = near.slice(0, NEAREST)
	for id in _horns.keys():
		var h: Dictionary = _horns[id]
		if not is_instance_valid(h["pole"]) or not near.has(h["pole"]):
			_free_horn(id)
	var src: AudioStreamPlayer = feed.get("player", null)
	var drifting := _drift_left > 0.0
	var radio_db := BASE_DB + float(feed.get("db", 0.0)) if bool(feed.get("on", false)) and not drifting else SILENT_DB
	for p in near:
		var h := _horn(p)
		_mirror(h["radio"], src, radio_db, delta)
		_drift_voice(h, delta)


## The camp's poles (this instance's world only: the split screen's two camps).
func _camp_poles() -> Array:
	var out: Array = []
	var world = main.get("_world_3d") if main != null else null
	for n in get_tree().get_nodes_in_group("pa_poles"):
		if n is Node3D and (n as Node3D).is_inside_tree() and (world == null or (world as Node).is_ancestor_of(n)):
			out.append(n)
	return out


func _feed() -> Dictionary:
	var im = main.get("_interior_manager") if main != null else null
	var bi = im.get("_building_interior") if im != null else null
	if bi != null and is_instance_valid(bi) and bi.has_method("pa_feed"):
		return bi.call("pa_feed")
	return {}


## Where you hear from: the camp's eye.
func _ear() -> Vector3:
	var p = main.get("_player") if main != null else null
	if p is Node3D and is_instance_valid(p):
		return (p as Node3D).global_position
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	return cam.global_position if cam != null else Vector3.ZERO


func _horn(pole: Node3D) -> Dictionary:
	var id := pole.get_instance_id()
	if _horns.has(id):
		return _horns[id]
	var h := {"pole": pole, "radio": _player(pole, "PaRadio"), "drift": _player(pole, "PaDrift"), "noise": _player(pole, "PaNoise")}
	_horns[id] = h
	return h


func _player(pole: Node3D, nm: String) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = nm
	p.bus = BUS
	p.unit_size = UNIT
	p.max_distance = PA.RANGE_M + 20.0
	p.volume_db = SILENT_DB
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	p.position = Vector3(0, HORN_Y, 0)
	pole.add_child(p)
	return p


## The horn plays the set's song where the set is in it (as building_interior's own outdoor
## copy does), its loudness eased.
func _mirror(p: AudioStreamPlayer3D, src: AudioStreamPlayer, db: float, delta: float) -> void:
	p.volume_db = move_toward(p.volume_db, db, FADE_DB_PER_SEC * delta)
	if src == null or not is_instance_valid(src) or not src.playing or src.stream == null or p.volume_db <= SILENT_DB + 1.0:
		if p.playing and p.volume_db <= SILENT_DB + 1.0:
			p.stop()
		return
	p.pitch_scale = src.pitch_scale
	var at := src.get_playback_position()
	if p.stream != src.stream or not p.playing:
		p.stream = src.stream
		p.play(at)
	elif not (src.stream is AudioStreamPlaylist) and absf(p.get_playback_position() - at) > 0.25:
		p.seek(at)


func _free_horn(id) -> void:
	var h: Dictionary = _horns[id]
	for k in ["radio", "drift", "noise"]:
		if is_instance_valid(h[k]):
			(h[k] as Node).queue_free()
	_horns.erase(id)


func _clear() -> void:
	for id in _horns.keys():
		_free_horn(id)


# ── the night's drifts ───────────────────────────────────────────────────────

## The minute of the night (from noon to noon: 23:00 is 1380, 2:00 is 1560) and its date.
func _night_clock() -> Array:
	var gm = INSTANCE.guests(self) if main != null else null
	if gm == null:
		return [-1, 0]
	var day := maxi(1, int(gm.get("_last_known_day")))
	var m := int(gm.get("_last_known_hour")) * 60 + int(gm.get("_last_known_minute"))
	if m < 12 * 60:
		return [day - 1, m + 1440]
	return [day, m]


## The night's draw: the same on every machine (seeded by its date).
func _plan_night(night: int) -> void:
	_night = night
	_done.clear()
	_plan.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("pa_drift:%d" % night)
	var n := rng.randi_range(DRIFTS_A_NIGHT.x, DRIFTS_A_NIGHT.y)
	for i in n:
		_plan.append([rng.randi_range(DRIFT_FROM_MIN, DRIFT_TO_MIN - 10), str(DRIFTS[rng.randi_range(0, DRIFTS.size() - 1)]),
			rng.randf(), rng.randf_range(DRIFT_SEC.x, DRIFT_SEC.y)])


func _tick_drift(delta: float, feed: Dictionary) -> void:
	if _drift_left > 0.0:
		_drift_left = maxf(0.0, _drift_left - delta)
		return
	var nc := _night_clock()
	if int(nc[0]) < 0:
		return
	if int(nc[0]) != _night:
		_plan_night(int(nc[0]))
	var m := int(nc[1])
	# The camp's power is what the horns run on (the set may be off: they drift on their own).
	if feed.is_empty() or not _grid_on():
		return
	for i in _plan.size():
		var d: Array = _plan[i]
		# Only at its minute (a night slept through does not play them all at dawn).
		if _done.has(i) or m < int(d[0]) or m > int(d[0]) + 3:
			continue
		_done[i] = true
		var s = _stream(str(d[1]))
		if s == null:
			continue
		_drift_path = str(d[1])
		_drift_len = float(d[3])
		_drift_left = _drift_len
		var length: float = (s as AudioStream).get_length()
		_drift_at = float(d[2]) * maxf(0.0, length - _drift_len)
		return


func _grid_on() -> bool:
	var im = main.get("_interior_manager") if main != null else null
	var bi = im.get("_building_interior") if im != null else null
	return bi == null or bool(bi.get("_grid_power_available"))


func _stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var st := ResourceLoader.load_threaded_get_status(path)
	if st == ResourceLoader.THREAD_LOAD_LOADED:
		return ResourceLoader.load_threaded_get(path) as AudioStream
	if st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE and ResourceLoader.has_cached(path):
		return load(path) as AudioStream
	return null


## A drift on a horn: the voice from its place in the song, the static under it, both in
## and out with the static first and last.
func _drift_voice(h: Dictionary, delta: float) -> void:
	var drift: AudioStreamPlayer3D = h["drift"]
	var noise: AudioStreamPlayer3D = h["noise"]
	if _drift_left <= 0.0:
		for p in [drift, noise]:
			(p as AudioStreamPlayer3D).volume_db = move_toward((p as AudioStreamPlayer3D).volume_db, SILENT_DB, FADE_DB_PER_SEC * 2.0 * delta)
			if (p as AudioStreamPlayer3D).playing and (p as AudioStreamPlayer3D).volume_db <= SILENT_DB + 1.0:
				(p as AudioStreamPlayer3D).stop()
		return
	var into := _drift_len - _drift_left
	if not noise.playing:
		var ns := _stream(STATIC)
		if ns != null:
			noise.stream = ns
			noise.play(randf() * maxf(0.0, ns.get_length() - _drift_len))
	# The voice a second in, gone a second before the end; the static over the edges.
	var voice_k := clampf(minf(into - 1.0, _drift_left - 1.0), 0.0, 1.0)
	noise.volume_db = STATIC_DB - 6.0 * voice_k
	if into >= 1.0 and not drift.playing:
		var vs := _stream(_drift_path)
		if vs != null:
			drift.stream = vs
			drift.play(_drift_at)
	drift.volume_db = lerpf(SILENT_DB, DRIFT_DB, voice_k) if voice_k > 0.0 else SILENT_DB
