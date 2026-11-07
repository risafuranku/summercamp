extends "res://tools/shot_driver.gd"

## What the camp runs at under each frame cap, with the screen's sync and without. Windowed,
## the same spot and hour each time. Lines "FPS ...".
##   godot --path godot --audio-driver Dummy --resolution 1366x768 res://tools/fps_check.tscn -- --out=DIR

const C := "get_tree().root.get_node('FpsCheck')"


func info() -> void:
	print("FPS screen %.2f Hz, cap now %d, sync %d" % [DisplayServer.screen_get_refresh_rate(DisplayServer.window_get_current_screen()), Engine.max_fps, DisplayServer.window_get_vsync_mode()])


func set_cap(sync: int, cap: int) -> void:
	DisplayServer.window_set_vsync_mode(sync)
	Engine.max_fps = cap


func read(sync: int, cap: int) -> void:
	print("FPS sync %d cap %3d: %3d fps, process %.1f ms, physics %.1f ms, draws %d" % [sync, cap, int(Engine.get_frames_per_second()),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])


func _ready() -> void:
	super._ready()
	var s: Array = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 4.0],
		["eval", "_interior_manager._building_interior.close_interior()"], ["wait", 3.0],
		["eval", C + ".info()"],
	]
	for sync in [1, 0]:
		for cap in [0, 144, 96, 72, 60, 50]:
			s.append_array([["eval", C + ".set_cap(%d, %d)" % [sync, cap]], ["wait", 4.0], ["eval", C + ".read(%d, %d)" % [sync, cap]]])
	s.append(["eval", "get_tree().quit()"])
	_steps = s
