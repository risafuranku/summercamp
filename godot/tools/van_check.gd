extends "res://tools/shot_driver.gd"

## The wholesaler's van as a plate like the post's and the orders on one van (TODO W1), the
## shelves running low as plates (W51). A pub's books in a new camp: beer down to 5 (its
## plate), an order (the plate goes, the van's comes, the fee), a second the same day (no
## fee: the same van), the next morning a third joins the van on its way, the van comes, its
## driver stacks the boxes on the pallet by the barrier (25. 11. „Krabice u závory“: no note
## at the counter), you carry the pub's box in: its beer on the shelves. Lines "VAN ..." and
## pictures.
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/van_check.tscn -- --out=DIR

const C := "get_tree().root.get_node('VanCheck')"
const BUSINESS := preload("res://scripts/business/business_runtime.gd")
var key := ""


func setup_pub() -> void:
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
			var d := Vector2(c - pc).length()
			if d < best_d and d > 3.0:
				best_d = d
				best = c
	st.grid.occupy_cell(best, "pub", "pub_test", best)
	key = "%d:%d" % [best.x, best.y]
	CoreRoot.actions.biz_site(key, "pub")
	print("VAN pub at ", key)


func log_state(tag: String) -> void:
	var hud = _main.get("_hud_manager")
	var strip = hud.get("_arrival_rings")
	var rows: Array = []
	for r in hud.get("_troubles"):
		if str(r.get("id", "")).begins_with("s") or str(r.get("id", "")) == "vboxes":
			rows.append("%s:%s:%.2f:%d" % [str(r["id"]), str(r["word"]), float(r["left"]), int(r.get("n", 0))])
	var orders: Array = []
	for o in CoreRoot.get_state().biz.get("orders", []):
		orders.append("%s d%d $%d" % [JSON.stringify(o["goods"]), int(o["due_day"]), int(o["cost"])])
	print("VAN %s day=%d hour=%.2f money=%d van_day=%d plate=%s stock_rows=%s orders=%s beer=%d" % [tag, CoreRoot.get_day(), float(_main.get("_time_of_day_hours")),
		CoreRoot.get_money(), BUSINESS.van_day(), JSON.stringify(strip.get("van")), str(rows), str(orders), BUSINESS.stock_of(key, "beer")])


func low_beer() -> void:
	CoreRoot.get_state().biz["sites"][key]["stock"]["beer"] = 5


func order(good: String) -> void:
	var before := CoreRoot.get_money()
	var ok: bool = CoreRoot.actions.biz_order(key, {good: 1}, BUSINESS.van_day())
	print("VAN order %s ok=%s paid=%d" % [good, str(ok), before - CoreRoot.get_money()])


func van_event() -> Dictionary:
	for ev in _main.get("_day_events").get("_events"):
		if str(ev["kind"]) == "delivery":
			return ev
	return {}


func to_van(extra_min: int) -> void:
	var ev := van_event()
	if ev.is_empty():
		print("VAN no van planned")
		return
	var at := int(ev.get("started", ev["at"])) + extra_min
	_main.call("debug_jump_to", at / 1440 + 1, float(posmod(at, 1440)) / 60.0)


## You by the pallet inside the barrier, looking at it and the road past it.
func by_pallet() -> void:
	var gate := get_tree().get_first_node_in_group("camp_gate")
	var pal: Vector3 = preload("res://scripts/business/delivery_pallet.gd").spot(gate)
	var me: Node3D = _main.get("_player")
	me.global_position = pal + Vector3(1.6, 0.6, 5.5)
	var to := pal - me.global_position
	me.rotation.y = atan2(-to.x, -to.z)


## The first box on the pallet into your arms, you at the pub, into it.
func carry_in() -> void:
	var carry := get_tree().get_first_node_in_group("carry")
	var boxes: Array = CoreRoot.actions.biz_boxes()
	if boxes.is_empty():
		print("VAN no box")
		return
	carry.call("_take_box", int(boxes[0]["id"]))
	print("VAN took box %d held=%s" % [int(boxes[0]["id"]), str(carry.get("held"))])
	var parts := key.split(":")
	var gm = _main.get("grid_manager")
	var o := Vector2i(int(parts[0]), int(parts[1]))
	(_main.get("_player") as Node3D).global_position = gm.get_footprint_center(o, CoreRoot.get_state().grid.footprint_of(o)) + Vector3(0, 0.6, 4.0)
	carry.call("_box_down")
	print("VAN carried in, boxes left %d" % CoreRoot.actions.biz_boxes().size())


func _ready() -> void:
	super._ready()
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 2.0],
		["eval", "_interior_manager._building_interior._exit_crt_view()"], ["wait", 0.5],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
		["money", 9000], ["eval", C + ".setup_pub()"], ["wait", 1.0],
		["eval", C + ".log_state('start')"],
		["eval", C + ".low_beer()"], ["wait", 1.2],
		["eval", C + ".log_state('low')"], ["shot", "v0_stock_low"],
		["eval", C + ".order('beer')"], ["wait", 1.2],
		["eval", C + ".log_state('ordered')"],
		["eval", C + ".order('rum')"], ["wait", 1.2],
		["eval", C + ".log_state('second')"], ["shot", "v1_on_way"],
		# Before midnight TOMORROW, after it TODAY, the bar only from the morning (14. 11.).
		["eval", "debug_jump_to(1, 23.5)"], ["wait", 1.2], ["eval", C + ".log_state('late')"],
		["eval", "debug_jump_to(2, 0.5)"], ["wait", 1.2], ["eval", C + ".log_state('midnight')"], ["shot", "v1b_today"],
		["eval", "debug_jump_to(2, 7.4)"], ["wait", 2.0],
		["eval", C + ".log_state('morning')"],
		["eval", C + ".order('kofola')"], ["wait", 1.2],
		["eval", C + ".log_state('joined')"],
		["eval", C + ".to_van(5)"], ["wait", 1.5],
		["eval", C + ".log_state('arrived')"],
		["eval", C + ".by_pallet()"], ["wait", 1.0], ["shot", "v2_van_here"],
		["eval", C + ".to_van(14)"], ["wait", 1.5], ["eval", C + ".log_state('at_pallet')"], ["shot", "v3_stacking"],
		["eval", C + ".to_van(26)"], ["wait", 2.0], ["eval", C + ".log_state('unloaded')"],
		["eval", "get_node('/root/CoreRoot').get_state().biz.get('boxes')"], ["shot", "v4_boxes"],
		["eval", C + ".carry_in()"], ["wait", 1.0], ["eval", C + ".log_state('carried')"],
		["eval", "get_tree().quit()"],
	]
