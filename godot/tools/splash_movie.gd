extends Node

## The studio splash recorded for the web page (tools/web/export.mjs plays it over the canvas
## while the engine downloads and boots: the engine's single thread can not draw it then).
##   godot --path godot --write-movie <out>/splash.avi --fixed-fps 30 --resolution 1280x720
##         --audio-driver Dummy res://tools/splash_movie.tscn
## The window stays out of the way (unfocusable, in the corner), as the shot driver's does. The
## splash is played as the game plays it; the run ends once main's title card is up.

const SPLASH := "res://scenes/studio_splash.tscn"
## The splash's whole length and the card after it (seconds at the movie's fixed 30 fps).
const SECONDS := 15.0


func _ready() -> void:
	var w := get_window()
	if DisplayServer.get_name() != "headless" and not ("--keep-focus" in OS.get_cmdline_user_args()):
		w.unfocusable = true
		var usable := DisplayServer.screen_get_usable_rect(w.current_screen)
		w.position = usable.end - w.size - Vector2i(8, 8)
	await get_tree().process_frame
	print("SPLASH MOVIE: start frame %d" % Engine.get_frames_drawn())
	# (The SceneTree's own quit: a lambda of this node dies with it at the scene change.)
	var tree := get_tree()
	tree.create_timer(SECONDS).timeout.connect(tree.quit)
	get_tree().change_scene_to_file(SPLASH)
