extends "res://scripts/closeup/closeup_view.gd"

## The timetable in its case on the bus stop pole, close up (like the noticeboard in the
## office): a ČSAD sheet for line 380 the way they hung at Czech stops (the PID ones the
## playtest photographed): the line's number in a black box, the stop and where it goes,
## down the left the stops on the way with the minutes to each (x: on request), on the
## right the hours in their dark column with the minutes past for weekdays and for the
## weekend, the small print under. The times straight from scripts/town/bus_timetable.gd,
## so what you read is what runs. The camp's sheet, Lesna's and the one at Podlesi (both
## ways) differ; somebody has ringed the last bus in red marker. The strip under says it
## in English.

const TIMES = preload("res://scripts/town/bus_timetable.gd")
const PIC := "res://assets/textury/town/closeup_timetable.png"
const SFX_TAP := "res://assets/sfx/rednecksfx/rrtick.wav"
## Where the sheet is in the picture (px).
const PAPER := Rect2(70, 54, 178, 136)
const INK := Color(0.08, 0.08, 0.12)
const INK_RED := Color(0.78, 0.1, 0.08)
const PAPER_COL := Color(0.92, 0.91, 0.86)
## Rows of the hour table, px apart (Tiny5's figures are 5 px).
const ROW := 6.0

## "camp", "town" or "hamlet": which stop's sheet.
var stop := "camp"
## Callable() -> float: the hour now (for the watch line).
var hour_provider: Callable


func _ready() -> void:
	super._ready()
	picture = load(PIC) if ResourceLoader.exists(PIC) else null


func _opened() -> void:
	play(SFX_TAP, -12.0)
	var h := float(hour_provider.call()) if hour_provider.is_valid() else 12.0
	var sh := _sheet()
	var said: Array = []
	for col in sh["cols"]:
		if str(col["en"]) == "":
			continue
		var times: Array = []
		for t in col["times"]:
			times.append(TIMES.hm(float(t)))
		said.append("%s %s" % [col["en"], ", ".join(times)])
	if sh.has("also"):
		said.append(str(sh["also"]))
	say("", "Your watch: %s. Line 380 %s." % [TIMES.hm(h), "; ".join(said)], false)


func _hotspots() -> Array:
	return []


## This stop's sheet: its name, where it goes, the minute columns ({head: two lines,
## en, times}), the stops ([minutes or -1 already passed, name, on request]) and the
## small print.
func _sheet() -> Dictionary:
	var to_prist := roundi(TIMES.TO_PRISTOUPIM * 60.0)
	var down_prist := roundi(TIMES.FROM_LIBLICE_PRISTOUPIM * 60.0)
	var ride := roundi(TIMES.RIDE_HOURS * 60.0)
	var on := roundi(TIMES.ON_TO_LSTIBOR * 60.0)
	var small := ["x - na znamení", "Jízdenku z automatu", "označte po nástupu.", "Doplňkový prodej", "u řidiče s přirážkou."]
	match stop:
		"hamlet":
			return {"name": "Přistoupim, rozc.", "towards": "oba směry",
				"cols": [{"head": ["směr", "Liblice"], "en": "to Liblice", "times": TIMES.hamlet_to_town()},
					{"head": ["směr", "kemp"], "en": "to the camp", "times": TIMES.hamlet_to_camp()}],
				"stops": [[ride - down_prist, "Černé jezero,kemp", false], [0, "Přistoupim,rozc.", true], [ride - to_prist, "Liblice", false],
					[ride - to_prist + on, "Lstiboř", false]],
				"notes": ["Zastavuje jen na", "znamení. Stůjte u", "sloupku, ať vás řidič", "vidí."]}
		"town":
			return {"name": "Liblice", "towards": "Černé jezero, kemp",
				"cols": [{"head": ["Pracovní", "dny"], "en": "to the camp", "times": TIMES.TOWN_LEAVE},
					{"head": ["Sobota,", "neděle"], "en": "", "times": TIMES.TOWN_LEAVE}],
				"stops": [[-1, "Lstiboř", false], [0, "Liblice", false], [down_prist, "Přistoupim,rozc.", true],
					[ride, "Černé jezero,kemp", false]],
				"notes": small + ["Směr Lstiboř:"] + _pairs(TIMES.TOWN_THROUGH),
				"also": "to Lstibor %s" % ", ".join(TIMES.TOWN_THROUGH.map(func(t): return TIMES.hm(float(t))))}
	return {"name": "Černé jezero, kemp", "towards": "Přistoupim, Liblice",
		"cols": [{"head": ["Pracovní", "dny"], "en": "to Liblice", "times": TIMES.CAMP_LEAVE},
			{"head": ["Sobota,", "neděle"], "en": "", "times": TIMES.CAMP_LEAVE}],
		"stops": [[0, "Černé jezero,kemp", false], [to_prist, "Přistoupim,rozc.", true], [ride, "Liblice", false],
			[ride + on, "Lstiboř", false]],
		"notes": small + ["Spoj %s zde nestaví." % TIMES.hm(TIMES.WORKS_TOWN)],
		"scrawl": "NEMÁVAT!"}


## Times two to a line ("6:17  10:22"), for the narrow small print.
func _pairs(times: Array) -> Array:
	var out: Array = []
	for i in range(0, times.size(), 2):
		var line := TIMES.hm(float(times[i]))
		if i + 1 < times.size():
			line += "  " + TIMES.hm(float(times[i + 1]))
		out.append(line)
	return out


func _paint(c: Control) -> void:
	if picture == null:
		# No picture: a grey case and a white sheet.
		c.draw_rect(Rect2(0, 0, W, PIC_H), Color(0.18, 0.2, 0.18))
		c.draw_rect(PAPER.grow(10), Color(0.5, 0.52, 0.5))
		c.draw_rect(PAPER.grow(6), Color(0.28, 0.29, 0.28))
		c.draw_rect(PAPER, Color(0.9, 0.89, 0.84))
	var sh := _sheet()
	var f: Font = RETRO_UI.FONT_TEXT
	var x0 := PAPER.position.x + 3.0
	var y0 := PAPER.position.y + 2.0
	var right := PAPER.end.x - 3.0
	# The head: the line in its black box, the stop, where it goes; the carrier and the
	# date it holds from on the right.
	c.draw_rect(Rect2(x0, y0, 25, 13), INK)
	ink(c, RETRO_UI.FONT_BIG, Vector2(x0 + 3.0, y0 + 11.0), "380", PAPER_COL, Color(0, 0, 0, 0), 10)
	ink(c, f, Vector2(x0 + 29.0, y0 + 6.0), str(sh["name"]), INK)
	ink(c, f, Vector2(x0 + 29.0, y0 + 13.0), "směr: " + str(sh["towards"]), Color(INK, 0.8))
	_ink_right(c, f, right, y0 + 6.0, "ČSAD KOLÍN", Color(INK, 0.75))
	c.draw_rect(Rect2(x0, y0 + 15.0, right - x0, 1.0), INK)
	# Down the left: the stops with the minutes to them, this one marked, the ones behind
	# greyed; then the small print.
	var y := y0 + 23.0
	for s in sh["stops"]:
		var mins := int(s[0])
		var here := mins == 0
		var col := Color(INK, 0.4) if mins < 0 else INK
		if here:
			c.draw_colored_polygon(PackedVector2Array([Vector2(x0, y - 5.0), Vector2(x0 + 4.0, y - 2.5), Vector2(x0, y)]), INK)
		elif mins > 0:
			_ink_right(c, f, x0 + 11.0, y, str(mins), col)
		ink(c, f, Vector2(x0 + 14.0, y), str(s[1]) + (" x" if bool(s[2]) else ""), col)
		y += 7.0
	y += 3.0
	for line in sh["notes"]:
		ink(c, f, Vector2(x0, y), str(line), Color(INK, 0.85))
		y += 6.0
	if sh.has("scrawl"):
		# Somebody's biro under the works bus line.
		ink(c, f, Vector2(x0 + 30.0, y + 1.0), str(sh["scrawl"]), Color(0.16, 0.2, 0.62))
	ink(c, f, Vector2(x0, PAPER.end.y - 3.0), "platí od 31.5.1998", Color(INK, 0.6))
	# The hour table: the hours in their dark column, the minutes past for each column.
	var xt := x0 + 82.0
	c.draw_rect(Rect2(xt - 3.0, y0 + 17.0, 1.0, PAPER.end.y - y0 - 19.0), Color(INK, 0.5))
	var cols: Array = sh["cols"]
	var cw := (right - xt - 12.0) / float(cols.size())
	for i in cols.size():
		var head: Array = cols[i]["head"]
		var cx := xt + 12.0 + cw * float(i)
		ink(c, f, Vector2(cx + 1.0, y0 + 23.0), str(head[0]), INK)
		ink(c, f, Vector2(cx + 1.0, y0 + 29.0), str(head[1]), INK)
	ink(c, f, Vector2(xt, y0 + 29.0), "hod", Color(INK, 0.7))
	var first := 24
	var last := 0
	for col in cols:
		for t in col["times"]:
			first = mini(first, int(floorf(float(t))))
			last = maxi(last, int(floorf(float(t))))
	var ring_at := Vector2(-1, -1)
	var ry := y0 + 38.0
	# As roomy as the paper lets the rows be.
	var row := clampf(floorf((PAPER.end.y - 3.0 - ry) / float(maxi(1, last - first))), ROW, 7.0)
	c.draw_rect(Rect2(xt, ry - row - 1.0, right - xt, 1.0), INK)
	for hr in range(first, last + 1):
		if (hr - first) % 2 == 1:
			c.draw_rect(Rect2(xt + 11.0, ry - row, right - xt - 11.0, row), Color(INK, 0.07))
		c.draw_rect(Rect2(xt, ry - row, 10.0, row), Color(INK, 0.86))
		_ink_right(c, f, xt + 9.0, ry, str(hr), PAPER_COL)
		for i in cols.size():
			var mx := xt + 13.0 + cw * float(i)
			var times: Array = cols[i]["times"]
			for k in times.size():
				var t := float(times[k])
				if int(floorf(t)) != hr:
					continue
				var mm := "%02d" % (int(roundf(t * 60.0)) % 60)
				ink(c, f, Vector2(mx, ry), mm, INK)
				if i == 0 and k == times.size() - 1:
					ring_at = Vector2(mx + 4.0, ry - 2.5)
				mx += 10.0
		ry += row
	c.draw_rect(Rect2(xt, ry - row, right - xt, 1.0), Color(INK, 0.5))
	# The last bus, ringed by hand in red marker (a little wobbly).
	if ring_at.x > 0.0:
		var pts := PackedVector2Array()
		for k in 15:
			var a := TAU * float(k) / 14.0
			pts.append(ring_at + Vector2(cos(a) * 8.0, sin(a) * 5.0) + Vector2(sin(a * 3.0) * 1.0, cos(a * 2.0) * 0.7))
		c.draw_polyline(pts, INK_RED, 1.0)


func _ink_right(c: Control, f: Font, x: float, y: float, text: String, col: Color) -> void:
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	ink(c, f, Vector2(x - tw, y), text, col)
