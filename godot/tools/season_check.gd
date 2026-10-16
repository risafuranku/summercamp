extends SceneTree

## Headless check of the autumn (core/systems/season.gd):
##
##   godot --headless --path godot --script res://tools/season_check.gd
##
## Asserts: day 1 is Saturday 19.9.1998, the month turns after day 12, Vera's day 31 is
## Monday 19 October; the leaves only turn and fall (never back), bare at the end; no
## snow before the first snow night, snow lying at the end; it gets colder; frosts only
## late; thunder rarer and fog likelier as it goes; the weather system turns rain into
## snow at the end; the evening light comes earlier, never the other way.

const SEASON := preload("res://core/systems/season.gd")
const WEATHER := preload("res://core/systems/weather_system.gd")


func _init() -> void:
	var f: Array[String] = []
	if SEASON.date_str(1) != "19.9.1998" or SEASON.date_long(1) != "Saturday 19 September":
		f.append("day 1 is %s (%s)" % [SEASON.date_str(1), SEASON.date_long(1)])
	if SEASON.date_str(12) != "30.9.1998" or SEASON.date_str(13) != "1.10.1998":
		f.append("the month does not turn after day 12")
	if SEASON.date_long(SEASON.RETURN_DAY) != "Monday 19 October":
		f.append("Vera's day is %s" % SEASON.date_long(SEASON.RETURN_DAY))
	if SEASON.date_str(-5) != "13.9.1998":
		f.append("days before the start: %s" % SEASON.date_str(-5))
	var last_leaves := 2.0
	var last_turn := -1.0
	var last_high := 99
	for d in range(1, SEASON.CAMPAIGN_DAYS + 1):
		var lv := SEASON.leaves_on(d)
		var tn := SEASON.leaf_turn(d)
		if lv > last_leaves + 0.0001 or tn < last_turn - 0.0001:
			f.append("the leaves go back on day %d" % d)
		last_leaves = lv
		last_turn = tn
		if SEASON.temp_high(d) > last_high:
			f.append("warmer again on day %d" % d)
		last_high = SEASON.temp_high(d)
		if d < SEASON.FIRST_SNOW_DAY and SEASON.snow_cover(d, 23.0) > 0.0:
			f.append("snow lying on day %d" % d)
		if d < 18 and SEASON.hard_frost(d):
			f.append("hard frost already on day %d" % d)
	if SEASON.leaves_on(1) < 0.99 or SEASON.leaves_on(SEASON.CAMPAIGN_DAYS) > 0.02:
		f.append("not green at the start or not bare at the end")
	if SEASON.snow_cover(SEASON.CAMPAIGN_DAYS, 20.0) < 0.6:
		f.append("no snow lying at the end")
	if not SEASON.hard_frost(SEASON.CAMPAIGN_DAYS):
		f.append("no frost at the end")
	var b0: Dictionary = SEASON.weather_bias(1)
	var b1: Dictionary = SEASON.weather_bias(SEASON.CAMPAIGN_DAYS)
	if float(b1["storm"]) >= float(b0["storm"]) or float(b1["fog"]) <= float(b0["fog"]):
		f.append("the weather does not lean toward October")
	var w = WEATHER.new()
	w.season_day = 2
	w.set_weather(WEATHER.WEATHER_RAIN)
	w.process(0.0, 22.0)
	if w.is_snowing():
		f.append("snow on day 2")
	w.season_day = SEASON.CAMPAIGN_DAYS
	w.process(0.0, 22.0)
	if not w.is_snowing() or w.get_weather_name() != "Snow":
		f.append("rain is not snow at the end (%s)" % w.get_weather_name())
	if SEASON.evening_earlier(SEASON.CAMPAIGN_DAYS) <= SEASON.evening_earlier(1):
		f.append("the evenings do not draw in")

	if f.is_empty():
		print("SEASON CHECK: PASS")
	else:
		print("SEASON CHECK: %d FAILURE(S)" % f.size())
		for x in f:
			print("  - " + x)
	quit(0 if f.is_empty() else 1)
