extends RefCounted

## The main menu's secret test nights (L): a fresh sandbox camp with a small camp built in
## it and guests of the kind that brings the thing (`_build_test_camp`), the clock on the
## second night at 20:00 and the chosen thing already out (`main.debug_spawn_enemy` ids).
## Nothing is saved.
## (Out of main.gd 15. 11.: main routes the title's L page here and keeps the camp's flag,
## main._test_night.)

const MAIN_MENU_SCRIPT = preload("res://scripts/ui/main_menu.gd")
const BALANCE_CONFIG = preload("res://core/balance/balance_config.gd")
const BUS_TIMES = preload("res://scripts/town/bus_timetable.gd")

var main: Node


func _init(main_node: Node) -> void:
	main = main_node


func start(enemy_id: String) -> void:
	if enemy_id == "content":
		await start_content_reel()
		return
	if enemy_id == "bus":
		await start_bus()
		return
	if enemy_id == TEST_BUSINESSES:
		await start_businesses()
		return
	await main._start_new_camp(true, enemy_id)
	for _i in 60:
		if not main._menu_mode:
			break
		await main.get_tree().process_frame
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	build_camp(enemy_id)
	await main.get_tree().process_frame
	# The jump runs the night's start (its roll stops every brain), so the thing comes after;
	# a test night after a test night is the same night 2 again.
	main._stop_active_enemy_brain()
	main._night_roll.last_rolled_night_id = -99999
	main.debug_jump_to(2, BALANCE_CONFIG.NIGHT_START_HOUR)
	if enemy_id == main.TEST_SEWER:
		main._test_sewer_wait = 0.0
		if main._player != null and is_instance_valid(main._player):
			main._player.rotate_y(PI)
		if main._hud_manager != null:
			main._hud_manager.push_status("Test night: the sewer breaks again whenever it is mended.", 2)
		return
	# The boy at his worst (heavy: in the pipes both him and the raccoon).
	main.debug_spawn_enemy(enemy_id, 4 if enemy_id == "child" else 3)
	# It is one of the test camp's guests, turned (gone in the morning if it gets you).
	if not main._enemy_brains.is_empty():
		var nb = main._enemy_brains.back()
		var ne: Dictionary = nb.get("_night_entry")
		ne["guest"] = main._night_roll.pick_turned_guest(str(TEST_NIGHT_GUESTS.get(enemy_id, "")))
		# The boy's job at once, not an hour into the night; his places in turn.
		if nb.get("soon") != null:
			nb.set("soon", true)
		# The granny is out whatever the hour (she keeps to the small hours).
		if nb.get("soon") != null and enemy_id == "basket":
			nb.set("soon", true)
		if nb.has_method("force_place"):
			var where: String = TEST_BOY_PLACES[boy_turn % TEST_BOY_PLACES.size()]
			boy_turn += 1
			nb.force_place(where)
			enemy_id = "child_" + where
	# The spawn faces the office wall (a new camp starts at the desk): turn to the camp.
	if main._player != null and is_instance_valid(main._player):
		main._player.rotate_y(PI)
	var label := enemy_id
	for entry in MAIN_MENU_SCRIPT.TEST_NIGHTS:
		if str(entry["id"]) == enemy_id:
			label = str(entry["text"])
	if main._hud_manager != null:
		if enemy_id.begins_with("child_"):
			main._hud_manager.push_status(str({"child_corn": "Test night: the boy is lost in the corn.",
				"child_breaker": "Test night: the boy is at the generator's board.",
				"child_sewer": "Test night: the boy is down the sewer."}.get(enemy_id, "")), 2)
		else:
			main._hud_manager.push_status("Test night: the %s is out." % label, 2)


## The bus test (L, "Bus to Liblice"): a fresh sandbox camp by day, the warden at the
## camp's stop with money in the pocket just as the 13:50 comes up the road; from there
## everything as in the game (the ticket machine, the ride, the request stop at Podlesi,
## Lesna, the way back). Nothing is saved.
func start_bus() -> void:
	await main._start_new_camp(true, "bus")
	for _i in 60:
		if not main._menu_mode:
			break
		await main.get_tree().process_frame
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	CoreRoot.actions.add_money(300)
	# A few seconds before it pulls up (it comes in over town_trip.IN_HOURS).
	main.debug_jump_to(1, BUS_TIMES.CAMP_ARRIVE[1] - 0.17)
	var trip = main._interior_manager.town_trip() if main._interior_manager != null else null
	if trip != null and trip.has_method("_put_player") and trip._road() != null:
		trip._put_player(trip._road().wait_spot())
	if main._hud_manager != null:
		main._hud_manager.push_status("Test: the 380 is coming up the road. Ticket from the yellow machine by the stop, punch it on board.", 2)


## The businesses' test camp (the title screen's L page, "Businesses"; the user 21. 10.:
## "every business, the corn, the pub, the bistro, the Jednota, and lots of people, to try
## the minigames"): a fresh camp at mid-morning, the four on paths up from the gate (each
## stocked as a new place is), tents and cabins round them full, the guests already hungry
## and thirsty, every blueprint open. Built through the real builder; what does not fit
## this camp's trees and lake is left out.
const TEST_BUSINESSES := "podniky"


## The content reel (the title screen's L page): the businesses' camp, then a day of its
## best scenes, L for the next (scripts/content_reel.gd).
func start_content_reel() -> void:
	await start_businesses(true)
	var reel = load("res://scripts/content_reel.gd").new()
	reel.name = "ContentReel"
	main.get_tree().root.add_child(reel)
	reel.start(main)


func start_businesses(quiet := false) -> void:
	await main._start_new_camp(true, TEST_BUSINESSES)
	for _i in 60:
		if not main._menu_mode:
			break
		await main.get_tree().process_frame
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	main.debug_jump_to(1, 10.5)
	CoreRoot.actions.add_money(60000)
	var g: Vector2i = main.world_generator.gate_tile() if main.world_generator != null and main.world_generator.has_method("gate_tile") else Vector2i(12, 0)
	for x0 in range(g.x - 9, g.x + 9, 5):
		for y0 in range(4, 19, 5):
			EventBus.RequestDemolish.emit(Rect2i(x0, y0, 5, 5))
	for y in range(4, 18):
		EventBus.RequestBuild.emit("path", Vector2i(g.x, y), 0)
	for x in range(g.x - 8, g.x + 9):
		if x != g.x:
			EventBus.RequestBuild.emit("path", Vector2i(x, 8), 0)
			EventBus.RequestBuild.emit("path", Vector2i(x, 13), 0)
	var plan := [
		["corn_stand", Vector2i(g.x + 1, 6)], ["pub", Vector2i(g.x + 1, 9)], ["restaurant", Vector2i(g.x + 4, 9)], ["vecerka", Vector2i(g.x - 4, 9)],
		["toilet_block", Vector2i(g.x + 3, 6)], ["shower_block", Vector2i(g.x + 4, 6)], ["toilet_block", Vector2i(g.x - 1, 12)],
		["picnic_table", Vector2i(g.x + 2, 5)], ["picnic_table", Vector2i(g.x + 7, 9)], ["picnic_table", Vector2i(g.x + 7, 10)], ["bonfire", Vector2i(g.x + 7, 6)],
		["lamp_post", Vector2i(g.x - 1, 7)], ["lamp_post", Vector2i(g.x + 1, 12)], ["lamp_post", Vector2i(g.x - 6, 7)], ["lamp_post", Vector2i(g.x + 6, 12)],
		["cabin_1", Vector2i(g.x - 8, 14)], ["cabin_1", Vector2i(g.x - 5, 14)], ["cabin_1", Vector2i(g.x + 2, 14)], ["cabin_1", Vector2i(g.x + 5, 14)],
	]
	for x in [g.x - 2, g.x - 3, g.x - 5, g.x - 6, g.x - 7]:
		plan.append(["tent_1", Vector2i(x, 5)])
		plan.append(["tent_1", Vector2i(x, 6)])
	for x in [g.x - 3, g.x - 5, g.x - 7, g.x + 3, g.x + 5]:
		plan.append(["tent_1", Vector2i(x, 12)])
	main._goggle.check_guests(99)
	for item in plan:
		EventBus.RequestBuild.emit(str(item[0]), item[1], 0)
	# Lodgings go up a level only as upgrades (a couple to a tent, a family to a cabin).
	for item in plan:
		if str(item[0]) in ["tent_1", "cabin_1"] and main._interior_manager != null:
			main._interior_manager.map_upgrade(item[1], str(item[0]))
	var parties := [["Novak", "quiet_guy", 2], ["Pepa", "drunk", 2], ["Lojza", "drunk", 2], ["Kristyna", "cheap_chick", 2], ["Denisa", "cheap_chick", 2],
		["Bobr", "tramp", 2], ["Svoboda family", "family", 3], ["Kral family", "family", 3], ["Mr Prochazka", "picker", 2], ["Dvorak", "quiet_guy", 2],
		["Kecal", "tramp", 2], ["Mrs Benesova", "picker", 2], ["Horak family", "family", 3], ["Vesely", "drunk", 2], ["Marek", "drunk", 2], ["Jana", "cheap_chick", 2],
		["Fiala family", "family", 3], ["Zeman", "quiet_guy", 2]]
	for p in parties:
		GuestManager.debug_check_in_party(str(p[0]), str(p[1]), int(p[2]), 3)
	GuestManager.debug_want_food(55.0, 85.0)
	# On the path just in from the gate, the businesses ahead.
	if main._player != null and is_instance_valid(main._player) and main.grid_manager != null:
		main._player.global_position = main.grid_manager.grid_to_world(Vector2i(g.x, 5)) + Vector3(0, 0.2, 0)
		main._player.rotation.y = PI
	if main._hud_manager != null and not quiet:
		main._hud_manager.push_status("Test: every business open and a full camp. The work is at their stations.", 2)


## Which guests bring which test night's thing (main_menu.TEST_NIGHTS ids).
## The boy's test night takes his places in turn (corn, board, pipes).
const TEST_BOY_PLACES := ["corn", "breaker", "sewer"]
static var boy_turn := 0
const TEST_NIGHT_GUESTS := {"silent_man": "quiet_guy", "tourist": "drunk", "girl": "cheap_chick", "whistler": "tramp", "child": "family", "basket": "picker"}


## A test night's camp (playtest 18. 10.: "not an empty map"): north of the office a path
## up from the gate with a cross path, lamps along them, tents, a cabin, the toilets, a
## fire; then the guests of the kind that brings the thing, let in at once (and one of
## another kind, so the camp is not only them). Built through the real builder; what does
## not fit this camp's trees and lake is just left out.
func build_camp(enemy_id: String) -> void:
	if main.world_generator == null or not main.world_generator.has_method("gate_tile"):
		return
	CoreRoot.actions.add_money(60000)
	var g: Vector2i = main.world_generator.gate_tile()
	for r in [Rect2i(g.x - 7, 4, 5, 5), Rect2i(g.x - 2, 4, 5, 5), Rect2i(g.x + 3, 4, 5, 5), Rect2i(g.x - 7, 9, 5, 5), Rect2i(g.x - 2, 9, 5, 5), Rect2i(g.x + 3, 9, 5, 5)]:
		EventBus.RequestDemolish.emit(r)
	for y in range(5, 13):
		EventBus.RequestBuild.emit("path", Vector2i(g.x, y), 0)
	for x in range(g.x - 6, g.x + 7):
		if x != g.x:
			EventBus.RequestBuild.emit("path", Vector2i(x, 8), 0)
	var plan := [
		["lamp_post", Vector2i(g.x, 6)], ["lamp_post", Vector2i(g.x - 5, 8)], ["lamp_post", Vector2i(g.x + 5, 8)], ["lamp_post", Vector2i(g.x, 12)],
		["tent_1", Vector2i(g.x - 5, 5)], ["tent_1", Vector2i(g.x - 3, 5)], ["tent_1", Vector2i(g.x - 5, 10)], ["tent_1", Vector2i(g.x - 3, 10)],
		["cabin_1", Vector2i(g.x + 2, 5)], ["cabin_1", Vector2i(g.x + 2, 10)],
		["toilet_block", Vector2i(g.x + 5, 5)], ["bonfire", Vector2i(g.x + 5, 10)], ["picnic_table", Vector2i(g.x - 2, 12)],
	]
	if enemy_id == main.TEST_SEWER:
		main._test_sewer_at = Vector2i(g.x + 6, 5)
		plan.append(["sewer", main._test_sewer_at])
	for item in plan:
		EventBus.RequestBuild.emit(str(item[0]), item[1], 0)
	var arch := str(TEST_NIGHT_GUESTS.get(enemy_id, ""))
	if arch.is_empty():
		return
	var names := {"quiet_guy": ["Novak", "Dvorak"], "drunk": ["Pepa", "Lojza"], "cheap_chick": ["Kristyna", "Denisa"], "tramp": ["Bobr", "Kecal"], "family": ["Svoboda family", "Kral family"], "picker": ["Mr Prochazka", "Mrs Benesova"]}
	for n in names.get(arch, ["Guest"]):
		GuestManager.debug_check_in_party(str(n), arch, 1, 3)
	GuestManager.debug_check_in_party("Mr Vesely", "quiet_guy" if arch != "quiet_guy" else "drunk", 1, 3)
