extends RefCounted

## Inside the camp's warehouse (playtest 14. 11.: "SKLAD an indoor building like the staffroom,
## the inside working like the whole game, the vibe of the reception's store room or the
## staffroom's boiler room"). Built by scripts/service_interior.gd for the "store" profile,
## in the building's room (service_plan.STORE) in the camp's own world. A plank-walled box
## under one bare bulb: steel racks along the back and the left wall, the junk of years by the
## right one. Each rack is given to one of the camp's places (click it: the next place, after
## the last none; actions.biz_set_rack, co-op through the books); its chalked board says which,
## and on it stand that place's goods beyond its own shelf as boxes (business_rules.own_cap,
## RACK_PACKS packs a good at most), looked at again every couple of seconds while you are in.

const K = preload("res://scripts/interior_kit.gd")
const PLAN = preload("res://scripts/service_plan.gd")
const RULES = preload("res://core/systems/business_rules.gd")
const HOVER_GLINT = preload("res://scripts/ui/hover_glint.gd")
const FONT := "res://assets/fonts/w95b.fnt"
const SFX_PICK := "res://assets/sfx/rednecksfx/rrtick.wav"
const LOOK_SEC := 2.0
## A rack: its width and depth, its shelves' heights, a box's size.
const RACK_W := 1.0
const RACK_D := 0.46
const RACK_H := 1.85
const SHELVES := [0.3, 0.84, 1.38]
const BOX := Vector3(0.29, 0.26, 0.34)

var host                      # service_interior
var root: Node3D
var key := ""
## The racks in room space: [{pos, yaw}] (the first three along the back, one by the left wall).
var racks: Array = []
var glint = HOVER_GLINT.new()
var _tags: Array = []
var _boxes: Array = []         # per rack: [MeshInstance3D]
var _rack_meshes: Array = []   # per rack: [MeshInstance3D]
var _rack_nodes: Array = []    # per rack: Node3D (its own space: +Z its front)
var _hover := -1
var _t := 0.0
var _sfx: AudioStreamPlayer


func build(host_node, parent: Node3D) -> void:
	host = host_node
	root = Node3D.new()
	root.name = "StoreRoom"
	parent.add_child(root)
	_sfx = AudioStreamPlayer.new()
	host.add_child(_sfx)
	var size: Vector3 = PLAN.STORE
	K.room(root, size, "concrete", ["hut_planks", "hut_planks", "hut_planks", "hut_planks"], "ceiling_board", 1.4, 1.2)
	var back := -size.z * 0.5
	var left := -size.x * 0.5
	var steel := K.surface("galvanized", 0.6, Color(0.86, 0.88, 0.9))
	for i in 3:
		racks.append({"pos": Vector3(-1.6 + 1.6 * float(i), 0.0, back + RACK_D * 0.5 + 0.06), "yaw": 0.0})
	racks.append({"pos": Vector3(left + RACK_D * 0.5 + 0.06, 0.0, 0.15), "yaw": PI * 0.5})
	for i in racks.size():
		_build_rack(i, steel)
	_build_junk(size)
	_build_bulb(size)


func _build_rack(i: int, steel: Material) -> void:
	var r := Node3D.new()
	r.name = "Rack%d" % i
	r.position = racks[i]["pos"]
	r.rotation.y = float(racks[i]["yaw"])
	root.add_child(r)
	_rack_nodes.append(r)
	var meshes: Array = []
	for s: float in [-1.0, 1.0]:
		for f: float in [-1.0, 1.0]:
			meshes.append(K.slab(r, Vector3(0.05, RACK_H, 0.05), Vector3(s * (RACK_W * 0.5 - 0.02), RACK_H * 0.5, f * (RACK_D * 0.5 - 0.02)), steel, "RackPost"))
	for y: float in SHELVES:
		meshes.append(K.slab(r, Vector3(RACK_W, 0.04, RACK_D), Vector3(0, y, 0), steel, "RackShelf"))
	# The board on top, chalked with the place it is given to.
	var board := K.slab(r, Vector3(0.62, 0.2, 0.025), Vector3(0, RACK_H + 0.08, RACK_D * 0.5 - 0.02), K.surface("planks_dark", 0.5, Color(0.42, 0.4, 0.38)), "RackBoard")
	meshes.append(board)
	_rack_meshes.append(meshes)
	var tag := Label3D.new()
	if ResourceLoader.exists(FONT):
		tag.font = load(FONT)
	tag.pixel_size = 0.0032
	tag.font_size = 32
	tag.modulate = Color(0.95, 0.93, 0.86)
	tag.outline_size = 0
	tag.shaded = true
	tag.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	tag.position = Vector3(0, RACK_H + 0.08, RACK_D * 0.5 + 0.002)
	r.add_child(tag)
	_tags.append(tag)
	_boxes.append([])
	# Clicked anywhere on it.
	var body := StaticBody3D.new()
	body.set_meta("store_rack", i)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(RACK_W, RACK_H + 0.3, RACK_D)
	shape.shape = box
	shape.position = Vector3(0, (RACK_H + 0.3) * 0.5, 0)
	body.add_child(shape)
	r.add_child(body)


## What years of a camp leave in its store: crates, a chair, a bucket, the coats on their hooks,
## a shelf of odds and ends, a broom against the wall.
func _build_junk(size: Vector3) -> void:
	var right := size.x * 0.5
	var back := -size.z * 0.5
	K.prop(root, "beer_crates", Vector3(right - 0.45, 0.0, back + 0.55), 12.0)
	K.prop(root, "cardboard_boxes", Vector3(right - 0.5, 0.0, 0.35), -20.0)
	K.prop(root, "folding_chair", Vector3(right - 1.15, 0.0, 0.9), 200.0)
	K.prop(root, "slop_bucket", Vector3(right - 0.35, 0.0, 1.2), 0.0)
	K.prop(root, "coat_hooks", Vector3(right - 0.02, 1.55, -0.6), -90.0)
	K.prop(root, "wall_shelf", Vector3(right - 0.12, 1.25, back + 1.55), -90.0)
	var broom := K.slab(root, Vector3(0.03, 1.3, 0.03), Vector3(right - 0.12, 0.66, 1.62), K.surface("planks_dark", 0.4), "BroomStick")
	broom.rotation_degrees.z = 8.0
	K.slab(root, Vector3(0.28, 0.1, 0.08), Vector3(right - 0.03, 0.06, 1.62), K.surface("cardboard", 0.3, Color(0.5, 0.42, 0.3)), "BroomHead")


## The bare bulb on its cord in the middle of the ceiling (the room's own light hangs there:
## service_interior's main light, its switch by the door).
func _build_bulb(size: Vector3) -> void:
	var at := Vector3(0.0, size.y - 0.42, -0.1)
	var cord := K.slab(root, Vector3(0.012, 0.4, 0.012), at + Vector3(0, 0.23, 0), K.surface("planks_dark", 0.2, Color(0.12, 0.12, 0.12)), "Cord")
	cord.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bulb := MeshInstance3D.new()
	bulb.name = "Bulb"
	var s := SphereMesh.new()
	s.radius = 0.045
	s.height = 0.11
	s.radial_segments = 8
	s.rings = 4
	bulb.mesh = s
	bulb.position = at
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.86, 0.72)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.84, 0.52)
	bulb.material_override = m
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bulb)


## Where the bulb is (room space): the room's light hangs there.
func bulb_at() -> Vector3:
	return Vector3(0.0, PLAN.STORE.y - 0.5, -0.1)


## Where you stand coming in: just inside the door, looking at the racks.
func stand(camera: Camera3D) -> void:
	if camera == null:
		return
	camera.position = Vector3(0.25, 1.52, PLAN.STORE.z * 0.5 - 0.55)
	camera.rotation_degrees = Vector3(-10.0, 8.0, 0.0)


## Walked in to the warehouse of `building_key` ("x:y"): its racks as the books have them.
func on_open(building_key: String) -> void:
	key = building_key
	_t = 0.0
	refresh()


func tick(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = LOOK_SEC
	refresh()


## The books as they are now on the racks: the boards and the boxes.
func refresh() -> void:
	var state = CoreRoot.get_state() if CoreRoot != null else null
	if state == null or key == "":
		return
	var given: Array = CoreRoot.actions.biz_store_racks(key)
	var sites: Dictionary = (state.biz as Dictionary).get("sites", {}) if state.biz is Dictionary else {}
	# Each place's goods beyond its own shelf, shared out over its racks in turn.
	var left := {}
	for i in mini(given.size(), racks.size()):
		var sk := str(given[i])
		var site: Dictionary = sites.get(sk, {})
		var kind := str(site.get("kind", ""))
		var tag := _tags[i] as Label3D
		tag.text = tr(str((RULES.KINDS.get(kind, {}) as Dictionary).get("name", ""))).to_upper() if kind != "" else "- - -"
		# Small enough to go on its board (STÁNEK S KUKUŘICÍ is twice CORN STAND).
		tag.font_size = clampi(int(300.0 / float(maxi(1, tag.text.length()))), 14, 32)
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
		_set_boxes(i, on_rack)


## The boxes on rack `i`: one a good's pack, its name on its front, shelf by shelf.
func _set_boxes(i: int, goods: Array) -> void:
	var have: Array = _boxes[i]
	var per_shelf := int(floor(RACK_W / (BOX.x + 0.02)))
	goods = goods.slice(0, per_shelf * SHELVES.size())
	while have.size() > goods.size():
		var b: Node = have.pop_back()
		if is_instance_valid(b):
			b.queue_free()
	var rack: Node3D = _rack_nodes[i]
	for j in goods.size():
		var b: MeshInstance3D
		if j < have.size():
			b = have[j]
		else:
			b = K.slab(rack, BOX, Vector3.ZERO, K.surface("cardboard", 0.6), "Box")
			var name_l := Label3D.new()
			if ResourceLoader.exists(FONT):
				name_l.font = load(FONT)
			name_l.pixel_size = 0.0025
			name_l.font_size = 24
			name_l.modulate = Color(0.16, 0.1, 0.06)
			name_l.outline_size = 0
			name_l.shaded = true
			name_l.position = Vector3(0, 0.02, BOX.z * 0.5 + 0.004)
			name_l.name = "Name"
			b.add_child(name_l)
			have.append(b)
		var shelf := mini(j / maxi(1, per_shelf), SHELVES.size() - 1)
		var col := j % maxi(1, per_shelf)
		b.position = Vector3(-RACK_W * 0.5 + (BOX.x + 0.02) * (float(col) + 0.5) + 0.02, float(SHELVES[shelf]) + 0.02 + BOX.y * 0.5, 0.02)
		var g := str(goods[j][0])
		var kind := str(goods[j][1])
		(b.get_node("Name") as Label3D).text = tr(str((RULES.goods(kind).get(g, {}) as Dictionary).get("label", g))).to_upper()


## How many boxes stand on rack `i` now (the shot driver's check).
func boxes_on(i: int) -> int:
	return (_boxes[i] as Array).size() if i >= 0 and i < _boxes.size() else 0


func tag_of(i: int) -> String:
	return (_tags[i] as Label3D).text if i >= 0 and i < _tags.size() else ""


# ── hover and click ──────────────────────────────────────────────────────────

func update_hover(mouse: Vector2) -> int:
	var hit: Dictionary = host._raycast_world(mouse)
	var n = hit.get("collider", null) as Node
	var id := -1
	while n != null:
		if n.has_meta("store_rack"):
			id = int(n.get_meta("store_rack"))
			break
		n = n.get_parent()
	_hover = id
	if id >= 0:
		HandCursor.want(HandCursor.POINT)
		glint.show_on(_rack_meshes[id])
	else:
		glint.clear()
	return id


func click() -> bool:
	if _hover < 0:
		return false
	next_place(_hover)
	return true


## Rack `i` given to the next of the camp's places (by the plan's order), after the last to
## none.
func next_place(i: int) -> void:
	if CoreRoot == null or key == "" or i < 0 or i >= racks.size():
		return
	var state = CoreRoot.get_state()
	var sites: Array = ((state.biz as Dictionary).get("sites", {}) as Dictionary).keys() if state.biz is Dictionary else []
	sites.sort()
	var now := str(CoreRoot.actions.biz_store_racks(key)[i])
	var at_i := sites.find(now)
	var next := str(sites[at_i + 1]) if at_i + 1 < sites.size() else ""
	CoreRoot.actions.biz_set_rack(key, i, next)
	if ResourceLoader.exists(SFX_PICK):
		_sfx.stream = load(SFX_PICK)
		_sfx.volume_db = -10.0
		_sfx.play()
	refresh()


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
	refresh()
