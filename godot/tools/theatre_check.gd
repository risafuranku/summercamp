extends "res://tools/shot_driver.gd"

## What comes down from the god cursor against the rooms that stand in buildings (the user 7. 11.:
## "the first cabin had no door at all, I could see in", "walking round it the caravan flickered
## and went"). A cabin near you that lands: its leaf on its hinge and seen; a room does not take a
## building still to come; two vans, the room going from one to the other: nothing of either left
## on the Builder's eye. Windowed. Lines "THEATRE ...", "THEATRE CHECK: PASS".
##   APPDATA=<dir> godot --path godot --audio-driver Dummy --resolution 1366x768 res://tools/theatre_check.tscn -- --out=DIR

const C := "get_tree().root.get_node('TheatreCheck')"
const BI := "_interior_manager._building_interior"
const DA := preload("res://scripts/attractions/door_anim.gd")
const GOD := preload("res://scripts/god/god_cursor.gd")

var at := {}
var fails := 0


func _ok(what: String, good: bool, more := "") -> void:
	print("THEATRE %s %s %s" % ["ok  " if good else "FAIL", what, more])
	if not good:
		fails += 1


func by_key(key: String) -> Node3D:
	var root = _main.building_manager.get_node_or_null("Structures")
	for c in root.get_children():
		if c.get_meta("grid_origin", Vector2i(-99, -99)) == at[key]:
			return c as Node3D
	return null


## A free place near `near` for `t`, built as a warden's order comes in.
func place(key: String, t: String, fp: Vector2i, near: Vector2i) -> void:
	var st = CoreRoot.get_state()
	var best := Vector2i(-1, -1)
	var bd := 1e9
	for y in range(0, 40):
		for x in range(0, 40):
			var c := Vector2i(x, y)
			var ok := true
			for dy in range(-1, fp.y + 1):
				for dx in range(-1, fp.x + 1):
					if not _main.grid_manager.is_in_bounds(c + Vector2i(dx, dy)):
						ok = false
			if not ok or not st.grid.can_place_footprint(c, fp):
				continue
			var d := float((c - near).length())
			if d < bd:
				bd = d
				best = c
	at[key] = best
	EventBus.RequestBuild.emit(t, best, 0)


func old_cabin() -> Vector2i:
	var root = _main.building_manager.get_node_or_null("Structures")
	for c in root.get_children():
		if str(c.get_meta("building_type", "")) == "cabin_1":
			return c.get_meta("grid_origin", Vector2i(10, 2))
	return Vector2i(10, 2)


func build() -> void:
	var o := old_cabin()
	place("van_a", "caravan_1", Vector2i(2, 1), o + Vector2i(5, 4))
	place("cabin", "cabin_1", Vector2i(2, 2), o + Vector2i(9, 4))
	place("van_b", "caravan_1", Vector2i(2, 1), o + Vector2i(5, 9))
	var c := by_key("cabin")
	var p: Node3D = _main._player
	p.global_position = c.global_position + Vector3(0, 0.2, 9.0)
	p.look_at(c.global_position + Vector3(0, 0.2, 0), Vector3.UP)


func waiting() -> void:
	for key in ["van_a", "cabin", "van_b"]:
		_ok("%s waits for its turn" % key, by_key(key).has_meta(GOD.WAITING))
	var cabin_room = _main._interior_manager.get("_cabin_interior")
	var van_room = _main._interior_manager.get("_caravan_interior")
	_ok("no room stands in what is still to come", cabin_room.get("_inview_cabin") != by_key("cabin") and van_room.get("_inview_van") != by_key("van_a") and van_room.get("_inview_van") != by_key("van_b"))


func landed() -> bool:
	for key in ["van_a", "cabin", "van_b"]:
		if by_key(key).has_meta(GOD.WAITING):
			return false
	return true


func nothing_left(tag: String) -> void:
	for key in ["van_a", "cabin", "van_b"]:
		var left := 0
		for g in by_key(key).find_children("*", "VisualInstance3D", true, false):
			if (g as VisualInstance3D).layers == GOD.BUILDER_EYE:
				left += 1
		_ok("%s: nothing of %s on the Builder's eye" % [tag, key], left == 0, str(left))
	var door: MeshInstance3D = DA.find_door(by_key("cabin"))
	_ok("%s: the cabin's leaf" % tag, door != null and door.is_visible_in_tree() and door.layers == 1 and door.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, str(door.layers) if door != null else "none")


func stand(key: String) -> void:
	var way: Dictionary = DA.entry_points(by_key(key), 0)
	var p: Node3D = _main._player
	var pos: Vector3 = way["outside"] + ((way["outside"] as Vector3) - (way["inside"] as Vector3)).normalized() * 4.0
	p.global_position = pos
	p.look_at(Vector3(way["inside"].x, pos.y, way["inside"].z), Vector3.UP)


func host_is(key: String) -> void:
	var room = _main._interior_manager.get("_caravan_interior")
	_ok("the room stands in %s" % key, room.get("_inview_van") == by_key(key))


func verdict() -> void:
	print("THEATRE CHECK: %s (%d failures)" % ["PASS" if fails == 0 else "FAILED", fails])


func _ready() -> void:
	super._ready()
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 4.0],
		["eval", BI + "._exit_crt_view()"], ["wait", 0.5], ["eval", BI + ".close_interior()"], ["wait", 2.0],
		["eval", "debug_jump_to(1, 11.0)"], ["wait", 1.0], ["money", 90000], ["wait", 1.0],
		["eval", "_god_cursor.set('debug_force', true)"],
		["eval", C + ".build()"], ["wait", 2.5], ["eval", C + ".waiting()"],
		["until", "get_tree().root.get_node('TheatreCheck').landed()", 90.0], ["wait", 2.0],
		["eval", C + ".nothing_left('landed')"], ["shot", "landed"],
		["eval", C + ".stand('cabin')"], ["wait", 2.0], ["shot", "cabin"], ["eval", C + ".nothing_left('at the cabin')"],
		["eval", C + ".stand('van_a')"], ["wait", 2.0], ["shot", "van_a"], ["eval", C + ".host_is('van_a')"], ["eval", C + ".nothing_left('at the first van')"],
		["eval", C + ".stand('van_b')"], ["wait", 2.0], ["shot", "van_b"], ["eval", C + ".host_is('van_b')"], ["eval", C + ".nothing_left('at the second van')"],
		["eval", C + ".stand('van_a')"], ["wait", 2.0], ["eval", C + ".host_is('van_a')"], ["eval", C + ".nothing_left('back at the first')"],
		["eval", C + ".verdict()"], ["eval", "get_tree().quit()"],
	]
