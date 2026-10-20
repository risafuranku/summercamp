extends Node3D

## The weather on the ground round you, outdoors (the camp, the road, Lesna):
##   - rain: puddles gather where you are (they grow the longer it rains and dry up after,
##     slowly), rings spread on them as the drops hit, in steps;
##   - after the rain, while it is still wet: drops fall off the eaves of the buildings near
##     you and the branches of the trees, a crown where each lands (Grok world/water_drop.png,
##     world/rain_splash.png), fewer as it dries (world_sounds.gd has their sound);
##   - night, the morning and fog: low mist lies along the ground and creeps with the wind,
##     thicker in the small hours, the most at first light (in the hollows, over the lake),
##     gone by half past eight, and in the fog all day: banks of it (Grok world/mist_bank.png,
##     see-through in four steps like Blood's smoke) in the fog's colour for the hour;
## The puddle and the rings on it are Grok pictures (world/puddle.png, world/rain_ring.png). Not while you are in a room. Made by
## InteriorManager.setup() in the camp's world, like sky_life.gd and wind_life.gd.

const FPS := 12.0
const PUDDLES := 26
const MIST := 18
const RADIUS := 22.0
const MIST_TEX := "res://assets/textury/world/mist_bank.png"
## A raindrop's ripple, four frames of 16 px side by side (tools/artgen/light_sprites.py).
const RING_TEX := "res://assets/textury/world/rain_ring.png"
const DROP_TEX := "res://assets/textury/world/water_drop.png"
const SPLASH_TEX := "res://assets/textury/world/rain_splash.png"
const DRIPS := 24

var player_getter: Callable
var indoors: Callable
var weather_getter: Callable
## Callable() -> float: the hour.
var hour_getter: Callable

var _rng := RandomNumberGenerator.new()
var _puddles: Array = []         # {mesh, mat, size, rings: [Sprite3D]}
var _wet := 0.0                  # 0 dry .. 1 soaked
var _mist: Array = []            # {sprite, off: Vector3, drift}
var _mist_amount := 0.0
var _ring_frames: Array = []     # the ripple's frames: regions of RING_TEX
var _ring_tex: Texture2D
var _acc := 0.0
var _t := 0.0
var _anchor := Vector3.INF
var _rain := 0.0
var _drips: Array = []           # {drop: Sprite3D, crown: Sprite3D, v, t (crown frames left)}
var _drip_t := 1.0               # the next drop off a tree
var _drip_eaves: Dictionary = {} # building id -> {pts: [Vector3], t: [float]}: the eaves near you
var _drip_scan := 0.0


func _ready() -> void:
	name = "GroundLife"
	_rng.randomize()
	var puddle_tex := _puddle_texture()
	_ring_tex = load(RING_TEX) if ResourceLoader.exists(RING_TEX) else null
	for i in 4:
		_ring_frames.append(Rect2(i * 16, 0, 16, 16))
	for i in PUDDLES:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.orientation = PlaneMesh.FACE_Y
		var s := _rng.randf_range(0.7, 2.2)
		q.size = Vector2(s, s * _rng.randf_range(0.5, 0.8))
		mi.mesh = q
		var m := StandardMaterial3D.new()
		m.albedo_texture = puddle_tex
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.roughness = 0.45
		m.metallic_specular = 0.25
		# The sky in it: the water shows the light of the sky over it (lit only by the rain's
		# dull light it was as dark as the wet grass and did not read), set every step.
		m.emission_enabled = true
		m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		m.emission_texture = puddle_tex
		m.emission_energy_multiplier = 0.0
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.rotation.y = _rng.randf() * TAU
		mi.visible = false
		add_child(mi)
		var rings: Array = []
		for k in 2:
			var r := Sprite3D.new()
			r.axis = Vector3.AXIS_Y
			r.texture = _ring_tex
			r.region_enabled = true
			r.region_rect = _ring_frames[0]
			r.pixel_size = 0.03
			r.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			r.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			r.shaded = true
			r.visible = false
			add_child(r)
			rings.append({"sprite": r, "t": _rng.randf() * 0.6})
		_puddles.append({"mesh": mi, "size": s, "rings": rings, "spot": Vector3.ZERO})
	var drop_tex: Texture2D = load(DROP_TEX) if ResourceLoader.exists(DROP_TEX) else null
	var crown_tex: Texture2D = load(SPLASH_TEX) if ResourceLoader.exists(SPLASH_TEX) else null
	for i in DRIPS:
		var dr := Sprite3D.new()
		dr.texture = drop_tex
		dr.pixel_size = 0.0075
		dr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		dr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		dr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		dr.shaded = false
		dr.visible = false
		add_child(dr)
		var cr := Sprite3D.new()
		cr.texture = crown_tex
		cr.pixel_size = 0.014
		cr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		cr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		cr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		cr.shaded = false
		cr.offset = Vector2(0, 5)
		cr.visible = false
		add_child(cr)
		_drips.append({"drop": dr, "crown": cr, "v": 0.0, "t": 0, "live": false})
	var mist_tex := _mist_texture()
	for i in MIST:
		var sp := Sprite3D.new()
		sp.texture = mist_tex
		sp.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		sp.transparent = true
		sp.shaded = false
		sp.pixel_size = _rng.randf_range(0.11, 0.16)
		sp.modulate = Color(0.75, 0.78, 0.82, 0.0)
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sp)
		var ang := _rng.randf() * TAU
		var d := _rng.randf_range(12.0, 36.0)
		_mist.append({"sprite": sp, "off": Vector3(cos(ang) * d, 0, sin(ang) * d), "drift": _rng.randf_range(0.2, 0.6)})


# ── pixel art ────────────────────────────────────────────────────────────────

## The puddle (Grok, assets/textury/world/puddle.png); the old pixel one if it is missing.
func _puddle_texture() -> Texture2D:
	if ResourceLoader.exists("res://assets/textury/world/puddle.png"):
		return load("res://assets/textury/world/puddle.png")
	var w := 32
	var h := 24
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var d := Vector2((x - w * 0.5 + 0.5) / (w * 0.5), (y - h * 0.5 + 0.5) / (h * 0.5))
			var wob := 0.86 + 0.14 * sin(atan2(d.y, d.x) * 3.0 + 1.3) * cos(atan2(d.y, d.x) * 2.0)
			if d.length() < wob:
				var edge := d.length() > wob - 0.16
				var c := Color(0.09, 0.1, 0.11) if not edge else Color(0.17, 0.15, 0.12)
				# The sky caught in it, in streaks.
				if not edge and (y % 5 == 1) and (x + y) % 7 < 3:
					c = Color(0.26, 0.29, 0.32)
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


## A long low bank of mist (Grok `spr_mist_bank`, tools/artgen/light_sprites.py: white,
## see-through in four steps as Blood's translucent sprites; it was drawn here in code).
func _mist_texture() -> Texture2D:
	return load(MIST_TEX) if ResourceLoader.exists(MIST_TEX) else null


## Whether one of the puddles lies at `p` (your feet: player_controller.gd's footsteps).
func puddle_at(p: Vector3) -> bool:
	for pd in _puddles:
		var mi: MeshInstance3D = pd["mesh"]
		if mi.visible and Vector2(mi.global_position.x - p.x, mi.global_position.z - p.z).length() < float(pd["size"]) * 0.4 * mi.scale.x:
			return true
	return false


# ── every frame ──────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	var p: Node3D = player_getter.call() if player_getter.is_valid() else null
	var inside: bool = indoors.is_valid() and indoors.call()
	visible = p != null and not inside
	if not visible:
		return
	_t += delta
	var wtr := int(weather_getter.call()) if weather_getter.is_valid() else 0
	var h := float(hour_getter.call()) if hour_getter.is_valid() else 12.0
	# 3 light rain, 4 rain, 5 storm.
	_rain = [0.0, 0.0, 0.0, 0.45, 0.8, 1.0, 0.0][clampi(wtr, 0, 6)]
	_wet = clampf(_wet + delta * (_rain * 0.012 if _rain > 0.0 else -0.004), 0.0, 1.0)
	var night := h >= 21.0 or h < 5.0
	var small_hours := h >= 1.0 and h < 5.0
	var want_mist := 0.0
	if wtr == 2:
		want_mist = 1.0
	elif h >= 5.0 and h < 8.5:
		# First light: the mist at its thickest, lifting from half past six (the dawn was
		# flat and bare: inventory 20. 10.).
		want_mist = 0.75 * clampf((8.5 - h) / 2.0, 0.0, 1.0)
	elif night:
		want_mist = 0.55 if small_hours else 0.35
	if _rain > 0.6:
		want_mist *= 0.4
	_mist_amount = move_toward(_mist_amount, want_mist, delta * 0.03)
	_acc += delta
	if _acc < 1.0 / FPS:
		return
	_acc = 0.0
	var centre := p.global_position
	# The puddles stay where they formed while you are near; far off they form anew round you.
	if _anchor == Vector3.INF or Vector2(_anchor.x - centre.x, _anchor.z - centre.z).length() > RADIUS * 0.7:
		_anchor = centre
		for pd in _puddles:
			var ang := _rng.randf() * TAU
			# More of them near you: flat on the ground, the far ones are a line at most.
			var d := lerpf(2.0, RADIUS, pow(_rng.randf(), 1.8))
			pd["spot"] = Vector3(centre.x + cos(ang) * d, 0.045, centre.z + sin(ang) * d)
	for i in _puddles.size():
		var pd: Dictionary = _puddles[i]
		var mi: MeshInstance3D = pd["mesh"]
		# The wetter it is the more there are, the bigger.
		var share := float(i) / float(_puddles.size())
		var on := _wet > share * 0.9 + 0.05
		mi.visible = on
		var k := clampf((_wet - share * 0.9) * 3.0, 0.3, 1.0)
		mi.scale = Vector3(k, 1.0, k)
		mi.global_position = pd["spot"]
		for rg in pd["rings"]:
			var r: Sprite3D = rg["sprite"]
			r.visible = on and _rain > 0.0
			if not r.visible:
				continue
			rg["t"] = float(rg["t"]) + 1.0 / FPS * (0.8 + _rain)
			if rg["t"] > 0.6:
				rg["t"] = 0.0
				var spot: Vector3 = pd["spot"]
				var rr := float(pd["size"]) * 0.3 * k
				r.global_position = spot + Vector3(_rng.randf_range(-rr, rr), 0.01, _rng.randf_range(-rr, rr))
			r.region_rect = _ring_frames[mini(3, int(float(rg["t"]) / 0.15))]
	# The mist drifts round you, low, dimmer the further. It is the fog's own colour for
	# the hour (it stood out pale blue-grey in a dark red evening: playtest 18. 10.).
	var wind := Vector3(cos(_t * 0.01), 0, sin(_t * 0.013))
	var tint := Color(0.72, 0.76, 0.82)
	var env := get_world_3d().environment if get_world_3d() != null else null
	if env != null and env.fog_enabled:
		tint = env.fog_light_color
	# The puddles mirror the sky's light (the fog's colour for the hour is the sky's).
	var sky_k := 1.3 if env != null and env.fog_enabled else 0.0
	for pd2 in _puddles:
		var pm := (pd2["mesh"] as MeshInstance3D).material_override as StandardMaterial3D
		if pm != null:
			pm.emission = tint
			pm.emission_energy_multiplier = sky_k
	for ms in _mist:
		var sp: Sprite3D = ms["sprite"]
		var off: Vector3 = ms["off"]
		off += wind * float(ms["drift"]) / FPS
		if off.length() > 38.0 or off.length() < 10.0:
			off = -off.normalized() * 30.0 if off.length() > 38.0 else off.normalized() * 12.0
		ms["off"] = off
		sp.global_position = Vector3(centre.x + off.x, 0.6 + sin(_t * 0.2 + off.x) * 0.15, centre.z + off.z)
		var a := _mist_amount * 0.9 * clampf((off.length() - 10.0) / 10.0, 0.2, 1.0)
		sp.modulate = Color(tint.r, tint.g, tint.b, a)
		sp.visible = a > 0.01
	_step_drips(centre, tint)


## The drops after the rain: off an eave near you or a tree's branch, falling, a crown where
## it lands; more often the wetter it still is. In steps, twelve a second.
func _step_drips(centre: Vector3, tint: Color) -> void:
	var dt := 1.0 / FPS
	var col := tint.lightened(0.45)
	for d in _drips:
		var cr: Sprite3D = d["crown"]
		if int(d["t"]) > 0:
			d["t"] = int(d["t"]) - 1
			cr.visible = int(d["t"]) > 0
		if not d["live"]:
			continue
		var dr: Sprite3D = d["drop"]
		d["v"] = float(d["v"]) + 9.8 * dt
		var p := dr.global_position - Vector3(0, float(d["v"]) * dt, 0)
		if p.y <= 0.06:
			d["live"] = false
			dr.visible = false
			cr.global_position = Vector3(p.x, 0.03, p.z)
			cr.modulate = col
			cr.visible = true
			d["t"] = 3
			continue
		dr.global_position = p
		dr.modulate = col
	if _rain > 0.0 or _wet < 0.15:
		return
	var wetness := clampf((_wet - 0.15) / 0.6, 0.0, 1.0)
	# The eaves of the buildings near you, looked up again every second: each spot where the
	# water gathers drips on its own beat, faster the wetter it still is.
	_drip_scan -= dt
	if _drip_scan <= 0.0:
		_drip_scan = 1.0
		_scan_eaves(centre)
	for id in _drip_eaves:
		var e: Dictionary = _drip_eaves[id]
		var pts: Array = e["pts"]
		var ts: Array = e["t"]
		for i in pts.size():
			ts[i] = float(ts[i]) - dt
			if float(ts[i]) <= 0.0:
				ts[i] = lerpf(3.2, 0.9, wetness) * _rng.randf_range(0.7, 1.3)
				_drop_from(pts[i], col)
	# Now and then off a tree near you.
	_drip_t -= dt
	if _drip_t > 0.0:
		return
	_drip_t = lerpf(1.6, 0.35, wetness) * _rng.randf_range(0.6, 1.4)
	var near: Array = []
	for t in get_tree().get_nodes_in_group("trees"):
		if t is Node3D:
			var tp := (t as Node3D).global_position
			if Vector2(tp.x - centre.x, tp.z - centre.z).length() < 10.0:
				near.append(tp)
	if not near.is_empty():
		var tp: Vector3 = near[_rng.randi() % near.size()]
		_drop_from(tp + Vector3(_rng.randf_range(-1.6, 1.6), _rng.randf_range(2.5, 4.5), _rng.randf_range(-1.6, 1.6)), col)


func _drop_from(from: Vector3, col: Color) -> void:
	for d in _drips:
		if not d["live"]:
			d["live"] = true
			d["v"] = 0.0
			var dr: Sprite3D = d["drop"]
			dr.global_position = from
			dr.modulate = col
			dr.visible = true
			return


## The buildings within reach, the four nearest; a building keeps its drips' beat while it
## stays near.
func _scan_eaves(centre: Vector3) -> void:
	var main := get_tree().current_scene
	var bm = main.get("building_manager") if main != null else null
	var structures: Node = bm.get_node_or_null("Structures") if bm != null else null
	var found: Array = []
	if structures != null:
		for c in structures.get_children():
			if not (c is Node3D) or str(c.get_meta("building_type", "")) == "":
				continue
			var cp := (c as Node3D).global_position
			var dd := Vector2(cp.x - centre.x, cp.z - centre.z).length()
			if dd < 16.0:
				found.append([dd, c])
	found.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var keep: Dictionary = {}
	for f in found:
		if keep.size() >= 4:
			break
		var s: Node3D = f[1]
		var id := s.get_instance_id()
		var pts := _eave_points(s)
		if pts.is_empty():
			continue
		if _drip_eaves.has(id) and (_drip_eaves[id]["pts"] as Array).size() == pts.size():
			keep[id] = _drip_eaves[id]
			keep[id]["pts"] = pts
			continue
		var ts: Array = []
		for i in pts.size():
			ts.append(_rng.randf_range(0.0, 2.0))
		keep[id] = {"pts": pts, "t": ts}
	_drip_eaves = keep


## Where the water gathers on a building's roof edge and drips off: a few spots along its
## eaves, just under them. A roof is whatever spans most of the building and starts high
## up; its eave is its lowest edge (a gable slab's outer edge, all four of a flat roof's).
## Kept on the building until it moves.
func _eave_points(s: Node3D) -> Array:
	if s.has_meta("drip_pts") and s.get_meta("drip_xf") == s.global_transform:
		return s.get_meta("drip_pts")
	var pts: Array = []
	var inv := s.global_transform.affine_inverse()
	var whole := AABB()
	var parts: Array = []
	for m in s.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var xf := inv * mi.global_transform
		var box: AABB = xf * mi.get_aabb()
		parts.append([mi, xf, box])
		whole = box if parts.size() == 1 else whole.merge(box)
	var edges: Array = []
	if whole.size.y >= 1.4 and whole.size.x >= 1.2 and whole.size.z >= 1.2:
		for pa in parts:
			var box: AABB = pa[2]
			if box.position.y < whole.position.y + whole.size.y * 0.4:
				continue
			if box.size.x < whole.size.x * 0.6 and box.size.z < whole.size.z * 0.6:
				continue
			# Flat sheets (a gable's end triangles) have no edge to drip from.
			var own: AABB = (pa[0] as MeshInstance3D).get_aabb()
			if minf(own.size.x, minf(own.size.y, own.size.z)) < 0.01:
				continue
			var low: Array = []
			var ymin := INF
			for k in 8:
				var c: Vector3 = (pa[1] as Transform3D) * own.get_endpoint(k)
				low.append(c)
				ymin = minf(ymin, c.y)
			low = low.filter(func(c): return c.y < ymin + 0.03)
			if low.size() == 2:
				edges.append([low[0], low[1]])
			elif low.size() == 4:
				var mid: Vector3 = (low[0] + low[1] + low[2] + low[3]) * 0.25
				low.sort_custom(func(a, b): return atan2(a.z - mid.z, a.x - mid.x) < atan2(b.z - mid.z, b.x - mid.x))
				for k in 4:
					edges.append([low[k], low[(k + 1) % 4]])
	for ed in edges:
		var a: Vector3 = ed[0] - Vector3(0, 0.03, 0)
		var b: Vector3 = ed[1] - Vector3(0, 0.03, 0)
		var n := maxi(1, int(a.distance_to(b) / 1.1))
		for i in n:
			if _rng.randf() < 0.35:
				pts.append(s.global_transform * a.lerp(b, (float(i) + _rng.randf_range(0.2, 0.8)) / float(n)))
	if pts.size() > 6:
		pts.shuffle()
		pts = pts.slice(0, 6)
	s.set_meta("drip_pts", pts)
	s.set_meta("drip_xf", s.global_transform)
	return pts
