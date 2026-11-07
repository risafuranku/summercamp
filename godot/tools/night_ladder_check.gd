extends SceneTree

## The nights follow on (core/systems/night_ladder.gd): the first bad night is one kind, gentle;
## no night with somebody in the camp is empty; what came last night comes first; the radio
## cannot reach the worst before it is worked up to.
##   godot --headless --path godot --script res://tools/night_ladder_check.gd

const LADDER := preload("res://core/systems/night_ladder.gd")
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


func _init() -> void:
	var known := {"quiet_guy": 1, "drunk": 1, "cheap_chick": 1, "tramp": 1}
	var full := [{"archetype": "quiet_guy", "spawned": 2, "guest_count": 9}, {"archetype": "drunk", "spawned": 1, "guest_count": 6},
		{"archetype": "tramp", "spawned": 1, "guest_count": 7}]
	var thin := [{"archetype": "quiet_guy", "spawned": 0, "guest_count": 2}, {"archetype": "drunk", "spawned": 0, "guest_count": 1},
		{"archetype": "tramp", "spawned": 0, "guest_count": 0}]
	_expect(_kinds(LADDER.shape(full, 1, [], known)).size() == 1, "the first bad night: one kind, however full the camp")
	_expect(_kinds(LADDER.shape(full, 1, [], known))[0] == "quiet_guy", "the one with the most guests")
	_expect(_kinds(LADDER.shape(full, 2, ["drunk"], known)) == ["drunk"], "last night's comes back")
	_expect(_kinds(LADDER.shape(full, 3, ["drunk"], known)).size() == 2, "a second kind joins it")
	_expect(_kinds(LADDER.shape(thin, 2, ["drunk"], known)) == ["drunk"], "a thin night is not an empty one: last night's")
	_expect(_kinds(LADDER.shape(thin, 2, ["tramp"], known)) == ["quiet_guy"], "theirs left the camp: the most guests'")
	_expect(_kinds(LADDER.shape(thin, 0, [], known)).is_empty(), "the quiet night stays quiet")
	var empty := [{"archetype": "quiet_guy", "spawned": 0, "guest_count": 0}]
	_expect(_kinds(LADDER.shape(empty, 3, [], known)).is_empty(), "nobody in the camp, nobody turns")
	_expect(_kinds(LADDER.shape(full, 9, [], known)).size() == 3, "past the ladder, all the camp brings")
	_expect(LADDER.dread_cap(1) < RADIO.TEROR, "the first bad night's radio stays under the terror songs")
	_expect(LADDER.dread_cap(3) < RADIO.PEKLO and LADDER.dread_cap(4) < RADIO.PEKLO, "the hell songs are worked up to")
	_expect(LADDER.dread_cap(5) >= RADIO.PEKLO, "and they come")
	for s in range(1, 8):
		_expect(LADDER.dread_cap(s + 1) >= LADDER.dread_cap(s) and LADDER.difficulty_cap(s + 1) >= LADDER.difficulty_cap(s) and LADDER.kinds_cap(s + 1) >= LADDER.kinds_cap(s), "never a step back at %d" % s)
	print("NIGHT LADDER CHECK: %s (%d failures)" % ["PASS" if _fails == 0 else "FAILED", _fails])
	quit(1 if _fails > 0 else 0)
