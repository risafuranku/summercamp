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
## jobs they sit in the lounge, on the sofa or in an armchair (bought in the books); one
## with nowhere to sit takes a guest's bed. At eight in the evening they all go home (the
## user 21. 10.: "the hands go home for the night; the mattress is for the player": the
## boiler room's mattress is the warden's to sleep on, scripts/lodge_bed.gd).
##
## Pure data and arithmetic. The state is GameState.biz["staff"] (actions.gd staff_*),
## the running side scripts/staff/staff_runtime.gd, the room scripts/staff/staffroom.gd,
## the books scripts/staff/staff_ledger.gd, the PC program os98/apps/staff_app.gd.
##
##   biz.staff = {
##     "crew": [person + {"since", "jobs": {job: bool}, "owed", "absent"}],
##     "gear": {"locker": n, "armchair": n},
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
	# (The user 4. 11.: "the cleaners did not clean the showers and the toilets properly":
	# they never did, it was no job of theirs.)
	["blocks", "Toilets and showers"],
	# A lamp gone or worn out, a toilet, a shower or the pump out of order (Richard 8. 11.:
	# "when I have plenty of staff the whole camp should run by itself and I only help out
	# when needed"): what you hold R for, at what it costs you. Not the sewer (a crawl, yours
	# or the crew's), not the breaker.
	["repairs", "Repairs"],
	# The lost boy, the noise: yours first; a hand goes when you have not got to it by the
	# half of its time (LATE_KINDS).
	["guests", "Guests"],
	# At the reception all day, checking in whoever waits there with their room made up
	# (the user 4. 11.: "the staffroom's: they clean, or take the guests in at the
	# reception"). Off unless ticked: one at the desk is one fewer at the brooms. Whoever
	# sits there pays the electricity too.
	["desk", "Reception"],
	# The one at the desk answers the booking letters. Taken off, the letters wait for you:
	# who comes is what comes for them at night.
	["letters", "Bookings"],
]
## The jobs off for somebody new.
const OFF_BY_DEFAULT := ["desk"]
## The day's events a hand leaves to you till the half of their time is up.
const LATE_KINDS := ["lost_kid", "noise"]
## The failures a hand can put right (what wants a crawl or the board does not count).
const MENDS := ["lamp_post", "path", "toilet_block", "shower_block", "water_pump"]

## Bought in the staffroom's books (the cards with a picture): how many fit the boiler
## room, the first one's price, each next one dearer.
const GEAR := {
	"locker": {"label": "Locker", "start": 1, "max": 5, "price": 80, "step": 30,
		"what": "A steel locker in the boiler room. One locker, one hand: no locker, nobody new."},
	"armchair": {"label": "Armchair", "start": 0, "max": 3, "price": 30, "step": 15,
		"what": "An old armchair in the lounge for a break between jobs. A hand with nowhere to sit lies down in a guest's bed."},
}

## Their day: in from the gate from 7:00 (each a little later than the last), home at
## 20:00. (Game hours.)
const START_HOUR := 7.0
const HOME_HOUR := 20.0
## A walk, in metres a game minute (a little quicker than the guests' stroll).
const WALK_M_PER_MIN := 1.6 / 0.8
## Between two jobs, at least this long sitting down (game minutes).
const REST_MIN := 18.0
## In the morning, the coffee on the sofa before the first job.
const COFFEE_MIN := 25.0
## One piece of work at the steady speed (game minutes); the quick do it in less.
const WORK_MIN := {"litter": 14.0, "raccoons": 10.0, "delivery": 16.0, "tree": 30.0, "rooms": 9.0, "blocks": 16.0, "repairs": 18.0, "lost_kid": 20.0, "noise": 8.0}
## At the desk: a guest who has waited this long (game minutes) is checked in, one every
## DESK_EACH_MIN at the steady speed.
const DESK_WAIT_MIN := 4.0
const DESK_EACH_MIN := 5.0
## A letter answered every so often; one that has found no bed for this long is declined.
const LETTER_EACH_MIN := 25.0
const LETTER_NO_BED_MIN := 240.0
## How often the one at the desk looks at the bills.
const BILLS_EACH_MIN := 45.0
## A lodging a party is on its way to, this far off (game minutes): before all the others.
const WANTED_WITHIN_MIN := 240
const SPEED_K := [1.45, 1.0, 0.72]
## A dishonest hand on a delivery: a little of it does not reach the shelves.
const PILFER := 0.08


static func job_label(job: String) -> String:
	if LATE_KINDS.has(job):
		return "Guests"
	for j in JOBS:
		if str(j[0]) == job:
			return str(j[1])
	return job.capitalize()


static func default_jobs() -> Dictionary:
	var out := {}
	for j in JOBS:
		out[str(j[0])] = not OFF_BY_DEFAULT.has(str(j[0]))
	return out


## Whether `job` is ticked for this hand (an older save's hand has the new ones as new).
static func does(p: Dictionary, job: String) -> bool:
	var jobs: Dictionary = p.get("jobs", {}) if p.get("jobs") is Dictionary else {}
	return bool(jobs.get(job, not OFF_BY_DEFAULT.has(job)))


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


## Somebody on shift now who is set to `job` and free to go to it (the desk keeps its
## own): that piece of the camp will be seen to without you.
static func covered(staff: Dictionary, job: String, hour: float, day: int) -> bool:
	if hour >= HOME_HOUR - 0.5:
		return false
	var crew: Array = staff.get("crew", []) if staff.get("crew", []) is Array else []
	for i in crew.size():
		var p: Dictionary = crew[i]
		if not does(p, job) or int(p.get("since", 0)) > day or int(p.get("absent", -1)) == day:
			continue
		if job != "desk" and does(p, "desk"):
			continue
		# (From the morning on: an hour before they come in it is theirs already.)
		if hour >= START_HOUR - 1.0:
			return true
	return false


## Somebody has the reception and answers the letters: a new booking is no business of
## your pager.
static func letters_covered(staff: Dictionary, day: int) -> bool:
	for p in staff.get("crew", []):
		if does(p, "desk") and does(p, "letters") and int((p as Dictionary).get("since", 0)) <= day:
			return true
	return false


## The day's wage (business_rules.wage for the staffroom's kind).
static func wage_of(p: Dictionary) -> int:
	return int(p.get("wage", 25))


## When this hand comes in in the morning (game hours): one after another, a quarter of
## an hour apart, in the order they were taken on.
static func start_hour(index: int) -> float:
	return START_HOUR + 0.25 * float(index)


## Whether a hand is on at `hour` (everybody goes home for the night; somebody taken on
## today comes in tomorrow: "since" the day they start, the user 4. 11.).
static func on_duty(p: Dictionary, hour: float, index: int, day := -1) -> bool:
	if day >= 0 and int(p.get("since", 0)) > day:
		return false
	return hour >= start_hour(index) and hour < HOME_HOUR


## What the hands have taken on just now, for the plates on the right: {"ev:<id>": slug,
## "room:<key>": slug (a lodging, "block:x:y", "desk")}. On their way to it counts.
static func taken(staff: Dictionary) -> Dictionary:
	var out := {}
	var acts: Dictionary = staff.get("act", {}) if staff.get("act", {}) is Dictionary else {}
	for slug in acts:
		var a: Dictionary = acts[slug]
		var next: Dictionary = a.get("next", {}) if a.get("next", {}) is Dictionary else {}
		var doing := str(a.get("do", "")) == "work" or (str(a.get("do", "")) == "walk" and str(next.get("do", "")) == "work")
		if not doing:
			continue
		if int(a.get("ev", -1)) >= 0:
			out["ev:%d" % int(a["ev"])] = str(slug)
		if str(a.get("room", "")) != "":
			out["room:" + str(a["room"])] = str(slug)
	return out


## Jobs one after another before going back for a sit-down (Richard's camp left alone, 8.
## 11.: the walk back to the sofa between every two jobs left a dirty cabin standing till
## the evening and its guests went home).
const JOBS_IN_A_ROW := 3
## Past eight with somebody still at the desk: the one there stays, and the one making up
## the lodging they are waiting for. This long at most (hours).
const OVERTIME_H := 1.25


## The hands' day on the clock's line (the user 7. 11.: "what I miss in the HUD is a time line:
## when the staff come to work and when their shift ends"): [[from hour, to hour, late?], ...],
## the camp's own and each business's, those who are off today left out. `biz`: state.biz.
static func day_bands(biz: Dictionary, day: int, late_close: float) -> Array:
	var out: Array = []
	var staff: Dictionary = biz.get("staff", {}) if biz.get("staff", {}) is Dictionary else {}
	var crew: Array = staff.get("crew", []) if staff.get("crew", []) is Array else []
	for i in crew.size():
		var p: Dictionary = crew[i]
		if int(p.get("since", 0)) <= day and int(p.get("absent", -1)) != day:
			out.append([start_hour(i), HOME_HOUR, false])
	var sites: Dictionary = biz.get("sites", {}) if biz.get("sites", {}) is Dictionary else {}
	for key in sites:
		for p in (sites[key] as Dictionary).get("crew", []):
			if int((p as Dictionary).get("since", 0)) > day or int((p as Dictionary).get("absent", -1)) == day:
				continue
			if str((p as Dictionary).get("shift", "day")) == "late":
				out.append([HOME_HOUR, late_close, true])
			else:
				out.append([START_HOUR, HOME_HOUR, false])
	return out


## The applicants at the staffroom today: business_rules' people who ask for this kind,
## those already working anywhere in the camp left out.
static func applicants(day: int, taken: Array, seed := 0) -> Array:
	return BRT.applicants("staff", "staffroom", day, taken, seed)
