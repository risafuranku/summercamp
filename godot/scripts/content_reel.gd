extends CanvasLayer

## The title screen's L page, "Content reel" (the user 21. 10.: "a few dense scenes one
## after another, switched with L, to film as gameplay for the socials: the camp, the
## minigames, the enemies, the NPCs, the vibe, a bit of the town"). One full camp (the
## businesses' test camp, main._start_test_businesses) through one day, a scene at a time;
## L cuts to the next (a short fade through black in steps), Shift+L takes the scene again
## from its start. After the last the next day begins with the first. Nothing is saved.
##
##   dawn          06:35, clear, the morning mist over the meadow: the camp from the
##                 south while the god cursor brings new buildings down out of the sky
##   pub           13:00: the pub full at lunch, you behind the bar at the tap
##   office        17:10, the golden hour: at the reception's PC with both monitors,
##                 Builder's map on the left, Goggle's reviews on the right (A / D)
##   bus           18:35, drizzle: the camp stop as the last 380 comes up the road
##   photographer  21:40, the storm: out by the office; he is somewhere out there; into
##                 the office, and he is at its window; draw the curtain
##   silent        23:30, fog: the Silent Man, the far end of the camp, the torch

const SCENES := ["dawn", "pub", "office", "bus", "photographer", "silent"]
const FADE_STEPS := 8
const FADE_SEC := 0.45
const BUS_TIMES = preload("res://scripts/town/bus_timetable.gd")

var main: Node
var _i := -1
var _day := 2
var _busy := false
var _fade: ColorRect
var _gen := 0


func start(main_node: Node) -> void:
	main = main_node
	layer = 140
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)
	var ws = main.get("weather_system")
	if ws != null and ws.has_method("set_auto_cycle_enabled"):
		ws.set_auto_cycle_enabled(false)
	await _go(0)


func _process(_delta: float) -> void:
	# Back at the title screen: the reel is over.
	if main == null or not is_instance_valid(main) or main.get("_menu_mode") == true:
		queue_free()


func _input(event: InputEvent) -> void:
	if _busy or get_tree().paused or not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if not k.pressed or k.echo or k.physical_keycode != KEY_L:
		return
	get_viewport().set_input_as_handled()
	if k.shift_pressed:
		_go(_i)
	else:
		_go(_i + 1)


## Cuts to scene `n` (the next day after the last).
func _go(n: int) -> void:
	_busy = true
	_gen += 1
	await _fade_to(1.0)
	if n >= SCENES.size():
		n = 0
		_day += 1
	_i = n
	_reset()
	await call("_scene_" + str(SCENES[n]))
	await _frames(3)
	await _fade_to(0.0)
	_busy = false


func _fade_to(a: float) -> void:
	var from := _fade.color.a
	for s in FADE_STEPS:
		_fade.color.a = lerpf(from, a, float(s + 1) / FADE_STEPS)
		await get_tree().create_timer(FADE_SEC / FADE_STEPS).timeout


func _frames(n: int) -> void:
	for _f in n:
		await get_tree().process_frame


## Out of any room or close-up, nothing hunting, whole again.
func _reset() -> void:
	main._leave_everything(true)
	main._stop_active_enemy_brain()
	main._despawn_all_runtime_enemies()
	main._set_player_health(100, false)
	main.set("_liminal_last_rolled_night_id", -99999)
	var g = main.get("_god_cursor")
	if g != null and is_instance_valid(g):
		g.set("debug_force", false)


func _time(hours: float) -> void:
	main.debug_jump_to(_day, hours)


## The weather at once (it otherwise blends over 40 s).
func _weather(w: int) -> void:
	var ws = main.get("weather_system")
	if ws != null:
		ws.set_weather(w)
	await _frames(2)
	var wv = main.get("_weather_visuals")
	if wv != null:
		wv.set("_weather_blend_t", 1.0)


func _gate() -> Vector2i:
	var wg = main.get("world_generator")
	return wg.gate_tile() if wg != null and wg.has_method("gate_tile") else Vector2i(12, 0)


## The warden on a tile, looking at another.
func _stand(tile: Vector2i, look_at: Vector2i) -> void:
	var gm = main.get("grid_manager")
	var p: Node3D = main.get("_player")
	if gm == null or p == null:
		return
	var at: Vector3 = gm.grid_to_world(tile)
	var to: Vector3 = gm.grid_to_world(look_at)
	p.global_position = at + Vector3(0, 0.2, 0)
	p.look_at(Vector3(to.x, p.global_position.y, to.z), Vector3.UP)
	var head := p.get_node_or_null("Head") as Node3D
	if head != null:
		head.rotation.x = 0.0


# ── the scenes ───────────────────────────────────────────────────────────────

func _scene_dawn() -> void:
	_time(6.58)
	await _weather(0)
	var g := _gate()
	# On the path between the tents, looking past the cabins to the open ground.
	_stand(Vector2i(g.x, 13), Vector2i(g.x, 19))
	# New buildings come down out of the sky in front of you, one after another.
	var gc = main.get("_god_cursor")
	if gc != null:
		gc.set("debug_force", true)
	var gen := _gen
	var plan := [["cabin_1", Vector2i(g.x - 2, 16)], ["bonfire", Vector2i(g.x + 2, 17)], ["lamp_post", Vector2i(g.x + 1, 16)],
		["picnic_table", Vector2i(g.x + 4, 17)], ["cabin_1", Vector2i(g.x + 6, 17)], ["flagpole", Vector2i(g.x - 4, 17)]]
	_drop(plan, gen)


func _drop(plan: Array, gen: int) -> void:
	await get_tree().create_timer(2.5).timeout
	for item in plan:
		if gen != _gen:
			return
		EventBus.RequestBuild.emit(str(item[0]), item[1], 0)
		await get_tree().create_timer(3.2).timeout


func _scene_pub() -> void:
	_time(13.0)
	await _weather(0)
	main.debug_send_guests_to("pub", 400)
	var im = main.get("_interior_manager")
	var pub: Node3D = main.debug_structure_of_type("pub")
	if im == null or pub == null:
		return
	im.handle_structure_interact(pub)
	await get_tree().create_timer(3.5).timeout
	var si = im.get("_service_interior")
	if si != null and si.has_method("_open_station"):
		si._open_station("tap")


func _scene_office() -> void:
	_time(17.15)
	await _weather(0)
	var im = main.get("_interior_manager")
	var bi = im.get("_building_interior") if im != null else null
	if bi == null:
		return
	# The second monitor on the desk (as if it had come by post).
	var post = bi.get("_post")
	if post != null:
		post._set_state({"stage": "delivered", "t0": main._now_abs_minutes_float(), "no": 418})
	bi.set_second_monitor(true)
	var sh = bi.get("_crt_ui")
	for prog in ["builder", "guestrack"]:
		if sh != null and not sh._is_program_unlocked(prog):
			sh.install_program(prog, false)
	if not bi.is_open():
		im.handle_structure_interact(main._find_reception_structure())
		await get_tree().create_timer(3.0).timeout
	bi.enter_crt_view()
	# The machine boots; then Builder's map on the left, the reviews on the right.
	var gen := _gen
	for _t in 40:
		await get_tree().create_timer(0.5).timeout
		if gen != _gen:
			return
		if sh != null and sh.is_desktop_ready():
			break
	if sh == null:
		return
	sh._select_tab_on("builder", 0)
	sh._select_tab_on("reviews", 1)
	for _t in 6:
		main.debug_close_msgboxes()
		await get_tree().create_timer(0.5).timeout


func _scene_bus() -> void:
	_time(BUS_TIMES.CAMP_ARRIVE[2] - 0.17)
	await _weather(3)
	var im = main.get("_interior_manager")
	var trip = im.town_trip() if im != null else null
	if trip != null and trip.has_method("_put_player") and trip._road() != null:
		trip._put_player(trip._road().wait_spot())


func _scene_photographer() -> void:
	await _night(21.67, 5, "tourist", "drunk")
	# By the office, the camp before you; he is out there in the storm.
	var door: Vector3 = main.get_reception_door_position()
	var rec: Node3D = main._find_reception_structure()
	var p: Node3D = main.get("_player")
	if door != Vector3.INF and rec != null and p != null:
		var out := rec.global_basis.z.normalized()
		p.global_position = door + out * 5.0 + Vector3(0, 0.2, 0)
		p.look_at(p.global_position + out * 10.0, Vector3.UP)


func _scene_silent() -> void:
	await _night(23.5, 2, "silent_man", "quiet_guy")
	var g := _gate()
	_stand(Vector2i(g.x - 8, 18), Vector2i(g.x - 8, 30))


## A night scene: the clock past the night's roll (which stops every brain), this one
## out, a guest of the camp turned into it.
func _night(hours: float, weather: int, enemy: String, archetype: String) -> void:
	_time(hours)
	await _frames(2)
	main._stop_active_enemy_brain()
	main._despawn_all_runtime_enemies()
	await _weather(weather)
	main.debug_spawn_enemy(enemy, 3)
	var brains: Array = main.get("_enemy_brains")
	if brains != null and not brains.is_empty():
		var ne = brains.back().get("_night_entry")
		if ne is Dictionary:
			ne["guest"] = main._pick_turned_guest(archetype)
