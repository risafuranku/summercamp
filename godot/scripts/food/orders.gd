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
	"rest": {"drunk": 1, "tramp": 1, "quiet_guy": 1, "cheap_chick": 1, "picker": 1, "family": 2},
	"vecerka": {"drunk": 2, "tramp": 1, "quiet_guy": 1, "cheap_chick": 1, "picker": 2, "family": 1},
}

## What was served to each visit so far: "<guest id>@<visit start>" -> count. Kept for
## the session, so leaving the close-up and coming back does not refill anybody.
static var _served: Dictionary = {}


## The guests in building `key` now: [{id, name, archetype, figures, visit}], arrived
## and not queuing outside.
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
		})
	return out


## How many more this visitor will have (0 = they are done).
static func left_for(v: Dictionary, profile: String) -> int:
	var per: int = int((APPETITE.get(profile, {}) as Dictionary).get(str(v.get("archetype", "")), 1))
	return maxi(0, per * int(v.get("figures", 1)) - int(_served.get(str(v.get("visit", "")), 0)))


static func note_served(v: Dictionary) -> void:
	var k := str(v.get("visit", ""))
	_served[k] = int(_served.get(k, 0)) + 1


## The till rings: the money is the camp's.
static func pay(amount: int) -> void:
	if amount != 0 and CoreRoot != null and CoreRoot.actions != null:
		CoreRoot.actions.add_money(amount)


## How it went down with them: a little on their mood, and what they think now.
static func mood(guest_id: int, delta: float, thought: String) -> void:
	if GuestManager != null and GuestManager.has_method("apply_guest_event"):
		GuestManager.apply_guest_event(guest_id, delta, thought)


static func first_name(full: String) -> String:
	var parts := full.split(" ")
	return parts[0] if parts.size() > 0 else full
