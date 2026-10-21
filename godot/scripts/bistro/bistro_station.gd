extends "res://scripts/business/station3d.gd"

## A station of the bistro (DESIGN.md §7b "The bistro"), worked in the room
## (scripts/business/station3d.gd): the kitchen's state (kitchen.gd: the trays, the pan,
## the pot, the plates, the tickets), the tickets on the rail with the dish's picture
## and how long they have waited, the picked one big in the frame, the plates on the bar,
## the stove's and the pot's timers when you are at another station of the room.
## The stations: floor (the dining room: the hatch's plates out to the tables, the
## bottles); pass, stove, pot, grill, bufet (the soup of the day), sink (the kitchen);
## potatoes, breading, machine (the cellar). The tickets drawn as in every place
## (station3d.draw_ticket), the big one a checklist of the plate.

const RULES := preload("res://core/systems/bistro_rules.gd")
const KITCHEN := preload("res://scripts/bistro/kitchen.gd")
const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const TEX := "res://assets/textury/bistro/"
const FOOD_ICONS := "res://assets/textury/closeup/food/"
## Each dish's picture on a ticket, and the sides'.
const ICONS := {"goulash": "icon_goulash", "smazak": "icon_cheese", "fries": "icon_fries", "dumpling": "icon_dumpling", "cheese": "icon_cheese", "tartar": "icon_tartar",
	"sausage": "icon_sausage", "mustard": "icon_mustard", "bread": "icon_bread", "soup": "icon_soup", "kofola": "icon_kofola", "malinovka": "icon_malinovka"}
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

## Which tickets this station's rail has: "pass" (plates still to make), "bufet" (the soup),
## "floor" (the plates on the hatch, the bottles), "" all.
func where() -> String:
	return ""


func tickets() -> Array:
	if kitchen == null or building_key == "":
		return []
	return kitchen.tickets(building_key, where())


func rail_tickets() -> Array:
	var out: Array = []
	for t in tickets():
		out.append(_with_patience(t))
	return out


## A ticket with its patience as the frame draws it (left 0..1, band).
func _with_patience(t: Dictionary) -> Dictionary:
	var d: Dictionary = t.duplicate()
	var age := int(t.get("age", 0))
	d["band"] = RULES.patience_band(age)
	d["left"] = 1.0 - clampf(float(age) / float(RULES.PATIENCE_GONE), 0.0, 1.0)
	d["sig"] = "%s|%s" % [str(t.get("dish", "")), bool(t.get("hatched", false))]
	return d


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


## The dish in short, for a ticket (six letters fit).
const SHORT := {"goulash": "GOULASH", "smazak": "CHEESE", "fries": "CHIPS", "sausage": "SAUSAGE", "soup": "SOUP", "kofola": "KOFOLA", "malinovka": "MALIN."}
## The parts by name, for the checklist.
const PART_WORD := {"goulash": "GOULASH", "dumpling": "DUMPLINGS", "onion": "ONION", "cheese": "FRIED CHEESE", "fries": "CHIPS", "tartar": "TARTAR",
	"sausage": "SAUSAGE", "mustard": "MUSTARD", "bread": "BREAD", "soup": "SOUP"}


## A ticket's dish: its picture, and the word for it or what is different about it (six
## dumplings, onion, no tartar).
func ticket_items(t: Dictionary) -> Array:
	var dish := str(t.get("dish", ""))
	var parts: Dictionary = t.get("parts", {})
	var word := str(SHORT.get(dish, dish.to_upper()))
	match dish:
		"goulash":
			word = "x%d" % int(parts.get("dumpling", 4)) + ("+ON" if parts.has("onion") else "")
		"smazak", "fries":
			if not parts.has("tartar"):
				word = "NO TART"
	return [{"icon": _icons.get(dish), "word": word}]


static func ORDERS_first(full: String) -> String:
	var p := full.split(" ")
	return p[0] if p.size() > 0 else full


func big_ticket() -> Dictionary:
	var t := current_ticket()
	return _with_patience(t) if not t.is_empty() else t


## What the plate being built has on it (the pass), to tick the big ticket off.
func plate_counts() -> Dictionary:
	return {}


func building_plate() -> bool:
	return false


## A plate's checklist: each thing it wants with how many (ticked when the plate being
## built has it right, red when too many or wanted none); on the hatch: plated, SERVE.
func checklist(t: Dictionary) -> Array:
	var out: Array = []
	if bool(t.get("hatched", false)):
		out.append({"text": "PLATED", "state": "done"})
		out.append({"text": "SERVE AT THE FLOOR", "state": "todo"})
		return out
	var want: Dictionary = t.get("parts", {})
	var have := plate_counts()
	var plating := building_plate()
	for p in RULES.PARTS:
		var w := int(want.get(p, 0))
		var h := int(have.get(p, 0))
		if w == 0 and (h == 0 or not plating):
			continue
		var state := "todo"
		if plating:
			state = "done" if h == w else ("bad" if h > w else "todo")
		var text := str(PART_WORD.get(p, str(p).to_upper()))
		if w > 1 or (plating and h != w):
			text = ("%d/%d " % [h, w] if plating else "%d " % w) + text
		elif w == 0:
			text = "NO " + text
		out.append({"text": text, "state": state})
	return out


## Something cooking is about to burn here (2), work waits here (1).
func alert() -> int:
	return 0


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
	if station != "grill":
		for slot in s["grill"]:
			if (slot as Dictionary).is_empty():
				continue
			var gt := float(slot["t"][int(slot["down"])])
			var gs := RULES.sausage_side(gt)
			out.append({"icon": _icons.get("sausage"), "fill": gt / (RULES.GRILL_BURNT + 2.0), "zone": Vector2(RULES.GRILL_GOLD / (RULES.GRILL_BURNT + 2.0), RULES.GRILL_BURNT / (RULES.GRILL_BURNT + 2.0)), "col": [RETRO_UI.C_BONE, RETRO_UI.C_GREEN, RETRO_UI.C_RED][gs], "blink": gs == 2})
	if station != "pot":
		var pot: Dictionary = s["pot"]
		if int(pot["level"]) > 0 and float(pot["catch"]) > 0.35:
			out.append({"icon": _icons.get("goulash"), "fill": float(pot["catch"]), "zone": Vector2(-1, -1), "col": RETRO_UI.C_RED if float(pot["catch"]) > 0.6 else RETRO_UI.C_AMBER_DIM, "blink": float(pot["catch"]) > 0.75})
	return out


## How many of `part` the plates still to be made want, beyond what is ready on the
## shelves (the frame's hints: the stove fries for them, the grill grills).
func wanted(part: String) -> int:
	if kitchen == null or building_key == "":
		return 0
	var n := 0
	for t in kitchen.tickets(building_key, "pass"):
		n += int((t["parts"] as Dictionary).get(part, 0))
	return maxi(0, n - kitchen.prep(building_key, part))


## A spot of this station's now (`_spots`) by its id as a hint ({} when it is not there).
func spot_hint(id: String, gesture := "click", to := Vector2(-1, -1)) -> Dictionary:
	for s in _spots():
		if str(s["id"]) != id:
			continue
		var h := {"gesture": gesture}
		if s.has("node"):
			h["node"] = s["node"]
		else:
			h["rect"] = s["rect"]
		if to.x >= 0.0:
			h["to"] = to
		return h
	return {}
