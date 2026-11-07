extends "res://scripts/business/station3d.gd"

## A station of the pub, worked in the room (scripts/business/station3d.gd; DESIGN.md §7b
## "the pub"): the taproom's state (taproom.gd: the mugs, the keg, the gas, what was
## poured for whom), a tab on the rail for each guest in the pub (their face, what they
## want now and their patience, the strokes of what they have had; lit when they want to
## pay, a click settles it), the order picked big in the frame as a checklist, the mugs and
## the keg under SERVE.
## The stations: tap, back (the back bar), wash (the washer) in the bar room, keg in the
## cellar.

const PUB := preload("res://core/systems/pub_rules.gd")
const TAPROOM := preload("res://scripts/pub/taproom.gd")
const ORDERS_S := preload("res://scripts/food/orders.gd")
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
	fine = 2.0
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


## The rail as a tab for each guest in the pub (the user 4. 11.: "when a guest comes, a tab
## with their head appears at the top; whenever they want something there is its icon,
## when you give it them a stroke is added; when they are leaving the tab is lit, and they
## go when you click it off"), in the order they came: who they are, what they want now and
## how long they will wait for it, the strokes of what they have had; a bill asked for
## lights the tabs of the party, a click on one settles it.
func rail_tickets() -> Array:
	var out: Array = []
	if taproom == null or building_key == "":
		return out
	var orders := {}
	for t in tickets():
		orders["%s#%d" % [str(t["visit"]), int(t["member"])]] = t
	var bill_of := {}
	for b in bills():
		bill_of[str(b["visit"])] = b
	var visits: Array = ORDERS_S.visitors(building_key)
	visits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("arrive", 0)) < int(b.get("arrive", 0)))
	var settled: Dictionary = taproom.site(building_key)["served"] if taproom != null else {}
	for v in visits:
		var visit := str(v["visit"])
		if settled.has(visit + "#bill"):
			continue
		var bill: Dictionary = bill_of.get(visit, {})
		for m in maxi(1, int(v.get("figures", 1))):
			var id := "%s#%d" % [visit, m]
			var tab := {"id": id, "kind": "tab", "visit": visit, "member": m, "guest_id": int(v["id"]), "arch": str(v["archetype"]),
				"name": str(v["name"]), "strokes": taproom.strokes(building_key, visit, m), "band": 0, "left": 1.0}
			var want: Dictionary = orders.get(id, {})
			if not bill.is_empty():
				var pb := _with_patience(bill)
				tab["bill"] = bill
				tab["band"] = pb["band"]
				tab["left"] = pb["left"]
			elif not want.is_empty():
				var pw := _with_patience(want)
				tab["want"] = want
				tab["band"] = pw["band"]
				tab["left"] = pw["left"]
			tab["sig"] = "%s|%d|%s" % [str(want.get("drink", "")), int(tab["strokes"]), "bill" if tab.has("bill") else ""]
			out.append(tab)
	return out


## New orders and bills ding (the tabs stay the same as their wants change).
func _check_rail() -> void:
	var now := {"@orders": true}
	var fresh := false
	var quiet := not _rail_seen.has("@orders")
	for t in tickets() + bills():
		var id := str(t.get("id", ""))
		now[id] = true
		fresh = fresh or not _rail_seen.has(id)
	if fresh and not quiet:
		sfx(ding_sound(), -12.0)
	_rail_seen = now


## A mat or a bill with its patience as the frame draws it (left 0..1, band).
func _with_patience(t: Dictionary) -> Dictionary:
	var d: Dictionary = t.duplicate()
	var age := int(t.get("age", 0))
	if str(t.get("kind", "")) == "bill":
		d["band"] = 0 if age < PUB.BILL_WAIT / 2 else (1 if age < PUB.BILL_WAIT - 3 else 2)
		d["left"] = 1.0 - clampf(float(age) / float(PUB.BILL_WAIT), 0.0, 1.0)
		d["sig"] = "bill"
	else:
		d["band"] = PUB.patience_band(age)
		d["left"] = 1.0 - clampf(float(age) / float(PUB.PATIENCE_GONE), 0.0, 1.0)
		d["sig"] = str(t.get("drink", ""))
	return d


func bills() -> Array:
	return taproom.bills(building_key) if taproom != null and building_key != "" else []


## The tab of the guest whose order is picked.
func picked_ticket() -> String:
	var at := picked.find("/")
	return picked.substr(0, at) if at > 0 else picked


## A click on a guest's tab: their party's bill settled at once if they want to pay (the
## money and the tip, no counting change: the brief of 21. 10.); else what they want picked
## (the tap pours for it first), or put back.
func rail_clicked(id: String) -> void:
	var visit := id.substr(0, id.rfind("#")) if id.rfind("#") > 0 else id
	for b in bills():
		if str(b["id"]) == id or str(b["visit"]) == visit:
			settle_bill(b)
			return
	for t in tickets():
		if "%s#%d" % [str(t["visit"]), int(t["member"])] == id or str(t["id"]) == id:
			picked = "" if picked == str(t["id"]) else str(t["id"])
			sfx("tick", -12.0, 1.2)
			return
	sfx("tick", -16.0, 0.9)


## A guest's tab (rail_tickets): their face and name at the top; in the middle what they
## want now, its word under it, or the bill when they want to pay (the tab lit gold); the
## strokes of what they have had in pencil; their patience along the bottom.
func draw_ticket(c: Control, t: Dictionary, size: Vector2) -> void:
	if str(t.get("kind", "")) != "tab":
		super.draw_ticket(c, t, size)
		return
	var paper := _paper_tex()
	if paper != null:
		c.draw_texture_rect(paper, Rect2(Vector2.ZERO, size), false)
	else:
		c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.92, 0.88, 0.76))
	var paying := t.has("bill")
	var wanting := t.has("want")
	var left := clampf(float(t.get("left", 1.0)), 0.0, 1.0)
	if paying:
		c.draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.78, 0.2, 0.32))
	elif wanting and left < 0.2:
		c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.75, 0.1, 0.05, 0.18))
	FACES.draw(c, Vector2(2, 2), 1, left if (wanting or paying) else 1.0, str(t.get("name", "")) + ("" if int(t.get("member", 0)) == 0 else "#%d" % int(t["member"])), _t)
	var f: Font = RETRO_UI.FONT_TEXT
	var nm := first_word(str(t.get("name", ""))).to_upper()
	c.draw_string(f, Vector2(13, 9), nm.substr(0, 4), HORIZONTAL_ALIGNMENT_LEFT, size.x - 14, 8, Color(0.55, 0.1, 0.08))
	var ic: Texture2D = null
	var word := ""
	if paying:
		ic = bill_slip(_bill_marks(t["bill"]))
		word = "BILL"
	elif wanting:
		var drink := str((t["want"] as Dictionary).get("drink", ""))
		ic = _icons.get(str(DRINK_ICONS.get(drink, "mark_mug")))
		word = str(SHORT.get(drink, drink.to_upper()))
	if ic != null:
		var sc := minf(1.0, 16.0 / maxf(ic.get_width(), ic.get_height()))
		var isz := (ic.get_size() * sc).floor()
		c.draw_texture_rect(ic, Rect2(Vector2(floorf((size.x - isz.x) * 0.5), 12.0 + floorf((16.0 - isz.y) * 0.5)), isz), false)
	if word != "":
		var tw := tr(word).to_upper()
		var ww := f.get_string_size(tw, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		c.draw_string(f, Vector2(maxf(1.0, floorf((size.x - ww) * 0.5)), 33), tw, HORIZONTAL_ALIGNMENT_LEFT, size.x - 2, 8, Color(0.16, 0.12, 0.1))
	# The strokes, as on the beer mat: four and the fifth across them.
	var pencil := Color(0.2, 0.19, 0.22)
	var n := mini(int(t.get("strokes", 0)), 15)
	for i in n:
		var gx := 3.0 + float(i / 5) * 10.0
		var k := i % 5
		if k < 4:
			c.draw_rect(Rect2(gx + float(k) * 2.0, 35, 1, 5), pencil)
		else:
			c.draw_line(Vector2(gx - 1.0, 39.5), Vector2(gx + 7.0, 35.5), pencil, 1.0)
	if wanting or paying:
		var band := int(t.get("band", 0))
		var col: Color = [RETRO_UI.C_GREEN, RETRO_UI.C_AMBER, RETRO_UI.C_RED][clampi(band, 0, 2)]
		RETRO_UI.draw_segments(c, Rect2(3, size.y - 5, size.x - 6, 3), left if band < 2 or int(_t * 4.0) % 2 == 0 else 0.0, 6, col)
	if paying:
		# Lit: they are going, a click sees them off.
		var lit := Color(0.85, 0.55, 0.08) if int(_t * 2.0) % 2 == 0 else Color(1.0, 0.82, 0.3)
		c.draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2.ONE), lit, false, 1.0)
	elif bool(t.get("picked", false)):
		c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.62, 0.42, 0.08), false, 1.0)


## A bill settled in one click: what the marks come to, the round sum they asked for as
## the tip, flying up over the rail.
func settle_bill(b: Dictionary) -> void:
	if taproom == null or b.is_empty():
		return
	var who := ORDERS_first(str(b.get("name", "")))
	var v: Dictionary = taproom.settle(building_key, b, PUB.change_due(b))
	if not bool(v.get("ok", false)):
		return
	v["ok"] = true
	sfx("coins_bar", -8.0)
	if picked == str(b["id"]):
		picked = ""
	score_card(v, "The bill", _with_patience(b))
	if int(b.get("make_it", 0)) > 0:
		say(who, ["Keep the change.", "Na shledanou.", "Good beer tonight."][randi() % 3])
	else:
		say(who, "Na shledanou.")


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


## What a mat asks for: the drink's picture and its word; a bill: BILL.
func ticket_items(t: Dictionary) -> Array:
	if str(t.get("kind", "")) == "bill":
		return [{"icon": bill_slip(_bill_marks(t)), "word": "BILL"}]
	var drink := str(t.get("drink", ""))
	return [{"icon": _icons.get(str(DRINK_ICONS.get(drink, "mark_mug"))), "word": str(SHORT.get(drink, drink.to_upper()))}]


## How many drinks a bill has on it (its marks).
static func _bill_marks(t: Dictionary) -> int:
	var n := 0
	var counts = t.get("counts", {})
	if counts is Dictionary:
		for v in (counts as Dictionary).values():
			n += int(v)
	return maxi(1, n)


static var _slips: Dictionary = {}


## A bill as the pub writes it (playtest 25. 10.: "bills are oblong slips of paper with
## strokes on them, not ... camemberts?"; it was the round beer mat): a strip torn off
## the order pad (the bistro's ticket paper) with a pencil stroke for each drink, the
## fifth across the four. Made once for each count.
static func bill_slip(marks: int) -> Texture2D:
	marks = clampi(marks, 1, 15)
	if _slips.has(marks):
		return _slips[marks]
	var w := 12
	var h := 18
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var paper_path := "res://assets/textury/bistro/ticket.png"
	if ResourceLoader.exists(paper_path):
		var src: Image = (load(paper_path) as Texture2D).get_image()
		if src.is_compressed():
			src.decompress()
		src.convert(Image.FORMAT_RGBA8)
		src.resize(w, h, Image.INTERPOLATE_NEAREST)
		img.blit_rect(src, Rect2i(0, 0, w, h), Vector2i.ZERO)
	else:
		img.fill(Color(0.9, 0.87, 0.76))
	# A darker edge so it reads as a slip on the rail's paper.
	for x in w:
		img.set_pixel(x, h - 1, Color(0.55, 0.5, 0.42))
	for y in h:
		img.set_pixel(w - 1, y, Color(0.6, 0.55, 0.46))
	var pencil := Color(0.2, 0.19, 0.22)
	var row_h := 7
	for i in marks:
		var group := i / 5
		var k := i % 5
		var gx := 1
		var gy := 2 + (group) * (row_h - 1)
		if gy + row_h > h - 1:
			break
		if k < 4:
			var x := gx + 1 + k * 2
			for y in range(gy, gy + row_h - 2):
				img.set_pixel(x, y, pencil)
		else:
			# The fifth across the four, a slant.
			for j in 9:
				var x2 := gx + j
				var y2 := gy + row_h - 3 - int(float(j) * 0.55)
				if x2 < w - 1 and y2 >= 0:
					img.set_pixel(x2, y2, pencil)
	var tex := ImageTexture.create_from_image(img)
	_slips[marks] = tex
	return tex


## A bill's checklist: what it comes to, and the click that settles it.
func checklist(t: Dictionary) -> Array:
	if str(t.get("kind", "")) == "bill":
		return [{"text": "TAB $%d" % PUB.to_pay(t), "state": "todo"}, {"text": "CLICK THE BILL", "state": "todo"}]
	return [{"text": PUB.label(str(t.get("drink", ""))), "state": "todo"}]


static func ORDERS_first(full: String) -> String:
	var p := full.split(" ")
	return p[0] if p.size() > 0 else full


## The order shown big: the picked one, else the first this station pours, else the
## oldest bill.
func big_ticket() -> Dictionary:
	for t in tickets():
		if str(t["id"]) == picked:
			return _with_patience(t)
	for b in bills():
		if str(b["id"]) == picked:
			return _with_patience(b)
	var mine := orders_here(serves_kind())
	if not mine.is_empty():
		return _with_patience(mine[0])
	var bl := bills()
	return _with_patience(bl[0]) if not bl.is_empty() else {}


## What this station pours: "tap", "bar" ("" the washer and the keg: nothing).
func serves_kind() -> String:
	return ""


## A bill waiting, or orders of this station's kind: amber.
func alert() -> int:
	if serves_kind() == "":
		return 0
	return 1 if not orders_here(serves_kind()).is_empty() or (serves_kind() == "tap" and not bills().is_empty()) else 0


## The mugs and the keg on the bar.
func bar_text() -> String:
	if taproom == null or building_key == "":
		return ""
	var m: Dictionary = taproom.mugs(building_key)
	var k: Dictionary = taproom.keg(building_key)
	# Each piece through the lookup (a line put together is never found whole).
	var text := tr("MUGS %d") % int(m["clean"])
	if int(m["dirty"]) > 0:
		text += "  " + tr("DIRTY %d") % int(m["dirty"])
	var trouble: String = taproom.tap_trouble(building_key)
	text += "   " + tr("KEG %s") % tr(str({"dry": "NO BEER", "empty": "SPENT", "off": "HEAD OFF"}.get(trouble, "%d" % int(k["line"]))))
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
