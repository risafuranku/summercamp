extends "res://tools/shot_driver.gd"

## What was left of the pass of 7. 11.: the village made as the game opens a share at a time,
## hidden past where you can see it; the shops' two rooms; the motel's rooms a few at a time;
## the night's things going at dawn only when you look away; the bread on its days; the fire
## with the wind. Windowed. Lines "PASS8 ...", "PASS8: PASS".
##   APPDATA=<dir> godot --path godot --audio-driver Dummy --resolution 1366x768 res://tools/pass8_check.tscn -- --out=DIR

const C := "get_tree().root.get_node('Pass8Check')"
const TT := "_interior_manager.town_trip()"

var fails := 0


func _ok(what: String, good: bool, more := "") -> void:
	print("PASS8 %s %s %s" % ["ok  " if good else "FAIL", what, more])
	if not good:
		fails += 1


func trip():
	return _main.get("_interior_manager").call("town_trip")


func pl() -> Node3D:
	return _main.get("_player")


func brain():
	var list: Array = _main.get("_enemy_brains")
	return list[0] if not list.is_empty() else null


# ── the village ─────────────────────────────────────────────

func town_ready() -> void:
	var t = trip().get("_town")
	_ok("the village is there as the game opens", t != null)
	if t != null:
		_ok("hidden from the camp", not bool(t.visible) and not bool(t.near))
		_ok("and still", int(t.process_mode) == Node.PROCESS_MODE_DISABLED)
		var due: Dictionary = t.spots["motel_block"].get("_rooms_due")
		_ok("every room of the motel made", due.size() <= 1, str(due.keys()))


func town_shows() -> void:
	var t = trip().get("_town")
	_ok("it shows when you are there", bool(t.visible) and bool(t.near) and int(t.process_mode) == Node.PROCESS_MODE_INHERIT)


func shops_turn() -> void:
	var t = trip().get("_town")
	var j: Node3D = t.spots["jednota"]
	t.call("_update_jednota", 12.0)
	var open: Node3D = j.get_node("SalesRoom")
	var t0 := Time.get_ticks_usec()
	t.call("_update_jednota", 18.0)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	var shut: Node3D = j.get_node("SalesRoom")
	_ok("the shop shows its other room at the hour", open != shut and shut.visible and not open.visible, "%.2f ms" % ms)
	_ok("and that costs nothing", ms < 2.0)
	t.call("_update_jednota", 12.0)
	_ok("and back", j.get_node("SalesRoom") == open and open.visible and not shut.visible)
	_ok("the view finds it", t.spots["jednota_shell"] == open)
	var p: Node3D = t.spots["pub"]
	t.call("_update_pub", 12.0)
	var street = p.get_node("Taproom").get_node_or_null("PubStreet")
	_ok("the pub's street life is in its open room", street != null)
	t.call("_update_pub", 23.5)
	t.set_night(true)
	_ok("and quiet when it shuts", street != null and not bool(street.is_processing()))
	t.call("_update_pub", 12.0)
	_ok("and on when it opens", street != null and bool(street.is_processing()))
	t.set_night(false)


func motel_queue() -> void:
	var t = trip().get("_town")
	var b = t.spots["motel_block"]
	var key_before := str(b.shells.get(1, {}).get("key", ""))
	b.marks[1] = {"curtain": 0.13}
	var t0 := Time.get_ticks_usec()
	b.set_state(12.0, 1)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	_ok("a room's change is only noted on the hour", (b.get("_rooms_due") as Dictionary).has(1) and ms < 6.0, "%.2f ms" % ms)
	_ok("nothing rebuilt yet", str(b.shells.get(1, {}).get("key", "")) == key_before)


func motel_made() -> void:
	var t = trip().get("_town")
	var b = t.spots["motel_block"]
	_ok("and made soon after with you near", not (b.get("_rooms_due") as Dictionary).has(1))
	b.marks.erase(1)


# ── dawn ────────────────────────────────────────────────────

func put(dist: float) -> void:
	var b = brain()
	var cam: Camera3D = pl().get_node("Head/Camera3D")
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	var at: Vector3 = pl().global_position + fwd.normalized() * dist
	b._body.visible = true
	b._body.global_position = Vector3(at.x, pl().global_position.y, at.z)


var _b


func dawn_in_view() -> void:
	_b = brain()
	# Turned to where nothing stands in the way (the test camp's lamps).
	for i in 12:
		put(9.0)
		if not _b._ray_blocked(pl().get_node("Head/Camera3D").global_position, _b._body.global_position + Vector3.UP * 1.1):
			break
		pl().rotate_y(TAU / 12.0)
	_main.call("_enemies_leave_at_dawn")
	_ok("in view at dawn it stays", (_main.get("_dawn_leaving") as Array).has(_b) and (_main.get("_enemy_brains") as Array).is_empty())


func still_there() -> void:
	_ok("as long as you look", (_main.get("_dawn_leaving") as Array).has(_b) and _b._body != null and _b._body.visible, "t %.1f" % _b._dawn_t)


func gone() -> void:
	_ok("and goes when you look away", not (_main.get("_dawn_leaving") as Array).has(_b))


func dawn_on_you() -> void:
	_b = brain()
	put(2.0)
	_main.call("_enemies_leave_at_dawn")
	_ok("on you it goes with the night", not (_main.get("_dawn_leaving") as Array).has(_b) and (_main.get("_enemy_brains") as Array).is_empty())


# ── the bread ───────────────────────────────────────────────

var _bread_on := 1
var _bread_off := 2


func bread_days() -> void:
	_bread_on = -1
	_bread_off = -1
	for d in range(1, 10):
		var wd := str(Season.WEEKDAYS[int(Season.date_of(d)["wd"])])
		if wd == "Tuesday" and _bread_on < 0:
			_bread_on = d
		if wd == "Wednesday" and _bread_off < 0:
			_bread_off = d
	print("PASS8 tuesday day %d wednesday day %d" % [_bread_on, _bread_off])


func on_bread_day() -> void:
	_main.call("debug_jump_to", _bread_on, 6.9)


func off_bread_day() -> void:
	_main.call("debug_jump_to", _bread_off, 6.9)


func van(want: bool) -> void:
	var s = trip().get("_town").spots["street"]
	s.update(6.9, 0.016)
	_ok("the bread van: %s" % str(want), bool(s.get("_van").visible) == want and bool(s.get("_bread_day")) == want)


# ── the fire ────────────────────────────────────────────────

func fire() -> void:
	var fires := get_tree().get_nodes_in_group("campfire")
	_ok("a fire to look at", not fires.is_empty())
	if fires.is_empty():
		return
	var f = fires[0]
	var wv = _main.get("_weather_visuals")
	wv.wind_dir = Vector2(1, 0)
	wv.set("_wind_now", 1.0)
	f.call("_air")
	var a: Vector3 = f.get("_wind")
	wv.wind_dir = Vector2(-1, 0)
	f.call("_air")
	var b: Vector3 = f.get("_wind")
	_ok("the fire goes with the wind", a.length() > 0.1 and a.dot(b) < 0.0, "%s %s" % [str(a), str(b)])


func verdict() -> void:
	print("PASS8: %s" % ("PASS" if fails == 0 else "%d FAILURE(S)" % fails))


func _ready() -> void:
	super._ready()
	var close := ["eval", "_interior_manager._building_interior.close_interior()"]
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 8.0], close, ["wait", 1.0],
		["eval", C + ".town_ready()"],
		["eval", "_build_test_camp('')"], ["wait", 2.0],
		# Dawn.
		["player", 15, 12, 180.0], ["eval", "debug_jump_to(2, 23.0)"], ["wait", 1.0], ["eval", "_stop_active_enemy_brain()"], ["wait", 0.3],
		["eval", "debug_spawn_enemy('stalker', 3)"], ["wait", 0.5], ["eval", C + ".dawn_in_view()"], ["shot", "dawn_stays"],
		["wait", 3.5], ["eval", C + ".still_there()"], ["eval", "_player.rotate_y(PI)"], ["wait", 0.6], ["eval", C + ".gone()"],
		["eval", "debug_spawn_enemy('stalker', 3)"], ["wait", 0.5], ["eval", C + ".dawn_on_you()"], ["wait", 0.5],
		["eval", C + ".fire()"],
		# Liblice.
		["eval", TT + "._ensure_town()"], ["eval", TT + "._put_player(%s._town.arrive_spot())" % TT], ["wait", 2.0],
		["eval", C + ".town_shows()"], ["eval", C + ".shops_turn()"],
		["eval", C + ".motel_queue()"], ["wait", 1.0], ["eval", C + ".motel_made()"],
		["eval", C + ".bread_days()"], ["eval", C + ".on_bread_day()"], ["wait", 0.3], ["eval", C + ".van(true)"],
		["eval", C + ".off_bread_day()"], ["wait", 0.3], ["eval", C + ".van(false)"],
		["eval", C + ".verdict()"], ["eval", "get_tree().quit()"],
	]
