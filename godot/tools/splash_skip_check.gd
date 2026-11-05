extends SceneTree

## The studio splash skipped (Y1 of 5. 11.): a key at `SKIP_AT` seconds; from there on not one
## more of its sounds, the picture gone within a moment, main taking over as soon as it is
## loaded. Lines "SPLASH ...". Not headless (the splash goes straight to main there):
##   godot --path godot --audio-driver Dummy --resolution 1280x720 --script res://tools/splash_skip_check.gd

const SPLASH := "res://scenes/studio_splash.tscn"
const SKIP_AT := 1.2

var _started := 0
var _sent_at := -1
var _events_then := -1
var _black_at := -1
var _splash: Node
var _done := false


func _initialize() -> void:
	change_scene_to_file(SPLASH)
	_started = Time.get_ticks_msec()


func _process(_delta: float) -> bool:
	if _done:
		return true
	var now := Time.get_ticks_msec()
	var s := current_scene
	if s != null and s.scene_file_path == SPLASH:
		_splash = s
	if _splash == null or not is_instance_valid(_splash) or s != _splash:
		if _sent_at >= 0 and s != null and s.scene_file_path != SPLASH:
			print("SPLASH main took over %.2f s after the key" % (float(now - _sent_at) / 1000.0))
			_done = true
			quit()
		return false
	if _sent_at < 0 and float(now - _started) / 1000.0 >= SKIP_AT:
		var k := InputEventKey.new()
		k.keycode = KEY_SPACE
		k.physical_keycode = KEY_SPACE
		k.pressed = true
		Input.parse_input_event(k)
		_sent_at = now
		print("SPLASH key at %.2f s, the clock at %.2f, events fired %d" % [float(now - _started) / 1000.0, float(s.get("_t")), int(s.get("_next_event"))])
		return false
	if _sent_at >= 0:
		if _events_then < 0 and bool(s.get("_skipped")):
			_events_then = int(s.get("_next_event"))
			print("SPLASH skipped %.2f s after the key" % (float(now - _sent_at) / 1000.0))
		if _black_at < 0 and float(s.call("_fade", float(s.get("_t")))) <= 0.01:
			_black_at = now
			print("SPLASH black %.2f s after the key, events fired since %d" % [float(now - _sent_at) / 1000.0, int(s.get("_next_event")) - _events_then])
	return false
