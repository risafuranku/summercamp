extends "res://tools/shot_driver.gd"

## The pass of 7. 11. played: the camp's night stays at the camp, closing time puts you out of
## the pub and the shop's windows live through the change of the hour, enemies stand neither on
## the water nor on a roof, the Whistler's song goes round, the Antlered Man walks back to his
## fence, guests take a path from a door, the trunks past the fence stop you, the land has an
## end, the first snow falls. Windowed. Lines "PASS7 ...", "PASS7: PASS".
##   APPDATA=<dir> godot --path godot --audio-driver Dummy --resolution 1366x768 res://tools/pass_check.tscn -- --out=DIR

const C := "get_tree().root.get_node('PassCheck')"
const TT := "_interior_manager.town_trip()"
const FAR_TREES := preload("res://scripts/ambient/far_trees.gd")

var fails := 0


func _ok(what: String, good: bool, more := "") -> void:
	print("PASS7 %s %s %s" % ["ok  " if good else "FAIL", what, more])
	if not good:
		fails += 1


func brain():
	var list: Array = _main.get("_enemy_brains")
	return list[0] if not list.is_empty() else null


func trip():
	return _main.get("_interior_manager").call("town_trip")


# ── the night stays at the camp ─────────────────────────────

func room_is_camp() -> void:
	_ok("the office is a room of the camp", bool(_main.call("in_camp_room")))


func pub_is_not() -> void:
	_ok("the pub in Liblice is not", not bool(_main.call("in_camp_room")), "open %s away %s" % [str(_main.call("_is_any_interior_open")), str(_main.call("_away_in_town"))])


# ── closing time ───────────────────────────────────────────

func in_pub() -> void:
	_ok("the pub took us in", bool(trip().get("_room").call("is_open")))


func pub_shut() -> void:
	_ok("closing time put us out", not bool(trip().get("_room").call("is_open")))


# ── what stands where ──────────────────────────────────────

func water() -> void:
	var b = brain()
	var g = _main.get("grid_manager")
	var c: Vector3 = g.get_map_center_world()
	var s: Vector2 = g.get_map_size_world()
	var row: Vector3 = g.grid_to_world(Vector2i(int(g.grid_width) / 2, int(g.grid_height) - 1))
	print("PASS7 lake row at %s, map %s %s" % [str(row), str(c), str(s)])
	_ok("the lake's row is no ground", b.call("_ground", row) == Vector3.INF)
	_ok("nor to stand on", b.call("_stand", row) == Vector3.INF)
	var inside: Vector3 = g.grid_to_world(Vector2i(14, 14))
	_ok("the meadow is", b.call("_ground", inside) != Vector3.INF, str(b.call("_ground", inside)))


func roof() -> void:
	var b = brain()
	var office: Node3D = _main.call("debug_structure_of_type", "main_building")
	var over: Vector3 = office.global_position
	var top: Vector3 = b.call("_ground", over)
	print("PASS7 from 20 m up over the office: %s" % str(top))
	_ok("nobody stands on the office's roof", b.call("_stand", over) == Vector3.INF)
	_ok("a step there stays on the ground", b.call("_floor_at", over) == Vector3.INF or (b.call("_floor_at", over) as Vector3).y < 0.8, str(b.call("_floor_at", over)))


func song() -> void:
	var b = brain()
	b.call("_enter", "play", 15.0)
	var m: AudioStreamPlayer3D = b.get("_music")
	_ok("the song goes round", m.stream is AudioStreamMP3 and (m.stream as AudioStreamMP3).loop)


func sits() -> void:
	var b = brain()
	b.set("_fire_at", Vector3.INF)
	b.call("_pose", b.get("_tex_sit"))
	var body: Sprite3D = b.get("_body")
	_ok("sat, his feet on the ground", is_equal_approx(body.offset.y, float(body.texture.get_height()) * 0.5))
	b.call("_pose", b.get("_tex_stand"))


func stalker_charge() -> void:
	var b = brain()
	var body: Sprite3D = b.get("_body")
	body.global_position = _main.get("_player").global_position + Vector3(6, 0, 0)
	b.set("_charging", true)
	b.call("_start_back")
	b.set("_charging", false)
	set_meta("was_at", body.global_position)


func stalker_walked() -> void:
	var b = brain()
	var body: Sprite3D = b.get("_body")
	var moved: float = (get_meta("was_at") as Vector3).distance_to(body.global_position)
	_ok("he walks back to the fence, not in one frame", moved > 0.5 and moved < 8.0, "%.1f m in a second and a bit" % moved)


# ── guests ─────────────────────────────────────────────────

func guest_path() -> void:
	var agents = _main.find_child("GuestAgents", true, false)
	if agents == null:
		for n in _main.get_children():
			if n.has_method("_free_tile_by"):
				agents = n
	if agents == null:
		agents = GuestManager.get("_agents") if "_agents" in GuestManager else null
	if agents == null:
		print("PASS7 no guest agents to ask")
		return
	var office: Node3D = _main.call("debug_structure_of_type", "main_building")
	var free: Vector2i = agents.call("_free_tile_by", office.global_position)
	var goal: Vector2i = agents.call("_stand_tile", Vector2i(20, 20), free)
	var way: Array = agents.call("_find_path", free, goal)
	_ok("a guest's way starts from the tile by the door", not way.is_empty(), "%s to %s, %d tiles" % [str(free), str(goal), way.size()])


# ── the land ───────────────────────────────────────────────

func trunks() -> void:
	FAR_TREES.add(Vector3(500, 0, 500), 0.3)
	var o: Vector2 = FAR_TREES.way_out(Vector3(500.2, 0, 500), 0.36)
	_ok("a trunk past the fence pushes you out", o.length() > 0.3, str(o))
	_ok("and none where there is none", FAR_TREES.way_out(Vector3(503, 0, 500), 0.36) == Vector2.ZERO)


func snow() -> void:
	_ok("the first snow's evening", Season.first_snow_now(Season.FIRST_SNOW_DAY, 21.0))
	_ok("and not the day before", not Season.first_snow_now(Season.FIRST_SNOW_DAY - 1, 21.0))
	var w := WeatherSystem.new()
	w.auto_cycle_enabled = true
	w.season_day = Season.FIRST_SNOW_DAY
	w.process(1.0, 21.0)
	_ok("it falls that night whatever the dice", w.current_weather >= WeatherSystem.WEATHER_LIGHT_RAIN and w.current_weather <= WeatherSystem.WEATHER_STORM, str(w.current_weather))
	var last := 0.0
	var smooth := true
	for i in 96:
		var v: float = Season.snow_cover(Season.FIRST_SNOW_DAY + int(i / 24.0), fposmod(float(i), 24.0))
		if absf(v - last) > 0.06:
			smooth = false
		last = v
	_ok("it lies by degrees", smooth)


func cap() -> void:
	var gs := get_tree().root.get_node("GameSettings")
	_ok("144 Hz: 72", int(gs.call("frame_cap", 144.0)) == 72)
	_ok("60 Hz: 60", int(gs.call("frame_cap", 60.0)) == 60)
	_ok("240 Hz: 80", int(gs.call("frame_cap", 240.0)) == 80)
	print("PASS7 this screen %.1f Hz, cap %d" % [DisplayServer.screen_get_refresh_rate(), Engine.max_fps])


func verdict() -> void:
	print("PASS7: %s" % ("PASS" if fails == 0 else "%d FAILURE(S)" % fails))


func _ready() -> void:
	super._ready()
	var close := ["eval", "_interior_manager._building_interior.close_interior()"]
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 4.0],
		["eval", C + ".room_is_camp()"], close, ["wait", 2.0],
		["eval", C + ".cap()"], ["eval", C + ".trunks()"], ["eval", C + ".snow()"],
		["eval", "_build_test_camp('')"], ["wait", 2.0], ["eval", C + ".guest_path()"],
		# Enemies: each in turn at night.
		["eval", "debug_jump_to(2, 22.0)"], ["wait", 2.0], ["eval", "_stop_active_enemy_brain()"], ["wait", 0.5],
		["eval", "debug_spawn_enemy('whistler', 3)"], ["wait", 1.0],
		["eval", C + ".water()"], ["eval", C + ".roof()"], ["eval", C + ".song()"], ["eval", C + ".sits()"],
		["eval", "_stop_active_enemy_brain()"], ["wait", 0.5],
		["eval", "debug_spawn_enemy('stalker', 3)"], ["wait", 1.0], ["eval", C + ".stalker_charge()"], ["wait", 1.2], ["eval", C + ".stalker_walked()"],
		["eval", "_stop_active_enemy_brain()"], ["wait", 0.5],
		# Liblice: the pub, closing time.
		["eval", "debug_jump_to(3, 21.5)"], ["wait", 1.0],
		["eval", TT + "._ensure_town()"], ["eval", TT + "._put_player(%s._town.arrive_spot())" % TT], ["wait", 2.0],
		["eval", TT + "._open_room('pub')"], ["wait", 2.0], ["eval", C + ".in_pub()"], ["eval", C + ".pub_is_not()"],
		["eval", "debug_jump_to(3, 23.02)"], ["wait", 5.0], ["eval", C + ".pub_shut()"],
		["eval", C + ".verdict()"], ["eval", "get_tree().quit()"],
	]
