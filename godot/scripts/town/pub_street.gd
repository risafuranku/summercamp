extends Node3D

## The pub U Jezera from the street after dark (the user, 4. 11.): while it is open the
## taproom behind the glass (pub_view.gd) is thick with smoke, the guests at the window
## tables are black against the lamps, one lifting his mug now and then, somebody goes
## along the windows to the bar and back, and the windows spill warm on the pavement. In
## room space, a child of the Taproom (town_lesna._update_pub): it goes with the room, and
## a look out of the pub's own windows does not see it (window_portal hides the shell).
## At closing the guests get up one by one (street_life.gd has them in the street), nobody
## goes along the windows any more, the smoke thins and the lamps go, window by window.

const PUB_VIEW = preload("res://scripts/town/pub_view.gd")
const NPC := "res://assets/textury/npc/"
const HABITS := "res://assets/textury/habits/"
## Black against the lamps.
const DARK := Color(0.06, 0.045, 0.04)
## Closing: between these hours; who has got up by when, and when each window goes dark
## (shares of it), in the order Kubat goes round.
const CLOSE_FROM := 22.9
const CLOSE_TO := 23.3
const UP_AT := [0.12, 0.3, 0.5]
const DARK_AT := [0.55, 0.7, 1.0, 0.85]
## Past this far from the eye nothing here moves.
const NEAR := 70.0
const STEP := 1.0 / 12.0

var _smoke: Array = []
var _walker: Sprite3D
var _walk_to := 5.3
var _walk_wait := 3.0
var _walk_t := 0.0
var _drinker: Sprite3D
var _sit_tex: Texture2D
var _drink_tex: Texture2D
var _drink_t := 4.0
var _drinking := false
var _acc := 0.0
var _rng := RandomNumberGenerator.new()
var _seated: Array = []
var _spill: Array = []
var _dark: Array = []
var _closing := 0.0


func build() -> void:
	name = "PubStreet"
	_rng.randomize()
	var t: Array = PUB_VIEW.TABLES
	# With their backs to the windows, at the tables under them.
	_seated.append(_figure("host1_sit.png", 1.42, Vector3((t[0] as Vector3).x - 0.1, 0.1, 2.42)))
	_drinker = _figure("host2_sit.png", 1.42, Vector3((t[2] as Vector3).x - 0.15, 0.1, 2.4))
	_seated.append(_drinker)
	_sit_tex = _drinker.texture
	if ResourceLoader.exists(NPC + "host2_drink.png"):
		_drink_tex = load(NPC + "host2_drink.png")
	_seated.append(_figure("host3_sit.png", 1.36, Vector3((t[3] as Vector3).x + 0.2, 0.1, 2.36)))
	_walker = _figure("host1.png", 1.74, Vector3(-5.3, 0.0, 2.75))
	_walker.visible = false
	# The smoke under the ceiling and down round the lamps.
	for i in 10:
		var path := HABITS + "smoke2_%d.png" % (i % 8)
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		var s := Sprite3D.new()
		s.name = "PubSmoke"
		s.texture = tex
		s.pixel_size = _rng.randf_range(1.2, 2.1) / float(tex.get_width())
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.shaded = false
		s.modulate = Color(0.82, 0.6, 0.38, _rng.randf_range(0.09, 0.17))
		s.position = Vector3(_rng.randf_range(-5.2, 5.2), _rng.randf_range(1.5, 2.8), _rng.randf_range(2.0, 2.95))
		add_child(s)
		_smoke.append({"node": s, "v": _rng.randf_range(0.03, 0.09) * (1.0 if i % 2 == 0 else -1.0), "y": s.position.y, "phase": _rng.randf() * TAU})
	# The windows' light on the pavement.
	for x in [-3.35, 3.35]:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.66, 0.36)
		l.light_energy = 1.8
		l.omni_range = 7.5
		l.position = Vector3(float(x), 1.6, 3.0)
		add_child(l)
		_spill.append(l)
	# A window with its lamp out: the room behind it gone dark.
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	black.albedo_color = Color(0.02, 0.02, 0.03, 0.84)
	for r in PUB_VIEW.PANES:
		var p: Dictionary = PUB_VIEW.pane(r)
		var q := QuadMesh.new()
		q.size = (p["size"] as Vector2) + Vector2(0.1, 0.1)
		var d := MeshInstance3D.new()
		d.name = "WindowDark"
		d.mesh = q
		d.material_override = black
		d.position = (p["at"] as Vector3) - Vector3(0, 0, 0.08)
		d.visible = false
		add_child(d)
		_dark.append(d)
	for g in find_children("*", "GeometryInstance3D", true, false):
		(g as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _figure(tex: String, height: float, pos: Vector3) -> Sprite3D:
	var s := Sprite3D.new()
	s.name = "PubGuest"
	if ResourceLoader.exists(NPC + tex):
		var t: Texture2D = load(NPC + tex)
		s.texture = t
		s.pixel_size = height / float(t.get_height())
		s.offset = Vector2(0, t.get_height() * 0.5)
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = false
	s.modulate = DARK
	s.position = pos
	add_child(s)
	return s


## On after dark while it is open.
func set_on(on: bool) -> void:
	visible = on
	set_process(on)


## How far closing has got (town_lesna, about once a second).
func set_hour(h: float) -> void:
	_closing = clampf((h - CLOSE_FROM) / (CLOSE_TO - CLOSE_FROM), 0.0, 1.0) if h >= 12.0 else 0.0
	for i in _seated.size():
		(_seated[i] as Sprite3D).visible = _closing < float(UP_AT[i])
	for i in _dark.size():
		(_dark[i] as MeshInstance3D).visible = _closing >= float(DARK_AT[i])
	(_spill[0] as OmniLight3D).visible = _closing < 0.7
	(_spill[1] as OmniLight3D).visible = _closing < 1.0
	if _closing > 0.0 and _walker != null:
		_walk_wait = 99.0
		_walker.visible = false


func _process(delta: float) -> void:
	_acc += delta
	if _acc < STEP:
		return
	var dt := _acc
	_acc = 0.0
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.global_position.distance_to(global_position) > NEAR:
		return
	_tick_smoke(dt)
	_tick_walker(dt)
	_tick_drinker(dt)


func _tick_smoke(dt: float) -> void:
	for p in _smoke:
		var s: Sprite3D = p["node"]
		s.position.x += float(p["v"]) * dt
		if absf(s.position.x) > 5.6:
			s.position.x = -signf(s.position.x) * 5.5
		p["phase"] = float(p["phase"]) + dt * 0.3
		s.position.y = float(p["y"]) + sin(float(p["phase"])) * 0.12
		s.visible = _closing < 0.9


## Somebody along the windows to the bar and back, in steps; a while till the next.
func _tick_walker(dt: float) -> void:
	if _walker == null:
		return
	if _walk_wait > 0.0:
		_walk_wait -= dt
		if _walk_wait <= 0.0:
			_walker.visible = true
		return
	_walk_t += dt
	var dir := signf(_walk_to - _walker.position.x)
	_walker.position.x += dir * 1.05 * dt
	_walker.position.y = absf(sin(_walk_t * 6.0)) * 0.035
	_walker.flip_h = dir < 0.0
	if signf(_walk_to - _walker.position.x) != dir:
		_walker.visible = false
		_walk_to = -_walk_to
		_walk_wait = _rng.randf_range(5.0, 16.0)


## The one at the east table lifts his mug now and then.
func _tick_drinker(dt: float) -> void:
	if _drinker == null or _drink_tex == null:
		return
	_drink_t -= dt
	if _drink_t > 0.0:
		return
	_drinking = not _drinking
	_drinker.texture = _drink_tex if _drinking else _sit_tex
	_drink_t = _rng.randf_range(1.6, 3.0) if _drinking else _rng.randf_range(5.0, 13.0)
