extends Node

## The pipes' own life, and the small things that make you not want to be down there
## (DESIGN §8). The crawl (sewer_pipe_minigame.gd) owns the pipes, you and the clamp, the
## raccoon is pipe_director.gd; this is the rest:
##   breath    your breath smokes in the cold, in front of your face, faster as it winds
##             you up; dust and spores drift in the beam
##   water     a palm slapping into the trickle each pull; drops off the crown land on
##             your face (the view): they run down and are gone
##   surge     once a descent (more often the harder the night) the pipes fill: a rumble
##             far off, then the roar going past you, the trickle a torrent, the view
##             shaking; crawling, it pushes you back; then it drains away
##   chalk     C at a junction chalks an arrow by the pipe you face, to find your way
##             back; on the bad nights the raccoon gets at your marks: one wiped, one
##             turned round
##   places    a street grate in the crown of a junction or two: cold moonlight coming
##             down through it in stripes, drops falling through, the street (wind, rain,
##             a car far off) above you; steam rising off a warm pipe somewhere
##   sound     a pumping station throbbing far off through the concrete, water running
##             in other pipes, the pipes groaning as they settle, rats
##   scares    one at a time, apart: fresh little hand prints in blood on the wall ahead
##             that were not there; the red shoe further on than it was; something dropping
##             into the water just behind you when you stop; a drain gurgling; the light
##             at the ladder behind you going out for a while

const SFX := "res://assets/sfx/pipes/"
const HANDPRINT := "res://assets/textury/mess/decal_handprint.png"
const SHOE := "res://assets/textury/pipes/red_shoe.png"
const GRATE := "res://assets/textury/pipes/sewer_grate.png"

var host
var rng := RandomNumberGenerator.new()
var _level := 1
## Your breath: the same puffs as in the camp (scripts/ambient/player_breath.gd's shader,
## picture, size and life, stepped twelve a second), in the torch's light; soft round
## blobs here were another breath than the one outside (playtest 21. 10.).
const BREATH = preload("res://scripts/ambient/player_breath.gd")
var _puffs: Array = []              # {mesh, mat, t, vel}
var _puff_acc := 0.0
var _motes: GPUParticles3D
var _splash_fx: GPUParticles3D
var _breath_t := 0.0
var _drop_tex: ImageTexture
var _drops: Array = []              # {node, t, life, v}
var _lens_next := 12.0
var _surge_at := -1.0
var _surge_t := -1.0
var _surge_loud: AudioStreamPlayer
var _water_y := {}
var _chalk := {}                    # "x,y,d" -> Label3D
var _chalk_tex: ImageTexture
var _scare_next := 20.0
var _done := {}
var _t := 0.0
var _was_moving := false
var _amb: Array = []                # looping players, stopped when you climb out
var _groan_next := 20.0
var _rat_next := 12.0


func start(level: int, seed_value: int) -> void:
	rng.seed = seed_value
	_level = clampi(level, 1, 3)
	_t = 0.0
	_breath_t = 1.0
	_lens_next = rng.randf_range(6.0, 14.0)
	_scare_next = rng.randf_range(14.0, 26.0) / (1.0 + 0.3 * float(_level - 1))
	_done.clear()
	_chalk.clear()
	_clear_drops()
	_surge_t = -1.0
	# The surge: the bad nights for sure, the quiet ones only sometimes.
	_surge_at = rng.randf_range(30.0, 75.0) if (_level >= 2 or rng.randf() < 0.35) else -1.0
	_water_y.clear()
	for mi in host._water_meshes:
		if is_instance_valid(mi):
			_water_y[mi] = (mi as Node3D).position.y
	_build_fx()
	_build_ambience()


func stop() -> void:
	for a in _amb:
		if is_instance_valid(a):
			a.stop()
	_amb.clear()
	_clear_drops()
	if _surge_loud != null:
		_surge_loud.stop()
	_surge_t = -1.0


# ── per frame ─────────────────────────────────────────────────────────────────

func tick(dt: float) -> void:
	_t += dt
	_update_breath(dt)
	_update_drops(dt)
	_update_surge(dt)
	_update_scares(dt)
	_update_ambience(dt)
	_was_moving = host._moving


## A palm into the trickle: a little splash just ahead, now and then a drop on the view.
func on_pull(idx: int) -> void:
	if _splash_fx != null:
		var fwd := -(host._rig.global_transform.basis.z as Vector3)
		_splash_fx.global_position = host._rig.global_position + fwd * 0.45 + Vector3(0, -host.EYE_Y + 0.06, 0) + (host._rig.global_transform.basis.x as Vector3) * -0.12
		_splash_fx.restart()
		_splash_fx.emitting = true
	_sound("splash.mp3", -12.0, rng.randf_range(0.85, 1.1))
	if rng.randf() < 0.12:
		lens_drop()


# ── breath and dust ───────────────────────────────────────────────────────────

func _build_fx() -> void:
	if _puffs.is_empty() or not is_instance_valid(_puffs[0]["mesh"]):
		_puffs.clear()
		for i in 3:
			var mi := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(1.0, 1.0)
			mi.mesh = q
			var m := ShaderMaterial.new()
			m.shader = BREATH.PUFF_SHADER
			m.set_shader_parameter("seed", float(i) * 1.7)
			m.set_shader_parameter("puff", load(BREATH.PUFF_TEX))
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visible = false
			host._camera.add_child(mi)
			_puffs.append({"mesh": mi, "mat": m, "t": -1.0, "vel": Vector3.ZERO})
	if _motes == null:
		_motes = _particles(70, 7.0, Vector3(0, 0, 0), 180.0, Vector2(0.0, 0.03), Vector3(0, -0.005, 0), 0.01, Color(0.95, 0.92, 0.8, 0.5), true)
		var pm: ParticleProcessMaterial = _motes.process_material
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(0.35, 0.3, 1.4)
		_motes.local_coords = false
		_motes.preprocess = 4.0
		host._flashlight.add_child(_motes)
		_motes.position = Vector3(0, 0, -1.8)
	if _splash_fx == null:
		_splash_fx = _particles(12, 0.55, Vector3(0, 1, 0), 40.0, Vector2(0.6, 1.3), Vector3(0, -9.0, 0), 0.018, Color(0.62, 0.66, 0.58, 0.8), true)
		_splash_fx.one_shot = true
		_splash_fx.explosiveness = 0.9
		_splash_fx.local_coords = false
		host._geo.get_parent().add_child(_splash_fx)
	elif _splash_fx.get_parent() != host._geo.get_parent():
		_splash_fx.reparent(host._geo.get_parent())
	_motes.emitting = true


func _particles(amount: int, life: float, dir: Vector3, spread: float, vel: Vector2, gravity: Vector3, size: float, col: Color, shaded: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = dir if dir.length() > 0.0 else Vector3.UP
	pm.spread = spread
	pm.initial_velocity_min = vel.x
	pm.initial_velocity_max = vel.y
	pm.gravity = gravity
	pm.damping_min = 0.1
	pm.damping_max = 0.4
	pm.scale_min = 0.7
	pm.scale_max = 1.6
	p.process_material = pm
	# Soft round puffs that fade out, not squares.
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	pm.color_ramp = rt
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.albedo_texture = _soft_dot()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if shaded else BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = m
	p.draw_pass_1 = q
	p.amount = amount
	p.lifetime = life
	return p


var _dot: GradientTexture2D


func _soft_dot() -> GradientTexture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_dot = GradientTexture2D.new()
		_dot.gradient = g
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(1.0, 0.5)
		_dot.width = 16
		_dot.height = 16
	return _dot


## Your breath in the cold, in front of your face: faster and harder as it winds you up.
func _update_breath(dt: float) -> void:
	if _puffs.is_empty():
		return
	var tension: float = host._director.tension if host._director != null else 0.0
	_breath_t -= dt
	if _breath_t <= 0.0:
		_breath_t = lerpf(3.4, 1.3, tension) * rng.randf_range(0.85, 1.15)
		_puff(tension > 0.6)
	_puff_acc += dt
	if _puff_acc < 1.0 / BREATH.FPS:
		return
	var step := _puff_acc
	_puff_acc = 0.0
	# As bright as the light it is in: the torch's, else hardly there.
	var torch_on: bool = host._flashlight != null and host._flashlight.visible
	var light := 0.7 if torch_on else 0.08
	for p in _puffs:
		if float(p["t"]) < 0.0:
			continue
		p["t"] = float(p["t"]) + step
		var k := float(p["t"]) / BREATH.LIFE
		var mi: MeshInstance3D = p["mesh"]
		if k >= 1.0:
			p["t"] = -1.0
			mi.visible = false
			continue
		mi.position += (p["vel"] as Vector3) * step
		var size := lerpf(BREATH.SIZE_FROM, BREATH.SIZE_TO, k)
		mi.scale = Vector3(size, size, size)
		(p["mat"] as ShaderMaterial).set_shader_parameter("fade", (1.0 - k) * 0.8)
		(p["mat"] as ShaderMaterial).set_shader_parameter("light", light)


func _puff(hard: bool) -> void:
	for p in _puffs:
		if float(p["t"]) >= 0.0:
			continue
		var mi: MeshInstance3D = p["mesh"]
		mi.position = Vector3(rng.randf_range(-0.04, 0.04), -0.22, -0.6)
		# No wind down here: up into the crown, slowly, a little forward.
		p["vel"] = Vector3(rng.randf_range(-0.05, 0.05), 0.14, -0.3 if not hard else -0.45)
		p["t"] = 0.0
		mi.scale = Vector3.ONE * BREATH.SIZE_FROM
		(p["mat"] as ShaderMaterial).set_shader_parameter("seed", rng.randf() * 10.0)
		(p["mat"] as ShaderMaterial).set_shader_parameter("fade", 0.8)
		mi.visible = true
		return


# ── places and sound ─────────────────────────────────────────────────────────

## This network's grates, steam and far sounds (its own dice off the pipes', so the same
## breakdown has them in the same places).
func _build_ambience() -> void:
	_amb.clear()
	var r := RandomNumberGenerator.new()
	r.seed = rng.seed + 77
	var nodes: Array = host._links.keys().filter(func(c): return c != host._entry)
	for i in range(nodes.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var t = nodes[i]
		nodes[i] = nodes[j]
		nodes[j] = t
	var k := 0
	for _i in r.randi_range(1, 3):
		if k < nodes.size():
			_grate(nodes[k], r)
			k += 1
	for _i in r.randi_range(1, 2):
		if k < nodes.size():
			_steam(nodes[k], r)
			k += 1
	# Far off, the pumping station; nearer, water running in other pipes.
	var far: Vector2i = _far_node(4)
	_amb.append(_loop_at("pump.mp3", host._world_pos(far), -18.0, 60.0))
	for _i in 2:
		if k < nodes.size():
			_amb.append(_loop_at("flow.mp3", host._world_pos(nodes[k]), -10.0, 11.0))
			k += 1
	_groan_next = rng.randf_range(10.0, 25.0)
	_rat_next = rng.randf_range(6.0, 16.0)


func _crown_y() -> float:
	return host.ARM_R * 0.9 + host.ARM_R * 0.97


const RAIN_STREAK := "res://assets/textury/world/rain_streak.png"


## A street grate in the junction's crown: moonlight in stripes, drops, the street above.
func _grate(c: Vector2i, r: RandomNumberGenerator) -> void:
	var p: Vector3 = host._world_pos(c)
	var top := _crown_y()
	if ResourceLoader.exists(GRATE):
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.62, 0.62)
		q.orientation = PlaneMesh.FACE_Y
		mi.mesh = q
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(GRATE)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		# Round as the grate is (the picture's square round it is cut away), and only the
		# slots glow with what comes through them: the whole square glowed, a blue
		# rectangle on the crown (playtest 25. 10.).
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.emission_enabled = true
		m.emission = Color(0.7, 0.8, 1.0)
		m.emission_energy_multiplier = 1.0
		m.emission_texture = m.albedo_texture
		m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		mi.material_override = m
		mi.position = Vector3(p.x, top - 0.02, p.z)
		mi.rotation.y = r.randf_range(0.0, TAU)
		host._geo.add_child(mi)
	var moon := SpotLight3D.new()
	moon.light_color = Color(0.55, 0.62, 0.78)
	moon.light_energy = 1.3
	moon.spot_range = 3.2
	moon.spot_angle = 20.0
	moon.spot_attenuation = 1.2
	moon.shadow_enabled = false
	host._geo.add_child(moon)
	moon.position = Vector3(p.x, top + 0.3, p.z)
	moon.rotation = Vector3(-PI * 0.5, 0, 0)
	var drops := _particles(10, 0.55, Vector3(0, -1, 0), 4.0, Vector2(0.2, 0.6), Vector3(0, -9.0, 0), 0.012, Color(0.7, 0.76, 0.85, 0.7), true)
	drops.local_coords = false
	var pm: ParticleProcessMaterial = drops.process_material
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.22, 0.01, 0.22)
	# Falling streaks of water as the rain's are drawn (they were little blue squares on
	# the crown: playtest 21. 10.), grey, seen only in the light.
	pm.particle_flag_align_y = true
	pm.scale_min = 1.0
	pm.scale_max = 1.0
	var streak := QuadMesh.new()
	streak.size = Vector2(0.012, 0.11)
	var sm := StandardMaterial3D.new()
	if ResourceLoader.exists(RAIN_STREAK):
		sm.albedo_texture = load(RAIN_STREAK)
	sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	sm.vertex_color_use_as_albedo = true
	sm.albedo_color = Color(0.62, 0.64, 0.66, 0.55)
	streak.material = sm
	drops.draw_pass_1 = streak
	host._geo.add_child(drops)
	drops.position = Vector3(p.x, top - 0.05, p.z)
	drops.emitting = true
	_amb.append(_loop_at("street.mp3", Vector3(p.x, top, p.z), -8.0, 9.0))


## Steam off a warm pipe, rising slowly in the dark (you see it in the torch).
func _steam(c: Vector2i, r: RandomNumberGenerator) -> void:
	var p: Vector3 = host._world_pos(c)
	var st := _particles(18, 3.2, Vector3(0, 1, 0), 18.0, Vector2(0.05, 0.14), Vector3(0, 0.04, 0), 0.28, Color(0.75, 0.75, 0.72, 0.07), true)
	st.local_coords = false
	var pm: ParticleProcessMaterial = st.process_material
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.12, 0.02, 0.12)
	host._geo.add_child(st)
	var a := r.randf_range(0.0, TAU)
	st.position = Vector3(p.x, 0.05, p.z) + Vector3(cos(a), 0, sin(a)) * host.ARM_R * 0.55
	st.emitting = true


func _loop_at(file: String, at: Vector3, db: float, reach: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = host.audio_bus()
	if ResourceLoader.exists(SFX + file):
		var stream = load(SFX + file)
		if stream is AudioStreamMP3:
			stream = (stream as AudioStreamMP3).duplicate()
			stream.loop = true
		p.stream = stream
	p.volume_db = db
	p.max_distance = reach
	p.unit_size = 3.0
	host._geo.add_child(p)
	p.global_position = at
	p.play()
	return p


## The pipes settling and the rats, now and then, somewhere off.
func _update_ambience(dt: float) -> void:
	_groan_next -= dt
	if _groan_next <= 0.0:
		_groan_next = rng.randf_range(15.0, 35.0)
		_sound_at("groan.mp3", host._world_pos(_far_node(2)), -4.0)
	_rat_next -= dt
	if _rat_next <= 0.0:
		_rat_next = rng.randf_range(10.0, 25.0)
		_sound_at("rat.mp3", host._world_pos(_far_node(1)), -10.0)


# ── drops on the view ─────────────────────────────────────────────────────────

## A cold drop off the crown, on your face: it runs down the view and is gone.
func lens_drop() -> void:
	if _drop_tex == null:
		_drop_tex = _make_drop()
	var vp: Vector2 = host.get_viewport().get_visible_rect().size
	var r := TextureRect.new()
	r.texture = _drop_tex
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var k := float(maxi(2, int(round(vp.y / 240.0))))
	var s := k * rng.randf_range(1.5, 3.0)
	r.size = Vector2(6.0, 9.0) * s
	r.position = Vector2(rng.randf_range(0.08, 0.92) * vp.x, rng.randf_range(0.0, 0.45) * vp.y).floor()
	host._root.add_child(r)
	host._root.move_child(r, 1)
	_drops.append({"node": r, "t": 0.0, "life": rng.randf_range(2.0, 3.5), "v": rng.randf_range(6.0, 22.0) * k})
	_sound("lensdrop.mp3", -12.0, rng.randf_range(0.9, 1.2))


func _make_drop() -> ImageTexture:
	var img := Image.create(6, 9, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 9:
		for x in 6:
			var dx := (float(x) - 2.5) / 2.6
			var dy := (float(y) - 5.0) / 4.0
			if dx * dx + dy * dy * (1.0 if y > 4 else 2.2) <= 1.0:
				var lit := 0.55 + 0.35 * (1.0 - absf(dx))
				img.set_pixel(x, y, Color(0.75 * lit, 0.78 * lit, 0.72 * lit, 0.42))
	img.set_pixel(2, 4, Color(1, 1, 0.95, 0.75))
	return ImageTexture.create_from_image(img)


func _update_drops(dt: float) -> void:
	_lens_next -= dt
	if _lens_next <= 0.0 and host._intro_t < 0.0:
		_lens_next = rng.randf_range(8.0, 22.0) * (0.4 if _surge_t >= 0.0 else 1.0)
		lens_drop()
	for i in range(_drops.size() - 1, -1, -1):
		var d: Dictionary = _drops[i]
		d["t"] = float(d["t"]) + dt
		var r: TextureRect = d["node"]
		if not is_instance_valid(r):
			_drops.remove_at(i)
			continue
		# It hangs a moment, then runs, stretching.
		if float(d["t"]) > 0.4:
			r.position.y += float(d["v"]) * dt
			r.size.y += float(d["v"]) * dt * 0.25
		r.modulate.a = clampf((float(d["life"]) - float(d["t"])) / 1.2, 0.0, 1.0)
		if float(d["t"]) >= float(d["life"]):
			r.queue_free()
			_drops.remove_at(i)


func _clear_drops() -> void:
	for d in _drops:
		if is_instance_valid(d["node"]):
			(d["node"] as Node).queue_free()
	_drops.clear()


# ── the surge ────────────────────────────────────────────────────────────────

## Far off a rumble; then the roar comes past you in the pipe, the trickle a torrent, the
## view shaking and drops all over it; crawling, it shoves you back; then it drains.
func _update_surge(dt: float) -> void:
	if _surge_at > 0.0 and _surge_t < 0.0 and _t >= _surge_at and host._intro_t < 0.0:
		_surge_t = 0.0
		_surge_at = -1.0
		_sound("gurgle.mp3", -6.0, 0.8)
		if _surge_loud == null:
			_surge_loud = AudioStreamPlayer.new()
			_surge_loud.bus = host.audio_bus()
			if ResourceLoader.exists(SFX + "surge.mp3"):
				_surge_loud.stream = load(SFX + "surge.mp3")
			host.add_child(_surge_loud)
		_surge_loud.volume_db = -4.0
		_surge_loud.play()
	if _surge_t < 0.0:
		return
	_surge_t += dt
	var t := _surge_t
	# 0-1.6 coming, 1.6-4.2 here, 4.2-6 going.
	var here := clampf((t - 1.2) / 0.6, 0.0, 1.0) * clampf((5.6 - t) / 1.4, 0.0, 1.0)
	for mi in _water_y:
		if is_instance_valid(mi):
			(mi as Node3D).position.y = float(_water_y[mi]) + 0.12 * here
	for m in host._water_mats:
		(m as ShaderMaterial).set_shader_parameter("speed", lerpf(0.5, 3.2, here))
		(m as ShaderMaterial).set_shader_parameter("strength", lerpf(0.6, 1.0, here))
	if here > 0.4:
		if rng.randf() < dt * 6.0:
			host._bump_t = 0.0
		if rng.randf() < dt * 3.0:
			lens_drop()
		if host._director != null:
			host._director.flicker = maxf(host._director.flicker, 0.4 * here)
		# Crawling into it: shoved back.
		if host._moving and not host._stuck:
			host._move_t = maxf(0.0, host._move_t - dt / host._move_secs * 1.3)
	if t >= 6.2:
		_surge_t = -1.0
		for mi in _water_y:
			if is_instance_valid(mi):
				(mi as Node3D).position.y = float(_water_y[mi])


# ── chalk ─────────────────────────────────────────────────────────────────────

## C at a junction: an arrow in chalk on the wall beside the pipe you face (again: wiped).
func chalk() -> void:
	if host._moving or host._turning or host._intro_t >= 0.0 or not host._links[host._node].has(host._facing):
		return
	var key := "%d,%d,%d" % [host._node.x, host._node.y, host._facing]
	_sound("chalk.mp3", -2.0, rng.randf_range(0.92, 1.08))
	if _chalk.has(key):
		var old = _chalk[key]
		if is_instance_valid(old):
			old.queue_free()
		_chalk.erase(key)
		return
	var l := Label3D.new()
	l.text = "->"
	l.font = host.RETRO_UI.FONT_BIG
	l.font_size = 32
	l.pixel_size = 0.004
	l.modulate = Color(0.88, 0.88, 0.82, 0.9)
	l.outline_size = 0
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.shaded = true
	var c: Vector3 = host._world_pos(host._node)
	var fwd := Vector3(float(host.DIRS[host._facing].x), 0, float(host.DIRS[host._facing].y))
	var right := Vector3(-fwd.z, 0, fwd.x)
	var wall: float = host.ARM_R * 1.12 * 0.9
	# On the drum's wall a little to the right of the pipe's mouth, at eye height,
	# pointing into it.
	l.position = Vector3(c.x, host.EYE_Y + 0.05, c.z) + (fwd * 0.55 + right * 0.83).normalized() * wall
	host._geo.add_child(l)
	l.look_at(Vector3(c.x, l.position.y, c.z), Vector3.UP)
	l.rotate_object_local(Vector3.UP, PI)
	_chalk[key] = l


## The raccoon at your marks (bad nights): one wiped off, or one turned the other way.
func _tamper_chalk() -> bool:
	if _chalk.is_empty():
		return false
	var keys := _chalk.keys()
	var key: String = keys[rng.randi() % keys.size()]
	var parts := key.split(",")
	if Vector2i(int(parts[0]), int(parts[1])) == host._node:
		return false
	var l = _chalk[key]
	if not is_instance_valid(l):
		return false
	if rng.randf() < 0.5:
		l.text = "<-"
	else:
		l.text = "~~"
		l.modulate = Color(0.5, 0.2, 0.18, 0.8)
	return true


# ── scares ────────────────────────────────────────────────────────────────────

func _update_scares(dt: float) -> void:
	if host._intro_t >= 0.0 or host._caught_t >= 0.0:
		return
	# Stopping: now and then something drops into the water just behind you.
	if _was_moving and not host._moving and rng.randf() < 0.12 * float(_level):
		_sound_behind("wetdrop.mp3", -3.0)
	_scare_next -= dt
	if _scare_next > 0.0:
		return
	_scare_next = rng.randf_range(16.0, 34.0) / (1.0 + 0.3 * float(_level - 1))
	var pool := ["gurgle", "drop"]
	for k in ["prints", "shoe", "ladder"]:
		if not _done.has(k):
			pool.append(k)
	if _level >= 2 and not _done.has("chalk"):
		pool.append("chalk")
	pool.shuffle()
	for k in pool:
		if _scare(k):
			_done[k] = true
			return


func _scare(k: String) -> bool:
	match k:
		"gurgle":
			_sound_at("gurgle.mp3", host._world_pos(_far_node(2)), -2.0)
			return true
		"drop":
			_sound_behind("wetdrop.mp3", 0.0)
			return true
		"prints":
			return _fresh_prints()
		"shoe":
			return _move_shoe()
		"ladder":
			return _ladder_dark()
		"chalk":
			return _tamper_chalk()
	return false


## Little hand prints in fresh blood on the wall of the junction ahead, not there before.
func _fresh_prints() -> bool:
	var ahead: Array = host._director._line_ahead() if host._director != null else []
	if ahead.size() < 1 or not ResourceLoader.exists(HANDPRINT):
		return false
	var j: Vector2i = ahead[mini(1, ahead.size() - 1)]
	var c: Vector3 = host._world_pos(j)
	var tex: Texture2D = load(HANDPRINT)
	for i in 3:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.11, 0.11)
		mi.mesh = q
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.albedo_color = Color(0.7, 0.08, 0.06)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.roughness = 0.15
		mi.material_override = m
		var ang := rng.randf_range(0.0, TAU)
		var dir := Vector3(cos(ang), 0, sin(ang))
		mi.position = Vector3(c.x, host.EYE_Y - 0.1 + 0.18 * float(i), c.z) + dir * (host.ARM_R * 1.12 * 0.92)
		host._geo.add_child(mi)
		mi.look_at(Vector3(c.x, mi.position.y, c.z), Vector3.UP)
		mi.rotate_object_local(Vector3.UP, PI)
		mi.rotate_object_local(Vector3.FORWARD, rng.randf_range(-0.6, 0.6))
	return true


## The red shoe: further on than it was, in a pipe ahead of you.
func _move_shoe() -> bool:
	var shoe: Node3D = null
	for n in host._geo.get_children():
		if n is Sprite3D and (n as Sprite3D).texture != null and (n as Sprite3D).texture.resource_path == SHOE:
			shoe = n
			break
	if shoe == null:
		return false
	var ahead: Array = host._director._line_ahead() if host._director != null else []
	if ahead.size() < 2:
		return false
	var p: Vector3 = (host._world_pos(ahead[0]) + host._world_pos(ahead[1])) * 0.5
	shoe.global_position = Vector3(p.x, shoe.global_position.y, p.z)
	return true


## The one light down here, at the ladder behind you, goes out for a while.
func _ladder_dark() -> bool:
	for n in host._geo.get_children():
		if n is OmniLight3D and (n as OmniLight3D).visible:
			var l: OmniLight3D = n
			if l.global_position.distance_to(host._rig.global_position) < 4.0:
				return false
			l.visible = false
			get_tree().create_timer(rng.randf_range(6.0, 12.0)).timeout.connect(func():
				if is_instance_valid(l):
					l.visible = true
			)
			_sound_at("gurgle.mp3", l.global_position, -10.0)
			return true
	return false


# ── helpers ───────────────────────────────────────────────────────────────────

func _far_node(at_least: int) -> Vector2i:
	var dist: Dictionary = host._distances_from(host._node)
	var cands: Array = []
	for c in dist.keys():
		if int(dist[c]) >= at_least:
			cands.append(c)
	return cands[rng.randi() % cands.size()] if not cands.is_empty() else host._node


func _sound(file: String, db: float, pitch: float = 1.0) -> void:
	if not ResourceLoader.exists(SFX + file):
		return
	var p := AudioStreamPlayer.new()
	p.bus = host.audio_bus()
	p.stream = load(SFX + file)
	p.volume_db = db
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _sound_at(file: String, at: Vector3, db: float) -> void:
	if not ResourceLoader.exists(SFX + file):
		return
	var p := AudioStreamPlayer3D.new()
	p.bus = host.audio_bus()
	p.stream = load(SFX + file)
	p.volume_db = db
	p.max_distance = 24.0
	p.unit_size = 4.0
	host._geo.add_child(p)
	p.global_position = at
	p.play()
	p.finished.connect(p.queue_free)


func _sound_behind(file: String, db: float) -> void:
	var back := (host._rig.global_transform.basis.z as Vector3)
	_sound_at(file, host._rig.global_position + back * 1.2 + Vector3(0, -0.3, 0), db)
