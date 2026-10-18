extends RefCounted

## Walking through a doorway in a room you look round in (the reception, its back room,
## the store): one move along the waypoints at the full frame rate, a smooth curve
## through the positions with the head turning along it, easing out at the start and
## in at the end, a light bob of the steps in the middle (playtest 17. 10.: "smoother
## transitions between the rooms"; it was three or four separate stepped moves that
## stopped dead at each waypoint).
##
##   var tw := WALK_PATH.play(host, camera, [
##       {"pos": camera.position, "rot": camera.rotation},
##       {"pos": Vector3(-1.1, 1.47, 1.28), "rot": Vector3(0, PI * 0.5, 0)},
##       {"pos": STAND, "rot": STAND_ROT},
##   ], 2.0)
##   tw.parallel().tween_property(door, "rotation_degrees:y", 96.0, 0.7)

## A step is this long (metres); the bob dips once per step.
const STRIDE := 0.68
const CAM_MOVE = preload("res://scripts/ui/cam_move.gd")
const BOB := 0.016
const SWAY := 0.006


static func play(host: Node, camera: Camera3D, keys: Array, duration: float) -> Tween:
	var pos: Array[Vector3] = []
	var rot: Array[Vector3] = []
	for k in keys:
		pos.append(k["pos"])
		var r: Vector3 = k["rot"]
		# The yaw the short way round from the one before.
		if not rot.is_empty():
			r.y = rot[-1].y + wrapf(r.y - rot[-1].y, -PI, PI)
		rot.append(r)
	# Each leg costs its length, and turning on the spot costs a little too.
	var cum: Array[float] = [0.0]
	var walked: Array[float] = [0.0]
	for i in range(1, pos.size()):
		var d := pos[i].distance_to(pos[i - 1])
		var turn := absf(rot[i].y - rot[i - 1].y) + absf(rot[i].x - rot[i - 1].x)
		cum.append(cum[-1] + d + turn * 0.3)
		walked.append(walked[-1] + d)
	var total: float = maxf(cum[-1], 0.001)
	var apply := func(u: float) -> void:
		if not is_instance_valid(camera):
			return
		var s := u * total
		var i := 0
		while i < cum.size() - 2 and s > cum[i + 1]:
			i += 1
		var span: float = maxf(cum[i + 1] - cum[i], 0.0001)
		var t := clampf((s - cum[i]) / span, 0.0, 1.0)
		var a := maxi(i - 1, 0)
		var d := mini(i + 2, pos.size() - 1)
		var p := _cr(pos[a], pos[i], pos[i + 1], pos[d], t)
		var r := _cr(rot[a], rot[i], rot[i + 1], rot[d], t)
		# The steps: fade in after the first and out before the last.
		var dist := lerpf(walked[i], walked[i + 1], t)
		var env := sin(clampf(u, 0.0, 1.0) * PI)
		var ph := dist / STRIDE * PI
		p.y -= absf(sin(ph)) * BOB * env
		r.z += sin(ph) * SWAY * env
		camera.position = p
		camera.rotation = r
	var tw := host.create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(apply, 0.0, 1.0, duration)
	# The room on the other side is often built this frame: walk from a steady one.
	CAM_MOVE.hold(host, tw)
	return tw


## Catmull-Rom through b and c (a and d the neighbours).
static func _cr(a: Vector3, b: Vector3, c: Vector3, d: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * b) + (c - a) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t2 + (3.0 * b - a - 3.0 * c + d) * t3)
