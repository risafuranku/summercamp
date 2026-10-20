extends Node3D

## Spider webs in the camp (playtest 19. 10.: "pavouky a pavucinu s fyzikou, ze ji
## potrhas, kdyz projdes"): orb webs strung between tree trunks that stand close together
## and between a tree and a lamp post, a garden spider in the middle of each (Grok,
## world/spider.png).
##   - The silk is a net of strands that really hangs: spokes from the hub out to the frame,
##     a spiral round them, the frame pinned to the trunks. Verlet, thirty steps a second:
##     a little gravity, the wind (weather_visuals.wind_dir), each strand a rope that pulls
##     but never pushes, so a loose one sags and blows.
##   - Drawn as thin ribbons with the silk's picture on them (world/silk_strand.png, dew
##     beads along it), added to what is behind: at dawn and in the fog the dew makes them
##     glint, by day they are hard to see, at night only your torch or a lamp shows them.
##   - Walk into one and the strands you touch snap (pulled along the way you walk), a
##     strand stretched too far snaps by itself, the frame comes off the trunk where you hit
##     it. The silk tears in your ear; the spider runs off along a strand and is gone.
##   - At face height it sticks to your face: torn strands across your view (ui/web_face.png)
##     that you wipe off in a moment, and you splutter (ElevenLabs).
##   - A torn web is spun again a while after you have left it; a web whose trunk or lamp
##     is gone (felled, cleared, demolished) goes with it, and new pairs are looked for
##     now and then (webs hung in the air where the trees had been: the user 20. 10.).
## Made by weather_visuals.gd in the camp's world.

const SILK_TEX := "res://assets/textury/world/silk_strand.png"
const SPIDER_TEX := "res://assets/textury/world/spider.png"
const FACE_TEX := "res://assets/textury/ui/web_face.png"
const SFX_TEAR := "res://assets/sfx/world/web_tear.mp3"
const SFX_SPLUTTER := "res://assets/sfx/player/web_splutter.mp3"
const MAX_WEBS := 40
const RADIALS := 9
const RINGS := 6
const DRAW_RANGE := 26.0
const SIM_RANGE := 18.0
const SIM_HZ := 30.0
const REGROW_SEC := 240.0
const BODY_R := 0.3
const FACE_SHADER := """
shader_type canvas_item;
uniform float fade = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = smoothstep(0.12, 0.6, max(c.r, max(c.g, c.b))) * fade;
	COLOR = vec4(c.rgb * 1.1, a * 0.7);
}
"""

var player_getter: Callable

var _webs: Array = []
var _placed := false
var _place_t := 3.0
var _acc := 0.0
var _t := 0.0
var _silk_mat: StandardMaterial3D
var _spider_tex: Texture2D
var _tear: AudioStreamPlayer3D
var _splutter: AudioStreamPlayer
var _tear_cd := 0.0
var _face_cd := 0.0
var _face: TextureRect
var _face_mat: ShaderMaterial
var _face_t := -1.0
var _check_t := 2.0
var _replace_t := 60.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "SpiderWebs"
	_rng.randomize()
	_silk_mat = StandardMaterial3D.new()
	_silk_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_silk_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_silk_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_silk_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_silk_mat.texture_repeat = true
	_silk_mat.roughness = 1.0
	_silk_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_silk_mat.vertex_color_use_as_albedo = true
	if ResourceLoader.exists(SILK_TEX):
		_silk_mat.albedo_texture = load(SILK_TEX)
	_spider_tex = load(SPIDER_TEX) if ResourceLoader.exists(SPIDER_TEX) else null
	_tear = AudioStreamPlayer3D.new()
	_tear.bus = "OutdoorAmbience"
	_tear.unit_size = 1.5
	_tear.max_distance = 10.0
	_tear.stream = load(SFX_TEAR) if ResourceLoader.exists(SFX_TEAR) else null
	add_child(_tear)
	_splutter = AudioStreamPlayer.new()
	_splutter.stream = load(SFX_SPLUTTER) if ResourceLoader.exists(SFX_SPLUTTER) else null
	_splutter.volume_db = -13.0
	add_child(_splutter)
	# The strands on your face: over the camp's picture (low-res, like the world).
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	_face = TextureRect.new()
	# A corner of the view, not all of it (it took too much: the user 20. 10.): sized and
	# placed when it sticks (_stick_face).
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.stretch_mode = TextureRect.STRETCH_SCALE
	_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_face.texture = load(FACE_TEX) if ResourceLoader.exists(FACE_TEX) else null
	_face_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = FACE_SHADER
	_face_mat.shader = sh
	_face.material = _face_mat
	_face.visible = false
	layer.add_child(_face)


# ── where the webs are ───────────────────────────────────────────────────────

## In the gap between two trunks (or a trunk and a lamp post) 1.4 to 4.2 m apart, always the same
## pairs (by where they stand), no more than MAX_WEBS of them.
func _place() -> void:
	var posts: Array = []
	for n in get_tree().get_nodes_in_group("trees"):
		var t := n as Node3D
		if t != null and t.is_inside_tree():
			posts.append([t.global_position, 0.24 * t.scale.x, t])
	for n in get_tree().get_nodes_in_group("lamp_posts"):
		var l := n as Node3D
		if l != null and l.is_inside_tree():
			posts.append([l.global_position, 0.07, l])
	if posts.size() < 2:
		return
	var pairs: Array = []
	for i in posts.size():
		for j in range(i + 1, posts.size()):
			var a: Vector3 = posts[i][0]
			var b: Vector3 = posts[j][0]
			var d := Vector2(a.x - b.x, a.z - b.z).length()
			if d < 1.4 or d > 4.2:
				continue
			var h := absi(hash(Vector3i(roundi(a.x * 10.0 + b.x * 10.0), 0, roundi(a.z * 10.0 + b.z * 10.0))))
			pairs.append([h, i, j])
	pairs.sort_custom(func(x, y): return int(x[0]) < int(y[0]))
	var used := {}
	# Trunks that hold a web already (looked again later: one web to a trunk still).
	for w in _webs:
		for n in w.get("posts", []):
			if is_instance_valid(n):
				for k in posts.size():
					if posts[k][2] == n:
						used[k] = true
	for pr in pairs:
		if _webs.size() >= MAX_WEBS:
			break
		var i: int = pr[1]
		var j: int = pr[2]
		# One web to a trunk.
		if used.has(i) or used.has(j):
			continue
		if int(pr[0]) % 5 == 0:
			continue
		used[i] = true
		used[j] = true
		var key := _pair_key(posts[i][0], posts[j][0])
		if _has_pair(key):
			continue
		var w := _make_web(posts[i], posts[j], int(pr[0]))
		w["posts"] = [posts[i][2], posts[j][2]]
		w["pair"] = key
		_webs.append(w)
	_placed = true


static func _pair_key(a: Vector3, b: Vector3) -> String:
	var ka := "%d,%d" % [roundi(a.x * 10.0), roundi(a.z * 10.0)]
	var kb := "%d,%d" % [roundi(b.x * 10.0), roundi(b.z * 10.0)]
	return ka + "|" + kb if ka < kb else kb + "|" + ka


func _has_pair(key: String) -> bool:
	for w in _webs:
		if str(w.get("pair", "")) == key:
			return true
	return false


## Webs whose trunk or lamp is gone go with it.
func _drop_orphans() -> void:
	for i in range(_webs.size() - 1, -1, -1):
		var w: Dictionary = _webs[i]
		var gone := false
		for n in w.get("posts", []):
			if not is_instance_valid(n) or not (n as Node).is_inside_tree() or (n as Node).is_queued_for_deletion():
				gone = true
		if not gone:
			continue
		if is_instance_valid(w["mesh"]):
			(w["mesh"] as Node).queue_free()
		if w["spider"] != null and is_instance_valid(w["spider"]):
			(w["spider"] as Node).queue_free()
		_webs.remove_at(i)


func _make_web(pa: Array, pb: Array, seed: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var a: Vector3 = pa[0]
	var b: Vector3 = pb[0]
	var flat := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
	var ea := Vector3(a.x, 0, a.z) + flat * float(pa[1])
	var eb := Vector3(b.x, 0, b.z) - flat * float(pb[1])
	# A garden spider's orb is a hand or two across, not the gap: 35 to 65 cm, hanging
	# somewhere in it at chest to head height, held to the trunks by long mooring lines.
	var t := r.randf_range(0.3, 0.7)
	var c := ea.lerp(eb, t) + Vector3(0, r.randf_range(1.0, 1.65), 0)
	var rad := r.randf_range(0.17, 0.32)
	var anchors := [c + Vector3(0, -rad, 0) - flat * rad, c + Vector3(0, rad * 1.1, 0) - flat * rad * 0.9,
		c + Vector3(0, rad, 0) + flat * rad, c + Vector3(0, -rad * 0.9, 0) + flat * rad * 1.05]
	# The mooring lines: up and out to each trunk, the lower ones slanting down to it.
	var moor: Array = [ea + Vector3(0, c.y - rad - r.randf_range(0.2, 0.6), 0), ea + Vector3(0, c.y + rad + r.randf_range(0.15, 0.5), 0),
		eb + Vector3(0, c.y + rad + r.randf_range(0.15, 0.5), 0), eb + Vector3(0, c.y - rad - r.randf_range(0.2, 0.6), 0)]
	var mesh := MeshInstance3D.new()
	mesh.name = "Web"
	mesh.mesh = ImmediateMesh.new()
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.set_meta("retro_skip", true)
	add_child(mesh)
	var spider: Sprite3D = null
	if _spider_tex != null:
		spider = Sprite3D.new()
		spider.texture = _spider_tex
		spider.pixel_size = 0.0022
		spider.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		spider.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		spider.double_sided = true
		spider.shaded = true
		add_child(spider)
	var w := {"anchors": anchors, "moor": moor, "centre": c, "u": flat, "v": Vector3.UP, "mesh": mesh, "spider": spider,
		"seed": seed, "torn_at": -1.0, "awake": false}
	_spin(w)
	return w


## Spin it (again): the hub, the spokes out to the frame, the spiral, the frame.
func _spin(w: Dictionary) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(w["seed"])
	var c: Vector3 = w["centre"]
	var u: Vector3 = w["u"]
	var v: Vector3 = w["v"]
	var anchors: Array = w["anchors"]
	var pos := PackedVector3Array()
	var pinned := PackedByteArray()
	pos.append(c)
	pinned.append(0)
	var ends: Array = []
	for k in RADIALS:
		var ang := TAU * float(k) / float(RADIALS) + r.randf_range(-0.15, 0.15)
		var dir := u * cos(ang) + v * sin(ang)
		var end := _hit_frame(c, dir, anchors)
		ends.append(end)
		for i in range(1, RINGS + 1):
			var f := float(i) / float(RINGS)
			pos.append(c + (end - c) * f)
			pinned.append(1 if i == RINGS else 0)
	var cons: Array = []      # [i, j, rest, kind] kind 0 spoke 1 spiral 2 frame
	for k in RADIALS:
		var prev := 0
		for i in range(1, RINGS + 1):
			var n := _node(k, i)
			cons.append([prev, n, pos[prev].distance_to(pos[n]), 0])
			prev = n
		var k2 := (k + 1) % RADIALS
		for i in range(2, RINGS):
			var n1 := _node(k, i)
			var n2 := _node(k2, i)
			# A little slack in the spiral, so it hangs.
			cons.append([n1, n2, pos[n1].distance_to(pos[n2]) * 1.04, 1])
		cons.append([_node(k, RINGS), _node(k2, RINGS), pos[_node(k, RINGS)].distance_to(pos[_node(k2, RINGS)]), 2])
	# The mooring lines: each corner of the frame to the trunk, and to its nearest spoke end.
	var moor: Array = w.get("moor", [])
	for k in moor.size():
		var corner := pos.size()
		pos.append(anchors[k])
		pinned.append(1)
		var anchor := pos.size()
		pos.append(moor[k])
		pinned.append(1)
		cons.append([corner, anchor, (anchors[k] as Vector3).distance_to(moor[k]), 2])
		var near := _node(0, RINGS)
		for kk in RADIALS:
			if pos[_node(kk, RINGS)].distance_to(anchors[k]) < pos[near].distance_to(anchors[k]):
				near = _node(kk, RINGS)
		cons.append([corner, near, pos[corner].distance_to(pos[near]), 2])
	var alive := PackedByteArray()
	alive.resize(cons.size())
	alive.fill(1)
	w["pos"] = pos
	w["prev"] = pos.duplicate()
	w["pinned"] = pinned
	w["cons"] = cons
	w["alive"] = alive
	w["broken"] = 0
	w["spider_state"] = "sit"
	w["spider_t"] = 0.0
	w["torn_at"] = -1.0
	var sp: Sprite3D = w["spider"]
	if sp != null:
		sp.visible = true
		sp.global_transform = Transform3D(Basis(u, v, u.cross(v)), c)


static func _node(k: int, i: int) -> int:
	return 1 + k * RINGS + (i - 1)


## Where a spoke from the hub meets the frame (the polygon through the anchors).
func _hit_frame(c: Vector3, dir: Vector3, anchors: Array) -> Vector3:
	var best := c + dir * 0.8
	var best_t := INF
	for i in anchors.size():
		var p0: Vector3 = anchors[i]
		var p1: Vector3 = anchors[(i + 1) % anchors.size()]
		# In the web's plane: solve c + dir*t = p0 + (p1-p0)*s (least squares in 3D).
		var e := p1 - p0
		var m := Basis(dir, -e, dir.cross(e).normalized())
		if absf(m.determinant()) < 0.0001:
			continue
		var ts := m.inverse() * (p0 - c)
		var t := ts.x
		var s := ts.y
		if t > 0.05 and s >= 0.0 and s <= 1.0 and t < best_t:
			best_t = t
			best = c + dir * t
	return best


# ── each frame ───────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_t += delta
	var player: Node3D = player_getter.call() if player_getter.is_valid() else null
	if player == null:
		return
	if not _placed:
		_place_t -= delta
		if _place_t <= 0.0:
			_place_t = 5.0
			_place()
		return
	_tear_cd -= delta
	_face_cd -= delta
	_update_face(delta)
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = 2.0
		_drop_orphans()
	_replace_t -= delta
	if _replace_t <= 0.0:
		_replace_t = 60.0
		_place()
	var main := get_tree().current_scene
	var indoors: bool = main != null and main.has_method("_is_any_interior_open") and bool(main.call("_is_any_interior_open"))
	var cam := get_viewport().get_camera_3d()
	var eye: Vector3 = cam.global_position if cam != null else player.global_position + Vector3.UP * 1.6
	var here := player.global_position
	_acc += delta
	var step := 1.0 / SIM_HZ
	var steps := 0
	while _acc >= step and steps < 3:
		_acc -= step
		steps += 1
		for w in _webs:
			var d := Vector2(here.x - (w["centre"] as Vector3).x, here.z - (w["centre"] as Vector3).z).length()
			w["awake"] = d < SIM_RANGE and not indoors
			if bool(w["awake"]):
				_simulate(w, step)
				if d < 3.5:
					_touch(w, player, eye)
			elif int(w["broken"]) > 0 and d > 35.0 and float(w["torn_at"]) >= 0.0 and _t - float(w["torn_at"]) > REGROW_SEC:
				_spin(w)
	# How wide one pixel of the world's (low-res) picture is a metre away.
	var px_m := 0.004
	if cam != null:
		px_m = 2.0 * tan(deg_to_rad(cam.fov) * 0.5) / maxf(1.0, float(get_viewport().get_visible_rect().size.y))
	var dew := _dew(main)
	_silk_mat.albedo_color = Color(0.75, 0.78, 0.82, 1.0) * dew
	for w in _webs:
		var d2 := Vector2(here.x - (w["centre"] as Vector3).x, here.z - (w["centre"] as Vector3).z).length()
		var show := d2 < DRAW_RANGE and not indoors
		(w["mesh"] as MeshInstance3D).visible = show
		if show:
			_draw(w, eye, px_m)
		_spider_step(w, delta, show)


## How much the silk shows: dew at dawn and in the fog.
func _dew(main: Node) -> float:
	if main == null:
		return 1.0
	var hour: float = float(main.get("_time_of_day_hours")) if main.get("_time_of_day_hours") != null else 12.0
	var w := int(main.get("_weather_state")) if main.get("_weather_state") != null else 0
	var k := 0.9
	if hour >= 5.0 and hour < 9.5:
		k = 1.8
	if w == 2 or w == 3:
		k = maxf(k, 1.6)
	return k


func _simulate(w: Dictionary, dt: float) -> void:
	var pos: PackedVector3Array = w["pos"]
	var prev: PackedVector3Array = w["prev"]
	var pinned: PackedByteArray = w["pinned"]
	var wv = get_tree().current_scene.get("_weather_visuals")
	var wd: Vector2 = wv.wind_dir if wv != null else Vector2(0.94, 0.34)
	var ws: float = float(wv.get("_wind_now")) if wv != null else 0.15
	var gravity := Vector3(0, -1.4, 0)
	for i in pos.size():
		if pinned[i] == 1:
			continue
		var p := pos[i]
		var vel := (p - prev[i]) * 0.96
		prev[i] = p
		var gust := sin(_t * 2.3 + float(i) * 0.7) * 0.5 + 0.7
		var wind := Vector3(wd.x, 0, wd.y) * ws * gust * 2.2
		pos[i] = p + vel + (gravity + wind) * dt * dt
	var cons: Array = w["cons"]
	var alive: PackedByteArray = w["alive"]
	for iter in 3:
		for ci in cons.size():
			if alive[ci] == 0:
				continue
			var c: Array = cons[ci]
			var i: int = c[0]
			var j: int = c[1]
			var pi := pinned[i] == 1
			var pj := pinned[j] == 1
			if pi and pj:
				continue
			var d := pos[j] - pos[i]
			var l := d.length()
			var rest: float = c[2]
			if l <= rest or l < 0.0001:
				continue
			if l > rest * 2.2:
				# Stretched past what silk takes.
				alive[ci] = 0
				w["broken"] = int(w["broken"]) + 1
				continue
			var corr := d * ((l - rest) / l)
			if pi:
				pos[j] -= corr
			elif pj:
				pos[i] += corr
			else:
				pos[i] += corr * 0.5
				pos[j] -= corr * 0.5
	w["pos"] = pos
	w["prev"] = prev
	w["alive"] = alive


## You walking into it: every strand within reach of your body snaps, the silk round it
## is pulled along the way you go.
func _touch(w: Dictionary, player: Node3D, eye: Vector3) -> void:
	var vel := Vector3.ZERO
	if player is CharacterBody3D:
		vel = (player as CharacterBody3D).velocity
	if Vector2(vel.x, vel.z).length() < 0.25:
		return
	var foot := Vector3(eye.x, eye.y - 1.55, eye.z)
	var top := Vector3(eye.x, eye.y + 0.12, eye.z)
	var pos: PackedVector3Array = w["pos"]
	var prev: PackedVector3Array = w["prev"]
	var pinned: PackedByteArray = w["pinned"]
	var cons: Array = w["cons"]
	var alive: PackedByteArray = w["alive"]
	var snapped := 0
	var face := false
	for ci in cons.size():
		if alive[ci] == 0:
			continue
		var c: Array = cons[ci]
		var a := pos[c[0]]
		var b := pos[c[1]]
		var pts := Geometry3D.get_closest_points_between_segments(a, b, foot, top)
		if (pts[0] as Vector3).distance_to(pts[1]) > BODY_R:
			continue
		alive[ci] = 0
		snapped += 1
		if (pts[0] as Vector3).y > eye.y - 0.45:
			face = true
		# A mooring line you broke lets its corner of the orb fall away.
		if int(c[0]) > RADIALS * RINGS and int(c[1]) == int(c[0]) + 1:
			pinned[c[0]] = 0
		for n in [c[0], c[1]]:
			# The frame comes off the trunk where you hit it.
			if pinned[n] == 1 and (pos[n] as Vector3).distance_to(pts[1]) < BODY_R * 1.4:
				pinned[n] = 0
			if pinned[n] == 0:
				prev[n] = pos[n] - vel * (1.0 / SIM_HZ) * 0.9
	if snapped == 0:
		return
	w["broken"] = int(w["broken"]) + snapped
	w["torn_at"] = _t
	w["pinned"] = pinned
	w["prev"] = prev
	w["alive"] = alive
	if _tear_cd <= 0.0 and _tear.stream != null:
		_tear_cd = 0.6
		_tear.global_position = w["centre"]
		_tear.pitch_scale = _rng.randf_range(0.92, 1.1)
		_tear.play()
	if face and _face_cd <= 0.0:
		_face_cd = 4.0
		_face_t = 0.0
		_stick_face()
		if _splutter.stream != null:
			_splutter.pitch_scale = _rng.randf_range(0.95, 1.05)
			get_tree().create_timer(0.25).timeout.connect(func(): if is_instance_valid(_splutter): _splutter.play())


## The strands as thin ribbons turned to the eye, the silk's picture along them.
func _draw(w: Dictionary, eye: Vector3, px_m: float) -> void:
	var im: ImmediateMesh = (w["mesh"] as MeshInstance3D).mesh
	im.clear_surfaces()
	var pos: PackedVector3Array = w["pos"]
	var cons: Array = w["cons"]
	var alive: PackedByteArray = w["alive"]
	var began := false
	for ci in cons.size():
		if alive[ci] == 0:
			continue
		var c: Array = cons[ci]
		var a := pos[c[0]]
		var b := pos[c[1]]
		var ab := b - a
		var l := ab.length()
		if l < 0.002:
			continue
		var mid := (a + b) * 0.5
		var dist := mid.distance_to(eye)
		# Silk is far thinner than a pixel: drawn a pixel wide (or it drops out of the
		# picture), as bright as the little of that pixel it covers, and fading out with
		# distance (added light: dimmer is fainter, not thicker).
		var silk := 0.0022 * (1.4 if int(c[3]) == 2 else 1.0)
		var width := maxf(silk, dist * px_m * 0.55)
		var side := ab.cross(eye - mid).normalized() * width
		var k := clampf(silk / width, 0.3, 1.0) * clampf(1.2 - (dist - 2.0) / 8.0, 0.0, 1.0)
		if k <= 0.02:
			continue
		if not began:
			im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _silk_mat)
			began = true
		im.surface_set_color(Color(k, k, k, 1.0))
		var u1 := l / 0.12
		# One strand of the picture (a band a twelfth of it high).
		var v0 := 0.0
		var v1 := 0.08
		im.surface_set_uv(Vector2(0, v0)); im.surface_add_vertex(a - side)
		im.surface_set_uv(Vector2(u1, v0)); im.surface_add_vertex(b - side)
		im.surface_set_uv(Vector2(u1, v1)); im.surface_add_vertex(b + side)
		im.surface_set_uv(Vector2(0, v0)); im.surface_add_vertex(a - side)
		im.surface_set_uv(Vector2(u1, v1)); im.surface_add_vertex(b + side)
		im.surface_set_uv(Vector2(0, v1)); im.surface_add_vertex(a + side)
	if began:
		im.surface_end()


## The spider: in the middle while the web holds; when it is torn it runs out along a
## spoke to the frame and is gone.
func _spider_step(w: Dictionary, delta: float, show: bool) -> void:
	var sp: Sprite3D = w["spider"]
	if sp == null:
		return
	var state := str(w["spider_state"])
	if state == "gone":
		sp.visible = false
		return
	sp.visible = show
	var pos: PackedVector3Array = w["pos"]
	if state == "sit":
		sp.global_position = pos[0]
		if int(w["broken"]) > 6:
			w["spider_state"] = "run"
			w["spider_t"] = 0.0
			# The spoke whose end still holds.
			var target := pos[0]
			var pinned: PackedByteArray = w["pinned"]
			for k in RADIALS:
				var n := _node(k, RINGS)
				if pinned[n] == 1:
					target = pos[n]
					break
			w["spider_to"] = target
			w["spider_from"] = pos[0]
	elif state == "run":
		w["spider_t"] = float(w["spider_t"]) + delta
		var k2 := clampf(float(w["spider_t"]) / 0.9, 0.0, 1.0)
		# Scuttling: in steps.
		var ks := floorf(k2 * 10.0) / 10.0
		sp.global_position = (w["spider_from"] as Vector3).lerp(w["spider_to"], ks)
		if k2 >= 1.0:
			w["spider_state"] = "gone"


## Where on your face it sticks: a corner or an edge of the view, under half of it.
func _stick_face() -> void:
	var vs := get_viewport().get_visible_rect().size
	var sz := vs * _rng.randf_range(0.36, 0.48)
	sz.y = sz.x * 0.75
	_face.size = sz
	_face.flip_h = _rng.randf() < 0.5
	_face.flip_v = _rng.randf() < 0.3
	var corner := Vector2(0.0 if _face.flip_h else 1.0, 0.0 if _rng.randf() < 0.6 else 1.0)
	_face.set_meta("home", ((vs - sz) * corner + Vector2(_rng.randf_range(-0.04, 0.04), _rng.randf_range(-0.04, 0.04)) * vs).floor())
	_face.position = _face.get_meta("home")


func _update_face(delta: float) -> void:
	if _face_t < 0.0:
		_face.visible = false
		return
	_face_t += delta
	var k := _face_t / 2.6
	if k >= 1.0:
		_face_t = -1.0
		_face.visible = false
		return
	_face.visible = _face.texture != null
	# Stuck on, then wiped off downwards, in steps.
	var ks := floorf(k * 12.0) / 12.0
	_face_mat.set_shader_parameter("fade", 1.0 if ks < 0.35 else 1.0 - (ks - 0.35) / 0.65)
	_face.position = (_face.get_meta("home", Vector2.ZERO) as Vector2) + Vector2(0, maxf(0.0, ks - 0.35) * 120.0)
