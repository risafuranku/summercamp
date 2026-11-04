extends RefCounted

## Number eleven, Mr Hora's (motel_furnish.gd builds it, motel_view.gd keeps its door,
## bathroom, bed and night): ten dollars, and he has not been back for his things.
##   the notebook  his Hruska gBook on the desk under the window (gbook.gd): it is his, there
##                 is nothing of the camp's on it, and you are not its administrator;
##   the hot plate warm when you come in; switch it off and some time later it is ticking
##                 again;
##   the aquarium  somebody has been feeding them;
##   the washing   still wet, dripping on the lino; at night it hangs like somebody, and
##                 when you are not well there are feet under it;
##   the slippers  never where you left them;
##   the suitcase  packed, the shirts folded, and it never went anywhere;
##   the map, the calendar, the newspapers, the transistor that will not hold its station;
##   by itself     (what wakes you as the set does in four) his screen lit on the desk.

const PLAN = preload("res://scripts/town/motel_plan.gd")
const FURN = preload("res://scripts/town/motel_furnish.gd")
const ROOMS = preload("res://scripts/town/motel_rooms.gd")
const SFX := "res://assets/sfx/"
const CAMP := "res://assets/textury/camp/"
const GBOOK_PATH := "res://scripts/town/gbook.gd"
## Where his slippers get to (floor x, z, turned), a step at a time: his bedside, towards
## the door, the hall's mouth, the bathroom's side of the room, and by your bed again.
const SLIPPERS := [[-0.42, 1.32, 0.3], [0.12, 1.42, 1.2], [0.74, 1.62, 2.1], [0.36, 0.72, -2.2], [-0.48, 0.92, 0.9]]

var view                         # motel_view.gd
var room                         # town_room.gd
var parts: Dictionary
var plate_on := false
var case_open := false
var screen_on := false
var _hum: AudioStreamPlayer
var _tank_light: OmniLight3D
var _plate_light: OmniLight3D
var _plate_glow: MeshInstance3D
var _plate_t := -1.0
var _screen: OmniLight3D
var _screen_glow: MeshInstance3D
var _slip: MeshInstance3D
var _slip_i := 0
var _slip_t := 40.0
var _drip_t := 5.0
var _feet: Sprite3D
var _feet_t := 30.0
var _feet_seen := 0.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func _init(p_view, p_room) -> void:
	view = p_view
	room = p_room
	parts = view.parts
	_rng.randomize()


func radio_voice() -> String:
	return "portable"


func spots() -> Dictionary:
	var r := func(p: float, y: float) -> Vector3: return Vector3(deg_to_rad(p), deg_to_rad(y), 0.0)
	return {
		"aisle": {"at": Vector3(0.68, 1.6, 0.2), "rot": r.call(-8.0, 0.0)},
		"bedfoot": {"at": Vector3(-0.3, 1.6, 1.2), "rot": r.call(-20.0, 100.0)},
		"desk": {"at": Vector3(0.68, 1.6, -1.22), "rot": r.call(-30.0, 0.0)},
		"window": {"at": Vector3(0.68, 1.6, -1.3), "rot": r.call(-4.0, 0.0)},
		"tank": {"at": Vector3(0.68, 1.6, 0.42), "rot": r.call(-20.0, -90.0)},
		"calendar": {"at": Vector3(0.82, 1.6, -0.72), "rot": r.call(0.0, -90.0)},
		"cupboard": {"at": Vector3(-0.22, 1.6, 1.42), "rot": r.call(-28.0, 112.0)},
		"corner": {"at": Vector3(-1.02, 1.6, -0.72), "rot": r.call(-20.0, -20.0)},
		"washing": {"at": Vector3(0.42, 1.6, -0.95), "rot": r.call(3.0, 92.0)},
	}


func ways() -> Array:
	return [["room", "tank"], ["room", "aisle"], ["tank", "aisle"], ["aisle", "calendar"], ["aisle", "desk"],
		["desk", "window"], ["calendar", "desk"], ["aisle", "bedfoot"], ["room", "bedfoot"], ["bedfoot", "cupboard"],
		["bedfoot", "corner"], ["aisle", "corner"], ["aisle", "washing"], ["desk", "washing"], ["calendar", "washing"]]


func from_bed() -> Array:
	return ["map"]


func things(hour: float) -> void:
	var w := PLAN.ROOM_W
	var da := FURN.DESK_AT
	room._hot_box("gbook", da + Vector3(0, 0.17, -0.03), Vector3(0.5, 0.34, 0.34), [parts["gbook"]] if parts.get("gbook") != null else [])
	if parts.get("radio") != null:
		room._hot_box("radio", da + Vector3(-0.5, 0.12, -0.08), Vector3(0.34, 0.24, 0.16), [parts["radio"]])
	if parts.get("plate") != null:
		room._hot_box("plate", (parts["plate_at"] as Vector3), Vector3(0.34, 0.2, 0.3), [parts["plate"]])
	room._hot_box("dishes", Vector3(-0.74, 0.92, PLAN.ROOM_D * 0.5 - 0.22), Vector3(0.74, 0.28, 0.3), [])
	if parts.get("tank") != null:
		room._hot_box("tank", parts["tank_at"], Vector3(0.14, 0.5, 0.95), [parts["tank"]])
	if parts.get("calendar") != null:
		room._hot_box("calendar", (parts["calendar"] as Node3D).position + Vector3(-0.03, 0, 0), Vector3(0.06, 0.56, 0.42), [parts["calendar"]])
	if parts.get("map") != null:
		room._hot_box("map", (parts["map"] as Node3D).position + Vector3(0.03, 0, 0), Vector3(0.06, 0.96, 1.3), [parts["map"]])
	if parts.get("papers") != null:
		room._hot_box("papers", Vector3(w * 0.5 - 0.3, 0.22, -1.0), Vector3(0.4, 0.44, 0.4), [parts["papers"]])
	if parts.get("washing") != null:
		room._hot_box("washing", Vector3(-0.42, 1.75, -1.28), Vector3(0.08, 0.95, 1.7), [parts["washing"]])
	if parts.get("suitcase") != null:
		room._hot_box("suitcase", Vector3(-1.1, 0.2, -1.62), Vector3(0.7, 0.42, 0.34), [parts["suitcase"]])
	_hum = view._player(-27.0)
	view._loop_on(_hum, "motel/aquarium.ogg", -25.0)
	_tank_light = _omni(parts.get("tank_at", Vector3.ZERO) + Vector3(-0.22, 0.05, 0), Color(0.5, 0.86, 0.72), 0.34, 2.3)
	_plate_light = _omni(parts.get("plate_at", Vector3.ZERO) + Vector3(0, 0.05, -0.1), Color(1.0, 0.36, 0.16), 0.1, 1.2)
	_plate_glow = ROOMS._glow_patch(room._root, (parts.get("plate_at", Vector3.ZERO) as Vector3) + Vector3(0, -0.02, -0.08), Vector2(0.2, 0.06))
	_screen = _omni(FURN.DESK_AT + Vector3(0, 0.3, 0.25), Color(0.62, 0.74, 1.0), 0.5, 2.2)
	_screen.visible = false
	_screen_glow = ROOMS._glow_patch(room._root, (parts.get("gbook_at", FURN.DESK_AT) as Vector3) + Vector3(0, 0.02, 0.012), Vector2(0.34, 0.2))
	_screen_glow.visible = false
	_set_plate(view._night(hour) or _rng.randf() < 0.5, true)
	_slip_i = _rng.randi_range(0, 1)
	_put_slippers()


func _omni(at: Vector3, col: Color, energy: float, rng: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = at
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	room._root.add_child(l)
	return l


func click(id: String) -> bool:
	match id:
		"gbook":
			view._walker.go("desk", func(): _open_book())
		"radio":
			view._walker.go("desk", func(): view.radio.toggle())
		"plate":
			view._walker.go("cupboard", func():
				if plate_on:
					view._play("motel/hotplate_sizzle.mp3", -8.0)
					_set_plate(false)
					_plate_t = _rng.randf_range(35.0, 110.0)
				else:
					_set_plate(true))
		"dishes":
			view._walker.go("cupboard", func(): view._play("motel/dishes.mp3", -9.0))
		"tank":
			view._walker.go("tank", func(): _tank())
		"calendar":
			view._walker.go("calendar", func(): view._look_at("calendar"))
		"map":
			if view.lying:
				view._look_at("map")
			else:
				view._walker.go("bedfoot", func(): view._look_at("map"))
		"papers":
			view._walker.go("calendar", func():
				view._play("motel/newspaper.mp3", -8.0)
				view._look_at("papers"))
		"washing":
			view._walker.go("washing", func():
				view._play("motel/shower_curtain.mp3", -16.0)
				view._play("pipes/wetdrop.mp3", -12.0)
				var ws: Node3D = parts.get("washing")
				if ws != null:
					var tw: Tween = room.create_tween()
					tw.tween_property(ws, "rotation:x", 0.1, 0.25).set_trans(Tween.TRANS_SINE)
					tw.tween_property(ws, "rotation:x", -0.06, 0.4).set_trans(Tween.TRANS_SINE)
					tw.tween_property(ws, "rotation:x", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
				if _feet != null and is_instance_valid(_feet):
					_feet.queue_free()
					_feet = null)
		"suitcase":
			view._walker.go("corner", func(): _suitcase(), Vector3(deg_to_rad(-42.0), deg_to_rad(5.0), 0.0))
		_:
			return false
	return true


## His machine: the one node, kept by the room, so it wakes where you left it.
func _open_book() -> void:
	if not ResourceLoader.exists(GBOOK_PATH):
		return
	var book = room.get_node_or_null("GBook")
	if book == null:
		book = load(GBOOK_PATH).new()
		book.name = "GBook"
		room.add_child(book)
	book.open_for(room)
	_set_screen(false)


func _set_screen(on: bool) -> void:
	screen_on = on
	_screen.visible = on
	_screen_glow.visible = on


func _set_plate(on: bool, quiet := false) -> void:
	plate_on = on
	_plate_light.visible = on
	_plate_glow.visible = on
	if on and not quiet:
		view._play("motel/hotplate_tick.mp3", -11.0)


func _tank() -> void:
	view._play("motel/glass_tap.mp3" if _rng.randf() < 0.6 else "motel/fish_food.mp3", -9.0)
	var tw: Tween = room.create_tween()
	tw.tween_property(_tank_light, "light_energy", 0.12, 0.08)
	tw.tween_property(_tank_light, "light_energy", 0.34, 0.5)


func _suitcase(quiet := false) -> void:
	if not quiet:
		view._play("motel/suitcase.mp3", -8.0)
	case_open = not case_open
	var sc: MeshInstance3D = parts.get("suitcase")
	var path := CAMP + ("suitcase_open.png" if case_open else "suitcase.png")
	if sc != null and ResourceLoader.exists(path):
		(sc.material_override as StandardMaterial3D).albedo_texture = load(path)


func _put_slippers() -> void:
	if _slip != null and is_instance_valid(_slip):
		_slip.queue_free()
		_slip = null
	if not ROOMS._exists("slippers"):
		return
	var v: Array = SLIPPERS[_slip_i % SLIPPERS.size()]
	_slip = ROOMS.decal(room._root, "slippers", Vector2(0.32, 0.3), Vector3(float(v[0]), 0.0, float(v[1])), Vector3.UP, float(v[2]), "Slippers")


func tick(delta: float) -> void:
	_t += delta
	if plate_on:
		var k := floorf(_t * 3.0)
		_plate_light.light_energy = 0.09 + 0.02 * sin(k * 1.3)
	elif _plate_t > 0.0:
		_plate_t -= delta
		if _plate_t <= 0.0:
			_set_plate(true)
	if screen_on:
		_screen.light_energy = 0.46 + 0.05 * sin(floorf(_t * 9.0) * 2.1)
	# The washing drips.
	_drip_t -= delta
	if _drip_t <= 0.0:
		_drip_t = _rng.randf_range(4.0, 9.0)
		if not view.asleep:
			view._play("pipes/wetdrop.mp3", -27.0)
	_tick_slippers(delta)
	_tick_feet(delta)


## The slippers move on while you are not looking at where they are.
func _tick_slippers(delta: float) -> void:
	if _slip == null or view.asleep:
		return
	_slip_t -= delta
	if _slip_t > 0.0:
		return
	if room._cam.is_position_in_frustum(_slip.global_position):
		_slip_t = 1.0
		return
	_slip_t = _rng.randf_range(40.0, 85.0) * (1.0 - 0.6 * view._low())
	_slip_i += 1
	_put_slippers()
	if view._night(view._now()):
		view._play("motel/slippers.mp3", -22.0)


## Feet under the washing, some nights, gone when you come near or look a while.
func _tick_feet(delta: float) -> void:
	if view.asleep or not view._night(view._now()):
		return
	var ws: Node3D = parts.get("washing")
	if ws == null:
		return
	var at := Vector3(-0.8, 0.0, -1.3)
	if _feet != null and is_instance_valid(_feet):
		var near: bool = Vector2(room._cam.position.x - at.x, room._cam.position.z - at.z).length() < 1.5
		var seen: bool = room._cam.is_position_in_frustum(_feet.global_position + Vector3(0, 0.3, 0))
		if seen:
			_feet_seen += delta
		if near or (not seen and _feet_seen > 2.5):
			_feet.queue_free()
			_feet = null
			_feet_seen = 0.0
		return
	_feet_t -= delta
	if _feet_t > 0.0:
		return
	_feet_t = _rng.randf_range(30.0, 70.0)
	if _rng.randf() < 0.1 + 0.8 * view._low() and not room._cam.is_position_in_frustum(ws.global_position):
		_feet = view._figure(room._root, at)


## What in four is the set coming on by itself: his screen lit in the dark.
func set_by_itself() -> void:
	_set_screen(true)
	view._play("motel/hotplate_tick.mp3", -24.0)


func woken(_kind: String) -> void:
	pass


func morning(_hour_now: float) -> void:
	_set_screen(false)
	# Beside your bed, pointing at you.
	_slip_i = SLIPPERS.size() - 1
	_put_slippers()
	_set_plate(true, true)


func state() -> Array:
	return [plate_on, case_open, screen_on]


func take(st: Array, quiet: bool) -> void:
	if st.size() < 3:
		return
	if bool(st[0]) != plate_on:
		_set_plate(bool(st[0]), quiet)
	if bool(st[1]) != case_open:
		_suitcase(quiet)
	if bool(st[2]) != screen_on:
		_set_screen(bool(st[2]))


func walked(_to: String) -> void:
	pass


func close() -> void:
	pass
