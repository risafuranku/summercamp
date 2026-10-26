extends Node

## The room in a business's building in the camp (business/room_outside.gd), lit as the
## place is: its lamps on while it is open (the books' shift, the day's or the late one's),
## off when it is shut. From the hour and the books, so every machine sees it the same.

const BUSINESS := preload("res://scripts/business/business_runtime.gd")
const CREW_FIGURES := preload("res://scripts/business/crew_figures.gd")
const SERVICE_LIFE := preload("res://scripts/food/service_life.gd")
## The place's records group -> its guests' profile (service_life.gd).
const PROFILE := {"taprooms": "pub", "kitchens": "rest", "jednotas": "vecerka"}

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
## The OTEVŘENO / ZAVŘENO card on the door (building_models._door_sign).
var door_sign: Sprite3D = null

var _key := ""
var _t := 0.0
var _on := -1
var _crew: Node3D = null
var _life: Node3D = null
var _sign := ""


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.0
	if _key == "":
		_key = _site_key()
	if _crew == null and _key != "" and room != null and layout != null and not roles.is_empty():
		_start_crew()
	# The guests at the tables and the racks, as inside (service_life.gd), quiet.
	if _life == null and _key != "" and room != null and room.is_inside_tree() and PROFILE.has(records_group):
		_life = SERVICE_LIFE.new()
		_life.name = "Patrons"
		_life.set("quiet", true)
		room.add_child(_life)
		var placed: Dictionary = SERVICE_LIFE.seats_of(str(PROFILE[records_group]), room)
		_life.setup(str(PROFILE[records_group]), _key, placed["seats"], placed["settings"])
	# The Jednota's rack as stocked as its records say (jednota_layout.shop_outside).
	if room != null and records_group == "jednotas" and _key != "":
		var shop := get_tree().get_first_node_in_group("jednotas")
		var goods := room.get_node_or_null("RackGoods") as Node3D
		if shop != null and goods != null and shop.has_method("shelf"):
			var units := 0
			for g in (shop.shelf(_key) as Dictionary):
				units += int(shop.shelf(_key)[g])
			goods.visible = units > 0
	# The hands' figures on the room's layer, lit by its lights (building_models.ROOM_LAYER).
	if room != null:
		for c in room.find_children("*", "GeometryInstance3D", true, false):
			(c as GeometryInstance3D).layers |= 1 << 13
	var on := 0
	if _key != "":
		var s := BUSINESS.site(_key)
		on = 1 if not s.is_empty() and BUSINESS.shift_now(s) != "closed" else 0
	# The card turned at last orders already: nobody new goes in (who ordered still eats).
	var sign := "open" if on == 1 and BUSINESS.to_last_orders(_key) > 0 else "closed"
	if sign != _sign and door_sign != null and is_instance_valid(door_sign):
		_sign = sign
		door_sign.texture = load("res://assets/textury/camp/door_sign_%s.png" % sign)
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
