extends Node

## The month's books (DESIGN.md §11.1). Vera is away the whole autumn (core/systems/
## season.gd: 19 September to 19 October 1998) and comes back on the morning train of
## day 31 (her last mail: "I will count them myself"). This node keeps
## what she will read: the till at the start, what came at night and how often you were
## hurt, the jobs left for the electrician, and the reviews. At 08:00 on day 8 main asks
## for the report (report()) and shows scripts/ui/week_report_screen.gd.
##
## The verdict is a plain grade of money, reviews and nights. The coda under it is the
## found-CD part: Vera counts the guests herself, and the count depends on what you let in.

const RETURN_DAY := Season.RETURN_DAY
const RETURN_HOUR := 8.0

const ENEMY_NAMES := {
	"silent_man": "the Silent Man",
	"tourist": "the Tourist",
	"girl": "the Girl",
	"whistler": "the Whistler",
	"child": "the Extra Child",
	"basket": "the Basket Man",
	"stalker": "the Antlered Man",
}

var start_money := 0
var closed := false          # the report has been shown; the camp runs on (endless)
var _nights: Dictionary = {} # night index (String) -> Array of enemy ids
var _hits := 0
var _damage := 0
var _jobs_left := 0
var _paged := false


func reset(money: int) -> void:
	start_money = money
	closed = false
	_nights.clear()
	_hits = 0
	_damage = 0
	_jobs_left = 0
	_paged = false


func note_enemy(enemy_id: String, night_index: int) -> void:
	var key := str(night_index)
	var list: Array = _nights.get(key, [])
	if not list.has(enemy_id):
		list.append(enemy_id)
	_nights[key] = list


## Nights on which anything came, so far.
func nights_visited() -> int:
	var n := 0
	for key in _nights.keys():
		if not (_nights[key] as Array).is_empty():
			n += 1
	return n


## Different kinds of thing that have come, so far.
func kinds_seen() -> int:
	var kinds := {}
	for key in _nights.keys():
		for id in _nights[key]:
			kinds[id] = true
	return kinds.size()


func note_hit(amount: int) -> void:
	_hits += 1
	_damage += maxi(0, amount)


## Night jobs still open at dawn: the electrician's or nobody's.
func note_jobs_left(count: int) -> void:
	_jobs_left += maxi(0, count)


## True once, on the morning of day 8 before the train: the pager line.
func should_page(day: int, hours: float) -> bool:
	if closed or _paged or day < RETURN_DAY or hours < 6.5:
		return false
	_paged = true
	return true


func is_due(day: int, hours: float) -> bool:
	return not closed and (day > RETURN_DAY or (day == RETURN_DAY and hours >= RETURN_HOUR))


## Everything the report screen needs. `state` is the GameState.
func report(state) -> Dictionary:
	var money := int(state.money) if state != null else 0
	var reviews: Array = state.guest_reviews if state != null else []
	var hosted := 0
	var rated := 0
	var stars := 0.0
	var gave_up := 0
	var stormed := 0
	for r_any in reviews:
		if not (r_any is Dictionary):
			continue
		var r: Dictionary = r_any
		if bool(r.get("gave_up", false)):
			gave_up += 1
			continue
		hosted += 1
		if bool(r.get("stormed_off", false)):
			stormed += 1
		if r.has("rating"):
			rated += 1
			stars += float(r.get("rating", 0))
	if state != null:
		hosted += (state.guests as Array).size()
	var avg := stars / float(rated) if rated > 0 else 0.0

	var tally: Dictionary = {}
	var visited := 0
	for key in _nights.keys():
		var list: Array = _nights[key]
		if list.is_empty():
			continue
		visited += 1
		for id in list:
			tally[id] = int(tally.get(id, 0)) + 1
	var came: Array = []
	for id in ["silent_man", "tourist", "girl", "whistler", "child", "basket", "stalker"]:
		if tally.has(id):
			var n := int(tally[id])
			came.append("%s%s" % [ENEMY_NAMES[id], (" x%d" % n) if n > 1 else ""])
	var nights := RETURN_DAY - 1

	var delta := money - start_money
	var score := 0
	score += 2 if delta >= 4000 else (1 if delta >= 0 else -1)
	if rated > 0:
		score += 2 if avg >= 3.8 else (1 if avg >= 3.0 else (-1 if avg < 2.3 else 0))
	score -= 1 if gave_up + stormed >= 8 else 0
	score -= 1 if _hits >= 20 else 0
	score -= 1 if _jobs_left >= 10 else 0
	var grade := "good" if score >= 3 else ("poor" if score <= 0 else "fair")

	var verdict := ""
	match grade:
		"good":
			verdict = "The books balance and the guests write nice things. Nobody has done that here in years. The winter is yours, if you want it."
		"fair":
			verdict = "We are down in places, but standing. Next time sleep more and accept less. You may stay on into the winter, if you can bear it."
		_:
			verdict = "I have read the reviews and the bank statement. I will take it from here. Your bus is at ten."

	var coda := ""
	if visited == 0:
		coda = "I counted them myself. %d in the book, %d at breakfast. I counted twice, because it is never right." % [hosted, hosted]
	elif tally.has("stalker"):
		coda = "I counted them myself. %d in the book, %d at breakfast. One of them was standing by the fence, facing the office. He was your uncle's too." % [hosted, hosted + 1]
	else:
		coda = "I counted them myself. %d in the book, %d at breakfast. It was like that when your uncle ran it." % [hosted, hosted + 1]

	var rows: Array = [
		["Takings", "%s$%d   (started with $%d, $%d in the till)" % ["+" if delta >= 0 else "-", absi(delta), start_money, money]],
		["Guests hosted", "%d   reviews %s   turned away %d   stormed off %d" % [hosted, ("%.1f stars" % avg) if rated > 0 else "none", gave_up, stormed]],
		["Nights", "%d   something came on %d   quiet %d" % [nights, mini(visited, nights), maxi(0, nights - visited)]],
		["What came", ", ".join(came) if not came.is_empty() else "nothing you could see"],
		["You were hurt", "%d times" % _hits if _hits != 1 else "once"],
		["Left for morning", "%d night jobs" % _jobs_left if _jobs_left != 1 else "1 night job"],
	]
	return {"grade": grade, "rows": rows, "verdict": verdict, "coda": coda}


func export_state() -> Dictionary:
	return {"start_money": start_money, "closed": closed, "nights": _nights.duplicate(true),
		"hits": _hits, "damage": _damage, "jobs_left": _jobs_left, "paged": _paged}


func import_state(data: Dictionary) -> void:
	start_money = int(data.get("start_money", start_money))
	closed = bool(data.get("closed", false))
	var n = data.get("nights", {})
	_nights = (n as Dictionary).duplicate(true) if n is Dictionary else {}
	_hits = int(data.get("hits", 0))
	_damage = int(data.get("damage", 0))
	_jobs_left = int(data.get("jobs_left", 0))
	_paged = bool(data.get("paged", false))
