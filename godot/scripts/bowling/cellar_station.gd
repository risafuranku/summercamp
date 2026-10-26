extends "res://scripts/business/station3d.gd"

## The pinsetting machine's gear train in the bowling alley's cellar (the user, 21. 10.:
## "a machine you buy in the books that now and then needs mending: gears in the cellar,
## eerie and morbidly creepy"; scripts/bowling/bowling_interior.gd hosts it in the cellar
## under the hall, bowling_layout.cellar()). The machine's front on the back wall: the big
## gear, the pinion it drives with the chain wheel on its shaft, the motor, the crank on the
## big gear's hub, the reset lever, the lamp.
##
## The Stavomat S-12 turns, clanking, while the lanes over it are set. When something gets
## caught where the big gear meets the pinion (bowling.gd: a broken pin, a rag, a crushed
## shoe, a clump of hair, a rat) everything stops, the lamp goes red, every lane upstairs
## waits; its ticket is on the rail. Freeing it: pull the thing out from between the teeth
## (drag it away, a few tugs: it is wedged; out it comes and drops on the floor), turn the
## crank back two turns (round and round), pull the lever: the motor groans and it runs
## again. Papa's stars by how long the lanes stood. The Brnoswick A-2 (its enamel, its
## polished chrome wheels, a clean motor) only purrs: nothing to do here.
## Design pixels on the machine's front (640 x 360 over its 3.2 m by 1.8 m, 200 a metre).

const BOWLING := preload("res://scripts/bowling/bowling.gd")
const BOARD_TEXT := preload("res://scripts/bowling/board_text.gd")
const LANG := preload("res://scripts/lang.gd")
const BTEX := "res://assets/textury/bowling/"
const GEAR_AT := Vector2(200, 200)
const GEAR_R := 115.0
const PINION_R := 50.0
## The pinion up and to the right of the big gear, meshing with it; the chain wheel on the
## pinion's shaft, in front of it.
const MESH_ANGLE := -0.49
const MOTOR_AT := Vector2(505, 262)
const LEVER_AT := Vector2(590, 268)
const LAMP_AT := Vector2(590, 64)
## How the gears turn running (the big gear, radians a second; the Brnoswick quicker).
const SPIN := 0.55
## Tugs to pull each thing out, and whether it comes out wet.
const TUGS := {"pin": 3, "shoe": 3, "rag": 4, "hair": 5, "rat": 2}
const WET := ["hair", "rat", "rag"]
## Turns of the crank back, and how far a tug must pull (design px).
const TURNS := 2
const TUG_PX := 30.0
## Where the crank turns (its boss) and where its handle is, and the lever's foot: shares of
## their pictures.
const CRANK_PIVOT := Vector2(0.18, 0.14)
const CRANK_HANDLE := Vector2(0.85, 0.85)
const LEVER_FOOT := Vector2(0.48, 0.9)

var _gear: Sprite3D
var _pinion: Sprite3D
var _sprocket: Sprite3D
var _motor: Sprite3D
var _crank: Sprite3D
var _lever: Sprite3D
var _jam: Sprite3D
var _lamp: MeshInstance3D
var _lamp_mat: StandardMaterial3D
var _plate: SubViewport
var _spin := 0.0
var _spin_speed := 0.0
## The repair under way: the step ("pull", "crank", "lever"; "" running), the tugs made,
## the crank's turns, what is caught.
var _step := ""
var _tugs := 0
var _turned := 0.0
var _crank_was := 0.0
var _crank_rot := 0.0
var _jam_kind := ""
var _press_at := Vector2(-1, -1)
var _lever_t := -9.0
var _icons: Dictionary = {}
## The crank's arm, its boss to its handle, as drawn (radians, design px: y down).
var _crank_arm := 0.0
## Which machine's parts are on the frame ("machine" the Stavomat's iron, "brnoswick").
var _parts := ""


func _build() -> void:
	fine = 1.5
	if state == null:
		state = BOWLING.of(get_tree())
	_gear = sprite(BTEX + "gear_big.png", GEAR_R * 2.0 / 200.0)
	put(_gear, GEAR_AT, 0.03)
	_pinion = sprite(BTEX + "gear_small.png", PINION_R * 2.0 / 200.0)
	put(_pinion, _pinion_at(), 0.04)
	_sprocket = sprite(BTEX + "sprocket.png", 0.34)
	put(_sprocket, _pinion_at(), 0.06)
	_motor = sprite(BTEX + "motor.png", 0.78)
	put(_motor, MOTOR_AT, 0.05)
	_crank = sprite(BTEX + "crank.png", 0.5)
	put(_crank, GEAR_AT, 0.09)
	if _crank.texture != null:
		# Turned about its boss on the big gear's hub.
		var cw := float(_crank.texture.get_width())
		var ch := float(_crank.texture.get_height())
		_crank.offset = Vector2(cw * (0.5 - CRANK_PIVOT.x), -ch * (0.5 - CRANK_PIVOT.y))
		_crank_arm = atan2(ch * (CRANK_HANDLE.y - CRANK_PIVOT.y), cw * (CRANK_HANDLE.x - CRANK_PIVOT.x))
	_lever = sprite(BTEX + "lever.png", 0.62)
	put(_lever, LEVER_AT, 0.05)
	if _lever.texture != null:
		# Turned about its foot.
		var lw := float(_lever.texture.get_width())
		var lh := float(_lever.texture.get_height())
		_lever.offset = Vector2(lw * (0.5 - LEVER_FOOT.x), lh * (LEVER_FOOT.y - 0.5))
	_jam = sprite(BTEX + "jam_rag.png", 0.3)
	_jam.visible = false
	_lamp = MeshInstance3D.new()
	_lamp.name = "Lamp"
	var sm := SphereMesh.new()
	sm.radius = 0.045
	sm.height = 0.07
	_lamp.mesh = sm
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.emission_enabled = true
	_lamp.material_override = _lamp_mat
	_lamp.set_meta("retro_skip", true)
	_lamp.position = local_at(LAMP_AT, 0.04)
	add_child(_lamp)
	# The maker's plate: stencilled on the Stavomat's frame, chrome letters on the Brnoswick.
	_plate = BOARD_TEXT.new()
	_plate.name = "PlateWords"
	add_child(_plate)
	_plate.setup(Vector2i(112, 16), RETRO_UI.FONT_LABEL, 8, Color(0.86, 0.84, 0.76), HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	BOARD_TEXT.quad(self, _plate, Vector2(2.24, 0.32), local_at(Vector2(300, 36), 0.02))
	for k in ["pin", "shoe", "rag", "hair", "rat"]:
		var p := BTEX + "jam_%s.png" % k
		_icons[k] = load(p) if ResourceLoader.exists(p) else null
	_icons["gear"] = load(BTEX + "gear_small.png") if ResourceLoader.exists(BTEX + "gear_small.png") else null


## The parts of the machine the books have: the Stavomat's crusted iron, or the Brnoswick's
## polished chrome and clean enamel motor (no crank to turn: it never jams).
func _dress(mach: String) -> void:
	var look := "brnoswick" if mach == "brnoswick" else "machine"
	if look == _parts:
		return
	_parts = look
	var brn := look == "brnoswick"
	var pre := "brn_" if brn and ResourceLoader.exists(BTEX + "brn_gear_big.png") else ""
	retex(_gear, BTEX + pre + "gear_big.png", GEAR_R * 2.0 / 200.0)
	retex(_pinion, BTEX + pre + "gear_small.png", PINION_R * 2.0 / 200.0)
	retex(_motor, BTEX + pre + "motor.png", 0.78)
	retex(_lever, BTEX + pre + "lever.png", 0.62)
	if _lever.texture != null:
		var lw := float(_lever.texture.get_width())
		var lh := float(_lever.texture.get_height())
		_lever.offset = Vector2(lw * (0.5 - LEVER_FOOT.x), lh * (LEVER_FOOT.y - 0.5))
	_sprocket.visible = not brn
	_crank.visible = not brn


func _pinion_at() -> Vector2:
	return GEAR_AT + Vector2(cos(MESH_ANGLE), sin(MESH_ANGLE)) * (GEAR_R + PINION_R)


## Where the teeth meet: what gets caught sits there.
func _contact() -> Vector2:
	return GEAR_AT + Vector2(cos(MESH_ANGLE), sin(MESH_ANGLE)) * GEAR_R


func sfx_dir() -> String:
	return "res://assets/sfx/bowling/"


func ding_sound() -> String:
	return "res://assets/sfx/bowling/machine_jam.mp3"


func has_rail() -> bool:
	return true


# ── the record ───────────────────────────────────────────────────────────────

func machine() -> String:
	return str(state.machine_of(building_key)) if state != null and building_key != "" else ""


func jammed() -> bool:
	return state != null and building_key != "" and bool(state.jammed(building_key))


func _stood() -> float:
	if not jammed():
		return 0.0
	return float(state.now()) - float(state.jam_of(building_key).get("since", state.now()))


func rail_tickets() -> Array:
	if not jammed():
		return []
	var age := _stood()
	return [{"id": "jam", "name": "Stavomat", "jam": str(state.jam_of(building_key).get("jam", "")), "age": age,
		"left": 1.0 - clampf(age / 90.0, 0.0, 1.0), "band": 0 if age < 20.0 else (1 if age < 45.0 else 2), "picked": true,
		"sig": str(state.jam_of(building_key).get("jam", ""))}]


func picked_ticket() -> String:
	return "jam" if jammed() else ""


func big_ticket() -> Dictionary:
	var r := rail_tickets()
	return r[0] if not r.is_empty() else {}


func ticket_items(t: Dictionary) -> Array:
	return [{"icon": _icons.get(str(t.get("jam", "")), _icons.get("gear")), "word": "Jammed"}]


func checklist(_t: Dictionary) -> Array:
	var need := int(TUGS.get(_jam_kind, 3))
	return [
		{"text": LANG.f("Pull it out %d/%d", [mini(_tugs, need), need]), "state": "done" if _step in ["crank", "lever"] else "todo"},
		{"text": LANG.f("Crank it back %d/%d", [mini(int(_turned / TAU), TURNS), TURNS]), "state": "done" if _step == "lever" else "todo"},
		{"text": tr("Pull the lever"), "state": "todo"},
	]


## The rail's ticket: no face on this one, the thing caught in the gears instead.
func draw_ticket(c: Control, t: Dictionary, size: Vector2) -> void:
	var paper := _paper_tex()
	if paper != null:
		c.draw_texture_rect(paper, Rect2(Vector2.ZERO, size), false)
	else:
		c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.92, 0.88, 0.76))
	var f: Font = RETRO_UI.FONT_TEXT
	c.draw_string(f, Vector2(3, 9), "S-12", HORIZONTAL_ALIGNMENT_LEFT, size.x - 4, 8, Color(0.55, 0.1, 0.08))
	var ic: Texture2D = _icons.get(str(t.get("jam", "")), _icons.get("gear"))
	if ic != null:
		var sc := minf(1.0, 20.0 / maxf(ic.get_width(), ic.get_height()))
		var isz := (ic.get_size() * sc).floor()
		c.draw_texture_rect(ic, Rect2(Vector2(floorf((size.x - isz.x) * 0.5), 12 + floorf((20.0 - isz.y) * 0.5)), isz), false)
	var word := tr("STOP")
	var ww := f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	c.draw_string(f, Vector2(maxf(1.0, floorf((size.x - ww) * 0.5)), 40), word, HORIZONTAL_ALIGNMENT_LEFT, size.x - 2, 8, Color(0.62, 0.08, 0.05))
	var band := int(t.get("band", 0))
	var bar := Rect2(2, size.y - 5, size.x - 4, 3)
	c.draw_rect(bar, Color(0.1, 0.08, 0.06))
	if band < 2 or int(_t * 4.0) % 2 == 0:
		c.draw_rect(Rect2(bar.position, Vector2(ceilf(bar.size.x * clampf(float(t.get("left", 1.0)), 0.0, 1.0)), bar.size.y)), [RETRO_UI.C_GREEN, RETRO_UI.C_AMBER, RETRO_UI.C_RED][clampi(band, 0, 2)])


## The big ticket: the machine's name, what is caught, the three steps, how long the lanes
## have stood.
func draw_big_ticket(c: Control, r: Rect2, t: Dictionary) -> void:
	var paper := _paper_tex()
	if paper != null:
		c.draw_texture_rect(paper, r, false)
	else:
		c.draw_rect(r, Color(0.92, 0.88, 0.76))
	c.draw_string(RETRO_UI.FONT_LABEL, Vector2(r.position.x + 5, r.position.y + 13), "STAVOMAT S-12", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, 8, Color(0.55, 0.1, 0.08))
	var ic: Texture2D = _icons.get(str(t.get("jam", "")), null)
	if ic != null:
		var sc := minf(2.0, 26.0 / maxf(ic.get_width(), ic.get_height()))
		var isz := (ic.get_size() * sc).floor()
		c.draw_texture_rect(ic, Rect2(Vector2(r.end.x - isz.x - 5, r.position.y + 17), isz), false)
	var band := int(t.get("band", 0))
	var bar := Rect2(r.position.x + 5, r.position.y + 19, r.size.x - 44, 4)
	c.draw_rect(bar.grow(1.0), Color(0.1, 0.08, 0.06, 0.9))
	if band < 2 or int(_t * 4.0) % 2 == 0:
		c.draw_rect(Rect2(bar.position, Vector2(ceilf(bar.size.x * clampf(float(t.get("left", 1.0)), 0.0, 1.0)), bar.size.y)), [RETRO_UI.C_GREEN, RETRO_UI.C_AMBER, RETRO_UI.C_RED][clampi(band, 0, 2)])
	var ink := Color(0.16, 0.12, 0.1)
	var ok := Color(0.1, 0.45, 0.12)
	var y := r.position.y + 50
	for line in checklist(t):
		var st := str(line.get("state", "todo"))
		var box := Rect2(r.position.x + 6, y - 7, 7, 7)
		var col := ok if st == "done" else ink
		c.draw_rect(box, Color(1, 1, 1, 0.35))
		c.draw_rect(box, col, false, 1.0)
		if st == "done":
			for pxy in [Vector2(1, 3), Vector2(2, 4), Vector2(3, 5), Vector2(4, 4), Vector2(5, 3), Vector2(5, 2), Vector2(6, 1)]:
				c.draw_rect(Rect2(box.position + pxy, Vector2.ONE), ok)
		c.draw_string(RETRO_UI.FONT_TEXT, Vector2(r.position.x + 17, y), str(line.get("text", "")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20, 8, col)
		y += 13


# ── what is shown ────────────────────────────────────────────────────────────

func _show() -> void:
	if state == null or building_key == "":
		return
	var mach := machine()
	var jam := str(state.jam_of(building_key).get("jam", "")) if jammed() else ""
	# A jam that came, or went (freed here, by the other warden or by the hand).
	if jam != _jam_kind:
		_jam_kind = jam
		_step = "pull" if jam != "" else ""
		_tugs = 0
		_turned = 0.0
		_jam.visible = jam != ""
		if jam != "":
			retex(_jam, BTEX + "jam_%s.png" % jam, 0.34 if jam != "hair" else 0.4)
	var running := mach != "" and jam == ""
	var brn := mach == "brnoswick"
	_plate.show_text("BRNOSWICK A-2" if brn else "STAVOMAT S-12")
	_plate.set_colour(Color(0.85, 0.12, 0.1) if brn else Color(0.86, 0.84, 0.76))
	_dress(mach)
	# The lamp: green running, red blinking jammed, out without a machine.
	if jam != "":
		var on := int(_t * 3.0) % 2 == 0
		_lamp_mat.albedo_color = Color(0.5, 0.05, 0.03)
		_lamp_mat.emission = Color(1.0, 0.1, 0.05)
		_lamp_mat.emission_energy_multiplier = 1.6 if on else 0.1
	else:
		_lamp_mat.albedo_color = Color(0.08, 0.3, 0.08) if running else Color(0.1, 0.1, 0.1)
		_lamp_mat.emission = Color(0.2, 1.0, 0.25)
		_lamp_mat.emission_energy_multiplier = 0.9 if running else 0.0
	# The jammed thing wedged in the teeth, pulled out a little with every tug, following a
	# held pointer as far as it gives.
	if _jam.visible:
		var out := _contact() + Vector2(14, -18) * (float(_tugs) / float(maxi(1, int(TUGS.get(_jam_kind, 3)))))
		if _held == "jam" and _mouse_free.x >= 0.0 and _press_at.x >= 0.0:
			out += (_mouse_free - _press_at).limit_length(22.0) * 0.6
		put(_jam, out, 0.08)
		_jam.rotation.z = sin(_t * 31.0) * 0.04 if _held == "jam" else 0.0
	# The motor hums, shakes while it strains against a jam.
	var shake := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * (2.4 if jam != "" else (0.6 if running else 0.0))
	put(_motor, MOTOR_AT + shake, 0.05)
	# The lever: up, pulled down when it was just pulled.
	var lk := clampf((_t - _lever_t) / 0.18, 0.0, 1.0)
	var back := clampf((_t - _lever_t - 0.9) / 0.4, 0.0, 1.0)
	_lever.rotation.z = -1.1 * lk * (1.0 - back)


func _process(delta: float) -> void:
	super._process(delta)
	if state == null or building_key == "":
		return
	# The train turning (run whoever is in the cellar): slowing to a stop on a jam, picking
	# up after the lever.
	var mach := machine()
	var target := 0.0
	if mach == "machine" and not jammed():
		target = SPIN
	elif mach == "brnoswick":
		target = SPIN * 1.6
	_spin_speed = move_toward(_spin_speed, target, delta * (0.8 if target > 0.0 else 3.0))
	_spin += _spin_speed * delta
	_gear.rotation.z = _spin
	_pinion.rotation.z = -_spin * GEAR_R / PINION_R + 0.13
	_sprocket.rotation.z = _pinion.rotation.z
	if _held != "crank":
		_crank.rotation.z = _spin + _crank_rot


# ── what can be done ─────────────────────────────────────────────────────────

func _spots() -> Array:
	var out: Array = []
	match _step:
		"pull":
			out.append({"id": "jam", "node": _jam, "verb": tr("Pull out what is caught in the gears")})
		"crank":
			out.append({"id": "crank", "node": _crank, "verb": tr("Turn the crank back")})
		"lever":
			out.append({"id": "lever", "node": _lever, "verb": tr("Pull the lever")})
	return out


func _press(id: String) -> void:
	_press_at = _mouse_free
	match id:
		"crank":
			_crank_was = (_mouse_free - GEAR_AT).angle()
		"lever":
			_pull_lever()


func _drag(at: Vector2) -> void:
	if _held != "crank" or at.x < 0.0:
		return
	# Round and round about the hub: the crank follows the pointer, the gears give a little.
	var a := (at - GEAR_AT).angle()
	var d := wrapf(a - _crank_was, -PI, PI)
	_crank_was = a
	var before := int(_turned / (PI * 0.5))
	_turned += absf(d)
	_spin -= absf(d) * 0.08
	# The handle where the pointer is (design y runs down, the node's y up).
	_crank.rotation.z = -(a - _crank_arm)
	_crank_rot = _crank.rotation.z - _spin
	if int(_turned / (PI * 0.5)) > before:
		sfx("crank", -12.0, randf_range(0.9, 1.15))
	if _turned >= TURNS * TAU:
		_step = "lever"
		sfx("lever", -16.0, 1.4)


func _release(id: String) -> void:
	if id != "jam" or _step != "pull":
		return
	var pulled := _mouse_free.distance_to(_press_at) if _mouse_free.x >= 0.0 and _press_at.x >= 0.0 else 0.0
	if pulled < TUG_PX:
		return
	_tugs += 1
	var wet := _jam_kind in WET
	sfx("tug_wet" if wet else "tug_hard", -8.0, randf_range(0.9, 1.1))
	if _tugs >= int(TUGS.get(_jam_kind, 3)):
		# Out: down onto the floor in front of the machine.
		_jam.visible = false
		var floor_at := global_transform * Vector3(local_at(_contact(), 0.3).x, -1.08, 0.6)
		fly(BTEX + "jam_%s.png" % _jam_kind, 0.32, local_at(_contact(), 0.1), floor_at, 0.45, 0.15)
		sfx("jam_drop", -6.0, randf_range(0.9, 1.05))
		_step = "crank"


## The lever: the jam cleared and cranked free, the machine runs again.
func _pull_lever() -> void:
	if _step != "lever" or not jammed():
		return
	_lever_t = _t
	sfx("lever", -6.0)
	var stood := _stood()
	state.unjam(building_key)
	sfx("machine_restart", -4.0)
	_step = ""
	var speed := 1.0 - clampf((stood - 8.0) / 70.0, 0.0, 1.0)
	var pts := RULES_BIZ.score(speed, 1.0)
	var r := RULES_BIZ.reward(pts, 2)
	score_card({"ok": true, "score": pts, "stars": int(r["stars"]), "tip": 0, "amount": 0, "speed": speed, "build": 1.0}, "Pinsetter",
		{"id": "jam", "name": "Stavomat", "left": 1.0 - clampf(stood / 90.0, 0.0, 1.0), "band": 0 if stood < 20.0 else (1 if stood < 45.0 else 2)})


## What is best to do: the thing pulled away from the teeth, the crank turned round, the lever.
func next_hint() -> Dictionary:
	match _step:
		"pull":
			return {"node": _jam, "gesture": "drag", "to": _contact() + Vector2(60, -60)}
		"crank":
			return {"node": _crank, "gesture": "rub"}
		"lever":
			return {"node": _lever, "gesture": "click"}
	return {}


func alert() -> int:
	if not jammed():
		return 0
	return 2 if _stood() >= 45.0 else 1


func bar_text() -> String:
	return tr("LANES STOPPED") if jammed() else ""


func hand_tool() -> String:
	var id := _held if _held != "" else _hover
	if id == "lever":
		return "press"
	return "open"


## Where the "guest" of the ticket is: the machine itself.
func guest_point(_t: Dictionary) -> Vector3:
	return global_transform * local_at(_contact(), 0.2)


# ── debug (the shot drivers) ─────────────────────────────────────────────────

## The repair done step by step as a warden would: the tugs, the turns, the lever. Returns
## the steps taken (0: nothing jammed).
func debug_repair() -> int:
	if not jammed():
		return 0
	_show()
	var n := 0
	while _step == "pull" and n < 12:
		_press_at = _contact()
		_mouse_free = _contact() + Vector2(50, -50)
		_held = "jam"
		_release("jam")
		_held = ""
		n += 1
	if _step == "crank":
		_held = "crank"
		_crank_was = 0.0
		for k in TURNS * 8 + 1:
			_drag(GEAR_AT + Vector2(cos(k * PI / 4.0), sin(k * PI / 4.0)) * 60.0)
		_held = ""
		n += 1
	_pull_lever()
	return n + 1


## The repair stopped halfway (the first tug and nothing more), for a picture of it.
func debug_tug() -> void:
	_show()
	if _step == "pull":
		_press_at = _contact()
		_mouse_free = _contact() + Vector2(50, -50)
		_held = "jam"
		_release("jam")
		_held = ""
