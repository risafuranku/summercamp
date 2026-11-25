extends Node3D

## The edge of a sandbox camp's land (core/systems/plot_rules.gd; Richard 25. 11. „Hranice z
## kolíků“): stakes driven in every STEP_M along the sides of the plot that are not the camp's
## own fence, a red-and-white tape strung between them at waist height (the barrier arm's
## stripes). Rebuilt when the plot changes (EventBus.plot_changed; a load, the host's camp
## arriving: it looks once a second whether the plot is still the one it drew); nothing when
## the camp is all its own. Nothing stops anybody at it: it only says where the camp's land ends.

const INSTANCE = preload("res://scripts/instance/instance.gd")
const PLOT = preload("res://core/systems/plot_rules.gd")
const POST_TEX := "res://assets/textury/camp/planks_dark.png"
const TAPE_TEX := "res://assets/textury/camp/barrier_arm.png"
const STEP_M := 2.0
const POST := Vector3(0.07, 1.0, 0.07)
const TAPE_Y := 0.8
const TAPE_H := 0.07

var main: Node
var _built := ""
var _post_mat: StandardMaterial3D
var _tape_mat: StandardMaterial3D
var _look := 0.0


func _ready() -> void:
	name = "PlotStakes"
	_post_mat = _mat(POST_TEX, Vector3(2, 2, 2))
	_tape_mat = _mat(TAPE_TEX, Vector3(1, 1, 1))
	var bus = INSTANCE.bus(self)
	if bus.has_signal("plot_changed") and not bus.plot_changed.is_connected(rebuild):
		bus.plot_changed.connect(rebuild)


func _mat(path: String, uv: Vector3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	m.uv1_triplanar = true
	m.uv1_scale = uv
	if ResourceLoader.exists(path):
		m.albedo_texture = load(path)
	return m


func _process(delta: float) -> void:
	_look -= delta
	if _look <= 0.0:
		_look = 1.0
		rebuild()


## The stakes as the plot is now.
func rebuild() -> void:
	var gm = main.get("grid_manager") if main != null else null
	var core = INSTANCE.core(self)
	if gm == null or core == null or core.get_state() == null:
		return
	var plot: Array = core.actions.plot_rect()
	var grid := Vector2i(int(gm.grid_width), int(gm.grid_height))
	var key := str(plot) + str(grid)
	if key == _built:
		return
	_built = key
	for c in get_children():
		c.queue_free()
	if plot.is_empty():
		return
	var r := PLOT.rect(plot, grid)
	var ts := float(gm.tile_size)
	# The plot's corners in the world (a tile's centre is grid_to_world; its edge half a tile off).
	var a: Vector3 = gm.grid_to_world(r.position) - Vector3(ts * 0.5, 0, ts * 0.5)
	var b: Vector3 = gm.grid_to_world(r.end - Vector2i.ONE) + Vector3(ts * 0.5, 0, ts * 0.5)
	var y := a.y
	var sw := Vector3(a.x, y, a.z)
	var se := Vector3(b.x, y, a.z)
	var nw := Vector3(a.x, y, b.z)
	var ne := Vector3(b.x, y, b.z)
	# Not along the camp's own fence: the south always, the others where the plot reaches it.
	if r.position.x > 0:
		_side(sw, nw)
	if r.end.x < grid.x:
		_side(se, ne)
	if r.end.y < grid.y:
		_side(nw, ne)


## Stakes from `p` to `q`, the tape between each two.
func _side(p: Vector3, q: Vector3) -> void:
	var length := p.distance_to(q)
	var n := maxi(1, int(ceil(length / STEP_M)))
	var prev := Vector3.INF
	for i in n + 1:
		var at := p.lerp(q, float(i) / float(n))
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = POST
		post.mesh = pm
		post.material_override = _post_mat
		add_child(post)
		# A little crooked, as driven in by hand.
		post.global_position = at + Vector3(0, POST.y * 0.5, 0)
		post.rotation = Vector3(float(i % 3 - 1) * 0.05, 0.0, float((i + 1) % 3 - 1) * 0.04)
		if prev != Vector3.INF:
			var tape := MeshInstance3D.new()
			var tm := BoxMesh.new()
			var span := prev.distance_to(at)
			tm.size = Vector3(span, TAPE_H, 0.01)
			tape.mesh = tm
			tape.material_override = _tape_mat
			add_child(tape)
			var mid := (prev + at) * 0.5 + Vector3(0, TAPE_Y - 0.03 * float(i % 2), 0)
			tape.global_position = mid
			tape.rotation.y = -atan2(at.z - prev.z, at.x - prev.x)
		prev = at
