extends "res://tools/coop_check.gd"

## The staffroom for two (DESIGN.md §7c): the host builds it and takes two hands on; the
## joining warden sees them in its books (the host's pulse), buys a locker (it goes to
## the host's books), walks in and sits down at the laptop. The host, outside at the front
## window, sees them at the laptop through the glass (staff_runtime's warden figures); then
## walks in and sees them on its chair (interior_manager's room figures). Tagged lines
## ["STAFF <role> <tag>", value] for tools/staff_coop.py; pictures of each.
##   godot --path godot res://tools/staff_coop.tscn -- --role=host --out=DIR

const RT := "_interior_manager.staff"
const SI := "_interior_manager._service_interior"


func _ready() -> void:
	super._ready()
	if _role == "host":
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 0.5],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			["money", 9000], ["place"], ["wait", 2.0], ["hire"], ["wait", 1.0],
			["coop_signal", "host_up"], ["coop_wait_file", "client_in"], ["wait", 3.0],
			["front"], ["wait", 2.0], ["tag", "outside_figs", "_wardens_seen()"], ["shot", "sc_host_outside"],
			["open"], ["wait", 3.0], ["tag", "inside_figs", "_room_figs()"], ["shot", "sc_host_inside"],
			["tag", "host_lockers", "_lockers()"],
			["coop_signal", "host_done"], ["wait", 2.0], ["eval", "get_tree().quit()"],
		]
	else:
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]],
			["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 0.5],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 4.0],
			["tag", "client_crew", "_crew_n()"],
			["buy_locker"], ["wait", 3.0],
			["open"], ["wait", 3.0], ["laptop"], ["wait", 3.0],
			["tag", "client_job", "_job()"], ["shot", "sc_client_laptop"],
			["coop_signal", "client_in"], ["coop_wait_file", "host_done"], ["wait", 1.0], ["eval", "get_tree().quit()"],
		]


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
		"hire":
			var ap: Array = load("res://core/systems/staff_rules.gd").applicants(CoreRoot.get_day(), [], 0)
			CoreRoot.actions.staff_buy_gear("locker")
			for p in ap.slice(0, 2):
				CoreRoot.actions.staff_hire(p, CoreRoot.get_day())
		"laptop":
			_main._interior_manager._service_interior._staff_open_laptop()
		"buy_locker":
			print("STAFF client buy ", CoreRoot.actions.staff_buy_gear("locker"))
		"open":
			_main.set("debug_camera", null)
			_main._interior_manager.handle_structure_interact(_structure())
		"front":
			# Outside the front window on the right, looking in.
			var s := _structure()
			var plan = load("res://scripts/staff/staffroom_plan.gd")
			var w: Dictionary = plan.WINDOWS["front_r"]
			var glass: Vector3 = s.global_transform * (w["c"] as Vector3)
			var out: Vector3 = (s.global_basis * (w["out"] as Vector3)).normalized()
			var p: Node3D = _main._player
			p.global_position = glass + out * 1.6 - Vector3(0, 1.6, 0)
			p.look_at(Vector3(glass.x, p.global_position.y, glass.z), Vector3.UP)
			var head := p.get_node_or_null("Head") as Node3D
			if head != null:
				head.rotation.x = -0.12
		"tag":
			var expr := Expression.new()
			expr.parse(str(step[2]))
			var v = expr.execute([], self)
			print("STAFF_TAG [\"STAFF %s %s\", %s]" % [_role, str(step[1]), JSON.stringify(v)])
		_:
			super._run_step(step)


func _wardens_seen() -> int:
	var n := 0
	for f in (_main._interior_manager.staff._wardens as Dictionary).values():
		if f != null and is_instance_valid(f) and f.visible:
			n += 1
	return n


func _room_figs() -> Array:
	var out: Array = []
	for e in (_main._interior_manager._coop_figs as Dictionary).values():
		var f = e.get("fig")
		if f != null and is_instance_valid(f) and f.visible:
			out.append(str(f.get("pose")) if f.get("pose") != null else "fig")
	return out


func _crew_n() -> int:
	return (CoreRoot.actions.staff_state().get("crew", []) as Array).size()


func _lockers() -> int:
	return int((CoreRoot.actions.staff_state().get("gear", {}) as Dictionary).get("locker", 1))


func _job() -> String:
	return str(_main._interior_manager.coop_room().get("w", ""))
