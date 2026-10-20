extends "res://scripts/business/station3d.gd"

## A station of the pub, worked in the room (scripts/business/station3d.gd; DESIGN.md §7b
## "the pub"): the taproom's state (taproom.gd: the mugs, the keg, the gas, what was
## poured for whom), the orders on the rail as the guests' beer mats (their name in the
## landlord's pencil, what they want, a stroke for every one they have had, how long
## they have waited), the picked one big in the frame, the mugs and the keg on the bar.
## The stations: tap, back (the back bar), wash (the washer) in the bar room, keg in the
## cellar.

const PUB := preload("res://core/systems/pub_rules.gd")
const TAPROOM := preload("res://scripts/pub/taproom.gd")
const PUB_TEX := "res://assets/textury/pub/"
const MARKS := "res://assets/textury/ui/"
## The little pictures on the mats (assets/textury/ui/mark_*.png, Grok).
const DRINK_ICONS := {"hladinka": "mark_mug", "snyt": "mark_mug", "mliko": "mark_foam", "rum": "mark_shot",
	"zelena": "mark_shot", "slivovice": "mark_shot", "kofola": "mark_kofola"}
const SPIRIT_TINT := {"rum": Color(0.75, 0.45, 0.2), "zelena": Color(0.45, 0.8, 0.35), "slivovice": Color(1.0, 1.0, 0.92), "kofola": Color(1, 1, 1)}
const SHORT := {"hladinka": "HLAD", "snyt": "SNYT", "mliko": "MLIKO", "rum": "RUM", "zelena": "ZEL", "slivovice": "SLIV", "kofola": "KOF"}

## The mat picked on the rail (the tap pours for it first).
static var picked := ""

var taproom
var _icons: Dictionary = {}


func _build() -> void:
	taproom = state if state != null else TAPROOM.of(get_tree())
	for n in ["mark_mug", "mark_foam", "mark_shot", "mark_kofola", "mark_keg", "mark_dirty"]:
		_icons[n] = load(MARKS + n + ".png") if ResourceLoader.exists(MARKS + n + ".png") else null
	var mat := PUB_TEX + "mat.png"
	_icons["mat"] = load(mat) if ResourceLoader.exists(mat) else null


func sfx_dir() -> String:
	return "res://assets/sfx/pub/"


## A pub sound, else the bistro's of the same name (or a whole path).
func sfx(n: String, db := -8.0, pitch := 1.0) -> void:
	if n.begins_with("res://"):
		super.sfx(n, db, pitch)
		return
	var p := sfx_dir() + n + ".mp3"
	if not ResourceLoader.exists(p):
		p = "res://assets/sfx/bistro/" + n + ".mp3"
	super.sfx(p, db, pitch)


## A pub picture laid on the bar, its longer side `metres` long.
func psprite(name: String, metres: float, flat := false) -> Sprite3D:
	var s := sprite(PUB_TEX + name + ".png", metres, flat)
	if not flat:
		# Standing on the bar: its foot on the surface.
		s.offset = Vector2(0, float(s.texture.get_height()) * 0.5) if s.texture != null else Vector2.ZERO
	return s


func pretex(s: Sprite3D, name: String, metres: float) -> void:
	retex(s, PUB_TEX + name + ".png", metres)
	if s.texture != null and s.axis != Vector3.AXIS_Y:
		s.offset = Vector2(0, float(s.texture.get_height()) * 0.5)


# ── the mats ─────────────────────────────────────────────────────────────────

func tickets() -> Array:
	return taproom.tickets(building_key) if taproom != null and building_key != "" else []


func rail_tickets() -> Array:
	var out: Array = []
	# Who wants to pay: their mat with the marks, BILL on it (the tap settles it).
	for b in bills():
		var d: Dictionary = (b as Dictionary).duplicate()
		var age := int(b.get("age", 0))
		d["band"] = 0 if age < PUB.BILL_WAIT / 2 else (1 if age < PUB.BILL_WAIT - 3 else 2)
		d["left"] = 1.0 - clampf(float(age) / float(PUB.BILL_WAIT), 0.0, 1.0)
		d["sig"] = "bill|%d" % int(float(d["left"]) * 12.0)
		out.append(d)
	for t in tickets():
		var d: Dictionary = (t as Dictionary).duplicate()
		var age := int(t.get("age", 0))
		d["band"] = PUB.patience_band(age)
		d["left"] = 1.0 - clampf(float(age) / float(PUB.PATIENCE_GONE), 0.0, 1.0)
		d["had"] = taproom.strokes(building_key, str(t["visit"]), int(t["member"])) if taproom != null else 0
		d["sig"] = "%d|%d" % [int(float(d["left"]) * 12.0), int(d["had"])]
		out.append(d)
	return out


func bills() -> Array:
	return taproom.bills(building_key) if taproom != null and building_key != "" else []


func picked_ticket() -> String:
	return picked


func rail_clicked(id: String) -> void:
	picked = "" if picked == id else id
	sfx("tick", -12.0, 1.2)


## The orders this station pours ("tap" or "bar"), oldest first; the picked one first.
func orders_here(kind_of: String) -> Array:
	var out: Array = []
	for t in tickets():
		if PUB.kind(str(t["drink"])) == kind_of:
			if str(t["id"]) == picked:
				out.push_front(t)
			else:
				out.append(t)
	return out


## A guest's beer mat on the rail (26 x 36 px): their name, the drink's picture and its
## word, a stroke a drink they have had, how long they have waited.
func draw_ticket(c: Control, t: Dictionary, size: Vector2) -> void:
	if t.is_empty():
		return
	if str(t.get("kind", "")) == "bill":
		_draw_bill_slip(c, t, size)
		return
	var f: Font = RETRO_UI.FONT_TEXT
	var mat: Texture2D = _icons.get("mat")
	var disc := Rect2(Vector2(0, 7), Vector2(size.x, size.x - 2))
	if mat != null:
		c.draw_texture_rect(mat, disc, false)
	else:
		c.draw_rect(disc, Color(0.9, 0.87, 0.8))
	var who := ORDERS_first(str(t.get("name", ""))).to_upper().substr(0, 5)
	c.draw_string(f, Vector2(1, 6), who, HORIZONTAL_ALIGNMENT_LEFT, size.x - 2, 8, Color(0.95, 0.85, 0.6))
	var drink := str(t.get("drink", ""))
	var ic: Texture2D = _icons.get(str(DRINK_ICONS.get(drink, "mark_mug")))
	if ic != null:
		c.draw_texture_rect(ic, Rect2((disc.get_center() - ic.get_size() * 0.5 - Vector2(0, 3)).floor(), ic.get_size()), false, SPIRIT_TINT.get(drink, Color(1, 1, 1)))
	var word := str(SHORT.get(drink, drink.to_upper()))
	var w := f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	c.draw_string(f, Vector2(floorf((size.x - w) * 0.5), disc.end.y - 1), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.18, 0.12, 0.1))
	for i in mini(int(t.get("had", 0)), 5):
		c.draw_rect(Rect2(3 + i * 3, 9 + (i % 2), 1, 4), Color(0.2, 0.18, 0.2, 0.85))
	var band := int(t.get("band", 0))
	var col: Color = [RETRO_UI.C_GREEN, RETRO_UI.C_AMBER, RETRO_UI.C_RED][band]
	var bar := Rect2(3, size.y - 3, size.x - 6, 2)
	c.draw_rect(bar, Color(0.1, 0.08, 0.06))
	c.draw_rect(Rect2(bar.position, Vector2(floorf(bar.size.x * float(t.get("left", 1.0))), bar.size.y)), col)
	if bool(t.get("picked", false)):
		c.draw_rect(Rect2(Vector2.ZERO, size), RETRO_UI.C_AMBER, false, 1.0)


## A bill on the rail: the mat with its marks, BILL in red over it.
func _draw_bill_slip(c: Control, t: Dictionary, size: Vector2) -> void:
	var f: Font = RETRO_UI.FONT_TEXT
	var mat: Texture2D = _icons.get("mat")
	var disc := Rect2(Vector2(0, 7), Vector2(size.x, size.x - 2))
	if mat != null:
		c.draw_texture_rect(mat, disc, false)
	else:
		c.draw_rect(disc, Color(0.9, 0.87, 0.8))
	c.draw_string(f, Vector2(1, 6), ORDERS_first(str(t.get("name", ""))).to_upper().substr(0, 5), HORIZONTAL_ALIGNMENT_LEFT, size.x - 2, 8, Color(0.95, 0.85, 0.6))
	_draw_marks(c, t.get("counts", {}), Rect2(disc.position + Vector2(4, 5), disc.size - Vector2(8, 14)), 1)
	var word := "BILL"
	var w := f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	c.draw_string(f, Vector2(floorf((size.x - w) * 0.5), disc.end.y - 1), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.62, 0.08, 0.05))
	var band := int(t.get("band", 0))
	var col: Color = [RETRO_UI.C_GREEN, RETRO_UI.C_AMBER, RETRO_UI.C_RED][band]
	var bar := Rect2(3, size.y - 3, size.x - 6, 2)
	c.draw_rect(bar, Color(0.1, 0.08, 0.06))
	c.draw_rect(Rect2(bar.position, Vector2(floorf(bar.size.x * float(t.get("left", 1.0))), bar.size.y)), col)


## The pencil marks on a mat, in rows: strokes (beer), crosses (shots), rings (kofola);
## `k` pixels a pencil line is wide.
static func _draw_marks(c: Control, counts: Dictionary, r: Rect2, k: int) -> void:
	var ink := Color(0.2, 0.18, 0.22, 0.95)
	var x := r.position.x
	var y := r.position.y
	var step := 3 * k
	var h := 5 * k
	for cls in ["beer", "shot", "kofola"]:
		var n := int(counts.get(cls, 0))
		for i in n:
			if x + step > r.end.x:
				x = r.position.x
				y += h + 2 * k
			match cls:
				"beer":
					c.draw_rect(Rect2(x + k, y, k, h), ink)
				"shot":
					for j in 3:
						c.draw_rect(Rect2(x + j * k, y + j * k + k, k, k), ink)
						c.draw_rect(Rect2(x + (2 - j) * k, y + j * k + k, k, k), ink)
				"kofola":
					c.draw_rect(Rect2(x, y + k, 3 * k, k), ink)
					c.draw_rect(Rect2(x, y + 3 * k, 3 * k, k), ink)
					c.draw_rect(Rect2(x, y + k, k, 3 * k), ink)
					c.draw_rect(Rect2(x + 2 * k, y + k, k, 3 * k), ink)
			x += step + (k if cls != "beer" else 0)
		if n > 0:
			x += 2 * k


static func ORDERS_first(full: String) -> String:
	var p := full.split(" ")
	return p[0] if p.size() > 0 else full


func big_ticket() -> Dictionary:
	for t in tickets():
		if str(t["id"]) == picked:
			return t
	for b in bills():
		if str(b["id"]) == picked:
			return b
	return {}


## A bill big: the mat with the marks, the board's prices, what they put down, the round
## sum they asked for.
func _draw_big_bill(c: Control, r: Rect2, t: Dictionary) -> void:
	var mat: Texture2D = _icons.get("mat")
	var disc := Rect2(r.position + Vector2(0, 10), Vector2(r.size.x, r.size.x))
	if mat != null:
		c.draw_texture_rect(mat, disc, false)
	else:
		c.draw_rect(disc, Color(0.9, 0.87, 0.8))
	c.draw_string(RETRO_UI.FONT_LABEL, r.position + Vector2(4, 8), ORDERS_first(str(t["name"])).to_upper().substr(0, 9), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, RETRO_UI.C_AMBER_LIGHT)
	_draw_marks(c, t.get("counts", {}), Rect2(disc.position + Vector2(12, 14), disc.size - Vector2(24, 30)), 2)
	var ink := Color(0.16, 0.12, 0.1)
	var y := disc.end.y + 2
	var f: Font = RETRO_UI.FONT_TEXT
	c.draw_rect(Rect2(r.position.x, y - 9, r.size.x, r.end.y - y + 9), Color(0.92, 0.88, 0.76))
	c.draw_string(f, Vector2(r.position.x + 4, y), "| %d  X %d  O %d" % [int(PUB.TAB["beer"]["price"]), int(PUB.TAB["shot"]["price"]), int(PUB.TAB["kofola"]["price"])], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 6, 8, ink)
	y += 11
	var note := int(t.get("note", 0))
	c.draw_string(f, Vector2(r.position.x + 4, y), "PAYS $%d" % note if note > 0 else "RIGHT MONEY", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 6, 8, ink)
	if int(t.get("make_it", 0)) > 0:
		y += 11
		c.draw_string(f, Vector2(r.position.x + 4, y), "MAKE IT $%d" % int(t["make_it"]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 6, 8, Color(0.1, 0.4, 0.12))


## The picked mat big: who, what, how many they have had, the wait.
func draw_big_ticket(c: Control, r: Rect2, t: Dictionary) -> void:
	if str(t.get("kind", "")) == "bill":
		_draw_big_bill(c, r, t)
		return
	var mat: Texture2D = _icons.get("mat")
	var disc := Rect2(r.position + Vector2(0, 10), Vector2(r.size.x, r.size.x))
	if mat != null:
		c.draw_texture_rect(mat, disc, false)
	else:
		c.draw_rect(disc, Color(0.9, 0.87, 0.8))
	c.draw_string(RETRO_UI.FONT_LABEL, r.position + Vector2(4, 8), ORDERS_first(str(t["name"])).to_upper().substr(0, 9), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, RETRO_UI.C_AMBER_LIGHT)
	var drink := str(t["drink"])
	var ic: Texture2D = _icons.get(str(DRINK_ICONS.get(drink, "mark_mug")))
	if ic != null:
		c.draw_texture_rect(ic, Rect2((disc.get_center() - ic.get_size() - Vector2(0, 8)).floor(), ic.get_size() * 2.0), false, SPIRIT_TINT.get(drink, Color(1, 1, 1)))
	var word := PUB.label(drink).to_upper()
	var w := RETRO_UI.FONT_LABEL.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	c.draw_string(RETRO_UI.FONT_LABEL, Vector2(floorf(disc.get_center().x - w * 0.5), disc.end.y - 18), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.18, 0.12, 0.1))
	var band := PUB.patience_band(int(t.get("age", 0)))
	var bar := Rect2(r.position.x + 6, r.end.y - 6, r.size.x - 12, 4)
	c.draw_rect(bar, Color(0.1, 0.08, 0.06, 0.8))
	c.draw_rect(Rect2(bar.position, Vector2(floorf(bar.size.x * (1.0 - clampf(float(t.get("age", 0)) / float(PUB.PATIENCE_GONE), 0.0, 1.0))), bar.size.y)), [RETRO_UI.C_GREEN, RETRO_UI.C_AMBER, RETRO_UI.C_RED][band])


## The mugs and the keg on the bar.
func bar_text() -> String:
	if taproom == null or building_key == "":
		return ""
	var m: Dictionary = taproom.mugs(building_key)
	var k: Dictionary = taproom.keg(building_key)
	var text := "MUGS %d" % int(m["clean"])
	if int(m["dirty"]) > 0:
		text += "  DIRTY %d" % int(m["dirty"])
	var trouble: String = taproom.tap_trouble(building_key)
	text += "   KEG " + ({"dry": "DRY", "empty": "EMPTY", "off": "OFF", "flat": "FLAT"}.get(trouble, "%d" % int(k["line"])))
	return text


## The keg's gas and what is left in it, for the frame (from the bar's stations).
func mirror() -> Array:
	var out: Array = []
	if taproom == null or building_key == "" or station == "keg":
		return out
	var k: Dictionary = taproom.keg(building_key)
	var gas := float(k.get("gas", 0.5))
	out.append({"icon": _icons.get("mark_keg"), "fill": float(int(k.get("line", 0))) / float(PUB.KEG_PINTS), "zone": Vector2(-1, -1), "col": RETRO_UI.C_AMBER if int(k.get("line", 0)) > 6 else RETRO_UI.C_RED, "blink": int(k.get("line", 0)) <= 3})
	out.append({"icon": _icons.get("mark_foam"), "fill": gas, "zone": Vector2(PUB.GAS_LOW, PUB.GAS_HIGH), "col": RETRO_UI.C_GREEN if PUB.gas_band(gas) == "OK" else RETRO_UI.C_RED, "blink": PUB.gas_band(gas) != "OK"})
	return out
