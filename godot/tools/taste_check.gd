extends Node

## Guest tastes and the night noise (core/systems/guest_needs_system.gd LODGING_TASTE,
## scripts/guest_life.gd _noise_for). Run:
##   godot --headless --path godot res://tools/taste_check.tscn

const NEEDS = preload("res://core/systems/guest_needs_system.gd")
const LIFE = preload("res://scripts/guest_life.gd")

var _fails := 0


func _ready() -> void:
	# Exact types before their kind.
	_eq(NEEDS.lodging_taste("family", "caravan_2"), 16.0, "family in a caravan with bunks")
	_eq(NEEDS.lodging_taste("family", "caravan_1"), 8.0, "family in a plain caravan (kind)")
	_eq(NEEDS.lodging_taste("cheap_chick", "cabin_1"), -4.0, "no shower in a basic cabin")
	_eq(NEEDS.lodging_taste("cheap_chick", "cabin_3"), 22.0, "her own shower")
	_eq(NEEDS.lodging_taste("picker", "tent_2"), -20.0, "a pensioner in a tent")
	_eq(NEEDS.lodging_taste("tramp", "tent_1"), 14.0, "a tramp under canvas")
	_eq(NEEDS.lodging_taste("nobody", "tent_1"), 0.0, "an unknown kind")
	_ok(NEEDS.lodging_thought("family", "caravan_3").length() > 0, "a word about the bunks")
	_ok(NEEDS.lodging_thought("drunk", "cabin_2") == "", "nothing worth saying")
	# The noise: a light sleeper two tiles from a drunk party, at 23:00 and at 10:00.
	var life = LIFE.new()
	life.set("_noise_sources", [{"id": 1, "coord": Vector2i(10, 10), "loud": 1.0}])
	var babi := {"id": 2, "archetype": "picker", "lodging_slots": [{"coord": Vector2i(12, 10), "building_type": "cabin_1"}]}
	var late := 23 * 60
	var day := 10 * 60
	_ok(life.call("_noise_for", babi, late) > 20.0, "Babi hears the lads at 23:00")
	_ok(bool(babi.get("noisy_night", false)), "and remembers it in the morning")
	_eq(life.call("_noise_for", babi, day), 0.0, "quiet by day")
	_eq(life.call("_noise_for", babi, 4 * 60), 0.0, "quiet after three")
	var far := {"id": 3, "archetype": "picker", "lodging_slots": [{"coord": Vector2i(20, 10), "building_type": "cabin_1"}]}
	_eq(life.call("_noise_for", far, late), 0.0, "far enough away")
	var lad := {"id": 4, "archetype": "drunk", "lodging_slots": [{"coord": Vector2i(11, 10), "building_type": "tent_1"}]}
	_eq(life.call("_noise_for", lad, late), 0.0, "the lads do not mind themselves")
	print("TASTE CHECK: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)


func _eq(got, want, what: String) -> void:
	if absf(float(got) - float(want)) > 0.001:
		_fails += 1
		print("  FAIL %s: %s != %s" % [what, str(got), str(want)])


func _ok(cond: bool, what: String) -> void:
	if not cond:
		_fails += 1
		print("  FAIL %s" % what)
