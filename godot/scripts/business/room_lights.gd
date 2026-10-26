extends Node

## The room in a business's building in the camp (business/room_outside.gd), lit as the
## place is: its lamps on while it is open (the books' shift, the day's or the late one's),
## off when it is shut. From the hour and the books, so every machine sees it the same.

const BUSINESS := preload("res://scripts/business/business_runtime.gd")

## The room's own light (as the service interior's room has), and its lamps.
var main: OmniLight3D
var lamps: Array = []
## The lamps' shades (their glow goes with the light).
var shades: Array = []

var _key := ""
var _t := 0.0
var _on := -1


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.0
	if _key == "":
		_key = _site_key()
	var on := 0
	if _key != "":
		var s := BUSINESS.site(_key)
		on = 1 if not s.is_empty() and BUSINESS.shift_now(s) != "closed" else 0
	if on == _on:
		return
	_on = on
	if main != null and is_instance_valid(main):
		main.light_energy = 6.0 if on == 1 else 0.0
	for l in lamps:
		if is_instance_valid(l):
			(l as OmniLight3D).light_energy = 2.5 if on == 1 else 0.0
	for sh in shades:
		if is_instance_valid(sh):
			var m := (sh as MeshInstance3D).material_override as StandardMaterial3D
			if m != null:
				m.emission_energy_multiplier = 0.7 if on == 1 else 0.0


## The business's key ("x:y", its grid origin) from the structure it stands in.
func _site_key() -> String:
	var n := get_parent()
	while n != null:
		if n.has_meta("grid_origin"):
			var o = n.get_meta("grid_origin")
			if o is Vector2i:
				return "%d:%d" % [(o as Vector2i).x, (o as Vector2i).y]
		n = n.get_parent()
	return ""
