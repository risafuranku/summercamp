extends Node

## The camp's rowing boat as everybody sees and hears it (camp_lake.gd ties it up by the
## jetty, lake_trip.gd rows it). The user, 21. 10.: "totálně polishnout lodičku, single i
## coop".
##   - The hull rides the lake's swell (more in a wind, a lot in a storm), heels into a
##     turn, lifts its bow on a stroke, dips when someone steps in and is knocked about
##     by what happens to it (kick; the night's lurches). The boat's own node keeps only
##     where it is and which way it points: that is what goes over co-op; each machine
##     rocks its own hull.
##   - The oars (rowboat_oar) lie in along the thwarts while nobody rows, are shipped in
##     the rowlocks when somebody sits down to them and pulled stroke by stroke: in at
##     the catch with the blade squared, pushed through the water, out at the release and
##     feathered flat on the way back. You row facing the bow, as the game always had it:
##     pushing the grips forward drives the boat on, pulling them backs water.
##   - The water round them: a splash where a blade goes in, the swirl each blade leaves
##     behind it in the water, drips off the blade on the way back, rings off the stern
##     while the boat makes way. Stepped twelve times a second, like the lake's own rings.
##   - The storm lantern on the fore thwart after dark while the boat is out.
##   - Its sounds where it is: the stroke, the rush along the hull, the drips, the creak.
## What drives the oars is their phase (set_oar), yours or the other warden's sent over
## co-op, and the boat's motion (set_motion): one boat, the same on every machine.

const INTERIOR_KIT = preload("res://scripts/interior_kit.gd")
const SFX := "res://assets/sfx/lake/"
const DROP_TEX := "res://assets/textury/world/water_drop.png"
const BUS := "OutdoorAmbience"

## Where things are in the hull's own space (+Z the bow, metres; props_more.py rowboat).
## The lake's surface lies at WATERLINE when the swell is still.
const WATERLINE := 0.12
## The left rowlock (the boat's +X, the rower's left hand); the right one is mirrored.
const ROWLOCK := Vector3(0.475, 0.55, -0.547)
## The oar's own space (rowboat_oar: the grip at -X, the blade at +X): where it hangs in
## the rowlock, the middle of its blade and its tip.
const OAR_PIVOT := Vector3(-0.475, 0.024, 0.0)
const OAR_BLADE := Vector3(0.785, 0.024, 0.0)
const OAR_TIP := Vector3(0.975, 0.024, 0.0)
## Laid in along the thwarts, a hand's breadth either side of the middle, blades forward.
const LAID := Vector3(0.2, 0.335, -0.75)
## The seats: the rower on the aft thwart facing the bow, a second one on the bow seat
## facing the rower. Eyes for the cameras, feet for the figures (coop/remote_player.gd).
const ROWER_EYE := Vector3(0.0, 1.06, -0.84)
const ROWER_FEET := Vector3(0.0, 0.1, -0.6)
const BOW_EYE := Vector3(0.0, 0.98, 0.74)
const BOW_FEET := Vector3(0.0, 0.08, 0.86)
## The storm lantern hangs from the stem post, lighting the way over the bow.
const LANTERN_AT := Vector3(0.0, 0.25, 1.33)

## One stroke of one oar, as shares of its period: the blade goes in at 0, is pushed
## through the water till RELEASE, comes out and swings back to the catch.
const PERIOD := 1.2
const RELEASE := 0.42
const RECOVER := 0.5
## The sweep (degrees, + toward the bow) at the catch, at the finish and at rest; how
## far down the oar slopes with the blade in the water, out of it, and lying on it.
const SWEEP_CATCH := 34.0
const SWEEP_FINISH := -30.0
const SWEEP_REST := -8.0
const DIP_IN := 22.0
const DIP_OUT := 13.5
const DIP_REST := 18.5
## Effects and the hands are drawn in steps, twelve a second (the lake's rings ten).
const FX_FPS := 12.0

var hull: Node3D
var lake: Node3D
var _boat: Node3D
## Per side (0: the left oar, +X; 1: the right, -X): its pivot node, the pose it is in now
## {sweep, dip, feather}, its stroke phase (< 0 at rest) and direction.
var _oars: Array = []
var _shipped := 0.0
var _ship_target := 0.0
var _lantern_light: OmniLight3D
var _glass: StandardMaterial3D
var _lantern_on := 0.0
var _lantern_want := false
var _t := 0.0
var _fx_acc := 0.0
## The boat's motion as whoever moves it says: speed along the bow (m/s), turning (rad/s),
## its surge (m/s^2).
var _speed := 0.0
var _yaw_rate := 0.0
var _accel := 0.0
## The hull's rocking: roll, pitch and heave with their springs.
var _roll := 0.0
var _roll_v := 0.0
var _pitch := 0.0
var _pitch_v := 0.0
var _heave := 0.0
var _heave_v := 0.0
var _rings: Array = []    # {node, t, life, s0, s1, a}
var _drops: Array = []    # {node, v}
var _wake_t := 0.0
var _drip_t := 0.0
var _creak_t := 4.0
var _stroke_snd_at := -10.0
var _drip_snd_at := -10.0
var _rush: AudioStreamPlayer3D
var _players: Array = []
var _next_player := 0
var _rng := RandomNumberGenerator.new()
var _drop_mat: StandardMaterial3D
var _ring_mats := {}

static var _ring_tex: ImageTexture
static var _swirl_tex: ImageTexture


## Builds the rig on `boat` (the rowboat prop camp_lake.gd made): its mesh into a hull that
## rocks, the oars, the lantern, the sounds.
func setup(boat: Node3D, p_lake: Node3D) -> void:
	name = "BoatRig"
	_boat = boat
	lake = p_lake
	_rng.randomize()
	hull = Node3D.new()
	hull.name = "Hull"
	var parts := boat.get_children()
	boat.add_child(hull)
	for c in parts:
		if c != self:
			c.reparent(hull, false)
	for side in 2:
		var pivot := Node3D.new()
		pivot.name = "Oar%d" % side
		hull.add_child(pivot)
		var oar := INTERIOR_KIT.prop(pivot, "rowboat_oar", -OAR_PIVOT)
		_oars.append({"pivot": pivot, "mesh": oar, "sweep": SWEEP_REST, "dip": DIP_REST, "feather": 0.0,
			"u": -1.0, "dir": 1, "was": -1.0})
	var lantern := INTERIOR_KIT.prop(hull, "lantern", LANTERN_AT, 0.0)
	if lantern != null:
		lantern.name = "Lantern"
		# Its glass glows when it burns: the boat's own copy of the shared material.
		for mi in lantern.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (mi as MeshInstance3D).mesh
			for i in mesh.get_surface_count():
				var src := mesh.surface_get_material(i)
				var cur := (mi as MeshInstance3D).get_surface_override_material(i) as StandardMaterial3D
				if src != null and src.resource_name == "lantern_glass" and cur != null:
					_glass = cur.duplicate() as StandardMaterial3D
					(mi as MeshInstance3D).set_surface_override_material(i, _glass)
	_lantern_light = OmniLight3D.new()
	_lantern_light.name = "LanternLight"
	_lantern_light.light_color = Color(1.0, 0.7, 0.38)
	_lantern_light.light_energy = 0.0
	_lantern_light.omni_range = 8.0
	_lantern_light.omni_attenuation = 1.2
	_lantern_light.shadow_enabled = false
	# A little above it and in from the bow: its light falls into the whole boat.
	_lantern_light.position = LANTERN_AT + Vector3(0.0, 0.42, -0.25)
	_lantern_light.visible = false
	hull.add_child(_lantern_light)
	_rush = _player3d(SFX + "rush.mp3", true)
	if _rush.stream == null:
		_rush.stream = _loop_of(SFX + "lap.mp3")
	_rush.volume_db = -80.0
	for i in 3:
		_players.append(_player3d("", false))
	_drop_mat = StandardMaterial3D.new()
	_drop_mat.albedo_texture = load(DROP_TEX) if ResourceLoader.exists(DROP_TEX) else null
	_drop_mat.albedo_color = Color(0.82, 0.88, 0.92)
	_drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_drop_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_drop_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_drop_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_pose_oars(0.0, true)


# ── what drives it ────────────────────────────────────────────────────────────

## Somebody sits at the oars (they are shipped in the rowlocks) or nobody does (laid in).
## `at_once`: no swing from one to the other (a boat that is simply there).
func set_manned(on: bool, at_once := false) -> void:
	_ship_target = 1.0 if on else 0.0
	if at_once:
		_shipped = _ship_target
		_pose_oars(0.0, true)
	if not on:
		for o in _oars:
			o["u"] = -1.0


func is_manned() -> bool:
	return _ship_target > 0.5


## One oar's stroke: `side` 0 the left (+X), 1 the right; `u` its phase (0..1, < 0 at
## rest on the water); `dir` 1 driving the boat on, -1 backing water.
func set_oar(side: int, u: float, dir: int) -> void:
	var o: Dictionary = _oars[side]
	o["u"] = u
	o["dir"] = dir


## The boat's motion: speed along the bow (m/s), its turn (rad/s), its surge (m/s^2).
func set_motion(speed: float, yaw_rate: float, accel: float) -> void:
	_speed = speed
	_yaw_rate = yaw_rate
	_accel = accel


## A knock to the hull: roll (+ to the left), pitch (+ bow down), heave (+ up), as
## velocities. Someone stepping in, the night's lurches, a bump on the shore.
func kick(roll: float, pitch := 0.0, heave := 0.0) -> void:
	_roll_v += roll
	_pitch_v += pitch
	_heave_v += heave


func set_lantern(on: bool) -> void:
	_lantern_want = on


func lantern_is_on() -> bool:
	return _lantern_want


## Where the blade of `side` is (world), and whether it is in the water.
func blade_at(side: int) -> Vector3:
	var o: Dictionary = _oars[side]
	var mesh = o["mesh"]
	if mesh == null:
		return hull.global_position
	return (mesh as Node3D).global_transform * OAR_BLADE


## The seats in the world (the hull rocks them): for the cameras and the figures.
func seat_xf(local: Vector3) -> Transform3D:
	return hull.global_transform * Transform3D(Basis(), local)


# ── every frame ───────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if hull == null or not is_instance_valid(hull):
		return
	var dt := clampf(delta, 0.0, 0.1)
	_t += dt
	_rock(dt)
	_shipped = move_toward(_shipped, _ship_target, dt / 0.55)
	_pose_oars(dt, false)
	_events(dt)
	_tick_lantern(dt)
	_tick_sound(dt)
	_fx_acc += dt
	if _fx_acc >= 1.0 / FX_FPS:
		_tick_fx(_fx_acc)
		_fx_acc = 0.0


## The swell (by the wind), the heel into a turn, the bow lifting on a stroke, and the
## knocks dying away; the hull's transform under the boat's own.
func _rock(dt: float) -> void:
	var main = lake.get("_main") if lake != null else null
	var wv = main.get("_weather_visuals") if main != null else null
	var wind := clampf(float(wv.get("_wind_now")) if wv != null and wv.get("_wind_now") != null else 0.15, 0.0, 1.8)
	var a_roll := 0.006 + 0.02 * wind
	var a_pitch := 0.004 + 0.014 * wind
	var a_heave := 0.006 + 0.028 * wind
	var wave_roll := a_roll * (sin(_t * 0.93) + 0.5 * sin(_t * 1.71 + 1.3))
	var wave_pitch := a_pitch * (sin(_t * 1.12 + 0.4) + 0.4 * sin(_t * 2.31))
	var wave_heave := a_heave * (sin(_t * 1.37) + 0.35 * sin(_t * 2.9 + 2.0))
	var heel := clampf(_yaw_rate * absf(_speed) * 0.05 + _yaw_rate * 0.02, -0.07, 0.07)
	var surge := -clampf(_accel * 0.011, -0.035, 0.035)
	# Springs: a wobble or two, then still.
	_roll_v += (-24.0 * (_roll - heel) - 4.2 * _roll_v) * dt
	_roll += _roll_v * dt
	_pitch_v += (-28.0 * (_pitch - surge) - 5.0 * _pitch_v) * dt
	_pitch += _pitch_v * dt
	_heave_v += (-30.0 * _heave - 5.5 * _heave_v) * dt
	_heave += _heave_v * dt
	hull.transform = Transform3D(Basis.from_euler(Vector3(_pitch + wave_pitch, 0.0, _roll + wave_roll)),
		Vector3(0.0, _heave + wave_heave, 0.0))


## The pose a stroke phase asks of an oar: {sweep, dip, feather} (degrees).
static func stroke_pose(u: float, dir: int) -> Vector3:
	if u < 0.0:
		return Vector3(SWEEP_REST, DIP_REST, 0.0)
	var catch_sweep := SWEEP_CATCH if dir >= 0 else SWEEP_FINISH
	var finish_sweep := SWEEP_FINISH if dir >= 0 else SWEEP_CATCH
	if u < RELEASE:
		# Through the water, the blade squared; it goes in over the first part.
		var t := u / RELEASE
		var dip := lerpf(DIP_OUT, DIP_IN, smoothstep(0.0, 0.12, t))
		return Vector3(lerpf(catch_sweep, finish_sweep, smoothstep(0.0, 1.0, t)), dip, 90.0)
	if u < RECOVER:
		# Out of the water and turned flat.
		var t2 := (u - RELEASE) / (RECOVER - RELEASE)
		return Vector3(finish_sweep, lerpf(DIP_IN, DIP_OUT, smoothstep(0.0, 1.0, t2)), lerpf(90.0, 0.0, t2))
	# Back over the water, feathered, squared again just before the catch.
	var t3 := (u - RECOVER) / (1.0 - RECOVER)
	var feather := lerpf(0.0, 90.0, smoothstep(0.82, 1.0, t3))
	return Vector3(lerpf(finish_sweep, catch_sweep, smoothstep(0.0, 1.0, t3)), DIP_OUT, feather)


func _pose_oars(dt: float, snap: bool) -> void:
	var k := 1.0 if snap else 1.0 - exp(-20.0 * dt)
	for side in 2:
		var o: Dictionary = _oars[side]
		var want := stroke_pose(float(o["u"]), int(o["dir"]))
		o["sweep"] = lerpf(float(o["sweep"]), want.x, k)
		o["dip"] = lerpf(float(o["dip"]), want.y, k)
		o["feather"] = lerpf(float(o["feather"]), want.z, k)
		var s := 1.0 if side == 0 else -1.0
		var shipped := _shipped_xf(s, float(o["sweep"]), float(o["dip"]), float(o["feather"]))
		var laid := Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(LAID.x * s, LAID.y, LAID.z))
		var f := smoothstep(0.0, 1.0, _shipped)
		var q := laid.basis.get_rotation_quaternion().slerp(shipped.basis.get_rotation_quaternion(), f)
		(o["pivot"] as Node3D).transform = Transform3D(Basis(q), laid.origin.lerp(shipped.origin, f))


## An oar in its rowlock on side `s` (1 the boat's +X): swept `sweep` degrees toward the
## bow, sloping `dip` degrees down to the blade, the blade turned `feather` degrees from
## flat (90: squared, upright in the water).
static func _shipped_xf(s: float, sweep: float, dip: float, feather: float) -> Transform3D:
	var sw := deg_to_rad(sweep)
	var dp := deg_to_rad(dip)
	var x := Vector3(s * cos(dp) * cos(sw), -sin(dp), cos(dp) * sin(sw)).normalized()
	var y0 := (Vector3.UP - x * x.dot(Vector3.UP)).normalized()
	var z0 := x.cross(y0)
	var fe := deg_to_rad(feather)
	var y := y0 * cos(fe) + z0 * sin(fe)
	var z := x.cross(y)
	return Transform3D(Basis(x, y, z), Vector3(ROWLOCK.x * s, ROWLOCK.y, ROWLOCK.z))


## The water as the blades go in and come out: splashes, swirls, drips; the stroke's sound.
func _events(dt: float) -> void:
	if _shipped < 0.9:
		for o in _oars:
			o["was"] = float(o["u"])
		return
	for side in 2:
		var o: Dictionary = _oars[side]
		var u := float(o["u"])
		var was := float(o["was"])
		o["was"] = u
		if u < 0.0:
			continue
		var into := (was < 0.0 or was > 0.9) and u < 0.3
		var out := was >= 0.0 and was < RELEASE and u >= RELEASE
		var water := _on_water(blade_at(side))
		if into:
			_splash(water, 7)
			_ring(water, 0.2, 0.75, 0.6, 0.6, false)
			if _t - _stroke_snd_at > 0.2:
				_stroke_snd_at = _t
				_play(SFX + "stroke.mp3", -6.0, _rng.randf_range(0.92, 1.06))
		elif out:
			# The swirl the blade leaves where it came out: it stays as the boat goes on.
			_ring(water, 0.22, 0.62, 2.8, 0.75, true)
			_ring(water, 0.12, 0.4, 1.4, 0.5, false)
		elif was < RECOVER and u >= RECOVER:
			# Off the blade on the way back.
			if _t - _drip_snd_at > 0.3:
				_drip_snd_at = _t
				_play(SFX + "drip.mp3", _rng.randf_range(-15.0, -10.0), _rng.randf_range(0.9, 1.15))
		elif u > RECOVER and u < 0.8:
			_drip_t -= dt
			if _drip_t <= 0.0:
				_drip_t = _rng.randf_range(0.05, 0.11)
				var tip: Vector3 = (o["mesh"] as Node3D).global_transform * OAR_TIP
				_drop(tip, Vector3(_rng.randf_range(-0.1, 0.1), -0.2, _rng.randf_range(-0.1, 0.1)))
	if is_manned() and _rng.randf() < dt * 1.5:
		var tip2: Vector3 = (_oars[_rng.randi() % 2]["mesh"] as Node3D).global_transform * OAR_TIP
		if tip2.y > _water_y() + 0.05:
			_drop(tip2, Vector3.ZERO)


func _water_y() -> float:
	return float(lake.get("WATER_Y")) if lake != null and lake.get("WATER_Y") != null else 0.06


func _on_water(p: Vector3) -> Vector3:
	return Vector3(p.x, _water_y() + 0.015, p.z)


# ── the water's effects ──────────────────────────────────────────────────────

func _tick_fx(step: float) -> void:
	# Rings off the stern while the boat makes way.
	_wake_t -= step
	if absf(_speed) > 0.45 and _wake_t <= 0.0:
		_wake_t = clampf(0.55 / absf(_speed), 0.18, 0.6)
		for s in [-1.0, 1.0]:
			var p := hull.global_transform * Vector3(0.36 * s, WATERLINE, -1.1 if _speed > 0.0 else 1.1)
			_ring(_on_water(p), 0.3, 1.1 + absf(_speed) * 0.25, 1.4, 0.45, false)
	for r in _rings:
		r["t"] = float(r["t"]) + step
		var n := r["node"] as MeshInstance3D
		var u := clampf(float(r["t"]) / float(r["life"]), 0.0, 1.0)
		var sz := lerpf(float(r["s0"]), float(r["s1"]), 1.0 - (1.0 - u) * (1.0 - u))
		n.scale = Vector3(sz, sz, sz)
		var m := n.material_override as StandardMaterial3D
		m.albedo_color.a = float(r["a"]) * (1.0 - u)
	for r in _rings:
		if float(r["t"]) >= float(r["life"]):
			(r["node"] as Node).queue_free()
	_rings = _rings.filter(func(r: Dictionary) -> bool: return float(r["t"]) < float(r["life"]))
	var wy := _water_y()
	for d in _drops:
		var n2 := d["node"] as Node3D
		var v: Vector3 = d["v"]
		v.y -= 9.0 * step
		d["v"] = v
		n2.global_position += v * step
	for d in _drops:
		var n3 := d["node"] as Node3D
		if n3.global_position.y < wy:
			if _rng.randf() < 0.35:
				_ring(_on_water(n3.global_position), 0.08, 0.32, 0.6, 0.5, false)
			n3.queue_free()
	_drops = _drops.filter(func(d: Dictionary) -> bool: return is_instance_valid(d["node"]) and not (d["node"] as Node3D).is_queued_for_deletion())


## A ring on the water at `at` (world), growing from `s0` to `s1` metres over `life`
## seconds, `alpha` at first; `swirl`: the blade's puddle, not a plain ring.
func _ring(at: Vector3, s0: float, s1: float, life: float, alpha: float, swirl: bool) -> void:
	if _rings.size() > 60 or lake == null:
		return
	var n := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.orientation = PlaneMesh.FACE_Y
	n.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = _swirl() if swirl else _ring_texture()
	m.albedo_color = Color(0.86, 0.9, 0.93, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.disable_receive_shadows = true
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lake.add_child(n)
	n.global_position = at
	n.rotation.y = _rng.randf() * TAU
	n.scale = Vector3.ONE * s0
	_rings.append({"node": n, "t": 0.0, "life": life, "s0": s0, "s1": s1, "a": alpha})


func _splash(at: Vector3, n: int) -> void:
	for i in n:
		var a := _rng.randf() * TAU
		var sp := _rng.randf_range(0.3, 0.9)
		_drop(at + Vector3(0.0, 0.03, 0.0), Vector3(cos(a) * sp, _rng.randf_range(1.0, 2.1), sin(a) * sp))


func _drop(at: Vector3, v: Vector3) -> void:
	if _drops.size() > 70 or lake == null:
		return
	var d := MeshInstance3D.new()
	var q := QuadMesh.new()
	var s := _rng.randf_range(0.022, 0.04)
	q.size = Vector2(s * 0.6, s * 1.4)
	d.mesh = q
	d.material_override = _drop_mat
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lake.add_child(d)
	d.global_position = at
	_drops.append({"node": d, "v": v})


## The lake's ring (camp_lake.gd draws its fish rings the same way): two pale circles.
static func _ring_texture() -> ImageTexture:
	if _ring_tex == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var d := Vector2(x - 15.5, y - 15.5).length()
				var a := 1.0 if (d > 12.5 and d < 15.0) else (0.55 if (d > 7.0 and d < 8.5) else 0.0)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_ring_tex = ImageTexture.create_from_image(img)
	return _ring_tex


## The swirl a blade leaves: a ring with a darker, smoother middle and a curl in it.
static func _swirl() -> ImageTexture:
	if _swirl_tex == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var v := Vector2(x - 15.5, y - 15.5)
				var d := v.length()
				var ang := atan2(v.y, v.x)
				var a := 0.0
				var c := Color(1, 1, 1)
				if d > 11.5 and d < 14.5:
					a = 0.9
				elif d < 11.5:
					# The calm water in it, a shade darker, and a curl winding in.
					a = 0.32
					c = Color(0.55, 0.6, 0.62)
					var curl := fposmod(ang + d * 0.55, TAU)
					if curl < 0.6 and d > 2.0:
						a = 0.75
						c = Color(1, 1, 1)
				img.set_pixel(x, y, Color(c.r, c.g, c.b, a))
		_swirl_tex = ImageTexture.create_from_image(img)
	return _swirl_tex


# ── the lantern, the sounds ──────────────────────────────────────────────────

func _tick_lantern(dt: float) -> void:
	_lantern_on = move_toward(_lantern_on, 1.0 if _lantern_want else 0.0, dt / 0.6)
	if _lantern_light == null:
		return
	_lantern_light.visible = _lantern_on > 0.01
	var flick := 0.92 + 0.07 * sin(_t * 7.3) + 0.05 * sin(_t * 12.7 + 1.1) + 0.03 * sin(_t * 23.0)
	_lantern_light.light_energy = 1.5 * _lantern_on * flick
	if _glass != null:
		_glass.emission_enabled = _lantern_on > 0.01
		_glass.emission = Color(1.0, 0.7, 0.36)
		_glass.emission_energy_multiplier = 2.4 * _lantern_on * flick


func _tick_sound(dt: float) -> void:
	if _rush != null and _rush.stream != null:
		var sp := absf(_speed)
		var want := -80.0 if sp < 0.12 else lerpf(-22.0, -9.0, clampf(sp / 2.6, 0.0, 1.0))
		_rush.volume_db = move_toward(_rush.volume_db, want, dt * 40.0)
		if want > -79.0 and not _rush.playing:
			_rush.play(_rng.randf() * 2.0)
		elif want <= -79.0 and _rush.playing and _rush.volume_db <= -79.0:
			_rush.stop()
	# The old boat creaks as it rocks, now and then, more when somebody is in it.
	_creak_t -= dt * (1.0 + absf(_roll_v) * 6.0 + (1.0 if is_manned() else 0.0))
	if _creak_t <= 0.0:
		_creak_t = _rng.randf_range(5.0, 12.0)
		if is_manned() or absf(_roll_v) > 0.05:
			_play(SFX + "creak.mp3", _rng.randf_range(-14.0, -8.0), _rng.randf_range(0.85, 1.1))


## A sound from the boat (heard where it is).
func play_sound(file: String, db: float, pitch := 1.0) -> void:
	_play(SFX + file, db, pitch)


func _play(path: String, db: float, pitch: float) -> void:
	if not ResourceLoader.exists(path) or _players.is_empty():
		return
	var p: AudioStreamPlayer3D = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = load(path)
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()


func _player3d(path: String, loop: bool) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = BUS if AudioServer.get_bus_index(BUS) >= 0 else "Master"
	p.unit_size = 3.0
	p.max_distance = 60.0
	p.attenuation_filter_cutoff_hz = 5000.0
	if path != "":
		p.stream = _loop_of(path) if loop else (load(path) if ResourceLoader.exists(path) else null)
	hull.add_child(p)
	p.position = Vector3(0.0, 0.4, 0.0)
	return p


static func _loop_of(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var s = load(path)
	if s is AudioStreamMP3:
		var c := (s as AudioStreamMP3).duplicate() as AudioStreamMP3
		c.loop = true
		return c
	return s
