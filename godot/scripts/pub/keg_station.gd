extends "res://scripts/pub/pub_station.gd"

## The keg in the cellar (DESIGN.md §7b "the pub"), worked on the floor by the pallet in
## the room: the keg on the line on its pallet, the head (coupler) on its hose over it,
## the gas regulator with its valve and its column, the full kegs along the wall (the
## books' beer: service_interior._fill_cellar). Things are sprites at the room's pixel.
##   the head     a click takes it off the keg; held on a full keg, it screws down and the
##                line fills (`coupled`)
##   the keg      spent (the chalk cross), off its head: roll it off the pallet (a click);
##                then a full one on (the spares at the right)
##   the gas      hold the valve and drag up for more, down for less: in the green it pours
##                right; low it comes flat and slow, high all foam
## A keg on the line keeps a few days (twice as long with the keg cooler) and then it is
## flat: what is left in it is thrown out with it. What is left in it is chalked on it.

const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const PALLET := Vector2(320, 150)
const SPARES := Rect2(520, 40, 120, 220)
const VALVE_AT := Vector2(90, 160)
const TWIST_SEC := 0.9
const KEG_M := 0.6

var _twist := -1.0
var _valve_from := -1.0
var _gas_from := 0.0
var _roll := 0.0
var _hiss: AudioStreamPlayer
var _keg: Sprite3D
var _head: Sprite3D
var _valve: Sprite3D
var _gauge: Sprite3D
var _left_meter: Sprite3D
var _chalk: Label3D
var _pipe: MeshInstance3D


func _build() -> void:
	super._build()
	_keg = psprite("keg", KEG_M)
	_head = psprite("coupler", 0.16)
	_valve = psprite("valve", 0.14)
	# The regulator's pipe up from the floor to the valve.
	_pipe = MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.04, 0.5, 0.04)
	_pipe.mesh = b
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.35, 0.35, 0.36)
	pm.roughness = 0.7
	_pipe.material_override = pm
	_pipe.position = local_at(VALVE_AT, 0.25)
	add_child(_pipe)
	put(_valve, VALVE_AT, 0.5)
	_gauge = meter(5, 20)
	_gauge.position = local_at(VALVE_AT + Vector2(36, 0), 0.62)
	_left_meter = meter(5, 22)
	_left_meter.position = local_at(PALLET + Vector2(66, 0), 0.5)
	# What is left in the keg, chalked on it.
	_chalk = Label3D.new()
	_chalk.font = RETRO_UI.FONT_LABEL
	_chalk.font_size = 8
	_chalk.pixel_size = 1.0 / PX_PER_M
	_chalk.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_chalk.modulate = Color(0.93, 0.93, 0.9)
	_chalk.outline_size = 0
	_chalk.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_chalk.position = local_at(PALLET, 0.3) + Vector3(0, 0, 0.12)
	add_child(_chalk)
	_hiss = AudioStreamPlayer.new()
	var path := "res://assets/sfx/pub/gas_hiss.mp3"
	if ResourceLoader.exists(path):
		var st = (load(path) as AudioStream).duplicate()
		if st is AudioStreamMP3:
			(st as AudioStreamMP3).loop = true
		_hiss.stream = st
	_hiss.volume_db = -60.0
	add_child(_hiss)


func _show() -> void:
	if taproom == null or building_key == "":
		return
	var k: Dictionary = taproom.keg(building_key)
	var pallet := str(k["pallet"])
	_keg.visible = pallet != "none"
	var flat: bool = taproom.tap_trouble(building_key) == "flat"
	pretex(_keg, "keg_empty" if pallet == "empty" or flat else "keg", KEG_M)
	var roll := floorf(_roll / 0.5 * 4.0) / 4.0
	put(_keg, PALLET + Vector2(roll * 140.0, 0), 0.0)
	_chalk.visible = pallet == "full" and not flat
	_chalk.text = "%d" % int(k["line"])
	_left_meter.visible = pallet == "full"
	if pallet == "full":
		set_meter(_left_meter, float(int(k["line"])) / float(PUB.KEG_PINTS), Vector2(-1, -1), RETRO_UI.C_AMBER if int(k["line"]) > 6 else RETRO_UI.C_RED, int(k["line"]) <= 3)
	# The head: on the keg's top when coupled, else hanging on its hose over the pallet.
	var on := bool(k["coupled"]) and pallet != "none"
	var up := KEG_M * 0.98 if on else KEG_M + 0.25
	if _twist >= 0.0:
		up = KEG_M + 0.1 - floorf(_twist / TWIST_SEC * 4.0) / 4.0 * 0.08
	put(_head, PALLET, up)
	var gas := float(k["gas"])
	set_meter(_gauge, gas, Vector2(PUB.GAS_LOW, PUB.GAS_HIGH), RETRO_UI.C_GREEN if PUB.gas_band(gas) == "OK" else RETRO_UI.C_RED)
	_valve.rotation.z = floorf(gas * 6.0) / 6.0 * 2.4


func _spots() -> Array:
	var out: Array = []
	if taproom == null:
		return out
	var k: Dictionary = taproom.keg(building_key)
	var pallet := str(k["pallet"])
	var spares: int = taproom.spares(building_key)
	var flat: bool = taproom.tap_trouble(building_key) == "flat"
	if pallet != "none":
		var verb := "The keg on the line: %d pints" % int(k["line"])
		if pallet == "empty" or flat:
			verb = "Take the head off first" if bool(k["coupled"]) else "Roll the %s keg off the pallet" % ("flat" if flat else "spent")
		out.append({"id": "line_keg", "node": _keg, "verb": verb})
	if pallet == "none" and spares > 0:
		out.append({"id": "spare", "rect": SPARES, "verb": "Roll a full keg onto the pallet (%d)" % spares})
	var cverb := "Take the head off the keg" if bool(k["coupled"]) else ("Hold to screw the head onto the keg" if pallet == "full" else "The head, on its hose")
	out.append({"id": "coupler", "node": _head, "verb": cverb})
	out.append({"id": "valve", "node": _valve, "verb": "The gas: %s. Hold and drag up for more, down for less" % PUB.gas_band(float(k["gas"])).to_lower()})
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
				say("", "There is no full keg on the pallet.")
		"line_keg":
			var flat: bool = taproom.tap_trouble(building_key) == "flat"
			if str(k["pallet"]) == "empty" or flat:
				if bool(k["coupled"]):
					say("", "Take the head off first.")
					return
				if flat and int(k["line"]) > 0:
					# The flat beer goes down the drain: off the books as waste.
					taproom.waste_keg(building_key)
				taproom.set_keg(building_key, {"pallet": "none", "line": 0})
				_roll = 0.5
				sfx("keg_roll", -6.0)
			else:
				say("", "%d pints left in it." % int(k["line"]))
		"spare":
			if str(k["pallet"]) != "none":
				return
			var beer := maxi(0, BUSINESS.stock_of(building_key, "beer"))
			if beer <= 0 or taproom.spares(building_key) <= 0:
				return
			taproom.set_keg(building_key, {"pallet": "full", "line": mini(PUB.KEG_PINTS, beer), "coupled": false})
			_roll = 0.5
			sfx("keg_roll", -6.0, 0.9)
		"valve":
			_valve_from = _mouse_free.y
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


func _drag(at: Vector2) -> void:
	if _valve_from >= 0.0 and at.x > -500.0:
		# Up the floor's picture (away from you) opens it.
		var gas := clampf(_gas_from + (_valve_from - at.y) / 200.0, 0.0, 1.0)
		var k: Dictionary = taproom.keg(building_key)
		if absf(gas - float(k["gas"])) >= 0.01:
			taproom.set_keg(building_key, {"gas": gas})


func _tick(delta: float) -> void:
	_roll = maxf(0.0, _roll - delta)
	if _twist >= 0.0:
		# The quick coupler (gear): it clicks on in a moment.
		_twist += delta * (3.5 if BUSINESS.has_gear(building_key, "coupler") else 1.0)
		if _twist >= TWIST_SEC:
			_twist = -1.0
			taproom.set_keg(building_key, {"coupled": true, "tapped": CoreRoot.get_day() if CoreRoot != null else 0})
			sfx("coupler", -6.0, 0.9)
			sfx("gas_hiss", -12.0)
	var want := -60.0
	if _valve_from >= 0.0:
		want = -10.0
	_hiss.volume_db = move_toward(_hiss.volume_db, want, delta * 120.0)
	if _hiss.volume_db <= -59.0 and _hiss.playing:
		_hiss.stop()


func _closing() -> void:
	_twist = -1.0
	_valve_from = -1.0
	_hiss.stop()


func has_rail() -> bool:
	return false


func big_ticket() -> Dictionary:
	return {}


# ── debug (tools/pub_check.gd) ───────────────────────────────────────────────

func debug_click(id: String) -> void:
	if id == "coupler_on":
		taproom.set_keg(building_key, {"coupled": true, "tapped": CoreRoot.get_day()})
		return
	_press(id)
