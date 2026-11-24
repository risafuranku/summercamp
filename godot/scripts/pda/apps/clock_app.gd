extends "res://scripts/pda/apps/pda_app.gd"

## Clock and weather (Richard 24. 11.): the time big, the day, the weather now and how long it
## holds, what comes after it when the sky already says (a storm building), and how long until
## the office's Builder shuts for the night at 20:00 (its licence: 06:30-20:00).

const INSTANCE = preload("res://scripts/instance/instance.gd")
const LOCK_MIN := 20 * 60
const OPEN_MIN := 6 * 60 + 30
const BIG: FontFile = preload("res://assets/fonts/jersey10.fnt")


func wants_tick() -> bool:
	return false


func draw(r: Rect2) -> void:
	var gm = INSTANCE.guests(os.main) if os.main != null else null
	var hour := int(gm.get("_last_known_hour")) if gm != null else 0
	var minute := int(gm.get("_last_known_minute")) if gm != null else 0
	var day := int(gm.get("_last_known_day")) if gm != null else 1
	# The time, twice the big font's size.
	var t := "%02d:%02d" % [hour, minute]
	var tw := BIG.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	os.draw_string(BIG, Vector2(r.position.x + floorf((r.size.x - tw) * 0.5), r.position.y + 24), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, os.ink())
	os.text_c(Rect2(r.position.x, r.position.y + 28, r.size.x, 9), os.tr("Day %d") % day)
	os.hline(r.position.x + 4, r.end.x - 4, r.position.y + 40, os.mid())
	var y := r.position.y + 44
	# The weather.
	var ws = os.main.get("weather_system") if os.main != null else null
	if ws != null:
		os.text(r.position.x + 3, y, os.tr("Now:"), os.mid())
		y += 9
		# ("Clear" alone is the Czech "Vymazat" elsewhere: the sky's own word.)
		var wn := str(ws.get_weather_name())
		os.text(r.position.x + 3, y, os.clip(os.tr("Clear skies" if wn == "Clear" else wn), r.size.x - 6))
		y += 9
		var left := int(ws.get_minutes_left())
		os.text(r.position.x + 3, y, os.clip(os.tr("For about %s") % _span(left), r.size.x - 6), os.mid())
		y += 12
		var up := int(ws.get("upcoming")) if ws.get("upcoming") != null else -1
		if up >= 0:
			os.text(r.position.x + 3, y, os.tr("Then:"), os.mid())
			y += 9
			os.text(r.position.x + 3, y, os.clip(os.tr(_weather_word(up)), r.size.x - 6))
			y += 12
	os.hline(r.position.x + 4, r.end.x - 4, y, os.mid())
	y += 4
	# The office's Builder.
	var now := hour * 60 + minute
	os.text(r.position.x + 3, y, os.tr("Builder 98:"), os.mid())
	y += 9
	if now >= OPEN_MIN and now < LOCK_MIN:
		os.text(r.position.x + 3, y, os.clip(os.tr("Shuts in %s") % _span(LOCK_MIN - now), r.size.x - 6))
	else:
		var to_open := (OPEN_MIN - now + 1440) % 1440
		os.text(r.position.x + 3, y, os.clip(os.tr("Opens in %s") % _span(to_open), r.size.x - 6))


## "2 h 05" / "35 min".
func _span(minutes: int) -> String:
	minutes = maxi(0, minutes)
	if minutes < 60:
		return "%d min" % minutes
	return "%d h %02d" % [minutes / 60, minutes % 60]


func _weather_word(state: int) -> String:
	return ["Clear skies", "Windy", "Fog", "Drizzle", "Rain", "Storm", "Anomaly"][clampi(state, 0, 6)]
