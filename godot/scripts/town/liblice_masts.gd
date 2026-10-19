extends Node3D

## The two masts of the medium-wave transmitter outside Lesna (Liblice B, built 1976):
## 355 m guyed lattice masts painted in red and white bands, close together in the open
## fields, seen over the village roofs at the end of the street the way they stand over
## Liblice. At night a red obstruction light every forty metres up each, the top one
## breathing slowly; they show from anywhere with a clear view of the sky line, the camp's
## lake included.
##
## Kilometres off, so the world's fog would wipe them out: their materials skip the fog
## and haze themselves instead, by the outdoor fog's own density and colour (gone in fog,
## faint on a grey day, sharp after rain). Thicker than the real 2.5 m so they keep a
## pixel of width at the low internal resolution.

const HEIGHT := 355.0
const WIDTH := 7.0
const BANDS := 15
const LIGHT_EVERY := 40.0
## Where they stand in Lesna's frame (town_lesna.ORIGIN + this): down the road west of
## the village, a little to the south. The player's camera sees 1 km (main
## FIRST_PERSON_CAMERA_FAR), so they stand at ~870 m scaled by SCALE: from the village
## they look the size the real ones do from Liblice, about 1.1 km off.
const SPOTS := [Vector3(-850.0, 0.0, 110.0), Vector3(-870.0, 0.0, 280.0)]
const SCALE := 0.8
const HAZE_SCALE := 0.1

const BODY_SHADER := """
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;
uniform vec4 haze_color : source_color = vec4(0.7, 0.76, 0.82, 1.0);
uniform float haze = 0.5;
uniform float light = 1.0;
uniform float height = 355.0;
uniform float bands = 15.0;
varying float h;
void vertex() {
	h = VERTEX.y;
}
void fragment() {
	float b = mod(floor(clamp(h / height, 0.0, 0.999) * bands), 2.0);
	vec3 col = mix(vec3(0.74, 0.13, 0.09), vec3(0.93, 0.92, 0.88), b);
	ALBEDO = mix(col * light, haze_color.rgb, haze);
}
"""

## A dot that keeps its size on screen whatever the distance (a quad turned to the eye).
const LAMP_SHADER := """
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.18, 0.08, 1.0);
uniform float glow = 1.0;
uniform float size = 0.011;
void vertex() {
	vec4 c = MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	POSITION = PROJECTION_MATRIX * (c + vec4(VERTEX.xy * -c.z * size, 0.0, 0.0));
}
void fragment() {
	ALBEDO = color.rgb * glow;
}
"""

const WIRE_SHADER := """
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;
uniform vec4 haze_color : source_color = vec4(0.7, 0.76, 0.82, 1.0);
uniform float haze = 0.5;
uniform float light = 1.0;
void fragment() {
	// The guys barely show against the sky, as in the photographs.
	ALBEDO = mix(vec3(0.3, 0.3, 0.32) * light, haze_color.rgb, haze);
	ALPHA = 0.16 * (1.0 - haze);
}
"""

var _body: ShaderMaterial
var _wire: ShaderMaterial
var _lamp: ShaderMaterial
var _top_lamps: Array = []
var _lamps: Array = []
var _t := 0.0


func build() -> void:
	name = "LibliceMasts"
	_body = _shader_mat(BODY_SHADER)
	_body.set_shader_parameter("height", HEIGHT)
	_body.set_shader_parameter("bands", float(BANDS))
	_wire = _shader_mat(WIRE_SHADER)
	_lamp = _shader_mat(LAMP_SHADER)
	for spot in SPOTS:
		_mast(spot)
	set_night(false)


func _shader_mat(code: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _mast(at: Vector3) -> void:
	var root := Node3D.new()
	root.position = at
	root.scale = Vector3.ONE * SCALE
	add_child(root)
	# The lattice as a slim triangular prism (its banding is in the shader).
	var prism := CylinderMesh.new()
	prism.radial_segments = 3
	prism.rings = 1
	prism.top_radius = WIDTH * 0.577
	prism.bottom_radius = WIDTH * 0.577
	prism.height = HEIGHT
	prism.cap_top = true
	prism.cap_bottom = false
	var mi := MeshInstance3D.new()
	mi.mesh = prism
	mi.position.y = HEIGHT * 0.5
	mi.material_override = _body
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	# Guy wires: three ways round, from five heights to anchors out in the fields.
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for k in 3:
		var ang := TAU * float(k) / 3.0 + 0.4
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		for level in [0.2, 0.38, 0.56, 0.74, 0.9]:
			var hgt: float = HEIGHT * level
			im.surface_add_vertex(Vector3(0.0, hgt, 0.0))
			im.surface_add_vertex(dir * (40.0 + hgt * 0.32))
	im.surface_end()
	var wires := MeshInstance3D.new()
	wires.mesh = im
	wires.material_override = _wire
	wires.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(wires)
	# The obstruction lights.
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var y := LIGHT_EVERY
	while y <= HEIGHT + 0.1:
		var lamp := MeshInstance3D.new()
		lamp.mesh = quad
		lamp.position = Vector3(0.0, minf(y, HEIGHT + 1.0), 0.0)
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lamp.material_override = _lamp
		root.add_child(lamp)
		_lamps.append(lamp)
		y += LIGHT_EVERY
	var top := MeshInstance3D.new()
	top.mesh = quad
	top.position = Vector3(0.0, HEIGHT + 1.5, 0.0)
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top.material_override = _lamp.duplicate()
	root.add_child(top)
	_top_lamps.append(top)
	_lamps.append(top)


## Night: the masts go dark against the sky and the lamps come on.
func set_night(night: bool) -> void:
	for m in [_body, _wire]:
		m.set_shader_parameter("light", 0.12 if night else 1.0)
	for l in _lamps:
		(l as Node3D).visible = night


## Put mast i somewhere else at another scale (the bus ride draws them near and small
## in the direction they really are: ride_scenery.gd).
func set_mast(i: int, pos: Vector3, s: float) -> void:
	var r := get_child(i) as Node3D
	if r != null:
		r.position = pos
		r.scale = Vector3.ONE * s


## Haze by hand (the bus ride has no outdoor fog of the camp's to read).
func set_haze_value(haze: float, col: Color) -> void:
	for m in [_body, _wire]:
		m.set_shader_parameter("haze", haze)
		m.set_shader_parameter("haze_color", col)
	var glow := 1.0 - haze * 0.75
	_lamp.set_shader_parameter("glow", glow)
	for t in _top_lamps:
		((t as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("glow", glow)


## Haze by the outdoor fog (called now and then by town_trip.gd).
func update_haze(env: Environment, from: Vector3) -> void:
	if env == null:
		return
	var dist := from.distance_to(global_position + SPOTS[0]) / SCALE
	var density := env.fog_density if env.fog_enabled else 0.002
	var haze := clampf(1.0 - exp(-density * dist * HAZE_SCALE), 0.0, 1.0)
	var col := env.fog_light_color
	for m in [_body, _wire]:
		m.set_shader_parameter("haze", haze)
		m.set_shader_parameter("haze_color", col)
	var glow := 1.0 - haze * 0.75
	_lamp.set_shader_parameter("glow", glow)
	for t in _top_lamps:
		((t as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("glow", glow)


func _process(delta: float) -> void:
	_t += delta
	# The top lamp breathes, in steps (Step12 time like the rest of the machinery).
	var step := floorf(_t * 12.0) / 12.0
	var k := 0.55 + 0.45 * sin(step * 1.6)
	for t in _top_lamps:
		var m := (t as MeshInstance3D).material_override as ShaderMaterial
		m.set_shader_parameter("color", Color(1.0, 0.18, 0.08) * k)
