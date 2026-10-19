extends Node

## The PS1/Build look on every surface in the game's 3D (playtest 17. 10.: "wobbly vertex
## edges, textures stretching with the view, sprites lit properly by the lamps, the torch
## on the corn, real mood"):
##   - vertices snap to a coarse grid on the screen, so edges shiver as the view moves
##     (not the ground and what lies flat on it: the ground box, the grass overlay 3 cm
##     over it, paths and verges are a few huge triangles each, and snapped apart they
##     cut through each other and flickered; nor the tiny grass tufts, which blinked
##     from one grid cell to the next: playtest 18. 10.);
##   - textures are mapped affine (as the PlayStation did), so they swim and stretch with
##     the angle you see them at (less on big surfaces, none on the ground);
##   - sprites, cut-outs and the corn are lit by every lamp and the torch whichever way
##     they face (no N.L: Build lit its sprites by the sector), so a lamp behind a guest
##     or a torch on the corn lights them; solid things keep their Lambert.
##
## It does not touch the game's materials: every StandardMaterial3D on a mesh or sprite
## stays the node's (the code that changes a lamp's glow or swaps a window's material
## goes on working on it); the renderer is handed a ShaderMaterial made from it instead
## (RenderingServer instance overrides), and what changes on the original is copied over
## (a rolling check, every frame for whatever changed lately).
##
## Started by RetroRender.register(), one per game (root/RetroMaterials).

const SNAP_LINES := 150.0
const AFFINE := 0.6
const CHECK_PER_FRAME := 400
const HOT_SECONDS := 4.0
## Size buckets (how much a surface may swim and shiver): 0 small, 1 medium, 2 big (the
## ground, the lake), 3 lying flat on the ground or a tiny tuft: neither swims nor snaps,
## 4 inside a room (a viewport with its own world): neither either. A room is all near
## surfaces in layers a centimetre apart (rugs, skirting, posters, bedding): snapped they
## cut into each other and the walls' big triangles tore along the diagonal (playtest
## 18. 10.: "terrible clipping of the textures, mostly in interiors").
const B_FLAT := 3
const B_ROOM := 4
const AFFINE_BY_BUCKET := [AFFINE, AFFINE * 0.3, 0.0, 0.0, 0.0]
const AFFINE_TRIPLANAR := [AFFINE * 0.7, AFFINE * 0.2, 0.0, 0.0, 0.0]

var enabled := true
var _shaders: Dictionary = {}       # variant key -> Shader
var _conv: Dictionary = {}          # "std id|size bucket" -> {std, mat, sig, hot, big}
var _by_std: Dictionary = {}        # std id -> [conv records]
var _hot: Array = []                # conv records being watched every frame
var _nodes: Array = []              # {node (weakref), std: [per slot], kind}
var _queue: Array = []
var _cursor := 0
var _sprites: Array = []            # {node wr, mat, tex}
var _multis: Array = []             # {node wr, over}


static func ensure(tree: SceneTree) -> void:
	if tree == null or tree.root == null:
		return
	if tree.root.get_node_or_null("RetroMaterials") != null:
		return
	var n = load("res://scripts/retro_materials.gd").new()
	n.name = "RetroMaterials"
	tree.root.add_child.call_deferred(n)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	# What is already there.
	for n in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		_on_node_added(n)


## Meta "retro_skip": left as it is (the lightning far off past the fog keeps its own
## fog-free material).
func _on_node_added(n: Node) -> void:
	if n.has_meta("retro_skip"):
		return
	if n is MeshInstance3D or n is Sprite3D or n is MultiMeshInstance3D:
		_queue.append(weakref(n))


func _process(delta: float) -> void:
	if not enabled:
		return
	# New nodes, once they are in their world.
	var q := _queue
	_queue = []
	for wr in q:
		var n = wr.get_ref()
		if n != null and is_instance_valid(n) and (n as Node).is_inside_tree():
			_track(n)
	# The rolling check: material swaps on the nodes, changes on the originals.
	var count := mini(CHECK_PER_FRAME, _nodes.size())
	for i in count:
		if _nodes.is_empty():
			break
		_cursor = (_cursor + 1) % _nodes.size()
		_check_node(_cursor)
	var still: Array = []
	for c in _hot:
		c["hot"] = float(c["hot"]) - delta
		_sync(c)
		if float(c["hot"]) > 0.0:
			still.append(c)
	_hot = still
	# Multimeshes: their material swapped, their tint changed (the corn drying).
	for mr in _multis:
		var mmi = mr["node"].get_ref()
		if mmi == null or not is_instance_valid(mmi):
			continue
		var cur = (mmi as MultiMeshInstance3D).material_override
		if cur != mr["over"]:
			mr["over"] = cur
			var cm := _converted(cur, int(mr.get("big", 1)))
			RenderingServer.instance_geometry_set_material_override(mmi.get_instance(), cm.get_rid() if cm != null else (cur.get_rid() if cur != null else RID()))
		elif cur is StandardMaterial3D:
			for c in _by_std.get((cur as Object).get_instance_id(), []):
				_sync(c)
	# Sprites change pictures every few frames (birds, leaves, hens).
	var keep: Array = []
	for sp in _sprites:
		var s = sp["node"].get_ref()
		if s == null or not is_instance_valid(s):
			continue
		keep.append(sp)
		var t: Texture2D = (s as Sprite3D).texture
		if t != sp["tex"]:
			sp["tex"] = t
			(sp["mat"] as ShaderMaterial).set_shader_parameter("albedo_tex", t)
			(sp["mat"] as ShaderMaterial).set_shader_parameter("has_tex", t != null)
	_sprites = keep


# ── nodes ────────────────────────────────────────────────────────────────────

func _track(n: Node) -> void:
	if n is Sprite3D:
		_track_sprite(n as Sprite3D)
		return
	if n is MultiMeshInstance3D:
		_track_multi(n as MultiMeshInstance3D)
		return
	var mi := n as MeshInstance3D
	if mi == null or mi.mesh == null:
		return
	var rec := {"node": weakref(mi), "over": null, "slots": []}
	_nodes.append(rec)
	_apply_mesh(mi, rec)


## The corn, the forest walls: one material over the lot.
func _track_multi(mmi: MultiMeshInstance3D) -> void:
	var rid := mmi.get_instance()
	var over := mmi.material_override
	if not rid.is_valid() or over == null:
		return
	var big := _multi_bucket(mmi)
	var m := _converted(over, big)
	if m != null:
		RenderingServer.instance_geometry_set_material_override(rid, m.get_rid())
		_multis.append({"node": weakref(mmi), "over": over, "big": big})


## Grass tufts and the like (each piece under a metre) do not snap; the corn and the
## forest walls do.
func _multi_bucket(mmi: MultiMeshInstance3D) -> int:
	if _in_room(mmi):
		return B_ROOM
	var mm := mmi.multimesh
	if mm != null and mm.mesh != null:
		var a := mm.mesh.get_aabb()
		if maxf(a.size.x, maxf(a.size.y, a.size.z)) < 0.8:
			return B_FLAT
	return 1


func _apply_mesh(mi: MeshInstance3D, rec: Dictionary) -> void:
	var rid := mi.get_instance()
	if not rid.is_valid():
		return
	var big := _bucket(mi)
	var over := mi.material_override
	rec["over"] = over
	if over != null:
		var m := _converted(over, big)
		RenderingServer.instance_geometry_set_material_override(rid, m.get_rid() if m != null else (over as Material).get_rid())
		return
	RenderingServer.instance_geometry_set_material_override(rid, RID())
	var slots: Array = []
	for i in mi.mesh.get_surface_count():
		var src: Material = mi.get_surface_override_material(i)
		if src == null:
			src = mi.mesh.surface_get_material(i)
		slots.append(src)
		var m := _converted(src, big)
		if m != null:
			RenderingServer.instance_set_surface_override_material(rid, i, m.get_rid())
		elif src != null:
			RenderingServer.instance_set_surface_override_material(rid, i, src.get_rid())
	rec["slots"] = slots


func _check_node(i: int) -> void:
	var rec: Dictionary = _nodes[i]
	var mi = rec["node"].get_ref()
	if mi == null or not is_instance_valid(mi):
		_nodes.remove_at(i)
		return
	var changed: bool = (mi as MeshInstance3D).material_override != rec["over"]
	if not changed and rec["over"] == null and mi.mesh != null:
		var slots: Array = rec["slots"]
		if slots.size() != mi.mesh.get_surface_count():
			changed = true
		else:
			for s in slots.size():
				var cur: Material = mi.get_surface_override_material(s)
				if cur == null:
					cur = mi.mesh.surface_get_material(s)
				if cur != slots[s]:
					changed = true
					break
	if changed:
		_apply_mesh(mi, rec)
	var mats: Array = [rec["over"]] if rec["over"] != null else rec["slots"]
	for over in mats:
		if over is StandardMaterial3D:
			for c in _by_std.get((over as Object).get_instance_id(), []):
				_sync(c)


## How much the texture may swim on a thing this size (big walls a little, the ground not).
func _bucket(mi: MeshInstance3D) -> int:
	if _in_room(mi):
		return B_ROOM
	var a := mi.get_aabb()
	var s := mi.global_transform.basis.get_scale()
	var longest := maxf(a.size.x * s.x, maxf(a.size.y * s.y, a.size.z * s.z))
	# Lying flat on the ground (a path, a verge, the grass overlay, a decal).
	var lowest := (mi.global_transform * a.position).y
	if a.size.y * s.y < 0.12 and longest > 0.5 and lowest < 0.6 and absf(mi.global_basis.y.normalized().y) > 0.9:
		return B_FLAT
	if longest > 24.0:
		return 2
	if longest > 6.0:
		return 1
	return 0


## Drawn by a viewport with a world of its own: a room, the bus, the pipes.
func _in_room(n: Node) -> bool:
	var vp := n.get_viewport()
	return vp is SubViewport and (vp as SubViewport).own_world_3d


func _track_sprite(s: Sprite3D) -> void:
	var rid := s.get_instance()
	if not rid.is_valid() or s.material_override != null:
		return
	var key := "sprite|%d|%d|%d|%d|%d" % [int(s.shaded), int(s.double_sided), int(s.alpha_cut), int(s.billboard), int(s.no_depth_test)]
	var m := ShaderMaterial.new()
	m.shader = _shader(_sprite_variant(s))
	m.set_shader_parameter("albedo_tex", s.texture)
	m.set_shader_parameter("has_tex", s.texture != null)
	m.set_shader_parameter("albedo_color", Color(1, 1, 1, 1))
	# A sprite laid flat on the floor (litter, a puddle) does not snap: it would flicker
	# against the floor under it.
	var flat := s.billboard == BaseMaterial3D.BILLBOARD_DISABLED and absf(s.global_basis.z.normalized().y) > 0.9
	m.set_shader_parameter("snap_lines", 0.0 if flat or _in_room(s) else SNAP_LINES)
	m.set_shader_parameter("affine", 0.0)
	RenderingServer.instance_geometry_set_material_override(rid, m.get_rid())
	_sprites.append({"node": weakref(s), "mat": m, "tex": s.texture, "key": key})


func _sprite_variant(s: Sprite3D) -> Dictionary:
	return {
		"lit": s.shaded,
		"cull": "disabled" if s.double_sided else "back",
		"alpha": 1 if s.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD else (0 if s.alpha_cut == SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS else 2),
		"billboard": int(s.billboard),
		"triplanar": false,
		"emission": 0,
		"sprite_light": true,
		"vcolor": true,
		"no_depth": s.no_depth_test,
	}


# ── materials ────────────────────────────────────────────────────────────────

## The ShaderMaterial for a StandardMaterial3D (made once, kept), or null when it is not
## one we can stand in for.
func _converted(src, big: int) -> ShaderMaterial:
	var std := src as StandardMaterial3D
	if std == null or not _supported(std):
		return null
	var key := "%d|%d" % [std.get_instance_id(), big]
	if _conv.has(key):
		return _conv[key]["mat"]
	var m := ShaderMaterial.new()
	m.shader = _shader(_variant(std))
	m.render_priority = std.render_priority
	var c := {"std": std, "mat": m, "sig": "", "hot": 0.0, "big": big}
	_conv[key] = c
	if not _by_std.has(std.get_instance_id()):
		_by_std[std.get_instance_id()] = []
	_by_std[std.get_instance_id()].append(c)
	_sync(c, true)
	return m


func _supported(std: StandardMaterial3D) -> bool:
	if std.normal_enabled or std.billboard_mode == BaseMaterial3D.BILLBOARD_PARTICLES or std.fixed_size:
		return false
	if std.detail_enabled or std.heightmap_enabled or std.refraction_enabled or std.use_point_size:
		return false
	if std.next_pass != null:
		return false
	return true


func _variant(std: StandardMaterial3D) -> Dictionary:
	var alpha := 0
	if std.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR or std.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_HASH:
		alpha = 1
	elif std.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA or std.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:
		alpha = 2
	var cull := "back"
	if std.cull_mode == BaseMaterial3D.CULL_DISABLED:
		cull = "disabled"
	elif std.cull_mode == BaseMaterial3D.CULL_FRONT:
		cull = "front"
	var emission := 0
	if std.emission_enabled:
		emission = 2 if std.emission_operator == BaseMaterial3D.EMISSION_OP_MULTIPLY else 1
	return {
		"lit": std.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED,
		"cull": cull,
		"alpha": alpha,
		"billboard": int(std.billboard_mode),
		"triplanar": std.uv1_triplanar,
		"emission": emission,
		# Cut-outs seen from both sides (sprites, the corn, fences, washing) and billboards
		# are lit like Build's sprites: by the light, not by which way they face it.
		"sprite_light": std.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or (alpha == 1 and cull == "disabled"),
		"vcolor": std.vertex_color_use_as_albedo,
		"no_depth": std.no_depth_test,
	}


## Copies what the game changes on the original (colour, picture, glow, tiling).
func _sync(c: Dictionary, force := false) -> void:
	var std: StandardMaterial3D = c["std"]
	if std == null or not is_instance_valid(std):
		return
	var sig := "%s|%s|%s|%s|%s|%s|%s|%s" % [std.albedo_color, std.albedo_texture, std.emission_enabled, std.emission, std.emission_energy_multiplier, std.emission_texture, std.uv1_scale, std.uv1_offset]
	if sig == c["sig"] and not force:
		return
	if c["sig"] != "" and not force:
		# Something about it is changing: watch it every frame for a while.
		if float(c["hot"]) <= 0.0:
			_hot.append(c)
		c["hot"] = HOT_SECONDS
	c["sig"] = sig
	var m: ShaderMaterial = c["mat"]
	# Glow switched on or off, a different kind of see-through: another variant.
	var sh := _shader(_variant(std))
	if m.shader != sh:
		m.shader = sh
	m.set_shader_parameter("albedo_color", std.albedo_color)
	m.set_shader_parameter("albedo_tex", std.albedo_texture)
	m.set_shader_parameter("has_tex", std.albedo_texture != null)
	m.set_shader_parameter("uv_scale", std.uv1_scale)
	m.set_shader_parameter("uv_offset", std.uv1_offset)
	m.set_shader_parameter("alpha_scissor", std.alpha_scissor_threshold)
	m.set_shader_parameter("emission_color", std.emission if std.emission_enabled else Color(0, 0, 0))
	m.set_shader_parameter("emission_energy", std.emission_energy_multiplier if std.emission_enabled else 0.0)
	m.set_shader_parameter("emission_tex", std.emission_texture)
	m.set_shader_parameter("has_emission_tex", std.emission_texture != null)
	var big: int = c["big"]
	m.set_shader_parameter("snap_lines", SNAP_LINES if big < 2 else 0.0)
	m.set_shader_parameter("affine", AFFINE_BY_BUCKET[big] if not std.uv1_triplanar else AFFINE_TRIPLANAR[big])


## One shader per combination of render modes and features.
func _shader(v: Dictionary) -> Shader:
	var key := str(v)
	if _shaders.has(key):
		return _shaders[key]
	var modes: Array[String] = ["specular_disabled", "cull_" + str(v["cull"])]
	if not v["lit"]:
		modes.append("unshaded")
	if int(v["alpha"]) != 2:
		modes.append("depth_draw_opaque")
	if v["no_depth"]:
		modes.append("depth_test_disabled")
	var defs := ""
	defs += "#define LIT\n" if v["lit"] else ""
	defs += "#define ALPHA_MODE %d\n" % int(v["alpha"])
	defs += "#define BILLBOARD %d\n" % int(v["billboard"])
	defs += "#define TRIPLANAR\n" if v["triplanar"] else ""
	defs += "#define EMISSION_MODE %d\n" % int(v["emission"])
	defs += "#define SPRITE_LIGHT\n" if v["sprite_light"] else ""
	defs += "#define VCOLOR\n" if v["vcolor"] else ""
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode " + ", ".join(modes) + ";\n" + defs + BODY
	_shaders[key] = sh
	return sh


const BODY := """
uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform bool has_tex = false;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
uniform float alpha_scissor = 0.5;
uniform vec4 emission_color : source_color = vec4(0.0);
uniform float emission_energy = 0.0;
uniform sampler2D emission_tex : source_color, filter_nearest, repeat_enable;
uniform bool has_emission_tex = false;
uniform float snap_lines = 150.0;
uniform float affine = 0.8;
// The light as the hands have it (materials/hand_ps1.gdshader): each lamp's, the torch's
// and the sun's light in steps, the steps dithered with a 4x4 Bayer matrix on the game's
// own low-res screen pixels, as the PlayStation dithered (on a far texture's texels the
// pattern turned to moire).
// Ten steps and half the dither (playtest 19. 10.: "the torch's light is far too harshly
// dithered"): the bands still show, the checker between them is a fringe, not a sheet.
uniform float light_steps = 10.0;
uniform float light_dither = 0.5;

varying vec2 v_uv;
varying vec2 v_texel;
varying vec2 v_uv_w;
varying float v_w;

void vertex() {
#if BILLBOARD == 1
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
#elif BILLBOARD == 2
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
#endif
	vec2 uv;
#ifdef TRIPLANAR
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz * uv_scale + uv_offset;
	vec3 wn = abs(normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz));
	wp *= vec3(1.0, -1.0, 1.0);
	if (wn.x >= wn.y && wn.x >= wn.z) {
		uv = wp.zy * vec2(-1.0, 1.0);
	} else if (wn.y >= wn.z) {
		uv = wp.xz * vec2(1.0, -1.0);
	} else {
		uv = wp.xy;
	}
#else
	uv = UV * uv_scale.xy + uv_offset.xy;
#endif
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	// The PlayStation's whole-pixel vertices, on a coarse grid: edges shiver as you move.
	if (snap_lines > 0.0 && clip.w > 0.05) {
		vec2 grid = vec2(snap_lines * VIEWPORT_SIZE.x / max(VIEWPORT_SIZE.y, 1.0), snap_lines) * 0.5;
		vec2 ndc = clip.xy / clip.w;
		ndc = floor(ndc * grid + 0.5) / grid;
		clip.xy = ndc * clip.w;
	}
	POSITION = clip;
	v_uv = uv;
	v_uv_w = uv * clip.w;
	v_w = clip.w;
}

void fragment() {
	// Affine: interpolated across the screen, not in depth (the stretch and the swim).
	// Not right in your face: a wall a step away would swirl into arcs (the PS1 cut its
	// big polygons up for that); the swim is for what is a few metres off.
	float near_fade = smoothstep(0.6, 3.5, v_w);
	vec2 uv = mix(v_uv, v_uv_w / max(v_w, 0.0001), affine * near_fade);
	vec4 c = albedo_color;
	if (has_tex) {
		c *= texture(albedo_tex, uv);
	}
#ifdef VCOLOR
	c *= COLOR;
#endif
	ALBEDO = c.rgb;
	v_texel = floor(FRAGCOORD.xy);
#if ALPHA_MODE == 1
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
#elif ALPHA_MODE == 2
	ALPHA = c.a;
#endif
#if EMISSION_MODE == 1
	vec3 e = emission_color.rgb;
	if (has_emission_tex) {
		e += texture(emission_tex, uv).rgb;
	}
	EMISSION = e * emission_energy;
#elif EMISSION_MODE == 2
	vec3 e = emission_color.rgb;
	if (has_emission_tex) {
		e *= texture(emission_tex, uv).rgb;
	}
	EMISSION = e * emission_energy;
#endif
}

#ifdef LIT
void light() {
#ifdef SPRITE_LIGHT
	float ndl = 0.8;
#else
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
#endif
	float lit = ndl * ATTENUATION;
	if (light_steps > 0.0) {
		const float B[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
		vec2 m = mod(v_texel, 4.0);
		float d = (B[int(m.x) + int(m.y) * 4] + 0.5) / 16.0 - 0.5;
		lit = max(floor(lit * light_steps + 0.5 + d * light_dither), 0.0) / light_steps;
	}
	DIFFUSE_LIGHT += LIGHT_COLOR * lit / PI;
}
#endif
"""
