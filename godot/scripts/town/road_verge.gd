extends RefCounted

## The autumn verge either side of a stretch of road (camp_gate.gd, road_south.gd): dry
## straw-yellow grass, the last green, fallen leaves (assets/textury/town/verge_autumn.png).
## Its edges are ragged tufts cut out of the picture, the gravel showing between them on
## the road side and the forest floor on the other, and its tone is brought down towards
## that floor: a bright strip with ruler-straight edges did not sit in the ground
## (playtest 18. 10.). It turns with the season like the camp's ground
## (scripts/season_look.gd "season_ground", keeping its own picture).

const TEX := "res://assets/textury/town/verge_autumn.png"
const WIDTH := 2.2
const TONE := Color(0.74, 0.7, 0.6)

static var _cut: ImageTexture


static func build(parent: Node3D, from: Vector3, to: Vector3, road_w: float) -> void:
	var tex := _ragged()
	if tex == null:
		return
	var length := from.distance_to(to)
	var yaw := atan2(to.x - from.x, to.z - from.z)
	var side_dir := Vector3(cos(yaw), 0.0, -sin(yaw))
	for side in [-1.0, 1.0]:
		var v := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(WIDTH, length + 1.0)
		v.mesh = pm
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.albedo_color = TONE
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		m.roughness = 1.0
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		# The picture's right edge is the outer one: the plane's +X, which is side_dir, so
		# the other side's verge has it mirrored.
		m.uv1_scale = Vector3(side, (length + 1.0) / WIDTH, 1.0)
		v.material_override = m
		# Over the road's edge (its surface is lower), so the gravel shows between the tufts.
		v.position = (from + to) * 0.5 + side_dir * side * (road_w * 0.5 + WIDTH * 0.5 - 0.15) + Vector3(0, 0.04, 0)
		v.rotation.y = yaw
		v.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		v.set_meta("season_keep_texture", true)
		v.add_to_group("season_ground")
		parent.add_child(v)


## The verge picture with its edges eaten away: a little on the left (the road side), a
## lot on the right (the forest side), in tufts that come and go along it; a few loose
## pixels beyond the edge. Repeats along its length like the picture does.
static func _ragged() -> ImageTexture:
	if _cut != null:
		return _cut
	if not ResourceLoader.exists(TEX):
		return null
	var img := (load(TEX) as Texture2D).get_image().duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		var a := TAU * float(y) / float(h)
		var outer := 0.7 + 0.11 * sin(a * 3.0 + 0.6) + 0.07 * sin(a * 7.0 + 2.1) + 0.04 * sin(a * 13.0)
		var inner := 0.05 + 0.03 * sin(a * 5.0 + 1.3) + 0.025 * sin(a * 11.0 + 0.4)
		for x in w:
			var u := (float(x) + 0.5) / float(w)
			var n := float(absi(hash(Vector2i(x, y))) % 1000) / 1000.0
			var edge_out := outer + (n - 0.5) * 0.16
			var edge_in := inner + (n - 0.5) * 0.06
			if u > edge_out or u < edge_in:
				var c := img.get_pixel(x, y)
				c.a = 0.0
				img.set_pixel(x, y, c)
	_cut = ImageTexture.create_from_image(img)
	return _cut
