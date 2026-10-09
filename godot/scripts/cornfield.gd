extends Node3D

## Past the west fence: a field of tall corn with a scarecrow in it, and a high-voltage
## line marching along behind on steel pylons. The wires hum; at night the pylon tops
## blink red. A good place to be chased through, and a bad place to get lost in.
## Visual and sound only (it is outside the fence); built by world_generator.gd.

const CORN_TEX := "res://assets/textury/world/corn.png"
const SCARECROW_TEX := "res://assets/textury/world/scarecrow.png"
const HUM_SFX := "res://assets/sfx/world/pylon_hum.mp3"
const RUSTLE_SFX := "res://assets/sfx/world/corn_rustle.mp3"
const PYLON_H := 24.0
const PYLON_STEP := 46.0

var field_rect := Rect2()     # x/z of the field, world metres
var line_x := 0.0             # where the pylons stand
var line_z := Vector2.ZERO    # from..to along z
var _lights: Array[Node3D] = []
var _t := 0.0
var _main: Node


func build(p_field: Rect2, p_line_x: float, p_line_z: Vector2, rng: RandomNumberGenerator) -> void:
	field_rect = p_field
	line_x = p_line_x
	line_z = p_line_z
	_build_corn(rng)
	_build_scarecrow(rng)
	_build_line()
	_build_sound()


func _process(delta: float) -> void:
	_t += delta
	if _main == null:
		_main = get_tree().current_scene if get_tree() != null else null
	var night := false
	if _main != null and _main.get("_time_of_day_hours") != null:
		var h := float(_main.get("_time_of_day_hours"))
		night = h >= 19.5 or h < 6.0
	# Slow red blink, all together, like the real ones.
	var on := night and fmod(_t, 2.0) < 1.0
	for l in _lights:
		l.visible = on


# ── corn ─────────────────────────────────────────────────────────────────────

func _build_corn(rng: RandomNumberGenerator) -> void:
	var tex: Texture2D = load(CORN_TEX) if ResourceLoader.exists(CORN_TEX) else null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _cross_quad(Vector2(0.7, 2.4))
	var xforms: Array[Transform3D] = []
	var row := 0.0
	while row < field_rect.size.x:
		var z := 0.0
		while z < field_rect.size.y:
			# A few gaps, as if something has walked through.
			if rng.randf() > 0.06:
				var p := Vector3(field_rect.position.x + row + rng.randf_range(-0.15, 0.15), 0.0, field_rect.position.y + z + rng.randf_range(-0.2, 0.2))
				var s := rng.randf_range(0.8, 1.15)
				xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s)), p))
			z += rng.randf_range(0.55, 0.8)
		row += 1.0
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = "Corn"
	mi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if tex != null:
		mat.albedo_texture = tex
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.5
	else:
		mat.albedo_color = Color(0.62, 0.6, 0.3)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# The soil under it: darker, ploughed.
	var soil := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = field_rect.size + Vector2(2, 2)
	soil.mesh = plane
	soil.position = Vector3(field_rect.get_center().x, 0.015, field_rect.get_center().y)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.24, 0.19, 0.13)
	soil.material_override = sm
	add_child(soil)


func _cross_quad(size: Vector2) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in [Vector3(1, 0, 0), Vector3(0, 0, 1)]:
		var a: Vector3 = axis * size.x * 0.5
		var h := Vector3(0, size.y, 0)
		var n: Vector3 = axis.cross(Vector3.UP)
		var verts := [[-a, Vector2(0, 1)], [a, Vector2(1, 1)], [a + h, Vector2(1, 0)], [-a, Vector2(0, 1)], [a + h, Vector2(1, 0)], [-a + h, Vector2(0, 0)]]
		for v in verts:
			st.set_normal(n)
			st.set_uv(v[1])
			st.add_vertex(v[0])
	return st.commit()


func _build_scarecrow(rng: RandomNumberGenerator) -> void:
	var tex: Texture2D = load(SCARECROW_TEX) if ResourceLoader.exists(SCARECROW_TEX) else null
	if tex == null:
		return
	var spr := Sprite3D.new()
	spr.name = "Scarecrow"
	spr.texture = tex
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	spr.shaded = true
	spr.pixel_size = 2.6 / float(tex.get_height())
	spr.offset = Vector2(0, tex.get_height() * 0.5)
	# Near the fence side of the field, in line with the middle of the camp.
	spr.position = Vector3(field_rect.end.x - 5.0, 0.0, field_rect.get_center().y + rng.randf_range(-10.0, 10.0))
	add_child(spr)


# ── the power line ───────────────────────────────────────────────────────────

func _build_line() -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.36, 0.37, 0.38)
	steel.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var tower := _pylon_mesh()
	var tops: Array = []
	var z := line_z.x
	while z <= line_z.y:
		var mi := MeshInstance3D.new()
		mi.mesh = tower
		mi.material_override = steel
		mi.position = Vector3(line_x, 0.0, z)
		add_child(mi)
		tops.append(mi.position)
		var light := _red_light()
		light.position = mi.position + Vector3(0, PYLON_H + 0.6, 0)
		add_child(light)
		_lights.append(light)
		z += PYLON_STEP
	# Three wires each side, sagging between towers.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	for i in tops.size() - 1:
		var a: Vector3 = tops[i]
		var b: Vector3 = tops[i + 1]
		for arm in [Vector3(-5.5, PYLON_H - 3.0, 0), Vector3(5.5, PYLON_H - 3.0, 0), Vector3(-3.8, PYLON_H - 7.0, 0), Vector3(3.8, PYLON_H - 7.0, 0), Vector3(-6.5, PYLON_H - 11.0, 0), Vector3(6.5, PYLON_H - 11.0, 0)]:
			var seg := 12
			for k in seg:
				var t0 := float(k) / seg
				var t1 := float(k + 1) / seg
				st.add_vertex((a + arm).lerp(b + arm, t0) - Vector3(0, sin(t0 * PI) * 3.2, 0))
				st.add_vertex((a + arm).lerp(b + arm, t1) - Vector3(0, sin(t1 * PI) * 3.2, 0))
	var wires := MeshInstance3D.new()
	wires.mesh = st.commit()
	var wm := StandardMaterial3D.new()
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.albedo_color = Color(0.08, 0.08, 0.09)
	wires.material_override = wm
	add_child(wires)


## A lattice tower: four tapering legs, cross-bracing, three cross arms.
func _pylon_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := 3.0
	var top := 0.7
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	var levels := 8
	for lv in levels:
		var y0 := PYLON_H * float(lv) / levels
		var y1 := PYLON_H * float(lv + 1) / levels
		var w0 := lerpf(base, top, float(lv) / levels)
		var w1 := lerpf(base, top, float(lv + 1) / levels)
		for c in corners:
			_beam(st, Vector3(c.x * w0, y0, c.y * w0), Vector3(c.x * w1, y1, c.y * w1), 0.16)
		for i in 4:
			var c0: Vector2 = corners[i]
			var c1: Vector2 = corners[(i + 1) % 4]
			_beam(st, Vector3(c0.x * w0, y0, c0.y * w0), Vector3(c1.x * w1, y1, c1.y * w1), 0.07)
			_beam(st, Vector3(c1.x * w0, y0, c1.y * w0), Vector3(c0.x * w1, y1, c0.y * w1), 0.07)
	for arm in [[PYLON_H - 3.0, 5.8], [PYLON_H - 7.0, 4.1], [PYLON_H - 11.0, 6.8]]:
		_beam(st, Vector3(-arm[1], arm[0], 0), Vector3(arm[1], arm[0], 0), 0.14)
	st.generate_normals()
	return st.commit()


func _beam(st: SurfaceTool, a: Vector3, b: Vector3, r: float) -> void:
	var d := (b - a).normalized()
	var side := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized() * r
	var up := d.cross(side).normalized() * r
	var ring := [side + up, side - up, -side - up, -side + up]
	for i in 4:
		var p0: Vector3 = ring[i]
		var p1: Vector3 = ring[(i + 1) % 4]
		st.add_vertex(a + p0)
		st.add_vertex(b + p0)
		st.add_vertex(b + p1)
		st.add_vertex(a + p0)
		st.add_vertex(b + p1)
		st.add_vertex(a + p1)


func _red_light() -> Node3D:
	var root := Node3D.new()
	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.35
	sphere.height = 0.7
	bulb.mesh = sphere
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.12, 0.08)
	bulb.material_override = m
	root.add_child(bulb)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.15, 0.1)
	l.light_energy = 1.6
	l.omni_range = 9.0
	l.shadow_enabled = false
	root.add_child(l)
	root.visible = false
	return root


func _build_sound() -> void:
	var hum: AudioStream = load(HUM_SFX) if ResourceLoader.exists(HUM_SFX) else null
	if hum is AudioStreamMP3:
		(hum as AudioStreamMP3).loop = true
	var rustle: AudioStream = load(RUSTLE_SFX) if ResourceLoader.exists(RUSTLE_SFX) else null
	if rustle is AudioStreamMP3:
		(rustle as AudioStreamMP3).loop = true
	var z := line_z.x
	while hum != null and z <= line_z.y:
		var p := AudioStreamPlayer3D.new()
		p.stream = hum
		p.position = Vector3(line_x, 6.0, z)
		p.unit_size = 6.0
		p.max_distance = 45.0
		p.volume_db = -6.0
		p.autoplay = true
		add_child(p)
		z += PYLON_STEP * 2.0
	if rustle != null:
		for k in 3:
			var r := AudioStreamPlayer3D.new()
			r.stream = rustle
			r.position = Vector3(field_rect.get_center().x, 1.0, field_rect.position.y + field_rect.size.y * (0.2 + 0.3 * k))
			r.unit_size = 5.0
			r.max_distance = 30.0
			r.volume_db = -10.0
			r.autoplay = true
			add_child(r)
