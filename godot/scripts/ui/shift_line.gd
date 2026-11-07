extends Control

## The hands' day under the clock (the user 7. 11.: "what I miss in the HUD is a time line or a
## progress bar: when the staff come to work and when their shift ends"): 06:00 to 24:00 along
## a thin line, the day shift lit, the late shift amber, the brighter the more hands are on,
## and the tick of now going along it. No words: the picture is the clock's own. Drawn again
## only when the bands or the minute change.

const FROM := 6.0
const TO := 24.0
const SLOT := Color(0.0, 0.0, 0.0, 0.55)
const DAY := Color(0.46, 0.86, 0.36)
const LATE := Color(1.0, 0.72, 0.22)
const NOW := Color(0.93, 0.89, 0.78)

var ui_scale := 2
var _bands: Array = []
var _now := 12.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func has_bands() -> bool:
	return not _bands.is_empty()


func set_bands(bands: Array) -> void:
	if bands == _bands:
		return
	_bands = bands.duplicate(true)
	queue_redraw()


func set_now(hour: float) -> void:
	var step := floorf(hour * 12.0) / 12.0
	if is_equal_approx(step, _now):
		return
	_now = step
	queue_redraw()


func _x(hour: float) -> float:
	return floorf(clampf((hour - FROM) / (TO - FROM), 0.0, 1.0) * size.x)


func _draw() -> void:
	var u := float(maxi(1, ui_scale))
	var h := 3.0 * u
	var y := floorf((size.y - h) * 0.5)
	draw_rect(Rect2(0.0, y, size.x, h), SLOT)
	# Hour by hour how many are on: more hands, brighter.
	for i in int(TO - FROM) * 4:
		var at := FROM + float(i) * 0.25
		var day := 0
		var late := 0
		for b in _bands:
			if at >= float(b[0]) and at < float(b[1]):
				if bool(b[2]):
					late += 1
				else:
					day += 1
		if day + late <= 0:
			continue
		var col: Color = LATE if late > day else DAY
		col.a = clampf(0.55 + 0.15 * float(day + late), 0.55, 1.0)
		draw_rect(Rect2(_x(at), y, maxf(u, _x(at + 0.25) - _x(at)), h), col)
	if _now >= FROM:
		draw_rect(Rect2(_x(_now), y - u, u, h + 2.0 * u), NOW)
