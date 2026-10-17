extends SceneTree

## Renders the studio splash (scripts/ui/studio_splash.gd) frame by frame, without playing
## it. Needs a window (not --headless):
##
##   godot --path godot --resolution 960x540 --script res://tools/studio_splash_bake.gd -- --boot
##       writes its first frame to assets/boot/undo_labs_boot.png, the engine's boot
##       splash (project.godot application/boot_splash/image). Re-bake after any change
##       to the sign, the wall or the shader, or the engine -> game hand-over jumps.
##   ... -- --frames=<dir> [--times=0,0.6,1.2] [--cut=<t>] [--uncanny] [--scale=3]
##       writes the 320x180 picture at those times (scaled up, nearest) for a look;
##       the power goes at --cut (default: as early as the splash allows).

const SPLASH := preload("res://scripts/ui/studio_splash.gd")
const BOOT_IMAGE := "res://assets/boot/undo_labs_boot.png"


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var splash = SPLASH.new()
	splash.preview = true
	root.add_child(splash)
	await process_frame
	if args.has("boot"):
		splash.seek(0.0)
		var img := await _grab(splash)
		img.convert(Image.FORMAT_RGB8)
		var err := img.save_png(ProjectSettings.globalize_path(BOOT_IMAGE))
		print("STUDIO SPLASH boot image ", BOOT_IMAGE, " ", img.get_size(), " err=", err)
	if args.has("frames"):
		var dir: String = args.frames
		DirAccess.make_dir_recursive_absolute(dir)
		var cut: float = float(args.cut) if args.has("cut") else splash.earliest_cut()
		splash.preview_cut(cut, args.has("uncanny"))
		var times: Array = []
		if args.has("times"):
			for s in String(args.times).split(","):
				times.append(float(s))
		else:
			for k in 24:
				times.append(snappedf(float(k) * (cut + 1.4) / 23.0, 0.01))
		var scale := int(args.get("scale", "3"))
		for t in times:
			splash.seek(t)
			var img := await _grab(splash)
			img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
			var path := dir.path_join("splash_%05.2f.png" % t)
			img.save_png(path)
			print("STUDIO SPLASH frame ", path)
	quit()


func _grab(splash) -> Image:
	# The sign redraws, then the post pass reads it back: give it two drawn frames.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return splash.frame_image()
