extends SceneTree

## Headless check of the reception desk (scripts/reception/checkin_desk.gd):
##
##   godot --headless --path godot --script res://tools/checkin_check.gd
##
## With a fake key board and check-in call:
## - a booked guest's papers come across; the wrong key comes back; returning the
##   papers unstamped or unwritten bounces them; written, keyed and stamped CHECKED IN
##   they go, the register has the row and the check-in is called once;
## - a key for a room that is not made up comes back;
## - REFUSED and the papers back: refused is emitted, nothing written;
## - the stranger (no slip): written, keyed, stamped in -> stranger_admitted, his row red
##   the next day; stamped REFUSED -> stranger_refused;
## - the key board: every key gets a hook, labels move and swap, the hooks are saved,
##   a demolished lodging's label comes off.

const DESK := preload("res://scripts/reception/checkin_desk.gd")

var _failures: Array = []
var _calls: Array = []
var _events: Array = []
var _ready_keys := {"9:6": true, "11:6": false, "12:6": true}


func _initialize() -> void:
	_run.call_deferred()


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)


func _frames(n := 2) -> void:
	for i in n:
		await process_frame


func _keys() -> Array:
	var out: Array = []
	for k in _ready_keys.keys():
		out.append({"key": k, "label": "Tent " + k, "kind": "tent", "ready": _ready_keys[k], "held": false})
	return out


func _guest(id: int, key: String) -> Dictionary:
	return {"id": id, "name": "Pepa", "party_size": 1, "stay_nights": 2, "rooms": [{"key": key, "label": "Tent " + key, "ready": _ready_keys[key]}],
		"sprite_path": "res://assets/textury/npc/host2.png", "card": {"surname": "NOVAK", "first": "JOSEF", "born": "1.1.1950", "number": "AB 123456", "town": "JIHLAVA", "valid": "1.1.2005"}}


func _run() -> void:
	var desk = DESK.new()
	desk.key_board_provider = _keys
	desk.check_in_call = func(id: int):
		_calls.append(id)
		return {"ok": true}
	desk.next_guest_provider = func(): return {}
	desk.checked_in.connect(func(id): _events.append("in:%d" % id))
	desk.refused.connect(func(id): _events.append("refused:%d" % id))
	desk.stranger_admitted.connect(func(): _events.append("stranger_in"))
	desk.stranger_refused.connect(func(): _events.append("stranger_out"))
	root.add_child(desk)
	await _frames()

	# A booked guest.
	desk.open_desk(_guest(1, "9:6"), 1)
	await _frames(40)
	_expect(desk.current_guest_id() == 1, "the guest is at the counter")
	desk.debug_do("wrong_key")
	_expect((desk._p["keys_given"] as Array).is_empty(), "the wrong key comes back")
	desk.debug_do("give")
	_expect(_calls.is_empty() and desk._p.get("card_on_desk", false), "unstamped papers bounce back")
	desk.debug_do("stamp_in")
	desk.debug_do("give")
	_expect(_calls.is_empty(), "papers bounce while nobody is written in")
	desk.debug_do("write")
	desk.debug_do("give")
	_expect(_calls.is_empty(), "papers bounce without the key")
	desk.debug_do("key")
	desk.debug_do("give")
	await _frames(40)
	_expect(_calls == [1], "the check-in is called once")
	_expect(_events.has("in:1"), "checked_in is emitted")
	_expect(desk.history().size() == 1 and str(desk.history()[0]["name"]) == "NOVAK J.", "the register has the row")

	# A room that is not made up.
	desk.open_desk(_guest(2, "11:6"), 1)
	await _frames(40)
	desk.debug_do("key")
	_expect((desk._p["keys_given"] as Array).is_empty(), "the key of an unready room comes back")
	desk.debug_do("stamp_out")
	desk.debug_do("give")
	await _frames(40)
	_expect(_events.has("refused:2"), "REFUSED sends them off")
	_expect(desk.history().size() == 1, "a refused guest is not written in")

	# The stranger.
	var s := {"id": -77, "stranger": true, "name": "", "party_size": 1, "stay_nights": 1, "rooms": [], "sprite_path": "res://assets/textury/npc/host1.png",
		"card": {"surname": "NOVAK", "first": "JOSEF", "born": "21.7.1984", "number": "AA 000003", "town": "CERNE JEZERO", "valid": "21.7.1984"}}
	desk.open_desk(s, 2)
	await _frames(40)
	_expect(not bool(desk._p.get("has_slip", true)), "the stranger has no booking slip")
	desk.debug_do("write")
	desk._drop_key("12:6", Vector2(200, 50))
	desk.debug_do("stamp_in")
	desk.debug_do("give")
	await _frames(40)
	_expect(_events.has("stranger_in"), "letting the stranger in is heard")
	_expect(bool(desk.history().back()["red"]), "his row is marked")
	desk.open_desk(s, 3)
	await _frames(40)
	desk.debug_do("stamp_out")
	desk.debug_do("give")
	await _frames(4)
	_expect(_events.has("stranger_out"), "refusing the stranger is heard")
	_expect(desk.current_guest_id() == -999, "he is not there any more")

	# The key board: a hook each, labels moved (swapping), saved, and a demolished
	# lodging's label coming off.
	desk._refresh_keys()
	_expect(desk._slots.size() == _ready_keys.size(), "every key has a hook")
	var first := str(desk._keys[0]["key"])
	var second := str(desk._keys[1]["key"])
	var a := int(desk._slots[first])
	var b := int(desk._slots[second])
	desk._stick_label(first, desk._hook_pos(b))
	_expect(int(desk._slots[first]) == b and int(desk._slots[second]) == a, "a label stuck on another swaps them")
	desk._stick_label(first, desk._hook_pos(20))
	_expect(int(desk._slots[first]) == 20, "a label goes on a free hook")
	var saved: Dictionary = desk.export_state()
	desk.import_state({})
	_expect(desk._slots.is_empty(), "a fresh desk has no labels")
	desk.import_state(saved)
	_expect(int(desk._slots.get(first, -1)) == 20, "the hooks are saved with the game")
	_ready_keys.erase(second)
	desk._refresh_keys()
	_expect(not desk._slots.has(second), "a demolished lodging's label comes off")

	if _failures.is_empty():
		print("CHECKIN CHECK: PASS")
	else:
		print("CHECKIN CHECK: %d FAILURE(S)" % _failures.size())
		for f in _failures:
			print("  - " + f)
	quit(0 if _failures.is_empty() else 1)
