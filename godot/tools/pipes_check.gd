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
	_check_thing(failures)
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


## The thing's rules (scripts/pipes/pipe_director.gd): the first time down it is not
## there at all; later it walks to a noise and, after breathing at you from next door,
## catches you (back to the ladder, hurt, the half-done clamp lost); light down a straight
## pipe makes it fold away.
func _check_thing(failures: Array[String]) -> void:
	var g = PIPES.new()
	add_child(g)
	g.open_repair(Vector2i(3, 3), "sewer")
	g._intro_t = -1.0
	var hurt := [0]
	g.player_hurt.connect(func(a): hurt[0] += a)
	g._flashlight.visible = false

	# Visit 1: nothing can happen to you, whatever you do.
	g._director.start(g, 1, true, 7)
	for i in 600:
		g._director.heard(g._node, 2)
		g._process(0.1)
	if hurt[0] > 0 or g._caught_t >= 0.0:
		failures.append("the first time down, it caught you")

	# Visit 3: stand two junctions from the ladder, ring the clamp: it comes and takes you.
	var dist: Dictionary = g._distances_from(g._entry)
	for c in dist.keys():
		if int(dist[c]) == 2:
			g._node = c
			break
	g._director.start(g, 3, true, 11)
	g._director._enter_phase(1)  # STALK
	g._clamp = 0.5
	g._at_leak = true
	var breathed := false
	for i in 1200:
		g._director.heard(g._node, 2)
		g._director._phase = 1
		g._director._phase_t = 0.0
		g._process(0.1)
		if g._director._warned_t > 0.0:
			breathed = true
		if g._caught_t >= 0.0:
			break
	for i in 60:
		g._process(0.1)
	if not breathed:
		failures.append("it came for you without breathing at you first")
	if hurt[0] <= 0:
		failures.append("it never caught a player ringing the clamp (or it did not hurt)")
	if g._clamp != 0.0:
		failures.append("being caught does not lose the half-done clamp")
	if g._node != g._entry:
		failures.append("being caught does not drag you to the ladder")

	# Light: it two junctions straight ahead, the torch on: it folds away.
	g._at_leak = false
	g._moving = false
	var ahead: Array = []
	for c in g._links.keys():
		for d in g._links[c]:
			var n1: Vector2i = c + g.DIRS[d]
			if g._links[n1].has(d):
				ahead = [c, d, n1 + g.DIRS[d]]
				break
		if not ahead.is_empty():
			break
	if ahead.is_empty():
		failures.append("no straight run of three junctions to test the light on")
	else:
		g._node = ahead[0]
		g._facing = ahead[1]
		g._director.start(g, 3, false, 5)
		g._director.node = ahead[2]
		g._director._scene = {}
		g._flashlight.visible = true
		var before := int(g._distances_from(g._node).get(g._director.node, 0))
		for i in 15:
			g._director._update_light(0.1, before)
		var after := int(g._distances_from(g._node).get(g._director.node, 0))
		if after <= before:
			failures.append("the light does not push it back (%d -> %d)" % [before, after])
	g.close_repair(true)
	g.queue_free()
