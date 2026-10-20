extends Node3D

## Boot prints in the snow once it lies (Season.snow_cover >= 0.2): every warden's (you and
## the other wardens' figures, so each machine draws them all without a word on the wire)
## left and right foot by turns, a stride apart, turned the way they walked (Grok
## world/boot_print.png, 1 cm a pixel, lying on the ground). Falling snow fills them in:
## each goes two thirds, then a third see-through (Build's translucencies) and is gone,
## in a minute and a half while it snows, in ten minutes when it does not; the oldest
## goes first when there are more than the pool. Made by ground_life.gd.

const TEX := "res://assets/textury/world/boot_print.png"
const POOL := 64
const STRIDE := 0.72
const SIDE := 0.11
const LIFE_SNOWING := 90.0
const LIFE_STILL := 600.0

var player_getter: Callable

var _prints: Array = []          # {mesh, age, life}
var _next := 0
var _mats: Array = []            # fresh, two thirds, a third
var _feet: Dictionary = {}       # warden id -> {at: Vector3, walked: float, left: bool}
var _acc := 0.0


func _ready() -> void:
	name = "SnowPrints"
	var tex: Texture2D = load(TEX) if ResourceLoader.exists(TEX) else null
	if tex == null:
		return
	for level in [1.0, 0.66, 0.33]:
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		# The print's blue shadow warmed toward the snow's own grey (blue on the camp's
		# dirty snow it read as blue blots).
		m.albedo_color = Color(1.0, 0.9, 0.74)
		if level >= 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
		else:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(1.0, 0.9, 0.74, level)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats.append(m)
	var q := QuadMesh.new()
	q.size = Vector2(tex.get_width(), tex.get_height()) * 0.01
	for i in POOL:
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = _mats[0]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_prints.append({"mesh": mi, "age": 0.0, "life": LIFE_STILL})


func _process(delta: float) -> void:
	if _mats.is_empty():
		return
	_acc += delta
	if _acc < 1.0 / 12.0:
		return
	var dt := _acc
	_acc = 0.0
	var main := get_tree().current_scene
	if main == null or main.get("_time_of_day_hours") == null:
		return
	var hour := float(main.get("_time_of_day_hours"))
	var day := int(main.get("_day_index")) if main.get("_day_index") != null else 1
	var lies := Season.snow_cover(day, hour) >= 0.2
	var sl = main.get("_season_look")
	var snowing: bool = sl != null and sl.has_method("is_snowing") and bool(sl.call("is_snowing"))
	for p in _prints:
		var mi: MeshInstance3D = p["mesh"]
		if not mi.visible:
			continue
		p["age"] = float(p["age"]) + dt * (LIFE_STILL / LIFE_SNOWING if snowing else 1.0)
		var k := float(p["age"]) / float(p["life"])
		if k >= 1.0 or not lies:
			mi.visible = false
		else:
			mi.material_override = _mats[0] if k < 0.6 else (_mats[1] if k < 0.82 else _mats[2])
	if lies:
		_step_feet()


func _step_feet() -> void:
	var nodes: Array = []
	# ground_life is handed its getter after it made this: take it from there.
	if not player_getter.is_valid() and get_parent() != null and get_parent().get("player_getter") is Callable:
		player_getter = get_parent().get("player_getter")
	var me: Node3D = player_getter.call() if player_getter.is_valid() else null
	# Your own body is not drawn (you see through its eyes): it walks all the same.
	if me != null and me.is_inside_tree():
		nodes.append(me)
	for r in get_tree().get_nodes_in_group("coop_remote_player"):
		if r is Node3D and (r as Node3D).is_visible_in_tree():
			nodes.append(r)
	var seen: Dictionary = {}
	for n in nodes:
		var id := (n as Node).get_instance_id()
		seen[id] = true
		var at := (n as Node3D).global_position
		if not _feet.has(id):
			_feet[id] = {"at": at, "walked": 0.0, "left": true}
			continue
		var f: Dictionary = _feet[id]
		var last: Vector3 = f["at"]
		var d := Vector2(at.x - last.x, at.z - last.z)
		f["at"] = at
		# A door, a teleport, a seat: no walk.
		if d.length() > 3.0 or d.length() < 0.001:
			continue
		f["walked"] = float(f["walked"]) + d.length()
		if float(f["walked"]) < STRIDE:
			continue
		f["walked"] = 0.0
		f["left"] = not bool(f["left"])
		var dir := Vector3(d.x, 0, d.y).normalized()
		var side := Vector3(-dir.z, 0, dir.x) * (SIDE if bool(f["left"]) else -SIDE)
		_print_at(_ground(Vector3(at.x, at.y, at.z) + side), dir)
	for id in _feet.keys():
		if not seen.has(id):
			_feet.erase(id)


## The ground under a foot (the camp is not flat everywhere): a ray down onto it.
func _ground(at: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space != null:
		var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.5, at + Vector3.DOWN * 2.5)
		var me: Node3D = player_getter.call() if player_getter.is_valid() else null
		if me is CollisionObject3D:
			q.exclude = [(me as CollisionObject3D).get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			return hit["position"]
	return Vector3(at.x, 0.0, at.z)


func _print_at(at: Vector3, dir: Vector3) -> void:
	var p: Dictionary = _prints[_next]
	_next = (_next + 1) % _prints.size()
	var mi: MeshInstance3D = p["mesh"]
	# Lying flat, its toe the way they walked.
	var yaw := atan2(-dir.x, -dir.z)
	mi.global_transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI * 0.5), at + Vector3(0, 0.05, 0))
	mi.material_override = _mats[0]
	mi.visible = true
	p["age"] = 0.0
	p["life"] = LIFE_STILL
