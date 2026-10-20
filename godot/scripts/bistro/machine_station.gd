extends "res://scripts/bistro/bistro_station.gd"

## PROTOTYP 540, the machine in the cellar nobody ordered (DESIGN.md §7b "The bistro"),
## behind the chain-link: its front is a Build texture on the wall (st_machine: green
## riveted steel, a hopper, a drum and its flywheel, a chute over a tray, a gauge and a
## lamp, its cable to a plug that lies out of its socket on the wet floor).
## By day a dead machine. At night (and from eight while the bistro is open late) it is
## awake: the lamp lit with the plug out, the needle off nought, the crank turned a little
## since you last looked. On some nights a jute sack lies in front of it, tied with wire
## (kitchen.gd proto: always the night after the camp woke without somebody, else now and
## then); hold on it and it goes up into the hopper. Then the machine runs till morning, and
## in the morning its tray is heaped with meat for twenty goulashes, in the books' stock.
## What is in the sack is never said.

const PLUG := Rect2(505, 295, 100, 50)
const LAMP := Rect2(140, 58, 30, 30)
const GAUGE := Rect2(120, 115, 55, 60)
const HOPPER := Rect2(180, 10, 300, 90)
const CRANK := Rect2(480, 75, 75, 165)
const TRAY := Rect2(205, 265, 245, 75)
const PLATE := Rect2(265, 140, 145, 30)
const LAMP_TEX := "res://assets/textury/bistro/machine_lamp.png"
## The sack on the floor against the wall left of the machine, and where it goes in.
const SACK_AT := Vector2(45, 360)
const SACK_OUT := 0.18
const SACK_M := 0.62
const HOPPER_MOUTH := Vector2(330, 40)
## Seconds of holding it to lift it in (it is heavy).
const LIFT_SEC := 1.6

var night := false
var _hum: AudioStreamPlayer
var _run: AudioStreamPlayer3D
var _crank_tries := 0
var _lamp: OmniLight3D
var _sack: Sprite3D
var _meat: Sprite3D
var _lifting := false
var _lift := 0.0
var _proto: Dictionary = {}
var _surface: Node3D
var _surface_at := Vector3.INF


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
	# Running, heard in the cellar wherever you stand in it.
	_run = AudioStreamPlayer3D.new()
	var run_path := "res://assets/sfx/bistro/proto_run.mp3"
	if ResourceLoader.exists(run_path):
		var rs = (load(run_path) as AudioStream).duplicate()
		if rs is AudioStreamMP3:
			rs.loop = true
		_run.stream = rs
	_run.unit_size = 3.0
	_run.volume_db = -6.0
	_run.position = local_at(Vector2(330, 180), 0.2)
	add_child(_run)
	# The lamp's glow on the steel round it (a small red light, lit only at night).
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(1.0, 0.22, 0.12)
	_lamp.light_energy = 0.0
	_lamp.omni_range = 0.6
	_lamp.position = local_at(LAMP.get_center(), 0.12)
	add_child(_lamp)
	_sack = sprite(TEX + "proto_sack.png", SACK_M, false)
	if _sack.texture != null:
		_sack.offset = Vector2(0, float(_sack.texture.get_height()) * 0.5)
	put(_sack, SACK_AT, SACK_OUT)
	_sack.visible = false
	_meat = sprite(TEX + "proto_meat.png", metres_x(TRAY.size.x) * 0.92, false)
	if _meat.texture != null:
		_meat.offset = Vector2(0, float(_meat.texture.get_height()) * 0.5)
	put(_meat, Vector2(TRAY.get_center().x, TRAY.end.y - 6.0), 0.16)
	_meat.visible = false


func has_rail() -> bool:
	return false


func _state() -> Dictionary:
	if kitchen != null and building_key != "" and kitchen.has_method("proto_state"):
		return kitchen.proto_state(building_key)
	var h := int(GuestManager._last_known_hour) if GuestManager != null else 12
	return {"awake": h >= 21 or h < 5, "sack": false, "fed": false, "running": false, "meat": false}


func _show() -> void:
	_proto = _state()
	night = bool(_proto["awake"])
	var running := bool(_proto["running"])
	# The lamp lit at night, in steps (now and then it drops out for a step); steady and
	# bright while it runs.
	if running:
		_lamp.light_energy = 1.2
	else:
		_lamp.light_energy = (0.9 if int(_t * 2.0) % 7 != 0 else 0.0) if night else 0.0
	_sack.visible = bool(_proto["sack"]) or _lifting
	if _lifting:
		var k := clampf(_lift / LIFT_SEC, 0.0, 1.0)
		k = floorf(k * 8.0) / 8.0
		_sack.position = local_at(SACK_AT, SACK_OUT).lerp(local_at(HOPPER_MOUTH, 0.3), k)
	elif _sack.visible:
		put(_sack, SACK_AT, SACK_OUT)
	_meat.visible = bool(_proto["meat"])
	# Running: the machine shakes in its bolts, a step at a time, and is heard.
	if _surface == null and get_parent() != null:
		_surface = get_parent().get_node_or_null("Surface_" + station) as Node3D
		if _surface != null:
			_surface_at = _surface.position
	if _surface != null and _surface_at != Vector3.INF:
		_surface.position = _surface_at + (Vector3(0.004 * float(int(_t * 12.0) % 3 - 1), 0.003 * float(int(_t * 9.0) % 2), 0) if running else Vector3.ZERO)
	if running and is_visible_in_tree():
		if not _run.playing and _run.stream != null:
			_run.play()
	elif _run.playing:
		_run.stop()


func _spots() -> Array:
	var out: Array = [
		{"id": "plug", "rect": PLUG, "verb": "Look at the plug"},
		{"id": "lamp", "rect": LAMP, "verb": "Look at the lamp"},
		{"id": "gauge", "rect": GAUGE, "verb": "Look at the gauge"},
		{"id": "hopper", "rect": HOPPER, "verb": "Look into the hopper"},
		{"id": "crank", "rect": CRANK, "verb": "Turn the crank"},
		{"id": "tray", "rect": TRAY, "verb": "Look at the tray"},
		{"id": "plate", "rect": PLATE, "verb": "Read the maker's plate"},
	]
	if _sack.visible and not _lifting:
		out.append({"id": "sack", "node": _sack, "verb": "Lift it into the hopper"})
	return out


func _press(id: String) -> void:
	var running := bool(_proto.get("running", false))
	match id:
		"sack":
			_lifting = true
			_lift = 0.0
			sfx("proto_sack", -10.0, 0.9)
		"plug":
			say("", "It is out of the socket. You leave it out." if not night else "Still out of the socket. The lamp is lit anyway.")
		"lamp":
			if running:
				say("", "Lit, and steady now.")
			else:
				say("", "A dead red lamp." if not night else "Lit. Warm to the touch.")
		"gauge":
			if running:
				say("", "The needle is hard over, and does not tremble.")
			else:
				say("", "The needle rests on nought." if not night else "The needle stands a little past nought, and trembles.")
		"hopper":
			if running:
				say("", "The lid is down. You leave it down.")
			else:
				say("", "Empty. It smells of iron." if not night else "Empty. The steel is warm inside, as if it had just been used.")
		"crank":
			_crank_tries += 1
			if running:
				say("", "It turns by itself, slowly, and does not stop for your hand.")
				sfx("crank", -10.0, 0.6)
			elif not night:
				say("", "It will not turn." if _crank_tries < 3 else "It will not turn. You are sure of it.")
				sfx("tick", -10.0, 0.5)
			else:
				say("", "It turns a quarter by itself before you touch it.")
				sfx("crank", -10.0, 0.7)
		"tray":
			if bool(_proto.get("meat", false)):
				say("", "Meat, minced fine. Enough for twenty goulashes. It is in the books.")
			else:
				say("", "Clean. Somebody scrubbed it, but not the corners.")
		"plate":
			say("", "PROTOTYP 540. JZD LIBLICE. The rest is scratched off with something sharp.")


func _release(id: String) -> void:
	if id == "sack" and _lifting and _lift < LIFT_SEC:
		# Let go: it slumps back onto the floor.
		_lifting = false
		_lift = 0.0
		sfx("proto_drop", -8.0)


func _tick(delta: float) -> void:
	if not _lifting:
		return
	_lift += delta
	if _lift >= LIFT_SEC:
		_lifting = false
		_lift = 0.0
		if kitchen != null and kitchen.has_method("proto_feed"):
			kitchen.proto_feed(building_key)
		sfx("proto_lid", -6.0)
		_held = ""


func _opened() -> void:
	_proto = _state()
	night = bool(_proto["awake"])
	if night and _hum.stream != null:
		_hum.play()


func _closing() -> void:
	_hum.stop()
	if _lifting:
		_lifting = false
		_lift = 0.0


func bar_text() -> String:
	return ""


func big_ticket() -> Dictionary:
	return {}


func mirror() -> Array:
	return []


# ── debug (tools/proto_check.gd, shots) ──────────────────────────────────────

## The sack lifted into the hopper, as a warden would (true when there was one).
func debug_feed() -> bool:
	_proto = _state()
	if not bool(_proto.get("sack", false)):
		return false
	_press("sack")
	_tick(LIFT_SEC + 0.1)
	return true
