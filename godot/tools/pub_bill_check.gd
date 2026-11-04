extends "res://tools/shot_driver.gd"

## Why a guest at the pub has neither an order nor a bill (TODO W47's tabs): each visitor's
## rounds as the rules have them against the taproom's orders and bills, a game hour at a
## time. Lines "PUBBILL ...", pictures of the rail.
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/pub_bill_check.tscn -- --out=DIR

const C := "get_tree().root.get_node('PubBillCheck')"
const SI := "_interior_manager._service_interior"
const RULES := preload("res://core/systems/pub_rules.gd")
const ORDERS := preload("res://scripts/food/orders.gd")
const BUSINESS := preload("res://scripts/business/business_runtime.gd")


func why(tag: String) -> void:
	var tr = get_tree().get_first_node_in_group("taprooms")
	var key: String = _main.get("_interior_manager").get("_service_interior").get("_upkeep_key")
	var now: int = tr.now_min()
	var served: Dictionary = tr.site(key)["served"]
	print("PUBBILL %s now=%d tickets=%d bills=%d visitors=%d" % [tag, now, tr.tickets(key).size(), tr.bills(key).size(), ORDERS.visitors(key).size()])
	for v in ORDERS.visitors(key):
		var visit := str(v["visit"])
		var arch := str(v["archetype"])
		var rt: Array = RULES.tickets_for(visit, arch, int(v.get("figures", 1)), int(v.get("arrive", now)), served, now)
		var b: Dictionary = RULES.bill_for(visit, arch, int(v.get("figures", 1)), int(v.get("arrive", now)), served, now)
		var tab: Dictionary = RULES.tab_of(visit, served)
		var line := "PUBBILL   %s %s fig=%d arrive=%d stay=%d rounds=%d tab_n=%d last_at=%d more=%s rules_tix=%s bill=%s hand=%d" % [visit, arch, int(v.get("figures", 1)), int(v.get("arrive", now)),
			RULES.stay(arch), RULES.rounds(arch), int(tab.get("n", 0)), int(tab.get("last_at", -1)),
			str(RULES.more_rounds(visit, arch, int(v.get("figures", 1)), int(v.get("arrive", now)), served, now)),
			str(rt.map(func(t): return "%s since=%d takes=%s" % [str(t["id"]), int(t["since"]), str(BUSINESS.takes_orders_at(key, int(t["since"])))])),
			"{}" if b.is_empty() else str(b.get("id", "")), int(ORDERS._served.get(visit, 0))]
		print(line)


func _ready() -> void:
	super._ready()
	var TR := "get_tree().get_first_node_in_group('taprooms')"
	var K := SI + "._upkeep_key"
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["eval", "_interior_manager._building_interior.close_interior()"],
		["money", 40000], ["clear", 5, 5, 15, 10], ["build", "pub", 6, 6, 0],
		["build", "cabin_1", 6, 11, 0], ["build", "cabin_1", 9, 11, 0], ["build", "tent_1", 12, 11, 0],
		["prep_all"], ["book", "Novak family", "family", 4, 3], ["prep_all"], ["book", "Pepa", "drunk", 2, 3], ["prep_all"], ["book", "Babi", "picker", 1, 3],
		["hours", 0.4], ["checkin"], ["hours", 3.0], ["wait", 6.0],
		["eval", "debug_send_guests_to('pub', 240)"], ["wait", 1.0],
		["player", 7, 9, 180.0], ["eval", "_interior_manager.handle_structure_interact(debug_structure_of_type('pub'))"], ["wait", 4.0],
		["eval", SI + "._open_station('back')"], ["wait", 1.0],
		["eval", C + ".why('start')"],
		["eval", TR + ".debug_pour_some(" + K + ", 5)"], ["wait", 1.0],
		["eval", C + ".why('poured')"],
		["hours", 0.5], ["wait", 2.0], ["eval", C + ".why('+30')"], ["shot", "b0_bills"],
		["hours", 0.5], ["wait", 2.0], ["eval", C + ".why('+60')"], ["shot", "b1"],
		["hours", 0.5], ["wait", 2.0], ["eval", C + ".why('+90')"], ["shot", "b2"],
	]
