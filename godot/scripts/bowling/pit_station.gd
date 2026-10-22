extends "res://scripts/business/station3d.gd"

## The pit behind a pair of the bowling alley's lanes (scripts/bowling/bowling_interior.gd
## hosts two: lanes 1 and 2, lanes 3 and 4), worked as the pin boys of the old alleys did
## (the user, 21. 10.: "at first by hand"): crouched on the walkway behind the pits, the
## two pin decks in front of you, the hall's lanes beyond.
##
## A ball comes through: the pins it took lie about the deck and in the pit, the ball in
## the pit. A lane whose pins wait is a ticket on the rail (how long they have waited,
## the party's face). After a frame's first ball the deadwood comes off the deck (a click
## on each pin lying there throws it back into the pit) and the pins still up stay; after
## its last all ten go up again: a click takes a pin (off the deck or out of the pit), a
## click on an empty spot of the triangle stands it there (or drag it). The ball goes back
## up the return with a click. When it is all done the pins are up for the bowler: the
## bell, the alley's record has them set (bowling.gd set_pins), and Papa's stars by how long
## the lane waited; a party pleased with its pin boy rolls a coin down to the pit.
## The pins themselves are the lanes' (scripts/bowling/lane.gd): you work them where they
## are, everybody in the hall sees them go up.
## Design pixels on the surface (640 x 360 over both decks and the pit, 3.4 m by 1.7 m):
## x from your left (the pair's outer side on the right of the hall) to your right, y from
## the head pins (far) to the pit (yours).

const RULES := preload("res://core/systems/bowling_rules.gd")
const BOWLING := preload("res://scripts/bowling/bowling.gd")
const LAYOUT := preload("res://scripts/bowling/bowling_layout.gd")
const ORDERS := preload("res://scripts/food/orders.gd")
const BTEX := "res://assets/textury/bowling/"
## How far round a spot (design px) a pin dropped stands on it.
const SPOT_R := Vector2(18, 16)
## How high a pin in the hand is held over the deck (metres).
const HOLD_LIFT := 0.22
## Above this many stars the party's coin rolls down to the pit.
const COIN_FROM := 3

## The lanes' views of this pit's pair (lane.gd), set by the hall, left to right as the
## hall sees them.
var lanes: Array = []
## The pin in the hand: [lane view, pin] ([] none) and where it was taken (to drop back).
var _carry: Array = []
## Pressed on a pin and not yet let go (a drag drops it where the pointer lets go).
var _pressed_at := Vector2(-1, -1)
var _icon_pin: Texture2D
var _done_once: Dictionary = {}


func _build() -> void:
	fine = 2.0
	if state == null:
		state = BOWLING.of(get_tree())
	_icon_pin = load(BTEX + "pin.png") if ResourceLoader.exists(BTEX + "pin.png") else null


func sfx_dir() -> String:
	return "res://assets/sfx/bowling/"


func ding_sound() -> String:
	return "res://assets/sfx/bowling/pit_bell.mp3"


## The record's lane index of view `v`.
func _li(v) -> int:
	return int(v.get("index"))


func _view_of(li: int):
	for v in lanes:
		if _li(v) == li:
			return v
	return null


# ── the record ───────────────────────────────────────────────────────────────

func rail_tickets() -> Array:
	if state == null or building_key == "":
		return []
	var ids: Array = lanes.map(func(v) -> int: return _li(v))
	var out: Array = []
	var first := picked_ticket()
	for t in state.pit_tickets(building_key, ids):
		var d: Dictionary = t.duplicate()
		d["picked"] = str(d["id"]) == first
		d["sig"] = str(d["set"])
		out.append(d)
	return out


## The lane worked now: the one a pin in the hand is from, else the one waiting longest.
func picked_ticket() -> String:
	if not _carry.is_empty():
		return "lane%d" % _li(_carry[0])
	var ids: Array = lanes.map(func(v) -> int: return _li(v))
	var q: Array = state.pit_tickets(building_key, ids) if state != null else []
	return str(q[0]["id"]) if not q.is_empty() else ""


func big_ticket() -> Dictionary:
	var id := picked_ticket()
	for t in rail_tickets():
		if str(t["id"]) == id:
			return t
	return {}


func ticket_items(t: Dictionary) -> Array:
	return [{"icon": _icon_pin, "word": tr("Lane %d") % (int(t.get("lane", 0)) + 1)}]


func checklist(t: Dictionary) -> Array:
	var v = _view_of(int(t.get("lane", -1)))
	if v == null:
		return []
	var out: Array = []
	if str(t.get("set", "")) == "sweep":
		var dead: int = (v.deadwood() as Array).size()
		out.append({"text": tr("Deadwood off (%d)") % dead, "state": "done" if dead == 0 else "todo"})
	else:
		var up: int = v.standing_count()
		out.append({"text": tr("Pins up %d/10") % up, "state": "done" if up == 10 else "todo"})
	out.append({"text": tr("Ball back"), "state": "todo" if v.ball_in_pit() else "done"})
	return out


## Lane `li`'s pins are as the record wants them for its next ball, and the ball is back.
func _work_done(li: int) -> bool:
	var v = _view_of(li)
	if v == null or not state.pins_waiting(building_key, li):
		return false
	if v.ball_in_pit():
		return false
	var rec: Dictionary = state.lane(building_key, li)
	if str(rec["set"]) == "sweep":
		if not (v.deadwood() as Array).is_empty():
			return false
		var standing: Array = rec["standing"]
		for s in 10:
			if bool(standing[s]) != (v.spot_taken(s) >= 0):
				return false
		return true
	return v.standing_count() == 10


# ── what is shown ────────────────────────────────────────────────────────────

func _show() -> void:
	if _carry.is_empty():
		return
	# The lane put its pins right under the hand (a new party, the record moved on).
	if _carry[0].pin_where(int(_carry[1])) != "hand":
		_carry = []
		return
	var pin: Node3D = _carry[0].pin_node(int(_carry[1]))
	if not is_instance_valid(pin):
		return
	# Held up under the finger, upright, a little sway.
	var at := held_at(HOLD_LIFT) if _mouse_free.x >= 0.0 else local_at(Vector2(320, 300), HOLD_LIFT)
	pin.global_position = global_transform * (at - Vector3(0, 0.19, 0))
	pin.global_basis = Basis(Vector3(0, 0, 1), sin(_t * 5.0) * 0.06)


# ── what can be done ─────────────────────────────────────────────────────────

func _spots() -> Array:
	var out: Array = []
	if state == null:
		return out
	for v in lanes:
		var li := _li(v)
		if not state.pins_waiting(building_key, li):
			continue
		var mode := str(state.lane(building_key, li)["set"])
		if v.ball_in_pit() and _carry.is_empty():
			out.append({"id": "ball:%d" % li, "node": v.ball_node(), "verb": tr("Send the ball back up lane %d") % (li + 1)})
		if not _carry.is_empty():
			if _li(_carry[0]) == li and mode == "rack":
				for s in 10:
					if v.spot_taken(s) < 0:
						out.append({"id": "spot:%d:%d" % [li, s], "rect": _spot_rect(v, s), "verb": tr("Stand the pin on its spot")})
			continue
		for k in 10:
			var where: String = v.pin_where(k)
			if where == "deck":
				out.append({"id": "pin:%d:%d" % [li, k], "node": v.pin_node(k), "verb": tr("Clear the pin off the deck") if mode == "sweep" else tr("Pick up the pin")})
			elif where == "pit" and mode == "rack":
				out.append({"id": "pin:%d:%d" % [li, k], "node": v.pin_node(k), "verb": tr("A pin out of the pit")})
	return out


## Spot `s` of lane view `v` on the surface (design px).
func _spot_rect(v, s: int) -> Rect2:
	var c := design_of(to_local(v.spot_point(s)))
	return Rect2(c - SPOT_R, SPOT_R * 2.0)


func _press(id: String) -> void:
	_pressed_at = _mouse
	var p := id.split(":")
	var li := int(p[1]) if p.size() > 1 else -1
	var v = _view_of(li)
	if v == null:
		return
	var mode := str(state.lane(building_key, li)["set"])
	match str(p[0]):
		"ball":
			v.send_ball()
			_check_done(li)
		"pin":
			var k := int(p[2])
			if mode == "sweep":
				if v.pin_where(k) == "deck":
					v.pit_pin(k)
					sfx("pins_few", -16.0, randf_range(1.3, 1.5))
					_check_done(li)
				return
			if v.take_pin(k):
				_carry = [v, k]
				sfx("pin_set", -18.0, 1.5)
		"spot":
			_stand(v, int(p[2]))


## Let go: dragged onto an empty spot, the pin stands there; let go where it was taken (a
## click), it stays in the hand for a click on a spot.
func _release(_id: String) -> void:
	if _carry.is_empty() or _mouse.x < 0.0:
		return
	if _pressed_at.x >= 0.0 and _pressed_at.distance_to(_mouse) < 12.0:
		return
	var v = _carry[0]
	for s in 10:
		if v.spot_taken(s) < 0 and _spot_rect(v, s).grow(6.0).has_point(_mouse):
			_stand(v, s)
			return


func _stand(v, s: int) -> void:
	if _carry.is_empty() or _carry[0] != v:
		return
	var k := int(_carry[1])
	if v.stand_pin(k, s):
		_carry = []
		_check_done(_li(v))


## The lane's pins are up and its ball back: the bell, the record has them set, the stars.
func _check_done(li: int) -> void:
	if not _work_done(li):
		return
	var rec: Dictionary = state.lane(building_key, li)
	var age := float(rec["wait"])
	var who := str(rec["name"])
	var t := {"id": "lane%d" % li, "lane": li, "name": who, "left": 1.0 - clampf(age / BOWLING.PINS_GONE, 0.0, 1.0),
		"band": 0 if age < BOWLING.PINS_OK else (1 if age < BOWLING.PINS_LATE else 2)}
	state.set_pins(building_key, li)
	sfx("pit_bell", -10.0, randf_range(0.97, 1.04))
	var speed := 1.0 - clampf((age - 2.0) / (BOWLING.PINS_GONE - 2.0), 0.0, 1.0)
	var pts := RULES_BIZ.score(speed, 1.0)
	var r := RULES_BIZ.reward(pts, 2)
	var tip := 1 if int(r["stars"]) >= COIN_FROM else 0
	if tip > 0 and CoreRoot != null and CoreRoot.actions != null:
		CoreRoot.actions.biz_sale(building_key, tip, 0, true)
	if CoreRoot != null and CoreRoot.actions != null:
		CoreRoot.actions.biz_score(building_key, {"score": pts, "tip": tip, "what": "Pins", "who": who, "hand": false})
	var v = _view_of(li)
	if tip > 0 and v != null:
		# The coin rolled down the lane to the pin boy.
		fly("res://assets/textury/jednota/coin2.png", 0.05, to_local(v.spot_point(0) + Vector3(0, 0.05, 0.6)), v.spot_point(9) + Vector3(0, 0.05, -0.5), 0.6, 0.02)
		sfx("res://assets/sfx/jednota/coin.mp3", -12.0, 1.1)
	score_card({"ok": true, "score": pts, "stars": int(r["stars"]), "tip": tip, "amount": tip, "speed": speed, "build": 1.0}, "Pins", t)


## Where the bowler of lane `t` is (global): at the far end, over the approach.
func guest_point(t: Dictionary) -> Vector3:
	var v = _view_of(int(t.get("lane", -1)))
	return v.spot_point(0) + Vector3(0, 0.6, 0) if v != null else Vector3.INF


## What is best to do now on the lane worked: the ball back, the deadwood off, a pin to an
## empty spot.
func next_hint() -> Dictionary:
	var id := picked_ticket()
	if id == "":
		return {}
	var li := int(id.substr(4))
	var v = _view_of(li)
	if v == null:
		return {}
	if not _carry.is_empty():
		for s in 10:
			if v.spot_taken(s) < 0:
				return {"rect": _spot_rect(v, s), "gesture": "click"}
		return {}
	if v.ball_in_pit():
		return {"node": v.ball_node(), "gesture": "click"}
	var mode := str(state.lane(building_key, li)["set"])
	for k in 10:
		if v.pin_where(k) == "deck":
			return {"node": v.pin_node(k), "gesture": "click"}
	if mode == "rack":
		for k in 10:
			if v.pin_where(k) == "pit":
				return {"node": v.pin_node(k), "gesture": "click"}
	return {}


func alert() -> int:
	var worst := -1
	for t in rail_tickets():
		worst = maxi(worst, int(t.get("band", 0)))
	return 0 if worst < 0 else (2 if worst == 2 else 1)


func bar_text() -> String:
	var n := rail_tickets().size()
	return tr("LANES WAITING %d") % n if n > 0 else ""


## The pin dropped back where it can go when you step away with it in the hand.
func _closing() -> void:
	if not _carry.is_empty():
		_carry[0].pit_pin(int(_carry[1]))
		_carry = []


## The bare glove for the pins and the ball, closed round a pin in the hand.
func hand_tool() -> String:
	return "open"


func holding() -> String:
	return _held if _held != "" else ("#pin" if not _carry.is_empty() else "")


# ── debug (the shot drivers) ─────────────────────────────────────────────────

## Does lane `li`'s work in the pit as a pin boy would, step by step: the ball back, the
## deadwood off, every empty spot stood. Returns how many clicks it took (0 nothing to do).
func debug_work(li: int) -> int:
	var v = _view_of(li)
	if v == null or not state.pins_waiting(building_key, li):
		return 0
	var n := 0
	if v.ball_in_pit():
		_press("ball:%d" % li)
		n += 1
	var mode := str(state.lane(building_key, li)["set"])
	for k in 10:
		if v.pin_where(k) == "deck" and mode == "sweep":
			_press("pin:%d:%d" % [li, k])
			n += 1
	if mode == "rack":
		for s in 10:
			if v.spot_taken(s) >= 0:
				continue
			for k in 10:
				if v.pin_where(k) in ["deck", "pit"]:
					_press("pin:%d:%d" % [li, k])
					_press("spot:%d:%d" % [li, s])
					n += 2
					break
	return n
