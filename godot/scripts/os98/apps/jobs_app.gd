extends "res://scripts/os98/apps/program_shelf.gd"

## Jobs: work from home at the camp computer, for pocket money (playtest 19. 10.: "a
## clicking side job"), shown as the program group their installers made. Three
## employers, each with a little program and a daily limit, so it pays for a lamp or a
## bill, never for the camp. The folder pane says only what a system would: the program,
## who made it, and how much of today's work it has had (the employers' own counters).
##   DataPunch 98   the District Office's old register, typed card by card (night work)
##   KlikBanka 98   Bohemia Online pays for every advert you confirm you have seen; the
##                  ones that are not adverts you close
##   SectiTo 98     the district counts things on aerial photographs: tents, cows, boats

const ADCLICK = preload("res://scripts/os98/apps/job_adclick.gd")
const CENSUS = preload("res://scripts/os98/apps/job_census.gd")


func _entries() -> Array:
	return [
		{"id": "datapunch", "script": "datapunch_app"},
		{"id": "adclick", "script": "job_adclick"},
		{"id": "census", "script": "job_census"},
	]


func _heading() -> Array:
	return ["Jobs", "money"]


func _card_status(id: String) -> String:
	match id:
		"datapunch":
			var dp_done := int((_shell.get_meta("datapunch_nights", {}) as Dictionary).get(_dp_night_key(), 0))
			return "Batch: %d of 24 cards" % dp_done
		"adclick":
			return "Today: $%d of $%d" % [_shell.job_done("adclick"), ADCLICK.DAY_LIMIT]
		"census":
			return "Today: %d of %d photos" % [_shell.job_done("census"), CENSUS.DAY_LIMIT]
	return ""


## DataPunch counts by its own night (datapunch_app._night_key).
func _dp_night_key() -> String:
	var day := CoreRoot.get_day() if CoreRoot != null else 1
	var m: Node = _shell.main_node()
	var h := float(m.get("_time_of_day_hours")) if m != null and m.get("_time_of_day_hours") != null else 22.0
	return str(day - (1 if h < 12.0 else 0))


func _cover_lines(id: String) -> Array:
	match id:
		"datapunch":
			return ["WORK AT HOME ON YOUR COMPUTER.", "The District Office pays $4 for every register card", "you type in, up to 24 a night. The old register of",
				"everyone who stayed by the reservoir, 1961-1989.", "", "Okresni urad Hlubocany, room 12."]
		"adclick":
			return ["EARN MONEY WITH YOUR MOUSE!", "Bohemia Online pays $1 for every advert you confirm.", "Click OK on a real advert. Close (x) what is not one:",
				"prizes, viruses, chain letters. A wrong click costs.", "", "Up to $30 a day. Paid at once."]
		"census":
			return ["THE DISTRICT COUNTS ITS PROPERTY.", "Count what the aerial photograph asks for: tents,", "cows, boats. Type the number. $3 for the right count,",
				"$1 if you are one out.", "", "Up to 12 photographs a day."]
	return []


func _cover_button(id: String) -> String:
	return "Sign up and download  (%d KB)" % int(_shell.PROGRAMS[id]["kb"])
