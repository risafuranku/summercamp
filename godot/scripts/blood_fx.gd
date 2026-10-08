extends Node

## Blood when the player is hurt: a short spray of drops leaves the body, flies on a
## ballistic arc and lands. Where a drop lands it leaves a pixel stain that fades after
## a few minutes; a drop that lands on nothing (off the edge of the world) just goes.
## Nothing ever stops in mid-air. Extracted from main.gd; main forwards damage tiers.
##
## Budget: at most MAX_DECALS stains live at once (oldest go first), a handful of drops
## per hit. Drop and stain materials are shared; per-stain opacity variation uses
## MeshInstance3D.transparency, which the fade-out animates anyway.

const TIER_SMALL := 0
const TIER_LETHAL := 4
const DROP_COUNTS := [5, 7, 10, 14, 20]
const SPREAD := [0.35, 0.45, 0.60, 0.80, 1.00]
const FADE_DELAY_SEC := 180.0
const FADE_DURATION_SEC := 34.0
const DROP_SPEED_MIN := 2.6
const DROP_SPEED_MAX := 5.2
const GRAVITY := 9.8
## A drop that has not landed by then (fell off the world) is dropped.
const DROP_MAX_AGE := 2.0
const MAX_DECALS := 160

var _world: Node3D
var _camera_getter: Callable
var _exclude_getter: Callable
var _root: Node3D
var _decals: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()
var _chunk_mat: StandardMaterial3D
var _decal_mat: StandardMaterial3D
## Drops in flight: {node, pos, vel, age, tier}.
var _drops: Array[Dictionary] = []


## `camera_getter` returns the player Camera3D; `exclude_getter` returns the body the
## rays must ignore (the player).
func setup(world: Node3D, camera_getter: Callable, exclude_getter: Callable) -> void:
	_world = world
	_camera_getter = camera_getter
	_exclude_getter = exclude_getter
	_rng.randomize()


func spawn(tier: int, fatal_hit: bool) -> void:
	if _world == null:
		return
	var camera: Camera3D = _camera_getter.call() if _camera_getter.is_valid() else null
	if camera == null:
		return
	_ensure_root()
	var tier_idx := clampi(tier, TIER_SMALL, TIER_LETHAL)
	var count := int(DROP_COUNTS[tier_idx]) + (6 if fatal_hit else 0)
	for _i in range(count):
		_spawn_drop(camera, tier_idx)


func clear() -> void:
	_decals.clear()
	_drops.clear()
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = null


func _ensure_root() -> void:
	if _root != null and is_instance_valid(_root):
		return
	_root = Node3D.new()
	_root.name = "BloodFxRoot"
	_world.add_child(_root)


## Drops leave from chest height just in front of the eye, mostly forward and up, then
## gravity brings them down onto the ground or a wall within a couple of metres.
func _spawn_drop(camera: Camera3D, tier_idx: int) -> void:
	var basis := camera.global_transform.basis
	var forward := -basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	var right := basis.x
	var spread := float(SPREAD[tier_idx])
	var dir := (
		forward * _rng.randf_range(0.5, 1.0)
		+ right * _rng.randf_range(-spread, spread)
		+ Vector3.UP * _rng.randf_range(0.05, 0.55)
	).normalized()
	var origin := camera.global_transform.origin + forward * 0.25 + Vector3.DOWN * 0.35

	var drop := MeshInstance3D.new()
	drop.name = "BloodDrop"
	var box := BoxMesh.new()
	box.size = Vector3.ONE * _rng.randf_range(0.012, 0.03) * (1.0 + float(tier_idx) * 0.15)
	drop.mesh = box
	drop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	drop.material_override = _chunk_material()
	_root.add_child(drop)
	drop.global_position = origin
	_drops.append({
		"node": drop,
		"pos": origin,
		"vel": dir * _rng.randf_range(DROP_SPEED_MIN, DROP_SPEED_MAX),
		"age": 0.0,
		"tier": tier_idx,
	})


func _physics_process(delta: float) -> void:
	if _drops.is_empty():
		return
	var still: Array[Dictionary] = []
	for d in _drops:
		var node: MeshInstance3D = d["node"]
		if not is_instance_valid(node):
			continue
		var pos: Vector3 = d["pos"]
		var vel: Vector3 = d["vel"]
		vel.y -= GRAVITY * delta
		var next := pos + vel * delta
		var hit := _raycast_segment(pos, next)
		if not hit.is_empty():
			var n: Vector3 = hit.get("normal", Vector3.UP)
			_spawn_decal(hit["position"], n if n.length_squared() > 0.0001 else Vector3.UP, int(d["tier"]))
			node.queue_free()
			continue
		d["age"] = float(d["age"]) + delta
		if float(d["age"]) > DROP_MAX_AGE:
			node.queue_free()
			continue
		d["pos"] = next
		d["vel"] = vel
		node.global_position = next
		still.append(d)
	_drops = still


func _raycast_segment(from: Vector3, to: Vector3) -> Dictionary:
	if _world.get_world_3d() == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var exclude_body = _exclude_getter.call() if _exclude_getter.is_valid() else null
	if exclude_body is CollisionObject3D and is_instance_valid(exclude_body):
		query.exclude = [(exclude_body as CollisionObject3D).get_rid()]
	return _world.get_world_3d().direct_space_state.intersect_ray(query)


func _spawn_decal(hit_pos: Vector3, normal: Vector3, tier_idx: int) -> void:
	if _root == null or not is_instance_valid(_root):
		return
	var live: Array[Node3D] = []
	for d in _decals:
		if d != null and is_instance_valid(d):
			live.append(d)
	_decals = live
	while _decals.size() >= MAX_DECALS:
		var oldest = _decals.pop_front()
		if oldest != null and is_instance_valid(oldest):
			oldest.queue_free()

	var n := normal.normalized()
	if n.length_squared() < 0.0001:
		n = Vector3.UP
	var decal_root := Node3D.new()
	decal_root.name = "BloodDecal"
	_root.add_child(decal_root)
	decal_root.global_position = hit_pos + n * 0.012
	var up_hint := Vector3.UP
	if absf(n.dot(up_hint)) > 0.94:
		up_hint = Vector3.FORWARD
	decal_root.look_at(decal_root.global_position + n, up_hint, true)
	decal_root.rotate_object_local(Vector3.FORWARD, _rng.randf_range(-PI, PI))

	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	var base_size := 0.10 + (float(tier_idx) * 0.05)
	quad.size = Vector2(base_size * _rng.randf_range(0.72, 1.36), base_size * _rng.randf_range(0.64, 1.28))
	mesh.mesh = quad
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.material_override = _decal_material()
	mesh.transparency = _rng.randf_range(0.0, 0.26)
	decal_root.add_child(mesh)
	_decals.append(decal_root)

	var fade := decal_root.create_tween()
	fade.tween_interval(FADE_DELAY_SEC)
	fade.tween_property(mesh, "transparency", 1.0, FADE_DURATION_SEC)
	fade.finished.connect(func():
		if is_instance_valid(decal_root):
			decal_root.queue_free()
	)


func _chunk_material() -> StandardMaterial3D:
	if _chunk_mat == null:
		_chunk_mat = StandardMaterial3D.new()
		_chunk_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_chunk_mat.albedo_color = Color(0.62, 0.04, 0.04, 1.0)
		_chunk_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _chunk_mat


func _decal_material() -> StandardMaterial3D:
	if _decal_mat == null:
		_decal_mat = StandardMaterial3D.new()
		_decal_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_decal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_decal_mat.albedo_texture = _build_texture()
		_decal_mat.albedo_color = Color(0.72, 0.05, 0.05, 0.98)
		_decal_mat.emission_enabled = true
		_decal_mat.emission = Color(0.24, 0.0, 0.0, 1.0)
		_decal_mat.emission_energy_multiplier = 0.26
		_decal_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_decal_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _decal_mat


func _build_texture() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var local_rng := RandomNumberGenerator.new()
	local_rng.randomize()
	var center := Vector2(15.5, 15.5)
	for y in range(32):
		for x in range(32):
			var dist := Vector2(float(x), float(y)).distance_to(center) / 16.0
			var threshold := 0.28 + local_rng.randf_range(0.0, 0.62)
			if dist > threshold:
				continue
			if local_rng.randf() < 0.18 and dist > 0.35:
				continue
			var shade := local_rng.randf_range(0.0, 0.22)
			var alpha := clampf(1.0 - dist + local_rng.randf_range(-0.16, 0.22), 0.0, 1.0)
			img.set_pixel(x, y, Color(0.78 - shade, 0.03, 0.03, alpha))
	return ImageTexture.create_from_image(img)
