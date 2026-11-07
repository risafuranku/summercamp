extends SceneTree

## The nights follow on (core/systems/night_swell.gd), by the guests and not by the calendar: the
## fear moves toward what the guests are like, a step at a time, up and down; a content little
## camp stays gentle, a full miserable one gets to the worst, one put right comes back; what came
## last night comes first; a night after a visit is not an empty one; the radio cannot reach the
## worst before the fear does.
##   godot --headless --path godot --script res://tools/night_swell_check.gd

const SWELL := preload("res://core/systems/night_swell.gd")
const RADIO := preload("res://scripts/radio/radio_tiers.gd")

var _fails := 0


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL ", what)


func _kinds(a: Array) -> Array:
	var out: Array = []
	for e in a:
		if int(e["spawned"]) > 0:
			out.append(str(e["archetype"]))
	return out


## `nights` nights of guests reading `read`, from `from`: the swell of each.
func _run(from: float, read: float, nights: int) -> Array:
	var out: Array = []
	var s := from
	for i in nights:
		s = SWELL.next(s, read)
		out.append(s)
	return out


func _init() -> void:
	var known := {"quiet_guy": 1, "drunk": 1, "cheap_chick": 1, "tramp": 1}
	var full := [{"archetype": "quiet_guy", "spawned": 2, "guest_count": 9}, {"archetype": "drunk", "spawned": 1, "guest_count": 6},
		{"archetype": "tramp", "spawned": 1, "guest_count": 7}]
	var thin := [{"archetype": "quiet_guy", "spawned": 0, "guest_count": 2}, {"archetype": "drunk", "spawned": 0, "guest_count": 1},
		{"archetype": "tramp", "spawned": 0, "guest_count": 0}]
	# What the guests are like.
	var content_few := SWELL.reading(2, 0, 1)
	var content_full := SWELL.reading(16, 0, 3)
	var miserable := SWELL.reading(20, 14, 4)
	_expect(SWELL.reading(0, 0, 0) == 0.0, "nobody in the camp reads nothing")
	_expect(content_few < 0.2, "two content guests hardly read (%.2f)" % content_few)
	_expect(content_full < 0.6 and content_full > content_few, "a full content camp reads in the middle (%.2f)" % content_full)
	_expect(miserable > 0.85, "a full miserable one reads near the top (%.2f)" % miserable)
	_expect(SWELL.reading(10, 5, 2) > SWELL.reading(10, 0, 2), "unhappy guests read higher")
	_expect(SWELL.reading(10, 0, 2, 1) > SWELL.reading(10, 0, 2), "and so does one the night took")
	# How it moves.
	var worst := _run(0.0, miserable, 8)
	_expect(float(worst[0]) <= SWELL.RISE + 0.001, "however full the camp, the first night is a step")
	for i in range(1, 8):
		_expect(float(worst[i]) - float(worst[i - 1]) <= SWELL.RISE + 0.001, "a step at a time up")
	_expect(float(worst[7]) > 0.85, "a miserable camp gets there")
	_expect(float(_run(0.0, content_few, 12)[11]) < 0.2, "a content little camp stays low")
	var after := _run(float(worst[7]), content_few, 3)
	_expect(float(after[0]) >= float(worst[7]) - SWELL.FALL - 0.001, "no drop: put right, it comes back slowly")
	_expect(float(_run(float(worst[7]), 0.0, 12)[11]) < 0.01, "an empty camp goes quiet in the end")
	# What the night may have.
	_expect(_kinds(SWELL.shape(full, 0.2, [], known, 0.9)).size() == 1, "gentle: one kind, however full the camp")
	_expect(_kinds(SWELL.shape(full, 0.2, [], known, 0.9))[0] == "quiet_guy", "the one with the most guests")
	_expect(_kinds(SWELL.shape(full, 0.25, ["drunk"], known, 0.9)) == ["drunk"], "last night's comes back")
	_expect(_kinds(SWELL.shape(full, 0.4, ["drunk"], known, 0.9)).size() == 2, "a second kind joins it")
	_expect(_kinds(SWELL.shape(full, 0.95, [], known, 0.9)).size() == 3, "at the top, all the camp brings")
	_expect(_kinds(SWELL.shape(thin, 0.3, ["drunk"], known, 0.9)) == ["drunk"], "after a visit a thin night is not an empty one")
	_expect(_kinds(SWELL.shape(thin, 0.3, ["tramp"], known, 0.9)) == ["quiet_guy"], "theirs left the camp: the most guests'")
	_expect(_kinds(SWELL.shape(thin, 0.1, [], known, 0.9)).is_empty(), "little fear, nothing rolled, nothing came before: a quiet night")
	_expect(_kinds(SWELL.shape(thin, 0.1, [], known, 0.1)).size() == 1, "though it may")
	_expect(_kinds(SWELL.shape(thin, 0.6, [], known, 0.9)).size() == 1, "with the fear up, it does")
	_expect(_kinds(SWELL.shape(thin, 0.0, ["drunk"], known, 0.0)).is_empty(), "no fear left, nothing")
	_expect(_kinds(SWELL.shape(thin, 0.8, ["drunk"], known, 0.5)).size() == 2, "well up, a second kind comes with the first")
	_expect(_kinds(SWELL.shape(thin, 0.8, ["drunk"], known, 0.5)).has("drunk"), "last night's among them")
	_expect(SWELL.difficulty_floor(0.2) == 1 and SWELL.difficulty_floor(0.8) == 3, "the fear makes them worse")
	for i in 21:
		var f := float(i) / 20.0
		_expect(SWELL.difficulty_floor(f) <= SWELL.difficulty_cap(f), "the floor is under the cap")
	var empty := [{"archetype": "quiet_guy", "spawned": 0, "guest_count": 0}]
	_expect(_kinds(SWELL.shape(empty, 0.8, ["quiet_guy"], known, 0.0)).is_empty(), "nobody in the camp, nobody turns")
	# The radio, the lamps.
	_expect(SWELL.dread_cap(0.0) <= SWELL.DREAD_FLOOR + 0.001, "nothing worked up to: the radio only frets")
	_expect(SWELL.dread_cap(SWELL.RISE) < RADIO.TEROR, "one step up it stays under the terror songs")
	_expect(SWELL.dread_cap(0.5) >= RADIO.TEROR and SWELL.dread_cap(0.6) < RADIO.PEKLO, "then the terror songs, the hell songs not yet")
	_expect(SWELL.dread_cap(0.9) >= RADIO.PEKLO, "near the top they come")
	_expect(SWELL.lamps_cap(0.1) == 1 and SWELL.lamps_cap(0.99) == 4, "the lamps go with it")
	for i in 20:
		var a := float(i) / 20.0
		var b := a + 0.05
		_expect(SWELL.dread_cap(b) >= SWELL.dread_cap(a) and SWELL.difficulty_cap(b) >= SWELL.difficulty_cap(a) and SWELL.kinds_cap(b) >= SWELL.kinds_cap(a) and SWELL.silent_cap(b) >= SWELL.silent_cap(a), "more fear never means less")
	print("NIGHT SWELL CHECK: %s (%d failures)" % ["PASS" if _fails == 0 else "FAILED", _fails])
	quit(1 if _fails > 0 else 0)
