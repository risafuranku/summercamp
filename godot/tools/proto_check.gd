extends Node

## Headless check for PROTOTYP 540, the bistro cellar's machine (DESIGN.md §7b "The bistro";
## core/systems/bistro_rules.gd proto_*, scripts/bistro/kitchen.gd _proto,
## scripts/bistro/machine_station.gd).
##
##   godot --headless --path godot res://tools/proto_check.tscn
##
## Run as a SCENE (CoreRoot / EventBus autoloads). Asserts:
## - it is awake at night, and from eight in the evening only while the bistro is open late;
## - a night is the day it began on; a sack lies there always the night after the camp
##   woke without somebody (a guest gone at dawn), else about one night in five;
## - lifted into the hopper at the machine's station, it runs; by morning its tray holds
##   meat for twenty goulashes, in the stock as a lot of that day (not past the shelf's cap);
## - a sack nobody lifted is gone in the morning and gives nothing; the hands never feed it.

const RULES := preload("res://core/systems/bistro_rules.gd")
const BIZ_RULES := preload("res://core/systems/business_rules.gd")
const LAYOUT := preload("res://scripts/bistro/bistro_layout.gd")
const KEY := "6:6"

var _failures: Array[String] = []


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var state = CoreRoot.get_state()
	var a = CoreRoot.actions
	state.grid.cells.clear()
	state.biz = {}
	state.money = 5000
	state.day = 5
	GuestManager._last_known_day = 5
	GuestManager._last_known_hour = 22
	GuestManager._last_known_minute = 0
	state.grid.occupy_cell(Vector2i(6, 6), "restaurant", "restaurant_6_6", Vector2i(6, 6))
	var site: Dictionary = a.biz_site(KEY, "restaurant")
	_expect(not site.is_empty(), "a bistro's books")

	# The rules.
	_expect(RULES.proto_awake(22, false) and RULES.proto_awake(3, false), "awake in the night")
	_expect(not RULES.proto_awake(20, false) and RULES.proto_awake(20, true), "from eight only when open late")
	_expect(not RULES.proto_awake(12, true) and not RULES.proto_awake(6, false), "dead by day")
	_expect(RULES.proto_night(5, 23) == 5 and RULES.proto_night(6, 3) == 5, "a night is the day it began on")
	_expect(RULES.proto_sack(KEY, 9, true), "always a sack after the camp woke without somebody")
	var nights := 0
	for n in 200:
		if RULES.proto_sack(KEY, n, false):
			nights += 1
	_expect(nights >= 20 and nights <= 70, "else about one night in five (%d of 200)" % nights)

	# The kitchen's machine.
	var k = get_tree().get_first_node_in_group("kitchens")
	if k == null:
		k = load("res://scripts/bistro/kitchen.gd").new()
		get_tree().root.add_child(k)
	k.set_process(false)
	k.site(KEY)
	# A guest gone at dawn: that night has its sack.
	GuestManager._last_known_hour = 5
	EventBus.guest_state_changed.emit(901, "sleep", "departed")
	_expect(int(k.site(KEY)["proto"]["taken"]) == 5, "the morning the camp woke without somebody is remembered")
	GuestManager._last_known_hour = 22
	k._proto(KEY)
	var st: Dictionary = k.proto_state(KEY)
	_expect(bool(st["awake"]) and bool(st["sack"]) and not bool(st["running"]), "that night the sack lies in front of it (%s)" % str(st))

	# Lifted in at the station.
	var room := Node3D.new()
	add_child(room)
	var v3: Node3D = load("res://scripts/bistro/machine_station.gd").new()
	var surf: Dictionary = LAYOUT.SURFACES["machine"]
	v3.set("building_key", KEY)
	v3.set("station", "machine")
	v3.set("surf_at", surf["at"])
	v3.set("surf_size", surf["size"])
	v3.set("surf_yaw", float(surf["yaw"]))
	v3.set("surf_flat", bool(surf["flat"]))
	v3.set("state", k)
	room.add_child(v3)
	await get_tree().process_frame
	_expect(v3.debug_feed(), "the sack lifted into the hopper")
	st = k.proto_state(KEY)
	_expect(bool(st["running"]) and not bool(st["sack"]) and int(k.site(KEY)["proto"]["fed"]) == 5, "it runs (%s)" % str(st))
	k._proto(KEY)
	_expect(int(k.site(KEY)["proto"]["sack"]) == 5, "no second sack the same night")

	# Morning: the tray, the stock.
	var before := int(site["stock"]["goulash"])
	state.day = 6
	GuestManager._last_known_day = 6
	GuestManager._last_known_hour = 7
	k._proto(KEY)
	var cap := BIZ_RULES.cap_of("rest", "goulash", site)
	_expect(int(site["stock"]["goulash"]) == mini(cap, before + RULES.PROTO_MEAT), "meat for twenty goulashes in the stock (%d -> %d)" % [before, int(site["stock"]["goulash"])])
	var lots: Array = site["lots"]["goulash"]
	_expect(not lots.is_empty() and int(lots[lots.size() - 1][1]) == 6, "a lot of today's")
	st = k.proto_state(KEY)
	_expect(bool(st["meat"]) and not bool(st["awake"]), "the tray heaped in the morning (%s)" % str(st))
	var after := int(site["stock"]["goulash"])
	k._proto(KEY)
	_expect(int(site["stock"]["goulash"]) == after, "once a morning")

	# A sack nobody lifted gives nothing and is gone by morning.
	GuestManager._last_known_hour = 22
	k.site(KEY)["proto"]["taken"] = 6
	k._proto(KEY)
	_expect(bool(k.proto_state(KEY)["sack"]) and not bool(k.proto_state(KEY)["meat"]), "the next night's sack; the tray clean in the dark")
	state.day = 7
	GuestManager._last_known_day = 7
	GuestManager._last_known_hour = 7
	var before2 := int(site["stock"]["goulash"])
	k._proto(KEY)
	_expect(int(site["stock"]["goulash"]) == before2 and not bool(k.proto_state(KEY)["sack"]) and not bool(k.proto_state(KEY)["meat"]), "nobody lifted it: nothing, and it is gone")

	print("")
	if _failures.is_empty():
		print("PROTO CHECK: PASS")
		get_tree().quit(0)
	else:
		print("PROTO CHECK: %d FAILURE(S)" % _failures.size())
		for f in _failures:
			print("  - " + f)
		get_tree().quit(1)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
