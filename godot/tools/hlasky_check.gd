extends "res://tools/shot_driver.gd"

## The pager's and the feed's lines in Czech (the user 4. 11.: "pager, a branch has come down
## není přeložené, zkontrolovat hlášky"): every day event's line and every night job's page as
## the game puts them together, printed as the player reads them ("HLASKY ..."), a line still
## English marked "EN". Run with --lang=cs (and --lang-audit for everything else asked for in
## Czech on the way that found none).
##   godot --path godot --audio-driver Dummy --resolution 1280x720 res://tools/hlasky_check.tscn -- --lang=cs --lang-audit --out=DIR

const C := "get_tree().root.get_node('HlaskyCheck')"
const LANG_F = preload("res://scripts/lang.gd")
const EVENTS := ["litter", "raccoons", "delivery", "lost_kid", "noise", "tree", "someone"]


func lines() -> String:
	var de = _main.get("_day_events")
	var nj = _main.get("_night_jobs")
	var out := 0
	var english := 0
	for kind in EVENTS:
		var ev := {"kind": kind, "coord": [9, 12], "label": "path", "family": "The Dvořáks", "guest_name": "Pepa"}
		var shown := tr("Pager: %s" % de.tr(de.call("_start_line", ev)))
		english += _say("event " + kind, shown)
		out += 1
	var jobs := [
		["Power out", "Generator: the distribution board"],
		["A lamp went out", "Lamp %d:%d, hold R" % [3, 14]],
		["Sewer leaking", "The sewer hatch: crawl in"],
		["Someone is in the corn", "The wicket gate in the west fence"],
		["%s froze" % "The shower", "%d:%d: thaw the pipes" % [7, 9]],
		["Toilets blocked", "Toilet block %d:%d: go in and unblock it" % [6, 11]],
	]
	for j in jobs:
		var shown2 := tr("Pager: %s. %s." % [nj.tr(str(j[0])), nj.tr(str(j[1]))])
		english += _say("job", shown2)
		out += 1
	english += _say("knock", "%s %s" % [tr("The cabin is taken."), tr("\"Who is it?\"")])
	english += _say("left", LANG_F.f("Left behind in %s by %s: %s.", ["%s %d:%d" % [tr("Cabin"), 3, 4], "Pepa", tr("Umbrella")]))
	english += _say("coop", tr("You came in by the barrier. %s is about." % "Jana"))
	english += _say("sorted", tr("%s: sorted." % nj.tr("The showers froze")))
	out += 4
	for literal in ["Pager: new mail at the office", "Pager: Vera came in on the first bus. The district at eight. Books on the desk.", "Pager: Sewer leaking. The sewer hatch: crawl in."]:
		english += _say("hud", tr(literal))
		out += 1
	var line := "HLASKY %d lines, %d still English" % [out, english]
	print(line)
	return line


func _say(what: String, shown: String) -> int:
	# Still English: the words of the English line are in it.
	var en := shown.contains(" the ") or shown.contains("has ") or shown.contains(" is ") or shown.begins_with("Pager:") and not shown.contains("á") and not shown.contains("í") and not shown.contains("é") and not shown.contains("ů") and not shown.contains("ě")
	print("HLASKY %s %s: %s" % ["EN" if en else "cs", what, shown])
	return 1 if en else 0


func _ready() -> void:
	super._ready()
	_steps = [
		["wait_menu"], ["call", "_on_menu_new_game_pressed", []], ["wait_gameplay"], ["wait", 2.0],
		["eval", C + ".lines()"],
	]
