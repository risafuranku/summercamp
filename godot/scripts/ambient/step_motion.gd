extends Node

## Things that move in steps, a few frames a second, like the Build world's machinery (the
## user 5. 11., on the Karosa's doors rattling on the road: "gorgeous low-fps animation,
## more of those in the game!"). One node for the world (get_for, as nightmare_fx): what is
## added here moves twelve times a second at most, only near the eye, driven by the wind
## (main's weather_visuals `_wind_now`: 0.15 still, 0.75 windy, 1.6 a gale) or by its own
## `drive` (a Callable, 0..1: the bus's speed), each from its own base: what it stood at
## when added, or since something else moved it (a door opened by hand, a tween).
##   swing   hanging things (the pub's sign on its bracket): a pendulum the wind pushes
##   rattle  things held loosely (a door in its frame, a stop's sign on its pole, a lamp on
##           its arm): still in a calm, knocked about in bursts once the wind is up
##   flap    cloth (a tent's door flap): two or three poses in turn, quicker in a gust
## kick(node, axis, turns): a one-off run of turns (radians, a step each: the barrier
## bouncing on its post, a pane clacking on a pothole); it gives up if something else moves
## the node meanwhile.
## opts: "shift" (a local direction it is also knocked along, metres at full), "from" (the
## wind a rattle starts at), "drive" (Callable, 0..1, instead of the wind), "with" (nodes
## that move as it does: the heart cut in an outhouse door), "near" (metres from the eye),
## "pivot" (the local point it turns about: a hanging sign's top edge, a flap's apex).
## In the camp it finds its own (`_scan_camp`, every few seconds, as they are built): the
## outhouses', the showers' and the generator shed's doors rattle in their frames in a
## gale; the tents' door flaps flap.

const NODE_NAME := "StepMotion"
const FPS := 12.0
const NEAR := 90.0

static var _pending: WeakRef = null


class Item:
	var node: WeakRef
	var kind := ""
	var axis := Vector3.RIGHT
	var amount := 0.0
	var shift := Vector3.ZERO
	var from := 0.6
	var drive := Callable()
	var near := NEAR
	var phase := 0.0
	var base := Transform3D.IDENTITY
	var written := Transform3D.IDENTITY
	var turns: Array = []
	var burst := 0.0
	var pose := 0
	var pose_t := 0.0
	var with: Array = []          # [node weakref, its base]
	var pivot := Vector3.ZERO
	var resting := true


## The camp's doors and flaps: building type -> [[the part, parts moving with it], ...].
const CAMP_DOORS := {
	"toilet_block": [["Door0", "Heart0", "Plaque0"], ["Door1", "Heart1", "Plaque1"]],
	"shower_block": [["Door"]],
	"power_generator": [["Door0"], ["Door1"]],
}
const CAMP_SCAN_SEC := 3.0
var _scan_t := 1.0
var _seen := {}
var _items: Array = []
var _acc := 0.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()


static func get_for(node: Node) -> Node:
	if node == null or not node.is_inside_tree():
		return null
	var root := node.get_tree().root
	var sm := root.get_node_or_null(NODE_NAME)
	if sm == null and _pending != null:
		var made = _pending.get_ref()
		if made != null and is_instance_valid(made):
			sm = made
	if sm == null:
		sm = (load("res://scripts/ambient/step_motion.gd") as GDScript).new()
		sm.name = NODE_NAME
		_pending = weakref(sm)
		root.add_child.call_deferred(sm)
	return sm


## `node` moves in steps from now on (kind: swing, rattle, flap); added once it is in the
## tree if it is not yet.
static func attach(node: Node3D, kind: String, axis: Vector3, amount: float, opts := {}) -> void:
	if node == null:
		return
	if not node.is_inside_tree():
		node.tree_entered.connect(func(): attach(node, kind, axis, amount, opts), CONNECT_ONE_SHOT)
		return
	var sm = get_for(node)
	if sm != null:
		sm.add(node, kind, axis, amount, opts)


## A one-off run of turns (radians about `axis`, one a step).
static func kick(node: Node3D, axis: Vector3, turns: Array) -> void:
	if node == null or not node.is_inside_tree():
		return
	var sm = get_for(node)
	if sm != null:
		sm.add_kick(node, axis, turns)


func _ready() -> void:
	_rng.randomize()
	process_mode = Node.PROCESS_MODE_PAUSABLE


func add(node: Node3D, kind: String, axis: Vector3, amount: float, opts := {}) -> void:
	var it := Item.new()
	it.node = weakref(node)
	it.kind = kind
	it.axis = axis.normalized() if axis.length() > 0.0 else Vector3.RIGHT
	it.amount = amount
	it.shift = opts.get("shift", Vector3.ZERO)
	it.from = float(opts.get("from", 0.6))
	it.drive = opts.get("drive", Callable())
	it.near = float(opts.get("near", NEAR))
	it.pivot = opts.get("pivot", Vector3.ZERO)
	it.phase = _rng.randf_range(0.0, TAU)
	it.base = node.transform
	it.written = node.transform
	for w in opts.get("with", []):
		if w is Node3D:
			it.with.append([weakref(w), (w as Node3D).transform])
	_items.append(it)


func add_kick(node: Node3D, axis: Vector3, turns: Array) -> void:
	for it in _items:
		if it.node.get_ref() == node:
			it.turns = turns.duplicate()
			return
	add(node, "kick", axis, 0.0)
	(_items[_items.size() - 1] as Item).turns = turns.duplicate()


## >= 0 pins the wind (tools/steps_check.gd).
var debug_wind := -1.0


## The wind now: weather_visuals' (0.15 if there is none, as on a still day).
func wind() -> float:
	if debug_wind >= 0.0:
		return debug_wind
	var scene := get_tree().current_scene if get_tree() != null else null
	var wv = scene.get("_weather_visuals") if scene != null else null
	var w = wv.get("_wind_now") if wv != null else null
	return float(w) if w != null else 0.15


func _process(delta: float) -> void:
	_acc += delta
	if _acc < 1.0 / FPS:
		return
	var step := _acc
	_acc = 0.0
	_t += step
	_scan_t -= step
	if _scan_t <= 0.0:
		_scan_t = CAMP_SCAN_SEC
		_scan_camp()
	if _items.is_empty():
		return
	var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
	var eye := cam.global_position if cam != null else Vector3.INF
	var w := wind()
	var i := _items.size() - 1
	while i >= 0:
		var it: Item = _items[i]
		var n := it.node.get_ref() as Node3D
		if n == null or not is_instance_valid(n) or not n.is_inside_tree():
			_items.remove_at(i)
			i -= 1
			continue
		if not _tick(it, n, step, w, eye):
			_items.remove_at(i)
		i -= 1


## False when it is done with (a kick that has run out).
func _tick(it: Item, n: Node3D, step: float, w: float, eye: Vector3) -> bool:
	# Something else moved it since: that is where it stands now (a kick gives up).
	if not n.transform.is_equal_approx(it.written):
		if it.kind == "kick":
			return false
		it.base = n.transform
		for g in it.with:
			var gn := (g[0] as WeakRef).get_ref() as Node3D
			if gn != null:
				g[1] = gn.transform
	if not n.is_visible_in_tree() or (eye != Vector3.INF and n.global_position.distance_to(eye) > it.near):
		_rest(it, n)
		return true
	var k: float = clampf(float(it.drive.call()), 0.0, 1.0) if it.drive.is_valid() else clampf(w / 1.6, 0.0, 1.0)
	var turn := 0.0
	var off := Vector3.ZERO
	match it.kind:
		"swing":
			# Pushed by the wind, hanging back, never quite still out of doors.
			turn = it.amount * (0.08 + 0.92 * k) * (0.65 * sin(_t * 1.6 + it.phase) + 0.35 * sin(_t * 3.7 + it.phase * 2.3))
		"rattle":
			var over := clampf((k * 1.6 - it.from) / maxf(0.2, 1.6 - it.from), 0.0, 1.0) if not it.drive.is_valid() else k
			it.burst -= step
			if it.burst <= 0.0 and over > 0.0 and _rng.randf() < 0.12 + 0.4 * over:
				it.burst = _rng.randf_range(0.25, 0.4 + 1.1 * over)
			if it.burst > 0.0 and over > 0.0:
				var a := _rng.randf_range(-1.0, 1.0)
				turn = it.amount * a * (0.45 + 0.55 * over)
				off = it.shift * _rng.randf_range(-1.0, 1.0) * (0.45 + 0.55 * over)
		"flap":
			# Two or three poses in turn: quicker and further the harder it blows.
			it.pose_t -= step
			if it.pose_t <= 0.0:
				it.pose = (it.pose + 1 + (1 if _rng.randf() < 0.25 else 0)) % 3
				it.pose_t = lerpf(0.5, 0.12, k) * _rng.randf_range(0.7, 1.3)
			turn = it.amount * k * [0.0, 1.0, -0.55][it.pose]
	if not it.turns.is_empty():
		turn += float(it.turns.pop_front())
	elif it.kind == "kick":
		_rest(it, n)
		return false
	if absf(turn) < 0.0001 and off == Vector3.ZERO:
		_rest(it, n)
		return true
	var r := Basis(it.axis, turn)
	_put(it, n, it.base * Transform3D(r, it.pivot - r * it.pivot + off))
	it.resting = false
	return true


## The camp's buildings as they stand: their loose doors and the tents' flaps, once each.
func _scan_camp() -> void:
	var scene := get_tree().current_scene if get_tree() != null else null
	var bm = scene.get("building_manager") if scene != null else null
	var root: Node = (bm as Node).get_node_or_null("Structures") if bm != null and bm is Node else null
	if root == null:
		return
	for s in root.get_children():
		var id := (s as Node).get_instance_id()
		if _seen.has(id) or not (s is Node3D):
			continue
		_seen[id] = true
		var t := str((s as Node).get_meta("building_type", ""))
		for parts in CAMP_DOORS.get(t, []):
			var door := (s as Node).find_child(str(parts[0]), true, false) as Node3D
			if door == null:
				continue
			var with: Array = []
			for k in range(1, (parts as Array).size()):
				var w := (s as Node).find_child(str(parts[k]), true, false) as Node3D
				if w != null:
					with.append(w)
			# In its frame: knocked a few millimetres in and out, a hair round, in bursts.
			add(door, "rattle", Vector3.UP, 0.01, {"shift": Vector3(0, 0, 0.007), "from": 0.8, "with": with, "near": 70.0})
		if t.begins_with("tent_"):
			var flap := (s as Node).find_child("TentFlap", true, false) as MeshInstance3D
			if flap != null and flap.mesh != null:
				# Pegged at its apex, its foot blown in and out.
				var box := flap.mesh.get_aabb()
				add(flap, "flap", Vector3.RIGHT, 0.085, {"pivot": Vector3(0, box.end.y, box.get_center().z), "near": 70.0})


func _rest(it: Item, n: Node3D) -> void:
	if it.resting:
		return
	it.resting = true
	_put(it, n, it.base)


func _put(it: Item, n: Node3D, xf: Transform3D) -> void:
	n.transform = xf
	it.written = n.transform
	var delta := xf * it.base.affine_inverse()
	for g in it.with:
		var gn := (g[0] as WeakRef).get_ref() as Node3D
		if gn != null and is_instance_valid(gn):
			gn.transform = delta * (g[1] as Transform3D)
