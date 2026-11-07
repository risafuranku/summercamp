extends "res://scripts/pub/pub_station.gd"

## The keg in the cellar (DESIGN.md §7b "the pub"), worked on the floor by the pallet in
## the room: the keg on the line on its pallet, the head (coupler) on its hose over it,
## the gas regulator with its valve and its column, the full kegs along the wall (the
## books' beer: service_interior._fill_cellar). Things are sprites at the room's pixel.
##   the head     a click takes it off the keg; held on a full keg, it screws down and the
##                line fills (`coupled`)
##   the keg      spent (the chalk cross), off its head: roll it off the pallet (a click);
##                then a full one on: a click on one of them, standing along the rack
##                (playtest 7. 11.: "I don't know where to get a new one, the ones standing
##                there take no click": they were the room's, the click was on the floor)
##   the gas      hold the valve and drag up for more, down for less: in the green it pours
##                right; low it comes flat and slow, high all foam
## What is left in it is chalked on it.

const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const PALLET := Vector2(320, 150)
## The full kegs along the rack, from the pallet's side.
const SPARE_AT := Vector2(600, 120)
const SPARE_STEP := 160.0
const SPARE_MAX := 6
## Where the spent keg goes (station pixels), out of the bottom of the picture.
const ROLL_OUT := Vector2(420, 560)
const ROLL_SEC := 0.5
## The bottom of the beer hose on the wall (pub_layout: BeerHose), in this node's space.
const HOSE_FROM := Vector3(0.0, 0.8, -0.2)
const HOSE_BITS := 7
const VALVE_AT := Vector2(90, 160)
const TWIST_SEC := 0.9
const KEG_M := 0.6
## Off the keg, the head hangs on its hose here (station pixels from the pallet).
const HEAD_HANG := Vector2(-95, 6)

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
var _spare_kegs: Array = []
var _spent_keg: Sprite3D
var _spent_t := -1.0
var _roll_from := Vector2.ZERO
var _hose: Array = []


func _build() -> void:
	super._build()
	_keg = psprite("keg", KEG_M)
	_head = psprite("coupler", 0.16)
	_valve = psprite("valve", 0.14)
	for i in SPARE_MAX:
		_spare_kegs.append(psprite("keg", KEG_M))
	_spent_keg = psprite("keg_empty", KEG_M)
	_spent_keg.visible = false
	# The hose down from the wall to the head, wherever it hangs.
	var hb := BoxMesh.new()
	hb.size = Vector3(0.03, 1.0, 0.03)
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.75, 0.72, 0.55)
	hm.roughness = 0.8
	for i in HOSE_BITS:
		var bit := MeshInstance3D.new()
		bit.mesh = hb
		bit.material_override = hm
		add_child(bit)
		_hose.append(bit)
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
	pretex(_keg, "keg_empty" if pallet == "empty" else "keg", KEG_M)
	# Rolled across from the rack, in the four steps the room moves in.
	var roll := ceilf(_roll / ROLL_SEC * 4.0) / 4.0
	put(_keg, PALLET.lerp(_roll_from, roll), 0.0)
	var spares: int = taproom.spares(building_key)
	for i in _spare_kegs.size():
		var s: Sprite3D = _spare_kegs[i]
		s.visible = i < spares
		put(s, SPARE_AT + Vector2(SPARE_STEP * float(i), 0.0), 0.02)
	_spent_keg.visible = _spent_t >= 0.0
	if _spent_keg.visible:
		put(_spent_keg, PALLET.lerp(ROLL_OUT, floorf(_spent_t / ROLL_SEC * 5.0) / 5.0), 0.0)
	_chalk.visible = pallet == "full" and _roll <= 0.0
	_chalk.text = "%d" % int(k["line"])
	_left_meter.visible = pallet == "full" and _roll <= 0.0
	if pallet == "full":
		set_meter(_left_meter, float(int(k["line"])) / float(PUB.KEG_PINTS), Vector2(-1, -1), RETRO_UI.C_AMBER if int(k["line"]) > 6 else RETRO_UI.C_RED, int(k["line"]) <= 3)
	# The head: on the keg's top when coupled, else hanging on its hose beside the keg at
	# the height of its top (over it, it hung out of the picture and could not be got
	# back: Richard, 20. 10.).
	var on := bool(k["coupled"]) and pallet != "none"
	var up := KEG_M * 0.98 if on else KEG_M * 0.72
	var at := PALLET if on else PALLET + HEAD_HANG
	if _twist >= 0.0:
		up = KEG_M + 0.1 - floorf(_twist / TWIST_SEC * 4.0) / 4.0 * 0.08
		at = PALLET
	put(_head, at, up)
	_lay_hose(_head.position + Vector3(0.0, 0.15, 0.0))
	# The quick coupler (gear): its own head on the hose.
	if BUSINESS.has_gear(building_key, "coupler"):
		retex(_head, "res://assets/textury/camp/gear_coupler.png", 0.16)
		if _head.texture != null:
			_head.offset = Vector2(0, float(_head.texture.get_height()) * 0.5)
	else:
		pretex(_head, "coupler", 0.16)
	var gas := float(k["gas"])
	set_meter(_gauge, gas, Vector2(PUB.GAS_LOW, PUB.GAS_HIGH), RETRO_UI.C_GREEN if PUB.gas_band(gas) == "OK" else RETRO_UI.C_RED)
	_valve.rotation.z = floorf(gas * 6.0) / 6.0 * 2.4


## Down from the wall and over to the head, the way a hose hangs.
func _lay_hose(to: Vector3) -> void:
	var bend := Vector3(HOSE_FROM.x, to.y, HOSE_FROM.z)
	var last := HOSE_FROM
	for i in _hose.size():
		var t := float(i + 1) / float(_hose.size())
		var p := HOSE_FROM.lerp(bend, t).lerp(bend.lerp(to, t), t)
		var d := p - last
		if d.length() > 0.001:
			var b := Basis(Quaternion(Vector3.DOWN, d.normalized()))
			(_hose[i] as MeshInstance3D).transform = Transform3D(b * Basis.from_scale(Vector3(1.0, d.length() + 0.012, 1.0)), (last + p) * 0.5)
		last = p


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
		out.append({"id": "line_keg", "node": _keg, "verb": verb})
	if spares > 0:
		out.append({"id": "spare", "on": _spare_kegs, "verb": "Roll a full keg onto the pallet (%d)" % spares if pallet == "none" else "Full kegs: %d" % spares})
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
			if str(k["pallet"]) == "empty":
				if bool(k["coupled"]):
					say("", "The head is still on it.")
					return
				taproom.set_keg(building_key, {"pallet": "none", "line": 0})
				_spent_t = 0.0
				sfx("keg_roll", -6.0)
			else:
				say("", "%d pints left in it." % int(k["line"]))
		"spare":
			if str(k["pallet"]) != "none":
				say("", "The pallet is taken.")
				return
			var beer := maxi(0, BUSINESS.stock_of(building_key, "beer"))
			var spares: int = taproom.spares(building_key)
			if beer <= 0 or spares <= 0:
				return
			_roll_from = SPARE_AT + Vector2(SPARE_STEP * float(mini(spares, SPARE_MAX) - 1), 0.0)
			taproom.set_keg(building_key, {"pallet": "full", "line": mini(PUB.KEG_PINTS, beer), "coupled": false})
			_roll = ROLL_SEC
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
	if _spent_t >= 0.0:
		_spent_t += delta
		if _spent_t >= ROLL_SEC:
			_spent_t = -1.0
	if _twist >= 0.0:
		# The quick coupler (gear): it clicks on in a moment.
		_twist += delta * (3.5 if BUSINESS.has_gear(building_key, "coupler") else 1.0)
		if _twist >= TWIST_SEC:
			_twist = -1.0
			taproom.set_keg(building_key, {"coupled": true})
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


## What is best to do at the keg now, step by step: the head off a spent keg, the keg rolled
## off, a full one rolled on, the head screwed on (hold), the gas into the green (drag the
## valve).
func next_hint() -> Dictionary:
	if taproom == null or building_key == "":
		return {}
	var k: Dictionary = taproom.keg(building_key)
	var pallet := str(k["pallet"])
	if pallet == "empty":
		return {"node": _head, "gesture": "click"} if bool(k["coupled"]) else {"node": _keg, "gesture": "click"}
	if pallet == "none":
		return {"node": _spare_kegs[0], "gesture": "click"} if taproom.spares(building_key) > 0 else {"ui": "books"}
	if not bool(k["coupled"]):
		return {"node": _head, "gesture": "hold"}
	var band := PUB.gas_band(float(k["gas"]))
	if band != "OK":
		return {"node": _valve, "gesture": "drag", "to": VALVE_AT + Vector2(0, -40 if float(k["gas"]) < PUB.GAS_LOW else 40)}
	return {"tab": "tap"} if not orders_here("tap").is_empty() else {}


## The keg will not pour (spent, the head off, no beer): red, on the cellar's tab
## wherever you are (the brief: "when the keg wants changing is seen on the frame");
## the gas off the green or the keg nearly spent: amber.
func alert() -> int:
	if taproom == null or building_key == "":
		return 0
	var trouble: String = taproom.tap_trouble(building_key)
	if trouble != "":
		return 2
	var k: Dictionary = taproom.keg(building_key)
	if PUB.gas_band(float(k["gas"])) != "OK" or int(k.get("line", 0)) <= 6:
		return 1
	return 0


func has_rail() -> bool:
	return false


func big_ticket() -> Dictionary:
	return {}


## The bare glove on the keg, the head and the valve (a grip, a press).
func hand_tool() -> String:
	var id := _held if _held != "" else _hover
	return "press" if id == "valve" else "open"

# ── debug (tools/pub_check.gd) ───────────────────────────────────────────────

func debug_click(id: String) -> void:
	if id == "coupler_on":
		taproom.set_keg(building_key, {"coupled": true})
		return
	_press(id)
