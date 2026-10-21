extends SceneTree

## People seen from eight sides (scripts/figures/doom_figure.gd): every set in
## assets/textury/npc/sets/ loads, its index is whole (five views of standing, four frames a
## view of walking and running where it has them, every frame inside the atlas, an anchor
## inside its frame), a warden's jacket mask is the atlas's size, and the eight sectors come
## out as they should round a figure facing -Z.
##   godot --headless --path godot --script res://tools/figure_check.gd

const DOOM = preload("res://scripts/figures/doom_figure.gd")

var _fails := 0


func _fail(msg: String) -> void:
	_fails += 1
	print("FIGURE CHECK FAIL: " + msg)


func _init() -> void:
	# The sectors: 0 front, 2 side (unmirrored = facing the picture's right), 4 back.
	var want := {Vector3(0, 0, -5): 0, Vector3(3, 0, -3): 1, Vector3(5, 0, 0): 2, Vector3(3, 0, 3): 3,
		Vector3(0, 0, 5): 4, Vector3(-3, 0, 3): -3, Vector3(-5, 0, 0): -2, Vector3(-3, 0, -3): -1}
	for eye in want:
		var got := DOOM.sector_for(Vector3.ZERO, 0.0, eye)
		if got != int(want[eye]):
			_fail("sector from %s is %d, want %d" % [eye, got, want[eye]])
	# Kept past the edge: 25 degrees off the front still the front once there.
	var e := Vector3(sin(deg_to_rad(25.0)), 0, -cos(deg_to_rad(25.0))) * 5.0
	if DOOM.sector_for(Vector3.ZERO, 0.0, e, 0) != 0:
		_fail("no hold past the sector's edge")
	var dir := DirAccess.open("res://assets/textury/npc/sets")
	var n := 0
	if dir != null:
		for f in dir.get_files():
			if f.ends_with(".json"):
				_check_set(f.get_basename())
				n += 1
	print("FIGURE CHECK: %d sets, %d failures" % [n, _fails])
	print("FIGURE CHECK: " + ("PASS" if _fails == 0 else "FAIL"))
	quit(1 if _fails > 0 else 0)


func _check_set(name: String) -> void:
	var set := DOOM.set_of(name)
	if set.is_empty():
		_fail("%s does not load" % name)
		return
	var tex: Texture2D = set["tex"]
	var size := Vector2i(tex.get_width(), tex.get_height())
	var anims: Dictionary = set.get("anims", {})
	if not anims.has("stand"):
		_fail("%s has no standing views" % name)
	for a in anims:
		var views: Array = anims[a]
		if views.size() != 5:
			_fail("%s %s has %d views" % [name, a, views.size()])
			continue
		for v in 5:
			var frames: Array = views[v]
			if a == "stand" and frames.size() != 1:
				_fail("%s stand view %d has %d frames" % [name, v + 1, frames.size()])
			# A view not drawn yet is allowed (the figure shows walking or standing there).
			if a in ["walk", "run"] and frames.size() != 4 and frames.size() != 0:
				_fail("%s %s view %d has %d frames" % [name, a, v + 1, frames.size()])
			for fr in frames:
				if not (fr is Array) or (fr as Array).size() < 6:
					_fail("%s %s view %d: a frame missing" % [name, a, v + 1])
					continue
				var r := Rect2i(int(fr[0]), int(fr[1]), int(fr[2]), int(fr[3]))
				if not Rect2i(Vector2i.ZERO, size).encloses(r):
					_fail("%s %s view %d: frame %s outside the atlas %s" % [name, a, v + 1, r, size])
				if float(fr[4]) < 0.0 or float(fr[4]) > float(fr[2]):
					_fail("%s %s view %d: anchor x %s outside the frame" % [name, a, v + 1, fr[4]])
	if name.begins_with("warden_"):
		var mp := "res://assets/textury/npc/sets/%s_mask.png" % name
		if not ResourceLoader.exists(mp):
			_fail("%s has no jacket mask" % name)
		else:
			var m: Texture2D = load(mp)
			if Vector2i(m.get_width(), m.get_height()) != size:
				_fail("%s's mask is %dx%d, the atlas %s" % [name, m.get_width(), m.get_height(), size])
