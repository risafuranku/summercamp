extends Node

## Headless check of the pipe-crawl network generator (scripts/sewer_pipe_minigame.gd).
##
##   godot --headless --path godot res://tools/pipes_check.tscn
##
## For 300 seeds: every junction has a way on (no dead ends, because the player can
## never turn around), the network is connected, the ladder opens north, the leak is
## reachable and not next to the ladder, and the same seed gives the same network.

const PIPES := preload("res://scripts/sewer_pipe_minigame.gd")


func _ready() -> void:
	var failures: Array[String] = []
	var g = PIPES.new()
	var far_sum := 0
	for seed in 300:
		g._rng.seed = seed
		g._generate()
		var snapshot := _signature(g)
		for c in g._links.keys():
			if g._links[c].size() < 2:
				failures.append("seed %d: dead end at %s" % [seed, c])
		var dist: Dictionary = g._distances_from(g._entry)
		if dist.size() != g._links.size():
			failures.append("seed %d: network not connected (%d/%d)" % [seed, dist.size(), g._links.size()])
		if not g._links[g._entry].has(0):
			failures.append("seed %d: ladder does not open north" % seed)
		var leak_dist := mini(int(dist.get(g._leak_a, -1)), int(dist.get(g._leak_b, -1)))
		if leak_dist < 2:
			failures.append("seed %d: leak only %d junctions from the ladder" % [seed, leak_dist])
		far_sum += leak_dist
		g._rng.seed = seed
		g._generate()
		if _signature(g) != snapshot:
			failures.append("seed %d: not deterministic" % seed)
		if failures.size() > 10:
			break
	g.free()
	print("")
	print("PIPES CHECK: average leak distance %.1f junctions" % (float(far_sum) / 300.0))
	if failures.is_empty():
		print("PIPES CHECK: PASS")
		get_tree().quit(0)
	else:
		print("PIPES CHECK: %d FAILURE(S)" % failures.size())
		for f in failures:
			print("  - " + f)
		get_tree().quit(1)


func _signature(g) -> String:
	var parts: Array[String] = []
	var keys: Array = g._links.keys()
	keys.sort()
	for c in keys:
		var dirs: Array = g._links[c].duplicate()
		dirs.sort()
		parts.append("%s%s" % [c, dirs])
	parts.append("leak %s-%s" % [g._leak_a, g._leak_b])
	return ",".join(parts)
