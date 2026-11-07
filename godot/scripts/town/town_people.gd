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
## Metres tall (the rest of them 1.72, the street's height).
const HEIGHTS := {"hruba": 1.55, "pepik": 1.35}
const BALANCE = preload("res://core/balance/balance_config.gd")
const FIGURE = preload("res://scripts/figures/doom_figure.gd")
## Drawn from eight sides with a walk (npc/sets/, tools/artgen/figures.py): by the name of their
## sprite, or by this one. Whoever is not keeps their one picture, mirrored the way they go.
const SETS := {"vavra": "vavra"}
## Standing about, they turn to you when you come this near, this fast (radians a second).
const LOOK_NEAR := 5.0
const LOOK_TURN := 2.2

## Places in the village's own frame (x east, z south; the road at z = 0).
const SPOTS := {
	"jednota": Vector3(-3.0, 0, -8.6),
	"jednota_side": Vector3(-11.5, 0, -8.8),
	"bench": Vector3(9.5, 0, 13.9),
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
	# Pepik on his bike up and down the south pavement (it was the road's lanes: the 380 ran
	# him over, the user 6. 11.).
	"bike": [Vector3(-62.0, 0, 4.6), Vector3(31.0, 0, 4.6)],
}
## Who: their name, sprite, day ([from, to, place or loop]) and what they say.
const PEOPLE := {
	"hruba": {"name": "Mrs Hruba", "sprite": "town_babicka.png", "day": [[6.5, 9.5, "jednota_side"], [9.5, 16.0, "bench"], [18.0, 18.5, "chapel"]],
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
			"The bus? Four a day. The last one up to you goes at a quarter to four. Nobody goes up there after dark anyway.",
			"The works bus at midnight goes up to the dam. Nobody gets on, nobody gets off. My cousin drives it. He says it is heavier coming back.",
			"Lesnak's at the Jednota. Ten degrees. Tastes like the reservoir.",
			"They say your register never adds up. More people in the beds than in the book.",
			"Lojza at the Benzina down by your turn pays cash if you can hold a nozzle steady. Do not ask him about the Tatra.",
		],
		"night": ["Pub's open. Kubat won't let you in the cellar, don't ask.", "Listen. No dogs tonight. When the dogs stop, I go home."]},
	"kubat": {"name": "Mr Kubat", "sprite": "town_landlord.png", "day": [],
		"lines": [
			"Kitchen's shut. The cellar is not open to guests.",
			"Karbanatky to our own recipe. What is in them is the recipe.",
			"If you have meat to sell, regular, any quantity, come round the back.",
			"A beer is a dollar. The second one is a dollar too. The tenth one, we talk.",
		],
		"night": ["Last orders at eleven. After that I lock the door and I do not open it, whoever knocks. Whoever."]},
	"simek": {"name": "Mr Simek", "sprite": "town_motel.png", "day": [],
		"lines": [
			"A room is fifteen. Breakfast is a promise, not a guarantee.",
			"Your camp people stay here when they miss the bus. Some of them. Some just stand in the car park all night looking up the road.",
			"Do not open the window in number six. It does not open, but do not.",
		],
		"night": ["Fifteen dollars. Key's on the board. Lock it twice."]},
	"vavra": {"name": "Sgt Vavra", "sprite": "town_policeman.png", "day": [[8.0, 23.0, "patrol"]],
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
		# As tall as they are, not all of them a head over you.
		s.pixel_size = float(HEIGHTS.get(who, 1.72)) / float(s.texture.get_height()) if s.texture != null else PIXEL
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
		var fig = null
		var drawn: Dictionary = FIGURE.set_of(str(SETS[who])) if SETS.has(who) else FIGURE.set_for(path)
		if not drawn.is_empty():
			fig = FIGURE.new(s, drawn, float(HEIGHTS.get(who, 1.72)))
		_people[who] = {"root": root, "sprite": s, "body": body, "line": 0, "place": "", "path": [], "loop_i": 0, "fig": fig}
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
				# Indoors: off down the pavement and gone once you are not looking (they went
				# out like a light on the bench at four).
				if root.visible and _seen(root.position) and not LOOPS.has(was):
					p["path"] = _way_off(root.position, was)
					p["loop_i"] = 0
					p["leaving"] = true
					continue
				root.visible = false
				(p["body"] as StaticBody3D).process_mode = Node.PROCESS_MODE_DISABLED
				continue
			p["leaving"] = false
			(p["body"] as StaticBody3D).process_mode = Node.PROCESS_MODE_INHERIT
			if was == "" or not root.visible:
				var spot := _first_point(place)
				# In your sight they come along the pavement, not out of the air.
				if _seen(spot) and not LOOPS.has(place):
					var way := _way_off(spot, place)
					way.reverse()
					root.position = way[0]
					root.visible = true
					p["path"] = way + [spot]
					p["loop_i"] = 1
				else:
					root.position = spot
					root.visible = true
					p["path"] = _route_to(place, was)
					p["loop_i"] = (p["path"] as Array).size() - 1
			else:
				p["path"] = _route_to(place, was)
				p["loop_i"] = 0
		if place == "":
			if bool(p.get("leaving", false)):
				_walk(p, "", delta)
				var path_off: Array = p["path"]
				var end_of: Vector3 = path_off[path_off.size() - 1]
				if root.position.distance_to(end_of) < 0.3 or not _seen(root.position):
					p["leaving"] = false
					root.visible = false
					(p["body"] as StaticBody3D).process_mode = Node.PROCESS_MODE_DISABLED
			continue
		if LOOPS.has(place):
			var was_at: Vector3 = root.position
			root.position = _round_at(str(who), place, hour)
			if root.position.distance_squared_to(was_at) > 0.000001:
				_look_along(p, root.position - was_at)
			_bob(p, true, root.position.distance_to(was_at))
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
	var speed := WALK
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


## In the eye of whoever is looking.
func _seen(at: Vector3) -> bool:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return false
	var w: Vector3 = to_global(at) + Vector3.UP
	return cam.global_position.distance_to(w) < 90.0 and cam.is_position_in_frustum(w)


## From `at` to the pavement and along it out of the village, by the nearer end.
func _way_off(at: Vector3, from := "") -> Array:
	var side := 4.6 if at.z >= 0.0 else -4.6
	var end := 62.0 if at.x >= 0.0 else -62.0
	var way: Array = [at]
	if from == "chapel":
		way.append(CHAPEL_GATE)
	way.append(Vector3(at.x, 0, side))
	way.append(Vector3(end, 0, side))
	return way


## The one picture they have, the way they walk: mirrored as they go left across your view.
func _look_along(p: Dictionary, to: Vector3) -> void:
	if p.get("fig") != null:
		p["fig"].face(global_transform.basis * to)
		return
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		(p["sprite"] as Sprite3D).flip_h = to.dot(cam.global_transform.basis.x) < 0.0


## The chapel's yard has its low wall (town_lesna._chapel_yard, L18): in and out by its
## gate on the pavement, not over the wall.
const CHAPEL_GATE := Vector3(-28.0, 0, -5.9)


func _route_to(place: String, from := "") -> Array:
	if LOOPS.has(place):
		return (LOOPS[place] as Array).duplicate()
	var to: Vector3 = SPOTS.get(place, Vector3.ZERO)
	if place == "chapel" or from == "chapel":
		return [CHAPEL_GATE, to]
	return [to]


func _walk(p: Dictionary, place: String, delta: float) -> void:
	var root: Node3D = p["root"]
	var path: Array = p["path"]
	if path.is_empty():
		return
	var i := int(p["loop_i"]) % path.size()
	var target: Vector3 = path[i]
	var to := target - root.position
	to.y = 0.0
	var speed := WALK
	var moving := to.length() > 0.08
	var step := minf(to.length(), speed * delta)
	if moving:
		root.position += to.normalized() * step
		_look_along(p, to)
	elif i < path.size() - 1:
		# On to the next point of the way (the chapel's gate, then its door).
		p["loop_i"] = i + 1
	_bob(p, moving, step)


## Walking bobs in steps; standing still breathes. Drawn from eight sides: their feet go by the
## ground they cover and the view by where you stand.
func _bob(p: Dictionary, moving: bool, metres := 0.0) -> void:
	var s: Sprite3D = p["sprite"]
	if p.get("fig") != null:
		var fig = p["fig"]
		fig.set_anim("walk" if moving else "stand")
		fig.advance(metres)
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			var to: Vector3 = cam.global_position - s.global_position
			if not moving and Vector2(to.x, to.z).length() < LOOK_NEAR:
				fig.turn_toward(to, LOOK_TURN * get_process_delta_time())
			fig.show(cam.global_position)
		return
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
