extends RefCounted

## The Hlubocany Courier's extra editions in Builder 98 (DESIGN §5j), Transport Tycoon's
## news in the district's own paper (the web's "Courier this week" is the same paper):
## the camp's firsts and records, each once (what has run is kept on the PC: os_shell's
## store "courier"). Diplomas from the district for the camp's good times, each once.
## Pure: builder_module feeds it what the camp has (`check`) and shows what it returns.

## [id, headline, the story] — {n} is the number that made it news.
const STORIES := {
	"caravan": ["NEW CARAVANS AT CERNE JEZERO", "The camp by the reservoir has put up its first caravan. \"A fridge and a proper bed,\" the operator told us. The district has not been asked."],
	"slide": ["LAKE SLIDE OPENS AT THE RESERVOIR", "Children queued at Cerne jezero for the new slide into the reservoir. The Water Board reminds swimmers that the water is colder than it looks."],
	"pub": ["A PUB AT THE CAMP AGAIN", "Cerne jezero pours beer again. The regulars from Liblice say the walk is worth it. The landlord of U Jezera did not comment."],
	"jednota": ["THE CAMP HAS ITS OWN JEDNOTA", "A shop at Cerne jezero: bread, salami, ice cream. The Jednota u Marku in Liblice says it is not worried. Its shelves were empty by noon."],
	"mega_gnome": ["GIANT GNOME BY THE RESERVOIR", "A garden gnome as tall as a cabin has appeared at Cerne jezero. Drivers on the dam road slow down to look. Nobody has seen it put up."],
	"tier": ["CAMP RATED {n} ON GOGGLE", "The reservoir camp is rated {n} stars on Goggle. \"People look before they book,\" said a woman from the district's tourist office, who has not been there."],
	"caught": ["CAMP CAUGHT TIDYING UP ITS REVIEWS", "Goggle says reviews of Cerne jezero have been taken down by a company that does such things. The camp says it knows nothing about it."],
	"guests": ["RECORD: {n} GUESTS AT THE RESERVOIR", "{n} people stayed at Cerne jezero last night, the most since the camp opened again. The district's accommodation office was surprised."],
}
## Guests worth a story.
const GUEST_RECORDS := [10, 20, 40, 80]
## Diplomas: [id, the award, what it says it is for].
const DIPLOMAS := {
	"improved": ["Most Improved Camp of the District", "for raising the camp's good name on the internet by a whole star"],
	"favourite": ["The Guests' Favourite Camp", "for guests in good spirits, ten or more of them at once"],
	"tidy": ["Tidiest Camp of the District 1998", "for a camp kept in good repair, ten buildings or more"],
}

var fired: Array = []
var diplomas: Array = []


## What the camp has now: {caravan: bool, slide, pub, jednota, mega_gnome, tier: int,
## rating: float, start_rating: float, caught: bool, guests: int, mood: float,
## buildings: int, repair: 0-1}. Returns the editions and diplomas due: [{kind:
## "news"|"diploma", id, title, text}] (each once ever).
func check(camp: Dictionary) -> Array:
	var out: Array = []
	for k in ["caravan", "slide", "pub", "jednota", "mega_gnome", "caught"]:
		if bool(camp.get(k, false)):
			_news(out, k, 0)
	var tier := int(camp.get("tier", 0))
	for t in range(1, tier + 1):
		_news(out, "tier%d" % t, 0, "tier", str(camp.get("tier_stars", {}).get(t, "")))
	var guests := int(camp.get("guests", 0))
	for r in GUEST_RECORDS:
		if guests >= r:
			_news(out, "guests%d" % r, r, "guests")
	# Diplomas.
	if float(camp.get("rating", 0.0)) >= float(camp.get("start_rating", 5.0)) + 1.0:
		_diploma(out, "improved")
	if guests >= 10 and float(camp.get("mood", 0.0)) >= 75.0:
		_diploma(out, "favourite")
	if int(camp.get("buildings", 0)) >= 10 and float(camp.get("repair", 0.0)) >= 0.9:
		_diploma(out, "tidy")
	return out


func _news(out: Array, id: String, n: int, story := "", stars := "") -> void:
	if fired.has(id):
		return
	fired.append(id)
	var s: Array = STORIES[story if story != "" else id]
	var num := stars if stars != "" else str(n)
	out.append({"kind": "news", "id": id, "title": str(s[0]).replace("{n}", num), "text": str(s[1]).replace("{n}", num)})


func _diploma(out: Array, id: String) -> void:
	if diplomas.has(id):
		return
	diplomas.append(id)
	out.append({"kind": "diploma", "id": id, "title": str(DIPLOMAS[id][0]), "text": str(DIPLOMAS[id][1])})


func export_state() -> Dictionary:
	return {"fired": fired.duplicate(), "diplomas": diplomas.duplicate()}


func import_state(d: Dictionary) -> void:
	fired = (d.get("fired", []) as Array).map(func(x): return str(x)) if d.get("fired", []) is Array else []
	diplomas = (d.get("diplomas", []) as Array).map(func(x): return str(x)) if d.get("diplomas", []) is Array else []
