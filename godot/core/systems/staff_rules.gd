extends RefCounted

## The camp's own staff (the user 21. 10., DESIGN.md §7c): the hands of the staffroom.
## Taken on one by one like the businesses' hands (the same people asking, their ID
## photos, speed, honesty, temper and wage: business_rules.applicants for the kind
## "staff"), but only with a staffroom standing, and one to a locker (one locker in the
## boiler room to start with; more are bought in its books). By day they sit in the
## staffroom and go out to the things that would otherwise call you away: a bin bag
## dumped by a path, raccoons in the bins, the wholesaler's van at the gate, a branch
## across a path, and the lodgings to clean and make up for the next guests. What each
## of them does is ticked in the staffroom's books or in SoftSklad's Personal 98. Between
## jobs they lie down on a mattress in the boiler room; one without a mattress of their
## own takes a guest's bed. At eight in the evening they go home.
##
## Pure data and arithmetic. The state is GameState.biz["staff"] (actions.gd staff_*),
## the running side scripts/staff/staff_runtime.gd, the room scripts/staff/staffroom.gd,
## the books scripts/staff/staff_ledger.gd, the PC program os98/apps/staff_app.gd.
##
##   biz.staff = {
##     "crew": [person + {"since", "jobs": {job: bool}, "owed", "absent"}],
##     "gear": {"locker": n, "mattress": n},
##     "act": {slug: {do, a, b, t0, t1, what, ev, room, spot}},   (where each one is)
##     "log": [{"day", "t", "text"}],                               (the day's work)
##     "done": {"day": n, "jobs": n},
##   }

const BRT := preload("res://core/systems/business_rules.gd")

## The jobs a hand can be set to (ticked on by default), in the books' order.
const JOBS := [
	["litter", "Rubbish"],
	["raccoons", "Raccoons"],
	["delivery", "Deliveries"],
	["tree", "Branches"],
	["rooms", "Lodgings"],
]

## Bought in the staffroom's books (the cards with a picture): how many fit the boiler
## room, the first one's price, each next one dearer.
const GEAR := {
	"locker": {"label": "Locker", "start": 1, "max": 5, "price": 80, "step": 30,
		"what": "A steel locker in the boiler room. One locker, one hand: no locker, nobody new."},
	"mattress": {"label": "Mattress", "start": 1, "max": 3, "price": 35, "step": 15,
		"what": "A mattress on the boiler room floor. A hand without one lies down in a guest's bed."},
}

## Their day: in from the gate from 7:00 (each a little later than the last), home at
## 20:00. (Game hours.)
const START_HOUR := 7.0
const HOME_HOUR := 20.0
## A walk, in metres a game minute (a little quicker than the guests' stroll).
const WALK_M_PER_MIN := 1.6 / 0.8
## Between two jobs, at least this long lying down (game minutes).
const REST_MIN := 18.0
## In the morning, the coffee on the sofa before the first job.
const COFFEE_MIN := 25.0
## One piece of work at the steady speed (game minutes); the quick do it in less.
const WORK_MIN := {"litter": 14.0, "raccoons": 10.0, "delivery": 16.0, "tree": 30.0, "rooms": 9.0}
const SPEED_K := [1.45, 1.0, 0.72]
## A dishonest hand on a delivery: a little of it does not reach the shelves.
const PILFER := 0.08


static func job_label(job: String) -> String:
	for j in JOBS:
		if str(j[0]) == job:
			return str(j[1])
	return job.capitalize()


static func default_jobs() -> Dictionary:
	var out := {}
	for j in JOBS:
		out[str(j[0])] = true
	return out


static func gear_count(staff: Dictionary, id: String) -> int:
	var g: Dictionary = staff.get("gear", {})
	return int(g.get(id, int((GEAR.get(id, {}) as Dictionary).get("start", 0))))


## What the next one of `id` costs (0: the room is full of them).
static func gear_price(staff: Dictionary, id: String) -> int:
	var d: Dictionary = GEAR.get(id, {})
	if d.is_empty():
		return 0
	var n := gear_count(staff, id)
	if n >= int(d["max"]):
		return 0
	return int(d["price"]) + (n - int(d["start"])) * int(d["step"])


## A locker free for somebody new.
static func can_hire(staff: Dictionary) -> bool:
	return (staff.get("crew", []) as Array).size() < gear_count(staff, "locker")


## How long a piece of work takes this hand (game minutes).
static func work_minutes(job: String, speed: int) -> float:
	return float(WORK_MIN.get(job, 12.0)) * float(SPEED_K[clampi(speed, 0, 2)])


## The day's wage (business_rules.wage for the staffroom's kind).
static func wage_of(p: Dictionary) -> int:
	return int(p.get("wage", 25))


## When this hand comes in in the morning (game hours): one after another, a quarter of
## an hour apart, in the order they were taken on.
static func start_hour(index: int) -> float:
	return START_HOUR + 0.25 * float(index)


## Whether a hand is on at `hour` (the night one stays: business_rules "night").
static func on_duty(p: Dictionary, hour: float, index: int) -> bool:
	if str(p.get("strange", "")) == "night":
		return hour >= start_hour(index)
	return hour >= start_hour(index) and hour < HOME_HOUR


## The applicants at the staffroom today: business_rules' people who ask for this kind,
## those already working anywhere in the camp left out.
static func applicants(day: int, taken: Array, seed := 0) -> Array:
	return BRT.applicants("staff", "staffroom", day, taken, seed)
