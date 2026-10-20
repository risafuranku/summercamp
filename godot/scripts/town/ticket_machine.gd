extends RefCounted

## The yellow ticket machine at a stop of the 380, the kind that stood on street poles
## in the nineties (Grok face_ticket_machine -> assets/textury/town/ticket_machine_face.png):
## a fibreglass box on its pole, a cash box under it. Click it and a ticket drops out
## (building_type "trip_ticket_machine": town_trip.gd takes PRICE and puts the ticket in
## the bag, to be punched on the bus).

const TEX := "res://assets/textury/town/"
const PRICE := 2


## The machine on its pole at `pos` in `parent`'s frame, its front looking along the
## parent's local +z turned by `yaw`. Clicked, town_trip.gd opens its close-up.
## `stop`: "camp" or "town", whose fares its close-up offers (ticket_machine_closeup.gd).
static func place(parent: Node3D, pos: Vector3, yaw: float, stop := "camp") -> Node3D:
	var root := Node3D.new()
	root.name = "TicketMachine"
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	var grey := _mat(null, Color(0.4, 0.42, 0.4))
	var yellow := _mat(null, Color(0.86, 0.64, 0.16))
	_box(root, Vector3(0, 1.0, -0.2), Vector3(0.08, 2.0, 0.08), grey)
	# The machine and the cash box under it, sized to the face picture.
	_box(root, Vector3(0, 1.13, 0), Vector3(0.56, 0.96, 0.3), yellow)
	_box(root, Vector3(0, 0.53, 0.02), Vector3(0.38, 0.22, 0.24), yellow)
	var face_path := TEX + "ticket_machine_face.png"
	if ResourceLoader.exists(face_path):
		var tex: Texture2D = load(face_path)
		var face := MeshInstance3D.new()
		var q := QuadMesh.new()
		var h := 1.2
		q.size = Vector2(h * float(tex.get_width()) / float(tex.get_height()), h)
		face.mesh = q
		face.position = Vector3(0, 1.02, 0.152)
		var m := _mat(tex, Color(1, 1, 1))
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		face.material_override = m
		root.add_child(face)
	var body := StaticBody3D.new()
	body.collision_layer = 1 << 11
	body.collision_mask = 0
	body.set_meta("building_type", "trip_ticket_machine")
	body.set_meta("stop", stop)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 1.4, 0.5)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0, 1.0, 0.05)
	root.add_child(body)
	var solid := StaticBody3D.new()
	var s2 := CollisionShape3D.new()
	var b2 := BoxShape3D.new()
	b2.size = Vector3(0.46, 1.6, 0.32)
	s2.shape = b2
	solid.add_child(s2)
	solid.position = Vector3(0, 0.8, 0)
	root.add_child(solid)
	return root


static func _mat(tex: Texture2D, tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	return m


static func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
