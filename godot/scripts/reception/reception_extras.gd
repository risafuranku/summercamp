extends RefCounted

## The office beyond the computer (scripts/building_interior.gd builds the room and the
## PC; this adds what you do in it when you are not at the screen):
##   - the push-button phone on the counter: click it for the close-up and ring someone
##     (scripts/closeup/phone_closeup.gd, who answers: phone_book.gd);
##   - the cork noticeboard on the right wall with the numbers (board_closeup.gd), and
##     the generator shed's back-room key hanging on it;
##   - the door in the left wall: it opens and you walk through into your own room
##     (scripts/reception/back_room.gd), where the bed is (sleep_sequence.gd).
## Everything usable glints under the cursor (scripts/ui/hover_glint.gd) and gets the
## gloved finger (scripts/ui/hand_cursor.gd).
##
## The camp side of it (the electrician's visit, the key, sleeping through the night)
## lives in scripts/reception/camp_office.gd, reached through main.

const K = preload("res://scripts/interior_kit.gd")
const INTERIOR_LOOK = preload("res://scripts/interior_look.gd")
const HOVER_GLINT = preload("res://scripts/ui/hover_glint.gd")
const BACK_ROOM = preload("res://scripts/reception/back_room.gd")
const SLEEP = preload("res://scripts/reception/sleep_sequence.gd")
const PHONE_CLOSEUP = preload("res://scripts/closeup/phone_closeup.gd")
const BOARD_CLOSEUP = preload("res://scripts/closeup/board_closeup.gd")
const SFX_DOOR := "res://assets/sfx/backroom/door_creak.wav"
const SFX_LATCH := "res://assets/sfx/dverezavrit.mp3"
const BOARD_TEX := "res://assets/textury/closeup/board.png"
const CURTAIN = preload("res://scripts/reception/curtain.gd")
const RL = preload("res://scripts/reception/reception_layout.gd")

## The doorway in the office's left wall (x = -2.55), z 0.79..1.77, 2.1 high.
const DOOR_HINGE := Vector3(-2.43, 0.0, 1.77)
const DOOR_OPEN_DEG := 96.0
const THRESHOLD := Vector3(-2.15, 1.47, 1.28)
const BACK_THRESHOLD := Vector3(-2.95, 1.47, 1.28)

var host
var room_root: Node3D
var camera: Camera3D
var back = BACK_ROOM.new()
var glint = HOVER_GLINT.new()
var where := "office"
var hot: Dictionary = {}   # id -> {body, meshes}
## The office window's floral curtains (open by day; click to draw them).
var office_curtain
var phone_view
var board_view
var sleep
## A whole turn (playtest 2026-10-17): the doorway back to the office is behind you.
var look_back = INTERIOR_LOOK.new(180.0, 26.0, 38.0)
var back_base_rot := Vector3(deg_to_rad(-11.0), deg_to_rad(101.0), 0.0)

var _door_pivot: Node3D
var _phone_root: Node3D
## Someone ringing the office: {call, left (rings), t, done: Callable(answered)}.
var _ring: Dictionary = {}
var _bell3d: AudioStreamPlayer3D
var _walk: Tween
var _hover := ""
var _sfx: AudioStreamPlayer


func build(host_node, root: Node3D, cam: Camera3D) -> void:
	host = host_node
	room_root = root
	camera = cam
	_sfx = AudioStreamPlayer.new()
	host.add_child(_sfx)
	_build_phone()
	_build_board()
	_build_doorway()
	_build_office_curtain()

	if host.has_method("desk_lamp_meshes") and host.get("_desk_lamp_body") != null:
		hot["desklamp"] = {"body": host.get("_desk_lamp_body"), "meshes": host.desk_lamp_meshes()}
	back.build(root, host)
	for id in back.hot.keys():
		hot[id] = back.hot[id]
	_bell3d = AudioStreamPlayer3D.new()
	_bell3d.unit_size = 4.0
	_bell3d.volume_db = 0.0
	if ResourceLoader.exists("res://assets/sfx/phone/bell.mp3"):
		_bell3d.stream = load("res://assets/sfx/phone/bell.mp3")
	_bell3d.position = Vector3(1.1, 1.05, 0.32)
	room_root.add_child(_bell3d)
	phone_view = PHONE_CLOSEUP.new()
	phone_view.context_provider = func(): return _office_call("phone_context", [], {})
	phone_view.on_effect = func(effect: String, number: String): _office_call("on_phone_effect", [effect, number], null)
	phone_view.on_incoming_done = func(answered: bool): _incoming_done(answered)
	host.add_child(phone_view)
	board_view = BOARD_CLOSEUP.new()
	board_view.key_present = func(): return not bool(_office_call("has_shed_key", [], false))
	board_view.on_key_taken = func(): _office_call("take_shed_key", [], null)
	host.add_child(board_view)
	sleep = SLEEP.new()
	host.add_child(sleep)
	sleep.finished.connect(_on_woke)


## The camp-side half (camp_office.gd) through main, or `fallback` without one.
func _office_call(method: String, args: Array, fallback):
	var main = host._resolve_main_runtime_host() if host != null and host.has_method("_resolve_main_runtime_host") else null
	var office = main.get("camp_office") if main != null else null
	if office == null or not office.has_method(method):
		return fallback
	return office.callv(method, args)


func _hot_body(id: String, parent: Node3D, pos: Vector3, size: Vector3, meshes: Array, yaw := 0.0) -> void:
	var body := StaticBody3D.new()
	body.name = "Hot_" + id
	body.set_meta("extra_hot", id)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	body.rotation_degrees.y = yaw
	parent.add_child(body)
	hot[id] = {"body": body, "meshes": meshes}


func _build_phone() -> void:
	for n in ["CounterPhone", "CounterPhoneHandle"]:
		var old := room_root.get_node_or_null(n)
		if old != null:
			old.queue_free()
	# The set as the close-up shows it (playtest 2026-10-17: "model the phone after the
	# picture"): a beige push-button phone, the handset on the left in its cradle, the key
	# deck sloping toward you, the display and the red button, the coiled cord.
	var at := Vector3(1.1, 0.955, 0.32)
	var parts := _phone_model(room_root, at, -16.0 + 180.0)
	_hot_body("phone", room_root, at + Vector3(0, 0.07, 0), Vector3(0.36, 0.18, 0.32), parts, -16.0)
	_phone_root = room_root.get_node_or_null("OfficePhone") as Node3D


## Boxes, Build style, in the set's own plastics, laid out as the picture: the near edge
## (the keys' bottom row) is -Z of the root, which is turned to face whoever stands behind
## the counter; seen from there +X is on your left (the handset), the display and the
## red button along the far edge, the cord off the near left corner.
func _phone_model(parent: Node3D, at: Vector3, yaw: float) -> Array:
	var r := Node3D.new()
	r.name = "OfficePhone"
	r.position = at
	r.rotation_degrees.y = yaw
	r.scale = Vector3.ONE * 1.15
	parent.add_child(r)
	var beige := K.surface("plastic", 0.3, Color(0.86, 0.82, 0.7))
	var deck_mat := K.surface("plastic", 0.3, Color(0.8, 0.76, 0.64))
	var key_mat := K.surface("plastic", 0.2, Color(0.56, 0.57, 0.6))
	var cord := K.surface("plastic", 0.2, Color(0.66, 0.62, 0.52))
	var out: Array = []
	out.append(K.slab(r, Vector3(0.25, 0.05, 0.21), Vector3(0, 0.025, 0), beige, "PhoneBase"))
	var deck := Node3D.new()
	deck.position = Vector3(-0.045, 0.06, 0.0)
	deck.rotation.x = -0.2
	r.add_child(deck)
	out.append(K.slab(deck, Vector3(0.15, 0.03, 0.19), Vector3(0, 0.0, 0), deck_mat, "PhoneDeck"))
	for row in 4:
		for col in 3:
			out.append(K.slab(deck, Vector3(0.026, 0.012, 0.02), Vector3(0.034 - col * 0.034, 0.019, 0.034 - row * 0.03), key_mat, "PhoneKey"))
	out.append(K.slab(deck, Vector3(0.085, 0.006, 0.026), Vector3(0.012, 0.017, 0.072), K.surface("plastic", 0.2, Color(0.38, 0.46, 0.3)), "PhoneLcd"))
	out.append(K.slab(deck, Vector3(0.02, 0.012, 0.018), Vector3(-0.05, 0.02, 0.072), K.surface("plastic", 0.2, Color(0.72, 0.16, 0.12)), "PhoneRed"))
	# The cradle and the handset in it.
	out.append(K.slab(r, Vector3(0.07, 0.03, 0.2), Vector3(0.085, 0.064, 0.0), beige, "PhoneCradle"))
	var hs := Node3D.new()
	hs.name = "Handset"
	hs.position = Vector3(0.085, 0.092, 0.0)
	r.add_child(hs)
	out.append(K.slab(hs, Vector3(0.05, 0.034, 0.12), Vector3(0, 0, 0), beige, "HandsetGrip"))
	for z in [-0.082, 0.082]:
		out.append(K.slab(hs, Vector3(0.066, 0.046, 0.056), Vector3(0, -0.004, z), beige, "HandsetEnd"))
	# The coiled cord, round the side and off toward the wall socket.
	for i in 7:
		var t := float(i) / 6.0
		var p := Vector3(0.13 + sin(t * PI) * 0.035, 0.03 + 0.03 * (1.0 - t), -0.09 + t * 0.12)
		out.append(K.slab(r, Vector3(0.018, 0.018, 0.022), p, cord, "PhoneCord"))
	return out


func _build_office_curtain() -> void:
	var c: Vector3 = RL.OFFICE_WINDOW_CENTER + Vector3(0, 0, 0.2)
	office_curtain = CURTAIN.new()
	office_curtain.build(room_root, c, RL.OFFICE_WINDOW_SIZE.x + 0.1, RL.OFFICE_WINDOW_SIZE.y + 0.3, 0.0, "curtain_floral", 0.7, host, true)
	_hot_body("curtain", room_root, c + Vector3(0, 0, 0.04), Vector3(RL.OFFICE_WINDOW_SIZE.x + 0.5, RL.OFFICE_WINDOW_SIZE.y + 0.4, 0.14), office_curtain.meshes)


func _build_board() -> void:
	# The cork board on the right wall by the counter: its face is the close-up's own
	# picture, so what you click is what you then read.
	var at := Vector3(2.46, 1.5, -0.45)
	var frame := K.surface("planks_dark", 0.5)
	var parts: Array = []
	parts.append(K.slab(room_root, Vector3(0.03, 0.7, 0.92), at + Vector3(-0.005, 0, 0), frame, "BoardFrame"))
	var face := MeshInstance3D.new()
	face.name = "BoardFace"
	var q := QuadMesh.new()
	q.size = Vector2(0.86, 0.645)
	face.mesh = q
	var m := StandardMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	if ResourceLoader.exists(BOARD_TEX):
		m.albedo_texture = load(BOARD_TEX)
	face.material_override = m
	face.position = at + Vector3(-0.025, 0, 0)
	face.rotation_degrees.y = -90.0
	room_root.add_child(face)
	parts.append(face)
	_hot_body("board", room_root, at + Vector3(-0.04, 0, 0), Vector3(0.1, 0.7, 0.92), parts)


## Cuts the doorway into the office's left wall and hangs the door on a hinge.
func _build_doorway() -> void:
	var wall := room_root.get_node_or_null("WallLeft")
	if wall != null:
		wall.queue_free()
		host._add_box(room_root, "WallLeftA", Vector3(-2.55, 1.4, -0.86), Vector3(0.1, 2.8, 3.28), Color(0.64, 0.48, 0.34))
		host._add_box(room_root, "WallLeftB", Vector3(-2.55, 1.4, 2.135), Vector3(0.1, 2.8, 0.73), Color(0.64, 0.48, 0.34))
		host._add_box(room_root, "WallLeftTop", Vector3(-2.55, 2.45, 1.28), Vector3(0.1, 0.7, 0.98), Color(0.64, 0.48, 0.34))
	var frame := room_root.get_node_or_null("DoorFrame")
	if frame != null:
		# The old frame was a solid board over the wall; now an open frame round the hole.
		frame.queue_free()
		var fm := K.surface("planks_dark", 0.6)
		K.slab(room_root, Vector3(0.14, 2.14, 0.06), Vector3(-2.5, 1.07, 0.76), fm, "DoorJambA")
		K.slab(room_root, Vector3(0.14, 2.14, 0.06), Vector3(-2.5, 1.07, 1.80), fm, "DoorJambB")
		K.slab(room_root, Vector3(0.14, 0.07, 1.1), Vector3(-2.5, 2.14, 1.28), fm, "DoorLintel")
	_door_pivot = Node3D.new()
	_door_pivot.name = "DoorHinge"
	_door_pivot.position = DOOR_HINGE
	room_root.add_child(_door_pivot)
	var meshes: Array = []
	for n in ["DoorLeaf", "DoorHandle"]:
		var part := room_root.get_node_or_null(n) as Node3D
		if part == null:
			continue
		var p := part.position
		room_root.remove_child(part)
		_door_pivot.add_child(part)
		part.position = p - DOOR_HINGE
		meshes.append(part)
	_hot_body("door", _door_pivot, Vector3(0.0, 1.05, -0.49), Vector3(0.12, 2.04, 0.98), meshes)
	# The open doorway, seen from the back room: the way back to the office (the leaf
	# has swung out of it).
	var jambs: Array = []
	for n in ["DoorJambA", "DoorJambB", "DoorLintel"]:
		var j := room_root.get_node_or_null(n)
		if j != null:
			jambs.append(j)
	_hot_body("doorway", room_root, Vector3(-2.55, 1.05, 1.28), Vector3(0.3, 2.04, 0.96), jambs)


# ── the phone ringing ────────────────────────────────────────────────────────

## Someone rings the office: `call` as phone_book makes them ({who, lines, effect...}),
## `rings` before they give up; `done(answered)` after. The set rings in the room (and
## outside, building_interior) whether or not you are there; pick it up in the close-up.
func start_incoming(call: Dictionary, rings: int, done := Callable()) -> void:
	if not _ring.is_empty():
		return
	_ring = {"call": call, "left": maxi(1, rings), "t": 0.0, "done": done}
	_ring_once()


func is_ringing() -> bool:
	return not _ring.is_empty()


func _ring_once() -> void:
	if phone_view != null and phone_view.visible:
		return
	if _bell3d != null and _bell3d.stream != null:
		_bell3d.play()
	if host != null and host.has_method("ring_outdoor"):
		host.ring_outdoor()
	if _phone_root != null:
		# The handset jumps in its cradle with the bell.
		var hs := _phone_root.get_node_or_null("Handset") as Node3D
		if hs != null:
			var tw: Tween = host.create_tween()
			for k in 6:
				tw.tween_property(hs, "position:y", 0.098 if k % 2 == 0 else 0.092, 0.05)


## Every frame, the room open or not (building_interior._process).
func tick_ring(delta: float) -> void:
	if _ring.is_empty():
		return
	if phone_view != null and phone_view.visible and not phone_view.is_ringing_in() and int(phone_view.get("_state")) == 0:
		phone_view.incoming(_ring["call"])
	_ring["t"] = float(_ring["t"]) + delta
	if float(_ring["t"]) >= 3.6:
		_ring["t"] = 0.0
		_ring["left"] = int(_ring["left"]) - 1
		if int(_ring["left"]) <= 0:
			if phone_view != null and phone_view.is_ringing_in():
				phone_view.stop_incoming()
			else:
				_incoming_done(false)
			return
		_ring_once()


func _incoming_done(answered: bool) -> void:
	if _ring.is_empty():
		return
	var done: Callable = _ring.get("done", Callable())
	_ring = {}
	if _bell3d != null:
		_bell3d.stop()
	if done.is_valid():
		done.call(answered)


# ── per frame ────────────────────────────────────────────────────────────────

func is_modal() -> bool:
	return (phone_view != null and phone_view.visible) or (board_view != null and board_view.visible) \
		or (sleep != null and sleep.is_running()) or _walking() \
		or (host != null and host.has_method("is_desk_open") and host.is_desk_open())


func in_back_room() -> bool:
	return where == "back"


func _walking() -> bool:
	return _walk != null and is_instance_valid(_walk) and _walk.is_running()


## Returns true when this owns the camera this frame (walking, sleeping, the back room).
func process(delta: float, hour: float) -> bool:
	back.update(delta, hour)
	var moved := false
	if office_curtain != null and office_curtain.update(delta):
		moved = true
	if back.curtain != null and not is_equal_approx(back.curtain.open, back.curtain.target):
		moved = true
	# Drawing a curtain changes the light in the room and the window seen from outside.
	if moved and host.has_method("_apply_room_time_profile"):
		host._apply_room_time_profile()
	if is_modal():
		glint.clear()
		_hover = ""
		return true
	_hover = _hover_under_mouse()
	if _hover != "":
		HandCursor.want(HandCursor.WALK if _hover in ["door", "doorway", "front_door"] else HandCursor.POINT)
		glint.show_on(hot[_hover]["meshes"])
	else:
		glint.clear()
	if where == "back":
		var vp: Viewport = host.get_viewport()
		var offset: Vector3 = look_back.update(delta, INTERIOR_LOOK.cursor_of(vp), INTERIOR_LOOK.key_axis())
		var want: Vector3 = back_base_rot + offset
		# The yaw wraps round: follow it the short way.
		want.y = camera.rotation.y + wrapf(want.y - camera.rotation.y, -PI, PI)
		camera.rotation = camera.rotation.lerp(want, clampf(delta * 30.0, 0.0, 1.0))
		if INTERIOR_LOOK.in_exit_zone(vp):
			HandCursor.want(HandCursor.WALK)
		return true
	return false


func hovered() -> String:
	return _hover


func _hover_under_mouse() -> String:
	var mouse: Vector2 = host.get_viewport().get_mouse_position()
	if where == "back" and INTERIOR_LOOK.in_exit_zone(host.get_viewport()):
		return ""
	var hit: Dictionary = host._raycast_room(mouse)
	var n = hit.get("collider", null) as Node
	while n != null:
		if n.has_meta("extra_hot"):
			var id := str(n.get_meta("extra_hot"))
			# Only what is in the room you are in.
			var in_back: bool = back.hot.has(id)
			if id == "doorway":
				return id if where == "back" else ""
			if id == "front_door":
				return id if where == "office" else ""
			if (where == "back") == in_back or id == "door":
				return id
			return ""
		n = n.get_parent()
	return ""


func click() -> bool:
	if is_modal():
		return true
	match _hover:
		"phone":
			glint.clear()
			phone_view.open_view()
		"guest", "bell":
			glint.clear()
			host.open_checkin_desk()
		"board":
			glint.clear()
			board_view.open_view()
		"door":
			if where == "back":
				go_office()
			else:
				go_back_room()
		"doorway":
			go_office()
		"front_door":
			glint.clear()
			_play("res://assets/sfx/dvereotevrit.mp3", -8.0)
			host.close_interior()
		"bed":
			_try_sleep()
		"tv":
			back.toggle_tv()
		"curtain":
			office_curtain.toggle()
		"back_curtain":
			back.curtain.toggle()
		"desklamp":
			host.toggle_desk_lamp()
		"lamp":
			back.toggle_lamp()
		_:
			return false
	return true


## S or the bottom edge in the back room takes you back to the office, not outside.
func handle_exit() -> bool:
	if where != "back":
		return false
	if not is_modal():
		go_office()
	return true


# ── walking between the rooms ────────────────────────────────────────────────

func go_back_room() -> void:
	if _walking() or where == "back":
		return
	glint.clear()
	_play(SFX_DOOR, -9.0)
	_walk = host.create_tween()
	_walk.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_walk.tween_property(_door_pivot, "rotation_degrees:y", DOOR_OPEN_DEG, 0.55)
	_walk.parallel().tween_property(camera, "rotation", Vector3(0.0, deg_to_rad(90.0), 0.0), 0.55)
	_walk.parallel().tween_property(camera, "position", Vector3(-1.1, 1.47, 1.28), 0.55)
	_walk.tween_property(camera, "position", THRESHOLD, 0.45)
	_walk.tween_property(camera, "position", BACK_ROOM.STAND, 0.7)
	_walk.parallel().tween_property(camera, "rotation", back_base_rot, 0.7)
	_walk.tween_callback(func():
		where = "back"
		look_back.reset()
	)


func go_office() -> void:
	if _walking() or where != "back":
		return
	glint.clear()
	var to_pos: Vector3 = host._initial_cam_pos
	var to_rot: Vector3 = host._initial_cam_rot
	var face := deg_to_rad(-90.0)
	camera.rotation.y = wrapf(camera.rotation.y, face - PI, face + PI)
	_walk = host.create_tween()
	_walk.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_walk.tween_property(camera, "rotation", Vector3(0.0, deg_to_rad(-90.0), 0.0), 0.45)
	_walk.parallel().tween_property(camera, "position", BACK_THRESHOLD, 0.45)
	_walk.tween_property(camera, "position", Vector3(-1.4, 1.42, 1.3), 0.6)
	_walk.tween_property(camera, "position", to_pos, 0.55)
	_walk.parallel().tween_property(camera, "rotation", to_rot, 0.55)
	_walk.parallel().tween_property(_door_pivot, "rotation_degrees:y", 0.0, 0.5)
	_walk.tween_callback(func():
		where = "office"
		_play(SFX_LATCH, -14.0)
		if host.get("_look") != null:
			host._look.reset()
	)


## Back to the office at once (the interior is opened again, or closed).
func reset_to_office() -> void:
	if _walk != null and is_instance_valid(_walk):
		_walk.kill()
	where = "office"
	if _door_pivot != null:
		_door_pivot.rotation_degrees.y = 0.0
	glint.clear()
	if phone_view != null and phone_view.visible:
		phone_view.close_view()
	if board_view != null and board_view.visible:
		board_view.close_view()


func _play(path: String, db: float) -> void:
	if ResourceLoader.exists(path):
		_sfx.stream = load(path)
		_sfx.volume_db = db
		_sfx.play()


# ── sleep ────────────────────────────────────────────────────────────────────

func _try_sleep() -> void:
	var refusal := str(_office_call("sleep_refusal", [], ""))
	if refusal != "":
		_office_call("say", [refusal], null)
		return
	var lie: Array = back.lie_pose()
	sleep.camera = camera
	sleep.lie_pos = lie[0]
	sleep.lie_rot = lie[1]
	sleep.stand_pos = BACK_ROOM.STAND + Vector3(-0.9, 0.0, -0.2)
	sleep.stand_rot = Vector3(deg_to_rad(-9.0), deg_to_rad(100.0), 0.0)
	sleep.lamp = func(on: bool): back.set_lamp(on)
	sleep.tv_focus = func(_on: bool): pass
	sleep.fast_forward = func(): _office_call("start_sleep", [], null)
	sleep.fast_forward_done = func(): return not bool(_office_call("is_sleeping_through", [], false))
	sleep.wake_text = func(): return str(_office_call("clock_text", [], "06:30"))
	glint.clear()
	sleep.start()


func _on_woke() -> void:
	back.set_lamp(true)
	look_back.reset()
	_office_call("on_woke", [], null)
