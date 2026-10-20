extends RefCounted

## A window of a room that looks out into the camp for real (the user, 20. 10.: "every
## building has windows with a real 3D view of what you would see from that window where
## the building stands, and curtains you can draw"), the way the reception's and the
## cabins' windows already did:
##   the glass    a quad in the opening showing a viewport of the camp's world, its camera
##                where your eye is, mapped out through the same window of the building
##                outside, the window its near plane (off-axis), so it moves as you look;
##   the curtain  a pair of drapes on a rod (scripts/reception/curtain.gd) with a click
##                box (meta interior_click_type "window_curtain", window_portal = this);
##   the flash    the Photographer's flash through it (scripts/enemies/tourist_brain.gd):
##                the glass goes white and a cold light pops in the room, dimmed behind a
##                drawn curtain (which glows instead).
## The room gives `room_to_world`: room space -> the camp (window_portal.room_to_world()
## builds it for a building: the room lies in the building's footprint, its front on the
## building's front).

const CURTAIN = preload("res://scripts/reception/curtain.gd")
const GLASS_LAYER := 1 << 19
const FLASH_SEC := 0.45

var vp: SubViewport
var cam: Camera3D
var quad: MeshInstance3D
var frame: Transform3D        # room space: origin the glass's middle, -Z out
var size: Vector2
var outward: Vector3          # room space
var curtain                   # curtain.gd or null
var body: StaticBody3D        # the curtain's click box
var light: OmniLight3D
var _flash := 0.0
var _mat: StandardMaterial3D
var _live := false


## A window in `room` (a Node3D of the room, room space) at `centre`, facing `outward`
## (room space, horizontal), `size` metres; viewport nodes under `host`. `curtain_tex` ""
## for none.
static func make(host: Node, room: Node3D, centre: Vector3, out_dir: Vector3, glass: Vector2, curtain_tex := "curtain_floral", px := 224, wood_frame := true):
	var w = load("res://scripts/ui/window_portal.gd").new()
	w._build(host, room, centre, out_dir, glass, curtain_tex, px, wood_frame)
	return w


## `wood_frame` false: no sill and frame (a tent's doorway: the canvas is its frame).
func _build(host: Node, room: Node3D, centre: Vector3, out_dir: Vector3, glass: Vector2, curtain_tex: String, px: int, wood_frame := true) -> void:
	size = glass
	outward = Vector3(out_dir.x, 0.0, out_dir.z).normalized()
	var z := -outward
	var x := Vector3.UP.cross(z).normalized()
	frame = Transform3D(Basis(x, Vector3.UP, z), centre)
	vp = SubViewport.new()
	vp.name = "WindowView"
	vp.size = Vector2i(px, maxi(8, int(float(px) * glass.y / glass.x)))
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(vp)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_FRUSTUM
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.cull_mask = 0xFFFFF & ~GLASS_LAYER
	vp.add_child(cam)
	quad = MeshInstance3D.new()
	quad.name = "WindowGlass"
	var q := QuadMesh.new()
	q.size = glass
	quad.mesh = q
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_mat.albedo_texture = vp.get_texture()
	quad.material_override = _mat
	quad.transform = frame
	room.add_child(quad)
	# A sill and a frame round it (pine), so it reads as a window from across the room.
	var K = load("res://scripts/interior_kit.gd")
	var wood = K.surface("knotty_pine", 0.6)
	var holder := Node3D.new()
	holder.name = "WindowFrame"
	holder.transform = Transform3D(frame.basis, centre)
	room.add_child(holder)
	if wood_frame:
		K.slab(holder, Vector3(glass.x + 0.12, 0.06, 0.14), Vector3(0, -glass.y * 0.5 - 0.03, 0.05), wood, "Sill")
		K.slab(holder, Vector3(glass.x + 0.12, 0.06, 0.06), Vector3(0, glass.y * 0.5 + 0.03, 0.01), wood, "Top")
		for sx: float in [-1.0, 1.0]:
			K.slab(holder, Vector3(0.06, glass.y + 0.12, 0.06), Vector3(sx * (glass.x * 0.5 + 0.03), 0, 0.01), wood, "Side")
		K.slab(holder, Vector3(0.035, glass.y, 0.04), Vector3(0, 0, 0.0), wood, "Mullion")
	light = OmniLight3D.new()
	light.name = "WindowFlash"
	light.light_color = Color(0.9, 0.94, 1.0)
	light.light_energy = 0.0
	light.omni_range = 6.0
	light.shadow_enabled = true
	light.position = centre - outward * 0.35
	room.add_child(light)
	if curtain_tex != "":
		curtain = CURTAIN.new()
		var yaw := rad_to_deg(atan2(-outward.x, -outward.z))
		curtain.build(room, centre - outward * 0.09, glass.x + 0.1, glass.y + 0.3, yaw, curtain_tex, 0.7, host, true)
		body = StaticBody3D.new()
		body.name = "CurtainBody"
		body.set_meta("interior_click_type", "window_curtain")
		body.set_meta("window_portal", self)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(glass.x + 0.5, glass.y + 0.4, 0.14)
		shape.shape = box
		body.add_child(shape)
		body.transform = Transform3D(frame.basis, centre - outward * 0.1)
		room.add_child(body)


## The building `anchor` (a structure in the camp) seen as the room: the room's origin on
## the middle of the building's walls (on the ground), its axes the anchor's; the window
## is pushed out to the building's wall on its side. So a window on the room's left wall
## looks out of the building's left wall, from where it stands in the camp.
static func room_to_world(anchor: Node3D, w, room_floor_y := 0.0) -> Transform3D:
	var box := building_box(anchor)
	var mid := box.get_center()
	var half := Vector2(box.size.x * 0.5, box.size.z * 0.5)
	var o: Vector3 = w.outward
	var c: Vector3 = w.frame.origin
	# Where its glass is on the building outside (anchor space): on the wall that way.
	var ext := Vector3(mid.x + c.x, box.position.y + c.y - room_floor_y, mid.z + c.z)
	if absf(o.x) > absf(o.z):
		ext.x = mid.x + signf(o.x) * (half.x + 0.03)
		ext.z = mid.z + clampf(c.z, -half.y + 0.4, half.y - 0.4)
	else:
		ext.z = mid.z + signf(o.z) * (half.y + 0.03)
		ext.x = mid.x + clampf(c.x, -half.x + 0.4, half.x - 0.4)
	return anchor.global_transform * Transform3D(Basis(), ext - c)


## The building's walls in its own space (meshes taller than a step; the roof's eaves
## trimmed a little): cached on the anchor.
static func building_box(anchor: Node3D) -> AABB:
	if anchor.has_meta("window_box"):
		return anchor.get_meta("window_box")
	var box := AABB()
	var first := true
	var inv := anchor.global_transform.affine_inverse()
	for m in anchor.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or not mi.visible:
			continue
		var bb: AABB = (inv * mi.global_transform) * mi.get_aabb()
		if bb.size.y < 0.4:
			continue
		box = bb if first else box.merge(bb)
		first = false
	if first:
		box = AABB(Vector3(-2.8, 0, -2.8), Vector3(5.6, 2.6, 5.6))
	elif anchor.has_meta("wall_size"):
		var ws: Vector3 = anchor.get_meta("wall_size")
		var c := box.get_center()
		box = AABB(Vector3(c.x - ws.x * 0.5, box.position.y, c.z - ws.z * 0.5), Vector3(ws.x, ws.y, ws.z))
	else:
		# The eaves stick out past the walls.
		box = AABB(box.position + Vector3(0.15, 0, 0.15), box.size - Vector3(0.3, 0, 0.3))
	anchor.set_meta("window_box", box)
	return box


## Each frame while the room is open. `room`: the room's node (room space), `eye`: the
## room's camera, `xform`: room_to_world, `live`: whether this window is to be drawn
## (its part of the building is the one you are in).
func update(room: Node3D, eye: Camera3D, xform: Transform3D, live: bool, world: World3D, delta: float) -> void:
	if curtain != null:
		curtain.update(delta)
	_flash = maxf(0.0, _flash - delta)
	var shut: bool = curtain != null and float(curtain.open) < 0.03
	var on: bool = live and not shut and world != null and eye != null
	if on:
		if vp.world_3d != world:
			vp.world_3d = world
		var e_room := room.global_transform.affine_inverse() * eye.global_position
		var e := frame.affine_inverse() * e_room
		if e.z < 0.05:
			on = false
		else:
			cam.global_transform = Transform3D(xform.basis * frame.basis, xform * e_room)
			cam.set_frustum(size.y, Vector2(-e.x, -e.y), e.z + 0.06, e.z + 240.0)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	_live = on
	# The flash: the glass white, a cold light in the room (behind a curtain: the cloth
	# lit through, a little light round its edges).
	var f := pow(_flash / FLASH_SEC, 1.6) if _flash > 0.0 else 0.0
	var through := 1.0 if curtain == null else lerpf(0.18, 1.0, curtain.open)
	light.light_energy = 9.0 * f * through
	_mat.albedo_texture = vp.get_texture() if on else null
	_mat.albedo_color = Color(1, 1, 1).lerp(Color(4, 4, 4), f) if on else Color(0.05, 0.06, 0.08).lerp(Color(3, 3, 3), f)
	if curtain != null:
		for m in curtain.meshes:
			var mi := m as MeshInstance3D
			var cm := mi.material_override as StandardMaterial3D
			if cm == null:
				continue
			if f > 0.0 and not cm.has_meta("flash_own"):
				cm = cm.duplicate()
				cm.set_meta("flash_own", true)
				mi.material_override = cm
			if cm.has_meta("flash_own"):
				cm.emission_enabled = f > 0.0
				cm.emission = Color(0.9, 0.92, 1.0) * f * 1.5


func toggle_curtain() -> void:
	if curtain != null:
		curtain.toggle()


func curtain_open() -> float:
	return 1.0 if curtain == null else float(curtain.open)


func set_curtain(open: bool, instant := false) -> void:
	if curtain != null and curtain.is_open() != open:
		curtain.set_open(open, instant)


func flash() -> void:
	_flash = FLASH_SEC


## Where the glass is in the camp and which way it faces: {pos, out} (world).
func outside(xform: Transform3D) -> Dictionary:
	return {"pos": xform * frame.origin, "out": (xform.basis * outward).normalized()}


## How squarely the room's eye looks at the window (1 straight at it, below 0 away).
func facing(room: Node3D, eye: Camera3D) -> float:
	if eye == null:
		return -1.0
	var at := room.global_transform * frame.origin
	var to := (at - eye.global_position).normalized()
	return (-eye.global_transform.basis.z).dot(to)


func free_all() -> void:
	if vp != null and is_instance_valid(vp):
		vp.queue_free()
