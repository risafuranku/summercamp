extends Node3D

## A lamp whose bulb has gone (building_manager's broken lamps: a breakdown, waiting for
## the repair) shorts now and then while the lamps are on: a shower of sparks from its
## head that falls and goes out (the camp's Grok embers, camp/embers.png, added to the
## scene like light), a blue-white flash for two steps and the crackle (ElevenLabs
## world/lamp_zap_a/b). Only the lamps within 40 m of you, in steps, twelve a second.
## A director's blackout (dark_until) is no fault and does not spark. Made by
## world_sounds.gd.

const FPS := 12.0
const EMBERS := "res://assets/textury/camp/embers.png"
const ZAPS := ["res://assets/sfx/world/lamp_zap_a.mp3", "res://assets/sfx/world/lamp_zap_b.mp3"]
const NEAR := 40.0

var player_getter: Callable

var _mats: Array = []
var _quad: QuadMesh
var _sparks: Array = []          # {node, v: Vector3, life, max}
var _next_t: Dictionary = {}     # lamp id -> seconds to its next short
var _flash: OmniLight3D
var _flash_steps := 0
var _snd: AudioStreamPlayer3D
var _acc := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "LampSparks"
	_rng.randomize()
	var tex: Texture2D = load(EMBERS) if ResourceLoader.exists(EMBERS) else null
	for i in 3:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		if tex != null:
			m.albedo_texture = tex
			m.uv1_scale = Vector3(1.0 / 3.0, 1.0, 1.0)
			m.uv1_offset = Vector3(float(i) / 3.0, 0.0, 0.0)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		# Electric: whiter than the fire's, but warm (blue-white they were stars).
		m.albedo_color = Color(1.0, 0.96, 0.82)
		_mats.append(m)
	_quad = QuadMesh.new()
	_quad.size = Vector2(0.075, 0.075)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(0.75, 0.85, 1.0)
	_flash.omni_range = 5.0
	_flash.light_energy = 2.2
	_flash.visible = false
	_flash.set_meta("retro_skip", true)
	add_child(_flash)
	_snd = AudioStreamPlayer3D.new()
	_snd.bus = "OutdoorAmbience" if AudioServer.get_bus_index("OutdoorAmbience") >= 0 else "Master"
	_snd.unit_size = 3.0
	_snd.max_distance = 45.0
	add_child(_snd)


func _process(delta: float) -> void:
	_acc += delta
	if _acc < 1.0 / FPS:
		return
	var dt := _acc
	_acc = 0.0
	_step_sparks(dt)
	if _flash_steps > 0:
		_flash_steps -= 1
		_flash.visible = _flash_steps > 0
	var main := get_tree().current_scene
	var bm = main.get("building_manager") if main != null else null
	if not player_getter.is_valid() and get_parent() != null and get_parent().get("player_getter") is Callable:
		player_getter = get_parent().get("player_getter")
	var me: Node3D = player_getter.call() if player_getter.is_valid() else null
	if bm == null or me == null or not bool(bm.get("_lamps_active")):
		return
	var broken: Dictionary = bm.get("_broken_lamps") if bm.get("_broken_lamps") is Dictionary else {}
	if broken.is_empty():
		return
	var runtime: Dictionary = bm.get("_lamp_runtime") if bm.get("_lamp_runtime") is Dictionary else {}
	var now := Time.get_ticks_msec() / 1000.0
	for id in runtime:
		var e: Dictionary = runtime[id]
		var root = e.get("root", null)
		if not (root is Node3D) or not is_instance_valid(root):
			continue
		var origin = (root as Node3D).get_meta("grid_origin", null)
		if not (origin is Vector2i) or not broken.has("%d:%d" % [(origin as Vector2i).x, (origin as Vector2i).y]):
			continue
		if float(e.get("dark_until", 0.0)) > now:
			continue
		var head: Node3D = e.get("spot", null) if e.get("spot", null) is Node3D else root
		if head.global_position.distance_to(me.global_position) > NEAR:
			continue
		var t := float(_next_t.get(id, _rng.randf_range(1.0, 6.0))) - dt
		if t <= 0.0:
			t = _rng.randf_range(3.0, 11.0)
			_short(head.global_position)
		_next_t[id] = t


func _short(at: Vector3) -> void:
	for i in _rng.randi_range(8, 14):
		var s := MeshInstance3D.new()
		s.mesh = _quad
		s.material_override = _mats[0]
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Their own material (added light): not the PS1 surfaces' (retro_materials.gd).
		s.set_meta("retro_skip", true)
		add_child(s)
		s.global_position = at
		var a := _rng.randf() * TAU
		var out := _rng.randf_range(0.4, 1.6)
		var life := _rng.randi_range(7, 14)
		_sparks.append({"node": s, "v": Vector3(cos(a) * out, _rng.randf_range(-0.2, 1.2), sin(a) * out), "life": life, "max": life})
	_flash.global_position = at
	_flash.visible = true
	_flash_steps = 2
	var path: String = ZAPS[_rng.randi() % ZAPS.size()]
	if ResourceLoader.exists(path):
		_snd.stream = load(path)
		_snd.global_position = at
		_snd.volume_db = _rng.randf_range(-9.0, -5.0)
		_snd.pitch_scale = _rng.randf_range(0.94, 1.08)
		_snd.play()


func _step_sparks(dt: float) -> void:
	for sp in _sparks:
		var n: MeshInstance3D = sp["node"]
		var v: Vector3 = sp["v"]
		v.y -= 9.8 * dt
		sp["v"] = v
		n.global_position += v * dt
		sp["life"] = int(sp["life"]) - 1
		var k := float(sp["life"]) / float(sp["max"])
		n.material_override = _mats[0] if k > 0.6 else (_mats[1] if k > 0.3 else _mats[2])
		if int(sp["life"]) <= 0 or n.global_position.y < 0.02:
			n.queue_free()
			sp["life"] = 0
	_sparks = _sparks.filter(func(sp): return int(sp["life"]) > 0)
