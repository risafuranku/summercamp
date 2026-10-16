extends "res://scripts/closeup/closeup_view.gd"

## The office telephone, close up: a beige push-button set on the counter (Grok,
## assets/textury/closeup/phone.png). Lift the handset (click it), hear the dial tone,
## press the keys (or type the digits), wait while it rings. Who answers, and what it
## leads to, is scripts/closeup/phone_book.gd; the numbers are on the noticeboard.
## Put the handset back to hang up. The LCD shows the clock while the phone rests,
## the digits as you dial and the call's length while you talk.

const BOOK = preload("res://scripts/closeup/phone_book.gd")
const PIC := "res://assets/textury/closeup/phone.png"
const SFX := "res://assets/sfx/phone/"
const VOICE := "res://assets/sfx/phone/voice/"
const KEYS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"]
## Key centres in picture pixels (row by row; the deck is drawn in perspective).
const KEY_CENTRES := [
	Vector2(152, 96), Vector2(178, 96), Vector2(203, 94),
	Vector2(155.5, 120.5), Vector2(181.5, 117.5), Vector2(207, 114.5),
	Vector2(159, 142.5), Vector2(185, 140), Vector2(210.5, 136),
	Vector2(162.5, 165), Vector2(189, 162), Vector2(215, 158),
]
const KEY_HALF := Vector2(9.5, 7.5)
const LCD := Rect2(129, 40, 70, 17)
const REDIAL := Rect2(211, 38, 18, 15)
const HANDSET := Rect2(41, 32, 76, 168)
## The handset's outline on the picture (px), for lifting it off the cradle.
const HANDSET_OUTLINE := [
	Vector2(49, 40), Vector2(57, 33), Vector2(92, 32), Vector2(101, 40), Vector2(102, 84),
	Vector2(106, 132), Vector2(116, 146), Vector2(117, 192), Vector2(110, 201), Vector2(70, 201),
	Vector2(61, 191), Vector2(59, 148), Vector2(56, 96), Vector2(47, 82), Vector2(45, 50),
]
const RING_ON := 1.0
const RING_OFF := 1.7
const WAIT_AFTER_LAST_KEY := 1.1
const GIVE_UP_DIALLING := 5.0

enum { RESTING, DIAL_TONE, DIALLING, RINGING, TALKING, ENDED }

## Callable() -> Dictionary: the camp's situation for phone_book (hour, faults...).
var context_provider: Callable
## Callable(effect: String, number: String): what a call set going.
var on_effect: Callable

var _state := RESTING
var _number := ""
var _last := ""
var _since_key := 0.0
var _call: Dictionary = {}
var _rings_left := 0
var _ring_t := 0.0
var _line_i := -1
var _line_t := 0.0
var _line_len := 0.0
var _talk_t := 0.0
var _pressed := -1
var _pressed_t := 0.0
var _clips: Array = []
var _tone: AudioStreamPlayer
var _key_snd: AudioStreamPlayer
var _voice: AudioStreamPlayer
var _hiss: AudioStreamPlayer
var _calls: Dictionary = {}


func _ready() -> void:
	super._ready()
	picture = load(PIC) if ResourceLoader.exists(PIC) else null
	_ensure_phone_bus()
	_tone = _player(-11.0, "Phone")
	_key_snd = _player(-12.0, "Phone")
	_voice = _player(-2.0, "Phone")
	_voice.finished.connect(_next_clip)
	_hiss = _player(-22.0, "Phone")


func _player(db: float, bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = db
	p.bus = bus
	add_child(p)
	return p


## A telephone line: everything below 300 Hz and above 3.4 kHz gone, a little grit.
static func _ensure_phone_bus() -> void:
	if AudioServer.get_bus_index("Phone") >= 0:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, "Phone")
	AudioServer.set_bus_send(i, "Master")
	var hp := AudioEffectHighPassFilter.new()
	hp.cutoff_hz = 320.0
	AudioServer.add_bus_effect(i, hp)
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 3300.0
	AudioServer.add_bus_effect(i, lp)
	var dist := AudioEffectDistortion.new()
	dist.mode = AudioEffectDistortion.MODE_OVERDRIVE
	dist.drive = 0.18
	dist.post_gain = -2.0
	AudioServer.add_bus_effect(i, dist)


func _opened() -> void:
	say("", "", false)


func _closing() -> void:
	if _state != RESTING:
		_hang_up(false)


func _hotspots() -> Array:
	var out: Array = [{"id": "handset", "rect": HANDSET}, {"id": "redial", "rect": REDIAL}]
	for i in KEYS.size():
		out.append({"id": "key%d" % i, "rect": Rect2(KEY_CENTRES[i] - KEY_HALF, KEY_HALF * 2.0)})
	return out


func _clicked(id: String) -> void:
	if id == "handset":
		if _state == RESTING:
			_lift()
		else:
			_hang_up(true)
	elif id == "redial":
		_press_visual(-2)
		if _state == DIAL_TONE and _last != "":
			for ch in _last:
				_dial(ch, false)
	elif id.begins_with("key"):
		var i := int(id.substr(3))
		_press_visual(i)
		_dial(KEYS[i])


func _key(event: InputEventKey) -> bool:
	var ch := char(event.unicode) if event.unicode > 0 else ""
	var i := KEYS.find(ch)
	if i >= 0:
		_press_visual(i)
		_dial(ch)
		return true
	if event.physical_keycode == KEY_SPACE or event.physical_keycode == KEY_ENTER:
		_clicked("handset")
		return true
	return false


func _press_visual(i: int) -> void:
	_pressed = i
	_pressed_t = 0.14


func _lift() -> void:
	play(SFX + "lift.wav", -6.0)
	_state = DIAL_TONE
	_number = ""
	_since_key = 0.0
	_loop_tone("dialtone.wav")
	_loop(_hiss, SFX + "line_hiss.wav")
	say("", "", false)


func _hang_up(sound: bool) -> void:
	if sound:
		play(SFX + "hangup.wav", -5.0)
	var finished_call := _state == TALKING or _state == ENDED
	_tone.stop()
	_voice.stop()
	_hiss.stop()
	_clips.clear()
	if _state == TALKING and _line_i >= 0:
		# Hung up on them: what was agreed before that still stands.
		_apply_effect()
	_state = RESTING
	_call = {}
	_line_i = -1
	if not finished_call:
		say("", "", false)


func _dial(ch: String, sound := true) -> void:
	if _state == RESTING:
		return
	if sound:
		var key_file := "star" if ch == "*" else ("hash" if ch == "#" else ch)
		_key_snd.stream = load(SFX + "dtmf_%s.wav" % key_file)
		_key_snd.play()
	if _state != DIAL_TONE and _state != DIALLING:
		return
	_tone.stop()
	_state = DIALLING
	_number += ch
	_since_key = 0.0


func _connect() -> void:
	var num := BOOK.digits(_number)
	_last = num
	var ctx: Dictionary = context_provider.call() if context_provider.is_valid() else {}
	ctx["calls"] = _calls
	_call = BOOK.dial(num, ctx)
	_call["number"] = num
	_calls[num] = int(_calls.get(num, 0)) + 1
	_talk_t = 0.0
	match str(_call.get("kind", "sit")):
		"busy":
			_state = ENDED
			_loop_tone("busy.wav")
		"sit":
			_state = ENDED
			_tone.stream = load(SFX + "sit.wav")
			_tone.play()
			_queue_clips(["sit_msg"])
			say("", "The number you have dialled does not exist.")
		_:
			_state = RINGING
			_rings_left = int(_call.get("rings", 1))
			_ring_t = 0.0
			if _rings_left <= 0:
				_pick_up()
			else:
				_ring()


func _ring() -> void:
	_tone.stream = load(SFX + "ringback.wav")
	_tone.play()


func _pick_up() -> void:
	_tone.stop()
	if str(_call.get("kind", "")) == "noanswer":
		_state = ENDED
		_loop_tone("dead.wav")
		return
	play(SFX + "lift.wav", -14.0)
	_state = TALKING
	_line_i = -1
	_next_line()


func _next_line() -> void:
	_line_i += 1
	var lines: Array = _call.get("lines", [])
	if _line_i >= lines.size():
		_end_call()
		return
	var line: Dictionary = lines[_line_i]
	var who := str(line.get("who", ""))
	if who == "":
		who = str(_call.get("who", ""))
	say(who, str(line.get("text", "")))
	_line_t = 0.0
	var text_len := float(str(line.get("text", "")).length())
	_line_len = clampf(text_len / 15.0, 1.4, 7.0)
	var voice := str(line.get("voice", ""))
	if voice == "clock":
		_queue_clips(_clock_clips())
	elif voice != "":
		_queue_clips([voice])


func _end_call() -> void:
	_apply_effect()
	_state = ENDED
	play(SFX + "hangup.wav", -16.0)
	_loop_tone("dead.wav")


func _apply_effect() -> void:
	var effect := str(_call.get("effect", ""))
	if effect != "" and on_effect.is_valid():
		on_effect.call(effect, str(_call.get("number", "")))
	_call["effect"] = ""


func _queue_clips(ids: Array) -> void:
	_clips.clear()
	for id in ids:
		var p := VOICE + str(id) + ".mp3"
		if ResourceLoader.exists(p):
			_clips.append(p)
	_next_clip()


func _next_clip() -> void:
	if _clips.is_empty():
		return
	_voice.stream = load(_clips.pop_front())
	_voice.play()
	# The line lasts at least as long as the voice.
	_line_len = maxf(_line_len, _line_t + _voice.stream.get_length() + 0.35)


func _clock_clips() -> Array:
	var ctx: Dictionary = context_provider.call() if context_provider.is_valid() else {}
	var hour := float(ctx.get("hour", 12.0))
	var h := int(hour) % 24
	var m := int((hour - floor(hour)) * 60.0)
	return ["clock_intro", "h%d" % h, "m%02d" % m, "clock_end"]


func _loop_tone(file: String) -> void:
	_loop(_tone, SFX + file)


func _loop(p: AudioStreamPlayer, path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var s := load(path)
	if s is AudioStreamWAV:
		var w := (s as AudioStreamWAV).duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
		s = w
	p.stream = s
	p.play()


func _tick(delta: float) -> void:
	_pressed_t -= delta
	match _state:
		DIALLING:
			_since_key += delta
			var num := BOOK.digits(_number)
			if BOOK.is_complete(num) and _since_key >= WAIT_AFTER_LAST_KEY:
				_connect()
			elif _since_key >= GIVE_UP_DIALLING:
				_state = ENDED
				_loop_tone("dead.wav")
		RINGING:
			_ring_t += delta
			if _ring_t >= RING_ON + RING_OFF:
				_ring_t = 0.0
				_rings_left -= 1
				if _rings_left <= 0:
					_pick_up()
				else:
					_ring()
			elif _ring_t >= RING_ON and _tone.playing:
				_tone.stop()
		TALKING:
			_talk_t += delta
			_line_t += delta
			if _line_t >= _line_len and not _voice.playing:
				_next_line()


func _paint(c: Control) -> void:
	if picture == null:
		return
	# Off the hook: the handset (cut out along its outline) lifted toward you, bigger and
	# up off the cradle, with the empty cradle dark under it.
	if _state != RESTING:
		var cradle := PackedVector2Array()
		for p in HANDSET_OUTLINE:
			cradle.append(p)
		c.draw_colored_polygon(cradle, Color(0.08, 0.06, 0.04, 0.78))
		var lifted := PackedVector2Array()
		var uvs := PackedVector2Array()
		var centre := HANDSET.get_center()
		for p in HANDSET_OUTLINE:
			lifted.append(centre + (p - centre) * 1.08 + Vector2(-10, -14))
			uvs.append(p / Vector2(W, PIC_H))
		var shadow := PackedVector2Array()
		for p in lifted:
			shadow.append(p + Vector2(6, 9))
		c.draw_colored_polygon(shadow, Color(0, 0, 0, 0.45))
		c.draw_colored_polygon(lifted, Color.WHITE, uvs, picture)
	# Digits on the keys.
	for i in KEYS.size():
		var down := _pressed_t > 0.0 and _pressed == i
		var r := Rect2(KEY_CENTRES[i] - KEY_HALF, KEY_HALF * 2.0)
		if down:
			c.draw_rect(r.grow(-2), Color(0, 0, 0, 0.32))
		var glyph: String = KEYS[i]
		var font: Font = RETRO_UI.FONT_LABEL
		var w := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var p: Vector2 = (KEY_CENTRES[i] + Vector2(-w * 0.5, 3.0)).floor() + (Vector2(0, 1) if down else Vector2.ZERO)
		ink(c, font, p, glyph, Color(0.16, 0.15, 0.14), Color(0.86, 0.84, 0.78, 0.6))
	if _pressed_t > 0.0 and _pressed == -2:
		c.draw_rect(REDIAL.grow(-2), Color(0, 0, 0, 0.3))
	if hovered() != "" and hovered().begins_with("key") and not (_pressed_t > 0.0):
		var hi := int(hovered().substr(3))
		var hr := Rect2(KEY_CENTRES[hi] - KEY_HALF, KEY_HALF * 2.0)
		c.draw_rect(hr.grow(-1), Color(1.0, 0.9, 0.6, 0.12))
	_paint_lcd(c)


func _paint_lcd(c: Control) -> void:
	var ink_col := Color(0.07, 0.12, 0.05)
	var ghost := Color(0.07, 0.12, 0.05, 0.12)
	var font: Font = RETRO_UI.FONT_TEXT
	c.draw_rect(LCD, Color(0.42, 0.5, 0.3, 0.35))
	var text := ""
	match _state:
		RESTING:
			var ctx: Dictionary = context_provider.call() if context_provider.is_valid() else {}
			var hour := float(ctx.get("hour", 12.0))
			text = "D%d %02d:%02d" % [int(ctx.get("day", 1)), int(hour) % 24, int((hour - floor(hour)) * 60.0)]
		DIAL_TONE:
			text = "_" if fmod(Time.get_ticks_msec() / 500.0, 2.0) < 1.0 else ""
		DIALLING, RINGING:
			text = _number.right(11)
		TALKING, ENDED:
			text = "%s %02d:%02d" % [_number.right(4), int(_talk_t) / 60, int(_talk_t) % 60] if _state == TALKING else _number.right(11)
	ink(c, font, Vector2(LCD.position.x + 3, LCD.position.y + 12), "88888888888", ghost)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	ink(c, font, Vector2(LCD.end.x - 3 - w, LCD.position.y + 12).floor(), text, ink_col)
