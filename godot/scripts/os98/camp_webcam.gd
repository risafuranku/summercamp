extends Node

## The camp's webcam (the web page cerne-jezero.cz/kamera, browser_app; playtest 14. 11.: "more
## consequences in the real world from clicking"): a small camera up on the reception's corner,
## looking out over the camp, that takes a 160x120 picture of the camp's own world when asked.
## Whatever is out there is in it: the guests by day, the lamps at night, and what walks
## between them. Grey and grainy, a line dark in two, as a cheap camera on a phone line sent it.

const SIZE := Vector2i(160, 120)
## On the reception (MainBuilding, front +Z): where it hangs, where it looks (its own space).
const AT := Vector3(3.2, 4.3, 3.4)
const LOOK := Vector3(-3.0, 0.4, 24.0)

var image: Image
## A new picture is in `image` (the browser takes it and clears this).
var fresh := false
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
	_place()
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_wait = 2


func _process(_delta: float) -> void:
	if _wait <= 0:
		return
	_wait -= 1
	if _wait == 0:
		var img := _vp.get_texture().get_image()
		if img != null:
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
	_cam.global_transform = Transform3D(Basis(), xf * AT).looking_at(xf * LOOK, Vector3.UP)


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
