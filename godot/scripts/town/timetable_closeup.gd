extends "res://scripts/closeup/closeup_view.gd"

## The timetable in its case on the bus stop pole, close up (like the noticeboard in the
## office): a CSAD sheet for line 380, typed, the times straight from
## scripts/town/bus_timetable.gd, so what you read is what runs. The camp stop's sheet
## and the one in Lesna differ; somebody has ringed the last bus in red marker.

const TIMES = preload("res://scripts/town/bus_timetable.gd")
const PIC := "res://assets/textury/town/closeup_timetable.png"
const SFX_TAP := "res://assets/sfx/rednecksfx/rrtick.wav"
## Where the sheet is in the picture (px).
const PAPER := Rect2(70, 54, 178, 136)
const INK := Color(0.08, 0.08, 0.12)
const INK_RED := Color(0.78, 0.1, 0.08)

## "camp" or "town": which stop's sheet.
var stop := "camp"
## Callable() -> float: the hour now (for the watch line).
var hour_provider: Callable


func _ready() -> void:
	super._ready()
	picture = load(PIC) if ResourceLoader.exists(PIC) else null


func _opened() -> void:
	play(SFX_TAP, -12.0)
	var h := float(hour_provider.call()) if hour_provider.is_valid() else 12.0
	say("", "Your watch: %s." % TIMES.hm(h), false)


func _hotspots() -> Array:
	return []


func _paint(c: Control) -> void:
	if picture == null:
		# No picture: a grey case and a white sheet.
		c.draw_rect(Rect2(0, 0, W, PIC_H), Color(0.18, 0.2, 0.18))
		c.draw_rect(PAPER.grow(10), Color(0.5, 0.52, 0.5))
		c.draw_rect(PAPER.grow(6), Color(0.28, 0.29, 0.28))
		c.draw_rect(PAPER, Color(0.9, 0.89, 0.84))
	var f: Font = RETRO_UI.FONT_TEXT
	var x0 := PAPER.position.x + 6.0
	var y := PAPER.position.y + 9.0
	var cols := [x0 + 92.0, x0 + 120.0, x0 + 148.0]
	ink(c, RETRO_UI.FONT_LABEL, Vector2(x0, y), "CSAD JIHLAVA a.s.", INK)
	ink(c, RETRO_UI.FONT_BIG, Vector2(PAPER.end.x - 22.0, y + 1.0), "380", INK, Color(0, 0, 0, 0), 10)
	y += 8.0
	ink(c, f, Vector2(x0, y), "Hlubocany - Lesna - Cerne jezero, kemp", INK)
	y += 4.0
	_rule(c, y)
	y += 9.0
	var ring_at := Vector2(-1, -1)
	for r in _rows():
		var row: Array = r
		if row.is_empty():
			_rule(c, y - 5.0)
			y += 5.0
			continue
		var bold := str(row[0]).begins_with("*")
		var label := str(row[0]).trim_prefix("*")
		ink(c, f, Vector2(x0 + (5.0 if bold else 0.0), y), label, INK)
		if bold:
			# This stop's own departures: a printed arrow.
			c.draw_colored_polygon(PackedVector2Array([Vector2(x0, y - 5.0), Vector2(x0 + 3.0, y - 2.5), Vector2(x0, y)]), INK)
		for i in mini(3, row.size() - 1):
			var t := str(row[i + 1])
			var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
			ink(c, f, Vector2(float(cols[i]) + 20.0 - tw, y), t, INK)
			if bold and i == 2:
				ring_at = Vector2(float(cols[i]) + 20.0 - tw * 0.5, y - 3.0)
		y += 8.0
	_rule(c, y - 4.0)
	y += 5.0
	for line in _notes():
		ink(c, f, Vector2(x0, y), str(line), INK)
		y += 7.0
	ink(c, f, Vector2(x0, PAPER.end.y - 5.0), "valid from 31.5.1998", Color(INK, 0.7))
	# The last bus, ringed by hand in red marker (a little wobbly).
	if ring_at.x > 0.0:
		var pts := PackedVector2Array()
		for k in 15:
			var a := TAU * float(k) / 14.0
			pts.append(ring_at + Vector2(cos(a) * 13.0, sin(a) * 6.0) + Vector2(sin(a * 3.0) * 1.2, cos(a * 2.0) * 0.8))
		c.draw_polyline(pts, INK_RED, 1.0)


func _rule(c: Control, y: float) -> void:
	c.draw_rect(Rect2(PAPER.position.x + 6.0, y, PAPER.size.x - 12.0, 1.0), Color(INK, 0.6))


## The table: a label then three times; "" rows draw a rule; a "*" label is this stop's.
func _rows() -> Array:
	if stop == "town":
		return [
			["*to Cerne jezero, kemp", TIMES.hm(TIMES.TOWN_LEAVE[0]), TIMES.hm(TIMES.TOWN_LEAVE[1]), TIMES.hm(TIMES.TOWN_LEAVE[2])],
			["  Cerne jezero, kemp", TIMES.hm(TIMES.CAMP_ARRIVE[0]), TIMES.hm(TIMES.CAMP_ARRIVE[1]), TIMES.hm(TIMES.CAMP_ARRIVE[2])],
			[],
			["to Hlubocany", TIMES.hm(TIMES.TOWN_THROUGH[0]), TIMES.hm(TIMES.TOWN_THROUGH[1]), TIMES.hm(TIMES.TOWN_THROUGH[2])],
			["  Hlubocany, bus st.", TIMES.hm(TIMES.HLUBOCANY_ARRIVE[0]), TIMES.hm(TIMES.HLUBOCANY_ARRIVE[1]), TIMES.hm(TIMES.HLUBOCANY_ARRIVE[2])],
		]
	return [
		["*to Lesna, Hlubocany", TIMES.hm(TIMES.CAMP_LEAVE[0]), TIMES.hm(TIMES.CAMP_LEAVE[1]), TIMES.hm(TIMES.CAMP_LEAVE[2])],
		["  Lesna, Jednota", TIMES.hm(TIMES.TOWN_THROUGH[0]), TIMES.hm(TIMES.TOWN_THROUGH[1]), TIMES.hm(TIMES.TOWN_THROUGH[2])],
		["  Hlubocany, bus st.", TIMES.hm(TIMES.HLUBOCANY_ARRIVE[0]), TIMES.hm(TIMES.HLUBOCANY_ARRIVE[1]), TIMES.hm(TIMES.HLUBOCANY_ARRIVE[2])],
		[],
		["from Lesna, arrives", TIMES.hm(TIMES.CAMP_ARRIVE[0]), TIMES.hm(TIMES.CAMP_ARRIVE[1]), TIMES.hm(TIMES.CAMP_ARRIVE[2])],
	]


func _notes() -> Array:
	if stop == "town":
		return ["Stop: LESNA, JEDNOTA      daily", "+ %s works bus to the dam." % TIMES.hm(TIMES.WORKS_TOWN)]
	return ["Stop: CERNE JEZERO, KEMP  daily", "+ the %s works bus does not stop" % TIMES.hm(TIMES.WORKS_TOWN), "  here. Please do not wave at it."]
