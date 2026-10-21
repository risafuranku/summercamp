extends Node3D

## The god cursor (DESIGN §5k): what is built in Builder 98 comes down into the camp you
## stand in from a giant computer pointer high in the haze, as if somebody up there were
## putting the camp together with a mouse. The OS's own arrow built in three dimensions
## out of its pixels, a hundred metres of it, hanging a hundred and fifty up in the haze
## with its tip down at the camp, the Builder's tool beside it (the user, 21. 10.: "godly
## v nebesích ... mohutnej cursor, fobie z velkejch věcí"); a deep hum, slowed-down Okna
## clicks and dings, and
## heavy landings: path tiles one after another like dominoes, buildings in their parts
## (the foundations, the walls, the roof), each settling in a puff of dust; a bulldozing
## pressed flat by the pointer's click.
##
## Only theatre: the camp has the building the moment the Builder takes the order (the
## sim, the guests, the books never wait for it). Here the real building is hidden under
## a shadow on the ground until its turn in the queue, then its own meshes come down in
## steps, twelve a second, and stand where they always were. Guests under it jump aside,
## a warden under it is pushed off with the ground shaking; nobody is ever hurt.
##
## Who builds: the warden at the PC (Builder 98 on the screen) and, in co-op, the other
## wardens (main sets `from_peer` around their builds); a camp built any other way (the
## world, a save, the tools) is just there. It builds as the PC orders, one to one (the
## user, 21. 10.): alone at the PC you mostly miss it (a glimpse through the office
## window); the other wardens see it. Each machine plays its own theatre.
##
## Two eyes on one world: Builder's 3D view (scripts/builder/map3d.gd) shows the camp as
## the PC has it, everything else shows the theatre. So the theatre works on copies on its
## own render layer (THEATRE, which the Builder's eye leaves out), and a building still to
## come stays where it is on a layer only the Builder's eye draws (BUILDER_EYE, taken out
## of every other camera), its shadow and lights off till it lands.

const SFX := "res://assets/sfx/god/"
const BUILDER_EYE := 1 << 15
const THEATRE := 1 << 16
const FPS := 12.0
const STEP := 1.0 / FPS
const BUS := "OutdoorAmbience"
## The pointer, a solid (the user, 21. 10.: "level with the ground like a flat aeroplane,
## a little isometric tilt, as you see it from above on the PC; not 2D, with height, not
## pixel-jagged: designed so it fits"): the OS's arrow as clean straight edges (units, x
## right, y down from the tip), pressed out to a slab with bevelled edges (a white face,
## light bevels, a charcoal rim, a slate-blue underside: the PC's outline as the camp sees
## it), the tool on a bevelled badge under its tail. It lies nearly flat, its picture's up
## the way Builder's map looks, its tip TILT down at the work, its tail up in the haze.
const ARROW := [Vector2(0, 0), Vector2(0, 17), Vector2(4.0, 13.4), Vector2(7.0, 20.0), Vector2(9.6, 18.8), Vector2(6.7, 12.4), Vector2(12.0, 12.4)]
const BADGE := [Vector2(9, 13), Vector2(19, 13), Vector2(21, 15), Vector2(21, 25), Vector2(19, 27), Vector2(9, 27), Vector2(7, 25), Vector2(7, 15)]
const UNIT := 4.0
const THICK := 6.4
const BEVEL := 1.5
const TILT := deg_to_rad(22.0)
const FACE_TIP := Color(1.0, 1.0, 1.0)
const FACE_TAIL := Color(0.82, 0.84, 0.88)
const SLOPE := Color(0.7, 0.72, 0.76)
const RIM := Color(0.1, 0.11, 0.14)
const UNDER := Color(0.27, 0.3, 0.4)
const UNDER_TAIL := Color(0.2, 0.22, 0.3)
const SLOPE_UNDER := Color(0.55, 0.6, 0.7)
const PLATE := Color(0.93, 0.9, 0.82)
## Where it rests between jobs, over the middle of the camp, and how fast it goes.
const IDLE_H := 210.0
const SPEED := 40.0
## A part falls this far (more when the warden watches from further off, so it is seen).
const DROP_MIN := 22.0
const DROP_MAX := 36.0
## The pointer's tip this far above where the pieces start falling: just under the cloud
## deck (cloud_layers.gd, from 95 m), the rest of it going up into the clouds.
const TIP_OVER := 30.0
## The shadow waiting on the ground for a building still to come.
const WAIT_SHADOW := 0.3
## What is pressed flat at once at most (a bulldozed wood stays a moment, the rest goes).
const WRECK_MAX := 48
## The landing's dust: the camp's own puff in its eight steps (habits' smoke), browned.
const DUST_FRAMES := "res://assets/textury/habits/smoke2_%d.png"
const DUST_COL := Color(0.74, 0.68, 0.58, 0.9)
const MIST_TEX := "res://assets/textury/world/mist_bank.png"
const TOOL_TEX := {
	"build": "res://assets/textury/builder/cur_blueprint.png",
	"path": "res://assets/textury/builder/tb2_path.png",
	"lamp_post": "res://assets/textury/builder/tb2_lamp.png",
	"wreck": "res://assets/textury/builder/tb2_bulldoze.png",
}
## The Builder's own moving tools when they are in (builder_module.CURSOR_FRAMES, Grok
## bld_cursors: the blade, the spade, the lamp blinking, the blueprint unrolling), so it
## is the PC's pointer over the camp; four frames a second as there. Else TOOL_TEX.
const TOOL_FRAMES := {"build": ["bp", 3], "path": ["path", 3], "lamp_post": ["lamp", 2], "wreck": ["dozer", 3]}
const TOOL_FRAME := "res://assets/textury/builder/cursors/%s_%d.png"
const TOOL_FPS := 4.0
## The OS's own arrow (os_shell.gd ARROW), the pointer's body.
const OS_SHELL := preload("res://scripts/os98/os_shell.gd")
const SMALL := ["bench", "lamp_post", "flower_bed", "gnome", "flagpole", "picnic_table", "hammock", "sewer", "tent_1", "tent_2", "tent_3", "bonfire", "corn_stand", "ping_pong"]

const CURSOR_SHADER := """
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, blend_mix, depth_draw_always, shadows_disabled;
uniform sampler2D tex : source_color, filter_linear;
uniform bool textured = false;
uniform vec4 haze_color : source_color = vec4(0.74, 0.78, 0.82, 1.0);
uniform float haze = 0.3;
uniform float fade = 1.0;
uniform float light = 1.0;
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 c = COLOR.rgb;
	// The badge's top carries the tool (UV below zero: a bevel, a rim, the underside).
	if (textured && UV.x >= 0.0) {
		vec4 t = texture(tex, UV);
		c = mix(c, t.rgb, t.a);
	}
	// Higher up it goes further into the haze (its tail is lost in the sky).
	float up = clamp((wp.y - 70.0) / 120.0, 0.0, 1.0);
	ALBEDO = mix(c * light, haze_color.rgb, clamp(haze + up * 0.35, 0.0, 0.85));
	ALPHA = fade;
}
"""

var main: Node
var grid_manager
## Set by main around a build or demolition that came from another warden's PC.
var from_peer := false
## Shot driver: stage every build, the Builder open or not.
var debug_force := false
## The wisps of mist round the pointer (off: only the pointer's own haze).
var mist_on := true

var _queue: Array = []
var _job: Dictionary = {}
var _acc := 0.0
var _t := 0.0
var _idle_t := 0.0
## The pointer: the root at its tip (where it points), the arrow's blocks, the tool.
var _cursor: Node3D
var _arrow: MeshInstance3D
var _plate: MeshInstance3D
var _mat: ShaderMaterial
var _plate_mat: ShaderMaterial
var _yaw := 0.0
var _yaw_t := 0.0
var _yaw_poll := 0.0
var _tex: Dictionary = {}
var _tool := ""
var _tool_frame := 0
var _frames_in: Dictionary = {}   # tool -> how many frames are in
var _pos := Vector3(0, IDLE_H, 0)
var _vis := 0.0
var _vis_want := 0.0
var _mist: Array = []
var _hum: AudioStreamPlayer3D
var _dust_tex: Texture2D
var _dust_frames: Array = []
var _shadow_mat: StandardMaterial3D
var _dust: Array = []     # {sprite, t, life, v}
var _hidden: Dictionary = {}  # node id -> {node, shadow, layer, veil}
var _mask_t := 0.0
var _push: Dictionary = {}


func setup(main_node: Node, grid) -> void:
	main = main_node
	grid_manager = grid
	name = "GodCursor"
	for i in 8:
		var fp := DUST_FRAMES % i
		if ResourceLoader.exists(fp):
			_dust_frames.append(load(fp))
	_dust_tex = _dust_frames[0] if not _dust_frames.is_empty() else null
	_shadow_mat = StandardMaterial3D.new()
	_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow_mat.albedo_texture = _dust_tex
	_shadow_mat.albedo_color = Color(0, 0, 0, 1)
	_shadow_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	get_tree().node_added.connect(_on_node_added)
	_mask_cameras()
	_build_cursor()
	EventBus.BuildConfirmed.connect(_on_build)
	EventBus.DemolishConfirmed.connect(_on_demolish)


# ── what to stage ────────────────────────────────────────────────────────────

## A build to stage: one from the Builder on this PC (the warden sits at it and Builder
## is the program on its screen: it runs on behind the others, visible in its own tree,
## so that alone is not enough), another warden's, or forced.
func _staged() -> bool:
	if debug_force or from_peer:
		return true
	if main == null or not main.has_method("debug_builder_map") or not _holding():
		return false
	var m = main.debug_builder_map()
	return m != null and (m as Control).is_visible_in_tree()


func _structure_at(at: Vector2i) -> Node3D:
	var tile = grid_manager.get_tile(at) if grid_manager != null else null
	if tile == null or not tile.occupied or tile.occupant == null:
		return null
	var n: Node = tile.occupant
	while n != null and not n.has_meta("grid_origin"):
		n = n.get_parent()
	return n as Node3D


func _on_build(t: String, at: Vector2i, rot: int) -> void:
	if not _staged() or grid_manager == null:
		return
	var node := _structure_at(at)
	if t == "lamp_post" and node != null and str(node.get_meta("building_type", "")) == "path":
		# A lamp on a path: the path's lamp (building_manager keeps it in its meta).
		var l = node.get_meta("lamp_node", null)
		node = l as Node3D if l != null and is_instance_valid(l) else null
	if node == null or _hidden.has(node.get_instance_id()):
		return
	var fp: Vector2i = node.get_meta("grid_footprint", Vector2i.ONE) if t != "lamp_post" else Vector2i.ONE
	var o: Vector2i = node.get_meta("grid_origin", at) if t != "lamp_post" else at
	var center: Vector3 = grid_manager.get_footprint_center(o, fp)
	_hide(node, center, fp)
	if t == "path":
		# Tiles of one drag come in one frame: one line of dominoes.
		var last: Dictionary = _queue.back() if not _queue.is_empty() else {}
		if not last.is_empty() and str(last["kind"]) == "path" and int(last["frame"]) == Engine.get_process_frames():
			(last["tiles"] as Array).append({"node": node, "center": center})
			return
		_queue.append({"kind": "path", "frame": Engine.get_process_frames(), "tiles": [{"node": node, "center": center}], "tool": "path"})
		return
	_queue.append({"kind": "build", "type": t, "node": node, "center": center, "fp": fp, "tool": "lamp_post" if t == "lamp_post" else "build"})


func _on_demolish(rect: Rect2i, _n: int, _fee: int, _refund: int) -> void:
	if not _staged() or grid_manager == null:
		return
	# The nodes are queued for freeing this frame: copies of what they look like stay.
	var a: Vector3 = grid_manager.get_footprint_center(rect.position, Vector2i.ONE) - Vector3(2.0, 0, 2.0)
	var b: Vector3 = grid_manager.get_footprint_center(rect.end - Vector2i.ONE, Vector2i.ONE) + Vector3(2.0, 0, 2.0)
	var mid := (a + b) * 0.5
	var gone: Array = []
	var roots: Array = []
	var bm = main.get("building_manager")
	var sr: Node = bm.get_node_or_null("Structures") if bm != null else null
	if sr != null:
		roots.append_array(sr.get_children())
	roots.append_array(get_tree().get_nodes_in_group("trees"))
	for n in roots:
		if not (n is Node3D) or not (n as Node).is_queued_for_deletion():
			continue
		var p := (n as Node3D).global_position
		if p.x >= a.x - 0.5 and p.x <= b.x + 0.5 and p.z >= a.z - 0.5 and p.z <= b.z + 0.5:
			gone.append(n)
	if gone.is_empty():
		return
	gone.sort_custom(func(x, y): return (x as Node3D).global_position.distance_to(mid) < (y as Node3D).global_position.distance_to(mid))
	var copies: Array = []
	for i in mini(gone.size(), WRECK_MAX):
		var c := _copy_of(gone[i])
		if c != null:
			copies.append(c)
	if copies.is_empty():
		return
	_queue.append({"kind": "wreck", "copies": copies, "center": Vector3(mid.x, 0.0, mid.z), "size": Vector2(b.x - a.x, b.z - a.z), "tool": "wreck"})


## What a node looks like, without its scripts: its meshes and sprites where they stand.
func _copy_of(src: Node3D) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.global_transform = src.global_transform
	var any := false
	for n in src.find_children("*", "", true, false):
		var vis := n as Node3D
		if vis == null or not vis.is_visible_in_tree():
			continue
		var c: Node3D = null
		if n is MeshInstance3D:
			var mi := MeshInstance3D.new()
			mi.mesh = (n as MeshInstance3D).mesh
			mi.material_override = (n as MeshInstance3D).material_override
			for s in (n as MeshInstance3D).get_surface_override_material_count():
				mi.set_surface_override_material(s, (n as MeshInstance3D).get_surface_override_material(s))
			c = mi
		elif n is MultiMeshInstance3D:
			var mm := MultiMeshInstance3D.new()
			mm.multimesh = (n as MultiMeshInstance3D).multimesh
			mm.material_override = (n as MultiMeshInstance3D).material_override
			c = mm
		elif n is Sprite3D:
			c = (n as Sprite3D).duplicate(0) as Node3D
			for ch in c.get_children():
				ch.free()
		if c == null:
			continue
		# A tree's near and far pictures take turns by distance: so must the copy's, or
		# all of them stand at once (the far card hung in the sky like a green cloud).
		var g := n as GeometryInstance3D
		var cg := c as GeometryInstance3D
		cg.visibility_range_begin = g.visibility_range_begin
		cg.visibility_range_end = g.visibility_range_end
		cg.visibility_range_begin_margin = g.visibility_range_begin_margin
		cg.visibility_range_end_margin = g.visibility_range_end_margin
		cg.visibility_range_fade_mode = g.visibility_range_fade_mode
		cg.transparency = g.transparency
		cg.layers = g.layers
		cg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(c)
		c.global_transform = vis.global_transform
		any = true
	if not any:
		root.queue_free()
		return null
	return root


# ── hiding what is still to come ─────────────────────────────────────────────

func _hide(node: Node3D, center: Vector3, fp: Vector2i) -> void:
	var sh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(float(fp.x) * 4.6, float(fp.y) * 4.6)
	sh.mesh = pm
	sh.material_override = _shadow_mat.duplicate()
	(sh.material_override as StandardMaterial3D).albedo_color = Color(0, 0, 0, WAIT_SHADOW)
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sh.set_meta("retro_skip", true)
	add_child(sh)
	sh.global_position = center + Vector3(0, 0.06, 0)
	var layer := -1
	if node is CollisionObject3D:
		# Not a wall you bump into while it is not there.
		layer = (node as CollisionObject3D).collision_layer
		(node as CollisionObject3D).collision_layer = 0
	_hidden[node.get_instance_id()] = {"node": node, "shadow": sh, "layer": layer, "veil": _veil(node)}
	_mask_cameras()


## Shown again; its waiting shadow is handed back (to darken as it falls) or freed.
func _reveal(node: Node3D, keep_shadow := false) -> MeshInstance3D:
	if node == null or not is_instance_valid(node):
		return null
	var h: Dictionary = _hidden.get(node.get_instance_id(), {})
	_hidden.erase(node.get_instance_id())
	if h.is_empty():
		return null
	_unveil(h["veil"])
	if int(h["layer"]) >= 0 and node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = int(h["layer"])
	if not is_instance_valid(h["shadow"]):
		return null
	if keep_shadow:
		return h["shadow"]
	(h["shadow"] as Node).queue_free()
	return null


## Its shadow, the building left waiting (the parts fall as a copy).
func _take_shadow(node: Node3D) -> MeshInstance3D:
	var h: Dictionary = _hidden.get(node.get_instance_id(), {})
	var sh = h.get("shadow")
	if sh != null and is_instance_valid(sh):
		h["shadow"] = null
		return sh
	return null


## A building on the Builder's eye only: its drawn parts there, its shadow and lights off.
func _veil(node: Node3D) -> Array:
	var out: Array = []
	for n in node.find_children("*", "", true, false) + [node]:
		_veil_one(n, out)
	return out


func _veil_one(n: Node, out: Array) -> void:
	if n is Light3D or n is GPUParticles3D or n is CPUParticles3D:
		if (n as Node3D).visible:
			out.append([n, -1, 0])
			(n as Node3D).visible = false
	elif n is VisualInstance3D:
		var gi := n as GeometryInstance3D
		out.append([n, (n as VisualInstance3D).layers, gi.cast_shadow if gi != null else 0])
		(n as VisualInstance3D).layers = BUILDER_EYE
		if gi != null:
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _unveil(veil: Array) -> void:
	for e in veil:
		var n = e[0]
		if not is_instance_valid(n):
			continue
		if int(e[1]) < 0:
			(n as Node3D).visible = true
		else:
			(n as VisualInstance3D).layers = int(e[1])
			if n is GeometryInstance3D:
				(n as GeometryInstance3D).cast_shadow = int(e[2])


## The theatre's own things never in the Builder's eye; what a waiting building grows
## meanwhile (a sign, a lit window) waits with it; every camera but the Builder's eye
## leaves the waiting buildings out.
func _on_node_added(n: Node) -> void:
	if n is Camera3D:
		if not n.has_meta("builder_eye"):
			(n as Camera3D).cull_mask &= ~BUILDER_EYE
		return
	if not (n is VisualInstance3D):
		return
	if is_ancestor_of(n):
		if not (n is Light3D):
			(n as VisualInstance3D).layers = THEATRE
		return
	if _hidden.is_empty():
		return
	var p := n.get_parent()
	for i in 10:
		if p == null:
			return
		var h: Dictionary = _hidden.get(p.get_instance_id(), {})
		if not h.is_empty():
			_veil_one(n, h["veil"])
			return
		p = p.get_parent()


func _mask_cameras() -> void:
	if get_tree() == null:
		return
	for c in get_tree().root.find_children("*", "Camera3D", true, false):
		if not c.has_meta("builder_eye"):
			(c as Camera3D).cull_mask &= ~BUILDER_EYE


## A building taken away (or rebuilt) while it waited: its shadow goes with it.
func _sweep_hidden() -> void:
	for id in _hidden.keys():
		var h: Dictionary = _hidden[id]
		if not is_instance_valid(h["node"]) or (h["node"] as Node).is_queued_for_deletion():
			if is_instance_valid(h["shadow"]):
				(h["shadow"] as Node).queue_free()
			_hidden.erase(id)


## Everything still waiting comes down at once, unseen (leaving the camp, a load).
func finish_all() -> void:
	for id in _hidden.keys():
		_reveal(_hidden[id]["node"])
	_hidden.clear()
	if not _job.is_empty():
		_end_job(_job)
	for j in _queue:
		_end_job(j)
	_queue.clear()
	_job = {}


func busy() -> bool:
	return not _job.is_empty() or not _queue.is_empty()


# ── the pointer ──────────────────────────────────────────────────────────────

func _build_cursor() -> void:
	_cursor = Node3D.new()
	_cursor.visible = false
	add_child(_cursor)
	var sh := Shader.new()
	sh.code = CURSOR_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_arrow = MeshInstance3D.new()
	_arrow.mesh = _slab(ARROW, THICK, FACE_TIP, FACE_TAIL, false)
	_arrow.material_override = _mat
	_arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arrow.extra_cull_margin = 200.0
	_arrow.set_meta("retro_skip", true)
	_cursor.add_child(_arrow)
	# The tool on a badge under the arrow's tail, as on the PC.
	_plate_mat = ShaderMaterial.new()
	_plate_mat.shader = sh
	_plate_mat.set_shader_parameter("textured", true)
	_plate = MeshInstance3D.new()
	_plate.mesh = _slab(BADGE, THICK * 0.6, PLATE, PLATE, true)
	_plate.material_override = _plate_mat
	_plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_plate.extra_cull_margin = 120.0
	_plate.set_meta("retro_skip", true)
	_plate.position = Vector3(0, 0, -THICK * 0.45)
	_cursor.add_child(_plate)
	var mist: Texture2D = load(MIST_TEX) if ResourceLoader.exists(MIST_TEX) else null
	for i in 3:
		# The fog's own colour, not fogged again by the world (it went green and blocky).
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = mist
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.disable_fog = true
		m.albedo_color = Color(0.86, 0.88, 0.9, 0.0)
		var mi := MeshInstance3D.new()
		var q2 := QuadMesh.new()
		q2.size = Vector2(34.0 + 8.0 * float(i % 2), 9.5 + 2.0 * float(i % 2))
		mi.mesh = q2
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("retro_skip", true)
		add_child(mi)
		_mist.append(mi)
	_hum = AudioStreamPlayer3D.new()
	_hum.stream = _load_sfx("hum")
	_hum.bus = BUS
	_hum.unit_size = 70.0
	_hum.max_distance = 900.0
	_hum.volume_db = -60.0
	_hum.attenuation_filter_cutoff_hz = 20500.0
	_cursor.add_child(_hum)
	_hum.position = Vector3(6.0, -11.0, 0.0) * UNIT
	if _hum.stream is AudioStreamMP3:
		(_hum.stream as AudioStreamMP3).loop = true


## A polygon (units, y down) pressed out to a slab `thick` metres through: its faces
## inset by the bevel, sloped bevels to the rim, the rim round it. The top face goes from
## `near` at the polygon's top to `far` at its bottom (the underside slate); `uv` maps the
## top face's outline to 0..1 (the badge's picture), the rest gets -1 (no picture).
func _slab(poly: Array, thick: float, near: Color, far: Color, uv: bool) -> ArrayMesh:
	var outer: Array = []
	for v in poly:
		outer.append(Vector2(v.x, -v.y) * UNIT)
	var n := outer.size()
	var area := 0.0
	for k in n:
		area += (outer[k] as Vector2).cross(outer[(k + 1) % n])
	var turn := 1.0 if area > 0.0 else -1.0
	# The faces' outline: each corner moved in along its bisector, mitred.
	var bevel := BEVEL * thick / THICK
	var inner: Array = []
	for k in n:
		var a: Vector2 = outer[(k - 1 + n) % n]
		var b: Vector2 = outer[k]
		var c: Vector2 = outer[(k + 1) % n]
		var n1 := (b - a).normalized().orthogonal() * -turn
		var n2 := (c - b).normalized().orthogonal() * -turn
		var m := (n1 + n2).normalized()
		inner.append(b + m * bevel / maxf(0.35, m.dot(n1)))
	var lo := 1e9
	var hi := -1e9
	var box := Rect2(outer[0], Vector2.ZERO)
	for v in outer:
		lo = minf(lo, v.y)
		hi = maxf(hi, v.y)
		box = box.expand(v)
	var h := thick * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := Geometry2D.triangulate_polygon(PackedVector2Array(inner))
	for z in [h, -h]:
		for t in tris:
			var p: Vector2 = inner[t]
			var k := (p.y - lo) / maxf(0.01, hi - lo)
			st.set_color(far.lerp(near, k) if z > 0.0 else UNDER_TAIL.lerp(UNDER, k))
			st.set_uv(Vector2((p.x - box.position.x) / box.size.x, (box.end.y - p.y) / box.size.y) if uv and z > 0.0 else Vector2(-1, -1))
			st.add_vertex(Vector3(p.x, p.y, z))
	for k in n:
		var o0: Vector2 = outer[k]
		var o1: Vector2 = outer[(k + 1) % n]
		var i0: Vector2 = inner[k]
		var i1: Vector2 = inner[(k + 1) % n]
		var e := h - bevel * 0.8
		for side in [1.0, -1.0]:
			_quad(st, Vector3(i0.x, i0.y, h * side), Vector3(i1.x, i1.y, h * side), Vector3(o1.x, o1.y, e * side), Vector3(o0.x, o0.y, e * side), SLOPE if side > 0.0 else SLOPE_UNDER)
		_quad(st, Vector3(o0.x, o0.y, e), Vector3(o1.x, o1.y, e), Vector3(o1.x, o1.y, -e), Vector3(o0.x, o0.y, -e), RIM)
	return st.commit()


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	for v in [a, b, c, a, c, d]:
		st.set_color(col)
		st.set_uv(Vector2(-1, -1))
		st.add_vertex(v)


## The tool's picture (the Builder's frame, or its icon).
func _cursor_tex(tool: String, frame := 0) -> Texture2D:
	var key := "%s|%d" % [tool, frame]
	if _tex.has(key):
		return _tex[key]
	var path := str(TOOL_TEX.get(tool, ""))
	if _tool_frames(tool) > 0:
		path = TOOL_FRAME % [str(TOOL_FRAMES[tool][0]), frame]
	var tex: Texture2D = load(path) if path != "" and ResourceLoader.exists(path) else null
	_tex[key] = tex
	return tex


## How many of the Builder's frames a tool has in (0: the still icon).
func _tool_frames(tool: String) -> int:
	if not TOOL_FRAMES.has(tool):
		return 0
	if not _frames_in.has(tool):
		var n := int(TOOL_FRAMES[tool][1])
		for i in n:
			if not ResourceLoader.exists(TOOL_FRAME % [str(TOOL_FRAMES[tool][0]), i]):
				n = 0
				break
		_frames_in[tool] = n
	return int(_frames_in[tool])


func _set_tool(tool: String) -> void:
	if tool == _tool:
		return
	_tool = tool
	_tool_frame = 0
	_plate_mat.set_shader_parameter("tex", _cursor_tex(tool))
	_plate.visible = _cursor_tex(tool) != null


## The tool's frame by the clock (in the stepped tick, so it moves in steps with the rest).
func _tick_tool() -> void:
	var n := _tool_frames(_tool)
	if n <= 1:
		return
	var f := int(_t * TOOL_FPS) % n
	if f != _tool_frame:
		_tool_frame = f
		_plate_mat.set_shader_parameter("tex", _cursor_tex(_tool, f))


## How far off the warden watches from: the pieces fall from higher the further off, so
## they come down where the eye is.
func _drop_h(at: Vector3) -> float:
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	var d := cam.global_position.distance_to(at) if cam != null else 40.0
	return clampf(d * 0.42, DROP_MIN, DROP_MAX)


func _camera_pos() -> Vector3:
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	return cam.global_position if cam != null else Vector3.ZERO


## The pointer over `at`, its tip a few metres above where the pieces start.
func _work_spot(at: Vector3) -> Vector3:
	return at + Vector3(0, _drop_h(at) + TIP_OVER, 0)


func _holding() -> bool:
	if main == null:
		return false
	var im = main.get("_interior_manager")
	var bi = im.get("_building_interior") if im != null else null
	return bi != null and bi.has_method("is_crt_view_active") and bool(bi.is_crt_view_active())


# ── the clock ────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_t += delta
	_acc += delta
	var n := 0
	while _acc >= STEP and n < 4:
		_acc -= STEP
		n += 1
		_step()
	_tick_look(delta)


func _speed() -> float:
	return clampf(1.0 + 0.12 * float(_queue.size()), 1.0, 3.0)


func _step() -> void:
	_tick_dust()
	_tick_tool()
	_tick_push()
	_sweep_hidden()
	if not _hidden.is_empty():
		_mask_t -= STEP
		if _mask_t <= 0.0:
			_mask_t = 2.0
			_mask_cameras()
	if _job.is_empty():
		if not _queue.is_empty():
			_job = _queue.pop_front()
			_job["phase"] = "go"
			_job["t"] = 0.0
			_job["from"] = _pos
			_set_tool(str(_job.get("tool", "build")))
			_vis_want = 1.0
			_idle_t = 0.0
		else:
			_idle_t += STEP
			if _idle_t > 2.5:
				_vis_want = 0.0
			# Rising back into the haze, slowly.
			_pos = _pos.move_toward(Vector3(_pos.x, IDLE_H, _pos.z), STEP * 6.0)
			return
	var j := _job
	j["t"] = float(j["t"]) + STEP * _speed()
	match str(j["kind"]):
		"build":
			_step_build(j)
		"path":
			_step_path(j)
		"wreck":
			_step_wreck(j)


## Over to the job: a long slow glide in steps.
func _glide(j: Dictionary, to: Vector3) -> bool:
	var from: Vector3 = j["from"]
	var dur := clampf(from.distance_to(to) / SPEED, 0.8, 2.2)
	var k := clampf(float(j["t"]) / dur, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	_pos = from.lerp(to, k)
	return float(j["t"]) >= dur


func _next(j: Dictionary, phase: String) -> void:
	j["phase"] = phase
	j["t"] = 0.0


func _step_build(j: Dictionary) -> void:
	# (Checked before the typed assignment: a freed node there is a script error.)
	if not is_instance_valid(j["node"]):
		_end_job(j)
		return
	var node: Node3D = j["node"]
	var c: Vector3 = j["center"]
	match str(j["phase"]):
		"go":
			if _glide(j, _work_spot(c)):
				_next(j, "click")
				_play("click", c, 0.0)
		"click":
			# The click: the pointer jabs down and back.
			var k := float(j["t"])
			_pos = _work_spot(c) - Vector3(0, 9.0 if k < 0.25 else 0.0, 0)
			if k >= 0.45:
				_play("ding", c, -4.0)
				_begin_parts(j)
				_next(j, "fall")
		"fall":
			if _step_parts(j):
				_next(j, "settle")
		"settle":
			if float(j["t"]) >= 0.4:
				_end_job(j)


## The building's meshes in their parts (by height: the foundations, the walls, the roof;
## small things in one piece), each lifted to fall in its turn.
func _begin_parts(j: Dictionary) -> void:
	var node: Node3D = j["node"]
	var c: Vector3 = j["center"]
	var shadow := _take_shadow(node)
	if shadow == null:
		shadow = _make_shadow(c, j["fp"])
	j["shadow"] = shadow
	# The theatre's copy falls; the building waits on the Builder's eye till it lands.
	var copy := _copy_of(node)
	j["copy"] = copy
	var vis: Array = []
	if copy != null:
		for n in copy.find_children("*", "", true, false):
			if n is VisualInstance3D:
				vis.append(n)
	var top := 0.4
	var info: Array = []
	for v in vis:
		var y := _height_of(v, c.y)
		top = maxf(top, y.y)
		info.append([v, y])
	var parts: Array = [[], [], []]
	var one := SMALL.has(str(j.get("type", ""))) or top < 2.2
	for e in info:
		var mid: float = (e[1] as Vector2).x
		var p := 0 if one else (0 if (e[1] as Vector2).y < top * 0.18 or mid < top * 0.12 else (2 if mid > top * 0.62 else 1))
		parts[p].append(e[0])
	var h := _drop_h(c)
	var list: Array = []
	for i in 3:
		if (parts[i] as Array).is_empty():
			continue
		var nodes: Array = parts[i]
		nodes.sort_custom(func(a, b): return (a as Node).get_path().get_name_count() < (b as Node).get_path().get_name_count())
		var orig: Array = []
		for n in nodes:
			orig.append((n as Node3D).global_transform)
		list.append({"nodes": nodes, "orig": orig, "h": h + float(i) * 4.0, "t": -0.12 * float(list.size()), "landed": false, "sound": ["thud_a", "thud_b", "thud_c"][i]})
	j["parts"] = list
	for p in list:
		_lift(p, float(p["h"]))


## Where a node's drawn part is, up from the ground: (middle, top) in metres.
func _height_of(n: Node, ground: float) -> Vector2:
	if n is VisualInstance3D:
		var ab: AABB = (n as VisualInstance3D).global_transform * (n as VisualInstance3D).get_aabb()
		return Vector2(ab.get_center().y - ground, ab.end.y - ground)
	var y := (n as Node3D).global_position.y - ground
	return Vector2(y, y)


func _lift(p: Dictionary, h: float) -> void:
	var nodes: Array = p["nodes"]
	var orig: Array = p["orig"]
	for i in nodes.size():
		if is_instance_valid(nodes[i]):
			var tr: Transform3D = orig[i]
			tr.origin.y += h
			(nodes[i] as Node3D).global_transform = tr


## One step of every part falling (quick, heavy, in steps); true when all are down.
func _step_parts(j: Dictionary) -> bool:
	var all := true
	for p in j["parts"]:
		if bool(p["landed"]):
			continue
		all = false
		p["t"] = float(p["t"]) + STEP * _speed()
		var dur := 0.62
		var k := clampf(float(p["t"]) / dur, 0.0, 1.0)
		var shadow: MeshInstance3D = j.get("shadow")
		if shadow != null and is_instance_valid(shadow):
			var m := shadow.material_override as StandardMaterial3D
			m.albedo_color.a = lerpf(WAIT_SHADOW, 0.62, k)
			shadow.scale = Vector3.ONE * lerpf(0.75, 1.1, k)
		if float(p["t"]) < 0.0:
			break
		_lift(p, float(p["h"]) * (1.0 - k * k))
		if k >= 1.0:
			p["landed"] = true
			_land(j, str(p["sound"]))
		# The next part starts when this one is most of the way down.
		if k < 0.7:
			break
	return all


func _land(j: Dictionary, sound: String) -> void:
	var c: Vector3 = j["center"]
	var fp: Vector2i = j.get("fp", Vector2i.ONE)
	var r := maxf(float(fp.x), float(fp.y)) * 2.2
	_play(sound, c, 0.0 if not SMALL.has(str(j.get("type", ""))) else -6.0)
	for i in 10:
		var a := TAU * float(i) / 10.0 + randf() * 0.4
		_puff(c + Vector3(cos(a) * r, 0.4, sin(a) * r), Vector3(cos(a), 0.5, sin(a)) * 2.2, 2.6 + r * 0.6)
	_shake(c, r)


func _make_shadow(c: Vector3, fp: Vector2i) -> MeshInstance3D:
	var sh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(float(fp.x) * 4.6, float(fp.y) * 4.6)
	sh.mesh = pm
	sh.material_override = _shadow_mat.duplicate()
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sh.set_meta("retro_skip", true)
	add_child(sh)
	sh.global_position = c + Vector3(0, 0.06, 0)
	return sh


func _end_job(j: Dictionary) -> void:
	match str(j.get("kind", "")):
		"build":
			var cp = j.get("copy")
			if cp != null and is_instance_valid(cp):
				(cp as Node).queue_free()
			if is_instance_valid(j.get("node")):
				_reveal(j["node"])
			var sh = j.get("shadow")
			if sh != null and is_instance_valid(sh):
				(sh as Node).queue_free()
		"path":
			for tile in j["tiles"]:
				var cp = tile.get("copy")
				if cp != null and is_instance_valid(cp):
					(cp as Node).queue_free()
				var n = tile["node"]
				if is_instance_valid(n):
					_reveal(n)
		"wreck":
			for c in j["copies"]:
				if is_instance_valid(c):
					(c as Node).queue_free()
	if j == _job:
		_job = {}
		_idle_t = 0.0


# ── paths: dominoes ──────────────────────────────────────────────────────────

func _step_path(j: Dictionary) -> void:
	var tiles: Array = j["tiles"]
	var first: Vector3 = tiles[0]["center"]
	match str(j["phase"]):
		"go":
			if _glide(j, _work_spot(first)):
				_next(j, "click")
				_play("click", first, -2.0)
		"click":
			if float(j["t"]) >= 0.35:
				j["h"] = _drop_h(first)
				for tile in tiles:
					var n = tile["node"]
					if is_instance_valid(n):
						# The tile's copy falls; the tile waits on the Builder's eye.
						var cp := _copy_of(n)
						if cp == null:
							continue
						tile["copy"] = cp
						tile["orig"] = cp.global_transform
						tile["shadow"] = _take_shadow(n)
						if tile["shadow"] == null:
							tile["shadow"] = _make_shadow(tile["center"], Vector2i.ONE)
						var tr: Transform3D = tile["orig"]
						tr.origin.y += float(j["h"])
						cp.global_transform = tr
				_next(j, "fall")
		"fall":
			# One after another down the line, the pointer drawing it along over them.
			var every := 0.2
			var dur := 0.45
			var t := float(j["t"])
			var lead := clampi(int(t / every), 0, tiles.size() - 1)
			_pos = _pos.lerp(_work_spot(tiles[lead]["center"]), 0.5)
			var done := true
			for i in tiles.size():
				var tile: Dictionary = tiles[i]
				var n = tile.get("copy")
				if n == null or not is_instance_valid(n) or not tile.has("orig"):
					continue
				var k := clampf((t - every * float(i)) / dur, 0.0, 1.0)
				var tr: Transform3D = tile["orig"]
				tr.origin.y += float(j["h"]) * (1.0 - k * k)
				n.global_transform = tr
				if k >= 1.0 and is_instance_valid(tile["node"]):
					# Down: the tile itself, the copy gone.
					(n as Node).queue_free()
					tile.erase("copy")
					_reveal(tile["node"])
				var sh = tile.get("shadow")
				if sh != null and is_instance_valid(sh):
					((sh as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a = lerpf(WAIT_SHADOW, 0.6, k)
				if k >= 1.0 and not bool(tile.get("landed", false)):
					tile["landed"] = true
					if sh != null and is_instance_valid(sh):
						(sh as Node).queue_free()
					# A thud each, louder every third (a line of thirty is not thirty booms).
					_play("thud_c", tile["center"], -3.0 if i % 3 == 0 else -11.0)
					for q in 3:
						var a := randf() * TAU
						_puff(tile["center"] + Vector3(cos(a) * 1.8, 0.2, sin(a) * 1.8), Vector3(cos(a), 0.3, sin(a)), 1.4)
					if i % 3 == 0:
						_shake(tile["center"], 2.6)
				if k < 1.0:
					done = false
			if done:
				_next(j, "settle")
		"settle":
			if float(j["t"]) >= 0.3:
				_end_job(j)


# ── bulldozing: pressed flat ─────────────────────────────────────────────────

func _step_wreck(j: Dictionary) -> void:
	var c: Vector3 = j["center"]
	var copies: Array = j["copies"]
	match str(j["phase"]):
		"go":
			if _glide(j, _work_spot(c)):
				_next(j, "dive")
		"dive":
			# Down at it, fast, the bulldozer on the pointer.
			var k := clampf(float(j["t"]) / 0.33, 0.0, 1.0)
			_pos = _work_spot(c).lerp(c + Vector3(0, 7.0, 0), k * k)
			if k >= 1.0:
				_play("click", c, 0.0)
				_play("dozer", c, 0.0)
				var r := maxf(j["size"].x, j["size"].y) * 0.5
				for i in 10:
					var a := TAU * float(i) / 10.0
					_puff(c + Vector3(cos(a) * r * 0.6, 0.4, sin(a) * r * 0.6), Vector3(cos(a), 0.6, sin(a)) * 2.4, 2.2)
				_shake(c, r)
				_next(j, "squash")
		"squash":
			# Flat in four steps, then down into the ground.
			var t := float(j["t"])
			var sy := maxf(0.06, 1.0 - floorf(t * FPS) / 4.0) if t < 0.34 else 0.06
			for cp in copies:
				if is_instance_valid(cp):
					var n := cp as Node3D
					n.scale = Vector3(1.0 + (1.0 - sy) * 0.25, sy, 1.0 + (1.0 - sy) * 0.25)
					if t > 0.6:
						n.position.y -= 0.18
			_pos = _pos.move_toward(_work_spot(c), STEP * 14.0)
			if t >= 1.2:
				_end_job(j)


# ── the look and the sound ───────────────────────────────────────────────────

func _tick_look(delta: float) -> void:
	_vis = move_toward(_vis, _vis_want, delta * (0.7 if _vis_want > _vis else 0.35))
	_cursor.visible = _vis > 0.02
	if not _cursor.visible:
		for m in _mist:
			(m as Node3D).visible = false
		if _hum.playing:
			_hum.stop()
		return
	# Its place in steps (as all machinery); flat, turned the way Builder's map looks, the
	# tip a little down at the work.
	_yaw_poll -= delta
	if _yaw_poll <= 0.0:
		_yaw_poll = 0.5
		_yaw_t = _map_yaw()
	_yaw = lerp_angle(_yaw, _yaw_t, clampf(delta * 3.0, 0.0, 1.0))
	var fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var side := Vector3(cos(_yaw), 0.0, -sin(_yaw))
	_cursor.global_transform = Transform3D(Basis(side, -TILT) * Basis(side, fwd, Vector3.UP), (_pos * 2.0).round() * 0.5)
	# The haze by the camp's own fog; lit by the sky's hour (dark at night, a shape on the
	# stars).
	var env := _environment()
	var dist := _camera_pos().distance_to(_pos)
	var density := env.fog_density if env != null and env.fog_enabled else 0.004
	var haze := clampf(0.08 + 1.0 - exp(-density * dist * 0.2), 0.08, 0.45)
	_mat.set_shader_parameter("haze", haze)
	_plate_mat.set_shader_parameter("haze", haze)
	if env != null:
		_mat.set_shader_parameter("haze_color", env.fog_light_color)
		_plate_mat.set_shader_parameter("haze_color", env.fog_light_color)
		var amb := env.ambient_light_color
		var lit := clampf((amb.r + amb.g + amb.b) / 3.0 * 2.2, 0.25, 1.0)
		_mat.set_shader_parameter("light", lit)
		_plate_mat.set_shader_parameter("light", lit)
	# Solid while it is there (the clouds showed through it); it fades only coming and going.
	var fade := clampf(_vis, 0.0, 1.0)
	_mat.set_shader_parameter("fade", fade)
	_plate_mat.set_shader_parameter("fade", fade)
	# Banks of mist across its body (the body hangs right and down from the tip, as the
	# eye sees it), drifting a little, in steps.
	var cam := get_viewport().get_camera_3d()
	var right := cam.global_transform.basis.x if cam != null else Vector3.RIGHT
	var up := cam.global_transform.basis.y if cam != null else Vector3.UP
	var toward := (cam.global_position - _pos).normalized() if cam != null else Vector3.BACK
	# The arrow's middle (in its pixels from the tip, turned as the pointer is).
	var body := _cursor.global_transform * (Vector3(6.0, -11.0, 0.0) * UNIT)
	var drift := floorf(_t * 4.0) / 4.0
	# A pale grey-blue haze (the fog's light colour went green on the mist's picture).
	var mist_col := Color(0.84, 0.86, 0.9).lerp(env.fog_light_color if env != null else Color(0.84, 0.86, 0.9), 0.25)
	for i in _mist.size():
		var mi := _mist[i] as MeshInstance3D
		mi.visible = mist_on
		var f := float(i)
		var off := right * (sin(drift * 0.11 + f * 2.1) * 8.0 + (f - 1.0) * 5.0) + up * ((f - 1.0) * 10.0 + cos(drift * 0.15 + f) * 2.0)
		mi.global_position = body + off + toward * (3.0 if i % 2 == 0 else -3.0)
		var mm := mi.material_override as StandardMaterial3D
		# Thin wisps on a clear day only: in the fog the camp's own fog does it (the
		# picture went blue against the grey).
		mm.albedo_color = Color(mist_col.r, mist_col.g, mist_col.b, (0.24 if i % 2 == 0 else 0.16) * _vis * clampf(1.0 - density * 40.0, 0.0, 1.0))
	if not _hum.playing and _hum.stream != null:
		_hum.play(randf() * 4.0)
	_hum.volume_db = lerpf(-40.0, -4.0, _vis)


## Which way Builder's map looks (its 3D view's camera, or the quarter the 2D map is
## turned); with no Builder open, the way the warden looks.
func _map_yaw() -> float:
	var m = main.debug_builder_map() if main != null and main.has_method("debug_builder_map") else null
	if m != null:
		var v = m.get("map3d")
		if v != null and bool(v.on):
			return float(v.get("_yaw"))
		return deg_to_rad(45.0 - 90.0 * float(m.get("view_rot")))
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	if cam == null:
		return _yaw_t
	var f := -cam.global_transform.basis.z
	return atan2(-f.x, -f.z)


func _environment() -> Environment:
	var w := get_world_3d()
	if w != null and w.environment != null:
		return w.environment
	var we = main.find_child("WorldEnvironment", true, false) if main != null else null
	return we.environment if we != null else null


func _load_sfx(id: String) -> AudioStream:
	var path := SFX + id + ".mp3"
	return load(path) if ResourceLoader.exists(path) else null


func _play(id: String, at: Vector3, db: float) -> void:
	var s := _load_sfx(id)
	if s == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.bus = BUS
	p.unit_size = 40.0
	p.max_distance = 700.0
	p.volume_db = db
	p.pitch_scale = randf_range(0.92, 1.04)
	add_child(p)
	p.global_position = at + Vector3(0, 4.0, 0)
	p.play()
	p.finished.connect(p.queue_free)


## Dust in steps: a puff that swells, rises a little and thins out.
func _puff(at: Vector3, v: Vector3, size: float) -> void:
	if _dust_tex == null:
		return
	var sp := Sprite3D.new()
	sp.texture = _dust_tex
	sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sp.transparent = true
	sp.shaded = false
	sp.pixel_size = size / 40.0
	sp.modulate = DUST_COL
	sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sp.set_meta("retro_skip", true)
	add_child(sp)
	sp.global_position = at
	_dust.append({"sprite": sp, "t": 0.0, "life": randf_range(0.9, 1.4), "v": v, "size": size})


func _tick_dust() -> void:
	for i in range(_dust.size() - 1, -1, -1):
		var d: Dictionary = _dust[i]
		var sp := d["sprite"] as Sprite3D
		d["t"] = float(d["t"]) + STEP
		var k := float(d["t"]) / float(d["life"])
		if k >= 1.0 or not is_instance_valid(sp):
			if is_instance_valid(sp):
				sp.queue_free()
			_dust.remove_at(i)
			continue
		sp.global_position += (d["v"] as Vector3) * STEP * (1.0 - k)
		if not _dust_frames.is_empty():
			sp.texture = _dust_frames[mini(_dust_frames.size() - 1, int(k * _dust_frames.size()))]
		sp.pixel_size = float(d["size"]) * (1.0 + k * 0.7) / 40.0
		sp.modulate.a = DUST_COL.a * (1.0 - k * k)


## The ground shakes under the warden near a landing; one standing under it is pushed
## out from under it (never hurt), and the guests round it jump aside.
func _shake(at: Vector3, r: float) -> void:
	var ga = main.get("_guest_agents") if main != null else null
	if ga != null and ga.has_method("dodge"):
		ga.dodge(at, r + 3.0, 4.0)
	var pl = main.get("_player") if main != null else null
	if pl == null or not is_instance_valid(pl) or not (pl as Node3D).is_visible_in_tree():
		return
	var to: Vector3 = (pl as Node3D).global_position - at
	to.y = 0.0
	var d := to.length()
	if pl.has_method("ground_shake"):
		pl.ground_shake(clampf(0.06 * (1.0 - d / 60.0), 0.0, 0.06))
	if d < r + 1.2 and pl is CharacterBody3D:
		var away := to.normalized() if d > 0.1 else Vector3.RIGHT
		_push = {"body": pl, "v": away * (r + 1.8 - d) / 6.0, "n": 6}


## The warden being pushed off (a sixth a step, against what is in the way).
func _tick_push() -> void:
	if _push.is_empty():
		return
	var pl = _push["body"]
	if is_instance_valid(pl):
		(pl as CharacterBody3D).move_and_collide(_push["v"])
	_push["n"] = int(_push["n"]) - 1
	if int(_push["n"]) <= 0:
		_push = {}
