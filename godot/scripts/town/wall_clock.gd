extends RefCounted

## A wall clock in a room in Liblice that keeps the game's time, the way the camp office's
## does (reception/office_dressing.gd): the dial's picture (camp/wall_clock.png, no hands
## of its own) and its two black hands, turned to the minute.
##
##   var clock = WALL_CLOCK.new()
##   clock.make(root, pos, yaw, size)   # the dial's middle at pos
##   clock.show_time(hour)              # every frame or so: moves only when the minute does

const K = preload("res://scripts/interior_kit.gd")

var _hour_hand: Node3D
var _minute_hand: Node3D
var _shown := -1


func make(root: Node3D, pos: Vector3, yaw: float, size := 0.32) -> Node3D:
	var c := Node3D.new()
	c.name = "WallClock"
	c.position = pos
	c.rotation_degrees.y = yaw
	root.add_child(c)
	K.cutout(c, "wall_clock", Vector2(size, size), Vector3(0, -size * 0.5, 0), 0.0, false, "ClockDial")
	var black := K._base(Color(0.08, 0.07, 0.06))
	var k := size / 0.32
	_hour_hand = _hand(c, 0.085 * k, 0.016 * k, black, 0.006)
	_minute_hand = _hand(c, 0.125 * k, 0.011 * k, black, 0.009)
	return c


func show_time(hour: float) -> void:
	var minute := int(floor(hour * 60.0)) % (24 * 60)
	if minute == _shown or _minute_hand == null or not is_instance_valid(_minute_hand):
		return
	_shown = minute
	var m := float(minute % 60)
	var h := float(int(minute / 60.0) % 12) + m / 60.0
	_minute_hand.rotation.z = -m / 60.0 * TAU
	_hour_hand.rotation.z = -h / 12.0 * TAU


func _hand(parent: Node3D, length: float, width: float, mat: Material, z: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(0, 0, z)
	parent.add_child(pivot)
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(width, length)
	q.mesh = qm
	q.material_override = mat
	q.position = Vector3(0, length * 0.38, 0)
	pivot.add_child(q)
	return pivot
