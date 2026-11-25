extends "res://tools/coop_check.gd"

## The bowling for two (station3d.coop_view, 25. 11.): the host works each of the hall's
## stations in turn and the other warden, standing in the hall, sees the work on theirs:
## the bufet's tray (crisps, a beer) and the glass under the tap, the pit's pin in the hand
## and the pins in the pit, the counter's lane picked, the cellar's crank turned.
## Tagged "BOWL_TAG [tag, ...]" for tools/bowling_coop.py, a picture at each.
##   godot --path godot res://tools/bowling_coop.tscn -- --role=host --out=DIR

const BI := "_interior_manager._bowling_interior"


func _ready() -> void:
	super._ready()
	if _role == "host":
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			["money", 40000], ["clear", 4, 4, 16, 12], ["build", "bowling", 6, 5, 0], ["wait", 1.0],
			["coop_place", 10, 13, 1.0], ["coop_signal", "host_up"],
			["coop_wait_file", "client_in"], ["wait", 1.0],
			["eval", "get_viewport().warp_mouse(get_viewport().get_visible_rect().size * Vector2(0.5, 0.5))"],
			["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('bowling'))"], ["wait", 3.0],
			# The bar's whole menu bought (a new bowling has its lanes only, no snack bar).
			["bw_do", "menu"], ["wait", 0.5],
			# The bufet: a tray laid, then a glass under the tap.
			["eval", BI + ".debug_open_station('bufet')"], ["wait", 1.5],
			["bw_do", "tray"], ["wait", 0.6], ["bw_tag", "host_tray"], ["shot", "bw1_host_tray"],
			["coop_signal", "host_tray"], ["coop_wait_file", "client_saw_tray"],
			# (A beer runs over the brim in 2.1 s and goes onto the tray: the other looks at once.)
			["bw_do", "pour"], ["coop_signal", "host_pour"], ["wait", 0.2], ["bw_tag", "host_pour"],
			["coop_wait_file", "client_saw_pour"], ["wait", 3.0], ["bw_tag", "host_tray_poured"],
			["coop_signal", "host_poured"], ["coop_wait_file", "client_saw_poured"],
			# The pit: a pin out of the pit into the hand, another in the pit.
			["eval", BI + ".debug_open_station('pit_a')"], ["wait", 1.5],
			["bw_do", "pin"], ["wait", 0.6], ["bw_tag", "host_pin"], ["shot", "bw3_host_pin"],
			["coop_signal", "host_pin"], ["coop_wait_file", "client_saw_pin"],
			# The counter: a lane picked.
			["eval", BI + ".debug_open_station('desk')"], ["wait", 1.5],
			["bw_do", "desk"], ["wait", 0.6], ["bw_tag", "host_desk"],
			["coop_signal", "host_desk"], ["coop_wait_file", "client_saw_desk"],
			# The cellar: the crank turned.
			["eval", BI + ".debug_open_station('cellar')"], ["wait", 2.0],
			["bw_do", "cellar"], ["wait", 0.6], ["bw_tag", "host_cellar"],
			["coop_signal", "host_cellar"], ["coop_wait_file", "client_saw_cellar"],
			["coop_wait_file", "client_back"],
			["coop_signal", "host_done"], ["wait", 1.0], ["eval", "get_tree().quit()"],
		]
	else:
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]],
			["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			["coop_place", 10, 14, 1.0],
			["eval", "get_viewport().warp_mouse(get_viewport().get_visible_rect().size * Vector2(0.5, 0.5))"],
			["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('bowling'))"], ["wait", 3.0],
			# Off the shoe counter (where one comes in) into the hall.
			["eval", BI + ".debug_station('desk').close_station()"], ["wait", 1.5],
			["coop_signal", "client_in"],
			["coop_wait_file", "host_tray"], ["wait", 1.5], ["bw_tag", "client_tray"], ["bw_look", "bufet"], ["shot", "bw2_client_tray"],
			["coop_signal", "client_saw_tray"],
			["coop_wait_file", "host_pour"], ["wait", 0.5], ["bw_tag", "client_pour"], ["bw_look", "bufet"], ["shot", "bw2b_client_pour"],
			["coop_signal", "client_saw_pour"],
			["coop_wait_file", "host_poured"], ["wait", 1.0], ["bw_tag", "client_tray_poured"],
			["coop_signal", "client_saw_poured"],
			["coop_wait_file", "host_pin"], ["wait", 1.0], ["bw_tag", "client_pin"], ["bw_look", "pit"], ["shot", "bw4_client_pin"],
			["coop_signal", "client_saw_pin"],
			["coop_wait_file", "host_desk"], ["wait", 1.0], ["bw_tag", "client_desk"],
			["coop_signal", "client_saw_desk"],
			["coop_wait_file", "host_cellar"], ["wait", 1.0], ["bw_tag", "client_cellar"],
			["coop_signal", "client_saw_cellar"],
			# Out of the bowling and back in: the tray the host left is there (the last one at a
			# station keeps sending it).
			["eval", "_interior_manager._bowling_interior.close_bowling()"], ["wait", 2.0],
			["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('bowling'))"], ["wait", 3.0],
			["eval", BI + ".debug_station('desk').close_station()"], ["wait", 2.0],
			["bw_tag", "client_tray_back"], ["bw_look", "bufet"], ["shot", "bw5_client_back"],
			["coop_signal", "client_back"], ["coop_wait_file", "host_done"], ["wait", 1.0], ["eval", "get_tree().quit()"],
		]


func _st(id: String) -> Node:
	var bi = _main._interior_manager._bowling_interior
	return bi.debug_station(id) if bi != null else null


func _run_step(step: Array) -> void:
	match str(step[0]):
		"bw_do":
			match str(step[1]):
				"menu":
					var key := str(_main._interior_manager._bowling_interior.key)
					for item in preload("res://core/systems/business_rules.gd").priced_lines("bowl"):
						CoreRoot.actions.biz_buy_menu(key, str(item))
				"tray":
					var buf = _st("bufet")
					buf._add("crisps", 1.0, Vector2.ZERO)
					buf._add("beer", 0.9, Vector2.ZERO)
				"pour":
					_st("bufet").debug_pour("beer", 0.0)
				"pin":
					var pit = _st("pit_a")
					var v = pit.lanes[0]
					v._to_pit_now(5, 5)
					v._to_pit_now(3, 3)
					v.take_pin(3)
					pit._carry = [v, 3]
				"desk":
					_st("desk")._pick = 2
				"cellar":
					var c = _st("cellar")
					c._crank_rot = 1.25
					c._tugs = 3
		"bw_look":
			# The hall's eye where the one working that station stands (bowling_layout SPOTS).
			var bi = _main._interior_manager._bowling_interior
			var cam: Camera3D = bi.get("_interior_camera") if bi != null else null
			var spot: Array = preload("res://scripts/bowling/bowling_layout.gd").SPOTS.get(str(step[1]), [])
			if cam != null and spot.size() >= 2:
				var rot: Vector3 = spot[1] * (PI / 180.0)
				cam.global_transform = (bi.get("_root") as Node3D).global_transform * Transform3D(Basis.from_euler(rot), spot[0])
				bi.set("_cam_base_rot", cam.rotation)
		"bw_tag":
			print("BOWL_TAG %s" % JSON.stringify([str(step[1])] + _tag_of(str(step[1]))))
		_:
			super._run_step(step)


## What the tag reports, by station: the tray (count, first item, shown), the glass under
## the tap (item, fill), lane 0's pin 3 and 5 (where, pin 3 shown) and pin 3's place in
## the pit station's frame, the counter's pick, the cellar's crank and tugs.
func _tag_of(tag: String) -> Array:
	if tag.ends_with("_tray") or tag.ends_with("_tray_poured") or tag.ends_with("_tray_back"):
		var t: Array = _st("bufet")._tray
		return [t.size(), str(t[0]["item"]) if t.size() > 0 else "", bool(t[0]["s"].visible) if t.size() > 0 else false]
	if tag.ends_with("_pour"):
		var p: Dictionary = _st("bufet")._pour
		return [str(p.get("item", "")), snappedf(float(p.get("fill", 0.0)), 0.01), bool(p["s"].visible) if p.has("s") else false]
	if tag.ends_with("_pin"):
		var pit = _st("pit_a")
		var v = pit.lanes[0]
		var pin: Node3D = v.pin_node(3)
		var at: Vector3 = pit.to_local(pin.global_position)
		return [v.pin_where(3), v.pin_where(5), pin.visible, snappedf(at.x, 0.01), snappedf(at.y, 0.01), snappedf(at.z, 0.01)]
	if tag.ends_with("_desk"):
		return [int(_st("desk")._pick)]
	if tag.ends_with("_cellar"):
		var c = _st("cellar")
		return [snappedf(float(c._crank_rot), 0.01), int(c._tugs)]
	return []
