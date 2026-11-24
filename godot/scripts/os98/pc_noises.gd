extends Node

## The office PC as a machine (Richard 24. 11., docs/pc.md "Stroj jako stroj", "jen zvuky,
## nesekat"): while it is on, its fan and its spinning disk hum under everything (a seamless
## loop, ElevenLabs `os98/pc_hum.ogg`), and now and then the disk ticks by itself as a busy
## Okna does in the background; a program opening makes it seek. Heard as the PC's other
## sounds are (os_shell.sound_db: from across the room or outside quieter, nothing from the menu
## or a PC that is off). It never hangs: only sound.
##
## os_shell makes it, ticks it (`tick`) and tells it when a program opens (`seek`).

const HUM := "res://assets/sfx/os98/pc_hum.ogg"
const SEEK := "res://assets/sfx/os98/seek.mp3"
const HUM_DB := -22.0
const SEEK_DB := -20.0
## Seconds between the disk's own ticks while nothing is asked of it.
const IDLE_SEEK := Vector2(18.0, 55.0)
const SILENT_DB := -80.0

var _hum: AudioStreamPlayer
var _seek_stream: AudioStream
var _next_seek := 20.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_hum = AudioStreamPlayer.new()
	_hum.name = "PcHum"
	_hum.volume_db = SILENT_DB
	if ResourceLoader.exists(HUM):
		_hum.stream = load(HUM)
	add_child(_hum)
	if ResourceLoader.exists(SEEK):
		_seek_stream = load(SEEK)


## Each frame: `db` is the PC's loudness where you are (os_shell.sound_db; -80 when it is off).
func tick(delta: float, db: float) -> void:
	var want := SILENT_DB if db <= -79.0 else HUM_DB + db
	_hum.volume_db = move_toward(_hum.volume_db, want, delta * 40.0)
	if _hum.volume_db > SILENT_DB + 1.0:
		if not _hum.playing and _hum.stream != null:
			_hum.play(_rng.randf() * 8.0)
	elif _hum.playing:
		_hum.stop()
	if db <= -79.0:
		return
	_next_seek -= delta
	if _next_seek <= 0.0:
		_next_seek = _rng.randf_range(IDLE_SEEK.x, IDLE_SEEK.y)
		_play_seek(db)


## The disk asked for something (a program opening).
func seek(db: float) -> void:
	if db > -79.0:
		_play_seek(db)
		_next_seek = maxf(_next_seek, 6.0)


func _play_seek(db: float) -> void:
	if _seek_stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = _seek_stream
	p.volume_db = SEEK_DB + db
	p.pitch_scale = _rng.randf_range(0.92, 1.08)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
