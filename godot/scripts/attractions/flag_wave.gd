extends Node3D

## The camp's flag on its pole (building_models._flagpole): six strips out from the
## pole, each turned a little more than the one before it in a wave that runs out to
## the fly end, faster and wider when the wind is up (the weather). Stepped at 12
## frames a second. The flag's material is the model's (meta "material" on the parent).

const STRIPS := 6
const FLAG_W := 1.2
const FLAG_H := 0.8
const FPS := 12.0

var _strips: Array[MeshInstance3D] = []
var _clock := 0.0
var _acc := 0.0
var _flag: Node3D


func _ready() -> void:
	call_deferred("_setup")


func _setup() -> void:
	_flag = get_parent() as Node3D
	var base_mat: StandardMaterial3D = _flag.get_meta("material", null)
	var sw := FLAG_W / float(STRIPS)
	for i in STRIPS:
		var m := MeshInstance3D.new()
		m.name = "Strip%d" % i
		var q := QuadMesh.new()
		q.size = Vector2(sw + 0.002, FLAG_H)
		m.mesh = q
		if base_mat != null:
			var mat := base_mat.duplicate() as StandardMaterial3D
			mat.uv1_scale = Vector3(1.0 / float(STRIPS), 1.0, 1.0)
			mat.uv1_offset = Vector3(float(i) / float(STRIPS), 0.0, 0.0)
			m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_flag.add_child(m)
		_strips.append(m)
	_layout()


func _process(delta: float) -> void:
	_clock += delta
	_acc += delta
	if _acc < 1.0 / FPS:
		return
	_acc = 0.0
	_layout()


## Harder in rain and storms (main's weather 3..5): the nearest ancestor that has it.
func _wind() -> float:
	var n: Node = self
	while n != null:
		if "_weather_state" in n:
			var weather := int(n.get("_weather_state"))
			return 1.0 if weather >= 3 and weather <= 5 else 0.6
		n = n.get_parent()
	return 0.6


## Each strip from the end of the one before, turned by the travelling wave.
func _layout() -> void:
	var sw := FLAG_W / float(STRIPS)
	var at := Vector3.ZERO
	var yaw := 0.0
	var wind := _wind()
	for i in _strips.size():
		var k := float(i + 1) / float(STRIPS)
		yaw += sin(_clock * (2.6 + wind * 1.4) - float(i) * 0.9) * 0.16 * wind * k
		var dir := Vector3(cos(yaw), 0.0, -sin(yaw))
		var m := _strips[i]
		m.position = at + dir * (sw * 0.5) + Vector3(0, -FLAG_H * 0.5 - sin(k * 1.2) * 0.04 * (1.0 - wind), 0)
		m.rotation = Vector3(0, yaw, 0)
		at += dir * sw
