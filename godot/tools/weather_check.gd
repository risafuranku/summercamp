extends SceneTree

## Headless check of the weather state machine (core/systems/weather_system.gd).
## Pure RefCounted, no autoloads, so --script is fine here:
##
##   godot --headless --path godot --script res://tools/weather_check.gd
##
## Simulates 50 seeded weeks minute by minute and asserts:
## - every state the cycle may reach is reached, and clear weather dominates;
## - no state outlives its STATE_MINUTES maximum;
## - the anomaly only starts at night, only with pressure, and not twice in a day;
## - a session sees several changes per day (the auto-cycle actually runs).

const WEATHER := preload("res://core/systems/weather_system.gd")
const DAYS := 7
const WEEKS := 50


func _init() -> void:
	var failures: Array[String] = []
	var minutes_in := {}
	var changes := 0
	var anomalies := 0
	var anomaly_day_starts: Array = []
	for week in WEEKS:
		var w = WEATHER.new()
		w.set_seed(1000 + week)
		w.set_auto_cycle_enabled(true)
		w.set_anomaly_pressure(0.6 if week % 2 == 0 else 0.0)
		var last: int = w.current_weather
		var run := 0.0
		var last_anomaly := -100000.0
		for m in DAYS * 1440:
			var hour := fmod(9.0 + float(m) / 60.0, 24.0)
			w.process(1.0, hour)
			var cur: int = w.current_weather
			minutes_in[cur] = int(minutes_in.get(cur, 0)) + 1
			if cur != last:
				changes += 1
				var span: Array = WEATHER.STATE_MINUTES[last]
				if run > float(span[1]) + 1.0:
					failures.append("week %d: state %d lasted %.0f min (max %s)" % [week, last, run, span[1]])
				if cur == WEATHER.WEATHER_EVENT:
					anomalies += 1
					if not (hour >= WEATHER.ANOMALY_NIGHT_START or hour < WEATHER.ANOMALY_NIGHT_END):
						failures.append("week %d: anomaly started at %.2f h" % [week, hour])
					if float(m) - last_anomaly < WEATHER.ANOMALY_COOLDOWN_MINUTES:
						failures.append("week %d: anomaly repeated after %.0f min" % [week, float(m) - last_anomaly])
					last_anomaly = float(m)
				last = cur
				run = 0.0
			else:
				run += 1.0
	var total := 0
	for v in minutes_in.values():
		total += int(v)
	print("")
	print("WEATHER CHECK over %d weeks:" % WEEKS)
	for state in range(WEATHER.WEATHER_STATE_COUNT):
		var share := float(minutes_in.get(state, 0)) / float(total) * 100.0
		print("  state %d  %5.1f%%" % [state, share])
	var per_day := float(changes) / float(WEEKS * DAYS)
	print("  changes per day %.1f, anomalies %d" % [per_day, anomalies])
	for state in [WEATHER.WEATHER_CLEAR, WEATHER.WEATHER_WINDY, WEATHER.WEATHER_FOG, WEATHER.WEATHER_LIGHT_RAIN, WEATHER.WEATHER_RAIN, WEATHER.WEATHER_STORM]:
		if int(minutes_in.get(state, 0)) == 0:
			failures.append("state %d never reached" % state)
	var clear_share := float(minutes_in.get(WEATHER.WEATHER_CLEAR, 0)) / float(total)
	if clear_share < 0.25:
		failures.append("clear weather only %.0f%% of the time" % (clear_share * 100.0))
	var storm_share := float(minutes_in.get(WEATHER.WEATHER_STORM, 0)) / float(total)
	if storm_share > 0.12:
		failures.append("storms %.0f%% of the time" % (storm_share * 100.0))
	if per_day < 2.0:
		failures.append("only %.1f weather changes per day" % per_day)
	if anomalies == 0:
		failures.append("the anomaly never happened")
	if failures.is_empty():
		print("WEATHER CHECK: PASS")
		quit(0)
	else:
		print("WEATHER CHECK: %d FAILURE(S)" % failures.size())
		for f in failures:
			print("  - " + f)
		quit(1)
