extends RefCounted

## The camp on Goggle (the PC's Reviews tab, scripts/os98/apps/goggle_app.gd; DESIGN.md
## §5i): every guest's review in public, the stars averaged as the world sees them. Pure
## logic (seeded), saved by main ("goggle"), checked by tools/goggle_check.gd.
##   - the camp's page was there before you: a few reviews from last summer, mostly bad
##     (and one or two that nobody should have written);
##   - the average (of what is up, to one decimal) is shown, and opens nothing for now
##     (Richard, 20. 10.: the start must play; the rating may matter again later);
##   - Builder 98's blueprints and the room upgrades open by how many guests the camp has
##     had at once (TIERS: 10, 20, 30...; `peak_guests`, main feeds it); once open, open;
##   - a review you do not like can go: SpotlessName Ltd take it down by the next morning,
##     for a price that rises with each one; now and then Goggle notices, the review
##     stays, the money is gone and the page says so for a few days (the rating with it);
##   - answer a review as the owner: an apology to a bad one may bring an edit by the next
##     morning (a star more), blaming the weather never does.
## Main feeds it the guests' reviews (EventBus.guest_review_posted) and settles it at dawn.

## A blueprint tier: the guests in the camp at once it needs, what it opens. The corn
## stand is there from the first day: cheap food and a drink when nothing else is open.
const TIERS := [
	{"guests": 0, "items": ["tent_1", "cabin_1", "toilet_block", "shower_block", "corn_stand", "bonfire", "bench", "flower_bed", "picnic_table", "path", "lamp_post"]},
	{"guests": 10, "items": ["pub", "caravan_1", "hammock", "gnome", "sports_field"]},
	{"guests": 20, "items": ["restaurant", "playground", "ping_pong", "flagpole", "upgrade:2"]},
	{"guests": 30, "items": ["vecerka", "lake_slide"]},
	{"guests": 40, "items": ["upgrade:3", "bowling"]},
]
## SpotlessName Ltd's price for the first review, and what each one after adds.
const REMOVE_BASE := 45
const REMOVE_STEP := 30
## The chance Goggle catches one, and what each one taken down before adds to it.
const CAUGHT_BASE := 0.10
const CAUGHT_STEP := 0.05
## Caught: the banner and the rating it costs, for this many days.
const FLAG_DAYS := 3
const FLAG_PENALTY := 0.3
## An apology to a review of 1-2 stars: the chance of an edit by the morning.
const APOLOGY_EDIT := 0.4

## The page as it was before you came (last summer's guests, day <= 0: "a year ago").
const OLD_REVIEWS := [
	{"name": "Jirka Holub", "archetype": "drunk", "stars": 2, "text": "Beer warm, toilets worse. The lake is nice if you like brown.", "day": -320},
	{"name": "Marketa S.", "archetype": "cheap_chick", "stars": 1, "text": "Mould in the cabin, a dead mouse in the shower. The owner just stared at us.", "day": -300},
	{"name": "Fam. Dvorakovi", "archetype": "family", "stars": 3, "text": "The kids loved the slide. Shame about the smell from the lake at night.", "day": -290},
	{"name": "Pavel K.", "archetype": "quiet_guy", "stars": 4, "text": "Quiet. Very quiet. I slept well.", "day": -280},
	{"name": "Houbari z Jihlavy", "archetype": "picker", "stars": 2, "text": "Mushrooms in the woods, yes. But someone walks round the tents before dawn and does not answer.", "day": -270},
	{"name": "anonymous", "archetype": "tramp", "stars": 1, "text": "Do not let the boy in the red shoes in. He knocks.", "day": -261,
		"ghost_reply": "We have his shoe. He can come and get it."},
	{"name": "Lenka", "archetype": "cheap_chick", "stars": 3, "text": "Cheap and nobody asks questions. Bring your own sheets.", "day": -250},
]
const REPLIES := {
	"thanks": "Thank you for staying with us. We hope to see you again next summer!",
	"sorry": "We are sorry your stay was not what it should have been. We have looked into it and it is being put right.",
	"weather": "The weather in the hills is not something we can do anything about. Other guests had a lovely time.",
}

## [{id, guest_id, name, archetype, stars, text, day, nights, old, removed, removing,
##   flagged, reply, reply_day, edited, ghost_reply, helpful}]
var reviews: Array = []
var removed_count := 0
var flagged_until := -999
var settled_day := 0
## The best tier the camp has reached (a tier once open stays open).
var tier := 0
## The most guests the camp has had at once (what opens the tiers).
var peak_guests := 0
var _next_id := 1
var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


## A new camp's page: last summer's reviews.
func reset(seed_value: int = 0) -> void:
	reviews.clear()
	removed_count = 0
	flagged_until = -999
	settled_day = 0
	tier = 0
	peak_guests = 0
	_next_id = 1
	if seed_value != 0:
		_rng.seed = seed_value
	for r in OLD_REVIEWS:
		var e := _entry(str(r["name"]), str(r["archetype"]), int(r["stars"]), str(r["text"]), int(r["day"]), 1, -1)
		e["old"] = true
		e["ghost_reply"] = str(r.get("ghost_reply", ""))
		e["helpful"] = _rng.randi_range(0, 6)
	_refresh_tier()


func _entry(name: String, arch: String, stars: int, text: String, day: int, nights: int, guest_id: int) -> Dictionary:
	var e := {"id": _next_id, "guest_id": guest_id, "name": name, "archetype": arch, "stars": clampi(stars, 1, 5), "text": text,
		"day": day, "nights": nights, "old": false, "removed": false, "removing": -1, "flagged": false,
		"reply": "", "reply_day": -1, "edited": false, "ghost_reply": "", "helpful": 0}
	_next_id += 1
	reviews.append(e)
	return e


## A guest's review (guest_manager's dictionary) goes up on the page. Returns the entry.
func add_guest_review(r: Dictionary, day: int) -> Dictionary:
	var e := _entry(str(r.get("name", "Guest")), str(r.get("archetype", "")), int(r.get("rating", 3)), str(r.get("text", "")),
		int(r.get("day", day)), int(r.get("stay_nights", 1)), int(r.get("guest_id", -1)))
	e["helpful"] = _rng.randi_range(0, 2)
	return e


func by_id(id: int) -> Dictionary:
	for e in reviews:
		if int(e["id"]) == id:
			return e
	return {}


## What is on the page (not taken down), newest first.
func shown() -> Array:
	var out: Array = reviews.filter(func(e): return not bool(e["removed"]))
	out.sort_custom(func(a, b): return int(a["day"]) > int(b["day"]) or (int(a["day"]) == int(b["day"]) and int(a["id"]) > int(b["id"])))
	return out


func count() -> int:
	return shown().size()


## The plain average of what is up (0 with nothing up).
func average() -> float:
	var s := shown()
	if s.is_empty():
		return 0.0
	var sum := 0.0
	for e in s:
		sum += float(e["stars"])
	return sum / float(s.size())


func flagged(day: int) -> bool:
	return day <= flagged_until


## The rating as the world (and Builder 98) sees it: the average, to one decimal, less
## the penalty while Goggle has the page flagged.
func rating(day: int) -> float:
	var r := average()
	if flagged(day):
		r = maxf(1.0, r - FLAG_PENALTY)
	return snappedf(r, 0.1)


## How many reviews of each star (index 1..5).
func histogram() -> Array:
	var h := [0, 0, 0, 0, 0, 0]
	for e in shown():
		h[int(e["stars"])] += 1
	return h


# ── the blueprints ────────────────────────────────────────────────────────────

## The tier open now (the best one reached; it stays open).
func _refresh_tier(_day: int = 1) -> int:
	var best := tier
	for i in TIERS.size():
		if peak_guests >= int(TIERS[i]["guests"]):
			best = maxi(best, i)
	var opened := best > tier
	tier = best
	return best if opened else -1


## After a change: the tier just opened (-1 none).
func check_tier(day: int) -> int:
	return _refresh_tier(day)


## The guests in the camp now (main, every few seconds): the most at once is what counts.
## The tier just opened (-1 none).
func check_guests(n: int) -> int:
	peak_guests = maxi(peak_guests, n)
	return _refresh_tier()


## Which tier `item` is in (a building type, or "upgrade:2" / "upgrade:3"); 0 if unlisted.
static func tier_of(item: String) -> int:
	for i in TIERS.size():
		if (TIERS[i]["items"] as Array).has(item):
			return i
	return 0


func unlocked(item: String) -> bool:
	return tier_of(item) <= tier


## The next tier still shut: {guests, items} or {}.
func next_tier() -> Dictionary:
	return TIERS[tier + 1] if tier + 1 < TIERS.size() else {}


# ── SpotlessName Ltd ──────────────────────────────────────────────────────────

func removal_cost() -> int:
	return REMOVE_BASE + REMOVE_STEP * (removed_count + pending_removals())


func pending_removals() -> int:
	return reviews.filter(func(e): return int(e["removing"]) >= 0 and not bool(e["removed"])).size()


## Booked for taking down by the morning. False when it cannot be (gone, booked, caught).
func request_removal(id: int, day: int) -> bool:
	var e := by_id(id)
	if e.is_empty() or bool(e["removed"]) or int(e["removing"]) >= 0 or bool(e["flagged"]):
		return false
	e["removing"] = day
	return true


# ── the owner's answer ────────────────────────────────────────────────────────

func reply(id: int, kind: String, day: int) -> bool:
	var e := by_id(id)
	if e.is_empty() or str(e["reply"]) != "" or not REPLIES.has(kind):
		return false
	e["reply"] = kind
	e["reply_day"] = day
	return true


## The morning of `day`: the removals booked before it go (or are caught), apologies may
## bring an edit. Returns {removed: [entries], caught: [entries], edited: [entries],
## tier: the tier just opened (-1 none)}.
func settle(day: int) -> Dictionary:
	var out := {"removed": [], "caught": [], "edited": [], "tier": -1}
	if day <= settled_day:
		return out
	settled_day = day
	for e in reviews:
		if int(e["removing"]) >= 0 and int(e["removing"]) < day and not bool(e["removed"]):
			var p := CAUGHT_BASE + CAUGHT_STEP * float(removed_count)
			if _rng.randf() < p:
				e["removing"] = -1
				e["flagged"] = true
				flagged_until = day + FLAG_DAYS - 1
				(out["caught"] as Array).append(e)
			else:
				e["removed"] = true
				removed_count += 1
				(out["removed"] as Array).append(e)
		if str(e["reply"]) == "sorry" and int(e["reply_day"]) < day and not bool(e["edited"]) and int(e["stars"]) <= 2 and not bool(e["old"]):
			e["edited"] = true
			if _rng.randf() < APOLOGY_EDIT:
				e["stars"] = int(e["stars"]) + 1
				e["text"] = str(e["text"]) + " EDIT: the owner wrote to us and apologised. One star more."
				(out["edited"] as Array).append(e)
	out["tier"] = check_tier(day)
	return out


func export_state() -> Dictionary:
	return {"reviews": reviews.duplicate(true), "removed_count": removed_count, "flagged_until": flagged_until,
		"settled_day": settled_day, "tier": tier, "next_id": _next_id, "peak_guests": peak_guests}


func import_state(d: Dictionary) -> void:
	reviews.clear()
	for r in d.get("reviews", []):
		if r is Dictionary:
			var e: Dictionary = (r as Dictionary).duplicate(true)
			for k in ["id", "guest_id", "stars", "day", "nights", "removing", "reply_day", "helpful"]:
				e[k] = int(e.get(k, -1))
			for k in ["old", "removed", "flagged", "edited"]:
				e[k] = bool(e.get(k, false))
			for k in ["name", "archetype", "text", "reply", "ghost_reply"]:
				e[k] = str(e.get(k, ""))
			reviews.append(e)
	removed_count = int(d.get("removed_count", 0))
	flagged_until = int(d.get("flagged_until", -999))
	settled_day = int(d.get("settled_day", 0))
	tier = int(d.get("tier", 0))
	peak_guests = int(d.get("peak_guests", 0))
	_next_id = maxi(1, int(d.get("next_id", reviews.size() + 1)))
