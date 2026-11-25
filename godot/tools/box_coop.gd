extends "res://tools/coop_check.gd"

## The van's boxes for two (docs/businesses.md, 25. 11. „Krabice u závory“): the host's pub has
## a box of beer on the pallet by the barrier; the other warden takes it (the host's books say
## it is theirs, nobody else can take it), carries it into the pub: on the host's shelves.
## Tagged "BOX_TAG [tag, ...]" for tools/box_coop.py.
##   godot --path godot res://tools/box_coop.tscn -- --role=host --out=DIR

var _key := ""


func _ready() -> void:
	super._ready()
	if _role == "host":
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", 0, 0], ["call", "_on_menu_coop_host", []], ["wait_gameplay"], ["wait", 2.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
			["money", 40000], ["clear", 9, 8, 9, 9], ["build", "pub", 12, 10, 0], ["wait", 1.5],
			["box_setup"], ["wait", 1.0], ["box_tag", "host_start"],
			["coop_signal", "host_up"], ["coop_wait_file", "client_took"], ["wait", 2.0], ["box_tag", "host_taken"],
			["box_steal"], ["coop_signal", "host_tried"],
			["coop_wait_file", "client_in"], ["wait", 2.0], ["box_tag", "host_end"],
			["coop_signal", "host_done"], ["coop_wait_file", "client_ended"], ["wait", 1.0], ["eval", "get_tree().quit()"],
		]
	else:
		_steps = [
			["wait_menu"], ["coop_port"], ["coop_look", CLIENT_LOOK[0], CLIENT_LOOK[1]],
			["coop_wait_file", "host_up"], ["coop_join", "127.0.0.1"], ["wait_gameplay"], ["wait", 3.0],
			["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.0],
			["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 2.0],
			["box_tag", "client_start"], ["box_take"], ["wait", 0.5], ["coop_signal", "client_took"],
			["coop_wait_file", "host_tried"], ["wait", 2.0], ["box_tag", "client_held"],
			["box_carry_in"], ["wait", 0.5], ["coop_signal", "client_in"],
			["coop_wait_file", "host_done"], ["wait", 2.0], ["box_tag", "client_end"], ["coop_signal", "client_ended"], ["wait", 1.0], ["eval", "get_tree().quit()"],
		]


func _pub_key() -> String:
	for k in CoreRoot.get_state().biz.get("sites", {}):
		if str(CoreRoot.get_state().biz["sites"][k].get("kind", "")) == "pub":
			return str(k)
	return ""


func _run_step(step: Array) -> void:
	match str(step[0]):
		"box_setup":
			# The pub's books, its beer low, a box of it unloaded by the barrier.
			var gm = _main.get("grid_manager")
			var o := Vector2i(12, 10)
			CoreRoot.actions.biz_site("%d:%d" % [o.x, o.y], "pub")
			_key = _pub_key()
			var site: Dictionary = CoreRoot.get_state().biz["sites"][_key]
			site["stock"]["beer"] = 5
			CoreRoot.get_state().biz["orders"].append({"key": _key, "goods": {"beer": 1}, "cost": 70, "due_day": CoreRoot.get_day()})
			print("BOX unloaded %d" % CoreRoot.actions.biz_unload(CoreRoot.get_day()))
		"box_take":
			var carry := get_tree().get_first_node_in_group("carry")
			var boxes: Array = CoreRoot.actions.biz_boxes()
			if not boxes.is_empty():
				carry.call("_take_box", int(boxes[0]["id"]))
		"box_steal":
			# The host tries to take the same box: it is the other's.
			var boxes2: Array = CoreRoot.actions.biz_boxes()
			print("BOX_TAG %s" % JSON.stringify(["host_steal", CoreRoot.actions.biz_box_carry(int(boxes2[0]["id"]), "p1") if not boxes2.is_empty() else "none"]))
		"box_carry_in":
			var carry2 := get_tree().get_first_node_in_group("carry")
			_key = _pub_key()
			var parts := _key.split(":")
			var o2 := Vector2i(int(parts[0]), int(parts[1]))
			var gm2 = _main.get("grid_manager")
			(_main.get("_player") as Node3D).global_position = gm2.get_footprint_center(o2, CoreRoot.get_state().grid.footprint_of(o2)) + Vector3(0, 0.6, 4.0)
			carry2.call("_box_down")
		"box_tag":
			_key = _pub_key()
			var boxes3: Array = CoreRoot.actions.biz_boxes()
			var site3: Dictionary = CoreRoot.get_state().biz.get("sites", {}).get(_key, {})
			var carry3 := get_tree().get_first_node_in_group("carry")
			print("BOX_TAG %s" % JSON.stringify([str(step[1]), boxes3.size(), str(boxes3[0].get("by", "")) if not boxes3.is_empty() else "", int((site3.get("stock", {}) as Dictionary).get("beer", -1)), str(carry3.get("held").get("kind", "")), str((CoreRoot.get_state().biz.get("sites", {}) as Dictionary).keys())]))
		_:
			super._run_step(step)
