extends Node

## The tap's pour gauge (TODO W44, scripts/pub/tap_station.gd _pour_meter): for a hladinka, a
## snyt and a mliko, empty, part poured, right, and run over; drawn side by side, twelve times
## its size, into <out>/gauge.png.
##   godot --headless --path godot res://tools/pour_gauge_check.tscn -- --out=DIR

const TAP := preload("res://scripts/pub/tap_station.gd")
const PUB := preload("res://core/systems/pub_rules.gd")


func _ready() -> void:
	var out := "user://"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var tap = TAP.new()
	var states := [[0.0, 0.0], [0.3, 0.05], [-1.0, 0.0], [-1.0, -1.0], [0.6, 0.5]]
	var sheet := Image.create((7 + 3) * 15 * 12, 22 * 12, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.2, 0.18, 0.16))
	var col := 0
	for drink in ["hladinka", "snyt", "mliko"]:
		var want := float(PUB.DRINKS[drink]["beer"])
		for st in states:
			var beer: float = want if float(st[0]) < 0.0 else float(st[0])
			var foam: float = (0.97 - want) if float(st[1]) < 0.0 else float(st[1])
			var img := Image.create(7, 22, false, Image.FORMAT_RGBA8)
			var s := Sprite3D.new()
			s.texture = ImageTexture.create_from_image(img)
			s.set_meta("meter_img", img)
			s.set_meta("meter_sig", "")
			tap._pour_meter(s, beer, foam, want)
			var big := (s.get_meta("meter_img") as Image).duplicate()
			big.resize(7 * 12, 22 * 12, Image.INTERPOLATE_NEAREST)
			sheet.blit_rect(big, Rect2i(0, 0, 7 * 12, 22 * 12), Vector2i(col * 10 * 12, 0))
			s.free()
			col += 1
		col += 0
	sheet.save_png(out.path_join("gauge.png"))
	print("GAUGE saved ", out.path_join("gauge.png"))
	tap.free()
	get_tree().quit()
