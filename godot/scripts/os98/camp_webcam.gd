extends Node

## The camp's webcam (the web page cerne-jezero.cz/kamera, browser_app; playtest 14. 11.: "more
## consequences in the real world from clicking"): a small camera up on the reception's corner,
## looking out over the camp, that takes a 160x120 picture of the camp's own world when asked.
## Whatever is out there is in it: the guests by day, the lamps at night, and what walks
## between them. Grey and grainy, a line dark in two, as a cheap camera on a phone line sent it.

const INSTANCE = preload("res://scripts/instance/instance.gd")
const SIZE := Vector2i(160, 120)
## On the reception (MainBuilding, front +Z): where it hangs, where it looks (its own space)
## while nothing is built about the camp.
const AT := Vector3(3.2, 4.3, 3.4)
const LOOK := Vector3(-3.0, 0.4, 24.0)
## It is turned to the middle of what is built (the tents, the cabins, the places: where the
## guests are; 25. 11., in a new camp it showed the forest past the reception and the tents off
## to its side), as far as it turns on its corner: this many degrees off the front.
const TURN_MAX := 75.0
## What it is not turned to: what nobody stays at or goes to.
const NOT_AIMED := ["main_building", "path", "tree_", "lamp_post", "sewer", "sewage_tank", "pa_pole", "power_generator", "water_pump", "flagpole"]

var image: Image
## A new picture is in `image` (the browser takes it and clears this).
var fresh := false
## The district's aerial photograph of the camp (SectiTo, job_census.gd): straight down over
## the whole plan, a photograph's colours, grainy. Its own picture and flag.
var aerial: Image
var aerial_fresh := false
var _mode := "pole"
var _main: Node
var _vp: SubViewport
var _cam: Camera3D
var _wait := 0
var _rng := RandomNumberGenerator.new()


## The one under `main` (made the first time).
static func of(main: Node) -> Node:
	if main == null:
		return null
	var n := main.get_node_or_null("CampWebcam")
	if n == null:
		n = load("res://scripts/os98/camp_webcam.gd").new()
		n.name = "CampWebcam"
		n.set("_main", main)
		main.add_child(n)
	return n


## Take a picture: it is in `image` two frames on.
func request() -> void:
	if not _ready_cam():
		return
	_mode = "pole"
	_vp.size = SIZE
	_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	_cam.far = 400.0
	_place()
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_wait = 2


## The aerial photograph, `px` big: in `aerial` two frames on.
func request_aerial(px: Vector2i) -> void:
	if not _ready_cam():
		return
	var gm = _main.get("grid_manager")
	if gm == null:
		return
	_mode = "aerial"
	_vp.size = px
	# Over the tents' pitches, with a margin: there they can be told and counted.
	var lo := Vector2i(gm.grid_width, gm.grid_height)
	var hi := Vector2i(-1, -1)
	var st = INSTANCE.core(self).get_state() if CoreRoot != null else null
	if st != null and st.grid != null:
		for coord in st.grid.cells:
			var tp := str((st.grid.cells[coord] as Dictionary).get("type", ""))
			if not tp.begins_with("tent"):
				continue
			lo = Vector2i(mini(lo.x, coord.x), mini(lo.y, coord.y))
			hi = Vector2i(maxi(hi.x, coord.x), maxi(hi.y, coord.y))
	if hi.x < 0:
		lo = Vector2i.ZERO
		hi = Vector2i(gm.grid_width - 1, gm.grid_height - 1)
	var a3: Vector3 = gm.grid_to_world(lo)
	var b3: Vector3 = gm.grid_to_world(hi)
	var mid: Vector3 = (a3 + b3) * 0.5
	var w := absf(b3.x - a3.x) + float(gm.tile_size) * 3.0
	var h := absf(b3.z - a3.z) + float(gm.tile_size) * 3.0
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = maxf(h, w * float(px.y) / float(px.x))
	# Under the clouds (the sky's own layer hangs higher): nothing between it and the ground.
	_cam.far = 60.0
	_cam.global_transform = Transform3D(Basis.from_euler(Vector3(-PI * 0.5, 0.0, 0.0)), mid + Vector3(0, 32.0, 0))
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_wait = 2


func _process(_delta: float) -> void:
	if _wait <= 0:
		return
	_wait -= 1
	if _wait == 0:
		var img := _vp.get_texture().get_image()
		if img != null and _mode == "aerial":
			aerial = _treat_aerial(img)
			aerial_fresh = true
		elif img != null:
			image = _treat(img)
			fresh = true


func _ready_cam() -> bool:
	if _vp != null:
		return true
	var world: Node3D = _main.get("_world_3d") if _main != null else null
	if world == null or world.get_world_3d() == null:
		return false
	_vp = SubViewport.new()
	_vp.name = "WebcamView"
	_vp.size = SIZE
	_vp.world_3d = world.get_world_3d()
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	add_child(_vp)
	_cam = Camera3D.new()
	_cam.fov = 64.0
	_cam.near = 0.1
	_cam.far = 400.0
	# Not the rooms' own things (their front doors drawn for their own eye).
	_cam.cull_mask &= ~(1 << 17)
	_vp.add_child(_cam)
	_cam.current = true
	return true


func _place() -> void:
	var world: Node3D = _main.get("_world_3d")
	var b := world.find_child("MainBuilding", true, false) as Node3D if world != null else null
	if b == null:
		return
	var xf := b.global_transform
	_cam.global_transform = Transform3D(Basis(), xf * AT).looking_at(_aim(xf), Vector3.UP)


## The point it looks at: the middle of what is built, turned to no more than TURN_MAX off the
## reception's front; straight out (LOOK) while nothing is.
func _aim(xf: Transform3D) -> Vector3:
	var out := xf * LOOK
	var gm = _main.get("grid_manager")
	var st = INSTANCE.core(self).get_state() if gm != null else null
	if st == null or st.grid == null:
		return out
	var sum := Vector3.ZERO
	var n := 0
	for coord in st.grid.cells:
		var tp := str((st.grid.cells[coord] as Dictionary).get("type", ""))
		if tp == "" or NOT_AIMED.any(func(x: String) -> bool: return tp.begins_with(x)):
			continue
		sum += gm.grid_to_world(coord)
		n += 1
	if n == 0:
		return out
	var at := xf * AT
	var mid := sum / float(n)
	var front := Vector2((out - at).x, (out - at).z)
	var to := Vector2((mid - at).x, (mid - at).z)
	if to.length() < 4.0:
		return out
	var off := clampf(front.angle_to(to), -deg_to_rad(TURN_MAX), deg_to_rad(TURN_MAX))
	var dir := front.normalized().rotated(off) * maxf(to.length(), 14.0)
	return Vector3(at.x + dir.x, out.y, at.z + dir.y)


## An aerial photograph's print: its colours a little faded, grain.
func _treat_aerial(src: Image) -> Image:
	var img := src.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGB8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var g := c.get_luminance()
			var n := _rng.randf_range(-0.03, 0.03)
			img.set_pixel(x, y, Color(clampf(lerpf(g, c.r, 0.7) + n + 0.03, 0, 1), clampf(lerpf(g, c.g, 0.7) + n + 0.02, 0, 1), clampf(lerpf(g, c.b, 0.65) + n, 0, 1)))
	return img


## A cheap camera's picture: mostly grey, grainy, every other line darker.
func _treat(src: Image) -> Image:
	var img := src.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGB8)
	for y in img.get_height():
		var line := 0.86 if y % 2 == 1 else 1.0
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var g := c.get_luminance()
			var n := _rng.randf_range(-0.035, 0.035)
			var v := Color(lerpf(g, c.r, 0.25), lerpf(g, c.g, 0.3), lerpf(g, c.b, 0.25))
			img.set_pixel(x, y, Color(clampf((v.r + n) * line, 0, 1), clampf((v.g + n) * line, 0, 1), clampf((v.b + n) * line, 0, 1)))
	return img
