extends RefCounted

## The radio's four tiers (the user 5. 11.: "songs that may come on any time, songs only at
## night, songs only when the night presses, and songs only when it is the very worst
## nightmare terror"). By the file's prefix in res://assets/sfx/radio/:
##   (none)   any time, day or night
##   night*   only at night (building_interior's night playlist, as before)
##   teror_   only at night with the radio's dread past TEROR
##   peklo_   only past PEKLO: the worst the night gets
## The day's and the night's songs stay building_interior's shuffled playlist. The two dread
## tiers are drawn here instead of its next song, the worse the night the more often; each
## goes round its own bag (none twice before the others have played), never the same twice
## running. And the worst does not wait for the song to end: radio_dread cuts it (Ev.BREAK,
## dead air) and the set comes back on one of them, already going.
## Granny's lullaby (night_hajejdadej) comes on more often on a night she is out.

const TEROR := 0.5
const PEKLO := 0.8
const LULLABY := "night_hajejdadej"
const LULLABY_CHANCE := 0.22

var _bags := {2: [], 3: []}
var _all := {2: [], 3: []}
var _last := ""
var _lullaby := ""


static func tier_of(path: String) -> int:
	var f := path.get_file().to_lower()
	if f.begins_with("peklo_"):
		return 3
	if f.begins_with("teror_"):
		return 2
	if f.begins_with("night"):
		return 1
	return 0


## What the radio may play now: 0 the day's, 1 the night's, 2 pressing, 3 the worst.
static func tier_now(night: bool, dread: float) -> int:
	if not night:
		return 0
	if dread >= PEKLO:
		return 3
	if dread >= TEROR:
		return 2
	return 1


func setup(paths: Array) -> void:
	for t in [2, 3]:
		(_all[t] as Array).clear()
		(_bags[t] as Array).clear()
	for p in paths:
		var t := tier_of(str(p))
		if t >= 2:
			(_all[t] as Array).append(str(p))
		elif str(p).get_file().get_basename() == LULLABY:
			_lullaby = str(p)


## Instead of the playlist's next song: one of the dread tiers' (or the lullaby on her
## night), or "" for the playlist's. ctx: radio_dread's (night, tonight).
func pick(ctx: Dictionary, dread: float, rng: RandomNumberGenerator) -> String:
	var night := bool(ctx.get("night", false))
	var t := tier_now(night, dread)
	var r := rng.randf()
	if t == 3:
		if r < 0.55:
			return _draw(3, rng)
		if r < 0.82:
			return _draw(2, rng)
	elif t == 2 and r < 0.42:
		return _draw(2, rng)
	if night and _lullaby != "" and _last != _lullaby and "basket" in (ctx.get("tonight", []) as Array) and rng.randf() < LULLABY_CHANCE:
		_last = _lullaby
		return _lullaby
	return ""


## The song cut for the worst: what comes on instead.
func pick_break(dread: float, rng: RandomNumberGenerator) -> String:
	var p := _draw(3, rng) if dread >= PEKLO else ""
	return p if p != "" else _draw(2, rng)


## The playlist played one: it counts for "never twice running".
func played(path: String) -> void:
	_last = path


func _draw(t: int, rng: RandomNumberGenerator) -> String:
	var bag: Array = _bags[t]
	if bag.is_empty():
		bag.append_array(_all[t])
		if bag.is_empty():
			return ""
	var i := rng.randi_range(0, bag.size() - 1)
	if bag.size() > 1 and str(bag[i]) == _last:
		i = (i + 1) % bag.size()
	var p := str(bag[i])
	bag.remove_at(i)
	_last = p
	return p
