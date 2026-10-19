extends Node3D

## The weather inside a room (the office and its back room, the cabins, the caravans, the
## tents): what you see of it at the windows and feel of it in the room.
##   - every window's glass: drops that cling to it and water running down it in steps
##     (Grok, world/glass_drops.png, glass_runs.png), thicker the harder it rains, and the
##     drops stay a while after it stops (the ground's wetness, season_look.gd);
##   - lightning: in the instant of the flash outside (weather_visuals.gd) a cold light
##     comes in at every window and throws the window's shape across the room (a cookie,
##     world/window_cookie.png), flickering as the bolt does;
##   - the room under a storm sky: a negative light takes the warmth out of it; after a
##     close strike the room's own lights blink off and on as the power dips;
##   - a tent (canvas) has no windows: in a flash the whole of it lights up from outside,
##     its walls breathe in the gusts and its lantern swings;
##   - the sound of it in here: rain drumming on the canvas, the timbers creaking and the
##     panes rattling in a gust (the canvas snapping in a tent), now and then a drip
##     through the roof (ElevenLabs, sfx/weather/).
## The room makes one (child of its root) and hands it its windows and its moving parts;
## `is_open` says when you are in it (nothing plays when you are not).

const DROPS_TEX := "res://assets/textury/world/glass_drops.png"
const RUNS_TEX := "res://assets/textury/world/glass_runs.png"
const COOKIE_TEX := "res://assets/textury/world/window_cookie.png"
const SFX := "res://assets/sfx/weather/"
const FPS := 12.0
const GLASS_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
uniform sampler2D drops : filter_nearest, repeat_enable, hint_default_black;
uniform sampler2D runs : filter_nearest, repeat_enable, hint_default_black;
uniform float rain = 0.0;
uniform float runs_amount = 0.0;
uniform float t_step = 0.0;
uniform vec2 tiles = vec2(2.0, 2.0);
uniform vec3 tint = vec3(0.62, 0.68, 0.76);
uniform float flash = 0.0;
void fragment() {
	vec2 uv = UV * tiles;
	vec3 d = texture(drops, uv).rgb;
	// Water running down: the streaks slide down the pane a step at a time.
	vec3 r = texture(runs, vec2(uv.x * 0.9 + 0.37, uv.y * 0.6 - t_step)).rgb;
	float da = smoothstep(0.08, 0.5, max(d.r, max(d.g, d.b))) * rain * 0.6;
	float ra = smoothstep(0.1, 0.55, max(r.r, max(r.g, r.b))) * runs_amount * 0.75;
	float a = clamp(max(da, ra), 0.0, 0.7);
	// Water: the grey-blue of the storm light in it, brighter where it catches it.
	vec3 water = tint * (0.45 + 0.6 * max(max(d.b, d.g), r.b));
	ALBEDO = mix(water, vec3(0.92, 0.96, 1.0), clamp(flash, 0.0, 1.0));
	ALPHA = a;
}
"""

## Callable() -> bool: you are in this room now (unset: the first room up the tree that
## answers is_open(), the interior this one is built in).
var is_open: Callable
## A tent: no glass, the canvas itself lit by the lightning and moved by the wind.
var canvas := false
## The storm's gloom over the room and the room's own weather sounds (off for a second
## room in the same world: the office's back room).
var gloom := true
var sounds := true

var _windows: Array = []          # {overlay, mat: ShaderMaterial, light: SpotLight3D}
var _gloom: OmniLight3D
var _canvas_flash: OmniLight3D
var _breathers: Array = []        # {node, rot: Vector3, axis: Vector3, phase}
var _swingers: Array = []         # {node, rot: Vector3, phase}
var _drip_at := Vector3.INF
var _drip_floor := 0.0
var _drip: Sprite3D
var _drip_t := 3.0
var _drop_y := -1.0
var _rain := 0.0
var _t := 0.0
var _acc := 0.0
var _gust_t := 8.0
var _rng := RandomNumberGenerator.new()
var _loop: AudioStreamPlayer
var _gust_snd: AudioStreamPlayer
var _drip_snd: AudioStreamPlayer
var _last_flash := 0.0
## The power dip after a close strike: the room's lights that were on, and the steps left.
var _dip_lights: Array = []
var _dip_step := -1
var _drops_tex: Texture2D
var _runs_tex: Texture2D
var _cookie: Texture2D


func _ready() -> void:
	name = "RoomWeather"
	_rng.randomize()
	_drops_tex = _tex(DROPS_TEX)
	_runs_tex = _tex(RUNS_TEX)
	_cookie = _tex(COOKIE_TEX)
	# The storm sky over the room: light taken out of it (a negative light).
	_gloom = OmniLight3D.new()
	_gloom.name = "StormGloom"
	_gloom.light_negative = true
	_gloom.omni_range = 9.0
	_gloom.omni_attenuation = 0.4
	_gloom.light_energy = 0.0
	_gloom.light_specular = 0.0
	_gloom.position = Vector3(0, 1.5, 0)
	add_child(_gloom)
	_loop = _player("rain_canvas.mp3", true)
	_gust_snd = _player("", false)
	_drip_snd = _player("roof_drip.mp3", false)


func _tex(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null


func _player(file: String, loop: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = -80.0
	if file != "" and ResourceLoader.exists(SFX + file):
		var st = load(SFX + file)
		if loop and st is AudioStreamMP3:
			st = (st as AudioStreamMP3).duplicate()
			(st as AudioStreamMP3).loop = true
		p.stream = st
	add_child(p)
	return p


## A window: its glass quad (facing into the room). The water goes on it; the lightning
## comes in through it.
func add_window(glass: MeshInstance3D) -> void:
	if glass == null or not (glass.mesh is QuadMesh):
		return
	var size: Vector2 = (glass.mesh as QuadMesh).size
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ov := MeshInstance3D.new()
	ov.name = "RainOnGlass"
	var q := QuadMesh.new()
	q.size = size
	ov.mesh = q
	ov.position = Vector3(0, 0, 0.012)
	ov.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = GLASS_SHADER
	mat.shader = sh
	if _drops_tex != null:
		mat.set_shader_parameter("drops", _drops_tex)
	if _runs_tex != null:
		mat.set_shader_parameter("runs", _runs_tex)
	# A tile of the water every 60 cm of glass (the drops a size you can see from the room).
	mat.set_shader_parameter("tiles", Vector2(maxf(1.0, size.x / 0.6), maxf(1.0, size.y / 0.6)))
	ov.material_override = mat
	ov.set_meta("retro_skip", true)
	glass.add_child(ov)
	# The flash: from just outside the glass, into the room and down to the floor.
	var l := SpotLight3D.new()
	l.name = "LightningIn"
	l.transform = Transform3D(Basis.looking_at(Vector3(0, -0.5, 1).normalized(), Vector3.UP), Vector3(0, 0, -0.3))
	l.spot_range = 7.5
	l.spot_angle = 52.0
	l.spot_attenuation = 0.6
	l.light_color = Color(0.78, 0.86, 1.0)
	l.light_energy = 0.0
	l.light_specular = 0.0
	l.shadow_enabled = false
	if _cookie != null:
		l.light_projector = _cookie
	l.visible = false
	glass.add_child(l)
	_windows.append({"overlay": ov, "mat": mat, "light": l})


## A wall of a tent that breathes in the wind (turned a little about `axis`).
func add_breather(n: Node3D, axis: Vector3) -> void:
	if n != null:
		_breathers.append({"node": n, "rot": n.rotation, "axis": axis.normalized(), "phase": _rng.randf() * TAU})


## Something hanging that swings in the wind (a lantern on its cord: the node's origin
## at the hook).
func add_swinger(n: Node3D) -> void:
	if n != null:
		_swingers.append({"node": n, "rot": n.rotation, "phase": _rng.randf() * TAU})


## Where the roof leaks in heavy rain (a drop falls from `ceiling` to the floor at y).
func set_drip(ceiling: Vector3, floor_y: float) -> void:
	_drip_at = ceiling
	_drip_floor = floor_y
	if _drip == null:
		_drip = Sprite3D.new()
		_drip.texture = _tex("res://assets/textury/world/rain_streak.png")
		_drip.pixel_size = 0.008
		_drip.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		_drip.shaded = false
		_drip.modulate = Color(0.8, 0.86, 0.95, 0.9)
		_drip.visible = false
		add_child(_drip)


func _make_canvas_flash() -> void:
	if _canvas_flash != null:
		return
	_canvas_flash = OmniLight3D.new()
	_canvas_flash.name = "CanvasFlash"
	_canvas_flash.light_color = Color(0.74, 0.82, 1.0)
	_canvas_flash.omni_range = 5.0
	_canvas_flash.light_energy = 0.0
	_canvas_flash.light_specular = 0.0
	_canvas_flash.position = Vector3(0, 1.4, 0)
	add_child(_canvas_flash)


func _process(delta: float) -> void:
	var open: bool = _room_open()
	var main := get_tree().current_scene if is_inside_tree() else null
	if main == null:
		return
	var w := int(main.get("_weather_state")) if main.get("_weather_state") != null else 0
	var wv = main.get("_weather_visuals")
	var sl = main.get("_season_look")
	var snowing: bool = sl != null and sl.has_method("is_snowing") and bool(sl.is_snowing())
	var target: float = 0.0 if snowing else float({3: 0.45, 4: 0.8, 5: 1.0}.get(w, 0.0))
	_rain = move_toward(_rain, target, delta * (0.25 if target > _rain else 0.05))
	var wet: float = float(sl.get("wet")) if sl != null and sl.get("wet") != null else 0.0
	var flash: float = float(wv.get("_storm_flash_strength")) if wv != null and wv.get("_storm_flash_strength") != null else 0.0
	var wind: float = float({1: 0.6, 3: 0.3, 4: 0.5, 5: 1.0}.get(w, 0.08))
	_t += delta
	_acc += delta
	if _acc >= 1.0 / FPS:
		_acc = 0.0
		_step(open, w, flash, wet, wind)
	_sound(open, delta, w, wind)


func _room_open() -> bool:
	if is_open.is_valid():
		return bool(is_open.call())
	var n := get_parent()
	while n != null:
		if n.has_method("is_open"):
			return bool(n.call("is_open"))
		n = n.get_parent()
	return false


## Everything that moves, in steps (twelve a second, like the rest of the Build world).
func _step(open: bool, w: int, flash: float, wet: float, wind: float) -> void:
	var tstep := floorf(_t * FPS) / FPS
	# The bolt flickers: on, off, on.
	var flick := 0.25 if int(_t * 16.0) % 3 == 1 else 1.0
	var glass := maxf(_rain, wet * 0.5)
	for win in _windows:
		var mat: ShaderMaterial = win["mat"]
		mat.set_shader_parameter("rain", glass)
		mat.set_shader_parameter("runs_amount", _rain)
		mat.set_shader_parameter("t_step", floorf(_t * 3.0) * 0.07)
		mat.set_shader_parameter("flash", flash * flick)
		var l: SpotLight3D = win["light"]
		l.visible = flash > 0.03
		l.light_energy = flash * flick * 9.0
	_gloom.light_energy = float({3: 0.14, 4: 0.24, 5: 0.4}.get(w, 0.0)) if open and gloom else 0.0
	# A close strike (a strong flash coming on): the power dips.
	if open and flash > 0.7 and _last_flash < 0.5 and _dip_step < 0 and _rng.randf() < 0.7:
		_start_dip()
	_last_flash = flash
	_run_dip()
	if canvas:
		_make_canvas_flash()
		_canvas_flash.light_energy = flash * flick * 4.0
		_canvas_flash.visible = flash > 0.03
	# The canvas breathes, the lantern swings: harder in the gusts.
	var gust := wind * (0.6 + 0.4 * sin(tstep * 1.7) * sin(tstep * 0.63 + 1.1))
	for b in _breathers:
		var n: Node3D = b["node"]
		if is_instance_valid(n):
			var a := deg_to_rad(1.6) * gust * sin(tstep * 5.3 + float(b["phase"]))
			n.rotation = (b["rot"] as Vector3) + (b["axis"] as Vector3) * a
	for s in _swingers:
		var n2: Node3D = s["node"]
		if is_instance_valid(n2):
			var sw := deg_to_rad(9.0) * gust * sin(tstep * 2.1 + float(s["phase"]))
			n2.rotation = (s["rot"] as Vector3) + Vector3(sw, 0, sw * 0.6)
	# A drop through the roof now and then in heavy rain (and a while after).
	if _drip != null:
		if _drop_y >= 0.0:
			_drop_y -= 0.35
			if _drop_y <= _drip_floor:
				_drop_y = -1.0
				_drip.visible = false
			else:
				_drip.position = Vector3(_drip_at.x, _drop_y, _drip_at.z)
				_drip.visible = open


func _start_dip() -> void:
	_dip_lights.clear()
	var room := get_parent()
	if room == null:
		return
	for n in room.find_children("*", "Light3D", true, false):
		var l := n as Light3D
		if l == null or l.light_negative or is_ancestor_of(l) or not l.visible:
			continue
		# Daylight through a window is not on the mains.
		var nm := String(l.name).to_lower()
		if nm.contains("window") or nm.contains("sun") or nm.contains("moon") or nm.contains("day"):
			continue
		if l.get_parent() is MeshInstance3D and (l.get_parent() as Node).has_node("RainOnGlass"):
			continue
		_dip_lights.append(l)
	_dip_step = 0


## Off, on, off, off, on (a step each).
func _run_dip() -> void:
	if _dip_step < 0:
		return
	var pattern := [false, true, false, false, true]
	var on: bool = pattern[_dip_step]
	for l in _dip_lights:
		if is_instance_valid(l):
			(l as Light3D).visible = on
	_dip_step += 1
	if _dip_step >= pattern.size():
		for l in _dip_lights:
			if is_instance_valid(l):
				(l as Light3D).visible = true
		_dip_lights.clear()
		_dip_step = -1


func _sound(open: bool, delta: float, w: int, wind: float) -> void:
	if not sounds:
		return
	# Rain on the canvas over your head.
	if _loop.stream != null:
		var want := canvas and open and _rain > 0.02
		if want and not _loop.playing:
			_loop.play()
		_loop.volume_db = (linear_to_db(_rain) - 4.0) if want else -80.0
		if not want and _loop.playing:
			_loop.stop()
	if not open:
		return
	# The gusts: the timbers creak and the panes rattle, the canvas snaps.
	_gust_t -= delta
	if _gust_t <= 0.0:
		_gust_t = _rng.randf_range(9.0, 22.0) / maxf(0.3, wind)
		if wind >= 0.5 and not _gust_snd.playing:
			var file := "tent_flap.mp3" if canvas else "wind_cabin_creak.mp3"
			if ResourceLoader.exists(SFX + file):
				_gust_snd.stream = load(SFX + file)
				_gust_snd.volume_db = -14.0 + wind * 6.0
				_gust_snd.pitch_scale = _rng.randf_range(0.92, 1.06)
				_gust_snd.play()
	# A drip.
	if _drip_at != Vector3.INF and (_rain > 0.6 or (_rain > 0.1 and w == 0)):
		_drip_t -= delta
		if _drip_t <= 0.0:
			_drip_t = _rng.randf_range(2.2, 6.0)
			_drop_y = _drip_at.y
			if _drip_snd.stream != null:
				_drip_snd.volume_db = -12.0
				_drip_snd.pitch_scale = _rng.randf_range(0.9, 1.15)
				get_tree().create_timer(0.35).timeout.connect(func(): if is_instance_valid(_drip_snd): _drip_snd.play())
