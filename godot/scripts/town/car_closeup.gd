extends "res://scripts/closeup/closeup_view.gd"

## Old Vondra's Skoda 120 with its engine lid up (the engine is at the back), close up
## (Grok painting closeup_engine.png): getting it going the wonky way, with what you
## found in Podlesi (hamlet_trip.gd keeps `state`):
##   - the empty battery tray: the Trabant's battery in, then both cables on (sparks);
##   - no fan belt: a pair of stockings round the four pulleys, in whatever order;
##   - an empty tank: hold the mouse on the filler with the can full of the Babetta's
##     petrol;
##   - the starter only clicks: a whack with the hammer;
##   - the key (the tag in the corner): it clicks, cranks, catches, screams or runs,
##     depending. When it runs: a bang, black smoke, Vondra's delight (`started`).

signal started

const PIC := "res://assets/textury/town/closeup_engine.png"
const SND := "res://assets/sfx/hamlet/"
const BATTERY := "res://assets/textury/town/ham_battery.png"
const TRAY := Rect2(22, 62, 52, 46)
const CABLES := {"red": Rect2(26, 136, 16, 22), "black": Rect2(52, 138, 16, 22)}
const PULLEYS := [Rect2(142, 160, 32, 30), Rect2(100, 182, 32, 32), Rect2(142, 192, 32, 32), Rect2(184, 182, 34, 32)]
const STARTER := Rect2(208, 78, 50, 58)
const FILLER := Rect2(238, 18, 40, 38)
const RAG := Rect2(240, 146, 58, 52)
const KEY := Rect2(274, 204, 40, 30)
const BELT := Color(0.86, 0.76, 0.6)

## hamlet_trip.gd's state: {"has": {...}, "car": {...}}.
var state: Dictionary = {}
var _battery_tex: Texture2D
var _pour_snd := false
var _smoke_t := 0.0


func _ready() -> void:
	super._ready()
	picture = load(PIC) if ResourceLoader.exists(PIC) else null
	_battery_tex = load(BATTERY) if ResourceLoader.exists(BATTERY) else null


func _car() -> Dictionary:
	return state.get("car", {})


func _has() -> Dictionary:
	return state.get("has", {})


var _lid_creaked := false


func _opened() -> void:
	# The engine lid creaks up the first time.
	if not _lid_creaked:
		_lid_creaked = true
		_snd("garage_door.mp3")
	var car := _car()
	if bool(car.get("running", false)):
		say("", "She runs. Rough, loud, alive.", false)
	else:
		say("", "The engine of a Skoda 120, at the back where they keep it. Something is missing from most of it.", false)


func _hotspots() -> Array:
	var out: Array = [{"id": "tray", "rect": TRAY}, {"id": "starter", "rect": STARTER}, {"id": "filler", "rect": FILLER}, {"id": "rag", "rect": RAG}, {"id": "key", "rect": KEY}]
	for c in CABLES:
		out.append({"id": c, "rect": CABLES[c]})
	for i in PULLEYS.size():
		out.append({"id": "pulley:%d" % i, "rect": PULLEYS[i]})
	return out


func _snd(name: String, fallback := "") -> void:
	if ResourceLoader.exists(SND + name):
		play(SND + name, -4.0)
	elif fallback != "" and ResourceLoader.exists(fallback):
		play(fallback, -6.0)


func _clicked(id: String) -> void:
	var car := _car()
	var has := _has()
	if bool(car.get("running", false)) and id != "key":
		say("", "Best not touch anything now it runs.")
		return
	if id.begins_with("pulley:"):
		_pulley(int(id.get_slice(":", 1)))
		return
	match id:
		"tray":
			if bool(car.get("battery", false)):
				say("", "The battery sits in its tray. It was the Trabant's.")
			elif bool(has.get("battery", false)):
				car["battery"] = true
				has["battery"] = false
				_snd("battery_clunk.mp3", "res://assets/sfx/bus/thump.mp3")
				say("", "In it goes. Heavy, and it smells of the Trabant. Now the cables.")
			else:
				say("VONDRA", "That battery went flat in ninety-one. The Trabant behind my house still has one in it.")
		"red", "black":
			if not bool(car.get("battery", false)):
				say("", "A loose cable, its clamp green with rot.")
			elif bool(car.get(id, false)):
				say("", "Tight.")
			else:
				car[id] = true
				_snd("spark.mp3", "res://assets/sfx/bus/button.mp3")
				say("", "A spark, a snap. It holds." if not (car.get("red", false) and car.get("black", false)) else "A spark, a snap. Both cables on.")
		"filler":
			if float(car.get("fuel", 0.0)) >= 0.99:
				say("", "Full. Of Babetta.")
			elif str(has.get("canister", "")) == "full":
				say("", "Hold the button to pour.")
			elif str(has.get("canister", "")) == "empty":
				say("", "The can is empty. Something by the road still has petrol in it.")
			else:
				say("VONDRA", "Bone dry, the tank. The can is in the garage, by the wall.")
		"starter":
			if bool(car.get("unstuck", false)):
				say("", "The starter. You two have had words.")
			elif bool(has.get("hammer", false)):
				car["unstuck"] = true
				_snd("hammer_hit.mp3", "res://assets/sfx/bus/thump.mp3")
				say("", "Clank. Clank. Something inside it gives.")
			else:
				say("", "The starter motor: black, greasy, stubborn.")
		"rag":
			say("", "An oily rag. Vondra's handkerchief too, by the look of it.")
		"key":
			_crank()


## A stocking round one more pulley; round all four, the belt is on.
func _pulley(i: int) -> void:
	var car := _car()
	var has := _has()
	var belt: Array = car.get("belt", [])
	if belt.size() >= PULLEYS.size():
		say("", "Mrs Vondrova's stockings, three times round. Holding.")
		return
	if not bool(has.get("stockings", false)):
		say("VONDRA", "The fan belt snapped in ninety-one. My Marie always said a stocking will do.")
		return
	if belt.has(i):
		say("", "Already round that one.")
		return
	belt.append(i)
	car["belt"] = belt
	_snd("stocking.mp3", "res://assets/sfx/bus/button.mp3")
	if belt.size() >= PULLEYS.size():
		has["stockings"] = false
		say("", "Round all four and knotted. It will do to Liblice and back. Probably.")
	else:
		say("", "Round that one. %d to go." % (PULLEYS.size() - belt.size()))


## The key: what the car does depends on what it has.
func _crank() -> void:
	var car := _car()
	if bool(car.get("running", false)):
		say("", "She is running. Leave her be.")
		return
	if not (bool(car.get("battery", false)) and bool(car.get("red", false)) and bool(car.get("black", false))):
		say("", "Nothing. Not even a click.")
		return
	if not bool(car.get("unstuck", false)):
		_snd("car_click.mp3", "res://assets/sfx/bus/button.mp3")
		car["clicks"] = int(car.get("clicks", 0)) + 1
		if int(car["clicks"]) >= 2:
			say("VONDRA", "It only clicks? Hit the starter! Not hard. Like you mean it.")
		else:
			say("", "Click. Only the click.")
		return
	if float(car.get("fuel", 0.0)) < 0.5:
		_snd("car_crank_fail.mp3")
		say("", "It turns over and over. Nothing to burn.")
		return
	if (car.get("belt", []) as Array).size() < PULLEYS.size():
		_snd("car_crank_fail.mp3")
		say("", "It catches, something screams, it dies. The fan belt.")
		return
	car["running"] = true
	_snd("car_start.mp3", "res://assets/sfx/bus/start_inside.mp3")
	say("VONDRA", "Listen to her! Like a sewing machine full of nails!")
	started.emit()


func _tick(delta: float) -> void:
	var car := _car()
	var has := _has()
	# Pouring: held on the filler with the full can.
	var pouring := hovered() == "filler" and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and str(has.get("canister", "")) == "full" and float(car.get("fuel", 0.0)) < 1.0
	if pouring:
		if not _pour_snd:
			_pour_snd = true
			_snd("fuel_pour.mp3")
		car["fuel"] = minf(1.0, float(car.get("fuel", 0.0)) + delta * 0.32)
		if float(car["fuel"]) >= 1.0:
			has["canister"] = "empty"
			say("", "The can is empty and the tank is full. Of Babetta.")
	else:
		_pour_snd = false
	if bool(car.get("running", false)):
		_smoke_t += delta


func _paint(c: Control) -> void:
	var car := _car()
	if picture == null:
		c.draw_rect(Rect2(0, 0, W, PIC_H), Color(0.1, 0.09, 0.08))
	# The battery in its tray, and its cables.
	if bool(car.get("battery", false)):
		if _battery_tex != null:
			c.draw_texture_rect(_battery_tex, TRAY.grow(-3), false)
		else:
			c.draw_rect(TRAY.grow(-3), Color(0.1, 0.1, 0.1))
		if bool(car.get("red", false)):
			c.draw_line(CABLES["red"].get_center(), TRAY.position + Vector2(10, 8), Color(0.7, 0.12, 0.08), 2.0)
		if bool(car.get("black", false)):
			c.draw_line(CABLES["black"].get_center(), TRAY.position + Vector2(40, 8), Color(0.08, 0.08, 0.08), 2.0)
	# The stocking round the pulleys it has been round.
	var belt: Array = car.get("belt", [])
	if belt.size() >= 2:
		var pts := PackedVector2Array()
		for i in belt:
			pts.append((PULLEYS[int(i)] as Rect2).get_center())
		if belt.size() >= PULLEYS.size():
			pts.append(pts[0])
		c.draw_polyline(pts, BELT, 2.0)
	# The tank filling while you pour.
	var fuel := float(car.get("fuel", 0.0))
	if fuel > 0.0 and fuel < 1.0:
		c.draw_rect(Rect2(FILLER.position + Vector2(0, FILLER.size.y + 3), Vector2(FILLER.size.x, 4)), Color(0, 0, 0, 0.7))
		c.draw_rect(Rect2(FILLER.position + Vector2(1, FILLER.size.y + 4), Vector2((FILLER.size.x - 2) * fuel, 2)), Color(0.9, 0.7, 0.2))
	# The key tag in the corner.
	c.draw_rect(KEY, Color(0.12, 0.1, 0.08, 0.9))
	c.draw_rect(Rect2(KEY.position, Vector2(KEY.size.x, 1)), RETRO_UI.C_PLATE_LIGHT)
	var kx := KEY.position + Vector2(8, 15)
	c.draw_circle(kx, 4.0, Color(0.72, 0.66, 0.5))
	c.draw_rect(Rect2(kx + Vector2(3, -1), Vector2(16, 3)), Color(0.72, 0.66, 0.5))
	ink(c, RETRO_UI.FONT_LABEL, KEY.position + Vector2(13, 27), "KEY", RETRO_UI.C_BONE_DIM)
	# Black smoke when it runs.
	if bool(car.get("running", false)):
		var step := floorf(_smoke_t * 12.0) / 12.0
		for k in 5:
			var age := fmod(step * 0.4 + float(k) / 5.0, 1.0)
			var p := Vector2(150 + sin(float(k) * 2.1) * 30.0, 120.0 - age * 110.0)
			c.draw_circle(p, 4.0 + age * 10.0, Color(0.08, 0.08, 0.08, 0.6 * (1.0 - age)))
	if hovered() != "":
		for h in _hotspots():
			if str(h["id"]) == hovered():
				c.draw_rect(h["rect"], Color(1.0, 0.92, 0.6, 0.12))
