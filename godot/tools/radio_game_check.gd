extends Node

## The radio going wrong inside the running game: the interior reads the night off Main
## (clock, NIGHT RISK, who is out, how close), and something close silences the songs.
##   godot --headless --path godot res://tools/radio_game_check.tscn

var _fails := 0


class FakeBrain:
	extends RefCounted
	var at: Vector3

	func get_enemy_id() -> String:
		return "girl"

	func get_presence() -> Dictionary:
		return {"position": at}

	func tick(_dt: float) -> void:
		pass


func _check(ok: bool, what: String) -> void:
	print("  ", "ok   " if ok else "FAIL ", what)
	if not ok:
		_fails += 1


func _ready() -> void:
	print("radio_game_check")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	var t := 0.0
	while not (bool(main.get("_gameplay_started")) and not bool(main.get("_menu_mode"))) and t < 30.0:
		if t > 1.0 and bool(main.get("_menu_mode")):
			main.call("_on_menu_new_game_pressed")
		await get_tree().process_frame
		t += get_process_delta_time()
	_check(bool(main.get("_gameplay_started")), "a new game starts")
	var im = main.get("_interior_manager")
	var bi = im.get("_building_interior") if im != null else null
	_check(bi != null and bi.get("_dread") != null, "the reception radio has its dread")
	if bi == null or bi.get("_dread") == null:
		_finish()
		return
	await _wait(1.0)
	var ctx: Dictionary = bi.call("_radio_dread_context", 0.0)
	_check(ctx.get("hours") is float and float(ctx["hours"]) > 0.0, "it reads Main's clock (%.1f h)" % float(ctx.get("hours", -1.0)))
	_check(float(bi.call("get_radio_dread")) < 0.2, "a calm first day (%.2f)" % float(bi.call("get_radio_dread")))

	var ts = main.get("time_system")
	ts.step_time_hours(13.0)
	main.call("_sync_runtime_state_from_systems", true)
	await _wait(1.0)
	ctx = bi.call("_radio_dread_context", 0.0)
	_check(bool(ctx.get("night", false)), "night falls for the radio (%.1f h)" % float(ctx.get("hours", -1.0)))
	# A brain that is out tonight and stands four metres from the player (the real ones
	# hide while the headless game refuses them actions).
	var player: Node3D = main.get("_player")
	var fake := FakeBrain.new()
	fake.at = player.global_position + Vector3(4.0, 0.0, 0.0)
	(main.get("_enemy_brains") as Array).append(fake)
	ctx = bi.call("_radio_dread_context", 0.0)
	_check("girl" in (ctx.get("tonight", []) as Array), "it knows who is out (%s)" % str(ctx.get("tonight", [])))
	_check(float(ctx.get("nearest", INF)) < 12.0, "and how close (%.1f m)" % float(ctx.get("nearest", INF)))
	await _wait(3.0)
	var dread = bi.get("_dread")
	_check(float(dread.get_near()) > 0.55, "near (%.2f)" % float(dread.get_near()))
	_check(float(dread.music_gain) < 0.2, "the song drops away (gain %.2f)" % float(dread.music_gain))
	_finish()


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()


func _finish() -> void:
	print("radio_game_check: %s" % ("PASS" if _fails == 0 else "%d FAILED" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)
