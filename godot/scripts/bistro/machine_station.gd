extends "res://scripts/bistro/bistro_station.gd"

## The machine in the cellar nobody ordered (DESIGN.md §7b), behind the chain-link: its
## front is a Build texture on the wall (st_machine: green riveted steel, a hopper, a drum
## and its crank, a chute over an empty tray, a gauge and a lamp, its cable to a plug that
## lies out of its socket on the wet floor). By day a dead machine. At night the lamp is
## lit with the plug out, the needle stands off nought and the drum has turned a little
## since you last looked.

const PLUG := Rect2(505, 295, 100, 50)
const LAMP := Rect2(140, 58, 30, 30)
const GAUGE := Rect2(120, 115, 55, 60)
const HOPPER := Rect2(180, 10, 300, 90)
const CRANK := Rect2(480, 75, 75, 165)
const TRAY := Rect2(205, 265, 245, 75)
const PLATE := Rect2(265, 140, 145, 30)
const LAMP_TEX := "res://assets/textury/bistro/machine_lamp.png"

var night := false
var _hum: AudioStreamPlayer
var _crank_tries := 0
var _lamp: OmniLight3D


func _build() -> void:
	super._build()
	_hum = AudioStreamPlayer.new()
	var path := "res://assets/sfx/bistro/machine_hum.mp3"
	if ResourceLoader.exists(path):
		var st = (load(path) as AudioStream).duplicate()
		if st is AudioStreamMP3:
			st.loop = true
		_hum.stream = st
	_hum.volume_db = -20.0
	add_child(_hum)
	# The lamp's glow on the steel round it (a small red light, lit only at night).
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(1.0, 0.22, 0.12)
	_lamp.light_energy = 0.0
	_lamp.omni_range = 0.6
	_lamp.position = local_at(LAMP.get_center(), 0.12)
	add_child(_lamp)


func has_rail() -> bool:
	return false


func _is_night() -> bool:
	var h := int(GuestManager._last_known_hour) if GuestManager != null else 12
	return h >= 21 or h < 5


func _show() -> void:
	night = _is_night()
	# The lamp lit at night, in steps (now and then it drops out for a step).
	_lamp.light_energy = (0.9 if int(_t * 2.0) % 7 != 0 else 0.0) if night else 0.0


func _spots() -> Array:
	return [
		{"id": "plug", "rect": PLUG, "verb": "Look at the plug"},
		{"id": "lamp", "rect": LAMP, "verb": "Look at the lamp"},
		{"id": "gauge", "rect": GAUGE, "verb": "Look at the gauge"},
		{"id": "hopper", "rect": HOPPER, "verb": "Look into the hopper"},
		{"id": "crank", "rect": CRANK, "verb": "Turn the crank"},
		{"id": "tray", "rect": TRAY, "verb": "Look at the tray"},
		{"id": "plate", "rect": PLATE, "verb": "Read the maker's plate"},
	]


func _press(id: String) -> void:
	match id:
		"plug":
			say("", "It is out of the socket. You leave it out." if not night else "Still out of the socket. The lamp is lit anyway.")
		"lamp":
			say("", "A dead red lamp." if not night else "Lit. Warm to the touch.")
		"gauge":
			say("", "The needle rests on nought." if not night else "The needle stands a little past nought, and trembles.")
		"hopper":
			say("", "Empty. It smells of iron." if not night else "Empty. The steel is warm inside, as if it had just been used.")
		"crank":
			_crank_tries += 1
			if not night:
				say("", "It will not turn." if _crank_tries < 3 else "It will not turn. You are sure of it.")
				sfx("tick", -10.0, 0.5)
			else:
				say("", "It turns a quarter by itself before you touch it.")
				sfx("crank", -10.0, 0.7)
		"tray":
			say("", "Clean. Somebody scrubbed it, but not the corners.")
		"plate":
			say("", "PROTOTYP 540. JZD LESNA. The rest is scratched off with something sharp.")


func _opened() -> void:
	night = _is_night()
	if night and _hum.stream != null:
		_hum.play()


func _closing() -> void:
	_hum.stop()


func bar_text() -> String:
	return ""


func big_ticket() -> Dictionary:
	return {}


func mirror() -> Array:
	return []
