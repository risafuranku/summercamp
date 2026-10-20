extends Node3D

## Fog you walk through (the user 20. 10.: the mist that moves round you is great, but
## there should also be fog you go right through): banks of it standing in the camp at
## eye height (Grok world/mist_bank.png, the mist's picture, see-through in four steps like
## Blood's smoke), each where it is in the world, drifting slowly with the wind. Walk at
## one and it comes up round you: near, the bank thins out of the way and the view goes
## into it instead (the same picture across the screen, sliding as you turn and walk,
## in the fog's colour), then clears as you come out the other side. Banks you have left
## far behind turn up again ahead. In the fog all day, thinner in the small hours and at
## first light, none by day; not in rain, not in a room. Made by weather_visuals.gd beside
## ground_life.gd's low mist (that one keeps round you).

const FPS := 12.0
const BANKS := 10
const MIST_TEX := "res://assets/textury/world/mist_bank.png"
## How far banks stand (m): met within this, taken away beyond FAR and set ahead again.
const NEAR := 7.0
const FAR := 34.0
## Within this of a bank's middle you are in it (times its half width).
const INSIDE := 0.55
## The world's depth fog added deep in a bank (weather_visuals.walk_fog_boost): the camp
## goes grey round you, the trees a few steps off fade, and it clears as you come out.
const WALK_FOG := 0.085

var player_getter: Callable

var _rng := RandomNumberGenerator.new()
var _banks: Array = []            # {sprite, pos: Vector3, half: float}
var _amount := 0.0
var _acc := 0.0
var _t := 0.0
var _layer: CanvasLayer
var _veil: Array = []             # two TextureRects of the mist across the screen
var _fill: ColorRect
var _veil_k := 0.0
var _yaw_px := 0.0


func _ready() -> void:
	name = "FogWalk"
	_rng.randomize()
	var tex: Texture2D = load(MIST_TEX) if ResourceLoader.exists(MIST_TEX) else null
	for i in BANKS:
		var sp := Sprite3D.new()
		sp.texture = tex
		sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		sp.transparent = true
		sp.shaded = false
		sp.pixel_size = _rng.randf_range(0.075, 0.1)
		sp.modulate = Color(0.75, 0.78, 0.82, 0.0)
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sp.visible = false
		add_child(sp)
		var half := 96.0 * sp.pixel_size * 0.5
		_banks.append({"sprite": sp, "pos": Vector3.INF, "half": half})
	# Inside a bank: the mist across the view, under the HUD.
	_layer = CanvasLayer.new()
	_layer.layer = 1
	add_child(_layer)
	_fill = ColorRect.new()
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fill.visible = false
	_layer.add_child(_fill)
	for i in 2:
		var tr := TextureRect.new()
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.texture = tex
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.flip_h = i == 1
		tr.visible = false
		_layer.add_child(tr)
		_veil.append(tr)


func _main() -> Node:
	return get_tree().current_scene if is_inside_tree() else null


## How much of it there is now: the fog all day, the small hours and first light a little.
func _want(main: Node) -> float:
	var h: float = float(main.get("_time_of_day_hours")) if main.get("_time_of_day_hours") != null else 12.0
	var w: int = int(main.get("_weather_state")) if main.get("_weather_state") != null else 0
	if w == 2 or w == 6:
		return 1.0
	if w >= 3 and w <= 5:
		return 0.0
	if h >= 5.0 and h < 8.5:
		return 0.55 * clampf((8.5 - h) / 2.0, 0.0, 1.0)
	if h >= 1.0 and h < 5.0:
		return 0.35
	return 0.0


func _process(delta: float) -> void:
	var main := _main()
	var p: Node3D = player_getter.call() if player_getter.is_valid() else null
	var indoors: bool = main == null or (main.has_method("_is_any_interior_open") and bool(main.call("_is_any_interior_open")))
	if p == null or indoors or main.get("_menu_mode") != false:
		visible = false
		for tr in _veil:
			tr.visible = false
		_fill.visible = false
		_veil_k = 0.0
		_set_boost(main, 0.0)
		return
	visible = true
	_t += delta
	_amount = move_toward(_amount, _want(main), delta * 0.03)
	_acc += delta
	if _acc < 1.0 / FPS:
		return
	var dt := _acc
	_acc = 0.0
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var eye := cam.global_position
	var fwd := -cam.global_transform.basis.z
	var fwd2 := Vector2(fwd.x, fwd.z).normalized()
	var wv = main.get("_weather_visuals")
	var wind: Vector2 = wv.get("wind_dir") if wv != null and wv.get("wind_dir") is Vector2 else Vector2(0.94, 0.34)
	var tint := Color(0.72, 0.76, 0.82)
	var env := get_world_3d().environment if get_world_3d() != null else null
	if env != null and env.fog_enabled:
		tint = env.fog_light_color
	var inside := 0.0
	for b in _banks:
		var sp: Sprite3D = b["sprite"]
		var pos: Vector3 = b["pos"]
		var flat := Vector2(pos.x - eye.x, pos.z - eye.z)
		if pos == Vector3.INF or flat.length() > FAR:
			# Set ahead of you (mostly where you look), not too close.
			var ang := fwd2.angle() + _rng.randf_range(-1.1, 1.1)
			var d := _rng.randf_range(NEAR + 4.0, FAR - 6.0)
			pos = Vector3(eye.x + cos(ang) * d, 0.0, eye.z + sin(ang) * d)
			pos.y = _rng.randf_range(1.0, 1.4)
		pos += Vector3(wind.x, 0, wind.y) * 0.22 * dt
		b["pos"] = pos
		flat = Vector2(pos.x - eye.x, pos.z - eye.z)
		var dist := flat.length()
		var half: float = b["half"]
		# In it: how deep (1 at its middle).
		var deep := clampf(1.0 - dist / (half * INSIDE), 0.0, 1.0) if absf(eye.y - pos.y) < 2.2 else 0.0
		inside = maxf(inside, deep)
		# The bank thins out of the way as you reach it (the view goes into it instead),
		# and at the far edge of where it is drawn.
		var a := _amount * clampf((dist - half * INSIDE) / 4.0, 0.0, 1.0) * clampf((FAR - dist) / 8.0, 0.0, 1.0) * 0.75
		a = floorf(a * 4.0 + 0.5) / 4.0 * 0.7
		sp.global_position = pos + Vector3(0, sin(_t * 0.25 + pos.x) * 0.08, 0)
		sp.modulate = Color(tint.r, tint.g, tint.b, a)
		sp.visible = a > 0.01
	_veil_k = move_toward(_veil_k, inside * _amount, dt * 1.4)
	_set_boost(main, _veil_k * WALK_FOG)
	_draw_veil(cam, tint, dt)


func _set_boost(main: Node, v: float) -> void:
	var wv = main.get("_weather_visuals") if main != null else null
	if wv != null and wv.get("walk_fog_boost") != null and absf(float(wv.get("walk_fog_boost")) - v) > 0.0001:
		wv.set("walk_fog_boost", v)


func _draw_veil(cam: Camera3D, tint: Color, dt: float) -> void:
	var vs := get_viewport().get_visible_rect().size
	# Four steps, as the banks: none, thin, half, thick.
	var a := floorf(_veil_k * 4.0 + 0.3) / 4.0 * 0.6
	var yaw := cam.global_rotation.y
	_yaw_px = fposmod(-yaw / TAU * vs.x * 3.0 + _t * 6.0, vs.x * 2.0)
	_fill.visible = a > 0.01
	_fill.color = Color(tint.r, tint.g, tint.b, a * 0.35)
	for i in _veil.size():
		var tr: TextureRect = _veil[i]
		tr.visible = a > 0.01
		if not tr.visible:
			continue
		var sz := Vector2(vs.x * 2.0, vs.y * (0.9 + 0.25 * float(i)))
		tr.size = sz
		var x := _yaw_px - sz.x * 0.5 + float(i) * vs.x * 0.7
		x = fposmod(x + sz.x * 0.5, sz.x) - sz.x * 0.5 - vs.x * 0.25
		tr.position = Vector2(floorf(x), floorf(vs.y * (0.12 + 0.18 * float(i)) - sz.y * 0.2))
		tr.modulate = Color(tint.r, tint.g, tint.b, a * (1.0 if i == 0 else 0.75))

