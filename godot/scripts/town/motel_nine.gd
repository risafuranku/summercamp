extends RefCounted

## Number nine, the apartment (motel_furnish.gd builds it, motel_view.gd keeps its door,
## bathroom, bed and night): twenty-five dollars. There is a fridge.
##   the minibar  hums; the little bottles in it, three dollars each, one and you feel it;
##   the armchair sit in it and the set is in front of you;
##   the set      as in four, and the recorder under it: there is a tape in it, and the tape
##                is this room, from up in the corner over the door, now. You on it. Some
##                nights somebody on the bed who is not on the bed, and every time you look
##                nearer, until the tape stops by itself;
##   the radiogram  the lid, the worn needle under the station;
##   the photograph a wedding, one of them scratched out;
##   by itself    (what wakes you as the set does in four) the tape runs.

const PLAN = preload("res://scripts/town/motel_plan.gd")
const FURN = preload("res://scripts/town/motel_furnish.gd")
const ROOMS = preload("res://scripts/town/motel_rooms.gd")
const LOOKS = preload("res://scripts/coop/warden_looks.gd")
const SFX := "res://assets/sfx/"
const CAMP := "res://assets/textury/camp/"
const BOTTLE_PRICE := 3
const CORNER := Vector3(1.32, 2.46, 1.95)
const CORNER_AIM := Vector3(-0.3, 0.45, -0.25)
## Where the one on the tape is, step by step: on the bed, its foot, the rug, behind you.
const STAGES := [Vector3(-0.35, 0.42, 1.0), Vector3(0.72, 0.0, 1.05), Vector3(0.62, 0.0, -0.05)]

## What is left in the minibar (the game's, not one visit's).
static var bottles := 4

var view                         # motel_view.gd
var room                         # town_room.gd
var parts: Dictionary
var bar_open := false
var tape_in := false
var _hum: AudioStreamPlayer
var _whirr: AudioStreamPlayer
var _bar_light: OmniLight3D
var _me: Sprite3D
var _them: Sprite3D
var _stage := -1
var _stage_t := 0.0
var _flick_t := 6.0
var _rng := RandomNumberGenerator.new()


func _init(p_view, p_room) -> void:
	view = p_view
	room = p_room
	parts = view.parts
	_rng.randomize()


func radio_voice() -> String:
	return "gram"


func spots() -> Dictionary:
	var r := func(p: float, y: float) -> Vector3: return Vector3(deg_to_rad(p), deg_to_rad(y), 0.0)
	var a := FURN.ARMCHAIR_AT
	return {
		"aisle": {"at": Vector3(0.85, 1.6, 0.1), "rot": r.call(-8.0, 0.0)},
		"bedfoot": {"at": Vector3(0.9, 1.6, 1.06), "rot": r.call(-16.0, 90.0)},
		"minibar": {"at": Vector3(0.22, 1.6, 0.72), "rot": r.call(-44.0, -90.0)},
		"window": {"at": Vector3(0.68, 1.6, -1.4), "rot": r.call(-4.0, 0.0)},
		"tv": {"at": Vector3(0.5, 1.6, -0.75), "rot": r.call(-26.0, -42.0)},
		"armchair": {"at": Vector3(a.x, 1.14, a.z), "rot": r.call(-3.0, -55.0)},
		"radio": {"at": Vector3(-0.2, 1.6, -1.05), "rot": r.call(-36.0, 90.0)},
	}


func ways() -> Array:
	return [["room", "bedfoot"], ["room", "minibar"], ["bedfoot", "minibar"], ["bedfoot", "aisle"], ["minibar", "aisle"],
		["aisle", "window"], ["aisle", "tv"], ["window", "tv"], ["aisle", "armchair"], ["aisle", "radio"],
		["armchair", "radio"], ["armchair", "tv"]]


func from_bed() -> Array:
	return ["phone", "lamps", "clock", "photo"]


func things(_hour: float) -> void:
	var w := PLAN.ROOM_W
	if parts.get("minibar") != null:
		room._hot_box("minibar", Vector3(w * 0.5 - 0.34, 0.48, 0.72), Vector3(0.1, 0.95, 0.72), [parts["minibar"]])
	if parts.get("vcr") != null:
		room._hot_box("vcr", FURN.TABLE_AT + Vector3(0.05, 0.76, 0.1), Vector3(0.42, 0.12, 0.3), [parts["vcr"]])
	if parts.get("radio") != null:
		room._hot_box("radio", Vector3(-w * 0.5 + 0.3, 0.42, -1.05), Vector3(0.14, 0.84, 1.45), [parts["radio"]])
	if parts.get("armchair") != null:
		room._hot_box("armchair", FURN.ARMCHAIR_AT + Vector3(0, 0.5, 0), Vector3(0.7, 1.0, 0.7), [parts["armchair"]])
	if parts.get("photo") != null:
		room._hot_box("photo", (parts["photo"] as Node3D).position + Vector3(0.03, 0, 0), Vector3(0.06, 0.66, 0.5), [parts["photo"]])
	_hum = view._player(-27.0)
	_whirr = view._player(-60.0)
	view._loop_on(_hum, "motel/minibar_hum.ogg", -28.0)
	_bar_light = OmniLight3D.new()
	_bar_light.light_color = Color(0.82, 0.9, 1.0)
	_bar_light.light_energy = 0.55
	_bar_light.omni_range = 1.8
	_bar_light.position = Vector3(w * 0.5 - 0.55, 0.62, 0.72)
	_bar_light.visible = false
	room._root.add_child(_bar_light)


func click(id: String) -> bool:
	match id:
		"minibar":
			view._walker.go("minibar", func(): _minibar())
		"vcr":
			view._walker.go("tv", func(): _tape(false))
		"eject":
			if tape_in:
				_tape(false)
		"radio":
			view._walker.go("radio", func():
				view.radio.toggle())
		"armchair":
			view._walker.go("armchair", func():
				var chair: Node3D = parts.get("armchair")
				if chair != null:
					chair.visible = false
				view._play("motel/armchair.mp3", -8.0))
		"photo":
			view._walker.go("bedfoot", func(): view._look_at("photo"))
		_:
			return false
	return true


func _set_bar(on: bool, quiet := false) -> void:
	if on == bar_open:
		return
	bar_open = on
	var mb: MeshInstance3D = parts.get("minibar")
	var path := CAMP + ("minibar_open.png" if on else "minibar.png")
	if mb != null and ResourceLoader.exists(path):
		(mb.material_override as StandardMaterial3D).albedo_texture = load(path)
	_bar_light.visible = on
	if not quiet:
		view._play("motel/minibar_open.mp3" if on else "motel/minibar_shut.mp3", -8.0)


## Shut: open it. Open: a bottle, while there are any, on the bill at once.
func _minibar() -> void:
	if not bar_open:
		_set_bar(true)
		return
	if bottles <= 0:
		_set_bar(false)
		return
	if CoreRoot.get_money() < BOTTLE_PRICE or not CoreRoot.actions.spend_money(BOTTLE_PRICE):
		view._play("director/knock_wrong.mp3", -14.0)
		return
	bottles -= 1
	view._play("motel/bottle_cap.mp3", -8.0)
	room.get_tree().create_timer(0.7).timeout.connect(func():
		if not view._alive():
			return
		view._play("motel/gulp.mp3", -7.0)
		var trip = room.get_parent()
		var pk = trip.get("pockets") if trip != null else null
		if pk != null:
			pk.set("drunk", float(pk.get("drunk")) + 0.6))


## The door swings to behind you; out of the armchair you stand up.
func walked(to: String) -> void:
	if bar_open and to != "minibar":
		_set_bar(false)
	var chair: Node3D = parts.get("armchair")
	if chair != null and to != "armchair":
		chair.visible = true


## The tape in or out. `by_itself`: nobody pressed anything.
func _tape(by_itself: bool) -> void:
	if tape_in:
		tape_in = false
		view._play("motel/vcr_out.mp3", -9.0)
		_tape_stop()
		return
	tape_in = true
	if not by_itself:
		view._play("motel/vcr_in.mp3", -9.0)
	var wait := 0.2 if by_itself else 2.1
	room.get_tree().create_timer(wait).timeout.connect(func():
		if view._alive() and tape_in:
			_tape_run())


func _tape_run() -> void:
	view._loop_on(_whirr, "motel/vcr_run.ogg", -24.0)
	var eye := Transform3D(Basis.looking_at((CORNER_AIM - CORNER).normalized(), Vector3.UP), CORNER)
	view.tape_on(eye)
	_make_me()
	# Who else is on it tonight, the worse you are the likelier.
	_stage = -1
	var night: bool = view._night(view._now())
	if night and _rng.randf() < 0.22 + 0.65 * view._low():
		_them = view._figure(room._root, STAGES[0])
		if _them != null:
			_them.layers = ROOMS.ONLY_MIRROR
			_stage = 0
			_stage_t = _rng.randf_range(10.0, 18.0)


func _tape_stop() -> void:
	if _whirr != null and _whirr.playing:
		_whirr.stop()
	view.tape_off()
	for nd in [_me, _them]:
		if nd != null and is_instance_valid(nd):
			(nd as Node).queue_free()
	_me = null
	_them = null
	_stage = -1


## You on the tape, where you are.
func _make_me() -> void:
	if _me != null:
		return
	var look: Dictionary = Coop.my_look() if Coop.has_method("my_look") else {}
	var tex: Texture2D = LOOKS.texture(int(look.get("m", 1)), int(look.get("c", 0)), "stand")
	if tex == null:
		return
	_me = Sprite3D.new()
	_me.name = "OnTheTape"
	_me.texture = tex
	_me.pixel_size = 1.72 / float(tex.get_height())
	_me.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_me.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_me.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_me.shaded = true
	_me.offset = Vector2(0, tex.get_height() * 0.5)
	_me.layers = ROOMS.ONLY_MIRROR
	room._root.add_child(_me)


func tick(delta: float) -> void:
	if tape_in and _me != null:
		var p: Vector3 = room._cam.position
		_me.position = Vector3(p.x, 0.0, p.z)
	if _stage >= 0 and _them != null and is_instance_valid(_them):
		_stage_t -= delta
		if _stage_t <= 0.0:
			_stage += 1
			_stage_t = _rng.randf_range(9.0, 16.0)
			if _stage < STAGES.size():
				_them.position = STAGES[_stage]
			elif _stage == STAGES.size():
				# Right behind you on the tape.
				var p: Vector3 = room._cam.position
				var back: Vector3 = room._cam.global_basis.z
				_them.position = Vector3(p.x + back.x * 0.5, 0.0, p.z + back.z * 0.5)
				_stage_t = 2.6
			else:
				# And the tape has had enough.
				view._play("backroom/tv_off.mp3", -6.0)
				tape_in = false
				room.get_tree().create_timer(0.6).timeout.connect(func():
					if view._alive():
						view._play("motel/vcr_out.mp3", -8.0))
				_tape_stop()
	# The chandelier, when you are not well.
	if view.ceiling_on and view.lights.has("ceiling"):
		_flick_t -= delta
		var l: OmniLight3D = view.lights["ceiling"]
		if _flick_t <= 0.0:
			_flick_t = _rng.randf_range(5.0, 22.0) / maxf(0.25, view._low() * 2.0)
			if view._low() > 0.15:
				l.visible = false
				room.get_tree().create_timer(0.09).timeout.connect(func():
					if is_instance_valid(l):
						l.visible = view.ceiling_on)


## What in four is the set coming on by itself: the tape runs.
func set_by_itself() -> void:
	if tape_in:
		return
	view._play("backroom/tv_on.mp3", -6.0)
	_tape(true)


func woken(_kind: String) -> void:
	pass


func morning(_hour_now: float) -> void:
	if tape_in:
		tape_in = false
		_tape_stop()
	_set_bar(false, true)


func state() -> Array:
	return [bar_open, tape_in, bottles]


func take(st: Array, quiet: bool) -> void:
	if st.size() < 3:
		return
	_set_bar(bool(st[0]), quiet)
	bottles = int(st[2])
	if bool(st[1]) != tape_in:
		_tape(quiet)


func close() -> void:
	if tape_in:
		_tape_stop()
