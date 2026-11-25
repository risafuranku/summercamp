extends Node3D

## A building going up (core/systems/construction_rules.gd, Richard 24. 11.: „lešení, dělníci
## a bouchání, hosté dovnitř nemůžou“): on a concrete slab the plank walls rise with the work
## done, a wooden scaffold round them, a pile of planks by the front corner and two workers
## at it in the workers' day: one kneeling at the front driving nails (a blow every
## BLOW_SEC, the blow heard), the other standing by the pile. At night the site stands empty
## and still. building_manager.place_site_at makes it on the site's structure; it reads how
## far the work is (GameState.sites) a few times a second, the walls only move when that
## changed.

const INSTANCE = preload("res://scripts/instance/instance.gd")
const RULES = preload("res://core/systems/construction_rules.gd")
const CAMP := "res://assets/textury/camp/"
const WORKER := "res://assets/textury/npc/site/worker_a_"
const SFX := "res://assets/sfx/site/"
## The people's pixel (128 px to 1.74 m, staff_runtime).
const PERSON_M := 1.74
## How tall the walls end (the building's own, near enough), metres.
const HEIGHT := {"toilet_block": 2.3, "shower_block": 2.6, "cabin_1": 2.6, "staffroom": 2.8, "warehouse": 3.0,
	"corn_stand": 2.4, "pub": 2.6, "restaurant": 2.9, "vecerka": 3.6, "bowling": 4.4}
## The hammer: raised this long, down this long.
const BLOW_SEC := 0.75
const DOWN_SEC := 0.16
const LOOK_SEC := 0.25

## The site's origin key in GameState.sites ("x:y"), what it will be, its size in metres.
var key := ""
var target := ""
var size := Vector2(4, 4)
var _mat_of: Callable
var _walls: MeshInstance3D
var _walls_h := -1.0
var _workers: Array = []   # [kneeling Sprite3D, standing Sprite3D]
var _hammer: AudioStreamPlayer3D
var _hour := 12.0
var _t := 0.0
var _look_t := 0.0
var _down := false
var _tex := {}


## `mat_of`: (file, tint, category, uv) -> Material (building_models._camp_or).
func setup(site_key: String, what: String, metres: Vector2, mat_of: Callable) -> void:
	key = site_key
	target = what
	size = metres
	_mat_of = mat_of
	_build()


func _ready() -> void:
	var bus = INSTANCE.bus(self)
	if bus.has_signal("time_tick") and not bus.time_tick.is_connected(_on_time):
		bus.time_tick.connect(_on_time)
	var m = INSTANCE.main_of(self)
	if m != null and "_time_of_day_hours" in m:
		_hour = float(m.get("_time_of_day_hours"))
	_look()


func _on_time(hour: int, minute: int) -> void:
	_hour = float(hour) + float(minute) / 60.0


func _mat(file: String, tint := Color.WHITE, uv := Vector3.ONE) -> Material:
	return _mat_of.call(file, tint, "wood", uv) if _mat_of.is_valid() else StandardMaterial3D.new()


func _box(n: String, s: Vector3, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var b := BoxMesh.new()
	b.size = s
	mi.mesh = b
	mi.position = at
	mi.material_override = m
	add_child(mi)
	return mi


func _build() -> void:
	var w := size.x
	var d := size.y
	var top := float(HEIGHT.get(target, 2.6))
	_box("Slab", Vector3(w * 0.92, 0.14, d * 0.92), Vector3(0, 0.07, 0), _mat("concrete.png"))
	_walls = _box("Walls", Vector3(w * 0.8, 1.0, d * 0.8), Vector3(0, 0.6, 0), _mat("hut_planks.png"))
	# The scaffold: posts at the corners (and between on a long side), ledgers at two heights,
	# a walk of planks along the front and the back.
	var post := _mat("planks_dark.png")
	var deck := _mat("planks_grey.png")
	var hx := w * 0.46 + 0.18
	var hz := d * 0.46 + 0.18
	var ph := top + 0.7
	var xs := [-hx, hx]
	if w > 5.0:
		xs.insert(1, 0.0)
	var zs := [-hz, hz]
	if d > 5.0:
		zs.insert(1, 0.0)
	for x in xs:
		for z in [-hz, hz]:
			_box("Post", Vector3(0.1, ph, 0.1), Vector3(x, ph * 0.5, z), post)
	for z in zs:
		for x in [-hx, hx]:
			_box("Post", Vector3(0.1, ph, 0.1), Vector3(x, ph * 0.5, z), post)
	for y in [1.25, 2.45]:
		if y > ph - 0.2:
			continue
		for z in [-hz, hz]:
			_box("Ledger", Vector3(hx * 2.0 + 0.12, 0.07, 0.07), Vector3(0, y, z), post)
			_box("Walk", Vector3(hx * 2.0 + 0.1, 0.05, 0.34), Vector3(0, y + 0.06, z - signf(z) * 0.2), deck)
		for x in [-hx, hx]:
			_box("Ledger", Vector3(0.07, 0.07, hz * 2.0 + 0.12), Vector3(x, y, 0), post)
	# The planks waiting by the front left corner.
	var pile := _mat("planks_red.png")
	for i in 4:
		_box("Pile", Vector3(1.7, 0.07, 0.22), Vector3(-hx - 0.7, 0.04 + 0.075 * i, hz + 0.3 + 0.24 * (i % 2)), pile)
	# The workers and the hammer.
	for k in 2:
		var s := Sprite3D.new()
		s.name = "Worker%d" % k
		s.pixel_size = PERSON_M / 128.0
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		s.shaded = true
		s.centered = false
		add_child(s)
		_workers.append(s)
	(_workers[0] as Sprite3D).position = Vector3(-w * 0.18, 0.0, hz + 0.55)
	(_workers[1] as Sprite3D).position = Vector3(-hx - 0.6, 0.0, hz + 0.95)
	for f in ["stand", "up", "down"]:
		var p: String = WORKER + str(f) + ".png"
		_tex[f] = load(p) if ResourceLoader.exists(p) else null
	_hammer = AudioStreamPlayer3D.new()
	_hammer.max_distance = 45.0
	_hammer.unit_size = 4.0
	_hammer.volume_db = -6.0
	_hammer.bus = "OutdoorAmbience" if AudioServer.get_bus_index("OutdoorAmbience") >= 0 else "Master"
	_hammer.position = (_workers[0] as Sprite3D).position + Vector3(0.4, 0.3, 0)
	add_child(_hammer)
	_dress(_workers[1], "stand")


## A worker's picture, its feet (its left edge: the back boot in every frame) on the ground.
func _dress(s: Sprite3D, frame: String) -> void:
	var t: Texture2D = _tex.get(frame)
	s.texture = t
	if t != null:
		s.offset = Vector2(-float(t.get_width()) * 0.5 if frame == "stand" else -28.0, 0.0)


func _process(delta: float) -> void:
	_look_t -= delta
	if _look_t <= 0.0:
		_look_t = LOOK_SEC
		_look()
	if not (_workers[0] as Sprite3D).visible:
		return
	_t += delta
	var down := fmod(_t, BLOW_SEC) > BLOW_SEC - DOWN_SEC
	if down != _down:
		_down = down
		_dress(_workers[0], "down" if down else "up")
		if down and _hammer != null and is_visible_in_tree():
			_hammer.stream = load(SFX + ("hammer_a.mp3" if randf() < 0.6 else "hammer_b.mp3"))
			_hammer.pitch_scale = randf_range(0.92, 1.06)
			_hammer.play()


## How far the work is (the walls), whether the workers are at it now.
func _look() -> void:
	var core = INSTANCE.core(self)
	var st = core.get_state() if core != null else null
	if st == null:
		return
	var site: Dictionary = st.sites.get(key, {})
	var p := RULES.progress(site) if not site.is_empty() else 1.0
	var top := float(HEIGHT.get(target, 2.6))
	var h := snappedf(top * (0.15 + 0.85 * p), 0.05)
	if h != _walls_h and _walls != null:
		_walls_h = h
		(_walls.mesh as BoxMesh).size.y = h
		_walls.position.y = 0.14 + h * 0.5
	var at_work := RULES.works_at(_hour) and not site.is_empty()
	for s in _workers:
		(s as Sprite3D).visible = at_work
