extends RefCounted

## The lake at night (scripts/lake/lake_trip.gd rows the boat; this decides what the
## water does about it). A night crossing gets one thing, from the third night crossing
## two, never the same twice running, never while the boat is coming alongside:
##   under    a long scrape along the bottom; the boat lurches (the old one)
##   knock    three knocks from under the hull. Keep rowing and that is all. Stop for
##            long and they come again, closer to the bow (the Ghosts page: DONT KNOCK
##            BACK, he goes for the noise)
##   lantern  a lantern on the water ahead, low, as if in a boat; it comes toward you and
##            goes out before it reaches you. The boathouse window is lit afterwards
##   fog      the fog closes in until the camp lamps are gone; a bell under the water;
##            it lifts again
##   hand     a pale hand comes over the gunwale, holds on, and the boat dips its way
## Everything comes and goes in steps, and nothing stays.

const SFX := "res://assets/sfx/lake/"
const HAND_TEX := "res://assets/textury/hands/lake_hand.png"
const KINDS := ["under", "knock", "lantern", "fog", "hand"]

var trip
var crossings := 0
var _plan: Array = []          # [{kind, at}] seconds into the crossing
var _t := 0.0
var _active := ""
var _a_t := 0.0
var _last := ""
var _still := 0.0
var _knocked_again := false
var _lantern: Node3D
var _hand: TextureRect
var _fog_from := -1.0
var _rng := RandomNumberGenerator.new()


func _init(owner_trip) -> void:
	trip = owner_trip
	_rng.randomize()


## A crossing starts. Night or not decides whether anything is planned.
func begin(night: bool) -> void:
	_plan.clear()
	_t = 0.0
	_active = ""
	_knocked_again = false
	if not night:
		return
	crossings += 1
	var n := 1 if crossings < 3 else 2
	var pool: Array = KINDS.duplicate()
	pool.erase(_last)
	pool.shuffle()
	for i in n:
		_plan.append({"kind": pool[i], "at": _rng.randf_range(6.0, 14.0) + float(i) * _rng.randf_range(10.0, 16.0)})
	_last = str(_plan.back()["kind"])


func end() -> void:
	_stop_active()
	_plan.clear()


## Every frame while rowing. `stroking`: a stroke is being pulled; `docking`: alongside.
func tick(delta: float, stroking: bool, docking: bool) -> void:
	_t += delta
	_still = 0.0 if stroking else _still + delta
	if _active != "":
		_a_t += delta
		_tick_active(delta)
		return
	if docking or _plan.is_empty():
		return
	if _t >= float(_plan[0]["at"]):
		var ev: Dictionary = _plan.pop_front()
		_start(str(ev["kind"]))


func _start(kind: String) -> void:
	_stop_active()
	_active = kind
	_a_t = 0.0
	match kind:
		"under":
			trip._play("under.mp3", 0.0)
			trip._speed *= 0.3
			trip._lurch(0.08)
			trip._say("Something long passes under the boat. Then nothing.")
			_active = ""
		"knock":
			trip._play("knock.mp3", -1.0)
			trip._speed *= 0.5
		"lantern":
			_spawn_lantern()
			trip._play("lantern.mp3", -6.0)
		"fog":
			_fog_from = trip._fog_density()
			trip._play("fog.mp3", -4.0)
		"hand":
			_show_hand()
			trip._play("grab.mp3", 0.0)
			trip._speed *= 0.2
			trip._lurch(-0.12)


func _tick_active(delta: float) -> void:
	match _active:
		"knock":
			# Sit still after the knocks and they come again, under the bow.
			if not _knocked_again and _a_t > 3.0 and _still > 5.0:
				_knocked_again = true
				trip._play("knock.mp3", 3.0)
				trip._lurch(0.04)
			if _a_t > 14.0:
				_active = ""
		"lantern":
			if _lantern == null:
				_active = ""
				return
			var boat: Node3D = trip._boat()
			var to := boat.global_position - _lantern.global_position
			to.y = 0.0
			if to.length() > 7.0 and _a_t < 16.0:
				_lantern.global_position += to.normalized() * delta * 1.1
				# The flame flickers in steps.
				(_lantern.get_node("Light") as OmniLight3D).light_energy = [0.9, 1.2, 0.7, 1.1][int(_a_t * 6.0) % 4]
			else:
				_lantern.queue_free()
				_lantern = null
				trip._light_boathouse()
				_active = ""
		"fog":
			var k := 0.0
			if _a_t < 4.0:
				k = _a_t / 4.0
			elif _a_t < 12.0:
				k = 1.0
			elif _a_t < 17.0:
				k = 1.0 - (_a_t - 12.0) / 5.0
			else:
				trip._set_fog_density(_fog_from)
				_active = ""
				return
			trip._set_fog_density(lerpf(_fog_from, maxf(_fog_from, 0.16), floorf(k * 8.0) / 8.0))
		"hand":
			if _hand == null:
				_active = ""
				return
			var vp: Vector2 = trip.get_viewport().get_visible_rect().size
			var k2 := 0.0
			if _a_t < 0.35:
				k2 = _a_t / 0.35
			elif _a_t < 2.4:
				k2 = 1.0
			elif _a_t < 2.9:
				k2 = 1.0 - (_a_t - 2.4) / 0.5
			else:
				_hand.queue_free()
				_hand = null
				trip._say("The edge of the boat is wet where it held on.")
				_active = ""
				return
			var s := float(maxi(1, int(round(vp.y / 260.0))))
			_hand.size = _hand.texture.get_size() * s if _hand.texture != null else Vector2(96, 96) * s
			_hand.position = Vector2(vp.x * 0.68, vp.y - _hand.size.y * floorf(k2 * 5.0) / 5.0 * 0.85).floor()


func _stop_active() -> void:
	if _lantern != null and is_instance_valid(_lantern):
		_lantern.queue_free()
	_lantern = null
	if _hand != null and is_instance_valid(_hand):
		_hand.queue_free()
	_hand = null
	if _active == "fog" and _fog_from >= 0.0:
		trip._set_fog_density(_fog_from)
	_active = ""


func _spawn_lantern() -> void:
	var boat: Node3D = trip._boat()
	if boat == null:
		_active = ""
		return
	_lantern = Node3D.new()
	_lantern.name = "NightLantern"
	var fwd := Vector3(sin(boat.rotation.y), 0.0, cos(boat.rotation.y))
	_lantern.position = boat.global_position + fwd * 24.0 + fwd.cross(Vector3.UP) * _rng.randf_range(-5.0, 5.0) + Vector3(0, 0.6, 0)
	var l := OmniLight3D.new()
	l.name = "Light"
	l.light_color = Color(1.0, 0.72, 0.36)
	l.light_energy = 1.0
	l.omni_range = 6.0
	_lantern.add_child(l)
	var flame := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.45, 0.6)
	flame.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(1.0, 0.8, 0.45)
	flame.material_override = m
	_lantern.add_child(flame)
	# The glow round it, and its smear on the water below.
	for g in [[Vector2(2.2, 2.2), Vector3.ZERO, 0.22], [Vector2(0.7, 2.6), Vector3(0, -1.3, 0), 0.16]]:
		var gl := MeshInstance3D.new()
		var gq := QuadMesh.new()
		gq.size = g[0]
		gl.mesh = gq
		var gm := StandardMaterial3D.new()
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		gm.albedo_color = Color(1.0, 0.6, 0.25, float(g[2]) * 3.0)
		gm.albedo_texture = _glow_tex()
		gm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		gl.material_override = gm
		gl.position = g[1]
		_lantern.add_child(gl)
	boat.get_parent().add_child(_lantern)
	_lantern.global_position = _lantern.position


## A round glow, 16 px, for the lantern (chunky, like the rest).
static func _glow_tex() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 16
	t.height = 16
	return t


func _show_hand() -> void:
	_hand = TextureRect.new()
	_hand.texture = load(HAND_TEX) if ResourceLoader.exists(HAND_TEX) else null
	_hand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hand.stretch_mode = TextureRect.STRETCH_SCALE
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trip._overlay.add_child(_hand)
