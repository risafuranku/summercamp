extends Node

## The room in a business's building in the camp (business/room_outside.gd), lit as the
## place is: its lamps on while it is open (the books' shift, the day's or the late one's),
## off when it is shut. From the hour and the books, so every machine sees it the same.

const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const CREW_FIGURES := preload("res://scripts/business/crew_figures.gd")

## The room's own light (as the service interior's room has), and its lamps.
var main: OmniLight3D
var lamps: Array = []
## The lamps' shades (their glow goes with the light).
var shades: Array = []

## The hands seen at work through the glass (crew_figures.gd, as in the service interior):
## the room they stand in, the layout (its STATIONS), role -> station of the stations in
## this room, and the group of the place's own records (their crew_places: beside the
## wardens where the work is).
var room: Node3D
var layout = null
var roles: Dictionary = {}
var records_group := ""

var _key := ""
var _t := 0.0
var _on := -1
var _crew: Node3D = null


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.0
	if _key == "":
		_key = _site_key()
	if _crew == null and _key != "" and room != null and layout != null and not roles.is_empty():
		_start_crew()
	# The hands' figures on the room's layer, lit by its lights (building_models.ROOM_LAYER).
	if room != null:
		for c in room.get_children():
			if c is Sprite3D:
				(c as Sprite3D).layers |= 1 << 13
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


func _start_crew() -> void:
	_crew = CREW_FIGURES.new()
	_crew.name = "CrewFigures"
	_crew.key = _key
	var spots := {}
	var at_role := {}
	for role in roles:
		var st: Dictionary = layout.STATIONS[roles[role]]
		spots[role] = {"root": room, "pos": st["stand"], "station": roles[role], "aside": Vector3(0.6, 0, 0.5), "note": (st["mark"] as Vector3) - Vector3(0, 0.45, 0)}
		at_role[str(roles[role])] = str(role)
	_crew.spots = spots
	var key := _key
	var group := records_group
	_crew.place_of = func(p: Dictionary) -> String:
		var biz := get_tree().get_first_node_in_group(group) if group != "" and is_inside_tree() else null
		if biz == null or not biz.has_method("crew_places"):
			return str(p.get("role", ""))
		var places: Dictionary = biz.crew_places(key)
		var slug := str(p.get("slug", ""))
		if not places.has(slug):
			return str(p.get("role", ""))
		return str(at_role.get(str(places[slug]), ""))
	add_child(_crew)


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
