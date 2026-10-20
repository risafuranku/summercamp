class_name PubRules
extends RefCounted

## The pub as a game (DESIGN.md §7b, "the pub"), the bistro's way (bistro_rules.gd): what
## the guests drink, round after round, how a pour is judged, the keg in the cellar.
## Pure data and arithmetic: the pub's state is scripts/pub/taproom.gd, the stations
## scripts/pub/*_station.gd.
##
## The chain, cellar to table:
##   cellar   a keg on the line (KEG_PINTS pints, out of the books' beer), the gas set
##            on the gauge: too low and the beer comes flat and slow, too high and it is
##            all foam; an empty keg is changed for a full one by hand
##   tap      a clean mug under it, pulled (beer) and pushed (foam): the three Czech
##            pours, judged against the line on the glass
##   back bar the spirits and the kofola, poured to the line of their glass
##   washer   the mugs come back dirty when they are drunk: scrubbed on the brushes,
##            racked; no clean mugs, no beer
## Nobody carries anything: what you pour goes to whoever ordered it, and a mark of the
## pencil goes on their beer mat (the rail of every station is the mats).
##
## The tab, the Czech way (the brief of 20. 10.): nothing is paid as it is poured. Every
## drink is a mark on the guest's mat, a stroke for a beer, a cross for a shot, a ring for
## a kofola (TAB, the price board's prices); when they have had their last, or their time
## is nearly up, they ask for the bill: the landlord counts the marks, they put down a note
## (often too big, pay_note) and maybe say "make it" a round sum (the tip), and the change
## is counted out of the waiter's wallet onto the mat. Nobody comes and they leave the
## money on the bar, or, if they are cross, nothing at all.

## What can be ordered: kind tap (a mug, poured at the tap) or bar (the back bar: a shot
## glass, or the tall glass for the kofola). beer: the share of the mug that should be
## beer (the rest foam to the rim); good: what it takes off the shelf.
const DRINKS := {
	"hladinka": {"label": "Hladinka", "kind": "tap", "beer": 0.78, "price": 4, "good": "beer", "tab": "beer"},
	"snyt": {"label": "Snyt", "kind": "tap", "beer": 0.46, "price": 4, "good": "beer", "tab": "beer"},
	"mliko": {"label": "Mliko", "kind": "tap", "beer": 0.12, "price": 4, "good": "beer", "tab": "beer"},
	"rum": {"label": "Rum", "kind": "bar", "tall": false, "price": 3, "good": "rum", "tab": "shot"},
	"zelena": {"label": "Zelena", "kind": "bar", "tall": false, "price": 3, "good": "rum", "tab": "shot"},
	"slivovice": {"label": "Slivovice", "kind": "bar", "tall": false, "price": 3, "good": "rum", "tab": "shot"},
	"kofola": {"label": "Kofola", "kind": "bar", "tall": true, "price": 2, "good": "kofola", "tab": "kofola"},
}
## The marks on a mat and what each costs (the price board over the bar).
const TAB := {"beer": {"mark": "|", "price": 4}, "shot": {"mark": "x", "price": 3}, "kofola": {"mark": "o", "price": 2}}
## Game minutes: the bill is asked for this long before their time is up (or when they
## have finished their last), and they wait this long for it.
const BILL_LEAD := 10
const BILL_WAIT := 15
## What they put down: the smallest of these it fits under (fifties for more).
const PAY_NOTES := [10, 20, 50]
## The waiter's wallet: what change is counted out in.
const CHANGE := [1, 2, 5, 10]
## What each kind of guest drinks (weights).
const TASTE := {
	"drunk": {"hladinka": 8, "snyt": 1, "rum": 3, "zelena": 2},
	"tramp": {"hladinka": 5, "snyt": 3, "zelena": 2, "slivovice": 1, "rum": 1},
	"quiet_guy": {"hladinka": 6, "snyt": 1, "slivovice": 2, "kofola": 1},
	"cheap_chick": {"mliko": 4, "snyt": 3, "kofola": 3, "zelena": 1},
	"picker": {"snyt": 4, "mliko": 1, "kofola": 2, "slivovice": 1},
	"family": {"hladinka": 3, "snyt": 1, "kofola": 5},
}
## Rounds a person has in one visit (orders.gd APPETITE "pub": the same numbers).
const ROUNDS := {"drunk": 4, "tramp": 3, "quiet_guy": 2, "cheap_chick": 2, "picker": 1, "family": 1}

## Game minutes (1.5 a second): the first order goes up this long after they sit down,
## the next one this long after the last one came (they drink it first). Green while an
## order is younger than PATIENCE_OK, amber to PATIENCE_LATE, red to PATIENCE_GONE, when
## they give up on it and order nothing more.
const ORDER_DELAY := 4
const DRINK_MINUTES := 30
const PATIENCE_OK := 30
const PATIENCE_LATE := 60
const PATIENCE_GONE := 90

## The mug, in shares of its height: the line (the half litre) and the rate the beer and
## the foam come at, pulled and pushed, and how fast the head settles back to beer.
const LINE := 0.8
const POUR_RATE := 0.24
const PULL_FOAM := 0.045
const PUSH_FOAM := 0.36
const PUSH_BEER := 0.012
const SETTLE := 0.03
## The shot glass and the tall glass: their line and how fast a tipped bottle fills them.
const LINE_SHOT := 0.8
const LINE_TALL := 0.85
const RATE_SHOT := 0.55
const RATE_TALL := 0.32
## Mugs in a new pub, and the scrubs a dirty one needs on the brushes.
const MUGS := 16
const SCRUBS := 7

## The keg: pints in one (a pack of the books' beer), and the gas. The gauge reads 0..1;
## the beer pours right between GAS_LOW and GAS_HIGH, and the gas creeps down while the
## tap runs (a bar of it every GAS_LEAK pints).
const KEG_PINTS := 50
const GAS_LOW := 0.42
const GAS_HIGH := 0.62
const GAS_START := 0.52
const GAS_LEAK := 18.0


static func label(drink: String) -> String:
	return str((DRINKS.get(drink, {}) as Dictionary).get("label", drink))


static func kind(drink: String) -> String:
	return str((DRINKS.get(drink, {}) as Dictionary).get("kind", "tap"))


## The drink person `member` of `visit` has in round `round`: decided by the visit and the
## seat alone, so every machine in co-op orders the same without being told.
static func drink_for(visit: String, archetype: String, member: int, round: int) -> String:
	var h := absi(hash("%s#%d/%d" % [visit, member, round]))
	var w: Dictionary = TASTE.get(archetype, {"hladinka": 1})
	var total := 0
	for k in w:
		total += int(w[k])
	var r := h % maxi(1, total)
	for k in w:
		r -= int(w[k])
		if r < 0:
			return str(k)
	return "hladinka"


static func rounds(archetype: String) -> int:
	return int(ROUNDS.get(archetype, 1))


## The orders one visit has open now: one at a time per person, the next after they have
## drunk the last; gone when they have waited PATIENCE_GONE for one (they stop ordering).
##   served: ticket id -> {at (game minute), ...} of what was poured for this camp
##   returns [{id, member, round, drink, price, since, age}]
static func tickets_for(visit: String, archetype: String, figures: int, arrive: int, served: Dictionary, now: int) -> Array:
	var out: Array = []
	# Their time is nearly up: they ask for the bill instead (bill_for).
	if now >= arrive + stay(archetype) - BILL_LEAD:
		return out
	for m in maxi(1, figures):
		var since := arrive + ORDER_DELAY + m
		for r in rounds(archetype):
			var tid := "%s#%d/%d" % [visit, m, r]
			if served.has(tid):
				since = int((served[tid] as Dictionary).get("at", now)) + DRINK_MINUTES
				continue
			if now < since or now - since >= PATIENCE_GONE:
				break
			var d := drink_for(visit, archetype, m, r)
			out.append({"id": tid, "member": m, "round": r, "drink": d, "price": int(DRINKS[d]["price"]), "since": since, "age": now - since})
			break
	return out


## A mug against what was asked for: {ok, accuracy 0..1, tip, stars 1..3, mood}. beer and
## foam are shares of the mug, spilled what went over the rim, age the order's minutes.
static func judge_pour(drink: String, beer: float, foam: float, spilled: float, age: int) -> Dictionary:
	var want := float((DRINKS.get(drink, {}) as Dictionary).get("beer", 0.78))
	var top := beer + foam
	var e_beer := absf(beer - want) / 0.13
	var e_top := maxf(0.0, 0.96 - top) / 0.1
	var e_spill := spilled / 0.12
	var accuracy := clampf(1.0 - 0.5 * e_beer - 0.5 * e_top - 0.25 * e_spill, 0.0, 1.0)
	return _verdict(accuracy, age, accuracy >= 0.3)


## A shot or a kofola against its line: {ok, accuracy, ...}; a short one is sent back.
static func judge_glass(drink: String, fill: float, spilled: float, age: int) -> Dictionary:
	var line := LINE_TALL if bool((DRINKS.get(drink, {}) as Dictionary).get("tall", false)) else LINE_SHOT
	var accuracy := clampf(1.0 - absf(fill - line) / 0.18 - spilled * 4.0, 0.0, 1.0)
	return _verdict(accuracy, age, fill >= line - 0.25)


static func _verdict(accuracy: float, age: int, ok: bool) -> Dictionary:
	if not ok:
		return {"ok": false, "accuracy": accuracy, "tip": 0, "stars": 0, "mood": -1.5}
	var speed := 1.0 if age < PATIENCE_OK * 0.6 else (0.6 if age < PATIENCE_OK else (0.3 if age < PATIENCE_LATE else 0.0))
	var tip := (2 if accuracy >= 0.85 else (1 if accuracy >= 0.6 else 0)) + (1 if speed >= 0.6 and accuracy >= 0.6 else 0)
	var stars := 1 + (1 if accuracy >= 0.85 else 0) + (1 if speed >= 0.6 else 0)
	return {"ok": true, "accuracy": accuracy, "speed": speed, "tip": tip, "stars": stars, "mood": -0.5 + accuracy * 2.0 + speed}


## The colour band of an order's wait: 0 green, 1 amber, 2 red.
static func patience_band(age: int) -> int:
	if age < PATIENCE_OK:
		return 0
	if age < PATIENCE_LATE:
		return 1
	return 2


## How the gas pours: {rate (x the beer's speed), foam (x the head a pull makes)}. Flat
## and slow under the green, all foam over it.
static func gas_pour(gas: float) -> Dictionary:
	if gas < GAS_LOW:
		var k := clampf(gas / GAS_LOW, 0.0, 1.0)
		return {"rate": 0.35 + 0.65 * k, "foam": 0.3 + 0.7 * k}
	if gas > GAS_HIGH:
		var k2 := clampf((gas - GAS_HIGH) / (1.0 - GAS_HIGH), 0.0, 1.0)
		return {"rate": 1.0 + 0.2 * k2, "foam": 1.0 + 7.0 * k2}
	return {"rate": 1.0, "foam": 1.0}


## A gauge reading in words: "LOW", "OK", "HIGH".
static func gas_band(gas: float) -> String:
	if gas < GAS_LOW:
		return "LOW"
	return "HIGH" if gas > GAS_HIGH else "OK"


# ── the tab ──────────────────────────────────────────────────────────────────

static func tab_class(drink: String) -> String:
	return str((DRINKS.get(drink, {}) as Dictionary).get("tab", "beer"))


## A visit's tab from what was poured for it: {counts: {beer, shot, kofola}, total (the
## marks at the board's prices), tips (what they would add for good service), last_at
## (the last drink's minute), n (drinks)}.
static func tab_of(visit: String, served: Dictionary) -> Dictionary:
	var counts := {"beer": 0, "shot": 0, "kofola": 0}
	var total := 0
	var tips := 0
	var last := -1
	var n := 0
	for tid in served:
		var id := str(tid)
		if not id.begins_with(visit + "#") or id.ends_with("#bill"):
			continue
		var rec: Dictionary = served[tid]
		var c := tab_class(str(rec.get("drink", "hladinka")))
		counts[c] = int(counts[c]) + 1
		total += int(TAB[c]["price"])
		tips += int(rec.get("tip", 0))
		last = maxi(last, int(rec.get("at", 0)))
		n += 1
	return {"counts": counts, "total": total, "tips": tips, "last_at": last, "n": n}


## Whether the visit has more rounds coming (an order open, or the next one not due yet
## because they are still drinking).
static func more_rounds(visit: String, archetype: String, figures: int, arrive: int, served: Dictionary, now: int) -> bool:
	for m in maxi(1, figures):
		var since := arrive + ORDER_DELAY + m
		for r in rounds(archetype):
			var tid := "%s#%d/%d" % [visit, m, r]
			if served.has(tid):
				since = int((served[tid] as Dictionary).get("at", now)) + DRINK_MINUTES
				continue
			if now - since < PATIENCE_GONE:
				return true
			break
	return false


## How long a visit stays in the pub (game minutes from coming in): their rounds and a
## little over; the pub keeps them past their time while their tab is open (taproom.gd,
## orders.set_holds).
static func stay(archetype: String) -> int:
	return ORDER_DELAY + rounds(archetype) * DRINK_MINUTES + BILL_LEAD


## Their bill when they want to pay ({} not yet, nothing on the tab, or paid): {id
## (visit#bill), kind "bill", visit, counts, total, make_it (the round sum they ask for
## with a tip: 0 none), note (what they put down: 0 the right money), since, age}. Asked
## for when they have finished their last drink, or BILL_LEAD before their time is up.
static func bill_for(visit: String, archetype: String, figures: int, arrive: int, served: Dictionary, now: int) -> Dictionary:
	if served.has(visit + "#bill"):
		return {}
	var tab := tab_of(visit, served)
	if int(tab["n"]) <= 0:
		return {}
	var due := arrive + stay(archetype) - BILL_LEAD
	if not more_rounds(visit, archetype, figures, arrive, served, now):
		due = mini(due, int(tab["last_at"]) + DRINK_MINUTES)
	if now < due:
		return {}
	var total := int(tab["total"])
	var make_it := 0
	if int(tab["tips"]) > 0:
		# "Make it twenty": up to the next five with their tip in it.
		make_it = int(ceil(float(total + int(tab["tips"])) / 5.0)) * 5
	var to_pay := make_it if make_it > 0 else total
	return {"id": visit + "#bill", "kind": "bill", "visit": visit, "counts": tab["counts"], "total": total,
		"make_it": make_it, "note": pay_note(to_pay, visit), "since": due, "age": now - due}


## What they put down for `amount`: the right money now and then (0), else the smallest
## note it fits under, or fifties.
static func pay_note(amount: int, visit: String) -> int:
	if absi(hash(visit + ":bill")) % 4 == 0:
		return 0
	for note in PAY_NOTES:
		if int(note) > amount:
			return int(note)
	return 50 * int(ceil(float(amount + 1) / 50.0))


## What the bill comes to with their tip in it (the round sum, or the marks).
static func to_pay(bill: Dictionary) -> int:
	return int(bill.get("make_it", 0)) if int(bill.get("make_it", 0)) > 0 else int(bill.get("total", 0))


## The change due on a bill (0 when they paid right).
static func change_due(bill: Dictionary) -> int:
	return maxi(0, int(bill.get("note", 0)) - to_pay(bill)) if int(bill.get("note", 0)) > 0 else 0


## The change counted out against what is due: {ok, accuracy, speed, over, short}. Short:
## they say so and wait; too much: they keep it.
static func judge_change(given: int, due: int, age: int) -> Dictionary:
	var speed := 1.0 if age < 5 else (0.7 if age < int(BILL_WAIT * 0.6) else 0.35)
	if given < due:
		return {"ok": false, "accuracy": 0.0, "speed": speed, "over": 0, "short": due - given}
	var over := given - due
	var acc := 1.0 if over == 0 else clampf(1.0 - 0.2 * float(over), 0.3, 0.9)
	return {"ok": true, "accuracy": acc, "speed": speed, "over": over, "short": 0}

