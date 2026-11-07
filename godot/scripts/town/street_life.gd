extends Node3D

## Liblice's comings and goings by the clock (the user, 4. 11.). At the pub's closing its
## last guests go off down the street, not quite straight, and Kubat turns the key. In the
## morning the baker's van pulls up in front of the Jednota, its driver carries the crates
## of bread to the door, Mrs Novotna comes along the street and unlocks at seven.
##
## All of it a function of the hour alone: you can walk up to it half way through, and every
## warden sees the same from their own clock. In the village's frame (town_lesna's: x east,
## z south, the road at z = 0); town_trip calls `update` every frame.

const NPC := "res://assets/textury/npc/"
const TOWN := "res://assets/textury/town/"
const SFX := "res://assets/sfx/"
const FIGURE = preload("res://scripts/figures/doom_figure.gd")
## Metres a game hour (1.25 game minutes a second): a man who has had enough, one at work.
const DRUNK := 50.0
const BRISK := 68.0
const STROLL := 54.0
## The pub's door; who goes when, and which way home.
const PUB_DOOR := Vector3(16.0, 0.0, -9.6)
const GUESTS := [
	{"tex": "town_vondra.png", "from": 22.98, "way": [PUB_DOOR, Vector3(15.0, 0, -4.4), Vector3(-30.0, 0, -4.4), Vector3(-46.0, 0, -11.0)]},
	{"tex": "town_pumpar.png", "from": 23.12, "way": [PUB_DOOR, Vector3(18.0, 0, -3.6), Vector3(26.0, 0, -4.6), Vector3(26.0, 0, 4.4), Vector3(66.0, 0, 4.4)]},
]
## The van: comes from the east along the north lane, stops with its back doors by the
## Jednota's door, goes on west.
const VAN_IN := 6.52
const VAN_STOP := 6.82
const VAN_GO := 7.28
const VAN_OUT := 7.5
const VAN_FROM := 110.0
const VAN_AT := -9.0
const VAN_TO := -110.0
const VAN_Z := -2.2
const VAN_LEN := 4.6
const SHOP_DOOR := Vector3(-6.0, 0.0, -9.3)
## Where the crates go down; when each is there; when they have been taken in.
const CRATE_AT := [Vector3(-4.5, 0.0, -9.6), Vector3(-3.8, 0.0, -9.5)]
const CRATES_IN := 7.6
## The driver's turns: out with a crate, back, out, back.
const TURNS_FROM := 6.85
## Mrs Novotna's way to work, and when she is at the door.
const NOVOTNA_WAY := [Vector3(-29.0, 0, -4.6), Vector3(-8.5, 0, -4.6), Vector3(-6.6, 0, -9.3)]
const NOVOTNA_AT := 6.97
const OPENS := 7.0
## What is heard as the clock passes it, and where: [hour, sound, db, "van" | "shop" | "pub"].
const CUES := [
	[6.6, "town/car_in.mp3", -2.0, "van"],
	[6.84, "bus/door_open.mp3", -6.0, "van"],
	[6.94, "bus/thump.mp3", -8.0, "shop"],
	[6.985, "town/motel_key.mp3", -4.0, "shop"],
	[7.0, "town/shop_bell.mp3", -6.0, "shop"],
	[7.1, "bus/thump.mp3", -8.0, "shop"],
	[7.24, "bus/door_close.mp3", -6.0, "van"],
	[7.28, "town/car_out.mp3", -2.0, "van"],
	[22.98, "backroom/room_door_close.mp3", -6.0, "pub"],
	[23.12, "backroom/room_door_close.mp3", -6.0, "pub"],
	[23.3, "town/motel_key.mp3", -4.0, "pub"],
]

## The bread comes Tuesdays and Fridays, as Mrs Novotna says at the counter: the van, its driver
## and his crates with it.
const BREAD_DAYS := ["Tuesday", "Friday"]
var _bread_day := true
var _day_seen := -1

var _t := 0.0
var _last_h := -1.0
var _guests: Array = []
var _van: Node3D
var _wheels: Array = []
var _driver: Sprite3D
var _in_hands: Sprite3D
var _crates: Array = []
var _novotna: Sprite3D
var _fx: AudioStreamPlayer3D


func _ready() -> void:
	name = "StreetLife"
	for g in GUESTS:
		_guests.append({"sprite": _person(str(g["tex"]), 1.72), "from": float(g["from"]), "way": g["way"], "len": _length(g["way"])})
	_driver = _person("town_driver.png", 1.74)
	_novotna = _person("town_shopgirl.png", 1.62)
	_in_hands = _crate(0.5)
	for at in CRATE_AT:
		var c := _crate(0.72)
		c.position = at
		_crates.append(c)
	_build_van()
	_fx = AudioStreamPlayer3D.new()
	_fx.unit_size = 6.0
	_fx.max_distance = 48.0
	add_child(_fx)


func _person(tex: String, height: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.name = "StreetPerson"
	if ResourceLoader.exists(NPC + tex):
		var t: Texture2D = load(NPC + tex)
		s.texture = t
		s.pixel_size = height / float(t.get_height())
		s.offset = Vector2(0, t.get_height() * 0.5)
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = true
	s.visible = false
	add_child(s)
	# Drawn from eight sides (npc/sets/): `_goes` walks them.
	var drawn: Dictionary = FIGURE.set_for(NPC + tex)
	if not drawn.is_empty():
		FIGURE.new(s, drawn, height)
	return s


## To `at`: on their feet if they are drawn from eight sides, the picture for where you stand.
func _goes(s: Sprite3D, at: Vector3) -> void:
	var step := at - s.position
	s.position = at
	var fig = s.get_meta("doom", null)
	if fig == null:
		return
	var flat := Vector2(step.x, step.z).length()
	fig.set_anim("walk" if flat > 0.0005 else "stand")
	if flat > 0.0005:
		fig.face(global_transform.basis * step)
		fig.advance(flat)
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		fig.show(cam.global_position)


func _crate(height: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.name = "BreadCrate"
	if ResourceLoader.exists(TOWN + "crates_bread.png"):
		var t: Texture2D = load(TOWN + "crates_bread.png")
		s.texture = t
		s.pixel_size = height / float(t.get_height())
		s.offset = Vector2(0, t.get_height() * 0.5)
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = true
	s.visible = false
	add_child(s)
	return s


## The wholesaler's Avia as day_events has it, turned to go west.
func _build_van() -> void:
	_van = Node3D.new()
	_van.name = "BreadVan"
	_van.rotation.y = -PI * 0.5
	_van.visible = false
	add_child(_van)
	var height := 2.3
	var width := 2.0
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, height, VAN_LEN)
	box.mesh = bm
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.86, 0.86, 0.82)
	box.material_override = white
	box.position = Vector3(0, height * 0.5 + 0.35, 0)
	_van.add_child(box)
	for side in [-1.0, 1.0]:
		_face("van_side.png", Vector2(VAN_LEN, height + 0.35), Vector3(float(side) * (width * 0.5 + 0.01), (height + 0.35) * 0.5 + 0.2, 0), float(side) * PI * 0.5, float(side) < 0.0)
	_face("van_front.png", Vector2(width, height * 0.8), Vector3(0, height * 0.42 + 0.2, VAN_LEN * 0.5 + 0.01), 0.0, false)
	_face("van_back.png", Vector2(width, height), Vector3(0, height * 0.5 + 0.35, -VAN_LEN * 0.5 - 0.01), PI, false)
	for x in [-1.0, 1.0]:
		for z in [-1.5, 1.6]:
			var w := _face("van_wheel.png", Vector2(0.8, 0.8), Vector3(float(x) * 1.03, 0.38, float(z)), float(x) * PI * 0.5, false)
			_wheels.append(w)


func _face(tex: String, size: Vector2, pos: Vector3, yaw: float, mirror: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(-size.x, size.y) if mirror else size
	mi.mesh = q
	var m := StandardMaterial3D.new()
	if ResourceLoader.exists(TOWN + tex):
		m.albedo_texture = load(TOWN + tex)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = yaw
	_van.add_child(mi)
	return mi


func _length(way: Array) -> float:
	var n := 0.0
	for i in way.size() - 1:
		n += (way[i] as Vector3).distance_to(way[i + 1] as Vector3)
	return n


## `metres` along the way.
func _along(way: Array, metres: float) -> Vector3:
	var left := metres
	for i in way.size() - 1:
		var a: Vector3 = way[i]
		var b: Vector3 = way[i + 1]
		var d := a.distance_to(b)
		if left <= d:
			return a.lerp(b, left / maxf(d, 0.001))
		left -= d
	return way.back()


func update(h: float, delta: float) -> void:
	_t += delta
	if _day_seen != CoreRoot.get_day():
		_day_seen = CoreRoot.get_day()
		var wd := str(Season.WEEKDAYS[int(Season.date_of(_day_seen)["wd"])])
		_bread_day = BREAD_DAYS.has(wd)
	_tick_guests(h)
	_tick_van(h)
	_tick_people(h)
	# Only as the clock goes by, not when it jumps (a night slept through).
	if _last_h >= 0.0 and h >= _last_h and h - _last_h < 0.05:
		for c in CUES:
			if _last_h < float(c[0]) and h >= float(c[0]) and (_bread_day or not (str(c[3]) == "van" or str(c[1]).ends_with("thump.mp3"))):
				_cue(str(c[1]), float(c[2]), str(c[3]))
	_last_h = h


func _cue(path: String, db: float, where: String) -> void:
	if not ResourceLoader.exists(SFX + path):
		return
	match where:
		"van":
			_fx.position = _van.position + Vector3(0, 1.0, 0)
		"shop":
			_fx.position = SHOP_DOOR + Vector3(0, 1.0, 0)
		_:
			_fx.position = PUB_DOOR + Vector3(0, 1.0, 0)
	_fx.stream = load(SFX + path)
	_fx.volume_db = db
	_fx.play()


## Off home from the pub, in steps, not quite straight.
func _tick_guests(h: float) -> void:
	var hh := h if h >= 12.0 else h + 24.0
	var step := floorf(_t * 8.0)
	for g in _guests:
		var s: Sprite3D = g["sprite"]
		var m: float = (hh - float(g["from"])) * DRUNK
		s.visible = m >= 0.0 and m < float(g["len"])
		if s.visible:
			var at := _along(g["way"], m)
			_goes(s, at + Vector3(sin(m * 0.8) * 0.4, absf(sin(step * 1.1)) * 0.03, cos(m * 0.53) * 0.3))
			if not s.has_meta("doom"):
				s.flip_h = sin(m * 0.8 + 1.5) < 0.0


func _van_x(h: float) -> float:
	if h < VAN_STOP:
		var k := clampf((h - VAN_IN) / (VAN_STOP - VAN_IN), 0.0, 1.0)
		return lerpf(VAN_FROM, VAN_AT, 1.0 - pow(1.0 - k, 2.2))
	if h < VAN_GO:
		return VAN_AT
	var k2 := clampf((h - VAN_GO) / (VAN_OUT - VAN_GO), 0.0, 1.0)
	return lerpf(VAN_AT, VAN_TO, pow(k2, 1.8))


func _tick_van(h: float) -> void:
	_van.visible = _bread_day and h >= VAN_IN and h < VAN_OUT
	if not _van.visible:
		return
	var x := _van_x(h)
	_van.position = Vector3(x, 0.0, VAN_Z)
	for w in _wheels:
		(w as MeshInstance3D).rotation.z = x / 0.38


## The driver with the crates, the crates at the door, Mrs Novotna coming to work.
func _tick_people(h: float) -> void:
	var tail := Vector3(VAN_AT + VAN_LEN * 0.5 + 0.5, 0.0, VAN_Z - 0.9)
	var leg := tail.distance_to(SHOP_DOOR)
	var turn := leg / BRISK
	var t := h - TURNS_FROM
	_driver.visible = _bread_day and t >= 0.0 and t < turn * 4.0
	_in_hands.visible = false
	if _driver.visible:
		var n := int(t / turn)
		var k := fmod(t, turn) / turn
		var out := n % 2 == 0
		var at := tail.lerp(SHOP_DOOR, k if out else 1.0 - k)
		_goes(_driver, at + Vector3(0, absf(sin(floorf(_t * 10.0) * 0.9)) * 0.03, 0))
		_in_hands.visible = out
		if out:
			_in_hands.position = at + Vector3(0, 0.72, 0.2)
	(_crates[0] as Sprite3D).visible = _bread_day and h >= TURNS_FROM + turn and h < CRATES_IN
	(_crates[1] as Sprite3D).visible = _bread_day and h >= TURNS_FROM + turn * 3.0 and h < CRATES_IN
	var way_len := _length(NOVOTNA_WAY)
	var m := way_len - (NOVOTNA_AT - h) * STROLL
	_novotna.visible = m >= 0.0 and h < OPENS
	if _novotna.visible:
		_goes(_novotna, _along(NOVOTNA_WAY, minf(m, way_len)) + Vector3(0, absf(sin(floorf(_t * 8.0) * 1.2)) * 0.02 if m < way_len else 0.0, 0))
