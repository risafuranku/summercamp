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
## How the head goes with the steps: `stride` metres a step, the eye dipping `bob` as each comes
## down, rolling `sway` (radians) over the side that bears it once every two, turning `yaw` with
## it and nodding `nod`; `dip` the look down at the way's middle (a low door).
const WALK := {"stride": STRIDE, "bob": BOB, "sway": SWAY}
## On hands and knees (into a tent and out of it, playtest 13. 11.: "the way into the tent and
## out is terribly stiff"): short shuffles, the head low and heavy from side to side, looking
## at the ground under the flap and up again.
const CRAWL := {"stride": 0.3, "bob": 0.028, "sway": 0.05, "yaw": 0.03, "nod": 0.035, "dip": 0.32}
const GAITS := {"walk": WALK, "crawl": CRAWL}


## The head's offset `dist` metres along a way in `gait` (WALK, CRAWL), its steps at `env`
## (0 standing, 1 under way): [position, rotation (x nod, y yaw, z roll)]. The camp's eye takes
## the same (interior_manager's walks into a tent and out of it: player_controller.gait_pos).
static func gait_offset(gait: Dictionary, dist: float, env: float) -> Array:
	var ph := dist / float(gait.get("stride", STRIDE)) * PI
	var down := absf(sin(ph))
	var side := sin(ph)
	var pos := Vector3(0.0, -down * float(gait.get("bob", BOB)) * env, 0.0)
	var rot := Vector3(-down * float(gait.get("nod", 0.0)) * env, side * float(gait.get("yaw", 0.0)) * env, side * float(gait.get("sway", SWAY)) * env)
	return [pos, rot]


## What a walk out of a room hands the camp's walk (interior_manager._walk_body): the eye's
## speed in its last frame and how far its steps had got, so the camp goes on in the same
## stride with no stop in the doorway (playtest 14. 11.: "part inside and part outside":
## the room's walk slowed to a stand at the door and the camp's set off again from one).
class Hand extends RefCounted:
	var speed := 0.0
	var phase := 0.0
	var _last := Vector3.INF
	var _was := 0.0

	func note(at: Vector3, dist: float, delta: float) -> void:
		if _last.is_finite() and delta > 0.0:
			# The last frame of a walk is only a part of one (it ends inside it): the higher
			# of the last two (the walk was still speeding up).
			var v := Vector2(at.x - _last.x, at.z - _last.z).length() / delta
			speed = maxf(v, _was)
			_was = v
		_last = at
		phase = dist


## `into`: the walk goes on into another one (a room's walk out, the camp's after it): it sets
## off easing in and ends still under way, at its pace, its steps still going; `hand` (a
## Hand) is told every frame how fast it goes and how far its steps are.
static func play(host: Node, camera: Camera3D, keys: Array, duration: float, gait: Dictionary = WALK, into := false, hand: Hand = null) -> Tween:
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
		var p1: Vector3 = pos[d]
		var r1: Vector3 = rot[d]
		if into and i + 2 > pos.size() - 1:
			# Going on past the last key: the curve leaves it at the last leg's pace.
			p1 = pos[i + 1] * 2.0 - pos[i]
			r1 = rot[i + 1] * 2.0 - rot[i]
		var p := _cr(pos[a], pos[i], pos[i + 1], p1, t)
		var r := _cr(rot[a], rot[i], rot[i + 1], r1, t)
		# The steps: fade in after the first and out before the last (on into the next walk:
		# still going at the end).
		var dist := lerpf(walked[i], walked[i + 1], t)
		var env := sin(clampf(u, 0.0, 0.5 if into else 1.0) * PI)
		var off := gait_offset(gait, dist, env)
		p += off[0]
		r += off[1]
		r.x -= float(gait.get("dip", 0.0)) * env
		camera.position = p
		camera.rotation = r
		if hand != null:
			hand.note(camera.global_position, dist, host.get_process_delta_time())
	var tw := host.create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN if into else Tween.EASE_IN_OUT)
	tw.tween_method(apply, 0.0, 1.0, duration)
	# The room on the other side is often built this frame: walk from a steady one.
	CAM_MOVE.hold(host, tw)
	return tw


## Catmull-Rom through b and c (a and d the neighbours).
static func _cr(a: Vector3, b: Vector3, c: Vector3, d: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * b) + (c - a) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t2 + (3.0 * b - a - 3.0 * c + d) * t3)
