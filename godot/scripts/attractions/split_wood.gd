extends RefCounted

## The camp's firewood as split at the chopping block (scripts/attractions/log_split.gd):
## half a round of pine, its bark's half-cylinder, the split face and the two half ends.
## The halves that fly off the block, the woodpile's pieces and the ones on the fire are the
## same piece (playtest 14. 11.: "the logs put on the fire the split pieces, so it goes with
## the splitting"). Its length along local Y, centred; the bark round +X and the split face
## looking -X (`s` 1), or the other way (`s` -1).
## Children: "Log" (the bark), "End" (the rings at the ends), "Face" (the split face): the
## bark's and the wood's materials are found there by name (log_split._wood_mats).


static func half(r: float, h: float, s: float, bark: Material, wood: Material, seg := 6) -> Node3D:
	var n := Node3D.new()
	n.name = "SplitHalf"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg:
		var a0 := -PI * 0.5 + PI * float(i) / float(seg)
		var a1 := -PI * 0.5 + PI * float(i + 1) / float(seg)
		var p0 := Vector3(cos(a0) * r * s, 0, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r * s, 0, sin(a1) * r)
		var up := Vector3(0, h, 0)
		var nm := ((p0 + p1) * 0.5).normalized()
		# Clockwise seen from outside (Godot's front face): the bark was drawn from inside only.
		for v in ([p0, p1, p1 + up, p0, p1 + up, p0 + up] if s > 0.0 else [p0, p1 + up, p1, p0, p0 + up, p1 + up]):
			st.set_normal(nm)
			st.set_uv(Vector2(float(i) / float(seg), (v as Vector3).y / h))
			st.add_vertex(v - Vector3(0, h * 0.5, 0))
	var bark_m := MeshInstance3D.new()
	bark_m.name = "Log"
	bark_m.mesh = st.commit()
	bark_m.material_override = bark
	n.add_child(bark_m)
	var ends := SurfaceTool.new()
	ends.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y: float in [h * 0.5, -h * 0.5]:
		var top := y > 0.0
		for i in seg:
			var a0 := -PI * 0.5 + PI * float(i) / float(seg)
			var a1 := -PI * 0.5 + PI * float(i + 1) / float(seg)
			var c := Vector3(0, y, 0)
			var p0 := Vector3(cos(a0) * r * s, y, sin(a0) * r)
			var p1 := Vector3(cos(a1) * r * s, y, sin(a1) * r)
			var tri: Array = [c, p0, p1] if (top == (s > 0.0)) else [c, p1, p0]
			for v in tri:
				ends.set_normal(Vector3(0, 1 if top else -1, 0))
				ends.set_uv(Vector2((v as Vector3).x / (r * 2.0) + 0.5, (v as Vector3).z / (r * 2.0) + 0.5))
				ends.add_vertex(v)
	var ring := MeshInstance3D.new()
	ring.name = "End"
	ring.mesh = ends.commit()
	ring.material_override = wood
	n.add_child(ring)
	var face := MeshInstance3D.new()
	face.name = "Face"
	var q := QuadMesh.new()
	q.size = Vector2(r * 2.0, h)
	face.mesh = q
	face.rotation.y = -PI * 0.5 * s
	face.material_override = wood
	n.add_child(face)
	return n


## A piece lying down: its length along Z, the split face up or down (`face_up`); for a
## half made with s = 1 (its bark round +X, the split face looking -X).
static func lying_basis(face_up: bool) -> Basis:
	return Basis(Vector3.BACK, -PI * 0.5 if face_up else PI * 0.5) * Basis(Vector3.RIGHT, PI * 0.5)
