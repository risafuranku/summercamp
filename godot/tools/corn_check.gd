extends SceneTree

## Headless check of the corn maze (scripts/cornfield.gd):
##
##   godot --headless --path godot --script res://tools/corn_check.gd
##
## Builds 30 fields with different seeds and asserts: every path tile can be reached
## from the way in (no sealed pockets), there are dead ends for the lost guest and the
## scarecrow, the way in lines up with the gate, the maze is different every time.

const CORNFIELD := preload("res://scripts/cornfield.gd")


func _init() -> void:
	var failures: Array[String] = []
	var layouts := {}
	for i in 30:
		var rng := RandomNumberGenerator.new()
		rng.seed = 4000 + i * 31
		var c = CORNFIELD.new()
		var gate := rng.randf_range(-10.0, 10.0)
		c.build(Rect2(-80.0, -64.0, 24.0, 128.0), -90.0, Vector2(-100, 100), rng, -53.0, gate)
		var reach := 0
		for t in c.maze_open.keys():
			if not c.path_between(c.entrance, t).is_empty():
				reach += 1
		if reach != c.maze_open.size():
			failures.append("seed %d: %d of %d path tiles reachable" % [i, reach, c.maze_open.size()])
		if c.dead_ends().size() < 4:
			failures.append("seed %d: only %d dead ends" % [i, c.dead_ends().size()])
		if absf(c.tile_world(c.entrance).z - c.gate_z) > 0.01:
			failures.append("seed %d: the way in is not in line with the gate" % i)
		if c.entrance.x != c.maze_cols - 1:
			failures.append("seed %d: the way in is not on the east edge" % i)
		var key := ""
		for r in c.maze_rows:
			for col in c.maze_cols:
				key += "1" if c.maze_open.has(Vector2i(col, r)) else "0"
		layouts[key] = true
		c.free()
	if layouts.size() < 28:
		failures.append("mazes too alike: %d different of 30" % layouts.size())
	print("CORN CHECK: 30 mazes, %d different" % layouts.size())
	for f in failures:
		print("CORN CHECK FAIL: " + f)
	print("CORN CHECK: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
