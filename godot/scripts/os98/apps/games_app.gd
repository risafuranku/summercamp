extends "res://scripts/os98/apps/program_shelf.gd"

## Games: the Games group of the Start menu, as a folder. Mines came with Okna; Komar,
## Vylet and Pexeso are shareware from bohemia-online.cz/hry, put on this machine before
## the season (README.TXT says whose they are). Each keeps its table of the five best
## with the names typed in (os_shell.scores), and the old names are still on them.
##   Komar 98    a camper asleep in his tent, mosquitoes coming for him: swat them, not him
##   Vylet 98    lead the hiking group through the woods and pick up the stragglers
##   Pexeso 98   the memory game, with the pictures from the Builder catalogue


func _entries() -> Array:
	return [
		{"id": "mines", "script": "mines_app"},
		{"id": "mosquito", "script": "game_mosquito"},
		{"id": "hike", "script": "game_hike"},
		{"id": "pexeso", "script": "game_pexeso"},
	]


func _heading() -> Array:
	return ["Games", "games"]


## The best on the table, and whose it is.
func _card_status(id: String) -> String:
	var rows: Array = _shell.scores(id)
	if rows.is_empty():
		return ""
	var unit := {"mines": " s", "pexeso": " turns"}.get(id, "") as String
	return "Best: %d%s, %s" % [int(rows[0][1]), unit, str(rows[0][0])]


func _cover_lines(id: String) -> Array:
	match id:
		"mosquito":
			return ["KOMAR 98  -  shareware", "A camper is asleep in his tent. The mosquitoes are", "not. Swat them before they bite him. Do not slap him:",
				"five bites or three slaps and he wakes up.", "", "Mouse only. For Okna 95 and 98."]
		"hike":
			return ["VYLET 98  -  shareware", "Lead the hiking group through the woods and pick", "up the children who wandered off. Do not walk into",
				"a tree, or into your own group.", "", "Arrow keys."]
		"pexeso":
			return ["PEXESO 98  -  shareware", "The memory game. Twelve pairs of pictures from the", "Builder 98 catalogue. Turn two cards; a pair stays.",
				"", "", "Mouse only."]
	return []
