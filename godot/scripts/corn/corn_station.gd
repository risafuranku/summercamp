extends "res://scripts/business/station3d.gd"

## A station of the corn stand, worked on its counter out in the camp
## (scripts/business/station3d.gd; DESIGN.md §7b "The corn stand"): the stand's state
## (cornstand.gd: the pot, the bowl, who was served), the orders on the rail as paper
## slips (the guest's name, a cob, the salt they want: a mark a shake, NO SALT), the
## picked one big in the frame, the cobs in the pot and the butter at the right end of
## the frame, the pot's timers when you are husking. The stations: counter, husk.

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
	return "res://assets/sfx/bistro/"


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
		var d: Dictionary = (t as Dictionary).duplicate()
		var age := int(t.get("age", 0))
		d["band"] = CORN.patience_band(age)
		d["left"] = 1.0 - clampf(float(age) / float(CORN.PATIENCE_GONE), 0.0, 1.0)
		d["sig"] = str(int(float(d["left"]) * 12.0))
		out.append(d)
	return out


func picked_ticket() -> String:
	return picked


func rail_clicked(id: String) -> void:
	picked = "" if picked == id else id
	sfx("tick", -12.0, 1.2)


## The picked order, or the oldest when none is (or it went).
func current_ticket() -> Dictionary:
	var tix := tickets()
	for t in tix:
		if str(t["id"]) == picked:
			return t
	return tix[0] if not tix.is_empty() else {}


static func first_name(full: String) -> String:
	var p := full.split(" ")
	return p[0] if p.size() > 0 else full


## A slip on the rail (26 x 36 px): the name, a cob, the salt (a mark a shake, or NO
## SALT in red), how long they have waited.
func draw_ticket(c: Control, t: Dictionary, size: Vector2) -> void:
	if t.is_empty():
		return
	var paper: Texture2D = _icons.get("ticket")
	if paper != null:
		c.draw_texture_rect(paper, Rect2(Vector2.ZERO, size), false)
	else:
		c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.92, 0.88, 0.76))
	if int(t.get("band", 0)) == 2:
		var old: Texture2D = _icons.get("ticket_old")
		if old != null:
			c.draw_texture_rect(old, Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, 0.6))
	var f: Font = RETRO_UI.FONT_TEXT
	c.draw_string(f, Vector2(2, 8), first_name(str(t.get("name", ""))).to_upper().substr(0, 5), HORIZONTAL_ALIGNMENT_LEFT, size.x - 3, 8, Color(0.55, 0.1, 0.08))
	var ic: Texture2D = _icons.get("corn")
	if ic != null:
		c.draw_texture_rect(ic, Rect2(Vector2(floorf((size.x - ic.get_width()) * 0.5), 10), ic.get_size()), false)
	var salt := int(t.get("salt", 0))
	if salt == 0:
		c.draw_string(f, Vector2(2, size.y - 6), "NO S", HORIZONTAL_ALIGNMENT_LEFT, size.x - 3, 8, Color(0.62, 0.08, 0.05))
	else:
		for i in salt:
			c.draw_rect(Rect2(4 + i * 6, size.y - 11, 3, 4), Color(0.2, 0.18, 0.2))
	var band := int(t.get("band", 0))
	var col: Color = [RETRO_UI.C_GREEN, RETRO_UI.C_AMBER, RETRO_UI.C_RED][band]
	var bar := Rect2(3, size.y - 4, size.x - 6, 2)
	c.draw_rect(bar, Color(0.1, 0.08, 0.06))
	c.draw_rect(Rect2(bar.position, Vector2(floorf(bar.size.x * float(t.get("left", 1.0))), bar.size.y)), col)


func big_ticket() -> Dictionary:
	return current_ticket()


## What the cob being dressed has on it (the counter), to tick the big slip off:
## {butter: share, salt: shakes, napkin: bool}; {} none.
func cob_counts() -> Dictionary:
	return {}


## The slip big in the frame: who, the cob, BUTTER, the salt they want against what is on
## it, the napkin, the wait.
func draw_big_ticket(c: Control, r: Rect2, t: Dictionary) -> void:
	var paper: Texture2D = _icons.get("ticket")
	if paper != null:
		c.draw_texture_rect(paper, r, false)
	else:
		c.draw_rect(r, Color(0.92, 0.88, 0.76))
	var x := r.position.x + 7
	var y := r.position.y + 18
	c.draw_string(RETRO_UI.FONT_LABEL, Vector2(x, y), first_name(str(t["name"])).substr(0, 9).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.55, 0.1, 0.08))
	var ic: Texture2D = _icons.get("corn")
	if ic != null:
		c.draw_texture_rect(ic, Rect2(Vector2(r.end.x - ic.get_width() * 2 - 6, r.position.y + 6), ic.get_size() * 2.0), false)
	var have := cob_counts()
	var ink := Color(0.16, 0.12, 0.1)
	var ok := Color(0.1, 0.45, 0.12)
	var bad := Color(0.62, 0.08, 0.05)
	y += 26
	var butter := float(have.get("butter", -1.0))
	c.draw_string(RETRO_UI.FONT_TEXT, Vector2(x, y), "BUTTER", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ok if butter >= 0.85 else ink)
	y += 13
	var want := int(t.get("salt", 0))
	var salt_text := "NO SALT" if want == 0 else "SALT x%d" % want
	var got := int(have.get("salt", -1))
	var scol := ink
	if got >= 0:
		scol = ok if got == want else (bad if got > want else ink)
	c.draw_string(RETRO_UI.FONT_TEXT, Vector2(x, y), salt_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, scol)
	if got > 0:
		c.draw_string(RETRO_UI.FONT_TEXT, Vector2(r.end.x - 22, y), "%d" % got, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, scol)
	y += 13
	c.draw_string(RETRO_UI.FONT_TEXT, Vector2(x, y), "NAPKIN", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ok if bool(have.get("napkin", false)) else ink)
	var band := CORN.patience_band(int(t.get("age", 0)))
	var bar := Rect2(r.position.x + 6, r.end.y - 8, r.size.x - 12, 4)
	c.draw_rect(bar, Color(0.1, 0.08, 0.06, 0.8))
	c.draw_rect(Rect2(bar.position, Vector2(floorf(bar.size.x * (1.0 - clampf(float(t.get("age", 0)) / float(CORN.PATIENCE_GONE), 0.0, 1.0))), bar.size.y)), [RETRO_UI.C_GREEN, RETRO_UI.C_AMBER, RETRO_UI.C_RED][band])


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
