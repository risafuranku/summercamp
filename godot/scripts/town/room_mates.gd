extends RefCounted

## The other wardens on foot in a place you walk about in (room_walk.gd's spots and ways: the
## reception, the corridor, a room): standing where they last went, walking when they walk
## ("walk" over Coop, town_trip keeps each one's spot), so you see them get there. The
## figures are REMOTE_PLAYERs fed with the walk's own positions.

const WALK = preload("res://scripts/town/room_walk.gd")
const SPEED := 1.25
const EYE := 1.6

var room
var spots: Dictionary = {}
var ways: Array = []
var start := ""
## id -> {"fig", "at" (feet), "path", "yaw", "then"}.
var mates: Dictionary = {}


func _init(p_room, p_spots: Dictionary, p_ways: Array, p_start: String) -> void:
	room = p_room
	spots = p_spots
	ways = p_ways
	start = p_start


func feet(spot: String) -> Vector3:
	var at: Vector3 = (spots.get(spot if spots.has(spot) else start, {}) as Dictionary).get("at", Vector3.ZERO)
	return Vector3(at.x, maxf(at.y - EYE, 0.0), at.z)


## Warden `id`'s figure, standing at `spot`, unless it is here already.
func put(id: int, fig, spot: String) -> void:
	if mates.has(id):
		return
	var at := feet(spot)
	fig.manual = false
	mates[id] = {"fig": fig, "at": at, "path": [], "yaw": 0.0, "then": Callable()}
	fig.push_state({"p": at - Vector3(0, 0.35, 0), "v": 0.0, "y": 0.0})


## Warden `id` has set off to `spot`: along the ways.
func walk(id: int, spot: String) -> void:
	var m: Dictionary = mates.get(id, {})
	if m.is_empty() or not spots.has(spot):
		return
	var legs: Array = WALK.route(spots, ways, _nearest(m["at"]), spot)
	var path: Array = []
	for s in legs:
		path.append(feet(str(s)))
	m["path"] = path


## Warden `id` walks these points and then `then` (they are gone).
func leave(id: int, path: Array, then: Callable) -> void:
	var m: Dictionary = mates.get(id, {})
	if m.is_empty():
		return
	m["path"] = path
	m["then"] = then


func _nearest(at: Vector3) -> String:
	var best := start
	var d := 1e9
	for k in spots:
		var dd := feet(str(k)).distance_to(at)
		if dd < d:
			d = dd
			best = str(k)
	return best


func tick(delta: float) -> void:
	for id in mates.keys():
		var m: Dictionary = mates[id]
		var fig = m["fig"]
		if fig == null or not is_instance_valid(fig):
			mates.erase(id)
			continue
		var at: Vector3 = m["at"]
		var path: Array = m["path"]
		var v := 0.0
		if not path.is_empty():
			var to: Vector3 = path[0]
			var way := to - at
			var step := SPEED * delta
			if way.length() <= step:
				at = to
				path.pop_front()
			else:
				at += way.normalized() * step
				m["yaw"] = atan2(-way.x, -way.z)
			v = SPEED
		m["at"] = at
		fig.push_state({"p": at - Vector3(0, 0.35, 0), "v": v, "y": float(m["yaw"])})
		var then: Callable = m["then"]
		if path.is_empty() and then.is_valid():
			mates.erase(id)
			then.call()
