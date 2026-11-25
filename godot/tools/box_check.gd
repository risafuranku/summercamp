extends Node

## Headless check for the van's boxes (docs/businesses.md, Rozhodnutí 25. 11., kolo 2: „Krabice
## u závory“; core/state/actions.gd biz_unload / biz_box_*): an order due today goes onto the
## pallet as a box for its place (not on the shelves), one taken is nobody else's, set down it
## lies where it was put, back by the pallet it is on it, carried in its goods are on the
## shelves (a lot of today's) and the box is gone; an order for tomorrow stays an order.
##
##   godot --headless --path godot res://tools/box_check.tscn

var _failures: Array[String] = []


func _ready() -> void:
	var st = CoreRoot.get_state()
	var act = CoreRoot.actions
	st.biz = {}
	st.money = 100000
	st.day = 3
	var key := "5:5"
	var site: Dictionary = act.biz_site(key, "pub")
	_expect(not site.is_empty(), "a pub's books")
	var goods: Dictionary = {}
	for g in preload("res://core/systems/business_rules.gd").goods("pub"):
		goods[g] = 1
		break
	var g0: String = str(goods.keys()[0])
	site["stock"][g0] = 0
	st.biz["orders"].append({"key": key, "goods": goods, "cost": 10, "due_day": 3})
	st.biz["orders"].append({"key": key, "goods": goods, "cost": 10, "due_day": 4})

	# The van unloads today's.
	_expect(act.biz_unload(3) == 1, "one box off the van today")
	var boxes: Array = act.biz_boxes()
	_expect(boxes.size() == 1 and str(boxes[0]["key"]) == key and str(boxes[0]["by"]) == "", "a box for the pub on the pallet (%s)" % [boxes])
	_expect((st.biz["orders"] as Array).size() == 1 and int(st.biz["orders"][0]["due_day"]) == 4, "tomorrow's order stays an order")
	_expect(int(site["stock"].get(g0, 0)) == 0, "nothing on the shelves yet")
	var id := int(boxes[0]["id"])

	# Taken: nobody else's.
	_expect(act.biz_box_carry(id, "p1"), "taken up")
	_expect(not act.biz_box_carry(id, "p2"), "not by another at the same time")
	_expect(not act.biz_box_carry(id, "sfranta", 50.0), "nor by a hand")
	# Set down: it lies there; by the pallet it is on it again.
	_expect(act.biz_box_down(id, Vector3(3, 0, 4)), "set down")
	_expect(str(act.biz_boxes()[0]["by"]) == "" and (act.biz_boxes()[0].get("at", []) as Array) == [3.0, 0.0, 4.0], "lying where it was put")
	act.biz_box_carry(id, "p2")
	act.biz_box_down(id, Vector3.ZERO, true)
	_expect(not act.biz_boxes()[0].has("at"), "back on the pallet")
	# A hand's fetch keeps the hour it began.
	_expect(act.biz_box_carry(id, "sfranta", 50.5) and float(act.biz_boxes()[0]["t0"]) == 50.5, "a hand fetching it from 50.5")

	# Carried in: on the shelves, the box gone.
	_expect(act.biz_box_in(id), "carried in")
	_expect(act.biz_boxes().is_empty(), "the box is gone")
	_expect(int(site["stock"].get(g0, 0)) > 0, "its goods on the shelves (%s %d)" % [g0, int(site["stock"].get(g0, 0))])
	_expect(not act.biz_box_in(id), "once")

	if _failures.is_empty():
		print("BOX CHECK: PASS")
	else:
		print("BOX CHECK: FAIL")
		for f in _failures:
			print("  - " + f)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
