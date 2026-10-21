extends Node3D

## The caravan's things, alive (scripts/caravan_interior.gd builds the room and hands its
## clicks here; the user 21. 10.: "new sprites, Build-engine textures, micro-interactions
## and fun animations"). The furniture wears Build faces (Grok, tools/artgen/
## prompts_caravan.tsv: camp/cv_*.png), the small things are Build sprites, and a click
## on one of them:
##   the fridge        swings open on its little bulb and the cold (beer, gherkins, eggs),
##                     the hum louder; shut with a thud
##   the locker        flips up, and the cards and the tin of sprats fall out on the worktop
##   the gas           click-click-whump, a blue ring of flame under the kettle; it comes to
##                     the boil and whistles, steam puffing; again, off
##   the tap           the pump buzzes, water runs into the sink
##   the radio         crackles, sweeps, finds a song (the camp radio's own, tinny)
##   the telly  (Lv3)  the whine, the snow, the test card glowing blue on you; off
##   the heater (Lv3)  clicks, pops, glows orange and ticks as it warms
##   the teddy         squeaks, flops over, is sat up again
##   the cat           some days, by day, curled up asleep on the bench or a bunk: opens
##                     its eyes, sits up and stares; purrs; or jumps down and trots off.
##                     Once in a long while at night it sits there staring, and when you
##                     look again there is no cat.
##   the dome lamp     clicks (the L key's)
##   the roof vent     cranked open on the sky: the day's light and the birds come in
## Sounds: assets/sfx/caravan/ (ElevenLabs, tools/audiogen/prompts_caravan.tsv), flat in
## your ears (the room is two metres wide).

const K = preload("res://scripts/interior_kit.gd")
const SFX := "res://assets/sfx/caravan/"
const SONGS_DIR := "res://assets/sfx/radio/"
const CLICK_META := "cv_thing"

signal lamp_clicked

var room: Node3D
var spec: Dictionary = {}
var level := 1
var _bodies: Array = []
var _things: Dictionary = {}       # kind -> {...}
var _loops: Dictionary = {}        # name -> AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _t := 0.0


## `spec`: the room's measures and where its furniture stands (caravan_interior).
func build(room_root: Node3D, room_spec: Dictionary) -> void:
	room = room_root
	spec = room_spec
	name = "CaravanLife"
	_rng.randomize()
	_build_faces()
	_build_fridge()
	_build_locker()
	_build_stove()
	_build_tap()
	_build_radio()
	_build_tv()
	_build_heater()
	_build_teddy()
	_build_cat()
	_build_vent()
	_build_things()
	_click_box("lamp", Vector3(0.5, 0.12, 0.5), spec["lamp"])


func apply_level(lv: int) -> void:
	level = clampi(lv, 1, 3)
	for k in ["tv", "heater"]:
		var th: Dictionary = _things.get(k, {})
		if th.has("root"):
			(th["root"] as Node3D).visible = level >= 3
			if level < 3 and bool(th.get("on", false)):
				_toggle(k)
	(_things["flowers"] as Node3D).visible = level >= 3
	(_things["teddy"]["root"] as Node3D).visible = level >= 2
	(_things["crate"] as Node3D).visible = level == 1
	_set_body("tv", level >= 3)
	_set_body("heater", level >= 3)
	_set_body("teddy", level >= 2)


## Coming in: what was left on goes off, what fell out is put back, the cat may be here.
func on_enter(hour: float, bed_made: bool) -> void:
	for k in ["gas", "tv", "heater", "radio"]:
		if bool(_things.get(k, {}).get("on", false)):
			_toggle(k)
	if bool(_things["fridge"].get("on", false)):
		_toggle("fridge")
	if bool(_things["locker"].get("on", false)):
		_toggle("locker")
	_reset_locker_spill()
	_place_cat(hour, bed_made)
	_loop("fridge_hum", -24.0, 1.0)


func on_leave() -> void:
	for n in _loops.keys():
		(_loops[n] as AudioStreamPlayer).stop()
	var cat: Dictionary = _things["cat"]
	(cat["root"] as Node3D).visible = false


func is_thing(collider: Node) -> bool:
	return collider != null and collider.has_meta(CLICK_META)


func click(collider: Node) -> void:
	if not is_thing(collider):
		return
	var kind := str(collider.get_meta(CLICK_META))
	if kind == "lamp":
		_play("lamp_click.mp3", -8.0)
		lamp_clicked.emit()
		return
	_toggle(kind)


func tick(delta: float, cam: Camera3D) -> void:
	_t += delta
	_tick_stove(delta)
	_tick_tv(delta)
	_tick_heater(delta)
	_tick_cat(delta, cam)
	var f: Dictionary = _things["fridge"]
	if f.has("light"):
		(f["light"] as OmniLight3D).light_energy = (0.9 + 0.05 * sin(_t * 31.0)) * float(f.get("open_k", 0.0))


# ── building ─────────────────────────────────────────────────────────────────

func _face(tex: String, size: Vector2, pos: Vector3, yaw_deg: float, name_: String) -> MeshInstance3D:
	var mi := K.picture(room, tex, size, pos, yaw_deg, name_)
	var m := mi.material_override as StandardMaterial3D
	if m != null:
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mi


func _sprite(tex: String, height: float, pos: Vector3, yaw_deg: float, name_: String, billboard := false) -> MeshInstance3D:
	var path := "res://assets/textury/camp/%s.png" % tex
	var w := height
	if ResourceLoader.exists(path):
		var t: Texture2D = load(path)
		w = height * float(t.get_width()) / float(maxi(1, t.get_height()))
	var mi := K.cutout(room, tex, Vector2(w, height), pos, yaw_deg, billboard, name_)
	var m := mi.material_override as StandardMaterial3D
	if m != null:
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mi


func _click_box(kind: String, size: Vector3, at: Vector3, yaw_deg := 0.0) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = "Click_" + kind
	b.set_meta(CLICK_META, kind)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	b.add_child(cs)
	b.position = at
	b.rotation_degrees.y = yaw_deg
	room.add_child(b)
	_bodies.append(b)
	return b


func _set_body(kind: String, on: bool) -> void:
	for b in _bodies:
		if str((b as Node).get_meta(CLICK_META, "")) == kind:
			(b as StaticBody3D).process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
			for c in (b as Node).get_children():
				if c is CollisionShape3D:
					(c as CollisionShape3D).disabled = not on


## The fronts of the fitted furniture: the kitchen cabinet, the dinette benches, the low
## cupboard, the worktop seen from above; the poster and the calendar on the walls.
func _build_faces() -> void:
	var kx: float = spec["kx"]
	var kz: float = spec["kz"]
	var W: float = spec["W"]
	_face("cv_kitchen", Vector2(1.1, 0.84), Vector3(kx, 0.43, kz + 0.272), 0.0, "KitchenFace")
	var top := _face("cv_worktop", Vector2(1.14, 0.58), Vector3(kx, 0.902, kz + 0.01), 0.0, "WorktopFace")
	top.rotation_degrees.x = -90.0
	var dx: float = spec["dx"]
	for side: float in [-1.0, 1.0]:
		_face("cv_bench", Vector2(0.98, 0.42), Vector3(dx, 0.21, side * (W * 0.5 - 0.51)), 0.0 if side < 0.0 else 180.0, "BenchFace")
	var sb: Vector3 = spec["sideboard"]
	_face("cv_sideboard", Vector2(0.7, 0.76), Vector3(sb.x, 0.39, sb.z - 0.192), 180.0, "SideboardFace")
	_face("cv_poster", Vector2(0.32, 0.42), Vector3(-0.85, 1.32, -W * 0.5 + 0.006), 0.0, "Poster")
	_face("cv_calendar", Vector2(0.26, 0.35), Vector3(-0.42, 1.42, W * 0.5 - 0.006), 180.0, "Calendar")


## The fridge: its box, its insides (the open picture, a bulb, the cold), its door on a
## hinge at the side by the cabinet.
func _build_fridge() -> void:
	var at: Vector3 = spec["fridge"]
	var size := Vector3(0.5, 0.84, 0.52)
	K.slab(room, size, at, K.surface("formica", 0.6, Color(0.92, 0.9, 0.84)), "FridgeBox")
	var front_z := at.z + size.z * 0.5
	var inside := _face("cv_fridge_open", Vector2(0.44, 0.78), Vector3(at.x, at.y, front_z + 0.002), 0.0, "FridgeInside")
	var im := inside.material_override as StandardMaterial3D
	im.emission_enabled = true
	im.emission_texture = im.albedo_texture
	im.emission = Color(0.85, 0.92, 1.0)
	im.emission_energy_multiplier = 0.0
	var pivot := Node3D.new()
	pivot.name = "FridgeHinge"
	pivot.position = Vector3(at.x - size.x * 0.5, at.y, front_z + 0.012)
	room.add_child(pivot)
	var door := K.picture(pivot, "cv_fridge", Vector2(size.x, size.y), Vector3(size.x * 0.5, 0, 0.01), 0.0, "FridgeDoor")
	(door.material_override as StandardMaterial3D).texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	K.slab(pivot, Vector3(size.x, size.y, 0.02), Vector3(size.x * 0.5, 0, 0.0), K.surface("formica", 0.6, Color(0.95, 0.94, 0.9)), "FridgeDoorBack")
	var light := OmniLight3D.new()
	light.light_color = Color(0.86, 0.93, 1.0)
	light.omni_range = 1.4
	light.light_energy = 0.0
	light.position = Vector3(at.x, at.y + 0.3, front_z + 0.1)
	room.add_child(light)
	_things["fridge"] = {"pivot": pivot, "light": light, "inside": im, "open_k": 0.0}
	_click_box("fridge", Vector3(size.x, size.y, 0.12), Vector3(at.x, at.y, front_z + 0.05))


## The overhead locker's front, flipping up on its top edge; what falls out of it.
func _build_locker() -> void:
	var at: Vector3 = spec["locker"]
	var size := Vector3(1.1, 0.34, 0.3)
	var pivot := Node3D.new()
	pivot.name = "LockerHinge"
	pivot.position = Vector3(at.x, at.y + size.y * 0.5, at.z + size.z * 0.5 + 0.012)
	room.add_child(pivot)
	var flap := K.picture(pivot, "cv_cupboard", Vector2(size.x, size.y), Vector3(0, -size.y * 0.5, 0.0), 0.0, "LockerFlap")
	(flap.material_override as StandardMaterial3D).texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	K.slab(pivot, Vector3(size.x, size.y, 0.016), Vector3(0, -size.y * 0.5, -0.01), K.surface("veneer_dark", 0.8), "LockerFlapBack")
	# The cards and the tin, waiting at the front of the shelf to fall out.
	var cards := K.slab(room, Vector3(0.07, 0.025, 0.1), Vector3.ZERO, K.surface("formica", 0.3, Color(0.8, 0.18, 0.16)), "Cards")
	var tin := MeshInstance3D.new()
	tin.name = "Tin"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.045
	cyl.bottom_radius = 0.045
	cyl.height = 0.03
	cyl.radial_segments = 10
	tin.mesh = cyl
	tin.material_override = K.surface("galvanized", 0.3, Color(0.9, 0.8, 0.5))
	room.add_child(tin)
	_things["locker"] = {"pivot": pivot, "spill": [cards, tin], "spilled": false, "at": at}
	_reset_locker_spill()
	_click_box("locker", Vector3(size.x, size.y, 0.12), Vector3(at.x, at.y, at.z + size.z * 0.5 + 0.05))


func _reset_locker_spill() -> void:
	var lk: Dictionary = _things.get("locker", {})
	if lk.is_empty():
		return
	var at: Vector3 = lk["at"]
	var i := 0
	for n in lk["spill"]:
		(n as Node3D).position = Vector3(at.x - 0.2 + float(i) * 0.3, at.y - 0.1, at.z + 0.08)
		(n as Node3D).rotation = Vector3.ZERO
		(n as Node3D).visible = false
		i += 1
	lk["spilled"] = false


## The two rings of the worktop picture: a blue flame on each once lit, the kettle on the
## front one, its steam.
func _build_stove() -> void:
	var rings: Array = spec["rings"]
	var flames: Array = []
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(0.35, 0.55, 1.0)
	fm.emission_enabled = true
	fm.emission = Color(0.3, 0.5, 1.0)
	fm.emission_energy_multiplier = 2.0
	for r in rings:
		var fl := MeshInstance3D.new()
		fl.name = "Flame"
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.085
		cyl.bottom_radius = 0.07
		cyl.height = 0.018
		cyl.radial_segments = 12
		fl.mesh = cyl
		fl.material_override = fm
		fl.position = (r as Vector3) + Vector3(0, 0.012, 0)
		fl.visible = false
		room.add_child(fl)
		flames.append(fl)
	var front: Vector3 = rings[1]
	var kettle := _sprite("cv_kettle", 0.2, front + Vector3(0, 0.02, 0), 0.0, "Kettle", true)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.4, 0.55, 1.0)
	glow.omni_range = 0.9
	glow.light_energy = 0.0
	glow.position = front + Vector3(0, 0.1, 0.1)
	room.add_child(glow)
	_things["gas"] = {"flames": flames, "kettle": kettle, "glow": glow, "mat": fm, "on": false, "boil": 0.0, "steam_t": 0.0}
	_click_box("gas", Vector3(0.4, 0.3, 0.6), Vector3(front.x, front.y + 0.12, (front.z + (rings[0] as Vector3).z) * 0.5))


func _build_tap() -> void:
	var sink: Vector3 = spec["sink"]
	var tap := K.slab(room, Vector3(0.04, 0.22, 0.04), Vector3(sink.x, 1.01, sink.z - 0.26), K.surface("galvanized", 0.4), "Tap")
	K.slab(room, Vector3(0.03, 0.03, 0.16), Vector3(sink.x, 1.11, sink.z - 0.19), K.surface("galvanized", 0.4), "TapSpout")
	var water := MeshInstance3D.new()
	water.name = "Water"
	var q := QuadMesh.new()
	q.size = Vector2(0.025, 0.2)
	water.mesh = q
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.7, 0.82, 0.95, 0.7)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	water.material_override = wm
	water.position = Vector3(sink.x, 1.0, sink.z - 0.12)
	water.visible = false
	room.add_child(water)
	_things["tap"] = {"water": water, "on": false}
	_click_box("tap", Vector3(0.3, 0.3, 0.4), Vector3(sink.x, 1.0, sink.z - 0.1))
	var _unused := tap


func _build_radio() -> void:
	var at: Vector3 = spec["radio"]
	var r := _sprite("cv_radio", 0.2, at, 0.0, "Radio")
	_things["radio"] = {"root": r, "on": false}
	_click_box("radio", Vector3(0.3, 0.24, 0.15), at + Vector3(0, 0.1, 0.04))


func _build_tv() -> void:
	var at: Vector3 = spec["tv"]
	var root := Node3D.new()
	root.name = "TV"
	room.add_child(root)
	var tv := _sprite("cv_tv", 0.36, at, 180.0, "TVSet")
	tv.reparent(root)
	# The screen: snow, then the test card, drawn here (no file: it changes each frame).
	var img := Image.create(24, 18, false, Image.FORMAT_RGB8)
	var tex := ImageTexture.create_from_image(img)
	var scr := MeshInstance3D.new()
	scr.name = "Screen"
	var q := QuadMesh.new()
	q.size = Vector2(0.2, 0.15)
	scr.mesh = q
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sm.albedo_texture = tex
	scr.material_override = sm
	scr.position = at + Vector3(-0.012, 0.2, -0.012)
	scr.rotation_degrees.y = 180.0
	scr.visible = false
	root.add_child(scr)
	var light := OmniLight3D.new()
	light.light_color = Color(0.6, 0.72, 1.0)
	light.omni_range = 2.4
	light.light_energy = 0.0
	light.position = at + Vector3(0, 0.25, -0.3)
	root.add_child(light)
	_things["tv"] = {"root": root, "screen": scr, "img": img, "tex": tex, "light": light, "on": false, "t": 0.0}
	_click_box("tv", Vector3(0.36, 0.36, 0.2), at + Vector3(0, 0.18, 0))


func _build_heater() -> void:
	var at: Vector3 = spec["heater"]
	var root := Node3D.new()
	root.name = "Heater"
	room.add_child(root)
	var h := _sprite("cv_heater", 0.42, at, 0.0, "HeaterSprite")
	h.reparent(root)
	(h.material_override as StandardMaterial3D).albedo_color = Color(0.55, 0.52, 0.5)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.2)
	light.omni_range = 2.0
	light.light_energy = 0.0
	light.position = at + Vector3(0, 0.22, 0.25)
	root.add_child(light)
	_things["heater"] = {"root": root, "sprite": h, "light": light, "on": false, "warm": 0.0}
	_click_box("heater", Vector3(0.4, 0.45, 0.25), at + Vector3(0, 0.22, 0))


func _build_teddy() -> void:
	var at: Vector3 = spec["teddy"]
	var root := Node3D.new()
	root.name = "TeddyRoot"
	root.position = at
	room.add_child(root)
	var t := _sprite("cv_teddy", 0.26, Vector3.ZERO, 90.0, "Teddy")
	t.reparent(root, false)
	_things["teddy"] = {"root": root, "sprite": t}
	_click_box("teddy", Vector3(0.25, 0.3, 0.25), at + Vector3(0, 0.13, 0))


## The cat's two pictures, one shown (or none); where it lies is chosen on coming in.
func _build_cat() -> void:
	var root := Node3D.new()
	root.name = "Cat"
	root.visible = false
	room.add_child(root)
	var sleep := _sprite("cv_cat_sleep", 0.2, Vector3.ZERO, 0.0, "CatAsleep", true)
	sleep.reparent(root, false)
	var awake := _sprite("cv_cat_awake", 0.36, Vector3.ZERO, 0.0, "CatAwake", true)
	awake.reparent(root, false)
	awake.visible = false
	var body := _click_box("cat", Vector3(0.4, 0.3, 0.4), Vector3.ZERO)
	body.reparent(root, false)
	body.position = Vector3(0, 0.15, 0)
	_things["cat"] = {"root": root, "sleep": sleep, "awake": awake, "state": "", "t": 0.0, "night": false}


## The roof vent over the aisle (the model's RoofVent): a frosted hatch cranked open.
func _build_vent() -> void:
	var at: Vector3 = spec["vent"]
	var frame := K.slab(room, Vector3(0.56, 0.04, 0.46), at + Vector3(0, -0.02, 0), K.surface("formica", 0.4, Color(0.92, 0.9, 0.86)), "VentFrame")
	var glass := MeshInstance3D.new()
	glass.name = "VentGlass"
	var q := QuadMesh.new()
	q.size = Vector2(0.46, 0.36)
	glass.mesh = q
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color(0.82, 0.84, 0.8)
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.material_override = gm
	var pivot := Node3D.new()
	pivot.name = "VentHinge"
	pivot.position = at + Vector3(0, -0.045, -0.18)
	room.add_child(pivot)
	glass.position = Vector3(0, 0, 0.18)
	glass.rotation_degrees.x = 90.0
	pivot.add_child(glass)
	var light := OmniLight3D.new()
	light.light_color = Color(0.9, 0.95, 1.0)
	light.omni_range = 2.2
	light.light_energy = 0.0
	light.position = at + Vector3(0, -0.4, 0)
	room.add_child(light)
	_things["vent"] = {"pivot": pivot, "glass": gm, "light": light, "on": false}
	_click_box("vent", Vector3(0.5, 0.1, 0.4), at + Vector3(0, -0.06, 0))
	var _unused := frame


## What only stands about: the flowers on the end window's sill (Lv3), the boots by the
## door, the crate of empties at the back end (Lv1).
func _build_things() -> void:
	_things["flowers"] = _sprite("cv_flowers", 0.28, spec["flowers"], -90.0, "Flowers")
	_sprite("cv_boots", 0.26, spec["boots"], 180.0, "Boots", true)
	_things["crate"] = _sprite("cv_beer_crate", 0.24, spec["crate"], 90.0, "Crate", true)


# ── what a click does ────────────────────────────────────────────────────────

func _toggle(kind: String) -> void:
	match kind:
		"fridge":
			var f: Dictionary = _things["fridge"]
			var open := not bool(f.get("on", false))
			f["on"] = open
			_play("fridge_open.mp3" if open else "fridge_shut.mp3", -6.0)
			var tw := create_tween()
			tw.tween_property(f["pivot"], "rotation_degrees:y", -112.0 if open else 0.0, 0.42 if open else 0.3) \
				.set_trans(Tween.TRANS_BACK if open else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)
			tw.parallel().tween_method(func(k: float) -> void:
				f["open_k"] = k
				(f["inside"] as StandardMaterial3D).emission_energy_multiplier = 0.6 * k, float(f.get("open_k", 0.0)), 1.0 if open else 0.0, 0.3)
			_loop("fridge_hum", -14.0 if open else -24.0, 1.0)
		"locker":
			var lk: Dictionary = _things["locker"]
			var open2 := not bool(lk.get("on", false))
			lk["on"] = open2
			_play("locker_open.mp3" if open2 else "locker_shut.mp3", -6.0)
			var tw2 := create_tween()
			tw2.tween_property(lk["pivot"], "rotation_degrees:x", -105.0 if open2 else 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			if open2 and not bool(lk.get("spilled", false)):
				lk["spilled"] = true
				_spill(lk)
		"gas":
			var g: Dictionary = _things["gas"]
			var on := not bool(g.get("on", false))
			g["on"] = on
			g["boil"] = 0.0
			if on:
				_play("gas_click.mp3", -6.0)
				get_tree().create_timer(0.55).timeout.connect(func() -> void:
					if bool(g["on"]):
						for fl in g["flames"]:
							(fl as Node3D).visible = true
						_loop("gas_burn", -16.0, 1.0))
			else:
				for fl in g["flames"]:
					(fl as Node3D).visible = false
				_stop_loop("gas_burn")
				_stop_loop("kettle_whistle")
				(g["glow"] as OmniLight3D).light_energy = 0.0
		"tap":
			var tp: Dictionary = _things["tap"]
			if bool(tp.get("on", false)):
				return
			tp["on"] = true
			(tp["water"] as Node3D).visible = true
			_play("tap.mp3", -6.0)
			get_tree().create_timer(2.0).timeout.connect(func() -> void:
				tp["on"] = false
				(tp["water"] as Node3D).visible = false)
		"radio":
			var rd: Dictionary = _things["radio"]
			var on3 := not bool(rd.get("on", false))
			rd["on"] = on3
			if on3:
				_play("radio_on.mp3", -8.0)
				get_tree().create_timer(1.4).timeout.connect(func() -> void:
					if bool(rd["on"]):
						_radio_song())
			else:
				_stop_loop("radio_song")
				_play("lamp_click.mp3", -10.0, 0.8)
		"tv":
			var tv: Dictionary = _things["tv"]
			var on4 := not bool(tv.get("on", false))
			tv["on"] = on4
			tv["t"] = 0.0
			(tv["screen"] as Node3D).visible = on4
			_play("tv_on.mp3" if on4 else "tv_off.mp3", -8.0)
			if not on4:
				(tv["light"] as OmniLight3D).light_energy = 0.0
		"heater":
			var ht: Dictionary = _things["heater"]
			var on5 := not bool(ht.get("on", false))
			ht["on"] = on5
			if on5:
				_play("heater_on.mp3", -6.0)
				get_tree().create_timer(1.6).timeout.connect(func() -> void:
					if bool(ht["on"]):
						_loop("heater_loop", -14.0, 1.0))
			else:
				_stop_loop("heater_loop")
				_play("lamp_click.mp3", -10.0, 0.7)
		"teddy":
			var td: Dictionary = _things["teddy"]
			_play("teddy_squeak.mp3", -6.0, _rng.randf_range(0.9, 1.15))
			var tw3 := create_tween()
			var spr := td["sprite"] as Node3D
			tw3.tween_property(spr, "rotation_degrees:z", 78.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw3.tween_interval(1.1)
			tw3.tween_property(spr, "rotation_degrees:z", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		"cat":
			_poke_cat()
		"vent":
			var vt: Dictionary = _things["vent"]
			var on6 := not bool(vt.get("on", false))
			vt["on"] = on6
			_play("vent.mp3", -6.0)
			var tw4 := create_tween()
			tw4.tween_property(vt["pivot"], "rotation_degrees:x", 38.0 if on6 else 0.0, 1.2).set_trans(Tween.TRANS_SINE)
			tw4.parallel().tween_property(vt["light"], "light_energy", float(spec.get("daylight", 0.6)) * 1.2 if on6 else 0.0, 1.2)


## Out of the locker: the cards and the tin tumble down onto the worktop.
func _spill(lk: Dictionary) -> void:
	var i := 0
	for n in lk["spill"]:
		var node := n as Node3D
		node.visible = true
		var land := Vector3(node.position.x + _rng.randf_range(-0.05, 0.05), 0.92 + 0.012, node.position.z + 0.12 + _rng.randf_range(0.0, 0.06))
		var tw := create_tween()
		tw.tween_interval(0.08 + float(i) * 0.12)
		tw.tween_property(node, "position", land, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(node, "rotation", Vector3(_rng.randf_range(-0.2, 0.2), _rng.randf_range(-1.5, 1.5), _rng.randf_range(-0.3, 0.3)), 0.32)
		tw.tween_property(node, "position:y", land.y + 0.04, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(node, "position:y", land.y, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		i += 1


func _radio_song() -> void:
	var songs: Array = []
	var dir := DirAccess.open(SONGS_DIR)
	if dir != null:
		for f in dir.get_files():
			var n := f.trim_suffix(".import").trim_suffix(".remap")
			if n.ends_with("_song.mp3") and not songs.has(n):
				songs.append(n)
	if songs.is_empty():
		return
	var path: String = SONGS_DIR + str(songs[_rng.randi() % songs.size()])
	if not ResourceLoader.exists(path):
		return
	var p := _loop_player("radio_song")
	p.stream = load(path)
	p.bus = "Radio" if AudioServer.get_bus_index("Radio") >= 0 else "Master"
	p.volume_db = -10.0
	p.play()


# ── each frame ───────────────────────────────────────────────────────────────

func _tick_stove(delta: float) -> void:
	var g: Dictionary = _things["gas"]
	if not bool(g.get("on", false)) or not (g["flames"][0] as Node3D).visible:
		return
	# The flames lick in steps; the kettle comes to the boil and whistles, steaming.
	var flick := 1.6 + 0.6 * float(int(_t * 12.0) % 3) / 2.0
	(g["mat"] as StandardMaterial3D).emission_energy_multiplier = flick
	(g["glow"] as OmniLight3D).light_energy = 0.35 * flick
	g["boil"] = float(g["boil"]) + delta
	if float(g["boil"]) > 6.0 and not _playing("kettle_whistle"):
		_loop("kettle_whistle", -10.0, 1.0)
	if float(g["boil"]) > 4.0:
		g["steam_t"] = float(g["steam_t"]) - delta
		if float(g["steam_t"]) <= 0.0:
			g["steam_t"] = 0.25
			_puff((g["kettle"] as Node3D).global_position + Vector3(-0.07, 0.16, 0.0))


func _puff(at: Vector3) -> void:
	var p := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	p.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(0.92, 0.92, 0.94, 0.55)
	p.material_override = m
	room.add_child(p)
	p.global_position = at
	var tw := create_tween()
	tw.tween_property(p, "global_position", at + Vector3(_rng.randf_range(-0.05, 0.05), 0.45, _rng.randf_range(-0.03, 0.05)), 1.4)
	tw.parallel().tween_property(p, "scale", Vector3.ONE * 2.6, 1.4)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 1.4)
	tw.tween_callback(p.queue_free)


func _tick_tv(delta: float) -> void:
	var tv: Dictionary = _things["tv"]
	if not bool(tv.get("on", false)):
		return
	tv["t"] = float(tv["t"]) + delta
	var img: Image = tv["img"]
	var t := float(tv["t"])
	# Snow for a moment and a roll, then the test card with a little snow in it.
	if int(t * 12.0) != int((t - delta) * 12.0):
		for y in img.get_height():
			for x in img.get_width():
				var c: Color
				if t < 1.6:
					var v := _rng.randf()
					c = Color(v, v, v)
				else:
					c = _test_card(x, y, img.get_width(), img.get_height())
					if _rng.randf() < 0.06:
						var v2 := _rng.randf()
						c = c.lerp(Color(v2, v2, v2), 0.6)
				img.set_pixel(x, y, c)
		(tv["tex"] as ImageTexture).update(img)
		(tv["light"] as OmniLight3D).light_energy = (0.45 if t < 1.6 else 0.6) + 0.15 * _rng.randf()


static func _test_card(x: int, y: int, w: int, h: int) -> Color:
	var bars := [Color(0.9, 0.9, 0.9), Color(0.9, 0.9, 0.2), Color(0.2, 0.85, 0.85), Color(0.2, 0.8, 0.2), Color(0.85, 0.2, 0.85), Color(0.85, 0.2, 0.2), Color(0.2, 0.2, 0.85)]
	var cx := float(x) - float(w) * 0.5 + 0.5
	var cy := float(y) - float(h) * 0.5 + 0.5
	if absf(sqrt(cx * cx + cy * cy) - float(h) * 0.36) < 0.8:
		return Color(0.95, 0.95, 0.95)
	if y >= h - 3:
		return Color(0.1, 0.1, 0.1) if x % 4 < 2 else Color(0.9, 0.9, 0.9)
	return bars[clampi(x * bars.size() / w, 0, bars.size() - 1)]


func _tick_heater(delta: float) -> void:
	var ht: Dictionary = _things["heater"]
	var on := bool(ht.get("on", false)) and _playing("heater_loop")
	ht["warm"] = move_toward(float(ht["warm"]), 1.0 if on else 0.0, delta * (0.35 if on else 0.6))
	var w := float(ht["warm"])
	var m := (ht["sprite"] as MeshInstance3D).material_override as StandardMaterial3D
	m.albedo_color = Color(0.55, 0.52, 0.5).lerp(Color(1.15, 1.0, 0.9), w)
	(ht["light"] as OmniLight3D).light_energy = 0.9 * w * (0.92 + 0.08 * float(int(_t * 6.0) % 2))


## The cat: where it lies today, if it is here at all (by day, now and then); once in a
## long while at night it sits there staring instead.
func _place_cat(hour: float, bed_made: bool) -> void:
	var cat: Dictionary = _things["cat"]
	var root := cat["root"] as Node3D
	root.visible = false
	cat["state"] = ""
	cat["night"] = false
	var day := hour >= 7.0 and hour < 20.0
	if day and _rng.randf() < 0.45:
		var spots: Array = [spec["cat_bench"]]
		if bed_made:
			spots.append(spec["cat_bed"])
		if level >= 2:
			spots.append(spec["cat_bunk"])
		root.position = spots[_rng.randi() % spots.size()]
		root.visible = true
		_cat_show("sleep")
	elif not day and _rng.randf() < 0.04:
		root.position = spec["cat_bench"]
		root.visible = true
		cat["night"] = true
		_cat_show("awake")


func _cat_show(state: String) -> void:
	var cat: Dictionary = _things["cat"]
	cat["state"] = state
	cat["t"] = 0.0
	(cat["sleep"] as Node3D).visible = state == "sleep"
	(cat["awake"] as Node3D).visible = state == "awake"


func _poke_cat() -> void:
	var cat: Dictionary = _things["cat"]
	if not (cat["root"] as Node3D).visible:
		return
	if bool(cat.get("night", false)):
		return
	match str(cat["state"]):
		"sleep":
			_play("cat_meow.mp3", -6.0, _rng.randf_range(0.92, 1.08))
			_cat_show("awake")
			var aw := cat["awake"] as Node3D
			aw.scale = Vector3(1.0, 0.7, 1.0)
			create_tween().tween_property(aw, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_loop("cat_purr", -12.0, 1.0)
		"awake":
			# Poked again: off it goes.
			_stop_loop("cat_purr")
			_cat_jump()


func _cat_jump() -> void:
	var cat: Dictionary = _things["cat"]
	var root := cat["root"] as Node3D
	cat["state"] = "gone"
	_play("cat_jump.mp3", -6.0)
	var door: Vector3 = spec["door_floor"]
	var tw := create_tween()
	tw.tween_property(root, "position", Vector3(root.position.x - 0.2, root.position.y + 0.15, root.position.z), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(root, "position", Vector3(root.position.x - 0.45, 0.0, clampf(root.position.z, -0.3, 0.3)), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(root, "position", door, 0.9)
	tw.tween_callback(func() -> void: root.visible = false)


func _tick_cat(delta: float, cam: Camera3D) -> void:
	var cat: Dictionary = _things["cat"]
	var root := cat["root"] as Node3D
	if not root.visible:
		return
	cat["t"] = float(cat["t"]) + delta
	match str(cat["state"]):
		"sleep":
			# Breathing: the curled cat rises and falls a hair.
			(cat["sleep"] as Node3D).scale = Vector3(1.0, 1.0 + 0.04 * sin(float(cat["t"]) * 2.2), 1.0)
		"awake":
			if bool(cat.get("night", false)):
				# At night: there while you look, gone once you have looked away.
				if cam != null:
					var to := (root.global_position - cam.global_position).normalized()
					var seen := (-cam.global_transform.basis.z).dot(to) > 0.75
					if seen:
						cat["t"] = maxf(float(cat["t"]), 0.5)
					elif float(cat["t"]) > 1.0:
						root.visible = false
				return
			if float(cat["t"]) > 6.0:
				_stop_loop("cat_purr")
				if _rng.randf() < 0.6:
					_cat_show("sleep")
				else:
					_cat_jump()


# ── sound ────────────────────────────────────────────────────────────────────

func _play(file: String, db: float, pitch := 1.0) -> void:
	var path := SFX + file
	if not ResourceLoader.exists(path):
		return
	var a := AudioStreamPlayer.new()
	a.stream = load(path)
	a.volume_db = db
	a.pitch_scale = pitch
	add_child(a)
	a.finished.connect(a.queue_free)
	a.play()


func _loop_player(n: String) -> AudioStreamPlayer:
	if not _loops.has(n):
		var a := AudioStreamPlayer.new()
		a.name = "Loop_" + n
		add_child(a)
		_loops[n] = a
	return _loops[n]


func _loop(n: String, db: float, pitch: float) -> void:
	var path := SFX + n + ".mp3"
	if not ResourceLoader.exists(path):
		return
	var a := _loop_player(n)
	if a.stream == null:
		var st := load(path) as AudioStream
		if st is AudioStreamMP3:
			st = (st as AudioStreamMP3).duplicate()
			(st as AudioStreamMP3).loop = true
		a.stream = st
	a.volume_db = db
	a.pitch_scale = pitch
	if not a.playing:
		a.play()


func _stop_loop(n: String) -> void:
	if _loops.has(n):
		(_loops[n] as AudioStreamPlayer).stop()


func _playing(n: String) -> bool:
	return _loops.has(n) and (_loops[n] as AudioStreamPlayer).playing
