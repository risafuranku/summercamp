class_name NightDirector
extends RefCounted

## The night's director (DESIGN.md §5f). The camp at night has a life of its own and
## something in it watches you: this decides, from what the day made of the camp and from
## how you are playing tonight, what happens and when. It does not spawn the hunting
## enemies (main.gd does, from the night roll); it plays everything around them: sounds
## that are almost right, a light where nothing is, a figure in the office window, the
## phone at three, a lamp dying over you, the room not quite as you left it. It decides;
## scripts/night/director_effects.gd does the deed with the camp's own systems.
##
## Pure logic over a context dictionary (tools/director_check.gd drives it with made-up
## nights). Every few seconds:
##   tension  0-1   the hour, what the camp brings (guests, unhappiness, strangers let in,
##                  what came before), the dark, being alone in it, cues you ignored
##   state          DORMANT, OBSERVATION, UNEASE, SUSPICION, ESCALATION, MANIFESTATION from
##                  the tension; CONFRONTATION while a hunter is close (then it keeps
##                  quiet); RECOVERY after anything big (it lets you breathe)
##   budget         points that come back with time; every event costs its weight, so the
##                  big ones are rare and never back to back, and most minutes are quiet
##   draw           among the events that fit where you are, the state and the budget,
##                  weighted by tonight's archetypes (who is in the camp), novelty (what
##                  you have had is less likely), a chain from the last event, and how you
##                  play (keep watching the window and it happens elsewhere)
## Archetypes (who brings what): OBSERVER (quiet ones, pickers: it is seen at the edge of
## things and avoids being looked at), MIMIC (drinkers, the girls: it sounds like us),
## DISTURBER (families, tramps, a dark camp: it moves things), HUNTER (what main sent out
## tonight: it comes for you; the director only sets the stage and backs off).
## Fair play: nothing in close-ups, minigames, the lake or a job; nothing that blocks a
## door or hurts; every change has a way back; the hunters keep their own tells.

signal event_fired(id: String, info: Dictionary)

enum State { DORMANT, OBSERVATION, UNEASE, SUSPICION, ESCALATION, MANIFESTATION, CONFRONTATION, RECOVERY }
const STATE_NAMES := ["DORMANT", "OBSERVATION", "UNEASE", "SUSPICION", "ESCALATION", "MANIFESTATION", "CONFRONTATION", "RECOVERY"]

const DECIDE_EVERY := 2.0          # real seconds between decisions
const BUDGET_MAX := 14.0
const RECOVERY_SECONDS := Vector2(28.0, 46.0)
const BIG_COST := 8.0
const CONFRONT_NEAR_M := 14.0
const CHAIN_SECONDS := 90.0
const INVESTIGATE_M := 9.0
const INVESTIGATE_SECONDS := 70.0

enum A { OBSERVER, MIMIC, DISTURBER, HUNTER }
const ARCH_NAMES := ["OBSERVER", "MIMIC", "DISTURBER", "HUNTER"]
## Who brings which (guest archetype -> director archetype).
const GUEST_ARCH := {"quiet_guy": A.OBSERVER, "picker": A.OBSERVER, "drunk": A.MIMIC, "cheap_chick": A.MIMIC, "family": A.DISTURBER, "tramp": A.DISTURBER}

## The library. places: where you must be for it (office, back_room, out_lit, out_dark).
## cost: tension budget. min: the lowest state it belongs to. cd: real seconds before it
## may come again tonight. arch: whose it is. next: what it leads to. w: base weight.
const EVENTS := {
	"window_tap":    {"places": ["office"], "cost": 2.0, "min": State.UNEASE, "cd": 150.0, "arch": [A.OBSERVER], "next": ["figure_window"], "w": 1.0},
	"figure_window": {"places": ["office"], "cost": 7.0, "min": State.SUSPICION, "cd": 300.0, "arch": [A.OBSERVER], "next": ["knock"], "w": 1.0, "needs": ["window_open"]},
	"knock":         {"places": ["office", "back_room"], "cost": 5.0, "min": State.SUSPICION, "cd": 220.0, "arch": [A.MIMIC, A.HUNTER], "next": ["handle", "steps_behind"], "w": 1.0},
	"knock_wrong":   {"places": ["office", "back_room"], "cost": 6.0, "min": State.ESCALATION, "cd": 400.0, "arch": [A.MIMIC], "next": ["handle"], "w": 0.8, "after": ["knock"]},
	"handle":        {"places": ["office"], "cost": 8.0, "min": State.ESCALATION, "cd": 500.0, "arch": [A.HUNTER, A.MIMIC], "next": [], "w": 0.7},
	"phone_night":   {"places": ["office", "back_room"], "cost": 5.0, "min": State.SUSPICION, "cd": 600.0, "arch": [A.MIMIC], "next": ["knock"], "w": 0.9, "hours": [23.0, 4.5]},
	"wall_brush":    {"places": ["back_room"], "cost": 6.0, "min": State.ESCALATION, "cd": 400.0, "arch": [A.HUNTER, A.DISTURBER], "next": [], "w": 1.0},
	"radio_bleed":   {"places": ["office"], "cost": 2.0, "min": State.UNEASE, "cd": 160.0, "arch": [A.MIMIC, A.DISTURBER], "next": ["phone_night"], "w": 0.8},
	"room_changed":  {"places": ["entering"], "cost": 4.0, "min": State.SUSPICION, "cd": 420.0, "arch": [A.DISTURBER], "next": [], "w": 1.2},
	"lamp_out":      {"places": ["out_lit"], "cost": 4.0, "min": State.UNEASE, "cd": 140.0, "arch": [A.DISTURBER], "next": ["silhouette", "steps_behind"], "w": 1.0, "needs": ["lamp_near"]},
	"steps_behind":  {"places": ["out_dark", "out_lit"], "cost": 4.0, "min": State.UNEASE, "cd": 180.0, "arch": [A.OBSERVER, A.HUNTER, A.MIMIC], "next": ["call_far"], "w": 1.0, "needs": ["walking"]},
	"call_far":      {"places": ["out_dark", "out_lit"], "cost": 3.0, "min": State.UNEASE, "cd": 200.0, "arch": [A.MIMIC], "next": ["silhouette"], "w": 1.0},
	"silhouette":    {"places": ["out_dark", "out_lit"], "cost": 8.0, "min": State.MANIFESTATION, "cd": 360.0, "arch": [A.OBSERVER], "next": [], "w": 1.0},
	"omen":          {"places": ["out_dark", "out_lit"], "cost": 5.0, "min": State.SUSPICION, "cd": 500.0, "arch": [A.OBSERVER, A.DISTURBER], "next": [], "w": 0.8},
}
## Places where nothing may happen (close-ups, jobs, the lake, the PC's own screen).
const SAFE_PLACES := ["modal", "job", "lake", "room"]

var state := State.DORMANT
var tension := 0.0
var budget := 4.0
var arch_weights := [0.0, 0.0, 0.0, 0.0]
## Tonight: event id -> times; the last event; when (night seconds) each fired.
var tonight: Dictionary = {}
var last_id := ""
var last_reason := ""
var recent: Array = []           # [{id, t, place, why}]
## Across nights: event id -> times (it does not repeat itself much over a month).
var ever: Dictionary = {}
## How you play tonight (seconds in each place, looks at the window, cues ignored).
var time_in: Dictionary = {}
var window_looks := 0.0
var ignored := 0
var investigated := 0

var _t := 0.0                    # night seconds
var _decide_in := DECIDE_EVERY
var _recover_until := -1.0
var _cooldown_until: Dictionary = {}
var _chain: Dictionary = {}      # id -> until (night seconds)
var _pending_check: Array = []   # [{id, pos, until}]
var _night := -1
## No two things close together: the next one not before this (night seconds), and a
## while after you come somewhere new (the place has to settle around you first).
var _next_any := 0.0
var _last_place := ""
## Real seconds between two events, by state (more often as the night closes in).
const GAP := {State.UNEASE: 46.0, State.SUSPICION: 34.0, State.ESCALATION: 24.0, State.MANIFESTATION: 18.0}
const SETTLE_SECONDS := 8.0
var _rng := RandomNumberGenerator.new()


func _init(seed := 0) -> void:
	if seed != 0:
		_rng.seed = seed
	else:
		_rng.randomize()


## A new night (main: at the night roll). Forgets tonight, keeps `ever`.
func begin_night(night_index: int) -> void:
	_night = night_index
	state = State.DORMANT
	tension = 0.0
	budget = 4.0
	tonight.clear()
	recent.clear()
	time_in.clear()
	window_looks = 0.0
	ignored = 0
	investigated = 0
	last_id = ""
	last_reason = ""
	_t = 0.0
	_decide_in = DECIDE_EVERY
	_recover_until = -1.0
	_cooldown_until.clear()
	_chain.clear()
	_pending_check.clear()
	_next_any = 20.0
	_last_place = ""


## Every frame. ctx: {night (bool), quiet (bool: a quiet night), hour, place, pos (Vector3),
## pressure (omens.pressure), guests_by_arch {quiet_guy: n...}, admitted, hunting (count),
## hunter_near_m, dark (bool), lamp_near (bool), walking (bool), window_open (bool),
## looking_at_window (bool), entering (bool: just came in from outside)}.
## Returns the event to play now ("" most of the time).
func tick(delta: float, ctx: Dictionary) -> String:
	if not bool(ctx.get("night", false)):
		state = State.DORMANT
		return ""
	_t += delta
	var place := str(ctx.get("place", ""))
	time_in[place] = float(time_in.get(place, 0.0)) + delta
	if place != _last_place:
		_last_place = place
		_next_any = maxf(_next_any, _t + SETTLE_SECONDS)
	if bool(ctx.get("looking_at_window", false)):
		window_looks += delta
	_check_reactions(ctx)
	budget = minf(BUDGET_MAX, budget + delta * _budget_rate(ctx))
	_decide_in -= delta
	# Coming in from outside is a moment of its own: the room may have changed.
	var entering := bool(ctx.get("entering", false))
	if _decide_in > 0.0 and not entering:
		return ""
	_decide_in = DECIDE_EVERY
	_update_archetypes(ctx)
	_update_state(ctx)
	if bool(ctx.get("quiet", false)) or SAFE_PLACES.has(place):
		return ""
	if state == State.DORMANT or state == State.OBSERVATION or state == State.CONFRONTATION or state == State.RECOVERY:
		return ""
	# Coming in may find the room changed at once; anything else waits its turn.
	if _t < _next_any and not entering:
		return ""
	var id := _draw(ctx, entering)
	if id != "":
		_fire(id, ctx)
	return id


func _budget_rate(ctx: Dictionary) -> float:
	var p := float(ctx.get("pressure", 0.3))
	return clampf(0.08 + 0.05 * p, 0.08, 0.4)


## The weight of each archetype tonight, from who is in the camp and what came out.
func _update_archetypes(ctx: Dictionary) -> void:
	var w := [0.15, 0.15, 0.15, 0.0]
	var by: Dictionary = ctx.get("guests_by_arch", {})
	for g in by.keys():
		if GUEST_ARCH.has(g):
			w[int(GUEST_ARCH[g])] += 0.35 * float(by[g])
	w[A.OBSERVER] += 0.8 * float(ctx.get("admitted", 0))
	if bool(ctx.get("dark", false)):
		w[A.DISTURBER] += 0.9
	w[A.HUNTER] += 0.7 * float(ctx.get("hunting", 0))
	arch_weights = w


func _update_state(ctx: Dictionary) -> void:
	var hour := float(ctx.get("hour", 22.0))
	# The night deepens from 21:30 to 03:00, then thins toward dawn.
	var h := hour if hour >= 12.0 else hour + 24.0
	var deep := clampf((h - 21.5) / 5.5, 0.0, 1.0)
	if h > 27.0:
		deep = clampf(1.0 - (h - 27.0) / 3.5, 0.3, 1.0)
	var place := str(ctx.get("place", ""))
	var alone := 0.12 if place == "out_dark" else (0.04 if place == "out_lit" else 0.0)
	var want := 0.12 * deep + 0.07 * float(ctx.get("pressure", 0.3)) + 0.12 * float(ctx.get("hunting", 0)) \
		+ (0.16 if bool(ctx.get("dark", false)) else 0.0) + alone + 0.06 * float(ignored) - 0.04 * float(investigated)
	want = clampf(want, 0.0, 1.0)
	# It builds over minutes, not seconds.
	tension = move_toward(tension, want, DECIDE_EVERY * 0.006)
	if float(ctx.get("hunter_near_m", INF)) < CONFRONT_NEAR_M:
		state = State.CONFRONTATION
		return
	if _t < _recover_until:
		state = State.RECOVERY
		tension = maxf(0.0, tension - DECIDE_EVERY * 0.01)
		return
	if bool(ctx.get("quiet", false)) or tension < 0.08:
		state = State.DORMANT
	elif tension < 0.2:
		state = State.OBSERVATION
	elif tension < 0.36:
		state = State.UNEASE
	elif tension < 0.54:
		state = State.SUSPICION
	elif tension < 0.72:
		state = State.ESCALATION
	else:
		state = State.MANIFESTATION


## The candidates and the draw; `last_reason` says why the winner won.
func candidates(ctx: Dictionary, entering := false) -> Dictionary:
	var place := "entering" if entering else str(ctx.get("place", ""))
	var hour := float(ctx.get("hour", 22.0))
	var out := {}
	# Tonight's camp has a character: an archetype carrying little weight next to the
	# strongest one does not act (rather silence than something out of character).
	var top := 0.0
	for x in arch_weights:
		top = maxf(top, float(x))
	for id in EVENTS.keys():
		var e: Dictionary = EVENTS[id]
		if not (e["places"] as Array).has(place):
			continue
		if int(e["min"]) > int(state):
			continue
		if float(e["cost"]) > budget:
			continue
		if _t < float(_cooldown_until.get(id, -1.0)):
			continue
		if id == last_id:
			continue
		if e.has("hours") and not _in_hours(hour, e["hours"]):
			continue
		var ok := true
		for need in e.get("needs", []):
			if not bool(ctx.get(need, false)):
				ok = false
		for need2 in e.get("after", []):
			if int(tonight.get(need2, 0)) <= 0:
				ok = false
		if not ok:
			continue
		var aw := 0.0
		for a in e["arch"]:
			aw = maxf(aw, float(arch_weights[int(a)]))
		if aw < top * 0.4:
			continue
		var wt := float(e["w"]) * (0.25 + aw)
		wt *= pow(0.3, float(tonight.get(id, 0))) * pow(0.75, float(ever.get(id, 0)))
		if _t < float(_chain.get(id, -1.0)):
			wt *= 3.0
		# You keep watching the window: it happens elsewhere.
		if (id == "figure_window" or id == "window_tap") and window_looks > 25.0:
			wt *= 0.25
		# You hide in the office all night: the office is where it comes.
		if place == "office" or place == "back_room":
			var inside := float(time_in.get("office", 0.0)) + float(time_in.get("back_room", 0.0))
			if inside > _t * 0.6 and _t > 60.0:
				wt *= 1.6
		# Big things only when the night has earned them.
		if float(e["cost"]) >= BIG_COST and int(state) < State.ESCALATION:
			wt *= 0.4
		if wt > 0.0:
			out[id] = wt
	return out


func _draw(ctx: Dictionary, entering: bool) -> String:
	var c := candidates(ctx, entering)
	if c.is_empty():
		return ""
	# Most decisions come to nothing: the night is mostly quiet.
	var quiet_chance := clampf(0.78 - 0.1 * float(int(state) - State.UNEASE), 0.35, 0.85)
	if not entering and _rng.randf() < quiet_chance:
		return ""
	var total := 0.0
	for id in c.keys():
		total += float(c[id])
	var r := _rng.randf() * total
	for id in c.keys():
		r -= float(c[id])
		if r <= 0.0:
			last_reason = "%s: %s, budget %.1f, w %.2f of %.2f" % [id, STATE_NAMES[state], budget, float(c[id]), total]
			return str(id)
	return str(c.keys().back())


func _fire(id: String, ctx: Dictionary) -> void:
	var e: Dictionary = EVENTS[id]
	budget -= float(e["cost"])
	tonight[id] = int(tonight.get(id, 0)) + 1
	ever[id] = int(ever.get(id, 0)) + 1
	last_id = id
	_cooldown_until[id] = _t + float(e["cd"])
	for n in e["next"]:
		_chain[n] = _t + CHAIN_SECONDS
	if float(e["cost"]) >= BIG_COST:
		_recover_until = _t + _rng.randf_range(RECOVERY_SECONDS.x, RECOVERY_SECONDS.y)
	_next_any = _t + float(GAP.get(state, 40.0)) * _rng.randf_range(0.8, 1.4)
	recent.append({"id": id, "t": _t, "place": str(ctx.get("place", "")), "why": last_reason})
	while recent.size() > 8:
		recent.remove_at(0)
	event_fired.emit(id, {"state": STATE_NAMES[state], "tension": tension})


## An event happened somewhere (effects tell): did you go and look?
func watch(id: String, pos: Vector3) -> void:
	if pos == Vector3.INF:
		return
	_pending_check.append({"id": id, "pos": pos, "until": _t + INVESTIGATE_SECONDS})


func _check_reactions(ctx: Dictionary) -> void:
	if _pending_check.is_empty():
		return
	var p: Vector3 = ctx.get("pos", Vector3.INF)
	var keep: Array = []
	for c in _pending_check:
		if p != Vector3.INF and p.distance_to(c["pos"]) < INVESTIGATE_M:
			investigated += 1
		elif _t > float(c["until"]):
			ignored += 1
		else:
			keep.append(c)
	_pending_check = keep


static func _in_hours(hour: float, span: Array) -> bool:
	var a := float(span[0])
	var b := float(span[1])
	return (hour >= a or hour < b) if a > b else (hour >= a and hour < b)


func snapshot() -> Dictionary:
	var cds := {}
	for id in _cooldown_until.keys():
		var left := float(_cooldown_until[id]) - _t
		if left > 0.0:
			cds[id] = int(left)
	return {"state": STATE_NAMES[state], "tension": tension, "budget": budget, "arch": arch_weights, "recent": recent, "cooldowns": cds,
		"time_in": time_in, "ignored": ignored, "investigated": investigated, "why": last_reason, "night_t": _t}


func export_state() -> Dictionary:
	return {"ever": ever.duplicate()}


func import_state(d: Dictionary) -> void:
	ever = (d.get("ever", {}) as Dictionary).duplicate()
