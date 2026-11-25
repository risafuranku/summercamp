extends Node3D

## The wholesaler's boxes (docs/businesses.md, Rozhodnutí 25. 11., kolo 2: „Krabice u závory“):
## the van's driver stacks a box a place on the pallet just inside the barrier
## (actions.biz_unload, biz["boxes"]); its goods are on that place's shelves only once the box
## is carried in (actions.biz_box_in). E takes one into your arms (scripts/ambient/carry.gd:
## the box in both arms, slower), at its place E carries it in; set down anywhere else it lies
## there till somebody picks it up again. Drawn on every machine from the books as each one
## has them (the host's: the co-op pulse); what is done to a box goes to the host
## (actions._biz_tell). Main makes it, the carry asks it.

const INSTANCE = preload("res://scripts/instance/instance.gd")
const BIZ_RULES = preload("res://core/systems/business_rules.gd")
const BOX_TEX := "res://assets/textury/camp/cardboard.png"
const PALLET_TEX := "res://assets/textury/camp/planks_grey.png"
const BOX := Vector3(0.52, 0.36, 0.4)
## A box taken up, set down (ElevenLabs, tools/audiogen/prompts_delivery.tsv).
const SFX := {"lift": "res://assets/sfx/world/box_lift.mp3", "down": "res://assets/sfx/world/box_down.mp3"}
## How near a box's place you carry it in (metres past the building's own half-size).
const PLACE_REACH := 2.6
const LOOK_SEC := 0.25

var main: Node
## Boxes a place's hand is on the way to (hands_commute sets it as it draws them): still on
## the pallet till they get there.
static var fetching: Dictionary = {}
var _pallet: MeshInstance3D
var _boxes: Dictionary = {}       # id -> MeshInstance3D
var _box_mat: StandardMaterial3D
var _t := 0.0
var _snd: AudioStreamPlayer3D


## Where the pallet stands: inside the barrier, beside the lane on the side the van stops.
static func spot(gate: Node) -> Vector3:
	return Vector3(float(gate.get("gap_center_x")) - 2.2, 0.0, float(gate.get("fence_z")) + 2.4)


func _ready() -> void:
	add_to_group("delivery_pallet")
	_box_mat = _mat(BOX_TEX, Vector3(1.4, 1.4, 1.4))
	_snd = AudioStreamPlayer3D.new()
	_snd.max_distance = 30.0
	_snd.unit_size = 3.0
	_snd.bus = "OutdoorAmbience" if AudioServer.get_bus_index("OutdoorAmbience") >= 0 else "Master"
	add_child(_snd)
	# Loaded now, not at the first box (a hitch).
	for k in SFX:
		if ResourceLoader.exists(str(SFX[k])):
			load(str(SFX[k]))


## A box's sound at `at`: "lift" or "down".
func play_box(at: Vector3, what: String) -> void:
	var path := str(SFX.get(what, ""))
	if _snd == null or not ResourceLoader.exists(path):
		return
	_snd.stream = load(path)
	_snd.global_position = at
	_snd.pitch_scale = randf_range(0.94, 1.05)
	_snd.play()


func _mat(path: String, uv: Vector3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	m.uv1_triplanar = true
	m.uv1_scale = uv
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
	return m


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = LOOK_SEC
	_sync()


func _boxes_now() -> Array:
	var st = INSTANCE.core(self).get_state() if INSTANCE.core(self) != null else null
	var b = st.biz if st != null else null
	return (b as Dictionary).get("boxes", []) if b is Dictionary else []


func _ground_y() -> float:
	var gm = main.get("grid_manager") if main != null else null
	return float(gm.grid_to_world(Vector2i.ZERO).y) if gm != null else 0.0


## The pallet and the boxes as the books have them: on the pallet (stacked two by two,
## three high), set down where they were, none for a box in somebody's arms.
func _sync() -> void:
	var gate := get_tree().get_first_node_in_group("camp_gate") if get_tree() != null else null
	if gate == null:
		return
	var base := spot(gate)
	base.y = _ground_y()
	var boxes := _boxes_now()
	if _pallet == null and not boxes.is_empty():
		_pallet = MeshInstance3D.new()
		_pallet.name = "Pallet"
		var pm := BoxMesh.new()
		pm.size = Vector3(1.2, 0.14, 1.0)
		_pallet.mesh = pm
		_pallet.material_override = _mat(PALLET_TEX, Vector3(1.6, 1.6, 1.6))
		add_child(_pallet)
	if _pallet != null:
		_pallet.global_position = base + Vector3(0, 0.07, 0)
		_pallet.visible = not boxes.is_empty()
	var seen := {}
	var slot := 0
	for bx in boxes:
		var id := int(bx["id"])
		if str(bx.get("by", "")) != "" and not fetching.has(id):
			continue
		seen[id] = true
		var m: MeshInstance3D = _boxes.get(id)
		if m == null or not is_instance_valid(m):
			m = MeshInstance3D.new()
			m.name = "VanBox%d" % id
			var bm := BoxMesh.new()
			bm.size = BOX
			m.mesh = bm
			m.material_override = _box_mat
			add_child(m)
			_boxes[id] = m
		var at = bx.get("at", null)
		if at is Array and (at as Array).size() >= 3:
			m.global_position = Vector3(float(at[0]), float(at[1]) + BOX.y * 0.5, float(at[2]))
			m.rotation.y = float(id % 5) * 0.31
		else:
			var col := slot % 2
			var row := (slot / 2) % 2
			var layer := slot / 4
			m.global_position = base + Vector3(-0.28 + 0.56 * col, 0.14 + BOX.y * (0.5 + layer), -0.22 + 0.44 * row)
			m.rotation.y = float(id % 3 - 1) * 0.06
			slot += 1
	for id in _boxes.keys():
		if not seen.has(id):
			(_boxes[id] as Node).queue_free()
			_boxes.erase(id)


## The box (its id) on the line of the look from `o` along `fwd`, within `reach`; -1 none.
func box_in_view(o: Vector3, fwd: Vector3, reach: float) -> int:
	var best := -1
	var best_d := INF
	for id in _boxes:
		var m: MeshInstance3D = _boxes[id]
		if not is_instance_valid(m) or not m.visible or fetching.has(id):
			continue
		var to := m.global_position - o
		var along := to.dot(fwd)
		if along < 0.2 or along > reach:
			continue
		var off := (to - fwd * along).length()
		if off < 0.42 and off < best_d:
			best_d = off
			best = int(id)
	return best


func box(id: int) -> Dictionary:
	for bx in _boxes_now():
		if int(bx["id"]) == id:
			return bx
	return {}


## The name of the place box `id` is for ("Pub", translated).
func place_name(id: int) -> String:
	var key := str(box(id).get("key", ""))
	var st = INSTANCE.core(self).get_state()
	var site: Dictionary = (st.biz.get("sites", {}) as Dictionary).get(key, {}) if st != null else {}
	return tr(str((BIZ_RULES.KINDS.get(str(site.get("kind", "")), {}) as Dictionary).get("name", "Business")))


## Whether `at` is by the place box `id` is for (near enough to carry it in).
func by_its_place(id: int, at: Vector3) -> bool:
	var key := str(box(id).get("key", ""))
	if not key.contains(":"):
		return false
	var origin := Vector2i(int(key.get_slice(":", 0)), int(key.get_slice(":", 1)))
	var gm = main.get("grid_manager") if main != null else null
	var st = INSTANCE.core(self).get_state()
	if gm == null or st == null:
		return false
	var fp: Vector2i = st.grid.footprint_of(origin)
	var c: Vector3 = gm.get_footprint_center(origin, fp)
	var half := float(maxi(fp.x, fp.y)) * float(gm.tile_size) * 0.5
	return Vector2(at.x - c.x, at.z - c.z).length() < half + PLACE_REACH


## Whether `at` is by the pallet (a box set down there goes back onto it).
func by_pallet(at: Vector3) -> bool:
	var gate := get_tree().get_first_node_in_group("camp_gate") if get_tree() != null else null
	if gate == null:
		return false
	var p := spot(gate)
	return Vector2(at.x - p.x, at.z - p.z).length() < 1.6
