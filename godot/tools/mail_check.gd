extends Node

## Headless check of the mail cadence (scripts/email_manager.gd): a simulated week of
## hourly rolls with every booking answered at once, 200 times.
##
##   godot --headless --path godot res://tools/mail_check.tscn

var _failures: Array[String] = []


func _ready() -> void:
	var em = EmailManager
	var runs := 200
	var bookings := []
	var spam := []
	bookings.resize(8)
	spam.resize(8)
	bookings.fill(0)
	spam.fill(0)
	var alarms_per_night := {}
	var day_alarms := 0
	for run in runs:
		em._false_alarm_night = -1
		for day in range(1, 8):
			for hour in 24:
				var n: int = em._roll_customer_mail_count({"capacity": 10, "free": 5}, day, hour, 0.4)
				bookings[day] += n
				if (hour < 7 or hour > 20) and n > 0:
					_failures.append("booking at %02d:00" % hour)
				if em._roll_spam(day, hour):
					spam[day] += 1
				if em._roll_night_false_alarm(day, hour):
					var night: int = day if hour >= 22 else day - 1
					var key := "%d:%d" % [run, night]
					alarms_per_night[key] = int(alarms_per_night.get(key, 0)) + 1
					if hour > 4 and hour < 22:
						day_alarms += 1
	for key in alarms_per_night:
		if int(alarms_per_night[key]) > 1:
			_failures.append("night %s had %d false alarms" % [key, alarms_per_night[key]])
			break
	if day_alarms > 0:
		_failures.append("%d false alarms in daytime" % day_alarms)
	var line := "MAIL CHECK: bookings/day"
	for day in range(1, 8):
		line += " d%d=%.1f" % [day, float(bookings[day]) / runs]
	print(line)
	print("MAIL CHECK: spam/day d1=%.1f d7=%.1f, false alarms on %.0f%% of nights" % [
		float(spam[1]) / runs, float(spam[7]) / runs, 100.0 * alarms_per_night.size() / float(runs * 6)])
	var d1 := float(bookings[1]) / runs
	var d7 := float(bookings[7]) / runs
	if d1 < 1.5 or d1 > 5.0:
		_failures.append("day 1 bookings %.1f, want a calm 2-4" % d1)
	if d7 <= d1 * 1.5:
		_failures.append("day 7 bookings %.1f do not build up from day 1 (%.1f)" % [d7, d1])
	if float(spam[7]) / runs > 3.0:
		_failures.append("too much spam on day 7")
	print("")
	if _failures.is_empty():
		print("MAIL CHECK: PASS")
		get_tree().quit(0)
	else:
		print("MAIL CHECK: %d FAILURE(S)" % _failures.size())
		for f in _failures.slice(0, 10):
			print("  - " + f)
		get_tree().quit(1)
