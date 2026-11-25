extends Node

## A camp's goals and score kept up (core/systems/goal_rules.gd; Richard 25. 11. „Vybereš si je
## při založení“): every few seconds the camp's numbers (the most guests at once, the till, the
## nights in a row without a lost guest, the lodgings, the places, the last reviews' stars), each
## morning the night that went (a guest lost to it starts the count again); a chosen goal met is
## marked in the books and celebrated: the big banner and the fanfare, on every machine (co-op
## fact "goal"). The host (or a camp alone) counts; the other machines see the books in the pulse.

const INSTANCE = preload("res://scripts/instance/instance.gd")
const RULES = preload("res://core/systems/goal_rules.gd")
const FANFARE := "res://assets/sfx/builder/diploma.mp3"
const LOOK_SEC := 2.0
## After the game starts (the day's banner up first), this long before the first look: a goal
## met at once is celebrated where it can be seen.
const FIRST_LOOK_SEC := 5.0
## The reviews the stars are the mean of.
const STARS_OF := 10

var main: Node
var _t := 0.0
var _day := -1
var _lost_seen := -1
var _snd: AudioStreamPlayer
var _was_on := false
## How many goals were celebrated here (the tests read it).
var celebrated := 0


func _ready() -> void:
	_snd = AudioStreamPlayer.new()
	_snd.volume_db = -4.0
	add_child(_snd)
	if ResourceLoader.exists(FANFARE):
		_snd.stream = load(FANFARE)


func _process(delta: float) -> void:
	var on: bool = main != null and main.get("_gameplay_started") == true and main.get("_menu_mode") != true
	if on and not _was_on:
		_t = FIRST_LOOK_SEC
		_day = -1
		_lost_seen = -1
	_was_on = on
	_t -= delta
	if _t > 0.0:
		return
	_t = LOOK_SEC
	var core = INSTANCE.core(self)
	if core == null or core.get_state() == null or INSTANCE.coop(self).is_client():
		return
	if main == null or main.get("_gameplay_started") != true or main.get("_menu_mode") == true:
		return
	var st = core.get_state()
	var day := int(core.get_day())
	var lost: int = (st.lost_guests as Array).size()
	if _day >= 0 and day > _day and _lost_seen >= 0:
		# A morning: the night that went, with a guest lost to it or not.
		core.actions.goals_night(lost > _lost_seen)
	if _day != day or _lost_seen < 0:
		_day = day
		_lost_seen = lost
	var nums := numbers()
	core.actions.goals_note(int(nums["peak"]))
	var done: Dictionary = (st.goals as Dictionary).get("done", {})
	for id in (st.goals as Dictionary).get("chosen", []):
		if not done.has(str(id)) and RULES.met(str(id), nums):
			core.actions.goal_done(str(id), day)
			celebrate(str(id))
			if INSTANCE.coop(self).is_host():
				INSTANCE.coop(self).send_fact("goal", [str(id)])


## The camp's numbers now (goal_rules reads them; CampStat shows them).
func numbers() -> Dictionary:
	var st = INSTANCE.core(self).get_state()
	var g: Dictionary = st.goals if st.goals is Dictionary else {}
	var now := 0
	for guest in st.guests:
		if guest is Dictionary and str(guest.get("status", "")) in ["active", "sleep"]:
			now += maxi(1, int(guest.get("party_size", 1)))
	var seen := {}
	var lodgings := 0
	for c in st.grid.cells:
		var cell: Dictionary = st.grid.cells[c]
		var t := str(cell.get("type", ""))
		var id := str(cell.get("id", ""))
		if seen.has(id):
			continue
		seen[id] = true
		if t.begins_with("tent_") or t.begins_with("cabin") or t.begins_with("caravan_"):
			lodgings += 1
	var reviews: Array = st.guest_reviews
	var stars := 0.0
	var n := mini(STARS_OF, reviews.size())
	for i in n:
		stars += float((reviews[reviews.size() - 1 - i] as Dictionary).get("rating", 0))
	return {"peak": maxi(int(g.get("peak", 0)), now), "money": int(st.money), "safe": int(g.get("safe", 0)), "safe_best": int(g.get("safe_best", 0)),
		"lodgings": lodgings, "places": ((st.biz as Dictionary).get("sites", {}) as Dictionary).size() if st.biz is Dictionary else 0,
		"stars": stars / float(n) if n > 0 else 0.0, "days": int(st.day)}


## A goal met: the banner across the screen and the fanfare.
func celebrate(id: String) -> void:
	celebrated += 1
	var g := RULES.goal(id)
	var hud = main.get("_hud_manager") if main != null else null
	if hud != null and hud.has_method("show_banner") and not g.is_empty():
		hud.show_banner(tr("GOAL MET"), tr(str(g[1])), Color8(120, 230, 110), 4.0)
	if _snd != null and _snd.stream != null:
		_snd.play()
