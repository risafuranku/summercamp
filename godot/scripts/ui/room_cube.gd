extends RefCounted

## A room drawn once from its middle into six square pictures (the faces of a cube), for its
## windows seen from the camp from far off (materials/window_cube.gdshader: the ray from your
## eye through the pane on into the room's box, its colour from these): the room as it is,
## its things where they stand, not a painted stand-in (the user 4. 11.: "the interiors of
## the cabins and the buildings must show through the windows from far off too; now they
## are not there, and you see them pop in as they start to be drawn when you come near").
## Each picture is a SubViewport drawn once and kept: nothing is read back from the GPU. Drawn,
## it leaves the world's list of those looking at it (a world takes 64 that use visibility
## ranges, six a room kind ran them out in a built-up camp: the error in the log, and past the
## 64th the views out of the windows lost what has a range).

## The faces, [forward, up] each, right = forward x up: the shader has the same table.
const FACES := [
	[Vector3(1, 0, 0), Vector3(0, 1, 0)],
	[Vector3(-1, 0, 0), Vector3(0, 1, 0)],
	[Vector3(0, 1, 0), Vector3(0, 0, 1)],
	[Vector3(0, -1, 0), Vector3(0, 0, -1)],
	[Vector3(0, 0, 1), Vector3(0, 1, 0)],
	[Vector3(0, 0, -1), Vector3(0, 1, 0)],
]
const SLOTS := ["face_px", "face_nx", "face_py", "face_ny", "face_pz", "face_nz"]
const PX := 192


## Six SubViewports under `host` drawing `world` from `eye` (global in that world), each once
## with the next frame; the six textures (in SLOTS' order).
static func bake(host: Node, world: World3D, eye: Vector3, cull_mask: int, px := PX) -> Array:
	var out: Array = []
	for f in FACES:
		var vp := SubViewport.new()
		vp.name = "RoomCube"
		vp.size = Vector2i(px, px)
		vp.world_3d = world
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		host.add_child(vp)
		var cam := Camera3D.new()
		cam.fov = 90.0
		cam.near = 0.05
		cam.far = 40.0
		cam.cull_mask = cull_mask
		var fwd: Vector3 = f[0]
		var up: Vector3 = f[1]
		cam.transform = Transform3D(Basis(fwd.cross(up), up, -fwd), eye)
		vp.add_child(cam)
		out.append(vp.get_texture())
		_drawn(vp)
	return out


static func _drawn(vp: SubViewport) -> void:
	await RenderingServer.frame_post_draw
	if is_instance_valid(vp):
		RenderingServer.viewport_set_scenario(vp.get_viewport_rid(), RID())


## A pane's material for one building: `tex` from bake(), the room's box and the eye it was
## drawn from (room space), and the camp -> the room.
static func material(tex: Array, box: AABB, eye: Vector3, world_to_room: Transform3D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://materials/window_cube.gdshader")
	for i in SLOTS.size():
		m.set_shader_parameter(SLOTS[i], tex[i])
	m.set_shader_parameter("box_min", box.position)
	m.set_shader_parameter("box_max", box.end)
	m.set_shader_parameter("eye", eye)
	m.set_shader_parameter("w2r_x", world_to_room.basis.x)
	m.set_shader_parameter("w2r_y", world_to_room.basis.y)
	m.set_shader_parameter("w2r_z", world_to_room.basis.z)
	m.set_shader_parameter("w2r_o", world_to_room.origin)
	return m
