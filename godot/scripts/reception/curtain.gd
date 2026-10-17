extends RefCounted

## Drapes on a rod in front of a window (the office's floral pair, the back room's heavy
## velvet): click them and they are drawn back to the sides or pulled shut. Each side is a
## few folds of cloth (Build-style slabs, a camp texture) that bunch up as it opens.
##
## `open` (0 shut .. 1 drawn) is what the rest reads: how much daylight comes in, whether
## the window's view is worth drawing, what the window looks like from outside.

const K = preload("res://scripts/interior_kit.gd")
const SFX_OPEN := "res://assets/sfx/backroom/curtain_open.mp3"
const SFX_SHUT := "res://assets/sfx/backroom/curtain_shut.mp3"
const FOLDS := 5
## Drawn back, a side keeps this share of its width.
const BUNCHED := 0.2
const SPEED := 1.8

var root: Node3D
var open := 1.0
var target := 1.0
var meshes: Array = []
var _panels: Array = []     # [left, right] Node3D, pivot at the window's edge
var _width := 1.0
var _sfx: AudioStreamPlayer
var _moved := false


## `center`: the middle of the window opening (room space), the curtain hangs a hand in
## front of it toward the room. `yaw_deg`: 0 for a window in a wall facing +Z (the room
## side), 90 for one facing +X.
func build(parent: Node3D, center: Vector3, width: float, height: float, yaw_deg: float, tex: String, metres: float, audio_parent: Node, start_open := true) -> void:
	_width = width
	root = Node3D.new()
	root.name = "Curtain"
	root.position = center
	root.rotation_degrees.y = yaw_deg
	parent.add_child(root)
	var cloth := K.surface(tex, metres)
	var rod_mat := K.surface("planks_dark", 0.5)
	var rod := K.slab(root, Vector3(width + 0.56, 0.035, 0.035), Vector3(0, height * 0.5 + 0.1, 0), rod_mat, "CurtainRod")
	for side: float in [-1.0, 1.0]:
		K.slab(root, Vector3(0.05, 0.08, 0.06), Vector3(side * (width * 0.5 + 0.26), height * 0.5 + 0.1, -0.02), rod_mat, "RodBracket")
	meshes.append(rod)
	var half := width * 0.5 + 0.14
	var fold_w := half / float(FOLDS)
	for side: float in [-1.0, 1.0]:
		var p := Node3D.new()
		p.name = "Drape%s" % ("L" if side < 0.0 else "R")
		p.position = Vector3(side * half, 0.0, 0.0)
		root.add_child(p)
		for f in FOLDS:
			# Folds toward the middle from the outer edge, every other one a little proud.
			var x := -side * (fold_w * (float(f) + 0.5))
			var z := 0.025 if f % 2 == 0 else -0.005
			var m := K.slab(p, Vector3(fold_w + 0.012, height + 0.18, 0.025), Vector3(x, 0.02, z), cloth, "Fold")
			meshes.append(m)
		_panels.append(p)
	_sfx = AudioStreamPlayer.new()
	_sfx.volume_db = -8.0
	audio_parent.add_child(_sfx)
	open = 1.0 if start_open else 0.0
	target = open
	_layout()


func is_open() -> bool:
	return target > 0.5


func toggle() -> void:
	set_open(not is_open())


func set_open(on: bool, instant := false) -> void:
	target = 1.0 if on else 0.0
	if instant:
		open = target
		_layout()
		return
	var path := SFX_OPEN if on else SFX_SHUT
	if _sfx != null and ResourceLoader.exists(path):
		_sfx.stream = load(path)
		_sfx.pitch_scale = randf_range(0.94, 1.06)
		_sfx.play()


## Returns true while it is moving.
func update(delta: float) -> bool:
	if is_equal_approx(open, target):
		return false
	open = move_toward(open, target, delta * SPEED)
	_layout()
	return true


func _layout() -> void:
	# Eased: a pull starts slow, runs, then the rings bunch.
	var e := open * open * (3.0 - 2.0 * open)
	var s := lerpf(1.0, BUNCHED, e)
	for p in _panels:
		(p as Node3D).scale.x = s
