extends RefCounted

## The doors between the rooms of a pub, the bistro and the Jednota (scripts/service_interior.gd
## builds the rooms and asks for them), point and click (DESIGN §10): a door glints under
## the cursor with the flat palm (scripts/ui/hover_glint.gd, hand_cursor.gd), a click
## and you walk to it, it swings open on the dark behind it, the room breaks up into the
## next (scripts/ui/door_transition.gd) and you come in through that room's door, which
## swings shut behind you. No more pushing the head on past the end of the turn or the
## side tabs.
##
## A door is set into the inside face of a wall: a frame, the leaf on its hinge with the
## painted face both sides (assets/textury/camp/door_interior.png), the dark of the way
## beyond it, and a click box over it.

const K = preload("res://scripts/interior_kit.gd")
const WALK_PATH = preload("res://scripts/ui/walk_path.gd")
const HOVER_GLINT = preload("res://scripts/ui/hover_glint.gd")
const DOOR_TEX := "res://assets/textury/camp/door_interior.png"
const SFX_DOOR := "res://assets/sfx/backroom/room_door_open.mp3"
const SFX_STEPS := "res://assets/sfx/rooms/steps_wood.mp3"
const W := 0.95
const H := 2.02
const OPEN_DEG := 92.0

var host: Node                # service_interior
## id -> {room, to, arrive, root, pivot, centre (room), inward (room), meshes, body}
var doors: Dictionary = {}
var glint = HOVER_GLINT.new()
var _walk: Tween
var _hover := ""


## A door `id` in `root` (room `room`): its centre on the wall's inside face at `centre`
## (floor y 0), `inward` the wall's normal into the room; through it to room `to`,
## coming in there by its door `arrive`.
func add(id: String, room: String, root: Node3D, centre: Vector3, inward: Vector3, to: String, arrive: String) -> void:
	inward = inward.normalized()
	var along := Vector3.UP.cross(inward).normalized()
	var yaw := atan2(inward.x, inward.z)
	var fm := K.surface("planks_dark", 0.6)
	# The dark beyond the door (stairs, a passage), just proud of the wall.
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.02, 0.018, 0.015)
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var hole := K.slab(root, Vector3(W, H, 0.01), centre + Vector3(0, H * 0.5, 0) + inward * 0.006, dark, "DoorDark_" + id)
	hole.rotation.y = yaw
	for side in [-1.0, 1.0]:
		var j := K.slab(root, Vector3(0.07, H + 0.06, 0.07), centre + along * side * (W * 0.5 + 0.035) + Vector3(0, (H + 0.06) * 0.5, 0) + inward * 0.035, fm, "DoorJamb_" + id)
		j.rotation.y = yaw
	var lintel := K.slab(root, Vector3(W + 0.14, 0.07, 0.07), centre + Vector3(0, H + 0.035, 0) + inward * 0.035, fm, "DoorLintel_" + id)
	lintel.rotation.y = yaw
	# The leaf on its hinge at one side, flush in the frame.
	var pivot := Node3D.new()
	pivot.name = "DoorHinge_" + id
	pivot.position = centre - along * (W * 0.5) + inward * 0.03
	pivot.rotation.y = yaw
	root.add_child(pivot)
	var meshes: Array = []
	var leaf := K.slab(pivot, Vector3(W - 0.02, H - 0.02, 0.04), Vector3(W * 0.5, H * 0.5, 0), K.surface("planks_dark", 0.8), "DoorLeaf")
	meshes.append(leaf)
	if ResourceLoader.exists(DOOR_TEX):
		var tex: Texture2D = load(DOOR_TEX)
		for s in [1.0, -1.0]:
			var q := MeshInstance3D.new()
			q.name = "DoorFace"
			var qm := QuadMesh.new()
			qm.size = Vector2(W - 0.03, H - 0.03)
			q.mesh = qm
			var m := StandardMaterial3D.new()
			m.albedo_texture = tex
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			m.roughness = 1.0
			if s < 0.0:
				m.uv1_scale = Vector3(-1, 1, 1)
			q.material_override = m
			q.position = Vector3(W * 0.5, H * 0.5, 0.022 * s)
			q.rotation.y = 0.0 if s > 0.0 else PI
			pivot.add_child(q)
			meshes.append(q)
	var body := StaticBody3D.new()
	body.name = "Door_" + id
	body.set_meta("business_door", id)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(W, H, 0.16)
	shape.shape = box
	body.add_child(shape)
	body.position = centre + Vector3(0, H * 0.5, 0) + inward * 0.06
	body.rotation.y = yaw
	root.add_child(body)
	doors[id] = {"room": room, "to": to, "arrive": arrive, "root": root, "pivot": pivot, "centre": centre, "inward": inward, "meshes": meshes, "body": body}


func clear() -> void:
	glint.clear()
	doors.clear()
	_hover = ""
	if _walk != null and _walk.is_valid():
		_walk.kill()
	_walk = null


func walking() -> bool:
	return _walk != null and _walk.is_valid() and _walk.is_running()


## The door under the cursor in room `room` ("" none): it glints, the palm shows.
func hover(collider: Node, room: String) -> String:
	var id := ""
	var n := collider
	while n != null:
		if n.has_meta("business_door"):
			id = str(n.get_meta("business_door"))
			break
		n = n.get_parent()
	if id != "" and str((doors.get(id, {}) as Dictionary).get("room", "")) != room:
		id = ""
	if id != _hover:
		_hover = id
		glint.show_on(doors[id]["meshes"] if id != "" else [])
	return id


## Through door `id`: to it, open, the next room, in through its door. `switch` puts the
## next room up (service_interior._apply_service_subroom); `stand` is where you stand
## in it and how you look [position, rotation] (the room's own camera).
## (`done`: called when you stand in the other room.)
func go(id: String, camera: Camera3D, switch: Callable, stand_of: Callable, door_fx: Callable, done := Callable()) -> void:
	if walking() or not doors.has(id):
		return
	var d: Dictionary = doors[id]
	glint.clear()
	_hover = ""
	var root: Node3D = d["root"]
	var c: Vector3 = d["centre"]
	var inward: Vector3 = d["inward"]
	var face := Vector3(0.0, atan2(inward.x, inward.z), 0.0)
	_play(SFX_STEPS, -10.0)
	_walk = WALK_PATH.play(host, camera, [
		{"pos": camera.position, "rot": camera.rotation},
		{"pos": c + inward * 0.85 + Vector3(0, camera.position.y, 0), "rot": face},
	], 0.95)
	_walk.parallel().tween_callback(_play.bind(SFX_DOOR, -9.0)).set_delay(0.45)
	_walk.parallel().tween_property(d["pivot"], "rotation:y", (d["pivot"] as Node3D).rotation.y - deg_to_rad(OPEN_DEG), 0.6).set_delay(0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_walk.tween_callback(func():
		door_fx.call()
		var leaf: Node3D = d["pivot"]
		leaf.rotation.y += deg_to_rad(OPEN_DEG)
		switch.call(str(d["to"]))
		_come_in(str(d["arrive"]), camera, stand_of, done)
	)


## The door in room `room` that leads to room `to` ("" none).
func door_to(room: String, to: String) -> String:
	for id in doors:
		if str(doors[id]["room"]) == room and str(doors[id]["to"]) == to:
			return str(id)
	return ""


## In through door `arrive` of the room just put up: a step in from it to where you stand.
func _come_in(arrive: String, camera: Camera3D, stand_of: Callable, done := Callable()) -> void:
	var stand: Array = stand_of.call()
	if not doors.has(arrive):
		camera.position = stand[0]
		camera.rotation = stand[1]
		if done.is_valid():
			done.call()
		return
	var d: Dictionary = doors[arrive]
	var inward: Vector3 = d["inward"]
	var c: Vector3 = d["centre"]
	var pivot: Node3D = d["pivot"]
	var shut := pivot.rotation.y
	pivot.rotation.y = shut - deg_to_rad(OPEN_DEG)
	camera.position = c + inward * 0.45 + Vector3(0, (stand[0] as Vector3).y, 0)
	camera.rotation = Vector3(0.0, atan2(-inward.x, -inward.z), 0.0)
	_walk = WALK_PATH.play(host, camera, [
		{"pos": camera.position, "rot": camera.rotation},
		{"pos": stand[0], "rot": stand[1]},
	], 1.0)
	_walk.parallel().tween_property(pivot, "rotation:y", shut, 0.7).set_delay(0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_walk.parallel().tween_callback(_play.bind("res://assets/sfx/dverezavrit.mp3", -12.0)).set_delay(0.95)
	if done.is_valid():
		_walk.tween_callback(done)


func _play(path: String, db: float) -> void:
	if host == null or not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = db
	host.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
