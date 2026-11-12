extends RefCounted

## A door painted on a front picture made a real one you walk through (the user 4. 11.: "a
## smooth way in at every building"; scripts/ui/door_through.gd), for the camp's buildings
## (building_models.gd) and Liblice's (town_lesna.gd): the leaf the size of the painted door,
## its face cut from the same picture, hung and swung by door_anim.gd (which finds "Door",
## "Door?" and "DoorLeaf"); the picture with the door cut out, so the room stands behind the
## doorway (the camp's one world).

## Pictures with doors cut out of them: key -> ImageTexture.
static var _cut: Dictionary = {}


## Where the door painted at `px` (the picture's pixels, `pic` its size) is on a front quad of
## `quad_size` at `quad_at` that faces +Z (`facing` 1) or -Z (-1) of its parent: x from its left
## jamb to its right as the parent sees them, y from its sill up.
static func rect(pic: Vector2, px: Rect2, quad_at: Vector3, quad_size: Vector2, facing := 1.0) -> Rect2:
	var x0 := quad_at.x + facing * (px.position.x / pic.x - 0.5) * quad_size.x
	var x1 := quad_at.x + facing * (px.end.x / pic.x - 0.5) * quad_size.x
	var top := quad_at.y + quad_size.y * 0.5 - px.position.y / pic.y * quad_size.y
	var bottom := quad_at.y + quad_size.y * 0.5 - px.end.y / pic.y * quad_size.y
	return Rect2(minf(x0, x1), bottom, absf(x1 - x0), top - bottom)


## The picture `tex` with each of `rects` (pixels) cut out, clear; made once a picture and set.
static func cut_texture(tex: Texture2D, rects: Array) -> Texture2D:
	if tex == null:
		return null
	var key := "%s|%s" % [tex.resource_path if tex.resource_path != "" else str(tex.get_instance_id()), str(rects)]
	if _cut.has(key):
		return _cut[key]
	var img: Image = tex.get_image()
	if img == null:
		return tex
	img = img.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for r in rects:
		img.fill_rect(Rect2i(r as Rect2), Color(0, 0, 0, 0))
	var out := ImageTexture.create_from_image(img)
	_cut[key] = out
	return out


## A leaf `n` for the door at `px` on the front quad (`quad_at`, `quad_size`, `facing`): a box
## `thick` deep standing `out` in front of the quad's plane, `body` its material, its street
## face a copy of `face` showing the picture's pixels of the door (its glass clear where the
## picture's is). Its face goes round with it (door_anim takes what is on a leaf).
static func leaf(parent: Node3D, n: String, tex: Texture2D, px: Rect2, quad_at: Vector3, quad_size: Vector2, facing: float,
		body: Material, face: StandardMaterial3D, out := 0.022, thick := 0.04) -> MeshInstance3D:
	var pic := Vector2(tex.get_size())
	var at := rect(pic, px, quad_at, quad_size, facing)
	var z := quad_at.z + facing * out
	var mi := MeshInstance3D.new()
	mi.name = n
	var b := BoxMesh.new()
	b.size = Vector3(at.size.x, at.size.y, thick)
	mi.mesh = b
	mi.material_override = body
	mi.position = Vector3(at.get_center().x, at.get_center().y, z)
	if facing < 0.0:
		mi.rotation.y = PI
	parent.add_child(mi)
	var fm := face.duplicate() as StandardMaterial3D
	fm.uv1_triplanar = false
	fm.uv1_offset = Vector3(px.position.x / pic.x, px.position.y / pic.y, 0.0)
	fm.uv1_scale = Vector3(px.size.x / pic.x, px.size.y / pic.y, 1.0)
	var q := MeshInstance3D.new()
	q.name = n + "Face"
	var qm := QuadMesh.new()
	qm.size = at.size
	q.mesh = qm
	q.material_override = fm
	q.position = Vector3(at.get_center().x, at.get_center().y, z + facing * (thick * 0.5 + 0.001))
	if facing < 0.0:
		q.rotation.y = PI
	# A picture of a door: it neither swims nor shivers (retro_materials).
	q.set_meta("retro_text", true)
	parent.add_child(q)
	return mi
