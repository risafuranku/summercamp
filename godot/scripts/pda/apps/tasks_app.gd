extends "res://scripts/pda/apps/pda_app.gd"

## Tasks (Richard 24. 11.: what the TAB screen's column said): Vera's checklist in the story
## camp, tonight's or today's jobs, what waits in the camp and where (the plan's marks:
## scripts/ui/camp_plan.gd), who is at the gate and who is on the way. A page at a time.

const PLAN := preload("res://scripts/ui/camp_plan.gd")

var _page := 0
var _lines: Array = []


func opened() -> void:
	_page = 0


## [[text, heading?], ...] read off the HUD's checklist and the camp.
func _collect() -> Array:
	var out: Array = []
	var hud = os.main.get("_hud_manager") if os.main != null else null
	if hud != null:
		var obj: Dictionary = hud.get("_objective") if hud.get("_objective") is Dictionary else {}
		if not obj.is_empty():
			out.append([os.tr(str(obj.get("title", "Vera's checklist"))).to_upper(), true])
			for k in ["text", "hint"]:
				var s := str(obj.get(k, ""))
				if s != "":
					out.append([os.tr(s), false])
			var prog := str(obj.get("progress", ""))
			if prog != "":
				out.append([os.tr(prog), false])
		var jobs: Array = hud.get("_jobs") if hud.get("_jobs") is Array else []
		if not jobs.is_empty():
			out.append([os.tr(str(hud.get("_jobs_heading"))).to_upper(), true])
			for row in jobs:
				out.append([_row_text(row), false])
	var data: Dictionary = PLAN.collect(os.main)
	var todo: Array = data.get("todo", [])
	if not todo.is_empty():
		out.append([os.tr("In the camp").to_upper(), true])
		for t in todo:
			out.append([str(t), false])
	var waiting := int(data.get("waiting", 0))
	var coming := int(data.get("coming", 0))
	if waiting > 0 or coming > 0:
		out.append([os.tr("Guests").to_upper(), true])
		if waiting > 0:
			out.append([os.tr("At the gate: %d") % waiting, false])
		if coming > 0:
			out.append([os.tr("On the way: %d") % coming, false])
	return out


func _row_text(row) -> String:
	if row is Dictionary:
		var t: String = os.tr(str(row.get("title", row.get("text", ""))))
		var w := str(row.get("where", ""))
		return t if w == "" else "%s - %s" % [t, os.tr(w)]
	return os.tr(str(row))


func draw(r: Rect2) -> void:
	_lines = _collect()
	if _lines.is_empty():
		os.text_c(Rect2(r.position.x, r.position.y + 20, r.size.x, 10), os.tr("Nothing waits for you."), os.mid())
		return
	var pages := _pages(r)
	_page = clampi(_page, 0, pages.size() - 1)
	var y := r.position.y + 3
	for item in pages[_page]:
		var heading: bool = item[1]
		if heading:
			if y > r.position.y + 3:
				y += 2
			os.text(r.position.x + 2, y, os.clip(str(item[0]), r.size.x - 4))
			os.hline(r.position.x + 2, r.end.x - 2, y + 9)
			y += 12
			continue
		var lines: Array = os.wrap(str(item[0]), r.size.x - 10)
		os.frame(Rect2(r.position.x + 2, y + 2, 5, 5))
		for l in lines:
			os.text(r.position.x + 9, y, str(l))
			y += 9
		y += 2
	if pages.size() > 1:
		var by := r.end.y - 13
		os.button(Rect2(r.position.x + 2, by, 18, 11), "<", "prev", _page > 0)
		os.button(Rect2(r.end.x - 20, by, 18, 11), ">", "next", _page < pages.size() - 1)
		os.text_c(Rect2(r.position.x + 20, by + 1, r.size.x - 40, 10), "%d/%d" % [_page + 1, pages.size()], os.mid())


func _pages(r: Rect2) -> Array:
	var out: Array = []
	var cur: Array = []
	var used := 0.0
	var room := r.size.y - 18.0
	for item in _lines:
		var hgt := 14.0 if bool(item[1]) else 9.0 * float(os.wrap(str(item[0]), r.size.x - 10).size()) + 2.0
		if not cur.is_empty() and used + hgt > room:
			out.append(cur)
			cur = []
			used = 0.0
		cur.append(item)
		used += hgt
	if not cur.is_empty():
		out.append(cur)
	return out


func press(id: String) -> void:
	if id == "prev":
		_page -= 1
	elif id == "next":
		_page += 1
