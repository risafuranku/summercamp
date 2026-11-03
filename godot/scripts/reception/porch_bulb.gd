extends Node3D

## The bare bulb under the reception's porch roof (S27, the playtest of 30. 10.: "in front
## of the reception, under the pergola, a tiny bulb, really yellow... in a storm it can
## flicker a little and swing"). It hangs on its cord from the roof, in front of the door
## (camp/bulb_cord.png, turned to your eye round the cord), and comes on with the camp's
## lamps (from dusk, while there is power: building_manager.set_lamps_active): the glass
## glows and a warm yellow falls on the porch, the door and the step. The wind swings it,
## the light with it: hardly on a still night, a little in a breeze or the rain, hard in a
## storm, which also makes it stutter now and then (a loose contact). In steps, twelve a
## second, like the camp's other things. Made by building_models.reception, its node at
## the hook.

const FPS := 12.0
## The bare cord from the hook, then the picture (its own bit of cord, the socket, the
## glass: 18 x 64 px), in metres: a small bulb, not a lamp.
const CORD := 0.2
const PIC := Vector2(0.07, 0.25)
## The light in the glass, up from the picture's bottom.
const GLASS := 0.05
const COLOR := Color(1.0, 0.76, 0.32)
const ENERGY := 1.5
const RANGE := 4.2
## How far the wind swings it (radians) in each weather (main.gd WEATHER_*: clear, windy,
## fog, drizzle, rain, storm, anomaly).
const SWING := [0.02, 0.1, 0.0, 0.05, 0.08, 0.26, 0.03]
const STORM := 5

var _pivot: Node3D
var _turn: Node3D
## The picture dark (lit by the night like the rest) and lit: full yellow whatever the
## light round it (lit by its own lamp the glass came out white).
var _pic_off: MeshInstance3D
var _pic_on: MeshInstance3D
var _light: OmniLight3D
var _acc := 0.0
## The swing: the bulb's way off the plumb line in this node's x and z (radians).
var _s := Vector2.ZERO
var _v := Vector2.ZERO
var _push := Vector2.ZERO
var _gust_t := 0.0
var _stutter := 0.0
var _stutter_wait := 3.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var kit = load("res://scripts/interior_kit.gd")
	_pivot = Node3D.new()
	_pivot.name = "Hook"
	add_child(_pivot)
	_turn = Node3D.new()
	_pivot.add_child(_turn)
	# The cord up to the hook: the picture's own chain (its top two fifths) drawn on (a thin
	# box came out a broad pale bar, its corners snapped to the screen's coarse grid).
	var cord: MeshInstance3D = kit.cutout(_turn, "bulb_cord", Vector2(PIC.x, CORD), Vector3(0, -CORD, 0), 0.0, false, "Cord")
	var cord_mat := cord.material_override as StandardMaterial3D
	if cord_mat != null:
		cord_mat.uv1_scale = Vector3(1.0, 0.4, 1.0)
	_pic_off = kit.cutout(_turn, "bulb_cord", PIC, Vector3(0, -CORD - PIC.y, 0), 0.0, false, "Bulb")
	_pic_on = kit.cutout(_turn, "bulb_cord", PIC, Vector3(0, -CORD - PIC.y, 0), 0.0, false, "BulbLit")
	var lit_mat := _pic_on.material_override as StandardMaterial3D
	if lit_mat != null:
		# The glass a deep yellow; the dark socket and cord stay dark.
		lit_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lit_mat.albedo_color = Color(1.0, 0.86, 0.42)
	_pic_on.visible = false
	for n in [cord, _pic_off, _pic_on]:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_light = OmniLight3D.new()
	_light.name = "PorchBulbLight"
	_light.light_color = COLOR
	_light.light_energy = ENERGY
	_light.omni_range = RANGE
	_light.omni_attenuation = 1.3
	_light.shadow_enabled = false
	_light.position = Vector3(0, -CORD - PIC.y + GLASS, 0)
	_light.visible = false
	_pivot.add_child(_light)


func _process(delta: float) -> void:
	_acc += delta
	if _acc < 1.0 / FPS:
		return
	var dt := minf(_acc, 0.25)
	_acc = 0.0
	var main := get_tree().current_scene
	var ws := 0
	var lit := false
	if main != null:
		if main.get("_weather_state") != null:
			ws = int(main.get("_weather_state"))
		var bm = main.get("building_manager")
		lit = bm != null and bool(bm.get("_lamps_active"))
	_swing(dt, ws, main)
	_glow(dt, lit, ws)
	_face()


## A pendulum on its cord, shoved by the wind now and then: mostly the wind's way, a little
## across it, harder in a gust.
func _swing(dt: float, ws: int, main: Node) -> void:
	var amp: float = SWING[clampi(ws, 0, SWING.size() - 1)]
	var gust := 0.5
	var dir := Vector2(1, 0)
	var wv: Node = main.get("_weather_visuals") if main != null else null
	if wv != null:
		gust = clampf(float(wv.get("wind_gust")), 0.0, 1.0)
		var d = wv.get("wind_dir")
		if d is Vector2 and (d as Vector2).length() > 0.01:
			dir = (d as Vector2).normalized()
	_gust_t -= dt
	if _gust_t <= 0.0:
		_gust_t = _rng.randf_range(0.5, 1.6)
		var local := global_transform.basis.inverse() * Vector3(dir.x, 0.0, dir.y)
		var way := Vector2(local.x, local.z).normalized() if Vector2(local.x, local.z).length() > 0.01 else Vector2(1, 0)
		var across := Vector2(-way.y, way.x) * _rng.randf_range(-0.5, 0.5)
		_push = (way * _rng.randf_range(0.3, 1.0) + across) * amp * (0.5 + gust)
	var k := 9.81 / (CORD + PIC.y)
	_v += (-(_s - _push) * k - _v * 1.1) * dt
	_s = (_s + _v * dt).limit_length(0.45)
	# Off the plumb line towards +x is a turn about z, towards +z one about -x.
	_pivot.rotation = Vector3(-_s.y, 0.0, _s.x)


func _glow(dt: float, lit: bool, ws: int) -> void:
	if lit and ws == STORM:
		_stutter_wait -= dt
		if _stutter_wait <= 0.0:
			_stutter_wait = _rng.randf_range(2.0, 7.0)
			_stutter = _rng.randf_range(0.2, 0.6)
	var f := 1.0
	if _stutter > 0.0:
		_stutter -= dt
		f = _rng.randf_range(0.08, 1.0)
	_light.visible = lit and f > 0.12
	_light.light_energy = ENERGY * f
	_pic_on.visible = lit and f > 0.4
	_pic_off.visible = not _pic_on.visible


## The picture turned to the eye round its cord (a flat bulb seen edge on is a line).
func _face() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var c := _pivot.global_transform.affine_inverse() * cam.global_position
	_turn.rotation.y = atan2(c.x, c.z)
