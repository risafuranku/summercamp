extends Node

## Out of the camp and down the road: the barrier you can raise yourself
## (scripts/camp_gate.gd), the road through the forest to the bus stop
## (scripts/town/road_south.gd) and its timetable (timetable_closeup.gd, the times from
## bus_timetable.gd).
##
## Things out there are clicked like the camp's buildings: they carry a building_type
## ("trip_*", "town_*") and InteriorManager hands them here (interact, hint_for).
## Created and owned by InteriorManager.

const TIMES = preload("res://scripts/town/bus_timetable.gd")
const TIMETABLE_CLOSEUP = preload("res://scripts/town/timetable_closeup.gd")

var _im: Node
var _timetable


func setup(interior_manager: Node) -> void:
	_im = interior_manager


func _main() -> Node:
	return get_tree().current_scene if get_tree() != null else null


func hour() -> float:
	var main := _main()
	if main != null and main.get("_time_of_day_hours") != null:
		return float(main.get("_time_of_day_hours"))
	return 12.0


func _gate() -> Node:
	return get_tree().get_first_node_in_group("camp_gate")


# ── clicking things out there ────────────────────────────────────────────────

func handles(building_type: String) -> bool:
	return building_type.begins_with("trip_") or building_type.begins_with("town_")


func hint_for(structure: Node3D) -> String:
	match str(structure.get_meta("building_type", "")):
		"trip_barrier":
			var gate := _gate()
			return "" if gate != null and gate.is_raised() else "Raise the barrier"
		"trip_timetable":
			return "Read the timetable"
	return ""


func interact(structure: Node3D) -> void:
	match str(structure.get_meta("building_type", "")):
		"trip_barrier":
			var gate := _gate()
			if gate != null and not gate.is_raised():
				gate.open_for_player()
		"trip_timetable":
			_open_timetable(str(structure.get_meta("stop", "camp")))


func _open_timetable(stop: String) -> void:
	if _timetable == null:
		_timetable = TIMETABLE_CLOSEUP.new()
		_timetable.hour_provider = hour
		add_child(_timetable)
		_timetable.closed.connect(_on_closeup_closed)
	_timetable.stop = stop
	_set_player_controls(false)
	_timetable.open_view()


func _on_closeup_closed() -> void:
	_set_player_controls(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _set_player_controls(on: bool) -> void:
	var main := _main()
	var player = main.get("_player") if main != null else null
	if player != null and player.has_method("set_controls_enabled"):
		player.set_controls_enabled(on)


## A close-up of ours is open (InteriorManager counts it as a room: the HUD and the
## camp's controls step aside).
func is_open() -> bool:
	return _timetable != null and _timetable.visible


func close_interior() -> void:
	if _timetable != null and _timetable.visible:
		_timetable.close_view()
