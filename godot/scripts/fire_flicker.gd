extends Node3D

## The bonfire, alive: its flame cones (siblings named "Flame*") jump to a new shape ten
## times a second, the fire light breathes with them, and sparks climb out of it in steps.
## Stepped on purpose (no smooth tweening), like a 1996 sprite fire.

const FPS := 10.0

var _acc := 0.0
var _flames: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _sparks: Array = []    # {node, v, life}
var _spark_mat: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for c in get_parent().get_children():
		if c is MeshInstance3D and str(c.name).begins_with("Flame"):
			_flames.append(c)
			c.set_meta("rest_scale", c.scale)
		elif c is OmniLight3D:
			_light = c
	_spark_mat = StandardMaterial3D.new()
	_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_mat.albedo_color = Color(1.0, 0.78, 0.3)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_acc += delta
	if _acc < 1.0 / FPS:
		return
	_acc = 0.0
	for f in _flames:
		var rest: Vector3 = f.get_meta("rest_scale")
		f.scale = Vector3(rest.x * _rng.randf_range(0.85, 1.12), rest.y * _rng.randf_range(0.78, 1.28), rest.z * _rng.randf_range(0.85, 1.12))
		f.rotation.y = _rng.randf() * TAU
	if _light != null:
		_light.light_energy = _rng.randf_range(1.05, 1.8)
	# Sparks: born at the top of the fire, climb and drift, die after a few frames.
	if _rng.randf() < 0.6:
		var s := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.035, 0.035, 0.035)
		s.mesh = b
		s.material_override = _spark_mat
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(s)
		s.position = Vector3(_rng.randf_range(-0.15, 0.15), 0.8, _rng.randf_range(-0.15, 0.15))
		_sparks.append({"node": s, "v": Vector3(_rng.randf_range(-0.05, 0.05), _rng.randf_range(0.12, 0.22), _rng.randf_range(-0.05, 0.05)), "life": _rng.randi_range(5, 12)})
	for sp in _sparks:
		var n: MeshInstance3D = sp["node"]
		n.position += sp["v"]
		sp["life"] -= 1
		if int(sp["life"]) <= 0:
			n.queue_free()
	_sparks = _sparks.filter(func(sp): return int(sp["life"]) > 0)
