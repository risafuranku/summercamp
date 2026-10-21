extends "res://scripts/business/station3d.gd"

## A station of the Jednota, worked in the shop or the storeroom (scripts/business/station3d.gd;
## DESIGN.md §7b "The Jednota"): the shop's state (jednota.gd: the rack, the trolley, the
## queue at the till), the queue on the rail drawn as in every place (the guest's face,
## their basket, their patience), the one at the till big in the frame as their receipt
## (the till's checklist).
## The stations: till and shelves in the shop, store in the storeroom.

const RULES := preload("res://core/systems/jednota_rules.gd")
const JEDNOTA := preload("res://scripts/jednota/jednota.gd")
const BIZ := preload("res://scripts/business/business_runtime.gd")
const JTEX := "res://assets/textury/jednota/"
## The goods' little words on the slips and the receipt.
const SHORT := {"bread": "BREAD", "roll": "ROLLS", "salami": "SALAMI", "milk": "MILK", "pickles": "PICKLE",
	"beer": "BEER", "icecream": "ICE", "sweets": "CHOC", "veg": "VEG", "soap": "SOAP", "cards": "CARDS",
	"magazine": "MAG", "rum": "RUM", "cigs": "START"}

var shop
var _icons: Dictionary = {}


func _build() -> void:
	shop = state if state != null else JEDNOTA.of(get_tree())
	for g in RULES.all_goods() + RULES.BEHIND + ["parcel"]:
		_icons[g] = _tex("goods_" + g)
	for n in ["basket", "bag", "box_closed", "coin1", "coin2", "note5", "note10", "note20"]:
		_icons[n] = _tex(n)


func _tex(n: String) -> Texture2D:
	var p := JTEX + n + ".png"
	return load(p) if ResourceLoader.exists(p) else null


func sfx_dir() -> String:
	return "res://assets/sfx/jednota/"


## A Jednota sound, else the pub's or the bistro's of the same name.
func sfx(n: String, db := -8.0, pitch := 1.0) -> void:
	if n.begins_with("res://"):
		super.sfx(n, db, pitch)
		return
	for d in [sfx_dir(), "res://assets/sfx/pub/", "res://assets/sfx/bistro/"]:
		var p: String = d + n + ".mp3"
		if ResourceLoader.exists(p):
			super.sfx(p, db, pitch)
			return


func ding_sound() -> String:
	return "res://assets/sfx/town/shop_bell.mp3"


## A Jednota picture at the station, its longer side `metres` long: lying on the surface
## (`flat`) or standing on it, its foot on it.
func jsprite(n: String, metres: float, flat := false, parent: Node3D = null) -> Sprite3D:
	var s := sprite(JTEX + n + ".png", metres, flat, parent)
	if not flat and s.texture != null:
		s.offset = Vector2(0, float(s.texture.get_height()) * 0.5)
	return s


func jretex(s: Sprite3D, n: String, metres: float) -> void:
	retex(s, JTEX + n + ".png", metres)
	if s.texture != null and s.axis != Vector3.AXIS_Y:
		s.offset = Vector2(0, float(s.texture.get_height()) * 0.5)


# ── the queue ────────────────────────────────────────────────────────────────

func tickets() -> Array:
	return shop.tickets(building_key) if shop != null and building_key != "" else []


func rail_tickets() -> Array:
	var out: Array = []
	var q := tickets()
	for i in q.size():
		var t: Dictionary = q[i]
		var d := t.duplicate()
		var age := int(t.get("age", 0))
		d["band"] = RULES.patience_band(age)
		d["left"] = 1.0 - clampf(float(age) / float(RULES.PATIENCE_GONE), 0.0, 1.0)
		d["picked"] = i == 0 and station == "till"
		d["sig"] = "%d" % (t["rung"] as Array).size()
		out.append(d)
	return out


## The one at the till: the first in the queue ({} nobody).
func first() -> Dictionary:
	var q := tickets()
	return q[0] if not q.is_empty() else {}


## A guest's till slip: their face as their patience goes, their basket and how many
## things are in it (station3d.draw_ticket, the same in every place).
func ticket_items(t: Dictionary) -> Array:
	return [{"icon": _icons.get("basket"), "word": "x%d" % (t.get("items", []) as Array).size()}]


static func first_name(full: String) -> String:
	var p := full.split(" ")
	return p[0] if p.size() > 0 else full


## The money's worth of the pieces on the mat.
static func sum_of(pieces: Array) -> int:
	var n := 0
	for p in pieces:
		n += int(p)
	return n


## The receipt of the one at the till, big (the till's checklist): their face and name;
## every thing with its price, ticked and in ink when rung up (the rest pale); the total,
## what they paid, the change due.
func draw_big_ticket(c: Control, r: Rect2, t: Dictionary) -> void:
	var f: Font = RETRO_UI.FONT_TEXT
	c.draw_rect(r, Color(0.92, 0.9, 0.82))
	c.draw_rect(Rect2(r.position, Vector2(r.size.x, 13)), Color(0.72, 0.16, 0.12))
	var age0 := int(t.get("age", 0))
	FACES.draw(c, r.position + Vector2(2, 2), 1, 1.0 - clampf(float(age0) / float(RULES.PATIENCE_GONE), 0.0, 1.0), str(t.get("name", "")), _t)
	c.draw_string(RETRO_UI.FONT_LABEL, r.position + Vector2(14, 10), first_name(str(t["name"])).to_upper().substr(0, 9), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.98, 0.92, 0.8))
	var items: Array = t["items"]
	var rung: Array = t.get("rung", [])
	var y := r.position.y + 23.0
	var ink := Color(0.16, 0.12, 0.1)
	var pale := Color(0.6, 0.57, 0.5)
	for i in items.size():
		if y > r.end.y - 40.0:
			c.draw_string(f, Vector2(r.position.x + 4, y), "...", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)
			break
		var g := str(items[i])
		var col := ink if rung.has(i) else pale
		if rung.has(i):
			for pxy in [Vector2(1, 3), Vector2(2, 4), Vector2(3, 5), Vector2(4, 4), Vector2(5, 3), Vector2(6, 2)]:
				c.draw_rect(Rect2(Vector2(r.end.x - 26, y - 7) + pxy, Vector2.ONE), Color(0.1, 0.45, 0.12))
		var ic: Texture2D = _icons.get("parcel" if RULES.is_parcel(g) else g)
		if ic != null:
			var sc := minf(8.0 / ic.get_width(), 8.0 / ic.get_height())
			c.draw_texture_rect(ic, Rect2(Vector2(r.position.x + 3, y - 7), (ic.get_size() * sc).floor()), false, Color(1, 1, 1, 1.0 if rung.has(i) else 0.45))
		var short := str(SHORT.get(g, g.to_upper()))
		if RULES.is_parcel(g):
			var pp := g.split(":")
			short = "%s %dG" % [str(pp[1]).substr(0, 5).to_upper(), int(pp[2])] if pp.size() >= 3 else "DELI"
		c.draw_string(f, Vector2(r.position.x + 13, y), short, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
		var price := "%d" % RULES.item_price(g)
		var pw := f.get_string_size(price, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		c.draw_string(f, Vector2(r.end.x - 4 - pw, y), price, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
		y += 9.0
	var all_rung := rung.size() >= items.size()
	var lines: Array = []
	if all_rung:
		lines.append(["TOTAL", "%d" % int(t["total"])])
		lines.append(["PAID", "%d" % (int(t["paid"]) if int(t["paid"]) > 0 else int(t["total"]))])
		lines.append(["CHANGE", "%d" % int(t["due"])])
	var yy := r.end.y - 34.0
	c.draw_rect(Rect2(r.position.x + 3, yy - 9, r.size.x - 6, 1), ink)
	for l in lines:
		c.draw_string(f, Vector2(r.position.x + 4, yy), str(l[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)
		var vw := f.get_string_size(str(l[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		c.draw_string(f, Vector2(r.end.x - 4 - vw, yy), str(l[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)
		yy += 9.0
	var age := int(t.get("age", 0))
	var band := RULES.patience_band(age)
	var bar := Rect2(r.position.x + 6, r.end.y - 5, r.size.x - 12, 3)
	c.draw_rect(bar, Color(0.1, 0.08, 0.06, 0.8))
	c.draw_rect(Rect2(bar.position, Vector2(floorf(bar.size.x * (1.0 - clampf(float(age) / float(RULES.PATIENCE_GONE), 0.0, 1.0))), bar.size.y)), [RETRO_UI.C_GREEN, RETRO_UI.C_AMBER, RETRO_UI.C_RED][band])


## The timers' plate: how long the first has stood at the till, how full the rack is.
func mirror() -> Array:
	var out: Array = []
	if shop == null or building_key == "":
		return out
	var f := first()
	if not f.is_empty():
		var age := int(f["age"])
		out.append({"icon": _icons.get("basket"), "fill": 1.0 - clampf(float(age) / float(RULES.PATIENCE_GONE), 0.0, 1.0), "zone": Vector2(-1, -1),
			"col": [RETRO_UI.C_GREEN, RETRO_UI.C_AMBER, RETRO_UI.C_RED][RULES.patience_band(age)], "blink": RULES.patience_band(age) == 2})
	var have := 0
	var room := 0
	var empty := 0
	for g in RULES.all_goods():
		have += int(shop.shelf(building_key).get(g, 0))
		room += int(shop.cap(building_key))
		if int(shop.shelf(building_key).get(g, 0)) == 0:
			empty += 1
	out.append({"icon": _icons.get("bread"), "fill": float(have) / float(maxi(1, room)), "zone": Vector2(-1, -1),
		"col": RETRO_UI.C_RED if empty > 0 else RETRO_UI.C_AMBER, "blink": empty > 2})
	return out


# ── debug (tools/jednota_check.gd, tools/jednota_shots.gd) ───────────────────

## A click on `id` as if the pointer pressed it.
func debug_click(id: String) -> void:
	_press(id)


## Something waits here: the queue at the till (red when the first is in the red), places
## empty on the rack (the shelves), the store with nothing ready on the trolley.
func alert() -> int:
	return 0


## The rack's places that are empty while the books still have their goods.
func empty_places() -> Array:
	var out: Array = []
	if shop == null or building_key == "":
		return out
	var site := BIZ.site(building_key)
	for g in RULES.all_goods():
		if not RULES_BIZ.menu_on("vecerka", site, str(g)):
			continue
		if int(shop.shelf(building_key).get(g, 0)) == 0 and BIZ.stock_of(building_key, str(g)) > 0:
			out.append(str(g))
	return out
