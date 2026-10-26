extends "res://scripts/closeup/closeup_view.gd"

## The shift's end (DESIGN.md §7b, Papa's results at the end of a day): the till prints
## its Z report, a long thermal receipt, in the game's look. It comes out when the place
## shuts (business_runtime.zreport) if you are in it, else it lies by the till / the books
## till you read it. What it says: the orders and their average score, the tips, the best
## and the worst order, what went away unserved, what was thrown out, the wages tonight,
## the takings, the goods used and the wages, and the stars for the shift; beside it the
## manager's note in pencil: the shift's mark (A to E, business_rules.day_grade) and the
## one thing to mend first.
## The picture is the dark counter (assets/textury/closeup/ledger.png darkened) with the
## receipt drawn over it: thermal paper, purple-grey ink, torn at the top.

const RULES := preload("res://core/systems/business_rules.gd")
const LANG := preload("res://scripts/lang.gd")
const SFX_PRINT := "res://assets/sfx/bistro/till.mp3"
const PAPER := Color(0.93, 0.92, 0.86)
const INK := Color(0.32, 0.27, 0.42)
const FADED := Color(0.52, 0.48, 0.58)
const RECEIPT := Rect2(84, 0, 104, 240)
## The manager's note in pencil beside the receipt.
const NOTE := Rect2(200, 26, 108, 120)

var building_key := ""
var report: Dictionary = {}
var _feed := 0.0


func _ready() -> void:
	super._ready()
	var p := "res://assets/textury/closeup/ledger.png"
	picture = load(p) if ResourceLoader.exists(p) else null


func open_report(key: String, z: Dictionary) -> void:
	building_key = key
	report = z
	_feed = 0.0
	open_view()


func _opened() -> void:
	play(SFX_PRINT, -10.0)
	var n := int(report.get("orders", 0))
	if n <= 0:
		say("", "Nothing rang through the till.")
	else:
		var avg := int(round(float(report.get("score", 0)) / float(n)))
		say("", ["A quiet shift.", "That was a shift.", "The till is warm."][clampi(n / 8, 0, 2)] if avg >= 60 else "The till prints slowly, as if it did not want to.")
	if CoreRoot != null and CoreRoot.get_state() != null:
		var site: Dictionary = (CoreRoot.get_state().biz.get("sites", {}) as Dictionary).get(building_key, {})
		if not site.is_empty():
			site["zreport_read"] = true


func _tick(delta: float) -> void:
	_feed = minf(1.0, _feed + delta * 1.6)


func _hotspots() -> Array:
	return []


func _paint(c: Control) -> void:
	# The counter in the dark under the receipt.
	c.draw_rect(Rect2(0, 0, W, PIC_H), Color(0, 0, 0, 0.55))
	# The receipt feeds out of the top in steps, the paper torn at its top edge.
	var shown := floorf(_feed * 8.0) / 8.0
	var r := Rect2(RECEIPT.position.x, RECEIPT.position.y, RECEIPT.size.x, RECEIPT.size.y * shown)
	c.draw_rect(r, PAPER)
	for x in range(int(r.position.x), int(r.end.x), 4):
		c.draw_rect(Rect2(x, r.end.y - 2 + ((x / 4) % 2), 4, 2), Color(0, 0, 0, 0.55))
	c.draw_rect(Rect2(r.position.x + r.size.x, r.position.y, 2, r.size.y), Color(0, 0, 0, 0.3))
	var lines := _lines()
	var y := 12.0
	for l in lines:
		if y > r.end.y - 6:
			break
		var text := str(l[0])
		var col: Color = l[1] if l.size() > 1 else INK
		var big: bool = l.size() > 2 and bool(l[2])
		var f: Font = RETRO_UI.FONT_BIG if big else RETRO_UI.FONT_TEXT
		var size := 10 if big else 8
		if text.contains("\t"):
			var parts := text.split("\t")
			c.draw_string(f, Vector2(r.position.x + 6, y), parts[0], HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
			var w := f.get_string_size(parts[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			c.draw_string(f, Vector2(r.end.x - 6 - w, y), parts[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		else:
			var w2 := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			c.draw_string(f, Vector2(floorf(r.position.x + (r.size.x - w2) * 0.5), y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		y += 12.0 if big else 8.5
	_paint_note(c)


func _lines() -> Array:
	var z := report
	var kind := str(z.get("kind", ""))
	var name := tr(str((RULES.KINDS.get(kind, {}) as Dictionary).get("name", ""))).to_upper()
	var n := int(z.get("orders", 0))
	var avg := int(round(float(z.get("score", 0)) / float(maxi(1, n))))
	var out: Array = [
		[tr("CERNE JEZERO"), INK, true],
		[(LANG.f("%s - LATE", name)) if bool(z.get("late", false)) else name, INK],
		[LANG.f("Z REPORT  DAY %d", int(z.get("day", 0))), FADED],
		["- - - - - - - - - -", FADED],
		[LANG.f("ORDERS\t%d", n)],
		[LANG.f("BY HANDS\t%d", int(z.get("by_hands", 0)))],
		[LANG.f("AVERAGE\t%d%%", avg)],
		[LANG.f("TIPS\t$%d", int(z.get("tips", 0)))],
		[LANG.f("WENT AWAY\t%d", int(z.get("lost", 0))), Color(0.6, 0.15, 0.2) if int(z.get("lost", 0)) > 0 else INK],
		[LANG.f("THROWN OUT\t%d", int(z.get("waste", 0))), Color(0.6, 0.15, 0.2) if int(z.get("waste", 0)) > 0 else INK],
		["- - - - - - - - - -", FADED],
	]
	var best: Dictionary = z.get("best", {})
	var worst: Dictionary = z.get("worst", {})
	if not best.is_empty():
		out.append([tr("BEST"), FADED])
		out.append(["%s\t%d%%" % [tr(str(best.get("what", ""))).substr(0, 12), int(best.get("score", 0))]])
		out.append([str(best.get("who", "")).substr(0, 16), FADED])
	if not worst.is_empty() and n > 1:
		out.append([tr("WORST"), FADED])
		out.append(["%s\t%d%%" % [tr(str(worst.get("what", ""))).substr(0, 12), int(worst.get("score", 0))]])
		out.append([str(worst.get("who", "")).substr(0, 16), FADED])
	out.append(["- - - - - - - - - -", FADED])
	var cost := int(round(float(z.get("cost", 0.0))))
	out.append([LANG.f("TAKINGS\t$%d", int(z.get("takings", 0))), INK, false])
	out.append([LANG.f("GOODS\t-$%d", cost)])
	out.append([LANG.f("WAGES\t-$%d", int(z.get("wages", 0)))])
	var net := int(z.get("takings", 0)) - cost - int(z.get("wages", 0))
	out.append([LANG.f("NET\t%s$%d", ["-" if net < 0 else "", absi(net)]), Color(0.6, 0.15, 0.2) if net < 0 else INK])
	# All the camp's places today, to set this one against.
	var all := 0
	if CoreRoot != null and CoreRoot.get_state() != null:
		var sites: Dictionary = CoreRoot.get_state().biz.get("sites", {})
		for k in sites:
			all += int(((sites[k] as Dictionary).get("today", {}) as Dictionary).get("takings", 0))
	out.append([LANG.f("ALL PLACES\t$%d", all), FADED])
	out.append(["- - - - - - - - - -", FADED])
	var stars := 1 + (1 if avg >= 65 else 0) + (1 if avg >= 88 else 0)
	if n <= 0:
		stars = 0
	out.append([("* ".repeat(stars).strip_edges() if stars > 0 else "-") + ("  %.1f" % (float(z.get("stars", 0)) / float(n)) if n > 0 and z.has("stars") else ""), INK, true])
	return out


## The shift's mark and the one thing to mend: the report's own, or worked out now.
func _mark() -> Dictionary:
	if report.has("grade"):
		return {"grade": str(report["grade"]), "advice": str(report.get("advice", ""))}
	return RULES.day_grade(report)


## The manager's note beside the receipt: the mark big in pencil, the advice under it.
func _paint_note(c: Control) -> void:
	if _feed < 1.0:
		return
	var m := _mark()
	var r := NOTE
	c.draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Color(0, 0, 0, 0.35))
	c.draw_rect(r, Color(0.86, 0.82, 0.68))
	var pencil := Color(0.24, 0.22, 0.26)
	c.draw_string(RETRO_UI.FONT_TEXT, Vector2(r.position.x + 6, r.position.y + 12), tr("MARK"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, FADED)
	var g := str(m["grade"])
	var col := Color(0.16, 0.42, 0.14) if g in ["A", "B"] else (Color(0.62, 0.12, 0.08) if g in ["D", "E"] else pencil)
	c.draw_string(RETRO_UI.FONT_BIG, Vector2(r.position.x + 6, r.position.y + 36), g, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)
	var y := r.position.y + 52
	for l in _wrap_note(tr(str(m["advice"])), r.size.x - 12):
		c.draw_string(RETRO_UI.FONT_TEXT, Vector2(r.position.x + 6, y), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, pencil)
		y += 10


func _wrap_note(text: String, width: float) -> Array:
	var out: Array = []
	var line := ""
	for word in text.split(" "):
		var cand := word if line == "" else line + " " + word
		if RETRO_UI.FONT_TEXT.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x > width and line != "":
			out.append(line)
			line = word
		else:
			line = cand
	if line != "":
		out.append(line)
	return out
