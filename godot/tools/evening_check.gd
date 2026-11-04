extends "res://tools/shot_driver.gd"

## The evening before a bad night and the radio's terror (TODO W19, W27): the plan for a
## pressing night, the world holding its breath (the insects' and the outdoor bus's level),
## a wrong sound far off in it; then at night in the office, the song cut and something on
## the frequency. Lines "EVENING ...".
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/evening_check.tscn

const C := "get_tree().root.get_node('EveningCheck')"


func ev():
	return _main.get("_evening")


func plan(pressure: float) -> void:
	var abs_minute := (maxi(1, int(_main.get("_day_index"))) - 1) * 1440 + int(round(float(_main.get("_time_of_day_hours")) * 60.0))
	ev()._planned_day = abs_minute / 1440
	ev()._plan_evening(abs_minute, {"pressure": pressure, "quiet": false})
	print("EVENING plan pressure=%.1f -> %s" % [pressure, str(ev().debug_plan())])


func probe(tag: String) -> void:
	var am = _main.get("_audio_manager")
	var ins := AudioServer.get_bus_index("Insects")
	var fx = am.get("_world_hold_fx")
	var fars := 0
	for n in _main.find_children("EveningFar", "AudioStreamPlayer3D", true, false):
		if (n as AudioStreamPlayer3D).playing:
			fars += 1
	print("EVENING %s hour=%.2f hold=%.2f insects_db=%.1f world_hold_db=%s far_playing=%d music_phase=%s" % [tag, float(_main.get("_time_of_day_hours")), float(ev().hold),
		AudioServer.get_bus_volume_db(ins) if ins >= 0 else 0.0, str(fx.volume_db) if fx != null else "-", fars, str(_main.get("_music_director").get("_phase")) if _main.get("_music_director") != null else "-"])


func terror() -> void:
	var d = _main.get("_interior_manager").get("_building_interior").get("_dread")
	d.debug_override = 0.85
	d._terror_at = -9999.0
	d._begin_event(6)
	print("EVENING terror begun clip=%s len=%.1f" % [str(d._terror_clip), float(d._event_len)])


func radio(tag: String) -> void:
	var d = _main.get("_interior_manager").get("_building_interior").get("_dread")
	var fx = d._layers["fx"]
	var car = d._layers["carrier"]
	print("EVENING radio %s event=%d t=%.1f music_gain=%.2f fx_playing=%s carrier=%.2f static=%.2f listening=%s" % [tag, int(d._event), float(d._event_t), float(d.music_gain), str(fx.playing()), float(car.gain), float(d._layers["static"].gain), str(d._ctx.get("listening", "?"))])


func _ready() -> void:
	super._ready()
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 1.0],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 1.0],
		["eval", "debug_jump_to(3, 18.6)"], ["wait", 1.0],
		["eval", C + ".plan(0.4)"], ["eval", C + ".plan(1.6)"], ["eval", C + ".plan(3.4)"],
		["eval", C + ".probe('before')"],
		["eval", "_evening.debug_fire('holdfar')"],
	]
	for i in 14:
		_steps.append(["wait", 0.8])
		_steps.append(["eval", C + ".probe('hold%d')" % i])
	_steps += [
		["eval", "debug_jump_to(3, 23.0)"], ["wait", 1.0],
		["eval", "_interior_manager._building_interior.open_interior()"], ["wait", 3.0],
		["eval", C + ".terror()"],
	]
	for j in 12:
		_steps.append(["wait", 0.7])
		_steps.append(["eval", C + ".radio('t%d')" % j])
	_steps.append(["eval", "get_tree().quit()"])
