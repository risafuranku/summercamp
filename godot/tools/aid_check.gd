extends "res://tools/shot_driver.gd"

## The first-aid cabinets (TODO W31, scripts/aid_cabinet.gd): the store's shut, a hurt warden
## takes its lot (+50), it hangs open and gives nothing more; the next morning it is shut
## and stocked. Then the staffroom's over the mattress. Lines "AID ..." and pictures.
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/aid_check.tscn -- --out=DIR

const C := "get_tree().root.get_node('AidCheck')"
const BI := "_interior_manager._building_interior"


func log_state(tag: String) -> void:
	var st = CoreRoot.get_state()
	var store = _main.get("_interior_manager").get("_building_interior").get("_extras").get("store")
	print("AID %s hp=%d hurt=%s day=%d hour=%.2f books=%s store_used=%s door=%.0f" % [tag, int(_main.get("_player_health")),
		str(_main.call("player_hurt")), CoreRoot.get_day(), float(_main.get("_time_of_day_hours")),
		JSON.stringify((st.biz as Dictionary).get("aid", {})), str(store.aid.used()), store.aid.hinge.rotation_degrees.y])


func use_store() -> void:
	var store = _main.get("_interior_manager").get("_building_interior").get("_extras").get("store")
	print("AID use_store -> ", store.aid.use())


func next_morning() -> void:
	_main.call("debug_jump_to", CoreRoot.get_day() + 1, 7.0)


func _staff_aid():
	var si = _main.get("_interior_manager").get("_service_interior")
	return si.get("_staff_room").get("aid") if si != null and si.get("_staff_room") != null else null


func log_staff(tag: String) -> void:
	var a = _staff_aid()
	print("AID staff %s hp=%d used=%s door=%.0f books=%s" % [tag, int(_main.get("_player_health")), str(a.used()) if a != null else "?",
		a.hinge.rotation_degrees.y if a != null else -1.0, JSON.stringify((CoreRoot.get_state().biz as Dictionary).get("aid", {}))])


func use_staff() -> void:
	var a = _staff_aid()
	print("AID use_staff -> ", a.use() if a != null else "no cabinet")


func _structure() -> Node3D:
	var l := get_tree().get_nodes_in_group("staffroom")
	return l[0] if not l.is_empty() else null


func _run_step(step: Array) -> void:
	match str(step[0]):
		"place":
			var st = CoreRoot.get_state()
			var gm = _main.get("grid_manager")
			var pc: Vector2i = gm.world_to_grid(_main._player.global_position)
			var best := Vector2i(-1, -1)
			var best_d := 1e9
			var size: Vector2i = gm.get_grid_size()
			for y in range(1, size.y - 3):
				for x in range(1, size.x - 3):
					var c := Vector2i(x, y)
					if not st.grid.can_place_footprint(c, Vector2i(2, 2)):
						continue
					var d := Vector2(c - pc).length() + (0.0 if st.grid.can_place_footprint(c + Vector2i(-1, -1), Vector2i(4, 4)) else 30.0)
					if d < best_d and d > 2.0:
						best_d = d
						best = c
			EventBus.RequestBuild.emit("staffroom", best, 0)
		"open":
			_main.set("debug_camera", null)
			_main._interior_manager.handle_structure_interact(_structure())
		"boiler":
			var sr = _main._interior_manager._service_interior.get("_staff_room")
			sr.walk_to("boiler")
		_:
			super._run_step(step)


func _ready() -> void:
	super._ready()
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 2.0],
		["eval", BI + "._exit_crt_view()"], ["wait", 1.0],
		["eval", BI + "._extras.go_store()"], ["wait", 5.6],
		["eval", C + ".log_state('start')"], ["shot", "a0_store_shut"],
		["eval", "damage_player(60)"], ["wait", 2.0],
		["eval", C + ".log_state('hurt')"],
		["eval", C + ".use_store()"], ["wait", 1.2],
		["eval", C + ".log_state('used')"], ["shot", "a1_store_open"],
		["eval", C + ".use_store()"],
		["eval", C + ".log_state('again')"],
		["eval", C + ".next_morning()"], ["wait", 1.5],
		["eval", C + ".log_state('morning')"], ["shot", "a2_store_morning"],
		["eval", BI + ".close_interior()"], ["wait", 1.0],
		["money", 9000], ["place"], ["wait", 2.0],
		["open"], ["wait", 3.0], ["boiler"], ["wait", 2.5],
		["eval", C + ".log_staff('in')"], ["shot", "a3_staff_shut"],
		["eval", "damage_player(30)"], ["wait", 1.5],
		["eval", C + ".use_staff()"], ["wait", 1.2],
		["eval", C + ".log_staff('used')"], ["shot", "a4_staff_open"],
		["eval", "get_tree().quit()"],
	]
