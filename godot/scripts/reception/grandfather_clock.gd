extends Node3D

## The grandfather clock in the warden's back room (playtest 13. 11.: "a big ticking
## grandfather clock, the kind that strikes its bell in the morning"): a longcase of dark
## veneer against the wall, its dial (camp/wall_clock.png) with hands at the camp's hour,
## the brass pendulum swinging in the dark of its case, a tock every second (tick and tock a
## little apart), the hour struck on its bell as it comes (not while the night is slept
## through: the hours fly by then) and the morning's hour as you get up.
## Boxes with their textures, as the room's other things (Grok's limit was spent on
## 13. 11.: its own picture can come later). Placed by back_room.gd at its foot, facing +X.

const K = preload("res://scripts/interior_kit.gd")
const SFX := "res://assets/sfx/backroom/"
## The pendulum: a swing to one side a second, this far.
const SWING_DEG := 6.5
const STRIKE_GAP := 2.3

var _hour_hand: Node3D
var _minute_hand: Node3D
var _pendulum: Node3D
var _tock: AudioStreamPlayer3D
var _gong: AudioStreamPlayer3D
var _t := 0.0
var _sec := -1
var _last_hour := -100.0
var _strikes_left := 0
var _strike_t := 0.0


func _ready() -> void:
	var wood := K.surface("veneer_dark", 0.6)
	var brass := K.surface("galvanized", 0.25, Color(0.95, 0.74, 0.34))
	var dark := K.surface("veneer_dark", 0.6, Color(0.12, 0.1, 0.09))
	# Its depth along x (its back to the wall at -x), its width along z.
	K.slab(self, Vector3(0.38, 0.26, 0.52), Vector3(0.0, 0.13, 0.0), wood, "Plinth")
	K.slab(self, Vector3(0.3, 1.2, 0.42), Vector3(-0.02, 0.86, 0.0), wood, "Case")
	K.slab(self, Vector3(0.36, 0.52, 0.5), Vector3(0.0, 1.72, 0.0), wood, "Hood")
	K.slab(self, Vector3(0.4, 0.07, 0.56), Vector3(0.0, 2.015, 0.0), wood, "Crown")
	K.slab(self, Vector3(0.02, 0.86, 0.28), Vector3(0.135, 0.92, 0.0), dark, "CaseWindow")
	var face := 0.181
	K.cutout(self, "wall_clock", Vector2(0.38, 0.38), Vector3(face, 1.53, 0.0), 90.0, false, "Dial")
	var ink := K.surface("veneer_dark", 0.2, Color(0.05, 0.04, 0.04))
	_hour_hand = _hand(Vector3(face + 0.006, 1.72, 0.0), 0.085, 0.014, ink)
	_minute_hand = _hand(Vector3(face + 0.01, 1.72, 0.0), 0.13, 0.01, ink)
	# The pendulum from its pivot under the hood, in front of the case's dark window.
	_pendulum = Node3D.new()
	_pendulum.name = "Pendulum"
	_pendulum.position = Vector3(0.152, 1.32, 0.0)
	add_child(_pendulum)
	K.slab(_pendulum, Vector3(0.008, 0.62, 0.014), Vector3(0.0, -0.31, 0.0), brass, "Rod")
	K.slab(_pendulum, Vector3(0.012, 0.12, 0.12), Vector3(0.0, -0.64, 0.0), brass, "Bob")
	_tock = _sound("gclock_tock.mp3", -15.0, 1.4)
	_gong = _sound("gclock_gong.mp3", -7.0, 2.2)


## A hand: a thin slab from the dial's centre outwards (up at 12), turned about x.
func _hand(at: Vector3, length: float, width: float, mat: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	add_child(pivot)
	K.slab(pivot, Vector3(0.004, length, width), Vector3(0.0, length * 0.45, 0.0), mat, "Hand")
	return pivot


func _sound(file: String, db: float, unit: float) -> AudioStreamPlayer3D:
	var a := AudioStreamPlayer3D.new()
	a.stream = load(SFX + file) if ResourceLoader.exists(SFX + file) else null
	a.volume_db = db
	a.unit_size = unit
	a.max_distance = 14.0
	a.position = Vector3(0.1, 1.4, 0.0)
	add_child(a)
	return a


## Every frame with the camp's hour (0-24).
func update(delta: float, hour: float) -> void:
	_t += delta
	_pendulum.rotation.x = deg_to_rad(SWING_DEG) * sin(_t * PI)
	var sec := int(floor(_t))
	if sec != _sec:
		_sec = sec
		if _tock.stream != null:
			_tock.pitch_scale = 1.0 if sec % 2 == 0 else 0.93
			_tock.play()
	var h12 := fmod(hour, 12.0)
	_hour_hand.rotation.x = -h12 / 12.0 * TAU
	_minute_hand.rotation.x = -fmod(hour, 1.0) * TAU
	# The hour struck as it comes; not when the clock went on by hours at once (asleep).
	var whole := floorf(hour)
	if _last_hour > -50.0 and whole != floorf(_last_hour) and absf(hour - _last_hour) < 0.25:
		strike(int(whole))
	_last_hour = hour
	if _strikes_left > 0:
		_strike_t -= delta
		if _strike_t <= 0.0:
			_strikes_left -= 1
			_strike_t = STRIKE_GAP
			if _gong.stream != null:
				_gong.play()


## The hour `h` (0-23) struck: as many as it is on the dial.
func strike(h: int) -> void:
	var n := h % 12
	_strikes_left = 12 if n == 0 else n
	_strike_t = 0.0
