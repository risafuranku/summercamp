extends RefCounted

## Builder 98 is shareware (DESIGN §5j): Stavitel software's nag after about ten builds and
## now and then after, the registration bought with the camp's money (the key comes by
## mail the next morning, typed into Help > Register...), the Mega gnome for registered
## copies only; and the cheats typed on the map. Pure state, kept on the PC (os_shell's
## store "builder98": it goes with the PC's save and to the other wardens' PCs), checked
## by tools/builder98_check.gd.

const NAG_FIRST := 10
const NAG_EVERY := 12
## What registering costs (the camp's money; the old price on the box was 990 Kc).
const PRICE := 99
## Typed on the map with no text field in focus: the cheat's name.
const CHEATS := ["BOHEMIA", "KAREL", "MOLE", "VERA"]

var registered := false
var builds := 0
## The key ordered (it comes by mail), "" until then.
var key := ""
var ordered_day := -1
var mailed := false
var _seed := 0
var _typed := ""


func reset(seed_value: int = 0) -> void:
	registered = false
	builds = 0
	key = ""
	ordered_day = -1
	mailed = false
	_seed = seed_value
	_typed = ""


## A build: true when it is time for the nag (unregistered only).
func note_build() -> bool:
	if registered:
		return false
	builds += 1
	return builds == NAG_FIRST or (builds > NAG_FIRST and (builds - NAG_FIRST) % NAG_EVERY == 0)


## Registration paid for on `day`: the key that will come by mail.
func order(day: int) -> String:
	if key == "":
		var h := absi(hash("%d|stavitel|%d" % [_seed, day]))
		key = "B98-%04d-%04d" % [h % 10000, (h / 10000) % 10000]
	ordered_day = day
	mailed = false
	return key


## The key typed in: registered when it is the one that came (any case, spaces ignored).
func register(typed: String) -> bool:
	if key == "" or registered:
		return registered and key != ""
	if typed.strip_edges().to_upper().replace(" ", "") == key:
		registered = true
		return true
	return false


func unlocked(item: String) -> bool:
	return item != "mega_gnome" or registered


## A letter typed on the map: the cheat it completes, or "".
func type_key(ch: String) -> String:
	if ch.length() != 1:
		return ""
	_typed = (_typed + ch.to_upper()).right(12)
	for c in CHEATS:
		if _typed.ends_with(c):
			_typed = ""
			return c
	return ""


## The mail that comes the next morning: "key" (Stavitel's registration) or "bohemia"
## (the district asks where the money came from). For EmailManager.schedule_pool_mail.
static func mail_for(kind: String, extra: String, day: int) -> Dictionary:
	if kind == "key":
		return {"day": day + 1, "time": "08:10", "from": "Stavitel software", "sender": "Stavitel software",
			"subject": "Your Builder 98 registration", "type": "system",
			"body": "Thank you for registering Builder 98.\n\nYour key:  %s\n\nHelp > Register... in Builder 98, and type it in.\n\nStavitel software\nBrnenska 14, Jihlava" % extra}
	return {"day": day + 1, "time": "08:05", "from": "District Office Pelhrimov", "sender": "District Office Pelhrimov",
		"subject": "Irregularity in your accounts", "type": "system",
		"body": "To the operator of the recreational facility Cerne jezero.\n\nOur records show that on day %d the facility's accounts rose by $5,000 with no receipt behind it.\n\nBring the documents to room 214 by Thursday, 8:00 - 11:30.\nDo not reply to this message.\n\nDistrict Office Pelhrimov, finance department" % day}


func export_state() -> Dictionary:
	return {"registered": registered, "builds": builds, "key": key, "ordered_day": ordered_day, "mailed": mailed, "seed": _seed}


func import_state(d: Dictionary) -> void:
	registered = bool(d.get("registered", false))
	builds = int(d.get("builds", 0))
	key = str(d.get("key", ""))
	ordered_day = int(d.get("ordered_day", -1))
	mailed = bool(d.get("mailed", false))
	_seed = int(d.get("seed", 0))
