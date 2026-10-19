extends "res://scripts/pub/pub_station.gd"

## The keg in the cellar (assets/textury/pub/st_keg.png): the pallet with the keg on the
## line, the beer hose down from the ceiling to its head, the full kegs standing by (the
## books' beer, KEG_PINTS a keg), the gas cylinder with its gauge and valve.
##   a spent keg   the tap upstairs coughs: take the head off (click it), roll the empty
##                 off the pallet (click it: it joins the empties, chalked), roll a full
##                 one on (click one), and put the head on (hold the button on it until
##                 it is screwed down)
##   the gas       hold the button on the valve wheel and drag up for more, down for less:
##                 the needle wants the green; low and the beer comes flat and slow, high
##                 and it is all foam. It creeps down as the tap runs.

const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const PALLET_FOOT := Vector2(250, 300)
const HOSE_END := Vector2(250, 120)
const SPARES_FOOT := Vector2(380, 300)
const EMPTIES_FOOT := Vector2(70, 300)
const VALVE := Rect2(520, 120, 50, 50)
const GAUGE := Rect2(590, 90, 8, 120)
const TWIST_SEC := 0.9

var _twist := -1.0
var _valve_from := -1.0
var _gas_from := 0.0
var _roll := 0.0
var _hiss: AudioStreamPlayer


func _ready() -> void:
	super._ready()
	station = "keg"
	room = "cellar"
	picture = tex("st_keg")
	for n in ["keg_full", "keg_empty", "coupler", "valve", "chalk"]:
		tex(n)
	_hiss = AudioStreamPlayer.new()
	var path := PUB_SFX + "gas_hiss.mp3"
	if ResourceLoader.exists(path):
		var st = (load(path) as AudioStream).duplicate()
		if st is AudioStreamMP3:
			(st as AudioStreamMP3).loop = true
		_hiss.stream = st
	_hiss.volume_db = -60.0
	add_child(_hiss)


func _opened() -> void:
	match taproom.tap_trouble(building_key):
		"dry":
			say("", "No full kegs down here. Order beer in the books.")
		"empty":
			say("", "The keg on the line is spent.")
		"off":
			say("", "The head is off the keg.")
		_:
			var k: Dictionary = taproom.keg(building_key)
			say("", "%d pints left in the keg on the line. Gas %s." % [int(k["line"]), PUB.gas_band(float(k["gas"])).to_lower()])


func _closing() -> void:
	_twist = -1.0
	_valve_from = -1.0
	_hiss.stop()


func _keg_rect(foot: Vector2, n := "keg_full") -> Rect2:
	var t := tex(n)
	var sz := t.get_size() * float(PIX) if t != null else Vector2(90, 128)
	return Rect2((foot - Vector2(sz.x * 0.5, sz.y)).floor(), sz)


func _coupler_rect() -> Rect2:
	var t := tex("coupler")
	var sz := t.get_size() * float(PIX) if t != null else Vector2(40, 44)
	var k: Dictionary = taproom.keg(building_key)
	var at := HOSE_END
	if bool(k["coupled"]) and str(k["pallet"]) != "none":
		at = Vector2(PALLET_FOOT.x, _keg_rect(PALLET_FOOT).position.y + 6.0)
	elif _twist >= 0.0:
		at = Vector2(PALLET_FOOT.x, _keg_rect(PALLET_FOOT).position.y + 6.0 - (1.0 - _twist / TWIST_SEC) * 10.0)
	return Rect2((at - Vector2(sz.x * 0.5, sz.y)).floor(), sz)


func _spots() -> Array:
	var out: Array = []
	if taproom == null:
		return out
	var k: Dictionary = taproom.keg(building_key)
	var pallet := str(k["pallet"])
	var spares: int = taproom.spares(building_key)
	if pallet != "none":
		var verb := "The keg on the line: %d pints" % int(k["line"])
		if pallet == "empty":
			verb = "Take the head off first" if bool(k["coupled"]) else "Roll the spent keg off the pallet"
		out.append({"id": "line_keg", "rect": _keg_rect(PALLET_FOOT, "keg_empty" if pallet == "empty" else "keg_full"), "verb": verb})
	if spares > 0 or pallet == "none":
		var r := _keg_rect(SPARES_FOOT)
		r.size.x += 30.0 * maxi(0, mini(spares, 3) - 1)
		out.append({"id": "spare", "rect": r, "verb": ("Roll a full keg onto the pallet (%d)" % spares) if spares > 0 and pallet == "none" else ("%d full kegs" % spares if spares > 0 else "No full kegs: order beer in the books")})
	var cverb := "Take the head off the keg" if bool(k["coupled"]) else ("Hold to screw the head onto the keg" if pallet == "full" else "The head, on its hose")
	out.append({"id": "coupler", "rect": _coupler_rect().grow(6.0), "verb": cverb})
	out.append({"id": "valve", "rect": VALVE, "verb": "The gas: %s. Hold and drag up for more, down for less" % PUB.gas_band(float(k["gas"]))})
	return out


func _press(id: String) -> void:
	var k: Dictionary = taproom.keg(building_key)
	match id:
		"coupler":
			if bool(k["coupled"]):
				taproom.set_keg(building_key, {"coupled": false})
				sfx("gas_hiss", -8.0, 1.3)
				sfx("coupler", -8.0)
			elif str(k["pallet"]) == "full":
				_twist = 0.0
			else:
				say("", "There is no full keg on the pallet to put it on.")
		"line_keg":
			if str(k["pallet"]) == "empty":
				if bool(k["coupled"]):
					say("", "Take the head off first.")
					return
				taproom.set_keg(building_key, {"pallet": "none", "line": 0})
				_roll = 0.5
				sfx("keg_roll", -6.0)
			else:
				say("", "%d pints left in it." % int(k["line"]))
		"spare":
			if str(k["pallet"]) != "none":
				say("", "The pallet is taken." if str(k["pallet"]) == "full" else "Roll the spent one off first.")
				return
			var beer := maxi(0, BUSINESS.stock_of(building_key, "beer"))
			if beer <= 0 or taproom.spares(building_key) <= 0:
				say("", "No full kegs. Order beer in the books.")
				return
			taproom.set_keg(building_key, {"pallet": "full", "line": mini(PUB.KEG_PINTS, beer), "coupled": false})
			_roll = 0.5
			sfx("keg_roll", -6.0, 0.9)
		"valve":
			_valve_from = _mouse.y
			_gas_from = float(k["gas"])
			if _hiss.stream != null and not _hiss.playing:
				_hiss.play()


func _release(id: String) -> void:
	if id == "coupler" and _twist >= 0.0:
		if _twist < TWIST_SEC:
			say("", "Screw it right down, or it leaks.")
		_twist = -1.0
	if id == "valve" and _valve_from >= 0.0:
		_valve_from = -1.0
		var k: Dictionary = taproom.keg(building_key)
		say("", "Gas %s." % PUB.gas_band(float(k["gas"])).to_lower())


func _drag(at: Vector2) -> void:
	if _valve_from >= 0.0 and at.y >= 0.0:
		var gas := clampf(_gas_from + (_valve_from - at.y) / 240.0, 0.0, 1.0)
		var k: Dictionary = taproom.keg(building_key)
		if absf(gas - float(k["gas"])) >= 0.01:
			taproom.set_keg(building_key, {"gas": gas})


func _tick(delta: float) -> void:
	_roll = maxf(0.0, _roll - delta)
	if _twist >= 0.0:
		_twist += delta
		if _twist >= TWIST_SEC:
			_twist = -1.0
			taproom.set_keg(building_key, {"coupled": true})
			sfx("coupler", -6.0, 0.9)
			sfx("gas_hiss", -12.0)
			say("", "On. The line fills with beer.")
	var want := -60.0
	if _valve_from >= 0.0:
		want = -10.0
	_hiss.volume_db = move_toward(_hiss.volume_db, want, delta * 120.0)
	if _hiss.volume_db <= -59.0 and _hiss.playing:
		_hiss.stop()


# ── drawing ──────────────────────────────────────────────────────────────────

func _paint(c: Control) -> void:
	if taproom == null:
		return
	var k: Dictionary = taproom.keg(building_key)
	# The empties by the wall, chalked; the full ones standing by.
	for i in 2:
		stand(c, "keg_empty", EMPTIES_FOOT + Vector2(i * 22, -i * 4), 0.9, Color(0.75, 0.72, 0.68))
	var spares: int = taproom.spares(building_key)
	for i in mini(spares, 3):
		stand(c, "keg_full", SPARES_FOOT + Vector2(i * 30 + (12.0 * _roll if i == 0 and str(k["pallet"]) == "full" else 0.0), -i * 3))
	if spares > 3:
		ink(c, SPARES_FOOT + Vector2(-20, 14), "x%d" % spares, RETRO_UI.C_BONE)
	# The keg on the pallet.
	var pallet := str(k["pallet"])
	if pallet != "none":
		stand(c, "keg_empty" if pallet == "empty" else "keg_full", PALLET_FOOT + Vector2(-20.0 * _roll if pallet == "full" else 0.0, 0))
		if pallet == "empty":
			blit(c, "chalk", PALLET_FOOT + Vector2(0, -70))
		var lr := _keg_rect(PALLET_FOOT)
		ink(c, Vector2(lr.position.x, lr.end.y + 12), "%d PINTS" % int(k["line"]) if pallet == "full" else "SPENT", RETRO_UI.C_BONE if pallet == "full" else RETRO_UI.C_RED_LIGHT)
	# The head on the end of its hose.
	var cr := _coupler_rect()
	stand(c, "coupler", Vector2(cr.get_center().x, cr.end.y))
	if _twist >= 0.0:
		meter(c, Rect2(cr.end.x + 6, cr.position.y, 30, 5), _twist / TWIST_SEC, Vector2(-1, -1), RETRO_UI.C_GREEN)
	# The valve wheel and the gauge: the needle's place on a scale with its green.
	blit(c, "valve", VALVE.get_center())
	var gas := float(k["gas"])
	var col := RETRO_UI.C_GREEN if PUB.gas_band(gas) == "OK" else RETRO_UI.C_RED
	meter(c, GAUGE, gas, Vector2(PUB.GAS_LOW, PUB.GAS_HIGH), col, true)
	ink(c, Vector2(GAUGE.position.x - 16, GAUGE.end.y + 12), "GAS " + PUB.gas_band(gas), col)
