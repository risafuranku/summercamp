extends RefCounted

## Inside the generator shed (built by scripts/service_interior.gd for the "generator"
## profile). Two rooms:
##   the set room   the diesel set on its skids, fuel drums, and years of junk: in front
##                  of the steel door at the back a fallen locker, a stack of boxes and
##                  an old mattress. Shove them aside (click each) to get to the door.
##   the switch room behind the door (locked: the key hangs on the office noticeboard,
##                  scripts/closeup/board_closeup.gd): a cold concrete box, a battery
##                  lamp, and the camp's distribution board on the wall. Click the board
##                  for the close-up (scripts/breaker_panel.gd).
## Once moved, the junk stays moved and the door stays unlocked (camp_office saves it).
## Some nights there is a coat hanging in the switch room's corner. Afterwards, there is
## not.

const K = preload("res://scripts/interior_kit.gd")
const HOVER_GLINT = preload("res://scripts/ui/hover_glint.gd")
const SFX_SHOVE := "res://assets/sfx/redneckstructures/"
const SFX_THUD := "res://assets/sfx/rednecksfx/rrtick.wav"
const SFX_DOOR := "res://assets/sfx/dvereotevrit.mp3"
const SFX_LOCKED := "res://assets/sfx/dverebubu.mp3"

var host                      # service_interior
var root: Node3D
var set_root: Node3D
var board_root: Node3D
var room := "set"
var glint = HOVER_GLINT.new()
var hot: Dictionary = {}       # id -> {body, meshes, room}
var _junk: Array = []          # [{id, node, to: Vector3, moved}]
var _door_pivot: Node3D
var _lamp: OmniLight3D
var _coat: Node3D
var _coat_tonight := false
var _hover := ""
var _sfx: AudioStreamPlayer


func build(host_node, parent: Node3D) -> void:
	host = host_node
	root = parent
	_sfx = AudioStreamPlayer.new()
	host.add_child(_sfx)
	set_root = Node3D.new()
	set_root.name = "ShedSetRoom"
	root.add_child(set_root)
	board_root = Node3D.new()
	board_root.name = "ShedSwitchRoom"
	# The switch room is built beside the set room and the camera jumps (with the
	# interior's own swipe), like the shop's storeroom.
	board_root.position = Vector3(0.0, 0.0, -9.0)
	root.add_child(board_root)
	_build_set_room()
	_build_switch_room()
	_apply_saved()


func _office():
	var main = _main()
	return main.get("camp_office") if main != null else null


func _main():
	var n: Node = host
	while n != null and not n.has_method("get_electricity_ui_snapshot"):
		n = n.get_parent()
	return n


func _hot(id: String, parent: Node3D, pos: Vector3, size: Vector3, meshes: Array, which_room: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.set_meta("shed_hot", id)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	parent.add_child(body)
	hot[id] = {"body": body, "meshes": meshes, "room": which_room}
	return body


# ── the set room ─────────────────────────────────────────────────────────────

func _build_set_room() -> void:
	var r := set_root
	K.room(r, Vector3(4.0, 2.8, 4.0), "concrete", "brick_red", "concrete", 1.0, 1.2, 0.05)
	K.prop(r, "generator", Vector3(-0.6, 0.05, -0.4))
	K.prop(r, "oil_drum", Vector3(-1.55, 0.05, -1.5))
	K.prop(r, "oil_drum", Vector3(-1.5, 0.05, 1.3), 30.0)
	K.prop(r, "oil_drum", Vector3(-1.6, 0.05, 0.75), 70.0)
	K.slab(r, Vector3(0.1, 1.4, 0.1), Vector3(-1.5, 2.1, -0.15), K.surface("galvanized", 0.5), "GenPipes")
	K.prop(r, "beer_crates", Vector3(1.5, 0.05, 1.4), 15.0)
	K.prop(r, "cardboard_boxes", Vector3(1.55, 0.05, 0.55), -80.0)
	K.prop(r, "folding_chair", Vector3(0.6, 0.05, 1.2), 140.0)
	# The steel door in the back wall, right of the set.
	var door_frame := K.surface("galvanized", 0.6, Color(0.55, 0.55, 0.52))
	K.slab(r, Vector3(1.0, 2.1, 0.06), Vector3(1.15, 1.1, -1.97), K.surface("planks_dark", 0.6), "SwitchDoorFrame")
	_door_pivot = Node3D.new()
	_door_pivot.position = Vector3(0.7, 0.0, -1.93)
	r.add_child(_door_pivot)
	var leaf := K.slab(_door_pivot, Vector3(0.86, 2.0, 0.05), Vector3(0.45, 1.05, 0.0), door_frame, "SwitchDoor")
	var handle := K.slab(_door_pivot, Vector3(0.06, 0.16, 0.06), Vector3(0.78, 1.0, 0.05), K.surface("galvanized", 0.3), "SwitchDoorHandle")
	var sign := Label3D.new()
	sign.text = "ROZVODNA\nswitch room"
	sign.font_size = 22
	sign.pixel_size = 0.004
	sign.modulate = Color(0.85, 0.2, 0.15)
	sign.outline_size = 0
	sign.position = Vector3(0.45, 1.75, 0.03)
	sign.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_door_pivot.add_child(sign)
	_hot("door", r, Vector3(1.15, 1.05, -1.9), Vector3(0.9, 2.0, 0.2), [leaf, handle], "set")
	# The junk in front of it.
	var locker := K.prop(r, "locker", Vector3(1.05, 0.05, -1.35), 75.0)
	if locker != null:
		locker.rotation_degrees.z = 72.0
		locker.position.y = 0.32
	_junk_item("locker", locker, Vector3(1.85, 0.05, -0.2), Vector3(0.0, 15.0, 0.0), Vector3(1.0, 0.65, 0.6))
	var boxes := K.prop(r, "cardboard_boxes", Vector3(1.4, 0.05, -1.55), 20.0)
	_junk_item("boxes", boxes, Vector3(-0.05, 0.05, 1.55), Vector3(0.0, 120.0, 0.0), Vector3(0.7, 0.8, 0.6))
	var mattress := K.slab(r, Vector3(0.9, 1.8, 0.14), Vector3(1.15, 0.92, -1.72), K.surface("mattress", 0.9), "OldMattress")
	mattress.rotation_degrees.x = 12.0
	_junk_item("mattress", mattress, Vector3(1.85, 0.92, 0.55), Vector3(10.0, 90.0, 0.0), Vector3(1.0, 1.8, 0.3))


func _junk_item(id: String, node: Node3D, to: Vector3, to_rot: Vector3, size: Vector3) -> void:
	if node == null:
		return
	var body := _hot(id, set_root, node.position + Vector3(0, size.y * 0.4, 0), size, [node], "set")
	_junk.append({"id": id, "node": node, "body": body, "to": to, "to_rot": to_rot, "moved": false})


## Saved progress: what has already been moved, whether the door has been opened.
func _apply_saved() -> void:
	var office = _office()
	var moved: Array = office.get("shed_moved") if office != null and office.get("shed_moved") is Array else []
	for j in _junk:
		if moved.has(j["id"]):
			_put_aside(j, false)


func _put_aside(j: Dictionary, animated: bool) -> void:
	j["moved"] = true
	var n: Node3D = j["node"]
	hot.erase(str(j["id"]))
	(j["body"] as Node).queue_free()
	if not animated:
		n.position = j["to"]
		n.rotation_degrees = j["to_rot"]
		return
	# Shoved in three jerks, like everything else that moves in this game.
	var from_p := n.position
	var from_r := n.rotation_degrees
	var tw: Tween = host.create_tween()
	for k in [0.35, 0.7, 1.0]:
		tw.tween_callback(func():
			n.position = from_p.lerp(j["to"], k)
			n.rotation_degrees = from_r.lerp(j["to_rot"], k)
			_play(SFX_THUD, -4.0, randf_range(0.5, 0.7))
		)
		tw.tween_interval(0.12)


## Shoves one piece of junk aside by id (the click does this; the shot driver too).
func shove(id: String) -> void:
	_hover = id
	click()


func junk_left() -> int:
	var n := 0
	for j in _junk:
		if not bool(j["moved"]):
			n += 1
	return n


# ── the switch room ──────────────────────────────────────────────────────────

func _build_switch_room() -> void:
	var r := board_root
	K.room(r, Vector3(2.2, 2.5, 2.6), "concrete", "plaster_stone", "concrete", 1.0, 1.0, 0.05)
	K.skirting(r, Vector3(2.2, 2.5, 2.6), "planks_dark", 0.05)
	# The board on the back wall: its face is the close-up's picture when there is one.
	var face := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 0.75)
	face.mesh = q
	var m := StandardMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var pic := "res://assets/textury/closeup/breaker.png"
	if ResourceLoader.exists(pic):
		m.albedo_texture = load(pic)
	else:
		m.albedo_color = Color(0.42, 0.44, 0.42)
	face.material_override = m
	face.position = Vector3(0.0, 1.45, -1.24)
	r.add_child(face)
	var cab := K.slab(r, Vector3(1.1, 0.85, 0.12), Vector3(0.0, 1.45, -1.3), K.surface("galvanized", 0.6, Color(0.6, 0.62, 0.6)), "BoardCabinet")
	_hot("board", r, Vector3(0.0, 1.45, -1.2), Vector3(1.1, 0.85, 0.2), [face, cab], "board")
	# Cables up into the ceiling.
	for x in [-0.3, -0.1, 0.15, 0.35]:
		K.slab(r, Vector3(0.03, 0.75, 0.03), Vector3(x, 2.2, -1.28), K.surface("planks_dark", 0.3, Color(0.2, 0.2, 0.2)), "Cable")
	# The battery lamp hanging on a nail: the only light here when the main is off.
	K.prop(r, "lantern", Vector3(-0.85, 1.6, -1.2))
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(1.0, 0.72, 0.4)
	_lamp.light_energy = 0.55
	_lamp.omni_range = 3.2
	_lamp.position = Vector3(-0.8, 1.8, -1.0)
	_lamp.shadow_enabled = true
	r.add_child(_lamp)
	# The coat in the corner, some nights.
	_coat = Node3D.new()
	_coat.position = Vector3(0.82, 0.05, -0.95)
	r.add_child(_coat)
	var cloth := K.surface("tarp_canvas", 0.6, Color(0.22, 0.22, 0.24))
	K.slab(_coat, Vector3(0.42, 1.35, 0.26), Vector3(0, 1.0, 0), cloth, "CoatBody")
	K.slab(_coat, Vector3(0.3, 0.12, 0.3), Vector3(0, 1.74, 0.01), cloth, "CoatHat")
	K.slab(_coat, Vector3(0.22, 0.18, 0.2), Vector3(0, 1.6, 0.02), K.surface("tarp_canvas", 0.6, Color(0.12, 0.12, 0.12)), "CoatCollar")
	_coat.visible = false


## The room you are in, and the camera for it.
func set_room(which: String, camera: Camera3D) -> void:
	room = which
	set_root.visible = which == "set"
	board_root.visible = which == "board"
	if camera == null:
		return
	if which == "board":
		camera.position = board_root.position + Vector3(0.0, 1.5, 1.0)
		camera.rotation_degrees = Vector3(-6.0, 0.0, 0.0)
	else:
		camera.position = Vector3(0.0, 1.5, 1.8)
		camera.rotation_degrees = Vector3(-12.0, 0.0, 0.0)


## Called when you walk in: lamps for the hour, the coat or no coat.
func on_open(is_night: bool, nights_visited: int) -> void:
	_coat_tonight = is_night and nights_visited >= 2 and randf() < 0.17
	_coat.visible = _coat_tonight
	set_room("set", host._interior_camera)
	_door_pivot.rotation_degrees.y = 0.0


# ── hover and click ──────────────────────────────────────────────────────────

func update_hover(mouse: Vector2) -> String:
	var hit: Dictionary = host._raycast_world(mouse)
	var n = hit.get("collider", null) as Node
	var id := ""
	while n != null:
		if n.has_meta("shed_hot"):
			id = str(n.get_meta("shed_hot"))
			break
		n = n.get_parent()
	if id != "" and (not hot.has(id) or str(hot[id]["room"]) != room):
		id = ""
	_hover = id
	if id != "":
		HandCursor.want(HandCursor.WALK if id == "door" else HandCursor.POINT)
		glint.show_on(hot[id]["meshes"])
	else:
		glint.clear()
	return id


func click() -> bool:
	match _hover:
		"locker", "boxes", "mattress":
			for j in _junk:
				if str(j["id"]) == _hover and not bool(j["moved"]):
					_put_aside(j, true)
					var office = _office()
					if office != null:
						var moved: Array = office.get("shed_moved") if office.get("shed_moved") is Array else []
						moved.append(_hover)
						office.set("shed_moved", moved)
			glint.clear()
			return true
		"door":
			try_door()
			return true
		"board":
			var main = _main()
			if main != null and main.has_method("open_breaker_board"):
				glint.clear()
				main.open_breaker_board()
			return true
	return false


## Through to the switch room, if you can.
func try_door() -> bool:
	if junk_left() > 0:
		_say("You can't get to the door for the junk in front of it.")
		_play(SFX_LOCKED, -10.0, 1.3)
		return false
	var office = _office()
	if office != null and not bool(office.get("has_shed_key")):
		_say("Locked. The key for it hangs on the noticeboard in the office.")
		_play(SFX_LOCKED, -6.0, 1.0)
		return false
	_play(SFX_DOOR, -6.0, 0.8)
	var tw: Tween = host.create_tween()
	tw.tween_property(_door_pivot, "rotation_degrees:y", 100.0, 0.35)
	tw.tween_callback(func(): host._play_room_swipe("board", 1))
	return true


## Back from the board: the coat is not there any more.
func on_board_closed() -> void:
	if _coat_tonight:
		_coat_tonight = false
		_coat.visible = false


func can_enter_board() -> bool:
	var office = _office()
	return junk_left() == 0 and office != null and bool(office.get("has_shed_key"))


func set_powered(on: bool) -> void:
	if _lamp != null:
		_lamp.light_energy = 0.32 if not on else 0.55


func _say(text: String) -> void:
	var main = _main()
	var hud = main.get("_hud_manager") if main != null else null
	if hud != null:
		hud.push_status(text, 1)


func _play(path: String, db: float, pitch := 1.0) -> void:
	if ResourceLoader.exists(path):
		_sfx.stream = load(path)
		_sfx.volume_db = db
		_sfx.pitch_scale = pitch
		_sfx.play()
