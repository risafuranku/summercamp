extends Node3D

## The camp's warehouse, alive (a child of the warehouse structure, built by
## building_models._warehouse; playtest 14. 11.: "every place has its own stock, the corn
## stand only ever one box; a warehouse of racks, each given to a place, and filled you would
## really see the goods there"). Its racks stand along the back of the open shed; each is
## given to one of the camp's places (E on it: the next place, then none), its tag says which,
## and on it stand the boxes of that place's goods beyond what its own shelf holds
## (business_rules.own_cap; the books: actions.biz_set_rack, biz["stores"]). Looked at again
## every couple of seconds.

const RULES = preload("res://core/systems/business_rules.gd")
const K = preload("res://scripts/interior_kit.gd")
const FONT := "res://assets/fonts/w95b.fnt"
const LOOK_SEC := 2.0
## A rack: its width, its shelves' heights, a box's size.
const RACK_W := 1.0
const SHELVES := [0.32, 0.86, 1.4]
const BOX := Vector3(0.3, 0.26, 0.34)

var key := ""
## Where each rack stands (local), built by the model.
var rack_at: Array = []
var _tags: Array = []
var _boxes: Array = []        # per rack: [MeshInstance3D] in use
var _t := 0.0
var _shown := ""
## The bare bulb on its cord over the racks: lit with the camp's lamps (building_manager.lamps_on).
var _bulb: MeshInstance3D
var _bulb_mat: StandardMaterial3D
var _light: OmniLight3D


func _ready() -> void:
	var o = get_parent().get_meta("grid_origin", null) if get_parent() != null else null
	if o is Vector2i:
		key = "%d:%d" % [o.x, o.y]
	for i in rack_at.size():
		var tag := Label3D.new()
		if ResourceLoader.exists(FONT):
			tag.font = load(FONT)
		tag.pixel_size = 0.004
		tag.font_size = 32
		# Chalk-white on the dark boards, as the hands wrote them.
		tag.modulate = Color(0.95, 0.93, 0.86)
		tag.outline_size = 6
		tag.outline_modulate = Color(0.06, 0.05, 0.04)
		tag.position = (rack_at[i] as Vector3) + Vector3(0, 1.86, 0.2)
		add_child(tag)
		_tags.append(tag)
		_boxes.append([])
	_make_bulb()
	add_to_group("warehouse")


func _make_bulb() -> void:
	if rack_at.is_empty():
		return
	var mid := Vector3.ZERO
	for a in rack_at:
		mid += a as Vector3
	mid /= float(rack_at.size())
	var at := Vector3(mid.x, 2.55, mid.z + 0.9)
	var cord := K.slab(self, Vector3(0.012, 0.5, 0.012), at + Vector3(0, 0.3, 0), K.surface("veneer_dark", 0.2, Color(0.1, 0.1, 0.1)), "Cord")
	cord.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bulb = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.045
	s.height = 0.11
	s.radial_segments = 8
	s.rings = 4
	_bulb.mesh = s
	_bulb.position = at
	_bulb_mat = StandardMaterial3D.new()
	_bulb_mat.albedo_color = Color(0.85, 0.82, 0.7)
	_bulb_mat.emission = Color(1.0, 0.84, 0.52)
	_bulb.material_override = _bulb_mat
	_bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bulb)
	_light = OmniLight3D.new()
	_light.position = at + Vector3(0, -0.08, 0)
	_light.light_color = Color(1.0, 0.84, 0.56)
	_light.omni_range = 5.5
	_light.omni_attenuation = 1.3
	_light.light_energy = 0.0
	_light.visible = false
	add_child(_light)


func _set_bulb(on: bool) -> void:
	if _light == null or _light.visible == on:
		return
	_light.visible = on
	_light.light_energy = 1.6 if on else 0.0
	_bulb_mat.emission_enabled = on


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = LOOK_SEC
	_look()


## The books as they are now on the racks: the tags and the boxes.
func _look() -> void:
	var state = CoreRoot.get_state() if CoreRoot != null else null
	if state == null or key == "":
		return
	var bm = get_tree().current_scene.get("building_manager") if get_tree().current_scene != null else null
	_set_bulb(bm != null and bm.has_method("lamps_on") and bool(bm.lamps_on()))
	var racks: Array = CoreRoot.actions.biz_store_racks(key)
	var sites: Dictionary = (state.biz as Dictionary).get("sites", {}) if state.biz is Dictionary else {}
	# Each place's goods beyond its own shelf, shared out over its racks in turn.
	var left := {}
	var sig := ""
	for i in mini(racks.size(), rack_at.size()):
		var sk := str(racks[i])
		var site: Dictionary = sites.get(sk, {})
		var kind := str(site.get("kind", ""))
		(_tags[i] as Label3D).text = tr(str((RULES.KINDS.get(kind, {}) as Dictionary).get("name", ""))) if kind != "" else "- - -"
		var on_rack: Array = []
		if kind != "":
			if not left.has(sk):
				var over := {}
				for g in RULES.goods(kind):
					var pack := maxi(1, int(RULES.goods(kind)[g].get("pack", 1)))
					var extra := int((site.get("stock", {}) as Dictionary).get(g, 0)) - RULES.own_cap(kind, str(g), site)
					if extra > 0:
						over[g] = int(ceil(float(extra) / float(pack)))
				left[sk] = over
			var over_now: Dictionary = left[sk]
			for g in over_now.keys():
				var n := mini(int(over_now[g]), RULES.RACK_PACKS)
				for j in n:
					on_rack.append([str(g), kind])
				over_now[g] = int(over_now[g]) - n
		sig += "%d:%s:%d|" % [i, sk, on_rack.size()]
		_set_boxes(i, on_rack)
	_shown = sig


## The boxes on rack `i`: one a good's pack, its name on its front, shelf by shelf.
func _set_boxes(i: int, goods: Array) -> void:
	var have: Array = _boxes[i]
	while have.size() > goods.size():
		var b: Node = have.pop_back()
		if is_instance_valid(b):
			b.queue_free()
	var per_shelf := int(floor(RACK_W / (BOX.x + 0.02)))
	for j in goods.size():
		var b: MeshInstance3D
		if j < have.size():
			b = have[j]
		else:
			b = K.slab(self, BOX, Vector3.ZERO, K.surface("cardboard", 0.6), "Box")
			var name_l := Label3D.new()
			if ResourceLoader.exists(FONT):
				name_l.font = load(FONT)
			name_l.pixel_size = 0.0025
			name_l.font_size = 24
			name_l.modulate = Color(0.16, 0.1, 0.06)
			name_l.position = Vector3(0, 0.02, BOX.z * 0.5 + 0.004)
			name_l.name = "Name"
			b.add_child(name_l)
			have.append(b)
		var shelf := mini(j / maxi(1, per_shelf), SHELVES.size() - 1)
		var col := j % maxi(1, per_shelf)
		b.position = (rack_at[i] as Vector3) + Vector3(-RACK_W * 0.5 + (BOX.x + 0.02) * (float(col) + 0.5), float(SHELVES[shelf]) + BOX.y * 0.5 + 0.02, 0.0)
		var g := str(goods[j][0])
		var kind := str(goods[j][1])
		(b.get_node("Name") as Label3D).text = tr(str((RULES.goods(kind).get(g, {}) as Dictionary).get("label", g))).to_upper()


## The rack nearest `at` (world), -1 none within reach.
func rack_near(at: Vector3) -> int:
	var best := -1
	var best_d := 2.2
	for i in rack_at.size():
		var p: Vector3 = global_transform * (rack_at[i] as Vector3)
		var d := Vector2(p.x - at.x, p.z - at.z).length()
		if d < best_d:
			best_d = d
			best = i
	return best


## E at the rack nearest `at`: given to the next of the camp's places (by the plan's order),
## after the last to none.
func next_place(at: Vector3) -> bool:
	var i := rack_near(at)
	if i < 0 or CoreRoot == null:
		return false
	var state = CoreRoot.get_state()
	var sites: Array = ((state.biz as Dictionary).get("sites", {}) as Dictionary).keys() if state.biz is Dictionary else []
	sites.sort()
	var now := str(CoreRoot.actions.biz_store_racks(key)[i])
	var at_i := sites.find(now)
	var next := ""
	if at_i + 1 < sites.size():
		next = str(sites[at_i + 1])
	CoreRoot.actions.biz_set_rack(key, i, next)
	_t = 0.0
	return true


## Shot driver: the places its racks are given to stocked to the full (racks too).
func debug_fill() -> void:
	var state = CoreRoot.get_state()
	var sites: Dictionary = (state.biz as Dictionary).get("sites", {})
	for sk in CoreRoot.actions.biz_store_racks(key):
		var site: Dictionary = sites.get(str(sk), {})
		if site.is_empty():
			continue
		var gifts := {}
		for g in RULES.goods(str(site["kind"])):
			gifts[g] = RULES.cap_of(str(site["kind"]), str(g), site)
		CoreRoot.actions.biz_gift(str(sk), gifts)
	_t = 0.0
