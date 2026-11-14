extends SceneTree

## The firewood plate's picture (the trouble strip, job_badge "wood"), rendered from the game's
## own split pieces (scripts/attractions/split_wood.gd, the woodpile's bark and ends) on the
## key colour: three pieces stacked, their ends to the eye. tools/artgen/trouble_icons.py
## boxes it down and rings it like the others (its kind "wood"). Windowed (it draws):
##   godot --audio-driver Dummy --path godot --script res://tools/wood_icon.gd
## Writes tools/artgen/out/spr_hud_tr_wood/raw.png.

const SPLIT_WOOD = preload("res://scripts/attractions/split_wood.gd")
const SIZE := Vector2i(512, 448)

var _vp: SubViewport
var _frames := 0


func _initialize() -> void:
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	root.add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(1, 0, 1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.58, 0.52)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = 1.25
	_vp.add_child(sun)
	var bark := _mat("res://assets/textury/camp/log_bark.png", Color(0.86, 0.8, 0.74))
	var ends := _mat("res://assets/textury/camp/log_end.png", Color(0.95, 0.9, 0.82))
	# Two side by side, bark up, one on top across the gap.
	for i in 3:
		var p := SPLIT_WOOD.half(0.12, 0.34, 1.0, bark, ends)
		_vp.add_child(p)
		p.basis = SPLIT_WOOD.lying_basis(false)
		p.position = [Vector3(-0.125, 0.0, 0.0), Vector3(0.125, 0.0, 0.02), Vector3(0.0, 0.118, -0.02)][i]
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.5
	var at := Vector3(0.16, 0.26, 1.0)
	cam.transform = Transform3D(Basis.looking_at(Vector3(0.0, 0.07, 0.0) - at, Vector3.UP), at)
	_vp.add_child(cam)
	cam.current = true


func _mat(path: String, tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.albedo_color = tint
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return m


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 8:
		return false
	var img := _vp.get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://").path_join("../tools/artgen/out/spr_hud_tr_wood")
	DirAccess.make_dir_recursive_absolute(path)
	img.save_png(path.path_join("raw.png"))
	print("WOOD ICON -> ", path.path_join("raw.png"))
	return true
