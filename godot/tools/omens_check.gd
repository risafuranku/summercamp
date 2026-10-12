extends SceneTree

## Headless check of the omens (scripts/omens.gd): no schedule, only the simulation.
##
##   godot --headless --path godot --script res://tools/omens_check.gd
##
## Simulates 400 weeks for three camps (empty, ordinary, overfull and troubled), a
## player who is outdoors a random part of each night, and asserts:
## - the busier and more troubled the camp, the more omens (empty camp: rare);
## - never two in one night;
## - "by_the_office" never before the camp has had real trouble;
## - every omen happens somewhere, on different nights in different weeks, and weeks
##   differ from each other (the order and the nights are not fixed).

const OMENS := preload("res://scripts/omens.gd")
const WEEKS := 400


class SimOmens:
	extends "res://scripts/omens.gd"
	var log: Array = []
	var place: Dictionary = {}

	func _situation(_p: Vector3) -> Dictionary:
		return place

	func _play(id: String, now: int, _p: Vector3) -> bool:
		log.append([id, now])
		return true


func _init() -> void:
	var failures: Array[String] = []
	var means := {}
	var nights_of := {}
	var sequences := {}
	var all_ids := {}
	for profile in ["empty", "ordinary", "troubled"]:
		var total := 0
		for week in WEEKS:
			var o := SimOmens.new()
			o._rng.seed = 7000 + week * 13 + profile.length()
			var visited := 0
			var kinds := 0
			for day in 7:
				# Tonight's camp.
				var ctx := {"guests": 0, "unhappy": 0, "kinds_seen": kinds, "nights_visited": visited, "hunting": 0, "dark": false}
				if profile == "ordinary":
					ctx["guests"] = 6 + o._rng.randi_range(0, 4)
					ctx["unhappy"] = o._rng.randi_range(0, 1)
				elif profile == "troubled":
					ctx["guests"] = 16 + o._rng.randi_range(0, 8)
					ctx["unhappy"] = o._rng.randi_range(2, 6)
					ctx["hunting"] = 1 if o._rng.randf() < 0.6 else 0
					ctx["dark"] = o._rng.randf() < 0.3
				# Out for a random stretch of the night, from 21:30.
				var start := day * 1440 + 1290 + o._rng.randi_range(0, 180)
				var length := o._rng.randi_range(60, 360)
				o.place = {"near_gate": o._rng.randf() < 0.3, "far_from_office": o._rng.randf() < 0.7}
				for m in range(start, start + length):
					o.tick(0.0, m, true, Vector3.ZERO, ctx)
				if profile == "ordinary" and o._rng.randf() < 0.3 or profile == "troubled" and o._rng.randf() < 0.75:
					visited += 1
					kinds = mini(kinds + (1 if o._rng.randf() < 0.5 else 0), 5)
				o._clear_live()
			# One per night at most.
			var nights := {}
			for e in o.log:
				var n := int(int(e[1]) / 1440) if posmod(int(e[1]), 1440) >= 1290 else int(int(e[1]) / 1440) - 1
				if nights.has(n):
					failures.append("%s week %d: two omens on night %d" % [profile, week, n])
				nights[n] = true
				all_ids[str(e[0])] = true
				var key := "%s:%s" % [profile, e[0]]
				(nights_of.get_or_add(key, {}) as Dictionary)[n] = true
			total += o.log.size()
			if profile == "troubled":
				sequences[str(o.log)] = true
			o.free()
		means[profile] = float(total) / float(WEEKS)

	print("OMENS CHECK: omens per week empty=%.2f ordinary=%.2f troubled=%.2f" % [means["empty"], means["ordinary"], means["troubled"]])
	if not (means["empty"] < 1.0):
		failures.append("empty camp too haunted: %.2f a week" % means["empty"])
	if not (means["empty"] < means["ordinary"] and means["ordinary"] < means["troubled"]):
		failures.append("omens do not follow the pressure")
	if not (means["troubled"] >= 2.0 and means["troubled"] <= 6.0):
		failures.append("troubled camp: %.2f a week, want 2-6" % means["troubled"])
	if (nights_of.get("empty:by_the_office", {}) as Dictionary).size() > 0:
		failures.append("by_the_office in an empty camp with no trouble")
	for id in ["torch", "one_more", "barrier", "phone", "by_the_office"]:
		if not all_ids.has(id):
			failures.append("%s never happened" % id)
	var spread := (nights_of.get("troubled:torch", {}) as Dictionary).size()
	if spread < 5:
		failures.append("torch only ever on %d different nights" % spread)
	if sequences.size() < int(WEEKS * 0.8):
		failures.append("troubled weeks too alike: %d distinct of %d" % [sequences.size(), WEEKS])
	for f in failures.slice(0, 12):
		print("OMENS CHECK FAIL: " + f)
	print("OMENS CHECK: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
