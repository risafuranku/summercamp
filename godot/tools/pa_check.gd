extends Node

## Headless check for the camp's PA poles (Richard 24. 11., docs/audio.md "amplióny"):
## the building (Builder's catalogue, its price and power, its pictures), the rules
## (core/systems/pa_rules.gd: the reach, the fun nearby and its cap), and the guests' side in
## guest_life: a light sleeper by a pole playing after ten sleeps badly and says so in the
## morning; not by day, not with the set off, not far away, not a drunk.
##
##   godot --headless --path godot res://tools/pa_check.tscn
##
## Run as a SCENE (guest_life reads CoreRoot).

const PA := preload("res://core/systems/pa_rules.gd")
const LIFE := preload("res://scripts/guest_life.gd")
const BUILDER := preload("res://scripts/builder_module.gd")
const AUTH := preload("res://core/systems/builder_authority.gd")

var _failures: Array[String] = []


func _ready() -> void:
	# The building.
	var def = load("res://data/buildings/pa_pole.tres")
	_expect(def != null and str(def.id) == "pa_pole" and int(def.cost) > 0 and int(def.power_use) > 0, "the PA pole's def: a price and power")
	_expect(bool(AUTH.ALLOWED_BUILD_TYPES.get("pa_pole", false)), "Builder may build it")
	var listed := false
	for cat in BUILDER.CATEGORIES:
		listed = listed or (cat["items"] as Array).has("pa_pole")
	_expect(listed, "it is in Builder's catalogue")
	_expect(ResourceLoader.exists(str(BUILDER.ITEM_ICONS.get("pa_pole", ""))), "its catalogue picture")
	_expect(ResourceLoader.exists("res://assets/textury/world/pa_pole.png"), "its picture in the camp")

	# The rules.
	_expect(is_equal_approx(PA.range_tiles(4.0), 8.75), "35 m are 8.75 tiles of 4 m")
	_expect(PA.near([Vector2i(10, 10)], Vector2i(16, 15), 4.0) and not PA.near([Vector2i(10, 10)], Vector2i(17, 17), 4.0), "within reach and out of it")
	_expect(is_equal_approx(PA.fun_after(30.0, 60.0), 30.0 + PA.FUN_PER_MIN * 60.0), "an hour's fun near a pole")
	_expect(is_equal_approx(PA.fun_after(58.0, 120.0), PA.FUN_CAP), "never past its cap")
	_expect(is_equal_approx(PA.fun_after(80.0, 60.0), 80.0), "and never down (a bonfire's fun stays)")
	_expect(PA.quiet_hours(23.0) and PA.quiet_hours(2.0) and not PA.quiet_hours(14.0) and not PA.quiet_hours(21.5), "the quiet from ten to six")

	# The guests: a picker in a tent by a pole.
	var life = LIFE.new()
	life._pa_tiles = [Vector2i(10, 10)] as Array[Vector2i]
	life._tile_m = 4.0
	life.set_pa_on(true)
	var picker := {"id": 1, "archetype": "picker", "lodging_slots": [{"coord": Vector2i(12, 10), "building_type": "tent_1"}]}
	var n_night: float = life._noise_for(picker, 23 * 60)
	_expect(n_night > 0.0 and bool(picker.get("pa_night", false)), "a light sleeper by a pole at 23:00 sleeps badly (%.1f)" % n_night)
	var thought: String = life._morning_thought(picker)
	_expect(thought in ["The loudspeaker outside played all night.", "A brass band at two in the morning. Through a horn.", "Who leaves the camp radio on all night?"] and int(picker.get("complaints", 0)) == 1,
		"and says so in the morning (%s)" % thought)
	_expect(not picker.has("pa_night"), "once")
	_expect(is_zero_approx(life._noise_for(picker, 14 * 60)), "not by day")
	var drunk := {"id": 2, "archetype": "drunk", "lodging_slots": [{"coord": Vector2i(11, 10), "building_type": "tent_1"}]}
	_expect(is_zero_approx(life._noise_for(drunk, 23 * 60)), "a drunk sleeps through it")
	var far := {"id": 3, "archetype": "picker", "lodging_slots": [{"coord": Vector2i(30, 30), "building_type": "tent_1"}]}
	_expect(is_zero_approx(life._noise_for(far, 23 * 60)), "not far from the poles")
	var cabin := {"id": 4, "archetype": "picker", "lodging_slots": [{"coord": Vector2i(12, 10), "building_type": "cabin_1"}]}
	_expect(life._noise_for(cabin, 23 * 60) < n_night, "a cabin's walls keep some of it out")
	life.set_pa_on(false)
	_expect(is_zero_approx(life._noise_for(picker, 23 * 60)), "with the set off, nothing")

	# A place's news out of the horns (docs/pc.md 24. 11.): guests in reach go to it, once,
	# about PULL_CHANCE of them; none out of reach, none after PULL_MINUTES.
	life._rng.seed = 2411
	var pub := {"key": "12:12", "coord": Vector2i(12, 12), "type": "pub", "services": {"thirst": 40.0, "fun": 30.0}, "use_minutes": 30}
	life.pa_pull("12:12", 600)
	var went := 0
	for i in 200:
		var g := {"id": 100 + i}
		if not (life._pulled_visit(g, Vector2i(11, 10), [pub], 610) as Dictionary).is_empty():
			went += 1
	_expect(went > 40 and went < 100, "about a third of the guests in reach go to the place named (%d of 200)" % went)
	var once := {"id": 999}
	var first: Dictionary = {}
	for i in 30:
		life.pa_pull("12:12", 600)
		once.erase("pull_seen")
		first = life._pulled_visit(once, Vector2i(11, 10), [pub], 610)
		if not first.is_empty():
			break
	_expect(not first.is_empty() and str(first.get("need", "")) == "thirst", "the visit is for what the place gives most (%s)" % first.get("need", ""))
	_expect((life._pulled_visit(once, Vector2i(11, 10), [pub], 612) as Dictionary).is_empty(), "the same guest goes once a news")
	_expect((life._pulled_visit({"id": 1000}, Vector2i(40, 40), [pub], 610) as Dictionary).is_empty(), "out of reach: nobody")
	_expect((life._pulled_visit({"id": 1001}, Vector2i(11, 10), [pub], 600 + PA.PULL_MINUTES + 1) as Dictionary).is_empty(), "later than the news holds: nobody")

	if _failures.is_empty():
		print("PA CHECK: PASS")
	else:
		for f in _failures:
			print("PA CHECK FAIL: " + f)
		print("PA CHECK: FAIL (%d)" % _failures.size())
	get_tree().quit()


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
