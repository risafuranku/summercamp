extends "res://tools/shot_driver.gd"

## The toilet and shower blocks' dirt (the user 4. 11.: "the hint is sometimes true, sometimes
## a lie, the notice only sometimes; count the ladies' and the gents' apart"): a toilet block
## built, dirtied by uses, its hint by the door, its plate, the list inside; one half's jobs
## done, the block again. Prints "BLOCKS ...".
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/blocks_check.tscn -- --out=DIR

const C := "get_tree().root.get_node('BlocksCheck')"


func _block() -> Node3D:
	for c in _main.get("building_manager").get_node("Structures").get_children():
		if str(c.get_meta("building_type", "")) == "toilet_block":
			return c
	return null


func soil(times: int) -> String:
	var b := _block()
	var at: Vector2i = b.get_meta("grid_origin")
	for i in times:
		CoreRoot.actions.soil_building(at, 0.12)
	return report("soiled %d" % times)


func report(what: String) -> String:
	var b := _block()
	var at: Vector2i = b.get_meta("grid_origin")
	var cell: Dictionary = CoreRoot.get_state().grid.cells[at]
	var rows: Array = _main.call("_work_rows")
	var line := "BLOCKS %s: l=%.2f r=%.2f whole=%.2f hint='%s' plate=%s" % [what, float(cell.get("maint_l", -1)), float(cell.get("maint_r", -1)), float(cell.get("maintenance", 1)),
		_main.get("_interior_manager").get_hint_for_structure(b), str(rows.size())]
	print(line)
	return line


func go_in() -> String:
	_main.get("_interior_manager").handle_structure_interact(_block())
	return "in"


func tasks() -> String:
	var si = _main.get("_interior_manager").get("_service_interior")
	var cache: Dictionary = si.get("_upkeep_cache")
	var out: Array = []
	for k in cache:
		for t in cache[k].get("tasks", []):
			out.append(str(t["spot"]))
	var line := "BLOCKS tasks: %s" % ", ".join(out)
	print(line)
	return line


func do_side(side: String) -> String:
	var si = _main.get("_interior_manager").get("_service_interior")
	var cache: Dictionary = si.get("_upkeep_cache")
	for k in cache:
		for t in cache[k].get("tasks", []):
			if str(t["spot"]).ends_with("_" + side):
				si.call("_on_upkeep_task_done", str(t["id"]))
	return report("did %s" % side)


func _ready() -> void:
	super._ready()
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 2.0],
		["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 1.5], ["key", "Escape"], ["wait", 4.0],
		["money", 9000], ["clear", 8, 5, 6, 5], ["build", "toilet_block", 9, 6, 0], ["prep_all"], ["wait", 1.0],
		["eval", C + ".report('new')"], ["eval", C + ".soil(2)"], ["eval", C + ".soil(4)"],
		["eval", C + ".go_in()"], ["wait", 6.0], ["eval", C + ".tasks()"], ["shot", "b_inside"],
		["eval", C + ".do_side('l')"], ["eval", C + ".do_side('r')"], ["eval", C + ".tasks()"],
	]
