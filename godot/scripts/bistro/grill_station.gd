extends "res://scripts/bistro/bistro_station.gd"

## The grill on the kitchen island (the brief of 20. 10.: "a sausage off the grill with
## mustard and bread: turn it, don't burn it"). Its top is a Build texture (st_grill: the
## tray at the left, the grate over the gas in the middle, the resting rack at the right),
## the sausages sprites in the room (bistro/sausage_*.png).
##   the tray     a click: a sausage out of the box onto a free place on the grate (one of
##                the books' sausages)
##   a sausage    a click with the tongs turns it over; brown on both sides a click puts
##                it on the rack (for the pass: a sausage on a plate, mustard, bread);
##                black, a click bins it
## The column over each is the side on the fire: brown in the green, black past it. The
## grill goes on without you (kitchen.gd): a sausage left on it burns.

const TRAY := Rect2(8, 60, 112, 236)
const SLOTS := [Vector2(256, 130), Vector2(384, 130), Vector2(256, 228), Vector2(384, 228)]
const RACK := Rect2(500, 48, 132, 268)
const SAUSAGE_M := 0.15

var _tray: Array = []
var _sausages: Array = []
var _meters: Array = []
var _rack: Array = []
var _smoke: Array = []
var _sizzle: AudioStreamPlayer


func _build() -> void:
	super._build()
	for i in 6:
		var t := sprite(TEX + "sausage_raw.png", SAUSAGE_M, true)
		put(t, TRAY.position + Vector2(56, 30 + i * 34), 0.012)
		_tray.append(t)
	for i in SLOTS.size():
		var s := sprite(TEX + "sausage_raw.png", SAUSAGE_M, true)
		put(s, SLOTS[i], 0.016)
		_sausages.append(s)
		var m := meter(5, 16)
		m.position = local_at(SLOTS[i] + Vector2(0, -34), 0.03)
		_meters.append(m)
		var puff := sprite("res://assets/textury/camp/steam_puff.png", 0.08, false)
		puff.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		puff.modulate = Color(0.35, 0.33, 0.32, 0.8)
		puff.visible = false
		_smoke.append(puff)
	for i in 6:
		var r := sprite(TEX + "sausage_done.png", SAUSAGE_M, true)
		put(r, RACK.position + Vector2(66, 30 + i * 40), 0.014)
		_rack.append(r)
	_sizzle = AudioStreamPlayer.new()
	var path := "res://assets/sfx/bistro/fryer.mp3"
	if ResourceLoader.exists(path):
		var st = (load(path) as AudioStreamMP3).duplicate()
		st.loop = true
		_sizzle.stream = st
	_sizzle.volume_db = -60.0
	add_child(_sizzle)


## What the side facing up looks like, from the two sides' states.
static func look_of(slot: Dictionary) -> String:
	var d := RULES.sausage_side(float(slot["t"][int(slot["down"])]))
	var u := RULES.sausage_side(float(slot["t"][1 - int(slot["down"])]))
	if d == 2 or u == 2:
		return "sausage_burnt"
	if u == 1 and d == 1:
		return "sausage_done"
	if u == 1:
		return "sausage_half"
	return "sausage_raw"


func _show() -> void:
	if kitchen == null or building_key == "":
		return
	var stock := maxi(0, BUSINESS.stock_of(building_key, "sausage"))
	for i in _tray.size():
		(_tray[i] as Sprite3D).visible = i < stock
	var g: Array = kitchen.site(building_key)["grill"]
	var any := false
	for i in SLOTS.size():
		var s: Sprite3D = _sausages[i]
		var m: Sprite3D = _meters[i]
		var slot: Dictionary = g[i] if i < g.size() else {}
		s.visible = not slot.is_empty()
		m.visible = s.visible and is_open()
		(_smoke[i] as Sprite3D).visible = false
		if slot.is_empty():
			continue
		any = true
		var look := look_of(slot)
		retex(s, TEX + look + ".png", SAUSAGE_M)
		var down := float(slot["t"][int(slot["down"])])
		var side := RULES.sausage_side(down)
		set_meter(m, down / RULES.GRILL_BURNT, Vector2(RULES.GRILL_GOLD / RULES.GRILL_BURNT, 1.0), RETRO_UI.C_RED if side == 2 else RETRO_UI.C_AMBER, side == 2)
		if look == "sausage_burnt":
			# Black smoke off it, in steps.
			var puff: Sprite3D = _smoke[i]
			puff.visible = true
			var k := fmod(_t * 1.5 + i * 0.3, 1.0)
			put(puff, SLOTS[i] + Vector2(0, -10), 0.05 + floorf(k * 6.0) / 6.0 * 0.18)
	var ready := kitchen.prep(building_key, "sausage")
	for i in _rack.size():
		(_rack[i] as Sprite3D).visible = i < ready
	_sizzle.volume_db = move_toward(_sizzle.volume_db, -14.0 if any and is_visible_in_tree() else -60.0, 6.0)
	if any and not _sizzle.playing and _sizzle.stream != null and is_visible_in_tree():
		_sizzle.play()
	elif not any and _sizzle.playing and _sizzle.volume_db <= -59.0:
		_sizzle.stop()


func _spots() -> Array:
	var out: Array = []
	if kitchen == null:
		return out
	var g: Array = kitchen.site(building_key)["grill"]
	var free := false
	for i in g.size():
		var slot: Dictionary = g[i]
		if slot.is_empty():
			free = true
			continue
		var look := look_of(slot)
		var verb := "Turn it over"
		if look == "sausage_burnt":
			verb = "Black: into the bin"
		elif look == "sausage_done":
			verb = "Brown all over: onto the rack"
		out.append({"id": "slot:%d" % i, "node": _sausages[i], "verb": verb})
	var stock := maxi(0, BUSINESS.stock_of(building_key, "sausage"))
	if free:
		out.append({"id": "tray", "rect": TRAY, "verb": "A sausage onto the grill (%d in the box)" % stock if stock > 0 else "No sausages: order them in the books"})
	return out


func where() -> String:
	return "pass"


func hand_tool() -> String:
	var id := _held if _held != "" else _hover
	return "tongs" if id.begins_with("slot:") or id == "tray" else "open"


func _press(id: String) -> void:
	if id == "tray":
		_lay()
	elif id.begins_with("slot:"):
		_use(int(id.substr(5)))


func _lay() -> void:
	var g: Array = kitchen.site(building_key)["grill"]
	for i in g.size():
		if not (g[i] as Dictionary).is_empty():
			continue
		if BUSINESS.stock_of(building_key, "sausage") == 0:
			say("", "The box is empty.")
			return
		if CoreRoot != null and CoreRoot.actions != null and not CoreRoot.actions.biz_take(building_key, {"sausage": 1}):
			return
		kitchen.act(building_key, "grill", [i, {"down": 0, "t": [0.0, 0.0]}])
		sfx("sizzle_in", -8.0, randf_range(0.95, 1.08))
		return
	say("", "The grill is full.")


func _use(i: int) -> void:
	var slot: Dictionary = (kitchen.site(building_key)["grill"] as Array)[i]
	if slot.is_empty():
		return
	match look_of(slot):
		"sausage_burnt":
			kitchen.act(building_key, "grill", [i, {}])
			sfx("scrape", -10.0)
			say("", "In the bin.")
		"sausage_done":
			if not kitchen.room_for(building_key, "sausage"):
				say("", "The rack is full.")
				return
			kitchen.act(building_key, "grill", [i, {}])
			kitchen.act(building_key, "prep", ["sausage", 1, [KITCHEN.sausage_quality(slot)]])
			sfx("plate_down", -12.0, 1.2)
		_:
			var turned := slot.duplicate(true)
			turned["down"] = 1 - int(slot["down"])
			kitchen.act(building_key, "grill", [i, turned])
			sfx("grill_turn", -8.0, randf_range(0.95, 1.1))


func _closing() -> void:
	_sizzle.stop()


## The sausages on the grill and on the rack, for the frame's bar.
func bar_text() -> String:
	if kitchen == null or building_key == "":
		return ""
	return "BOX %d  RACK %d" % [maxi(0, BUSINESS.stock_of(building_key, "sausage")), kitchen.prep(building_key, "sausage")]


# ── debug (tools/bistro_check.gd, tools/bistro_shots.gd) ─────────────────────

func debug_click(id: String) -> void:
	_press(id)


## Every sausage on the grill `t` seconds on its side down.
func debug_cook(t: float) -> void:
	var g: Array = kitchen.site(building_key)["grill"]
	for i in g.size():
		var slot: Dictionary = g[i]
		if slot.is_empty():
			continue
		var s2 := slot.duplicate(true)
		s2["t"][int(s2["down"])] = t
		kitchen.act(building_key, "grill", [i, s2])
