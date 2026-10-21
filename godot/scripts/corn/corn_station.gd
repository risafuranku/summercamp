extends "res://scripts/business/station3d.gd"

## A station of the corn stand, worked on its counter out in the camp
## (scripts/business/station3d.gd; DESIGN.md §7b "The corn stand"): the stand's state
## (cornstand.gd: the pot, the bowl, who was served), the orders on the rail as paper
## slips drawn the same as in every place (station3d.draw_ticket: the guest's face, a cob
## and the salt they want, NO SALT, or the cup or the bag of a drink; their patience), the
## picked one big in the frame as a checklist (cooked, butter, the salt, the napkin), the
## crate, the bowl and the butter under SERVE, the pot's timers when you are husking. The
## stations: counter, husk, drinks. Each says what is best to do next (`next_hint`), the
## stand being the frame's model for the other three places (the brief of 21. 10.).

const CORN := preload("res://core/systems/corn_rules.gd")
const CORNSTAND := preload("res://scripts/corn/cornstand.gd")
const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const CORN_TEX := "res://assets/textury/corn/"
const PAPER := "res://assets/textury/bistro/"
const MARKS := "res://assets/textury/ui/"

## The order picked on the rail (the counter hands the cob to them first).
static var picked := ""

var stand
var _icons: Dictionary = {}


func _build() -> void:
	stand = state if state != null else CORNSTAND.of(get_tree())
	for n in ["ticket", "ticket_old"]:
		_icons[n] = load(PAPER + n + ".png") if ResourceLoader.exists(PAPER + n + ".png") else null
	_icons["corn"] = load(MARKS + "mark_corn.png") if ResourceLoader.exists(MARKS + "mark_corn.png") else null
	var salt := "res://assets/textury/closeup/parts/salt.png"
	_icons["salt"] = load(salt) if ResourceLoader.exists(salt) else null


func sfx_dir() -> String:
	return "res://assets/sfx/corn/"


## A corn stand sound, else the bistro's of the same name.
func sfx(n: String, db := -8.0, pitch := 1.0) -> void:
	if n.begins_with("res://"):
		super.sfx(n, db, pitch)
		return
	for d in [sfx_dir(), "res://assets/sfx/bistro/", "res://assets/sfx/pub/"]:
		var p: String = d + n + ".mp3"
		if ResourceLoader.exists(p):
			super.sfx(p, db, pitch)
			return


## A corn picture on the counter, its longer side `metres` long (lying flat, or standing
## on its foot).
func csprite(name: String, metres: float, flat := true) -> Sprite3D:
	var s := sprite(CORN_TEX + name + ".png", metres, flat)
	if not flat and s.texture != null:
		s.offset = Vector2(0, float(s.texture.get_height()) * 0.5)
	return s


func cretex(s: Sprite3D, name: String, metres: float) -> void:
	retex(s, CORN_TEX + name + ".png", metres)


## A cob (or a leaf of its husk) lying on its side, turned to you: a standing sprite laid
## over, its middle at the point it is put; `tilt` fans it a little.
func lying(name: String, metres: float, tilt := 0.0) -> Sprite3D:
	var s := sprite(CORN_TEX + name + ".png", metres, false)
	s.rotation.z = PI * 0.5 + tilt
	return s


# ── the orders ───────────────────────────────────────────────────────────────

func tickets() -> Array:
	return stand.tickets(building_key) if stand != null and building_key != "" else []


func rail_tickets() -> Array:
	var out: Array = []
	for t in tickets():
		out.append(_with_patience(t))
	return out


## A ticket with its patience as the frame draws it (left 0..1, band).
static func _with_patience(t: Dictionary) -> Dictionary:
	var d: Dictionary = t.duplicate()
	var age := int(t.get("age", 0))
	d["band"] = CORN.patience_band(age)
	d["left"] = 1.0 - clampf(float(age) / float(CORN.PATIENCE_GONE), 0.0, 1.0)
	d["sig"] = "%s|%d" % [str(t.get("kind", "")), int(t.get("salt", 0))]
	return d


## A cob slip: the cob and the salt they want; a drink slip: its cup or its bag.
func ticket_items(t: Dictionary) -> Array:
	var kind := str(t.get("kind", "cob"))
	if kind == "cob":
		var salt := int(t.get("salt", 0))
		return [{"icon": _icons.get("corn"), "word": "NO SALT" if salt == 0 else "SALT %d" % salt}]
	return [{"icon": _mark(kind), "word": "TEA" if kind == "tea" else "LIMO"}]


func _mark(kind: String) -> Texture2D:
	if not _icons.has(kind):
		var p := MARKS + "mark_%s.png" % kind
		_icons[kind] = load(p) if ResourceLoader.exists(p) else null
	return _icons[kind]


## The cob orders waiting, the cobs in the pot (cooking for them) and in the bowl.
func cob_tickets() -> Array:
	return stand.tickets(building_key, "cob") if stand != null and building_key != "" else []


func drink_tickets() -> Array:
	return stand.tickets(building_key, "drink") if stand != null and building_key != "" else []


## Whether the drinks are sold (the books' MENU) and so have a station.
func drinks_on() -> bool:
	var site := BUSINESS.site(building_key)
	return RULES_BIZ.menu_on("corn", site, "tea") or RULES_BIZ.menu_on("corn", site, "limo")


## Where the guest of ticket `t` stands in front of the counter (their head).
func guest_point(t: Dictionary) -> Vector3:
	var life := get_parent().get_node_or_null("Use") if get_parent() != null else null
	if life == null or not life.has_method("member_point"):
		return Vector3.INF
	return life.call("member_point", int(t.get("guest_id", -1)), int(t.get("member", 0)))


func picked_ticket() -> String:
	return picked


func rail_clicked(id: String) -> void:
	picked = "" if picked == id else id
	sfx("tick", -12.0, 1.2)


## What this station hands over: "cob" (the counter, the husking) or "drink".
func serves() -> String:
	return "cob"


## The picked order if it is this station's to hand over, or the oldest of those.
func current_ticket() -> Dictionary:
	var tix: Array = stand.tickets(building_key, serves()) if stand != null and building_key != "" else []
	for t in tix:
		if str(t["id"]) == picked:
			return t
	return tix[0] if not tix.is_empty() else {}


static func first_name(full: String) -> String:
	var p := full.split(" ")
	return p[0] if p.size() > 0 else full


func big_ticket() -> Dictionary:
	var t := current_ticket()
	return _with_patience(t) if not t.is_empty() else t


## What the cob being dressed has on it (the counter), to tick the big slip off:
## {butter: share, salt: shakes, napkin: bool}; {} none.
func cob_counts() -> Dictionary:
	return {}


## The cob order's checklist (Papa's): cooked (red when hard or gone soft), the butter
## all along, the salt they want (red when too much), the napkin.
func checklist(t: Dictionary) -> Array:
	if str(t.get("kind", "cob")) != "cob":
		return []
	var have := cob_counts()
	var out: Array = []
	var cook := float(have.get("cook", -1.0))
	out.append({"text": "COOKED", "state": "todo" if cook < 0.0 else ("done" if cook >= 1.0 and cook <= 1.25 else ("bad" if cook > 1.25 or cook < 0.75 else "todo"))})
	var butter := float(have.get("butter", -1.0))
	out.append({"text": "BUTTER", "state": "done" if butter >= 0.85 else "todo"})
	var want := int(t.get("salt", 0))
	var got := int(have.get("salt", -1))
	var sstate := "todo"
	if got >= 0:
		sstate = "done" if got == want else ("bad" if got > want else "todo")
	out.append({"text": "NO SALT" if want == 0 else "SALT x%d" % want, "state": sstate})
	out.append({"text": "NAPKIN", "state": "done" if bool(have.get("napkin", false)) else "todo"})
	return out


## The crate, the bowl and the butter, for the frame's bar.
func bar_text() -> String:
	if stand == null or building_key == "":
		return ""
	var cobs := maxi(0, BUSINESS.stock_of(building_key, "cobs"))
	var butter := maxi(0, BUSINESS.stock_of(building_key, "butter"))
	return "CRATE %d  BOWL %d  BUTTER %d" % [cobs, int(stand.bowl(building_key)), butter]


## The pot's cobs for the frame while you husk: how done each is, green when it is.
func mirror() -> Array:
	var out: Array = []
	if stand == null or building_key == "" or station == "counter":
		return out
	for c in stand.pot(building_key):
		var cook := CORN.cook_of(float(c["t"]))
		var st := CORN.stage(float(c["t"]))
		out.append({"icon": _icons.get("corn"), "fill": clampf(cook / 1.5, 0.0, 1.0), "zone": Vector2(1.0 / 1.5, 1.25 / 1.5), "col": [RETRO_UI.C_BONE, RETRO_UI.C_GREEN, RETRO_UI.C_RED][st], "blink": st == 2})
	return out
