extends "res://scripts/pda/apps/pda_app.gd"

## The camp's plan on the PDA (Richard 24. 11.: instead of the TAB map): drawn as you see the
## camp walking in through the gate (the gate at the bottom), on the STN glass: the lake
## hatched, the woods dotted, the paths, every building a box. What needs you blinks: a
## breakdown, tonight's jobs, today's events, guests waiting at the gate or for an order. The
## stylus on a place writes what it is and how it stands on the line at the bottom. It does
## not show where you are (scripts/ui/camp_plan.gd reads the camp; once a second while open).

const PLAN := preload("res://scripts/ui/camp_plan.gd")
## Small things drawn as a dot, not a box.
const DOTS := ["lamp_post", "bench", "flower_bed", "gnome", "flagpole", "pa_pole", "picnic_table"]

var _data: Dictionary = {}
var _age := 99.0
var _pick := ""
var _plan_r := Rect2()
var _cell := 3.0


func opened() -> void:
	_age = 99.0
	_pick = ""


func wants_tick() -> bool:
	return true


func tick(delta: float) -> void:
	_age += delta
	if _age >= 1.0:
		_age = 0.0
		_data = PLAN.collect(os.main)


func draw(r: Rect2) -> void:
	if _data.is_empty():
		_data = PLAN.collect(os.main)
	if _data.is_empty():
		return
	var w := int(_data["w"])
	var h := int(_data["h"])
	var info_h := 20.0
	var avail := Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2 + info_h))
	_cell = maxf(1.0, floorf(minf(avail.size.x / float(w), avail.size.y / float(h))))
	var size := Vector2(w, h) * _cell
	_plan_r = Rect2((avail.position + (avail.size - size) * 0.5).floor(), size)
	os.frame(_plan_r.grow(1))
	# The lake, hatched; the woods, a dot a tree.
	for c in _data["lake"]:
		var p := _at(Vector2(c))
		var cr := Rect2(p, Vector2(_cell, _cell))
		for yy in int(_cell):
			for xx in int(_cell):
				if (int(p.x) + xx + int(p.y) + yy) % 2 == 0:
					os.fill(Rect2(cr.position + Vector2(xx, yy), Vector2.ONE), os.mid())
	for c in _data["trees"]:
		var p2 := _at(Vector2(c)) + Vector2(floorf(_cell * 0.5), floorf(_cell * 0.5))
		os.fill(Rect2(p2, Vector2.ONE), os.mid())
	for c in (_data["paths"] as Dictionary).keys():
		var p3 := _at(Vector2(c))
		os.fill(Rect2(p3 + Vector2(1, 1), Vector2(maxf(1.0, _cell - 2.0), maxf(1.0, _cell - 2.0))), os.mid())
	var marks := _marks()
	for b in _data["buildings"]:
		var t := str(b["type"])
		if t.begins_with("tree_"):
			continue
		var at: Vector2i = b["at"]
		var fp: Vector2i = b["fp"]
		var br := _rect(at, fp)
		var key := "%d:%d" % [at.x, at.y]
		var wanted := marks.has(key) or (_data["broken"] as Dictionary).has(key)
		if DOTS.has(t):
			os.fill(Rect2(br.get_center().floor() - Vector2(1, 1), Vector2(2, 2)))
			continue
		if wanted and os.blink():
			os.fill(br)
		else:
			os.frame(br)
			# A lodging: guests in, its middle filled; to clean or make up, a dot.
			var rs: Dictionary = (_data["rooms"] as Dictionary).get(key, {})
			if not rs.is_empty() and br.size.x > 4.0:
				if bool(rs.get("occupied", false)):
					os.fill(br.grow(-2))
				elif str(rs.get("status", "")) != "ready":
					os.fill(Rect2(br.get_center().floor() - Vector2(1, 1), Vector2(2, 2)))
		if _pick == key:
			os.frame(br.grow(2))
	# Marks with no building under them (the gate's guests, a job out in the open).
	for k in marks.keys():
		var c2: Vector2i = marks[k]
		if os.blink():
			os.fill(Rect2(_at(Vector2(c2)) - Vector2(1, 1), Vector2(_cell + 2, _cell + 2)))
	# The gate.
	var g: Vector2i = _data["gate"]
	var gp := _at(Vector2(g))
	os.text(gp.x - 1, minf(_plan_r.end.y - 2, gp.y + _cell), "v")
	_draw_info(Rect2(r.position.x, r.end.y - info_h, r.size.x, info_h))


## Cells that need you (jobs, events, waiting) -> their coord, by "x:y".
func _marks() -> Dictionary:
	var out := {}
	for j in _data["jobs"]:
		var c = j.get("coord", null)
		if c is Array and (c as Array).size() >= 2:
			var v := Vector2i(int(c[0]), int(c[1]))
			out["%d:%d" % [v.x, v.y]] = v
		elif c is Vector2i:
			out["%d:%d" % [c.x, c.y]] = c
	if int(_data.get("waiting", 0)) > 0:
		var g: Vector2i = _data["gate"]
		out["%d:%d" % [g.x, g.y]] = g
	return out


## A grid cell's top left on the screen.
func _at(c: Vector2) -> Vector2:
	var p: Vector2 = PLAN.to_plan(c + Vector2.ONE, int(_data["w"]), int(_data["h"]))
	return (_plan_r.position + p * _cell).floor()


func _rect(at: Vector2i, fp: Vector2i) -> Rect2:
	var a := _at(Vector2(at))
	var b := _at(Vector2(at + fp - Vector2i.ONE))
	var tl := Vector2(minf(a.x, b.x), minf(a.y, b.y))
	var br := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(_cell, _cell)
	return Rect2(tl, br - tl)


func _draw_info(r: Rect2) -> void:
	os.hline(r.position.x, r.end.x, r.position.y, os.mid())
	var line1 := ""
	var line2 := ""
	if _pick == "":
		var waiting := int(_data.get("waiting", 0))
		line1 = os.tr("Tap a place.")
		if waiting > 0:
			line2 = os.tr("At the gate: %d") % waiting
	else:
		var parts := _pick.split(":")
		var c := Vector2i(int(parts[0]), int(parts[1]))
		var t := ""
		for b in _data["buildings"]:
			if b["at"] == c:
				t = str(b["type"])
		line1 = os.tr(PLAN.place_name(t))
		if (_data["broken"] as Dictionary).has(_pick):
			line2 = os.tr("Broken down")
		else:
			for j in _data["jobs"]:
				var jc = j.get("coord", null)
				if (jc is Array and (jc as Array).size() >= 2 and Vector2i(int(jc[0]), int(jc[1])) == c) or (jc is Vector2i and jc == c):
					line2 = os.tr(str(j.get("title", "")))
					break
			if line2 == "":
				var rs: Dictionary = (_data["rooms"] as Dictionary).get(_pick, {})
				if not rs.is_empty():
					line1 = os.tr(str(rs.get("label", line1)))
					if bool(rs.get("occupied", false)):
						line2 = os.tr("Guests in")
					else:
						line2 = os.tr({"dirty": "To clean", "unprepared": "Not made up"}.get(str(rs.get("status", "")), "Ready to let"))
	os.text(r.position.x + 2, r.position.y + 2, os.clip(line1, r.size.x - 4))
	os.text(r.position.x + 2, r.position.y + 11, os.clip(line2, r.size.x - 4), os.mid())


func tap(p: Vector2) -> void:
	if not _plan_r.has_point(p) or _data.is_empty():
		return
	_pick = ""
	var best := INF
	for b in _data["buildings"]:
		if str(b["type"]).begins_with("tree_"):
			continue
		var br := _rect(b["at"], b["fp"]).grow(1)
		if br.has_point(p):
			var d := br.get_center().distance_to(p)
			if d < best:
				best = d
				_pick = "%d:%d" % [(b["at"] as Vector2i).x, (b["at"] as Vector2i).y]
	os.queue_redraw()
