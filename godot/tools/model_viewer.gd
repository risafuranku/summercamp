extends Node3D

## Renders each building model (scripts/building_models.gd) alone on a patch of grass
## from the front three-quarter view, for comparing with the Builder's pixel art.
##
##   godot --path godot --resolution 960x720 res://tools/model_viewer.tscn -- --out=<dir> [--only=pub,restaurant]

const MODELS := preload("res://scripts/building_models.gd")
const BUILDING_MANAGER := preload("res://scripts/building_manager.gd")
const FOOTPRINTS := {"pub": Vector2i(2, 2), "restaurant": Vector2i(2, 2), "sports_field": Vector2i(2, 1), "lake_slide": Vector2i(2, 1), "cabin_1": Vector2i(2, 2), "cabin_2": Vector2i(2, 2), "cabin_3": Vector2i(2, 2), "caravan_1": Vector2i(2, 1)}

var _out := "user://models"
var _only: Array = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--only="):
			_only = Array(a.substr(7).split(","))
	DirAccess.make_dir_recursive_absolute(_out)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.56, 0.68, 0.82)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.64, 0.7)
	e.ambient_light_energy = 0.7
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.3, 0.42, 0.22)
	ground.material_override = gm
	add_child(ground)
	var bm = BUILDING_MANAGER.new()
	add_child(bm)
	var models = MODELS.new(Callable(bm, "_make_psx_material"))
	var cam := Camera3D.new()
	cam.fov = 55.0
	add_child(cam)
	cam.current = true
	for type in MODELS.MODELS + ["cabin_1", "cabin_2", "cabin_3", "caravan_1"]:
		if not _only.is_empty() and not _only.has(type):
			continue
		var root := Node3D.new()
		add_child(root)
		var fp: Vector2i = FOOTPRINTS.get(type, Vector2i.ONE)
		var info: Dictionary = models.build(type, root, 4.0, fp)
		var size: Vector3 = info["size"]
		var r := maxf(size.x, maxf(size.y, size.z))
		cam.global_position = Vector3(r * 0.95, r * 0.7 + 1.0, r * 1.25)
		cam.look_at(Vector3(0, size.y * 0.4, 0), Vector3.UP)
		for i in 3:
			await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(_out.path_join("m_%s.png" % type))
		print("MODEL VIEWER: %s %s" % [type, size])
		root.queue_free()
		await get_tree().process_frame
	get_tree().quit()
