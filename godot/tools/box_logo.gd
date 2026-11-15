extends Node

## The game's logo for its UNDO.games box and cover, rendered by the game itself (the boot card's
## CURSED CAMP with its fill, the subtitle) on a transparent picture, with the red stamp of the new
## camp's form (page_form.gd APPROVED) saying DEMO under it. undogames/assets/gameart/<slug>/logo.png.
##   godot --path godot --audio-driver Dummy res://tools/box_logo.tscn -- --out=<file.png> [--scale=8]

const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const BOOT_SCREEN = preload("res://scripts/ui/boot_screen.gd")
const STAMP_RED := Color(0.72, 0.1, 0.08, 0.92)


class Stamp:
	extends Control
	var k := 8
	var word := "DEMO"

	# Twice the form's stamp: read on a box a few centimetres tall.
	const Z := 2

	func _ready() -> void:
		custom_minimum_size = Vector2(_w(), 18 * k * Z)

	func _w() -> float:
		return RETRO_UI.FONT_TEXT.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 8 * k * Z).x + 24 * k * Z

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, Vector2(_w(), 18 * k * Z))
		draw_rect(r.grow(-1.0 * k * Z), STAMP_RED, false, 2.0 * k * Z)
		var tw := RETRO_UI.FONT_TEXT.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 8 * k * Z).x
		draw_string(RETRO_UI.FONT_TEXT, Vector2((r.size.x - tw) * 0.5, 12 * k * Z), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 8 * k * Z, STAMP_RED)


func _ready() -> void:
	var out := ""
	var s := 8
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.get_slice("=", 1)
		elif arg.begins_with("--scale="):
			s = int(arg.get_slice("=", 1))
	var w := get_window()
	w.unfocusable = true
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.size = Vector2i(400 * s, 140 * s)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 3 * s)
	box.size = Vector2(vp.size)
	vp.add_child(box)
	var logo := RETRO_UI.PixelTitle.new()
	logo.configure(RETRO_UI.FONT_BIG, RETRO_UI.SIZE_BIG * 3, s)
	logo.set_colors(Color(1.0, 0.84, 0.44), Color(0.92, 0.38, 0.08))
	logo.set_text("CURSED CAMP")
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(logo)
	BOOT_SCREEN.paint_logo(logo, s)
	var sub := RETRO_UI.label("M A N A G E R   S I M U L A T O R", RETRO_UI.FONT_LABEL, RETRO_UI.SIZE_LABEL, RETRO_UI.C_AMBER, s)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6 * s)
	box.add_child(gap)
	var stamp := Stamp.new()
	stamp.k = s
	stamp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(stamp)
	for i in 6:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var used := img.get_used_rect()
	img = img.get_region(used.grow(2 * s).intersection(Rect2i(Vector2i.ZERO, img.get_size())))
	img.save_png(out)
	print("BOX LOGO: %s %s" % [out, img.get_size()])
	get_tree().quit()
