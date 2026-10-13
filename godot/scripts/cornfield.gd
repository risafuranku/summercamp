extends Node3D

## Past the west fence: a field of tall corn with a scarecrow in it, and a high-voltage
## line marching along behind on steel pylons. The wires hum; at night the pylon tops
## blink red. A good place to be chased through, and a bad place to get lost in.
##
## A wicket gate in the west fence lets you in. Behind it the corn has been cut into a
## maze (new every game: a random walk with a few loops), the paths 1.6 m wide, the
## stalks a wall you cannot push through. The night job "Someone is in the corn"
## (scripts/corn_hunt.gd) sends you in after a lost guest. Built by world_generator.gd.

const CORN_TEX := "res://assets/textury/world/corn.png"
const SCARECROW_TEX := "res://assets/textury/world/scarecrow.png"
const HUM_SFX := "res://assets/sfx/world/pylon_hum.mp3"
const RUSTLE_SFX := "res://assets/sfx/world/corn_rustle.mp3"
const PYLON_H := 24.0
const PYLON_STEP := 46.0

const TILE := 1.6
const GATE_SFX := "res://assets/sfx/world/gate_creak.mp3"

var field_rect := Rect2()     # x/z of the field, world metres
## The maze: a grid of TILE squares over `maze_rect`; true = path. Odd cells are rooms.
var maze_rect := Rect2()
var maze_cols := 0
var maze_rows := 0
var maze_open: Dictionary = {}   # Vector2i -> true for path tiles
var entrance := Vector2i(-1, -1)
var fence_x := 0.0
var gate_z := 0.0
var scarecrow: Sprite3D
var _gate_leaf: Node3D
var _gate_open := 0.0
var _gate_sfx: AudioStreamPlayer3D
var line_x := 0.0             # where the pylons stand
var line_z := Vector2.ZERO    # from..to along z
var _lights: Array[Node3D] = []
var _t := 0.0
var _main: Node


func build(p_field: Rect2, p_line_x: float, p_line_z: Vector2, rng: RandomNumberGenerator, p_fence_x: float = 0.0, p_gate_z: float = 0.0) -> void:
	field_rect = p_field
	line_x = p_line_x
	line_z = p_line_z
	fence_x = p_fence_x
	gate_z = p_gate_z
	_build_maze(rng)
	_build_corn(rng)
	_build_wicket_gate()
	_build_scarecrow(rng)
	_build_line()
	_build_sound()


func _process(delta: float) -> void:
	_t += delta
	_update_gate(delta)
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


# ── the maze ─────────────────────────────────────────────────────────────────

func _build_maze(rng: RandomNumberGenerator) -> void:
	var width := field_rect.size.x - 2.0
	var depth := minf(field_rect.size.y - 6.0, 40.0)
	maze_cols = int(width / TILE)
	maze_rows = int(depth / TILE)
	if maze_cols % 2 == 0:
		maze_cols -= 1
	if maze_rows % 2 == 0:
		maze_rows -= 1
	var w := maze_cols * TILE
	var d := maze_rows * TILE
	# East edge 1 m in from the field's fence side; centred on the gate.
	maze_rect = Rect2(field_rect.end.x - 1.0 - w, clampf(gate_z - d * 0.5, field_rect.position.y + 2.0, field_rect.end.y - 2.0 - d), w, d)
	maze_open.clear()
	# A random walk from a random room, then a few walls knocked through for loops.
	var start := Vector2i(1 + 2 * rng.randi_range(0, (maze_cols - 3) / 2), 1 + 2 * rng.randi_range(0, (maze_rows - 3) / 2))
	var stack: Array[Vector2i] = [start]
	maze_open[start] = true
	while not stack.is_empty():
		var cur: Vector2i = stack.back()
		var dirs := [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]
		_shuffle(dirs, rng)
		var moved := false
		for dvec in dirs:
			var nxt: Vector2i = cur + dvec
			if nxt.x < 1 or nxt.y < 1 or nxt.x > maze_cols - 2 or nxt.y > maze_rows - 2 or maze_open.has(nxt):
				continue
			maze_open[cur + dvec / 2] = true
			maze_open[nxt] = true
			stack.append(nxt)
			moved = true
			break
		if not moved:
			stack.pop_back()
	for i in int(maze_cols * maze_rows * 0.025):
		var wall := Vector2i(rng.randi_range(1, maze_cols - 2), rng.randi_range(1, maze_rows - 2))
		if (wall.x + wall.y) % 2 == 1:
			maze_open[wall] = true
	# The way in: the east edge, on the room row nearest the gate.
	var row := clampi(int((gate_z - maze_rect.position.y) / TILE), 1, maze_rows - 2)
	if row % 2 == 0:
		row += 1 if row + 1 < maze_rows - 1 else -1
	entrance = Vector2i(maze_cols - 1, row)
	maze_open[entrance] = true
	gate_z = tile_world(entrance).z
	# Stalks you cannot walk through: one long box per run of wall tiles in a row.
	var body := StaticBody3D.new()
	body.name = "MazeWalls"
	add_child(body)
	# Solid ground under the maze and the path to it (the camp's ground stops at the fence).
	var floor_rect := maze_rect.merge(Rect2(maze_rect.end.x - 1.0, gate_z - TILE, fence_x - maze_rect.end.x + 2.0, TILE * 2.0)).grow(1.0)
	_wall_box(body, Vector3(floor_rect.get_center().x, -0.5, floor_rect.get_center().y), Vector3(floor_rect.size.x, 1.0, floor_rect.size.y))
	for r in maze_rows:
		var c := 0
		while c < maze_cols:
			if maze_open.has(Vector2i(c, r)):
				c += 1
				continue
			var c0 := c
			while c < maze_cols and not maze_open.has(Vector2i(c, r)):
				c += 1
			var a := tile_world(Vector2i(c0, r))
			var b := tile_world(Vector2i(c - 1, r))
			_wall_box(body, (a + b) * 0.5 + Vector3(0, 1.2, 0), Vector3(b.x - a.x + TILE, 2.4, TILE))
	# The path from the gate to the way in: walled on both sides, through the cut corn.
	var path_x0 := maze_rect.end.x
	var path_len := fence_x - path_x0
	if path_len > 0.1:
		for side: float in [-1.0, 1.0]:
			_wall_box(body, Vector3(path_x0 + path_len * 0.5, 1.2, gate_z + side * (TILE * 0.5 + 0.15)), Vector3(path_len, 2.4, 0.3))


func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func _on_gate_path(p: Vector2) -> bool:
	return p.x > maze_rect.end.x - 0.2 and p.x < fence_x + 0.5 and absf(p.y - gate_z) < TILE * 0.8


func _wall_box(body: StaticBody3D, center: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = center
	body.add_child(cs)


## The centre of maze tile `c` on the ground.
func tile_world(c: Vector2i) -> Vector3:
	return Vector3(maze_rect.position.x + (float(c.x) + 0.5) * TILE, 0.0, maze_rect.position.y + (float(c.y) + 0.5) * TILE)


func world_tile(p: Vector3) -> Vector2i:
	return Vector2i(int(floor((p.x - maze_rect.position.x) / TILE)), int(floor((p.z - maze_rect.position.y) / TILE)))


func in_maze(p: Vector3) -> bool:
	return maze_rect.has_point(Vector2(p.x, p.z))


## Path tiles with one way out (the ends of the corridors), not the way in.
func dead_ends() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for t in maze_open.keys():
		if t == entrance:
			continue
		var n := 0
		for dvec in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if maze_open.has(t + dvec):
				n += 1
		if n == 1:
			out.append(t)
	return out


## Shortest way between two path tiles (tiles from `a` to `b`), empty if none.
func path_between(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var prev := {a: a}
	var queue: Array[Vector2i] = [a]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == b:
			break
		for dvec in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + dvec
			if maze_open.has(n) and not prev.has(n):
				prev[n] = cur
				queue.append(n)
	if not prev.has(b):
		return []
	var out: Array[Vector2i] = [b]
	while out.back() != a:
		out.append(prev[out.back()])
	out.reverse()
	return out


## The world point inside the camp just through the gate.
func gate_inside() -> Vector3:
	return Vector3(fence_x + 1.4, 0.0, gate_z)


# ── the wicket gate ──────────────────────────────────────────────────────────

func _build_wicket_gate() -> void:
	if fence_x == 0.0:
		return
	var K = load("res://scripts/interior_kit.gd")
	var root := Node3D.new()
	root.name = "WicketGate"
	root.position = Vector3(fence_x, 0.0, gate_z)
	add_child(root)
	var posts = K.surface("planks_dark", 0.6)
	for side: float in [-1.0, 1.0]:
		K.slab(root, Vector3(0.16, 1.5, 0.16), Vector3(0, 0.75, side * (TILE * 0.5 + 0.08)), posts, "GatePost")
	K.slab(root, Vector3(0.12, 0.12, TILE + 0.4), Vector3(0, 1.56, 0), posts, "GateLintel")
	# The leaf: pickets on two rails, hinged on the south post.
	var hinge := Node3D.new()
	hinge.name = "GateHinge"
	hinge.position = Vector3(0, 0, -TILE * 0.5)
	root.add_child(hinge)
	var planks = K.surface("planks_grey", 1.0)
	for i in 6:
		K.slab(hinge, Vector3(0.05, 1.05, 0.16), Vector3(0, 0.62, 0.15 + i * 0.25), planks, "Picket")
	for y: float in [0.32, 0.92]:
		K.slab(hinge, Vector3(0.06, 0.1, TILE - 0.05), Vector3(0.04, y, TILE * 0.5), planks, "Rail")
	_gate_leaf = hinge
	_gate_sfx = AudioStreamPlayer3D.new()
	_gate_sfx.stream = load(GATE_SFX) if ResourceLoader.exists(GATE_SFX) else null
	_gate_sfx.unit_size = 4.0
	root.add_child(_gate_sfx)


## The gate swings open as you come up to it (from either side) and falls shut after.
func _update_gate(delta: float) -> void:
	if _gate_leaf == null or _main == null:
		return
	var player = _main.get("_player")
	if player == null or not is_instance_valid(player):
		return
	var near: bool = Vector2(player.global_position.x - fence_x, player.global_position.z - gate_z).length() < 2.6
	var target := 1.0 if near else 0.0
	if target > 0.5 and _gate_open < 0.05 and _gate_sfx != null and _gate_sfx.stream != null:
		_gate_sfx.play()
	_gate_open = move_toward(_gate_open, target, delta * (2.2 if near else 0.9))
	# Stepped, like the rest of the old machinery: 10 positions a second.
	var shown := floorf(ease(_gate_open, 0.6) * 10.0) / 10.0
	_gate_leaf.rotation.y = shown * deg_to_rad(-100.0)


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
			# A few gaps, as if something has walked through. The maze is planted below.
			var here := Vector2(field_rect.position.x + row, field_rect.position.y + z)
			if rng.randf() > 0.06 and not maze_rect.grow(0.3).has_point(here) and not _on_gate_path(here):
				var p := Vector3(field_rect.position.x + row + rng.randf_range(-0.15, 0.15), 0.0, field_rect.position.y + z + rng.randf_range(-0.2, 0.2))
				var s := rng.randf_range(0.8, 1.15)
				xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s)), p))
			z += rng.randf_range(0.55, 0.8)
		row += 1.0
	# The maze walls: every wall tile a thicket of stalks.
	for r in maze_rows:
		for c in maze_cols:
			if maze_open.has(Vector2i(c, r)):
				continue
			var centre := tile_world(Vector2i(c, r))
			for k in 4:
				var p := centre + Vector3(rng.randf_range(-0.7, 0.7), 0.0, rng.randf_range(-0.7, 0.7))
				var s := rng.randf_range(0.85, 1.15)
				xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.95, 1.2), s)), p))
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
	scarecrow = spr
	spr.name = "Scarecrow"
	spr.texture = tex
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	spr.shaded = true
	spr.pixel_size = 2.6 / float(tex.get_height())
	spr.offset = Vector2(0, tex.get_height() * 0.5)
	# Somewhere in the maze, at the end of a path.
	var ends := dead_ends()
	spr.position = tile_world(ends[rng.randi_range(0, ends.size() - 1)]) if not ends.is_empty() else Vector3(field_rect.end.x - 5.0, 0.0, field_rect.get_center().y)
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
