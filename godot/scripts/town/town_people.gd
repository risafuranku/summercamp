extends Node3D

## The people of Lesna (scripts/town/town_lesna.gd): Build-engine billboards (Grok,
## assets/textury/npc/town_*.png) that keep to a day: where each of them is from which
## hour to which, walking between their places in steps, gone indoors at night. Click
## one to talk (building_type "town_npc"): a line at a time from what they know, and
## they know things about the camp. Lines go round; some only come out after dark.
## A round (the patrol, the bike) is walked by the clock, not from where they were seen
## last: at the same hour they are at the same place on it, on both co-op machines too.

const NPC := "res://assets/textury/npc/"
const WALK := 1.3
const PIXEL := 0.0145
const BALANCE = preload("res://core/balance/balance_config.gd")

## Places in the village's own frame (x east, z south; the road at z = 0).
const SPOTS := {
	"jednota": Vector3(-3.0, 0, -8.6),
	"jednota_side": Vector3(-11.5, 0, -8.8),
	"bench": Vector3(8.0, 0, 14.4),
	"memorial": Vector3(24.4, 0, 11.4),
	"chapel": Vector3(-28.0, 0, -17.2),
	"pub": Vector3(19.2, 0, -9.4),
	"station": Vector3(44.2, 0, 9.4),
	"motel": Vector3(-29.0, 0, 9.6),
	"home_hruba": Vector3(-36.0, 0, -30.5),
	"home_franta": Vector3(23.8, 0, -16.5),
	"home_pepik": Vector3(-46.5, 0, -11.0),
}
const LOOPS := {
	"patrol": [Vector3(-52.0, 0, -4.6), Vector3(26.0, 0, -4.6), Vector3(26.0, 0, 4.4), Vector3(60.0, 0, 4.4), Vector3(26.0, 0, 4.4), Vector3(26.0, 0, -4.6)],
	"bike": [Vector3(-62.0, 0, -2.6), Vector3(72.0, 0, -2.6), Vector3(72.0, 0, 2.6), Vector3(-62.0, 0, 2.6)],
}
## Who: their name, sprite, day ([from, to, place or loop]) and what they say.
const PEOPLE := {
	"hruba": {"name": "Mrs Hruba", "sprite": "town_babicka.png", "day": [[6.5, 9.5, "jednota_side"], [9.5, 16.0, "bench"], [16.0, 18.5, "chapel"]],
		"lines": [
			"You are from the camp. I can tell by the boots. That black mud is the lake.",
			"My Karel kept the boats up there thirty years. One night he rowed out to fetch something. The boat came back by itself.",
			"There is a photograph of his on your board, I expect. The lake from the jetty. Look at the middle of it.",
			"Vera used to bring me eggs from the camp. Then she stopped coming down. Then she stopped.",
			"Do not buy the sausages on a Monday.",
		],
		"night": ["You should not be out. Go to the motel, Simek keeps a light on."]},
	"franta": {"name": "Franta", "sprite": "town_tracksuit.png", "day": [[9.0, 19.0, "jednota"], [19.0, 23.5, "pub"]],
		"lines": [
			"The bus? Three a day. The last one up to you goes at half past six. Nobody goes up there after dark anyway.",
			"The works bus at midnight goes up to the dam. Nobody gets on, nobody gets off. My cousin drives it. He says it is heavier coming back.",
			"Lesnak's at the Jednota. Ten degrees. Tastes like the reservoir.",
			"They say your register never adds up. More people in the beds than in the book.",
			"Lojza at the Benzina down by your turn pays cash if you can hold a nozzle steady. Do not ask him about the Tatra.",
		],
		"night": ["Pub's open. Kubat won't let you in the cellar, don't ask.", "Listen. No dogs tonight. When the dogs stop, I go home."]},
	"kubat": {"name": "Mr Kubat", "sprite": "town_landlord.png", "day": [[10.0, 23.0, "pub"]],
		"lines": [
			"Kitchen's shut. The cellar is not open to guests.",
			"Karbanatky to our own recipe. What is in them is the recipe.",
			"If you have meat to sell, regular, any quantity, come round the back.",
			"A beer is a dollar. The second one is a dollar too. The tenth one, we talk.",
		],
		"night": ["Last orders at eleven. After that I lock the door and I do not open it, whoever knocks. Whoever."]},
	"simek": {"name": "Mr Simek", "sprite": "town_motel.png", "day": [[0.0, 24.0, "motel"]],
		"lines": [
			"A room is fifteen. Breakfast is a promise, not a guarantee.",
			"Your camp people stay here when they miss the bus. Some of them. Some just stand in the car park all night looking up the road.",
			"Do not open the window in number six. It does not open, but do not.",
		],
		"night": ["Fifteen dollars. Key's on the board. Lock it twice."]},
	"vavra": {"name": "Sgt Vavra", "sprite": "town_policeman.png", "day": [[8.0, 21.0, "patrol"]],
		"lines": [
			"The camp? You are the new one up there. The district has been asking about your register.",
			"Persons found in a facility who are not in the register are not the district's responsibility. It is on the notice. Read it.",
			"In ninety-four a man walked in out of the forest with a camp key in his hand. He could not say his name. Still can't.",
			"Off the road at night. The works bus does not brake.",
		],
		"night": ["Home. Now."]},
	"pepik": {"name": "Pepik", "sprite": "town_kid.png", "day": [[13.0, 19.5, "bike"]],
		"lines": [
			"Have you seen the man in the corn? My brother has. He won't say what he looks like.",
			"Bet you a crown you won't swim in your lake at night.",
			"My bike's faster than the bus. The bus doesn't stop for anybody after dark.",
		],
		"night": []},
}

var _rng := RandomNumberGenerator.new()
var _people: Dictionary = {}       # who -> {sprite, body, at, target, path, line, place}
var _acc := 0.0


func build() -> void:
	name = "People"
	_rng.seed = 7
	for who in PEOPLE.keys():
		var d: Dictionary = PEOPLE[who]
		var path: String = NPC + str(d["sprite"])
		if not ResourceLoader.exists(path):
			continue
		var root := Node3D.new()
		root.name = str(who)
		add_child(root)
		var s := Sprite3D.new()
		s.texture = load(path)
		s.pixel_size = PIXEL
		s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.shaded = true
		s.offset = Vector2(0, s.texture.get_height() * 0.5)
		root.add_child(s)
		var body := StaticBody3D.new()
		body.set_meta("building_type", "town_npc")
		body.set_meta("who", str(who))
		var shape := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.35
		cap.height = 1.8
		shape.shape = cap
		shape.position = Vector3(0, 0.9, 0)
		body.add_child(shape)
		root.add_child(body)
		_people[who] = {"root": root, "sprite": s, "body": body, "line": 0, "place": "", "path": [], "loop_i": 0}
		root.visible = false


## Who is where at `hour` (called a few times a second by town_trip.gd).
func update(hour: float, delta: float) -> void:
	_acc += delta
	for who in _people.keys():
		var p: Dictionary = _people[who]
		var place := _place_at(str(who), hour)
		var root: Node3D = p["root"]
		if place != str(p["place"]):
			var was := str(p["place"])
			p["place"] = place
			if place == "":
				# Indoors: they walk off to where they live and are gone (or just gone).
				root.visible = false
				(p["body"] as StaticBody3D).process_mode = Node.PROCESS_MODE_DISABLED
				continue
			(p["body"] as StaticBody3D).process_mode = Node.PROCESS_MODE_INHERIT
			if was == "" or not root.visible:
				root.position = _first_point(place)
				root.visible = true
			p["path"] = _route_to(place)
			p["loop_i"] = 0
		if place == "":
			continue
		if LOOPS.has(place):
			root.position = _round_at(str(who), place, hour)
			_bob(p, true)
			continue
		_walk(p, place, delta)


func _place_at(who: String, hour: float) -> String:
	for slot in PEOPLE[who]["day"]:
		var a: float = slot[0]
		var b: float = slot[1]
		if (a <= b and hour >= a and hour < b) or (a > b and (hour >= a or hour < b)):
			return str(slot[2])
	return ""


## Where on its round someone is at `hour`: as far along it as they would have walked
## since their slot began (game minutes to seconds at the walking pace).
func _round_at(who: String, place: String, hour: float) -> Vector3:
	var start := hour
	for slot in PEOPLE[who]["day"]:
		if str(slot[2]) == place:
			start = float(slot[0])
	var since := fposmod(hour - start, 24.0)
	var speed := WALK * (2.6 if place == "bike" else 1.0)
	var dist := since * 60.0 / BALANCE.GAME_MINUTES_PER_SECOND * speed
	var pts: Array = LOOPS[place]
	var total := 0.0
	for i in pts.size():
		total += (pts[i] as Vector3).distance_to(pts[(i + 1) % pts.size()])
	if total <= 0.0:
		return pts[0]
	dist = fposmod(dist, total)
	for i in pts.size():
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % pts.size()]
		var seg := a.distance_to(b)
		if dist <= seg:
			return a.lerp(b, dist / maxf(seg, 0.001))
		dist -= seg
	return pts[0]


func _first_point(place: String) -> Vector3:
	if LOOPS.has(place):
		return LOOPS[place][0]
	return SPOTS.get(place, Vector3.ZERO)


func _route_to(place: String) -> Array:
	if LOOPS.has(place):
		return (LOOPS[place] as Array).duplicate()
	return [SPOTS.get(place, Vector3.ZERO)]


func _walk(p: Dictionary, place: String, delta: float) -> void:
	var root: Node3D = p["root"]
	var path: Array = p["path"]
	if path.is_empty():
		return
	var i := int(p["loop_i"]) % path.size()
	var target: Vector3 = path[i]
	var to := target - root.position
	to.y = 0.0
	var speed := WALK * (2.6 if place == "bike" else 1.0)
	var moving := to.length() > 0.08
	if moving:
		root.position += to.normalized() * minf(to.length(), speed * delta)
	_bob(p, moving)


## Walking bobs in steps; standing still breathes.
func _bob(p: Dictionary, moving: bool) -> void:
	var s: Sprite3D = p["sprite"]
	var tick := floorf(_acc * 12.0)
	if moving:
		s.position.y = (0.04 if int(tick) % 2 == 0 else 0.0)
	else:
		s.position.y = 0.0
		s.scale.y = 1.0 + (0.008 if int(tick / 12.0) % 2 == 0 else 0.0)


## Talking to them: the next line (the night's after dark).
func talk(who: String, hour: float) -> Array:
	if not PEOPLE.has(who):
		return ["", ""]
	var d: Dictionary = PEOPLE[who]
	var p: Dictionary = _people.get(who, {})
	var night := hour >= 20.0 or hour < 6.0
	var lines: Array = d["night"] if night and not (d["night"] as Array).is_empty() else d["lines"]
	var i := int(p.get("line", 0))
	if not p.is_empty():
		p["line"] = i + 1
	return [str(d["name"]), str(lines[i % lines.size()])]


func name_of(who: String) -> String:
	return str(PEOPLE.get(who, {}).get("name", who))
