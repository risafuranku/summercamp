extends "res://scripts/business/station3d.gd"

## A station of the bistro (DESIGN.md §7b "The bistro"), worked in the room
## (scripts/business/station3d.gd): the kitchen's state (kitchen.gd: the trays, the pan,
## the pot, the plates, the tickets), the tickets on the rail with the dish's picture
## and how long they have waited, the picked one big in the frame, the plates on the bar,
## the stove's and the pot's timers when you are at another station of the room.
## The stations: stove, pot, pass, sink (the kitchen); potatoes, breading, machine (the
## cellar).

const RULES := preload("res://core/systems/bistro_rules.gd")
const KITCHEN := preload("res://scripts/bistro/kitchen.gd")
const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const TEX := "res://assets/textury/bistro/"
const FOOD_ICONS := "res://assets/textury/closeup/food/"
## Each dish's picture on a ticket, and the sides'.
const ICONS := {"goulash": "icon_goulash", "smazak": "icon_cheese", "fries": "icon_fries", "dumpling": "icon_dumpling", "cheese": "icon_cheese", "tartar": "icon_tartar"}
## The pictures were drawn for the surface two to one: a design pixel is half a
## picture's pixel (station3d.room_tex shrinks them to the room's pixel).
const PIX := 2.0

## The ticket picked on the rail, the same for every station of the bistro (the pass
## plates for it).
static var picked := ""

var kitchen: KITCHEN
var _icons: Dictionary = {}


func _build() -> void:
	kitchen = state as KITCHEN
	for k in ICONS:
		var p := FOOD_ICONS + str(ICONS[k]) + ".png"
		_icons[k] = load(p) if ResourceLoader.exists(p) else null
	for n in ["ticket", "ticket_old", "star", "star_dim"]:
		_icons[n] = load(TEX + n + ".png") if ResourceLoader.exists(TEX + n + ".png") else null
	var onion := TEX + "food_onion.png"
	_icons["onion"] = load(onion) if ResourceLoader.exists(onion) else null


func sfx_dir() -> String:
	return "res://assets/sfx/bistro/"


## The metres a bistro picture covers on this surface (as it was drawn on its 16:9 Build
## picture), for sprite().
func dm(name: String) -> float:
	var p := TEX + name + ".png"
	if not ResourceLoader.exists(p):
		return 0.1
	var t: Texture2D = load(p)
	return metres_x(float(maxi(t.get_width(), t.get_height())) * PIX)


## A bistro picture as a sprite on the surface, at the size it was drawn.
func bsprite(name: String, flat := true, scale := 1.0) -> Sprite3D:
	return sprite(TEX + name + ".png", dm(name) * scale, flat)


## A thing standing up on the counter, turned to face you (a stack of plates).
func bstand(name: String, scale := 1.0) -> Sprite3D:
	var s := sprite(TEX + name + ".png", dm(name) * scale, false)
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.offset = Vector2(0, float(s.texture.get_height()) * 0.5) if s.texture != null else Vector2.ZERO
	return s


func bretex(s: Sprite3D, name: String, scale := 1.0) -> void:
	retex(s, TEX + name + ".png", dm(name) * scale)


# ── tickets ──────────────────────────────────────────────────────────────────

func tickets() -> Array:
	if kitchen == null or building_key == "":
		return []
	return kitchen.tickets(building_key)


func rail_tickets() -> Array:
	var out: Array = []
	for t in tickets():
		var d: Dictionary = (t as Dictionary).duplicate()
		var age := int(t.get("age", 0))
		d["band"] = RULES.patience_band(age)
		d["left"] = 1.0 - clampf(float(age) / float(RULES.PATIENCE_GONE), 0.0, 1.0)
		# Redrawn as its bar shortens (a step in twelve).
		d["sig"] = str(int(float(d["left"]) * 12.0))
		out.append(d)
	return out


func picked_ticket() -> String:
	return picked


func rail_clicked(id: String) -> void:
	picked = "" if picked == id else id
	sfx("tick", -12.0, 1.2)


## The picked ticket, or the oldest when none is (or it went).
func current_ticket() -> Dictionary:
	var tix := tickets()
	for t in tix:
		if str(t["id"]) == picked:
			return t
	return tix[0] if not tix.is_empty() else {}


## A ticket on the rail (26 x 36 px): the guest's name, the dish's picture, what is
## different about it (six dumplings, onion, no tartar), how long they have waited.
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
	var name := ORDERS_first(str(t.get("name", ""))).to_upper().substr(0, 5)
	c.draw_string(f, Vector2(2, 8), name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 3, 8, Color(0.55, 0.1, 0.08))
	var ic: Texture2D = _icons.get(str(t.get("dish", "")))
	if ic != null:
		c.draw_texture_rect(ic, Rect2(Vector2(floorf((size.x - ic.get_width()) * 0.5), 10), ic.get_size()), false)
	var parts: Dictionary = t.get("parts", {})
	var note := ""
	var note_col := Color(0.16, 0.12, 0.1)
	match str(t.get("dish", "")):
		"goulash":
			note = "x%d" % int(parts.get("dumpling", 4))
			if parts.has("onion"):
				note += "+O"
		"smazak", "fries":
			if not parts.has("tartar"):
				note = "NO T"
				note_col = Color(0.62, 0.08, 0.05)
	if note != "":
		var w := f.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		c.draw_string(f, Vector2(floorf((size.x - w) * 0.5), 28), note, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, note_col)
	var band := int(t.get("band", 0))
	var col: Color = [RETRO_UI.C_GREEN, RETRO_UI.C_AMBER, RETRO_UI.C_RED][band]
	var bar := Rect2(3, size.y - 5, size.x - 6, 2)
	c.draw_rect(bar, Color(0.1, 0.08, 0.06))
	c.draw_rect(Rect2(bar.position, Vector2(floorf(bar.size.x * float(t.get("left", 1.0))), bar.size.y)), col)
	if bool(t.get("picked", false)):
		c.draw_rect(Rect2(Vector2.ZERO, size), RETRO_UI.C_AMBER, false, 1.0)


static func ORDERS_first(full: String) -> String:
	var p := full.split(" ")
	return p[0] if p.size() > 0 else full


func big_ticket() -> Dictionary:
	return current_ticket()


## What the plate being built has on it (the pass), to tick the big ticket off.
func plate_counts() -> Dictionary:
	return {}


func building_plate() -> bool:
	return false


## The ticket big in the frame (`r`, the frame's pixels): who, the dish, each thing it
## wants with how many are on the plate (the pass), the wait.
func draw_big_ticket(c: Control, r: Rect2, t: Dictionary) -> void:
	var paper: Texture2D = _icons.get("ticket")
	if paper != null:
		c.draw_texture_rect(paper, r, false)
	else:
		c.draw_rect(r, Color(0.92, 0.88, 0.76))
	var x := r.position.x + 7
	var y := r.position.y + 18
	c.draw_string(RETRO_UI.FONT_LABEL, Vector2(x, y), ORDERS_first(str(t["name"])).substr(0, 9).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.55, 0.1, 0.08))
	var main_ic: Texture2D = _icons.get(str(t.get("dish", "")))
	if main_ic != null:
		c.draw_texture_rect(main_ic, Rect2(Vector2(r.end.x - main_ic.get_width() * 2 - 6, r.position.y + 6), main_ic.get_size() * 2.0), false)
	y += 12
	var want: Dictionary = t["parts"]
	var have := plate_counts()
	var plating := building_plate()
	for p in RULES.PARTS:
		var w := int(want.get(p, 0))
		var h := int(have.get(p, 0))
		if w == 0 and h == 0:
			continue
		y += 13
		var ic: Texture2D = _icons.get(p)
		if ic != null:
			c.draw_texture_rect(ic, Rect2(x, y - 10, ic.get_width(), ic.get_height()), false)
		var col := Color(0.16, 0.12, 0.1)
		var mark := ""
		if plating:
			if h == w:
				col = Color(0.1, 0.45, 0.12)
				mark = "OK"
			elif h > w:
				col = Color(0.65, 0.1, 0.06)
				mark = "+%d" % (h - w) if w > 0 else "NO"
			else:
				col = Color(0.4, 0.3, 0.2)
				mark = "-%d" % (w - h)
			c.draw_string(RETRO_UI.FONT_TEXT, Vector2(x + 15, y), "%d/%d" % [h, w], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
		else:
			c.draw_string(RETRO_UI.FONT_TEXT, Vector2(x + 15, y), "x%d" % w, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
		c.draw_string(RETRO_UI.FONT_LABEL, Vector2(x + 46, y), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
	var band := RULES.patience_band(int(t.get("age", 0)))
	var bar := Rect2(r.position.x + 6, r.end.y - 10, r.size.x - 12, 4)
	c.draw_rect(bar, Color(0.1, 0.08, 0.06, 0.8))
	c.draw_rect(Rect2(bar.position, Vector2(floorf(bar.size.x * (1.0 - clampf(float(t.get("age", 0)) / float(RULES.PATIENCE_GONE), 0.0, 1.0))), bar.size.y)), [RETRO_UI.C_GREEN, RETRO_UI.C_AMBER, RETRO_UI.C_RED][band])


## The plates on the bar.
func bar_text() -> String:
	if kitchen == null:
		return ""
	var pl: Dictionary = kitchen.plates(building_key)
	var text := "PLATES %d" % int(pl["clean"])
	if int(pl["dirty"]) > 0:
		text += "  DIRTY %d" % int(pl["dirty"])
	return text


## The timers of the stove and the pot for the frame (from another station of the room).
func mirror() -> Array:
	var out: Array = []
	if kitchen == null or building_key == "":
		return out
	var s: Dictionary = kitchen.site(building_key)
	if station != "stove":
		for slot in s["pan"]:
			if (slot as Dictionary).is_empty():
				continue
			var bad := bool(slot.get("bad", false))
			var t := float(slot["t"][int(slot["down"])])
			var burnt := RULES.CHEESE_BURNT_BAD if bad else RULES.CHEESE_BURNT
			var st := RULES.cheese_side(t, bad)
			out.append({"icon": _icons.get("cheese"), "fill": t / (burnt + 2.0), "zone": Vector2(RULES.CHEESE_GOLD / (burnt + 2.0), burnt / (burnt + 2.0)), "col": [RETRO_UI.C_BONE, RETRO_UI.C_GREEN, RETRO_UI.C_RED][st], "blink": st == 2})
		var b: Dictionary = s["basket"]
		if str(b["st"]) == "down":
			var bt := float(b["t"])
			var fs := RULES.fries_state(bt)
			out.append({"icon": _icons.get("fries"), "fill": bt / (RULES.FRIES_BURNT + 3.0), "zone": Vector2(RULES.FRIES_GOLD / (RULES.FRIES_BURNT + 3.0), RULES.FRIES_BURNT / (RULES.FRIES_BURNT + 3.0)), "col": [RETRO_UI.C_BONE, RETRO_UI.C_GREEN, RETRO_UI.C_RED][fs], "blink": fs == 2})
	if station != "pot":
		var pot: Dictionary = s["pot"]
		if int(pot["level"]) > 0 and float(pot["catch"]) > 0.35:
			out.append({"icon": _icons.get("goulash"), "fill": float(pot["catch"]), "zone": Vector2(-1, -1), "col": RETRO_UI.C_RED if float(pot["catch"]) > 0.6 else RETRO_UI.C_AMBER_DIM, "blink": float(pot["catch"]) > 0.75})
	return out
