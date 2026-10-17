extends Node3D

## The garden gnome (building_models._gnome). Kitsch; guests smile at it. Only, in the
## morning it is not always facing the way it was the night before. Mostly a little
## round, as if somebody knocked it. Now and then it is looking straight at the office.
## (Checked when the day changes; it then stays put for the day.)

const LOOKS_AT_OFFICE := 0.3

var _day := -1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _process(_delta: float) -> void:
	if CoreRoot == null or not CoreRoot.has_method("get_day"):
		return
	var day: int = CoreRoot.get_day()
	if day == _day:
		return
	var first := _day < 0
	_day = day
	var gnome := get_parent() as Node3D
	if gnome == null:
		return
	if first:
		return
	if _rng.randf() < LOOKS_AT_OFFICE:
		var office := _office()
		if office != null:
			var to := office.global_position - gnome.global_position
			to.y = 0.0
			if to.length_squared() > 0.01:
				# The model looks down its +Z.
				gnome.global_rotation.y = atan2(to.x, to.z)
				return
	gnome.rotation.y += _rng.randf_range(-0.7, 0.7)


## The reception: the camp's main building among the structures.
func _office() -> Node3D:
	var n: Node = self
	while n != null and not n.has_meta("grid_origin"):
		n = n.get_parent()
	if n == null or n.get_parent() == null:
		return null
	return n.get_parent().get_node_or_null("MainBuilding") as Node3D
