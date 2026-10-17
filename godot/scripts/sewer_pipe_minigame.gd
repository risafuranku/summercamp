extends CanvasLayer

## The pipe crawl: fixing a broken sewer from the inside (DESIGN.md §8).
##
## A pipe network is generated for each breakdown (seeded by the sewer and the day it
## broke, so leaving and coming back finds the same pipes). You crawl it in first
## person: W moves to the next junction, A/D take a side branch at a junction, there is
## no turning around. Hold TAB to read the paper map the last worker left: it shows the
## pipes, the coordinates, the entry ladder, the leak (red X) and a few landmarks, but
## not where you are. While you read, you are not moving. Coordinates are stencilled
## at some junctions only; between them you count turns, or recognise a landmark.
## At the leak, hold E to clamp it; then find your way back to the ladder and press E.
##
## Something lives down here, and how much of it you meet grows with your visits; what
## it is and how it is staged is scripts/pipes/pipe_director.gd. The rules, which the old
## worker's note on the map spells out:
##   - It is blind. It hunts by sound: every step you take splashes, and the clamp rings
##     louder. It goes to where it last heard you.
##   - It hates light. Keep the torch on it down a straight pipe and it folds away.
##   - You hear it before you see it: knocks and splashes far off, breathing when it is
##     next to you. Hold S to look back over your shoulder.
##   - If it reaches you it drags you back through the dark to the ladder (and hurts):
##     a half-done clamp slips off. The job is not lost, the time is.
##
## The look of it: you climb down the ladder, the worker's map unfolds for a moment,
## your gloved hand holds the torch in front of you (a Build-engine weapon sprite), the
## water along the bottom of the pipes runs away from the leak (follow it upstream), it
## drips, the torch stutters when something is close.

signal repair_completed(coord: Vector2i, building_type: String)
signal repair_cancelled
signal player_hurt(amount: int)

const RETRO_RENDER = preload("res://scripts/retro_render.gd")
const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")

const PIPE_TEXTURE := "res://assets/textury/pipes/pipe_concrete.png"
## The old 1962 sections that the 1993 works did not reach: brick.
const BRICK_TEXTURE := "res://assets/textury/pipes/pipe_brick.png"
const SHOE_SPRITE := "res://assets/textury/pipes/red_shoe.png"
const SCRATCHES := "res://assets/textury/mess/decal_scratches.png"
const PAPER_TEXTURE := "res://assets/textury/pipes/paper_map.png"
const DIRECTOR = preload("res://scripts/pipes/pipe_director.gd")
const WORK_HAND = preload("res://scripts/ui/work_hand.gd")
const WATER_SHADER = preload("res://materials/pipe_water.gdshader")
const HAND_TORCH := "res://assets/textury/hands/torch.png"
const LUNGE_SPRITE := "res://assets/textury/npc/pipe_lunge.png"
const HANDPRINT := "res://assets/textury/mess/decal_handprint.png"
const SCUM := "res://assets/textury/pipes/sludge.png"
const SFX_DIR := "res://assets/sfx/pipes/"
const SFX_AMBIENCE := "res://assets/sfx/rednecksfx/rrswerambience.wav"
const SFX_PIPES := "res://assets/sfx/ambiencesfx/pipesambience.mp3"
const SFX_LEAK := "res://assets/sfx/weather/calmrain.mp3"
const SFX_THING := "res://assets/sfx/npc/silentdistract2.mp3"
const SFX_CLANK := "res://assets/sfx/rednecksfx/rrtick.wav"

const GRID := Vector2i(6, 5)
const COLS := "ABCDEFGH"
const CELL := 3.2
const PIPE_R := 0.8
const ARM_R := 0.9
const ARM_LEN := 1.0
const SIDES := 10
const EYE_Y := 0.78
const MOVE_SECONDS := 0.6
const CLAMP_SECONDS := 2.6
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]  # N E S W
const DIR_YAW := [0.0, -PI * 0.5, PI, PI * 0.5]
const LANDMARKS := ["crack", "tally", "rags", "bucket", "shoe", "scratches"]
const LANDMARK_MAP_GLYPH := {"crack": "~", "tally": "IIII", "rags": "#", "bucket": "o", "shoe": "!", "scratches": "///"}

var _active: bool = false
var _coord: Vector2i = Vector2i.ZERO
var _building_type: String = ""
var _rng := RandomNumberGenerator.new()

# network
var _links: Dictionary = {}      # Vector2i -> Array[int] of open directions
var _entry: Vector2i
var _leak_a: Vector2i
var _leak_b: Vector2i
var _plates: Dictionary = {}     # Vector2i -> true
var _landmarks: Array = []       # {a, b, kind, on_map}
var _fixed: bool = false

# player
var _node: Vector2i
var _facing: int = 0
var _moving: bool = false
var _move_from: Vector3
var _move_to: Vector3
var _move_t: float = 0.0
var _move_target_node: Vector2i
var _at_leak: bool = false
var _clamp: float = 0.0
var _bob: float = 0.0
var _map_open: bool = false

# the thing and its staging (pipe_director.gd)
var _director
var _visit := 1
## Looking back over your shoulder (hold S): 0..1.
var glancing := false
var _glance := 0.0
## Climbing down at the start, then the map unfolds for a moment.
var _intro_t := -1.0
## Caught: the lunge, the dark, the drag back to the ladder.
var _caught_t := -1.0
var _caught_hit := false
var _torch_hand: TextureRect
var _work_hand: Control
var _lunge: TextureRect
var _black: ColorRect
var _drips: Array = []
var _step_player: AudioStreamPlayer
var _one: AudioStreamPlayer
var _prints_placed := false
var _flicker_t := 0.0
var _night := false

# scene
var _root: Control
var _container: SubViewportContainer
var _viewport: SubViewport
var _world: Node3D
var _geo: Node3D
var _rig: Node3D
var _camera: Camera3D
var _flashlight: SpotLight3D
var _leak_fx: GPUParticles3D
var _leak_audio: AudioStreamPlayer3D
var _ambience: AudioStreamPlayer
var _pipes_bed: AudioStreamPlayer
var _hud_status: Label
var _hud_controls: Label
var _hud_bar
var _map: Control
var _paper: TextureRect
var _ink: Control
var _pipe_mat: StandardMaterial3D
var _brick_mat: StandardMaterial3D
var _scale: int = 3


func _ready() -> void:
	layer = 128
	visible = false
	_build_shell()


func is_open() -> bool:
	return _active


func open_repair(coord: Vector2i, building_type: String, _label_text: String = "") -> void:
	_coord = coord
	_building_type = building_type
	var since_day := 1
	var state = CoreRoot.get_state() if CoreRoot != null else null
	if state != null:
		since_day = int((state.failures.get("%d:%d" % [coord.x, coord.y], {}) as Dictionary).get("since_day", state.day))
	_rng.seed = hash("%d:%d:%d" % [coord.x, coord.y, since_day])
	_generate()
	_build_world()
	_fixed = false
	_node = _entry
	_facing = 0
	_moving = false
	_at_leak = false
	_clamp = 0.0
	_map_open = false
	_night = CoreRoot != null and CoreRoot.is_night()
	_visit = _next_visit()
	_director = DIRECTOR.new()
	_director.start(self, _visit, _night, _rng.randi())
	_prints_placed = false
	glancing = false
	_glance = 0.0
	_caught_t = -1.0
	_black.color.a = 0.0
	_lunge.visible = false
	_active = true
	visible = true
	_rebuild_hud()
	_set_status("")
	_play(_ambience)
	_play(_pipes_bed)
	for d in _drips:
		(d as AudioStreamPlayer3D).play()
	_intro_t = 0.0
	_play_one("ladder.mp3", -4.0)
	_update_rig(0.0)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


## How many times you have been down (the camp office keeps the count over the week).
func _next_visit() -> int:
	var main := get_parent()
	var office = main.get("camp_office") if main != null else null
	if office == null:
		return 3
	var n := int(office.get("pipe_visits")) + 1
	office.set("pipe_visits", n)
	return n


## Leaving from the pause menu: up the ladder at once (a clamped leak still counts).
func abort() -> void:
	if not _active:
		return
	close_repair(not _fixed)
	if _fixed:
		repair_completed.emit(_coord, _building_type)


func close_repair(cancelled: bool = true) -> void:
	if not _active:
		return
	_active = false
	visible = false
	for a in [_ambience, _pipes_bed]:
		if a != null:
			a.stop()
	if _leak_audio != null:
		_leak_audio.stop()
	if _director != null:
		_director.stop()
	for d in _drips:
		(d as AudioStreamPlayer3D).stop()
	if _work_hand != null:
		_work_hand.stop()
	if cancelled:
		repair_cancelled.emit()


# ── network ───────────────────────────────────────────────────────────────────

func _generate() -> void:
	_links.clear()
	_plates.clear()
	_landmarks.clear()
	for y in GRID.y:
		for x in GRID.x:
			_links[Vector2i(x, y)] = []
	# Spanning tree by randomised DFS, then extra loops, then no dead ends: with no
	# turning around, every junction needs a way on.
	var start := Vector2i(_rng.randi_range(0, GRID.x - 1), _rng.randi_range(0, GRID.y - 1))
	var stack: Array[Vector2i] = [start]
	var seen := {start: true}
	while not stack.is_empty():
		var c: Vector2i = stack.back()
		var options: Array[int] = []
		for d in 4:
			var n: Vector2i = c + DIRS[d]
			if _in_grid(n) and not seen.has(n):
				options.append(d)
		if options.is_empty():
			stack.pop_back()
			continue
		var pick := options[_rng.randi_range(0, options.size() - 1)]
		var nxt: Vector2i = c + DIRS[pick]
		_connect(c, pick)
		seen[nxt] = true
		stack.append(nxt)
	for c in _links.keys():
		for d in [1, 2]:
			var n: Vector2i = c + DIRS[d]
			if _in_grid(n) and not _links[c].has(d) and _rng.randf() < 0.28:
				_connect(c, d)
	for c in _links.keys():
		while _links[c].size() < 2:
			var free: Array[int] = []
			for d in 4:
				if _in_grid(c + DIRS[d]) and not _links[c].has(d):
					free.append(d)
			if free.is_empty():
				break
			_connect(c, free[_rng.randi_range(0, free.size() - 1)])
	_entry = Vector2i(GRID.x / 2, GRID.y - 1)
	if not _links[_entry].has(0):
		_connect(_entry, 0)
	# The leak: an edge as far from the ladder as the network allows.
	var dist := _distances_from(_entry)
	var best := -1
	var edges := _edges()
	_shuffle(edges)
	for e in edges:
		var dd: int = mini(int(dist.get(e[0], 0)), int(dist.get(e[1], 0)))
		if dd > best:
			best = dd
			_leak_a = e[0]
			_leak_b = e[1]
	# Stencilled coordinates: always at the ladder, at some junctions, rarely at bends.
	for c in _links.keys():
		var deg: int = _links[c].size()
		if c == _entry or (deg >= 3 and _rng.randf() < 0.45) or (deg == 2 and _rng.randf() < 0.12):
			_plates[c] = true
	# Landmarks on five other pipes; the last worker noted three of them on the map.
	var pool := edges.filter(func(e): return not (_same_edge(e[0], e[1], _leak_a, _leak_b)))
	_shuffle(pool)
	for i in mini(6, pool.size()):
		_landmarks.append({"a": pool[i][0], "b": pool[i][1], "kind": LANDMARKS[i % LANDMARKS.size()], "on_map": i < 3})


## Seeded shuffle: Array.shuffle() uses the global RNG, which would give the same
## breakdown a different network every time you climbed down.
func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t


func _connect(c: Vector2i, d: int) -> void:
	var n: Vector2i = c + DIRS[d]
	if not _links[c].has(d):
		_links[c].append(d)
	var back := (d + 2) % 4
	if not _links[n].has(back):
		_links[n].append(back)


func _in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < GRID.x and c.y < GRID.y


func _edges() -> Array:
	var out: Array = []
	for c in _links.keys():
		for d in _links[c]:
			if d == 1 or d == 2:
				out.append([c, c + DIRS[d]])
	return out


func _same_edge(a: Vector2i, b: Vector2i, c: Vector2i, d: Vector2i) -> bool:
	return (a == c and b == d) or (a == d and b == c)


func _distances_from(src: Vector2i) -> Dictionary:
	var dist := {src: 0}
	var q: Array[Vector2i] = [src]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		for d in _links[c]:
			var n: Vector2i = c + DIRS[d]
			if not dist.has(n):
				dist[n] = int(dist[c]) + 1
				q.append(n)
	return dist


func _label(c: Vector2i) -> String:
	return "%s%d" % [COLS[c.x], c.y + 1]


func _world_pos(c: Vector2i) -> Vector3:
	return Vector3(float(c.x) * CELL, EYE_Y, float(c.y) * CELL)


# ── 3D ────────────────────────────────────────────────────────────────────────

func _build_shell() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_container = SubViewportContainer.new()
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.stretch = true
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_container)
	RETRO_RENDER.register(_container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.handle_input_locally = false
	_container.add_child(_viewport)
	_world = Node3D.new()
	_viewport.add_child(_world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.10, 0.11, 0.10)
	env.ambient_light_energy = 0.12
	env.fog_enabled = true
	env.fog_light_color = Color(0.02, 0.02, 0.02)
	env.fog_density = 0.09
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	_rig = Node3D.new()
	_world.add_child(_rig)
	_camera = Camera3D.new()
	_camera.fov = 62.0
	_camera.near = 0.03
	_camera.far = 30.0
	_camera.current = true
	_rig.add_child(_camera)
	_flashlight = SpotLight3D.new()
	_flashlight.light_color = Color(0.95, 0.9, 0.76)
	_flashlight.light_energy = 3.0
	_flashlight.spot_range = 12.0
	_flashlight.spot_angle = 34.0
	_flashlight.spot_attenuation = 0.9
	_camera.add_child(_flashlight)
	_pipe_mat = StandardMaterial3D.new()
	_pipe_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	_pipe_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_pipe_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_pipe_mat.roughness = 0.95
	if ResourceLoader.exists(PIPE_TEXTURE):
		_pipe_mat.albedo_texture = load(PIPE_TEXTURE)
	else:
		_pipe_mat.albedo_color = Color(0.3, 0.32, 0.31)
	_brick_mat = _pipe_mat.duplicate() as StandardMaterial3D
	if ResourceLoader.exists(BRICK_TEXTURE):
		_brick_mat.albedo_texture = load(BRICK_TEXTURE)
	_ambience = _make_player(SFX_AMBIENCE, -9.0, true)
	_pipes_bed = _make_player(SFX_PIPES, -14.0, true)
	_build_hud_nodes()


func _make_player(path: String, db: float, loop: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = db
	if ResourceLoader.exists(path):
		var s := load(path) as AudioStream
		if loop:
			_set_loop(s)
		p.stream = s
	add_child(p)
	return p


func _set_loop(s: AudioStream) -> void:
	if s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	elif s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true


func _play(p: AudioStreamPlayer) -> void:
	if p != null and p.stream != null and not p.playing:
		p.play()


func _build_world() -> void:
	if _geo != null and is_instance_valid(_geo):
		_geo.queue_free()
	_geo = Node3D.new()
	_world.add_child(_geo)
	# The whole network is one CSG union: drums at junctions and full-length pipes
	# between them. Separate meshes would cap each other off; a union has only the
	# inside surface, which is what we see (front faces culled).
	var comb := CSGCombiner3D.new()
	for c in _links.keys():
		_junction(comb, c)
		for d in _links[c]:
			if d == 1 or d == 2:
				_pipe(comb, c, c + DIRS[d])
	_geo.add_child(comb)
	for c in _links.keys():
		if _plates.has(c):
			_stencil(c)
	_build_ladder()
	for lm in _landmarks:
		_build_landmark(lm)
	_build_leak()
	_build_water()
	_build_drips()


## The trickle along the bottom of every pipe, running away from the leak (the farther a
## pipe is from the leak, the less there is). Follow it upstream.
func _build_water() -> void:
	var dist := _distances_from(_leak_a)
	var mat_cache := {}
	var scum: Texture2D = load(SCUM) if ResourceLoader.exists(SCUM) else null
	# The pipe's invert is 0.08 below the junction floor: the water lies a little above it.
	var floor_y := EYE_Y - PIPE_R * 0.9 - 0.02
	for e in _edges():
		var a: Vector2i = e[0]
		var b: Vector2i = e[1]
		var da := int(dist.get(a, 9))
		var db := int(dist.get(b, 9))
		# Flow from the end nearer the leak to the farther one.
		var src := a if da <= db else b
		var dst := b if src == a else a
		var strength := clampf(1.0 - float(mini(da, db)) / 6.0, 0.15, 1.0)
		var key := snappedf(strength, 0.1)
		if not mat_cache.has(key):
			var m := ShaderMaterial.new()
			m.shader = WATER_SHADER
			m.set_shader_parameter("strength", strength)
			m.set_shader_parameter("speed", 0.25 + 0.5 * strength)
			if scum != null:
				m.set_shader_parameter("scum", scum)
				m.set_shader_parameter("has_scum", true)
			mat_cache[key] = m
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.orientation = PlaneMesh.FACE_Y
		q.size = Vector2(PIPE_R * 0.9, CELL)
		mi.mesh = q
		mi.material_override = mat_cache[key]
		var pa := _world_pos(src)
		var pb := _world_pos(dst)
		mi.position = (pa + pb) * 0.5
		mi.position.y = floor_y
		# The quad's +V runs along -Z before turning: face it from src to dst.
		var dir := (pb - pa).normalized()
		mi.rotation.y = atan2(dir.x, dir.z) + PI
		_geo.add_child(mi)


## A few places where it drips from the crown; they fall silent now and then.
func _build_drips() -> void:
	for d in _drips:
		if is_instance_valid(d):
			d.queue_free()
	_drips.clear()
	var nodes := _links.keys()
	_shuffle(nodes)
	for i in mini(4, nodes.size()):
		var p := AudioStreamPlayer3D.new()
		var path := SFX_DIR + "drip.mp3"
		if ResourceLoader.exists(path):
			var st := (load(path) as AudioStreamMP3).duplicate() as AudioStreamMP3
			st.loop = true
			p.stream = st
		p.volume_db = -6.0
		p.max_distance = 12.0
		p.pitch_scale = _rng.randf_range(0.85, 1.15)
		p.position = _world_pos(nodes[i]) + Vector3(0, 0.6, 0)
		_geo.add_child(p)
		_drips.append(p)


## Wet hand prints on the ladder rungs and the wall by it: long fingers, still running.
## The first time down, they are there when you come back to the ladder.
func _place_handprints() -> void:
	if _prints_placed:
		return
	_prints_placed = true
	var p := _world_pos(_entry)
	var tex: Texture2D = load(HANDPRINT) if ResourceLoader.exists(HANDPRINT) else null
	for i in 4:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.2, 0.2)
		mi.mesh = q
		var m := StandardMaterial3D.new()
		if tex != null:
			m.albedo_texture = tex
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		else:
			m.albedo_color = Color(0.08, 0.07, 0.05)
			q.size = Vector2(0.09, 0.14)
		m.roughness = 0.2
		mi.material_override = m
		mi.position = p + Vector3(-0.18 + 0.36 * float(i % 2), -0.1 + 0.32 * float(i), 0.52)
		mi.rotation = Vector3(0, PI, 0.4 * (1.0 if i % 2 == 0 else -1.0))
		_geo.add_child(mi)


func _floor_offset(r: float) -> Vector3:
	return Vector3(0, EYE_Y - r * 0.9, 0)


func _junction(comb: CSGCombiner3D, c: Vector2i) -> void:
	var drum := CSGCylinder3D.new()
	drum.radius = ARM_R * 1.12
	drum.height = ARM_R * 2.0
	drum.sides = SIDES
	drum.material = _pipe_mat
	drum.position = _world_pos(c) - _floor_offset(ARM_R)
	comb.add_child(drum)


func _pipe(comb: CSGCombiner3D, a: Vector2i, b: Vector2i) -> void:
	var cyl := CSGCylinder3D.new()
	cyl.radius = PIPE_R
	cyl.height = CELL
	cyl.sides = SIDES
	# A seeded third of the pipes are the old brick ones (also a landmark of sorts).
	cyl.material = _brick_mat if (absi(hash("%s%s%d" % [a, b, _rng.seed])) % 3) == 0 else _pipe_mat
	cyl.position = (_world_pos(a) + _world_pos(b)) * 0.5 - _floor_offset(PIPE_R)
	cyl.rotation = Vector3(0, 0, PI * 0.5) if a.y == b.y else Vector3(PI * 0.5, 0, 0)
	comb.add_child(cyl)


## Coordinates spray-painted at a junction, readable from every arm.
func _stencil(c: Vector2i) -> void:
	var l := Label3D.new()
	l.text = _label(c)
	l.font = RETRO_UI.FONT_BIG
	l.font_size = 64
	l.pixel_size = 0.006
	l.modulate = Color(0.86, 0.82, 0.70, 0.85)
	l.outline_size = 0
	l.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.shaded = true
	# Up under the crown of the junction: readable while approaching down the pipe,
	# out of the way (above the view) while standing in the junction itself.
	l.position = _world_pos(c) + Vector3(0, 0.58, 0)
	_geo.add_child(l)


func _build_ladder() -> void:
	var p := _world_pos(_entry)
	for x in [-0.22, 0.22]:
		var rail := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.05, 3.0, 0.05)
		rail.mesh = m
		rail.position = p + Vector3(x, 0.4, 0.55)
		rail.material_override = _flat_mat(Color(0.35, 0.22, 0.14))
		_geo.add_child(rail)
	for i in 6:
		var rung := MeshInstance3D.new()
		var m2 := BoxMesh.new()
		m2.size = Vector3(0.48, 0.04, 0.04)
		rung.mesh = m2
		rung.position = p + Vector3(0, -0.3 + float(i) * 0.32, 0.55)
		rung.material_override = _flat_mat(Color(0.35, 0.22, 0.14))
		_geo.add_child(rung)
	var light := OmniLight3D.new()
	light.light_color = Color(0.95, 0.85, 0.6)
	light.light_energy = 0.9
	light.omni_range = 3.5
	light.position = p + Vector3(0, 1.4, 0.5)
	_geo.add_child(light)


func _flat_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m


func _edge_mid(a: Vector2i, b: Vector2i) -> Vector3:
	return (_world_pos(a) + _world_pos(b)) * 0.5


func _build_landmark(lm: Dictionary) -> void:
	var p := _edge_mid(lm["a"], lm["b"])
	var floor_y := EYE_Y - PIPE_R * 0.9 - 0.6
	match str(lm["kind"]):
		"scratches":
			if ResourceLoader.exists(SCRATCHES):
				var mi := MeshInstance3D.new()
				var q := QuadMesh.new()
				q.size = Vector2(0.6, 0.6)
				mi.mesh = q
				var m := StandardMaterial3D.new()
				m.albedo_texture = load(SCRATCHES)
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				mi.material_override = m
				var side2 := Vector3(lm["b"].y - lm["a"].y, 0, lm["a"].x - lm["b"].x).normalized()
				mi.position = p + side2 * (PIPE_R * 0.7) + Vector3(0, 0.1, 0)
				_geo.add_child(mi)
				mi.look_at(p + Vector3(0, 0.1, 0), Vector3.UP)
				mi.rotate_object_local(Vector3.UP, PI)
		"crack", "tally":
			var l := Label3D.new()
			l.text = "\\/\\_/\\" if lm["kind"] == "crack" else "IIII IIII IIII II"
			l.font = RETRO_UI.FONT_TEXT
			l.font_size = 48
			l.pixel_size = 0.006
			l.modulate = Color(0.05, 0.04, 0.04, 0.9) if lm["kind"] == "crack" else Color(0.55, 0.5, 0.45, 0.9)
			l.shaded = true
			l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			var side := Vector3(lm["b"].y - lm["a"].y, 0, lm["a"].x - lm["b"].x).normalized()
			l.position = p + side * (PIPE_R * 0.75) + Vector3(0, 0.15, 0)
			l.look_at_from_position(l.position, p + Vector3(0, 0.15, 0), Vector3.UP)
			l.rotate_object_local(Vector3.UP, PI)
			_geo.add_child(l)
		"rags":
			_lump(p + Vector3(0.2, floor_y + 0.08, 0.1), Vector3(0.45, 0.12, 0.3), Color(0.32, 0.26, 0.18))
		"bucket":
			var mi := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.16
			cyl.bottom_radius = 0.12
			cyl.height = 0.3
			cyl.radial_segments = 8
			mi.mesh = cyl
			mi.material_override = _flat_mat(Color(0.45, 0.24, 0.12))
			mi.position = p + Vector3(-0.2, floor_y + 0.15, 0.0)
			mi.rotation = Vector3(0.5, 0, 0.3)
			_geo.add_child(mi)
		"shoe":
			# One red high-heeled shoe. You have seen someone missing one.
			if ResourceLoader.exists(SHOE_SPRITE):
				var shoe := Sprite3D.new()
				shoe.texture = load(SHOE_SPRITE)
				shoe.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
				shoe.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				shoe.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
				shoe.shaded = true
				shoe.pixel_size = 0.22 / float(shoe.texture.get_width())
				shoe.position = p + Vector3(0.12, floor_y + 0.62, 0.0)
				_geo.add_child(shoe)
			else:
				_lump(p + Vector3(0.1, floor_y + 0.05, 0.0), Vector3(0.22, 0.08, 0.08), Color(0.62, 0.08, 0.06))


func _lump(at: Vector3, size: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = _flat_mat(c)
	mi.position = at
	_geo.add_child(mi)


func _build_leak() -> void:
	var p := _edge_mid(_leak_a, _leak_b)
	_leak_fx = GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 2.2
	pm.gravity = Vector3(0, -9.0, 0)
	pm.color = Color(0.55, 0.6, 0.5, 0.8)
	_leak_fx.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.08)
	var qm := StandardMaterial3D.new()
	qm.albedo_color = Color(0.6, 0.66, 0.55, 0.8)
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = qm
	_leak_fx.draw_pass_1 = q
	_leak_fx.amount = 120
	_leak_fx.lifetime = 0.7
	_leak_fx.position = p + Vector3(0, PIPE_R * 0.6, 0)
	_geo.add_child(_leak_fx)
	_leak_audio = AudioStreamPlayer3D.new()
	if ResourceLoader.exists(SFX_LEAK):
		var s := load(SFX_LEAK) as AudioStream
		_set_loop(s)
		_leak_audio.stream = s
	_leak_audio.volume_db = 4.0
	_leak_audio.max_distance = 14.0
	_leak_audio.position = p
	_geo.add_child(_leak_audio)
	_leak_audio.play()


# ── HUD and map ───────────────────────────────────────────────────────────────

func _build_hud_nodes() -> void:
	_torch_hand = TextureRect.new()
	_torch_hand.texture = load(HAND_TORCH) if ResourceLoader.exists(HAND_TORCH) else null
	_torch_hand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_torch_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_torch_hand.stretch_mode = TextureRect.STRETCH_SCALE
	_root.add_child(_torch_hand)
	_work_hand = WORK_HAND.new()
	_root.add_child(_work_hand)
	_lunge = TextureRect.new()
	_lunge.texture = load(LUNGE_SPRITE) if ResourceLoader.exists(LUNGE_SPRITE) else null
	_lunge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_lunge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lunge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_lunge.visible = false
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_step_player = AudioStreamPlayer.new()
	_step_player.volume_db = -7.0
	add_child(_step_player)
	_one = AudioStreamPlayer.new()
	add_child(_one)
	_hud_bar = RETRO_UI.BevelPanel.new()
	_hud_bar.fill = Color(0.04, 0.035, 0.03, 0.9)
	_root.add_child(_hud_bar)
	_hud_status = Label.new()
	_root.add_child(_hud_status)
	_hud_controls = Label.new()
	_root.add_child(_hud_controls)
	_map = ColorRect.new()
	_map.color = Color(0, 0, 0, 0.55)
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.visible = false
	_root.add_child(_map)
	_paper = TextureRect.new()
	_paper.stretch_mode = TextureRect.STRETCH_SCALE
	_paper.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(PAPER_TEXTURE):
		_paper.texture = load(PAPER_TEXTURE)
	_map.add_child(_paper)
	_ink = Control.new()
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ink.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ink.draw.connect(_draw_map)
	_map.add_child(_ink)
	_root.add_child(_black)
	_root.add_child(_lunge)


func _rebuild_hud() -> void:
	var vp := get_viewport().get_visible_rect().size
	_scale = RETRO_UI.ui_scale(vp.y, vp.x, 400.0)
	var s := float(_scale)
	_hud_bar.ui_scale = _scale
	_hud_bar.position = Vector2(0, vp.y - 14.0 * s)
	_hud_bar.size = Vector2(vp.x, 14.0 * s)
	RETRO_UI.style_label(_hud_controls, RETRO_UI.FONT_LABEL, 8, RETRO_UI.C_BONE_DIM, _scale, false)
	_hud_controls.text = "W FORWARD   A/D TURN AT A JUNCTION   HOLD S LOOK BACK   HOLD TAB MAP   E USE   F LIGHT   ESC LEAVE"
	_hud_controls.position = Vector2(6.0 * s, vp.y - 11.0 * s)
	RETRO_UI.style_label(_hud_status, RETRO_UI.FONT_TEXT, 8, RETRO_UI.C_BONE, _scale, true)
	_hud_status.position = Vector2(6.0 * s, 5.0 * s)
	_map.position = Vector2.ZERO
	_map.size = vp
	_black.position = Vector2.ZERO
	_black.size = vp
	_lunge.position = Vector2.ZERO
	_lunge.size = vp
	if _torch_hand.texture != null:
		var k := float(maxi(1, int(round(vp.y / 300.0))))
		_torch_hand.size = _torch_hand.texture.get_size() * k


func _set_status(text: String) -> void:
	if _hud_status != null:
		_hud_status.text = text


## The paper map: the pipes as the last worker drew them, in pen, slightly wobbly.
## No "you are here".
func _draw_map() -> void:
	var vp := _map.size
	var s := float(_scale)
	var w := minf(vp.x * 0.8, vp.y * 1.15)
	var h := w * 0.75
	var r := Rect2((vp - Vector2(w, h)) * 0.5, Vector2(w, h))
	_paper.position = r.position
	_paper.size = r.size
	var margin := Vector2(w * 0.12, h * 0.14)
	var cell := Vector2((w - margin.x * 2.0) / float(GRID.x - 1), (h - margin.y * 2.0) / float(GRID.y - 1))
	var ink := Color(0.12, 0.10, 0.18, 0.92)
	var pen_rng := RandomNumberGenerator.new()
	pen_rng.seed = hash(_label(_leak_a)) + 7
	var to_px := func(c: Vector2i) -> Vector2:
		return r.position + margin + Vector2(float(c.x) * cell.x, float(c.y) * cell.y)
	for e in _edges():
		var a: Vector2 = to_px.call(e[0])
		var b: Vector2 = to_px.call(e[1])
		var mid := (a + b) * 0.5 + Vector2(pen_rng.randf_range(-1.5, 1.5), pen_rng.randf_range(-1.5, 1.5)) * s
		_ink.draw_line(a, mid, ink, 2.0 * s)
		_ink.draw_line(mid, b, ink, 2.0 * s)
	var font := RETRO_UI.FONT_TEXT
	var fs := 8 * _scale
	for c in _links.keys():
		var p: Vector2 = to_px.call(c)
		_ink.draw_rect(Rect2(p - Vector2(s, s) * 1.5, Vector2(s, s) * 3.0), ink)
		_ink.draw_string(font, p + Vector2(3.0, -3.0) * s, _label(c), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(ink, 0.7))
	# entry
	var ep: Vector2 = to_px.call(_entry)
	_ink.draw_string(RETRO_UI.FONT_LABEL, ep + Vector2(-14.0, 14.0) * s, "LADDER", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	# leak
	var lp: Vector2 = (to_px.call(_leak_a) + to_px.call(_leak_b)) * 0.5
	var red := Color(0.72, 0.08, 0.06, 0.95)
	_ink.draw_line(lp + Vector2(-5, -5) * s, lp + Vector2(5, 5) * s, red, 2.5 * s)
	_ink.draw_line(lp + Vector2(-5, 5) * s, lp + Vector2(5, -5) * s, red, 2.5 * s)
	# landmarks the last worker bothered to note
	for lm in _landmarks:
		if not bool(lm["on_map"]):
			continue
		var mp: Vector2 = (to_px.call(lm["a"]) + to_px.call(lm["b"])) * 0.5
		_ink.draw_string(font, mp + Vector2(-2.0, 10.0) * s, str(LANDMARK_MAP_GLYPH[lm["kind"]]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.25, 0.22, 0.2, 0.9))
	_ink.draw_string(font, r.position + Vector2(margin.x, h - margin.y * 0.35), "it cant see. it hears boots + the clamp. stand still, keep the light on it. - P.", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.2, 0.18, 0.3, 0.8))


# ── play ──────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not _active:
		return
	var key := event as InputEventKey
	if event.is_action_pressed("ui_cancel"):
		return
	if key == null:
		return
	if _caught_t >= 0.0:
		get_viewport().set_input_as_handled()
		return
	if _intro_t >= 0.0 and key.pressed and not key.echo:
		_intro_t = 99.0
		get_viewport().set_input_as_handled()
		return
	if key.physical_keycode == KEY_S or key.physical_keycode == KEY_DOWN:
		glancing = key.pressed and not _moving and not _at_leak
		get_viewport().set_input_as_handled()
		return
	if key.physical_keycode == KEY_TAB:
		_map_open = key.pressed
		_map.visible = _map_open
		_ink.queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if not key.pressed or key.echo or _map_open:
		return
	var used := true
	match key.physical_keycode:
		KEY_W, KEY_UP:
			_try_move(_facing)
		KEY_A, KEY_LEFT:
			_try_move((_facing + 3) % 4)
		KEY_D, KEY_RIGHT:
			_try_move((_facing + 1) % 4)
		KEY_F:
			_flashlight.visible = not _flashlight.visible
		KEY_E:
			if not _moving and _node == _entry:
				close_repair(not _fixed)
				if _fixed:
					repair_completed.emit(_coord, _building_type)
		_:
			used = false
	if used:
		get_viewport().set_input_as_handled()


func _try_move(d: int) -> void:
	if _moving or _at_leak:
		return
	if not _links[_node].has(d):
		return
	var nxt: Vector2i = _node + DIRS[d]
	_facing = d
	_move_from = _world_pos(_node)
	_move_to = _world_pos(nxt)
	_move_target_node = nxt
	_move_t = 0.0
	_moving = true
	glancing = false
	# Boots in the water: it hears every step.
	if _director != null:
		_director.heard(_node, 1)
	_step_player.stream = load(SFX_DIR + "step.mp3") if ResourceLoader.exists(SFX_DIR + "step.mp3") else null
	_step_player.pitch_scale = _rng.randf_range(0.9, 1.1)
	_step_player.play()


func _process(delta: float) -> void:
	if not _active:
		return
	if _caught_t >= 0.0:
		_update_caught(delta)
		return
	if _intro_t >= 0.0:
		_update_intro(delta)
		return
	if _moving:
		var leak_here := not _fixed and _same_edge(_node, _move_target_node, _leak_a, _leak_b)
		var limit := 0.5 if leak_here else 1.0
		_move_t = minf(limit, _move_t + delta / MOVE_SECONDS)
		if leak_here and _move_t >= 0.5:
			_moving = false
			_at_leak = true
			_set_status("The crack is right here, spraying. Hold E to clamp it.")
		elif _move_t >= 1.0:
			_arrive()
	if _at_leak:
		_update_clamp(delta)
	else:
		_work_hand.stop()
	if _director != null:
		_director.tick(delta)
	_update_torch(delta)
	if _fixed and _director != null and not _director.is_real():
		_place_handprints()
	_update_rig(delta)


func _arrive() -> void:
	_moving = false
	_node = _move_target_node
	# No turning around: at a bend the pipe takes you round it.
	if not _links[_node].has(_facing):
		var right := (_facing + 1) % 4
		var left := (_facing + 3) % 4
		if _links[_node].has(right) and not _links[_node].has(left):
			_facing = right
		elif _links[_node].has(left) and not _links[_node].has(right):
			_facing = left
	if _plates.has(_node):
		_set_status("Stencilled on the wall: %s" % _label(_node))
	elif _node == _entry:
		_set_status("The ladder. Press E to climb out%s." % (" - the job is done" if _fixed else ""))
	else:
		_set_status("")


func _update_clamp(delta: float) -> void:
	if Input.is_physical_key_pressed(KEY_E):
		_clamp += delta / CLAMP_SECONDS
		_work_hand.start("Clamping", get_viewport().get_visible_rect().size * Vector2(0.5, 0.55))
		_work_hand.aim(get_viewport().get_visible_rect().size * Vector2(0.5, 0.55))
		if int(_clamp * 8.0) != int((_clamp - delta / CLAMP_SECONDS) * 8.0):
			_clank()
			if _director != null:
				_director.heard(_node, 2)
		_set_status("Clamping... %d%%" % int(clampf(_clamp, 0.0, 1.0) * 100.0))
		if _clamp >= 1.0:
			_fixed = true
			_at_leak = false
			_leak_fx.emitting = false
			_leak_audio.stop()
			_set_status("Clamped. Now find the ladder.")
			_play_one("clamp.mp3", -3.0)
			_work_hand.stop()
			# finish crossing the pipe
			_moving = true
	else:
		_work_hand.stop()
		_clamp = maxf(0.0, _clamp - delta * 0.5)


func _clank() -> void:
	var p := AudioStreamPlayer.new()
	if ResourceLoader.exists(SFX_CLANK):
		p.stream = load(SFX_CLANK)
	p.pitch_scale = randf_range(0.5, 0.65)
	p.volume_db = -4.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _update_rig(delta: float) -> void:
	var pos: Vector3
	if _moving or _at_leak:
		var t := _move_t * _move_t * (3.0 - 2.0 * _move_t)
		pos = _move_from.lerp(_move_to, t)
	else:
		pos = _world_pos(_node)
	_rig.position = pos
	_glance = move_toward(_glance, 1.0 if glancing else 0.0, delta * 4.5)
	var g := _glance * _glance * (3.0 - 2.0 * _glance)
	var target_yaw: float = DIR_YAW[_facing] + PI * 0.94 * g
	_rig.rotation.y = lerp_angle(_rig.rotation.y, target_yaw, minf(1.0, delta * 12.0)) if delta > 0.0 else target_yaw
	_camera.rotation.x = -0.12 * g
	_bob += delta * (8.5 if _moving else 1.8)
	_camera.position = Vector3(0, sin(_bob) * (0.03 if _moving else 0.008), 0)


# ── the thing in the pipes ────────────────────────────────────────────────────

func _next_step_toward(from: Vector2i, to: Vector2i) -> Vector2i:
	var dist := _distances_from(to)
	var best := from
	var best_d := int(dist.get(from, 999))
	for d in _links[from]:
		var n: Vector2i = from + DIRS[d]
		if int(dist.get(n, 999)) < best_d:
			best_d = int(dist[n])
			best = n
	return best


# ── staging: the torch, the intro, being caught ─────────────────────────────

## Your hand holding the torch, bottom right, bobbing in steps with your walk; lowered
## when the torch is off; the beam stutters when the director says something is near.
func _update_torch(delta: float) -> void:
	_flicker_t += delta
	var f: float = _director.flicker if _director != null else 0.0
	var stutter := f > 0.0 and fmod(floorf(_flicker_t * 14.0) * 0.618, 1.0) < f * 0.6
	_flashlight.light_energy = 0.15 if stutter else 3.0
	if _torch_hand == null or _torch_hand.texture == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var k := _torch_hand.size.x / maxf(1.0, _torch_hand.texture.get_width())
	var step := floorf(_bob * 1.6)
	var bob := (absf(sin(step * 0.9)) * 6.0 * k) if _moving else (floorf(sin(_bob * 0.8) * 2.0) * k)
	var lowered := 0.0 if _flashlight.visible else _torch_hand.size.y * 0.55
	var hide := _torch_hand.size.y * (1.0 if _at_leak and Input.is_physical_key_pressed(KEY_E) else 0.0)
	_torch_hand.position = Vector2(vp.x * 0.62, vp.y - _torch_hand.size.y * 0.86 - 14.0 * float(_scale) + bob + lowered + hide).floor()
	_torch_hand.modulate = Color(0.8, 0.78, 0.72) if not _flashlight.visible else Color.WHITE
	_torch_hand.visible = _glance < 0.5


## Down the ladder: the rungs go up past you, the splash at the bottom, then the map you
## were given unfolds for a moment so you know what you have. Any key skips.
func _update_intro(delta: float) -> void:
	_intro_t += delta
	_update_torch(delta)
	var base := _world_pos(_entry)
	var k := clampf(_intro_t / 2.2, 0.0, 1.0)
	_rig.position = base + Vector3(0, lerpf(2.6, 0.0, k * k * (3.0 - 2.0 * k)), 0.35 * (1.0 - k))
	_rig.rotation.y = DIR_YAW[_facing]
	_camera.rotation.x = lerpf(-0.5, 0.0, k)
	var map_on := _intro_t >= 2.3 and _intro_t < 5.6
	if _map.visible != map_on:
		_map.visible = map_on
		_ink.queue_redraw()
	if _intro_t >= 5.6:
		_intro_t = -1.0
		_map.visible = false
		_camera.rotation.x = 0.0
		_set_status("The water runs away from the leak.")
		_update_rig(0.0)


## Called by the director: it has you. The hands out of the dark, the blow, then the dark
## and the long drag back to the ladder.
func caught_by_thing() -> void:
	if _caught_t >= 0.0:
		return
	_caught_t = 0.0
	_caught_hit = false
	glancing = false
	_lunge.visible = _lunge.texture != null
	_lunge.scale = Vector2.ONE * 0.7
	_lunge.pivot_offset = _lunge.size * 0.5
	_play_one("grab.mp3", 2.0)


func _update_caught(delta: float) -> void:
	_caught_t += delta
	if _caught_t < 0.35:
		var k := _caught_t / 0.35
		_lunge.scale = Vector2.ONE * lerpf(0.7, 1.6, k)
		_camera.position = Vector3(randf_range(-0.04, 0.04), randf_range(-0.04, 0.04), 0)
		return
	if not _caught_hit:
		_caught_hit = true
		_lunge.visible = false
		_black.color.a = 1.0
		player_hurt.emit(DIRECTOR.DAMAGE)
		_play_one("drag.mp3", -1.0)
		_moving = false
		_at_leak = false
		if not _fixed:
			_clamp = 0.0
		_work_hand.stop()
	if _caught_t >= 3.4:
		_node = _entry
		_facing = 0
		_update_rig(0.0)
		_black.color.a = maxf(0.0, _black.color.a - delta * 1.5)
		if _black.color.a <= 0.0:
			_caught_t = -1.0
			_set_status("It dragged you back to the ladder by the ankle.%s" % ("" if _fixed else " The clamp slipped off."))


func _play_one(file: String, db: float) -> void:
	if ResourceLoader.exists(SFX_DIR + file):
		_one.stream = load(SFX_DIR + file)
		_one.volume_db = db
		_one.play()
