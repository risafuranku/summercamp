extends RefCounted

## Orders for the counter minigames (the pub tap, the bistro pass, the Jednota till):
## who of the guests the simulation has visiting the building right now, how much each
## of them still has in them this visit, the money for what you served and how it went
## down with them. Serving by hand is on top of the building's own takings (its passive
## income): the sale, plus a tip when it was done well.

const POSES = preload("res://scripts/attractions/poses.gd")

## Per person, per visit: beers at the pub, meals at the bistro, baskets at the Jednota.
const APPETITE := {
	"pub": {"drunk": 4, "tramp": 3, "quiet_guy": 2, "cheap_chick": 2, "picker": 1, "family": 1},
	# One plate each at the bistro (its tickets: core/systems/bistro_rules.gd).
	"rest": {"drunk": 1, "tramp": 1, "quiet_guy": 1, "cheap_chick": 1, "picker": 1, "family": 1},
	"vecerka": {"drunk": 2, "tramp": 1, "quiet_guy": 1, "cheap_chick": 1, "picker": 2, "family": 1},
}

## What was served to each visit so far: "<guest id>@<visit start>" -> count. Kept for
## the session, so leaving the close-up and coming back does not refill anybody.
static var _served: Dictionary = {}


## The guests in building `key` now: [{id, name, archetype, figures, visit, arrive}],
## arrived and not queuing outside (arrive: the game minute they came in).
static func visitors(key: String) -> Array:
	var out: Array = []
	if GuestManager == null or key == "":
		return out
	var now: int = GuestManager._absolute_minutes(maxi(1, GuestManager._last_known_day), GuestManager._last_known_hour, GuestManager._last_known_minute)
	for g in GuestManager.get_guest_life_snapshot():
		var act: Dictionary = g.get("activity", {}) if g.get("activity", {}) is Dictionary else {}
		if str(act.get("kind", "")) != "visit" or str(act.get("target_key", "")) != key or bool(act.get("queued", false)):
			continue
		if int(act.get("arrive", now)) > now:
			continue
		var arch := str(g.get("archetype", ""))
		out.append({
			"id": int(g.get("id", 0)),
			"name": str(g.get("name", "Guest")),
			"archetype": arch,
			"figures": POSES.figure_count(arch, int(g.get("party_size", 1))),
			"visit": "%d@%d" % [int(g.get("id", 0)), int(act.get("start", 0))],
			"arrive": int(act.get("arrive", now)),
		})
	return out


## How many more this visitor will have (0 = they are done).
static func left_for(v: Dictionary, profile: String) -> int:
	var per: int = int((APPETITE.get(profile, {}) as Dictionary).get(str(v.get("archetype", "")), 1))
	return maxi(0, per * int(v.get("figures", 1)) - int(_served.get(str(v.get("visit", "")), 0)))


static func note_served(v: Dictionary) -> void:
	var k := str(v.get("visit", ""))
	_served[k] = int(_served.get(k, 0)) + 1
	if Coop.is_client():
		Coop.send_request("served", [k])


## Whether visit `visit` at business `key` has had anything yet. A building without
## books (an old save, a harness camp) feeds them as before; on the joining machine a
## hand's serving happens in the host's camp, so a staffed site counts as served.
static func served(key: String, visit: String) -> bool:
	if int(_served.get(visit, 0)) > 0:
		return true
	if CoreRoot == null or CoreRoot.get_state() == null:
		return true
	var s: Dictionary = (CoreRoot.get_state().biz.get("sites", {}) as Dictionary).get(key, {})
	if s.is_empty():
		return true
	return bool(s.get("staff", false)) and not Coop.sim_here()


## The till rings: the money is the camp's.
static func pay(amount: int) -> void:
	if amount != 0 and CoreRoot != null and CoreRoot.actions != null:
		CoreRoot.actions.add_money(amount)


## How it went down with them: a little on their mood, and what they think now.
static func mood(guest_id: int, delta: float, thought: String) -> void:
	if GuestManager != null and GuestManager.has_method("apply_guest_event"):
		GuestManager.apply_guest_event(guest_id, delta, thought)


## A meal or a drink they will remember in their review (the best and the worst are
## kept: "The fried cheese was perfect."), its score 0..100. The host's guests: the
## joining machine sends it there.
static func note_meal(guest_id: int, line: String, score: int) -> void:
	if line == "":
		return
	if Coop.is_client():
		Coop.send_request("meal", [guest_id, line, score])
		return
	if GuestManager != null and GuestManager.has_method("note_meal"):
		GuestManager.note_meal(guest_id, line, score)


## Visits kept in their building past their time (guest_life.visit_holds), by who keeps
## them: "rest" (the bistro's kitchen: waiting for the plate, eating it), "vecerka" (the
## Jednota: looking round, in the queue for the till), "pub" (waiting to pay their tab)
## -> {guest id: game minute}. The simulation gets the latest of them all.
static var _holds: Dictionary = {}


static func set_holds(source: String, holds: Dictionary) -> void:
	_holds[source] = holds
	var merged := {}
	for s in _holds:
		var h: Dictionary = _holds[s]
		for gid in h:
			merged[gid] = maxi(int(merged.get(gid, -1)), int(h[gid]))
	var life = GuestManager.get("_life") if GuestManager != null else null
	if life != null and "visit_holds" in life:
		life.visit_holds = merged


static func first_name(full: String) -> String:
	var parts := full.split(" ")
	return parts[0] if parts.size() > 0 else full
