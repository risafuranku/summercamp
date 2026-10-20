extends RefCounted

## Builder 98's Graphs (DESIGN §5j): what each day of the camp ended with, for the lines
## Transport Tycoon drew. Main records the day that ended at every dawn: the cash, how
## many people stayed, their mood, the Goggle rating, and each kind of business's takings
## (from its books' "yesterday"). Saved by main ("graph"), checked by
## tools/builder98_check.gd.

## How many days the graphs go back.
const DAYS := 14

## day -> {money, guests, mood, rating, takings: {business kind: $}}
var days: Dictionary = {}


func reset() -> void:
	days.clear()


## The day that ended: its numbers (later calls for the same day replace them).
func record(day: int, money: int, guests: int, mood: float, rating: float, takings: Dictionary = {}) -> void:
	if day < 1:
		return
	# One decimal through text: the same number again after the save's JSON.
	days[day] = {"money": money, "guests": guests, "mood": float("%.1f" % mood), "rating": float("%.1f" % rating), "takings": takings.duplicate()}
	for d in days.keys():
		if int(d) < day - DAYS - 2:
			days.erase(d)


## One line: [[day, value or null], ...] for the last DAYS days up to `today` (today's
## own value from `live` when given, not stored yet). "takings:pub" is one business kind's.
func series(key: String, today: int, live: Variant = null) -> Array:
	var out: Array = []
	for d in range(maxi(1, today - DAYS + 1), today + 1):
		var v: Variant = null
		if days.has(d):
			if key.begins_with("takings:"):
				v = ((days[d] as Dictionary).get("takings", {}) as Dictionary).get(key.get_slice(":", 1), null)
			else:
				v = (days[d] as Dictionary).get(key, null)
		if d == today and live != null:
			v = live
		out.append([d, v])
	return out


func export_state() -> Dictionary:
	var out := {}
	for d in days:
		out[str(d)] = (days[d] as Dictionary).duplicate()
	return {"days": out}


func import_state(data: Dictionary) -> void:
	days.clear()
	var src: Dictionary = data.get("days", {}) if data.get("days", {}) is Dictionary else {}
	for k in src:
		var e: Dictionary = src[k] if src[k] is Dictionary else {}
		var tk := {}
		var tsrc: Dictionary = e.get("takings", {}) if e.get("takings", {}) is Dictionary else {}
		for kind in tsrc:
			tk[str(kind)] = int(tsrc[kind])
		days[int(k)] = {"money": int(e.get("money", 0)), "guests": int(e.get("guests", 0)),
			"mood": float(e.get("mood", 0.0)), "rating": float(e.get("rating", 0.0)), "takings": tk}
