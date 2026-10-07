extends Node

## Blood spatter when the player is hurt: chunks fly from the camera along jittered
## rays, land on whatever they hit and leave a pixel decal that fades after a few
## minutes. Extracted from main.gd; main forwards damage tiers here.
##
## Budget: at most MAX_DECALS decals live at once (oldest go first). Chunk and decal
## materials are shared; per-decal opacity variation uses MeshInstance3D.transparency,
## which the fade-out animates anyway.

const TIER_SMALL := 0
const TIER_LETHAL := 4
const CHUNK_COUNTS := [6, 12, 18, 28, 40]
const SPREAD := [0.30, 0.45, 0.62, 0.86, 1.08]
const FADE_DELAY_SEC := 180.0
const FADE_DURATION_SEC := 34.0
const RAY_DISTANCE := 11.5
const CHUNK_SPEED_MIN := 12.0
const CHUNK_SPEED_MAX := 24.0
const MAX_DECALS := 260

var _world: Node3D
var _camera_getter: Callable
var _exclude_getter: Callable
var _root: Node3D
var _decals: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()
var _chunk_mat: StandardMaterial3D
var _decal_mat: StandardMaterial3D


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
	var chunk_count := int(CHUNK_COUNTS[tier_idx])
	if fatal_hit:
		chunk_count += 10
	for _i in range(chunk_count):
		_spawn_chunk(camera, tier_idx)


func clear() -> void:
	_decals.clear()
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = null


func _ensure_root() -> void:
	if _root != null and is_instance_valid(_root):
		return
	_root = Node3D.new()
	_root.name = "BloodFxRoot"
	_world.add_child(_root)


func _spawn_chunk(camera: Camera3D, tier_idx: int) -> void:
	var forward := -camera.global_transform.basis.z
	var right := camera.global_transform.basis.x
	var up := camera.global_transform.basis.y
	var spread := float(SPREAD[tier_idx])
	var direction := (
		forward * _rng.randf_range(0.35, 1.0)
		+ right * _rng.randf_range(-spread, spread)
		+ up * _rng.randf_range(-0.38, 0.54 + spread * 0.2)
	).normalized()
	if direction.length_squared() < 0.0001:
		direction = forward

	var origin := camera.global_transform.origin + forward * 0.18 + up * -0.05
	var hit := _raycast(origin, direction)
	var target_pos := origin + direction * _rng.randf_range(2.4, 4.8)
	var target_normal := Vector3.UP
	if not hit.is_empty():
		target_pos = hit.get("position", target_pos)
		var hit_normal_any = hit.get("normal", Vector3.UP)
		if hit_normal_any is Vector3:
			target_normal = (hit_normal_any as Vector3).normalized()
		if target_normal.length_squared() < 0.0001:
			target_normal = Vector3.UP

	var chunk := MeshInstance3D.new()
	chunk.name = "BloodChunk"
	var box := BoxMesh.new()
	box.size = Vector3.ONE * _rng.randf_range(0.010, 0.028) * (1.0 + float(tier_idx) * 0.20)
	chunk.mesh = box
	chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chunk.material_override = _chunk_material()
	_root.add_child(chunk)
	chunk.global_position = origin

	var speed := _rng.randf_range(CHUNK_SPEED_MIN, CHUNK_SPEED_MAX)
	var duration := clampf(origin.distance_to(target_pos) / maxf(speed, 0.01), 0.08, 0.34)
	var tween := chunk.create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(chunk, "global_position", target_pos, duration)
	tween.finished.connect(func():
		if not is_instance_valid(chunk):
			return
		_spawn_decal(target_pos, target_normal, tier_idx)
		chunk.queue_free()
	)


func _raycast(origin: Vector3, direction: Vector3) -> Dictionary:
	if _world.get_world_3d() == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * RAY_DISTANCE)
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
	var base_size := 0.12 + (float(tier_idx) * 0.07)
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
