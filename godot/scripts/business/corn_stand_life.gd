extends Node3D

## The corn stand standing in the camp (building_models._corn_stand): steam off the pot
## in puffs (a Grok sprite) (in steps, twelve a second), the awning's flaps stirring in the wind,
## a cob or two on the counter when there is corn in the books.

const FPS := 12.0
const PUFFS := 6

var guests_here := 0

var _puffs: Array = []            # {sprite, phase}
var _flaps: Array = []
var _acc := 0.0
var _t := 0.0
var _steam_at := Vector3.ZERO


func _ready() -> void:
	add_to_group("attraction")
	call_deferred("_setup")


func _setup() -> void:
	var r := get_parent() as Node3D
	if r == null:
		return
	_steam_at = r.get_meta("steam_at", Vector3(0, 1.6, 0))
	for c in r.get_children():
		if str(c.name).begins_with("AwningFlap"):
			_flaps.append(c)
	# A puff of steam (Grok, camp/steam_puff.png).
	var path := "res://assets/textury/camp/steam_puff.png"
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	for i in PUFFS:
		var s := Sprite3D.new()
		s.texture = tex
		s.pixel_size = 0.24 / float(maxi(1, tex.get_height()))
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.shaded = false
		s.transparent = true
		r.add_child(s)
		_puffs.append({"sprite": s, "phase": float(i) / float(PUFFS)})


func _process(delta: float) -> void:
	_acc += delta
	if _acc < 1.0 / FPS:
		return
	_t += _acc
	_acc = 0.0
	for p in _puffs:
		var age := fmod(_t * 0.35 + float(p["phase"]), 1.0)
		var s: Sprite3D = p["sprite"]
		s.position = _steam_at + Vector3(sin(_t * 1.3 + float(p["phase"]) * 6.0) * 0.12 * age, age * 1.2, age * 0.15)
		s.scale = Vector3.ONE * (0.6 + age * 1.6)
		s.modulate = Color(1, 1, 1, (1.0 - age) * 0.55)
	for i in _flaps.size():
		var f := _flaps[i] as Node3D
		if is_instance_valid(f):
			f.rotation.x = sin(_t * 2.2 + i * 0.9) * 0.12
