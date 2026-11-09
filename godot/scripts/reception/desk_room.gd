extends RefCounted

## The counter side of the office (scripts/building_interior.gd builds the room; this,
## the people at it). Whoever waits at reception (GuestManager.get_desk_queue()) stands
## across the counter from you, the next one by the bench under the window. They come
## in by the front door; the one at the counter rings the bell when you are not at the
## desk, and again if you leave them standing. Click them, or the bell, and the desk
## close-up opens (scripts/reception/checkin_desk.gd).
##
## Late at night, from the second night, when nobody is waiting and you are in the
## office, now and then somebody is at the counter who did not come in by the door.
## He has no booking. What you do with him is up to you (checkin_desk.gd); main hears
## how many such you let in (the omens draw on it, scripts/omens.gd).

const DESK = preload("res://scripts/reception/checkin_desk.gd")
const K = preload("res://scripts/interior_kit.gd")
const BELL_TEX := "res://assets/textury/desk/bell.png"
const SFX_BELL := "res://assets/sfx/desk/bell.mp3"
const SFX_DOOR := "res://assets/sfx/desk/door.mp3"
const STRANGER_SPRITE := "res://assets/textury/npc/host1.png"

## Room coordinates (building_interior.gd): the counter runs along z = 0.2, you stand
## behind it at z = 1.15, the front door is in the window wall at x = 1.25..2.2.
const COUNTER_SPOT := Vector3(0.42, 0.0, -0.62)
const BENCH_SPOT := Vector3(-1.05, 0.0, -1.95)
const DOOR_HINGE := Vector3(2.2, 0.0, -2.55)
const DOOR_W := 0.95
const BELL_POS := Vector3(0.98, 1.0, 0.02)
const POLL_SEC := 0.5
## The one of the staffroom's hands who has the reception (Richard 8. 11.: "the staff clean
## and are at the reception"; it was a line in their books: you came in and nobody stood
## behind the counter, the guest rang at nobody): by the key board, turned to whoever is
## across it; a step back while you are at the desk yourself. Seen through the panes too.
const HAND_SPOT := Vector3(1.3, 0.0, 0.78)
const HAND_ASIDE := Vector3(1.46, 0.0, 1.34)
const HAND_M := 1.74
const DOOM_HAND = preload("res://scripts/figures/doom_figure.gd")
## The check-in played on the counter itself (the user 30. 10.), checkin_desk.gd's picture
## laid on it: its counter part (y 104..270 of the 384) over the counter's top left of the
## phone, the far edge where the guest stands; its key board (x 284..478, y 280..384) in the
## drawer under the counter's edge. Your eye over the counter; look up at the guest.
const INTERIOR_LOOK = preload("res://scripts/interior_look.gd")
const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const HOVER_GLINT = preload("res://scripts/ui/hover_glint.gd")
const DESK_EYE := Vector3(0.1, 1.42, 0.56)
const DESK_LOOK_AT := Vector3(0.12, 0.965, 0.097)
const SHEET_X0 := -0.52
const SHEET_W := 1.45
const SHEET_Z0 := -0.17
const SHEET_D := 0.5015
const SHEET_Y := 0.965
const SHEET_PX_Y := Vector2(104.0, 166.0)
const BOARD_PX := Rect2(284, 280, 194, 104)
## The keys, in a drawer under the counter (the user 9. 11.: "move the keys to a drawer under
## the counter, the way to the keys on the wall is quite awkward"): at the back of the bite out
## of your side of the counter (building_interior: its front in view from over the register).
## It comes out to you and the eye leans back from the counter, so that the keys, the papers
## and whoever is across it are all in view: a key goes straight to them, no turn of the head.
const DRAWER_X := 0.33
const DRAWER_FELT_Y := 0.823
const DRAWER_SHUT_Z := 0.351
const DRAWER_OPEN_Z := 0.79
const DRAWER_DEEP := 0.5
const DRAWER_PIC := Vector2(0.8, 0.429)
const DRAWER_EYE := Vector3(0.32, 1.5, 1.0)
const DRAWER_LOOK_AT := Vector3(0.32, 0.9, 0.44)
const DRAWER_SEC := 0.42
const SFX_DRAWER := "res://assets/sfx/jednota/drawer.mp3"
## The stamps, standing on the counter (the user 9. 11.: "make the stamps 3D objects, so they
## are not so flat on that board"): how far off the paper one is carried, how long the press.
const STAMP_LIFT := 0.07
const STAMP_PRESS_SEC := 0.3
const STAMP_INK := {"in": Color(0.3, 0.72, 0.36), "out": Color(0.86, 0.26, 0.2)}
const DYMO_LIFT := 0.03
const STEP_SEC := 0.6
## Carried over the counter: where the guest's side begins on the counter's picture (a share
## of its depth from the far edge), the plane it goes along on the way to them, the row of
## the desk's picture that means "over there" (above its GIVE), its picture's size in the
## room, and the last of the way as you let go.
const AIR_V := 0.08
const AIR_Z := -0.36
const AIR_PX_Y := 40.0
const AIR_M_PER_PX := 0.0022
const GIVE_SEC := 0.22
const RING_AGAIN_SEC := 28.0
const STRANGER_ID := -77

var host
var extras
var room_root: Node3D
var desk
var admitted := 0

var _front: Sprite3D
var _second: Sprite3D
var _bell: MeshInstance3D
var _door_pivot: Node3D
var _door_t := -1.0
var _audio: AudioStreamPlayer
var _queue: Array = []
var _poll := 0.0
var _front_id := -999
var _unseen_t := 0.0
## Going over to the PC from the counter: its screen (-1 not).
var _to_pc := -1
var _ring_t := 0.0
var _stranger: Dictionary = {}
var _stranger_night := -1
var _stranger_wait := -1.0
var _pending_state: Dictionary = {}
var _tex_cache: Dictionary = {}
var look = INTERIOR_LOOK.new(112.0, 44.0, 12.0)
var _sheet: MeshInstance3D
var _board: MeshInstance3D
var _board_t := 0.0
var _drawer: Node3D
var _drawer_pull: Array = []
var _drawer_open := false
## How far out, 0..1 in time (_drawer_k: as it moves).
var _drawer_t := 0.0
var _drawer_rot := Vector3.ZERO
var _front_hot := false
var _glint = HOVER_GLINT.new()
## kind -> {root, home, press (seconds into the press, -1 not), label}
var _stamps: Dictionary = {}
## The label maker beside them, lifted a little while it is in your hand.
var _dymo: Node3D
var _at_desk := false
var _cam_from: Array = []
var _cam_tween: Tween
var _desk_rot := Vector3.ZERO
var _air: MeshInstance3D
## A harness's pointer in the room's picture (the machine's own mouse is everybody's).
var debug_pointer := Vector2(-1, -1)
var _say_layer: CanvasLayer
var _say_label: Label
var _say_t := 0.0
## The band at the screen's edges that turns the head at the counter, and how long first.
## The look's dead middle at the counter (the work fills the picture).
const DESK_DEAD := 0.5


func build(host_node, extras_node, root: Node3D) -> void:
	host = host_node
	extras = extras_node
	room_root = root
	_audio = AudioStreamPlayer.new()
	_audio.volume_db = -6.0
	host.add_child(_audio)
	_front = _make_person("DeskGuest")
	_second = _make_person("DeskGuestNext")
	_build_bell()
	_build_door()
	_build_stamps()
	_build_dymo()
	_hot("guest", COUNTER_SPOT + Vector3(0, 0.9, 0), Vector3(0.8, 1.8, 0.5), [])
	_hot("bell", BELL_POS + Vector3(0, 0.06, 0), Vector3(0.26, 0.22, 0.26), [_bell])
	desk = DESK.new()
	desk.mode_3d = true
	desk.on_say = func(text: String): _say(text)
	desk.key_board_provider = func(): return GuestManager.get_key_board() if GuestManager != null else []
	desk.check_in_call = func(id: int):
		# Co-op: checked in for real in the host's camp; here at once, for the desk.
		if Coop.is_client():
			Coop.send_request("checkin", [id])
		return GuestManager.request_check_in(id) if GuestManager != null else {"ok": false}
	desk.next_guest_provider = _next_for_desk
	# How bad tonight is, for what the desk sees across the counter at night.
	desk.pressure_provider = func():
		var dread = host.get("_dread") if host != null else null
		return float(dread.get("dread")) if dread != null else 0.0
	desk.refused.connect(func(id: int):
		if Coop.is_client():
			Coop.send_request("refuse", [id])
		if GuestManager != null:
			GuestManager.refuse_at_desk(id)
		_poll = 0.0
	)
	desk.checked_in.connect(func(_id: int):
		_open_door()
		_poll = 0.0
	)
	desk.stranger_admitted.connect(func():
		admitted += 1
		_stranger = {}
		_poll = 0.0
	)
	desk.stranger_refused.connect(func():
		_stranger = {}
		_poll = 0.0
	)
	host.add_child(desk)
	if not _pending_state.is_empty():
		import_state(_pending_state)


func export_state() -> Dictionary:
	var d: Dictionary = desk.export_state() if desk != null else _pending_state.duplicate(true)
	d["admitted"] = admitted
	d["stranger_night"] = _stranger_night
	return d


func import_state(d: Dictionary) -> void:
	admitted = int(d.get("admitted", 0))
	_stranger_night = int(d.get("stranger_night", -1))
	if desk == null:
		_pending_state = d.duplicate(true)
		return
	desk.import_state(d)
	_pending_state = {}


## Co-op: the register and the key hooks, both ways (main polls it, Coop.send_sync
## "register"); what comes in is merged with what was written here.
func coop_register() -> Dictionary:
	return desk.export_state() if desk != null else {}


func coop_take_register(d: Dictionary) -> void:
	if desk != null:
		desk.coop_merge(d)


func is_open() -> bool:
	return desk != null and desk.visible


func open() -> void:
	if desk == null:
		return
	_ring_t = 0.0
	desk.open_desk(_front_info(), CoreRoot.get_day() if CoreRoot != null else 1)
	if desk.visible and not _at_desk:
		_step_up()


## Leaving the office: whoever is not booked is not there when you come back.
func on_left_office() -> void:
	if not _stranger.is_empty():
		_stranger = {}
	_stranger_wait = -1.0
	# The warden went out by it (reception_extras.go_out_front): shut behind him.
	if _door_t < 0.0 and _door_pivot != null:
		_door_pivot.rotation_degrees.y = 0.0


func front_door() -> Node3D:
	return _door_pivot


# ── every frame (building_interior.gd, while the office is open) ─────────────

func process(delta: float, in_office: bool) -> void:
	_tick_desk(delta)
	_tick_drawer(delta)
	_tick_stamps(delta)
	_tick_dymo(delta)
	# The drawer is in the counter from the moment you come in, not only at the desk.
	_board_t -= delta
	if _board_t <= 0.0:
		_board_t = 1.0
		if _sheet == null or not is_instance_valid(_sheet):
			_make_sheets()
			_sheet.visible = _at_desk
	_poll -= delta
	if _poll <= 0.0:
		_poll = POLL_SEC
		_queue = GuestManager.get_desk_queue() if GuestManager != null else []
		_tick_stranger(POLL_SEC, in_office)
		_place_people()
		_place_hand()
	_turn_hand(delta)
	if _door_t >= 0.0:
		_door_t += delta
		var k := 0.0
		if _door_t < 0.5:
			k = _door_t / 0.5
		elif _door_t < 2.4:
			k = 1.0
		elif _door_t < 3.0:
			k = 1.0 - (_door_t - 2.4) / 0.6
		else:
			_door_t = -1.0
		# In steps, like everything that moves in here.
		_door_pivot.rotation_degrees.y = floorf(k * 6.0) / 6.0 * 82.0
	if not is_open() and _front_id != -999 and in_office and desk_hand() == "":
		_ring_t += delta
		if _ring_t >= RING_AGAIN_SEC:
			_ring_t = 0.0
			_ring()


# ── at the counter (3D) ──────────────────────────────────────────────────────

func _step_up() -> void:
	_make_sheets()
	_sheet.visible = true
	# The office's own notebook lies where the register is laid.
	var book := room_root.get_node_or_null("ReceptionNotebook") as Node3D
	if book != null:
		book.visible = false
	var cam: Camera3D = host._interior_camera
	_cam_from = [cam.position, cam.rotation]
	_desk_rot = Transform3D(Basis(), DESK_EYE).looking_at(DESK_LOOK_AT, Vector3.UP).basis.get_euler()
	_drawer_rot = Transform3D(Basis(), DRAWER_EYE).looking_at(DRAWER_LOOK_AT, Vector3.UP).basis.get_euler()
	look.reset()
	_at_desk = true
	_glide(DESK_EYE, _desk_rot)


func _step_down() -> void:
	_at_desk = false
	desk.in_air = false
	desk.stamp_3d_hover = ""
	_front_hot = false
	_glint.clear()
	_set_drawer(false)
	if _air != null:
		_air.visible = false
	if _sheet != null:
		_sheet.visible = false
	var book := room_root.get_node_or_null("ReceptionNotebook") as Node3D
	if book != null:
		book.visible = true
	_say("")
	if _to_pc >= 0:
		# Straight over to the PC from where you are.
		var screen := _to_pc
		_to_pc = -1
		_cam_from = []
		host.go_to_pc(screen)
		return
	if not _cam_from.is_empty():
		_glide(_cam_from[0], _cam_from[1])
		_cam_from = []


func _glide(pos: Vector3, rot: Vector3) -> void:
	var cam: Camera3D = host._interior_camera
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	rot.y = cam.rotation.y + wrapf(rot.y - cam.rotation.y, -PI, PI)
	_cam_tween = host.create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_property(cam, "position", pos, STEP_SEC)
	_cam_tween.tween_property(cam, "rotation", rot, STEP_SEC)


func _gliding() -> bool:
	return _cam_tween != null and _cam_tween.is_valid() and _cam_tween.is_running()


## The eye on its way to or from the counter: the room leaves it alone till it is there
## (the room's own look set the turn back at once, the position still gliding: the user
## 4. 11., "tranzice není dostatečně plynulá").
func gliding() -> bool:
	return _gliding()


func _tick_desk(delta: float) -> void:
	if _say_t > 0.0:
		_say_t -= delta
		if _say_t <= 0.0 and _say_label != null:
			_say_label.visible = false
	if not _at_desk:
		return
	if not desk.visible:
		_step_down()
		return
	if _gliding():
		desk.pointer = Vector2(-1, -1)
		return
	var cam: Camera3D = host._interior_camera
	var vp: Viewport = host.get_viewport()
	# The pointer is the look's stick, with a wide dead middle (the work fills the picture;
	# a held button, writing or carrying, widens it further); W A S D turn the head as well.
	look.dead = DESK_DEAD
	var offset: Vector3 = look.update(delta, INTERIOR_LOOK.cursor_of(vp) if debug_pointer.x < 0.0 else Vector2(-1, -1), INTERIOR_LOOK.turn_axis())
	# The label maker works on the keys' labels: the drawer comes out for it.
	if desk.labels_mode():
		_set_drawer(true)
	var k := _drawer_k()
	cam.position = DESK_EYE.lerp(DRAWER_EYE, k)
	cam.rotation = _desk_rot.lerp(_drawer_rot, k) + offset
	_point()


func _set_drawer(open: bool) -> void:
	if open == _drawer_open or _drawer == null:
		return
	_drawer_open = open
	_play(SFX_DRAWER, -8.0 if open else -11.0)


## How far out it is as it goes: in and out of it gently, nothing at the end of it.
func _drawer_k() -> float:
	var t := _drawer_t
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


func _tick_drawer(delta: float) -> void:
	var want := 1.0 if _drawer_open else 0.0
	if _drawer == null or _drawer_t == want:
		return
	_drawer_t = move_toward(_drawer_t, want, delta / DRAWER_SEC)
	_drawer.position.z = lerpf(DRAWER_SHUT_Z, DRAWER_OPEN_Z, _drawer_k())
	_board.visible = _drawer_t > 0.0
	if _drawer_t >= 1.0:
		desk.rattle_keys()


func _tick_dymo(delta: float) -> void:
	var want := SHEET_Y + (DYMO_LIFT if _at_desk and desk.labels_mode() else 0.0)
	if _dymo.position.y != want:
		_dymo.position.y = move_toward(_dymo.position.y, want, delta * 0.3)


## The stamp in hand goes with the pointer, over the counter; pressed, it comes down on the
## paper and up again; put down (or used), back to its place, in an arc.
func _tick_stamps(delta: float) -> void:
	var held: String = desk.holding_stamp() if _at_desk else ""
	for kind in _stamps:
		var s: Dictionary = _stamps[kind]
		var root: Node3D = s["root"]
		var press := float(s["press"])
		if press >= 0.0:
			press += delta
			s["press"] = press if press < STAMP_PRESS_SEC else -1.0
			var k := clampf(press / STAMP_PRESS_SEC, 0.0, 1.0)
			# Down fast, a moment on the paper, up.
			var up := 0.0
			if k < 0.2:
				up = 1.0 - k / 0.2
			elif k > 0.5:
				up = (k - 0.5) / 0.5
			root.position.y = SHEET_Y + STAMP_LIFT * up
			continue
		if kind == held:
			if desk.pointer.x >= 0.0 and not desk.pointer_on_board:
				root.position = root.position.lerp(_counter_at(desk.pointer) + Vector3(0.0, STAMP_LIFT, 0.0), 1.0 - exp(-40.0 * delta))
			continue
		var home: Vector3 = s["home"]
		if root.position == home:
			continue
		var off := Vector2(root.position.x - home.x, root.position.z - home.z) * exp(-13.0 * delta)
		if off.length() < 0.003:
			root.position = home
		else:
			root.position = Vector3(home.x + off.x, home.y + STAMP_LIFT * clampf(off.length() / 0.1, 0.0, 1.0), home.z + off.y)


## A point of the counter's picture, in the room.
func _counter_at(px: Vector2) -> Vector3:
	return Vector3(SHEET_X0 + px.x / 480.0 * SHEET_W, SHEET_Y, SHEET_Z0 + clampf((px.y - SHEET_PX_Y.x) / SHEET_PX_Y.y, 0.0, 1.0) * SHEET_D)


func _stamp_under(o: Vector3, d: Vector3) -> String:
	for kind in _stamps:
		var c: Vector3 = _stamps[kind]["home"]
		if AABB(c + Vector3(-0.07, 0.0, -0.05), Vector3(0.14, 0.14, 0.1)).intersects_ray(o, d) != null:
			return str(kind)
	return ""


## The drawer's front (the pull and the board it is on), where it is now.
func _front_under(o: Vector3, d: Vector3) -> bool:
	if _drawer == null:
		return false
	var w := DRAWER_PIC.x + 0.06
	return AABB(Vector3(DRAWER_X - w * 0.5, 0.79, _drawer.position.z - 0.02), Vector3(w, 0.12, 0.08)).intersects_ray(o, d) != null


## The pointer through the room's eye onto the counter's picture or the keys in the drawer.
func _point() -> void:
	var cam: Camera3D = host._interior_camera
	var vpm: Vector2 = host._to_interior_viewport_pos(host.get_viewport().get_mouse_position())
	if debug_pointer.x >= 0.0:
		vpm = debug_pointer
	var o: Vector3 = room_root.to_local(cam.project_ray_origin(vpm))
	var d: Vector3 = room_root.global_basis.inverse() * cam.project_ray_normal(vpm)
	var px := Vector2(-1, -1)
	var in_drawer := false
	if absf(d.y) > 0.0001:
		if _drawer_t >= 1.0:
			var dp := o + d * ((DRAWER_FELT_Y - o.y) / d.y)
			var near := DRAWER_OPEN_Z - 0.02
			var u2 := (dp.x - (DRAWER_X - DRAWER_PIC.x * 0.5)) / DRAWER_PIC.x
			var v2 := (dp.z - (near - DRAWER_PIC.y)) / DRAWER_PIC.y
			if d.y < 0.0 and u2 >= 0.0 and u2 <= 1.0 and v2 >= 0.0 and v2 <= 1.0:
				px = Vector2(BOARD_PX.position.x + u2 * BOARD_PX.size.x, BOARD_PX.position.y + v2 * BOARD_PX.size.y - desk.RACK_3D.y)
				in_drawer = true
		var t := (SHEET_Y - o.y) / d.y
		if not in_drawer and t > 0.0:
			var p := o + d * t
			var u := (p.x - SHEET_X0) / SHEET_W
			var v := (p.z - SHEET_Z0) / SHEET_D
			# Past the far edge, over to the guest: where the papers go back. (Past the near one,
			# something in hand on its way from the drawer: the strip of the counter's edge.)
			var near_v := 1.3 if desk.carrying() and _drawer_t >= 1.0 else 1.0
			if u >= 0.0 and u <= 1.0 and v >= -0.25 and v <= near_v:
				px = Vector2(u * 480.0, SHEET_PX_Y.x + clampf(v, 0.0, 1.0) * SHEET_PX_Y.y)
	px = _carry_over(o, d, px, in_drawer)
	desk.pointer = px
	desk.pointer_on_board = in_drawer
	desk.stamp_3d_hover = _stamp_under(o, d) if desk.holding_nothing() else ""
	_front_hot = desk.holding_nothing() and _front_under(o, d)
	if _front_hot:
		HandCursor.want(HandCursor.POINT)
		_glint.show_on(_drawer_pull)
	elif desk.stamp_3d_hover != "":
		_glint.show_on([_stamps[desk.stamp_3d_hover]["root"]])
	elif desk.holding_nothing() and DESK.DYMO.has_point(px):
		_glint.show_on([_dymo])
	else:
		_glint.clear()
	# The PC across the room takes a click (input).
	if px.x < 0.0 and desk.holding_nothing() and host.crt_under(host.get_viewport().get_mouse_position()) >= 0:
		HandCursor.want(HandCursor.POINT)


## A paper or a key in hand, the pointer past the counter's far edge: it comes up off the
## counter and goes over to whoever stands there, in the air under the pointer (the user
## 4. 11.: they stayed stuck to the table, and whether you were giving them anything was
## anybody's guess). The picture draws it in rows the counter does not show; a quad in
## the room shows those rows. Let go there, it is theirs (the picture's own giving: it is
## above GIVE).
func _carry_over(o: Vector3, d: Vector3, px: Vector2, in_drawer: bool) -> Vector2:
	var over := false
	var at := Vector3.ZERO
	if desk.carrying() and not in_drawer and absf(d.z) > 0.0001:
		var past := d.y >= -0.001
		if not past:
			var p := o + d * ((SHEET_Y - o.y) / d.y)
			past = (p.z - SHEET_Z0) / SHEET_D < AIR_V
		var t := (AIR_Z - o.z) / d.z
		if past and t > 0.0:
			at = o + d * t
			at.y = clampf(at.y, 1.02, 1.8)
			over = true
			px = Vector2(clampf((at.x - SHEET_X0) / SHEET_W, 0.04, 0.96) * 480.0, AIR_PX_Y)
	desk.in_air = over
	if over:
		_show_air(at)
	elif _air != null:
		_air.visible = false
	return px


func _show_air(at: Vector3) -> void:
	if _air == null:
		_air = MeshInstance3D.new()
		_air.name = "DeskInHand"
		_air.mesh = QuadMesh.new()
		var m := _sheet_mat(desk.picture(), Vector2.ZERO, Vector2.ONE)
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.no_depth_test = true
		_air.material_override = m
		_air.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_air.set_meta("retro_text", true)
		room_root.add_child(_air)
	var r: Rect2 = desk.held_rect()
	if r.size.x <= 0.0:
		_air.visible = false
		return
	var size := Vector2(float(desk.W), float(desk.H_3D))
	var mat := _air.material_override as StandardMaterial3D
	mat.uv1_offset = Vector3(r.position.x / size.x, r.position.y / size.y, 0.0)
	mat.uv1_scale = Vector3(r.size.x / size.x, r.size.y / size.y, 1.0)
	(_air.mesh as QuadMesh).size = r.size * AIR_M_PER_PX
	_air.position = at
	_air.visible = true


## Let go over there: the thing crosses the last of the way to the guest as you let go of it,
## and they take it (a picture of it: the desk has done with it by now).
func _hand_over() -> void:
	if _air == null or not _air.visible:
		return
	var r: Rect2 = desk.held_rect()
	var img: Image = desk.picture().get_image()
	if img == null or r.size.x <= 0.0:
		return
	var rect := Rect2i(r).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var s := Sprite3D.new()
	s.texture = ImageTexture.create_from_image(img.get_region(rect))
	s.pixel_size = AIR_M_PER_PX
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = false
	s.no_depth_test = true
	s.position = _air.position
	room_root.add_child(s)
	var hand := COUNTER_SPOT + Vector3(0.0, 1.12, 0.1)
	var tw: Tween = host.create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(s, "position", hand, GIVE_SEC)
	tw.tween_property(s, "scale", Vector3.ONE * 0.55, GIVE_SEC)
	tw.chain().tween_callback(s.queue_free)
	if _front != null and _front.visible:
		var off0 := _front.offset
		var nod: Tween = host.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		nod.tween_interval(GIVE_SEC * 0.7)
		nod.tween_property(_front, "offset", off0 + Vector2(0.0, -3.0), 0.09)
		nod.tween_property(_front, "offset", off0, 0.14)


## The room's input while you are at the counter (building_interior._input).
func input(event: InputEvent) -> void:
	host.get_viewport().set_input_as_handled()
	if not _at_desk or _gliding():
		return
	if event.is_action_pressed("ui_cancel") or INTERIOR_LOOK.is_space(event):
		desk.close_desk()
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN) and mb.pressed:
		if desk.pointer_on_board:
			desk.wheel(1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
		return
	if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		if not desk.put_down():
			_back_out()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		# The drawer's front, nothing in hand: out, or in.
		if _front_hot:
			_set_drawer(not _drawer_open)
			return
		# The band at the bottom of the screen, nothing in hand: up from the counter.
		if desk.holding_nothing() and INTERIOR_LOOK.in_exit_zone(host.get_viewport()):
			_back_out()
			return
		# Turned to the PC, its screen clicked: over to it (the user 4. 11.).
		if desk.holding_nothing() and desk.pointer.x < 0.0:
			var screen: int = host.crt_under(mb.position)
			if screen >= 0:
				_to_pc = screen
				desk.close_desk()
				return
		var was_held: String = desk.holding_stamp()
		desk.press_at()
		if was_held != "" and desk.holding_stamp() == "":
			_stamps[was_held]["press"] = 0.0
	else:
		_hand_over()
		desk.release_at()
		desk.in_air = false
		if _air != null:
			_air.visible = false


## One step back from the work: the drawer shut first, then up from the counter.
func _back_out() -> void:
	if _drawer_open:
		_set_drawer(false)
	else:
		desk.close_desk()


func _make_sheets() -> void:
	if _sheet != null and is_instance_valid(_sheet):
		return
	var tex: Texture2D = desk.picture()
	var plane := PlaneMesh.new()
	plane.size = Vector2(SHEET_W, SHEET_D)
	_sheet = MeshInstance3D.new()
	_sheet.name = "DeskSheet"
	_sheet.mesh = plane
	_sheet.material_override = _sheet_mat(tex, Vector2(0.0, SHEET_PX_Y.x / float(desk.H_3D)), Vector2(1.0, SHEET_PX_Y.y / float(desk.H_3D)))
	_sheet.position = Vector3(SHEET_X0 + SHEET_W * 0.5, SHEET_Y, SHEET_Z0 + SHEET_D * 0.5)
	_sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sheet.set_meta("retro_text", true)
	room_root.add_child(_sheet)
	_build_drawer(tex)


## A surface that goes with what moves (K.surface is mapped to the world: it would slide over
## a drawer as it comes out).
func _on_it(tex: String, metres: float, tint := Color.WHITE) -> StandardMaterial3D:
	var m := K.surface(tex, metres, tint).duplicate() as StandardMaterial3D
	m.uv1_world_triplanar = false
	return m


## The drawer: boards, a pull, and in it the desk's key board lying on its back, the top of its
## picture to the far side.
func _build_drawer(tex: Texture2D) -> void:
	_drawer = Node3D.new()
	_drawer.name = "KeyDrawer"
	_drawer.position = Vector3(DRAWER_X, 0.0, DRAWER_SHUT_Z)
	room_root.add_child(_drawer)
	var wood := _on_it("veneer_dark", 0.3)
	var w := DRAWER_PIC.x
	var deep_z := -DRAWER_DEEP * 0.5
	K.slab(_drawer, Vector3(w + 0.05, 0.092, 0.022), Vector3(0.0, 0.853, 0.0), _on_it("veneer_dark", 0.3, Color(1.25, 1.2, 1.15)), "KeyDrawerFront")
	K.slab(_drawer, Vector3(w + 0.04, 0.012, DRAWER_DEEP), Vector3(0.0, 0.815, deep_z), wood, "KeyDrawerFloor")
	K.slab(_drawer, Vector3(0.02, 0.066, DRAWER_DEEP), Vector3(-(w * 0.5 + 0.01), 0.848, deep_z), wood, "KeyDrawerLeft")
	K.slab(_drawer, Vector3(0.02, 0.066, DRAWER_DEEP), Vector3(w * 0.5 + 0.01, 0.848, deep_z), wood, "KeyDrawerRight")
	K.slab(_drawer, Vector3(w + 0.04, 0.066, 0.02), Vector3(0.0, 0.848, -DRAWER_DEEP + 0.01), wood, "KeyDrawerBack")
	# The pull: a bar on two posts, the brass of the keys.
	var brass := _on_it("galvanized", 0.08, Color(1.45, 1.08, 0.5))
	var bar := K.slab(_drawer, Vector3(0.15, 0.018, 0.016), Vector3(0.0, 0.858, 0.044), brass, "KeyDrawerPull")
	var post_a := K.slab(_drawer, Vector3(0.016, 0.014, 0.036), Vector3(-0.06, 0.858, 0.026), brass, "KeyDrawerPost")
	var post_b := K.slab(_drawer, Vector3(0.016, 0.014, 0.036), Vector3(0.06, 0.858, 0.026), brass, "KeyDrawerPost")
	_drawer_pull = [bar, post_a, post_b]
	var pm := PlaneMesh.new()
	pm.size = DRAWER_PIC
	_board = MeshInstance3D.new()
	_board.name = "DeskKeyBoard"
	_board.mesh = pm
	_board.material_override = _sheet_mat(tex, Vector2(BOARD_PX.position.x / float(desk.W), BOARD_PX.position.y / float(desk.H_3D)), Vector2(BOARD_PX.size.x / float(desk.W), BOARD_PX.size.y / float(desk.H_3D)))
	_board.position = Vector3(0.0, DRAWER_FELT_Y, -0.02 - DRAWER_PIC.y * 0.5)
	_board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_board.set_meta("retro_text", true)
	_board.visible = false
	_drawer.add_child(_board)


## The two stamps standing on the counter, where the picture had them: rubber, a wooden mount,
## a neck and a knob in the colour of its ink. (Their Dymo tapes lie in front of them on the
## counter's picture: on the mount the words were too small to read.)
func _build_stamps() -> void:
	for kind in DESK.STAMP_HOME.keys():
		var home_px: Vector2 = DESK.STAMP_HOME[kind] + DESK.STAMP_SIZE * 0.5
		var root := Node3D.new()
		root.name = "Stamp_" + str(kind)
		root.position = _counter_at(home_px)
		room_root.add_child(root)
		var ink: Color = STAMP_INK[kind]
		var wood := _on_it("knotty_pine", 0.16, Color(0.8, 0.68, 0.56))
		var dark := _on_it("veneer_dark", 0.12, Color(1.3, 1.2, 1.1))
		K.slab(root, Vector3(0.1, 0.01, 0.056), Vector3(0.0, 0.005, 0.0), _on_it("plastic", 0.2, ink * 0.45), "StampRubber")
		K.slab(root, Vector3(0.112, 0.03, 0.064), Vector3(0.0, 0.025, 0.0), wood, "StampMount")
		_turned(root, 0.013, 0.013, 0.05, 0.065, dark, "StampNeck")
		_turned(root, 0.02, 0.027, 0.034, 0.107, dark, "StampKnob")
		_turned(root, 0.012, 0.02, 0.012, 0.13, _on_it("plastic", 0.2, ink * 1.25), "StampCap")
		_stamps[kind] = {"root": root, "home": root.position, "press": -1.0}


## The label maker, where the picture had it: its shell, the wheel of letters on top, the grip
## to your hand and a bit of red tape out of its nose.
func _build_dymo() -> void:
	_dymo = Node3D.new()
	_dymo.name = "DeskDymo"
	_dymo.position = _counter_at(DESK.DYMO.get_center())
	room_root.add_child(_dymo)
	var shell := _on_it("plastic", 0.2, Color(0.46, 0.47, 0.5))
	K.slab(_dymo, Vector3(0.12, 0.04, 0.08), Vector3(0.0, 0.02, 0.0), shell, "DymoBody")
	K.slab(_dymo, Vector3(0.036, 0.034, 0.07), Vector3(-0.012, 0.017, 0.07), shell, "DymoGrip")
	_turned(_dymo, 0.034, 0.036, 0.016, 0.048, _on_it("plastic", 0.2, Color(0.2, 0.2, 0.23)), "DymoWheel")
	K.slab(_dymo, Vector3(0.03, 0.004, 0.014), Vector3(0.072, 0.03, 0.0), _on_it("plastic", 0.2, Color(0.85, 0.16, 0.12)), "DymoTape")


## A turned piece of a stamp: eight-sided, standing `at` up the stamp's middle.
func _turned(root: Node3D, top: float, bottom: float, tall: float, at: float, mat: Material, n: String) -> void:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = tall
	c.radial_segments = 8
	c.rings = 1
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = c
	mi.material_override = mat
	mi.position.y = at
	root.add_child(mi)


func _sheet_mat(tex: Texture2D, offset: Vector2, scale: Vector2) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.uv1_offset = Vector3(offset.x, offset.y, 0.0)
	m.uv1_scale = Vector3(scale.x, scale.y, 1.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	return m


## What the guest says, under the room for a while (their bubble, played in the room).
func _say(text: String) -> void:
	if _say_layer == null:
		_say_layer = CanvasLayer.new()
		_say_layer.layer = 130
		host.add_child(_say_layer)
		_say_label = RETRO_UI.label("", RETRO_UI.FONT_TEXT, RETRO_UI.SIZE_LABEL, RETRO_UI.C_BONE, maxi(1, RETRO_UI.ui_scale(host.get_viewport().get_visible_rect().size.y)))
		_say_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_say_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_say_layer.add_child(_say_label)
	var size: Vector2 = host.get_viewport().get_visible_rect().size
	_say_label.size = Vector2(size.x * 0.7, 0.0)
	_say_label.position = Vector2(size.x * 0.15, size.y * 0.80)
	_say_label.text = text
	_say_label.visible = text != "" and _at_desk
	_say_t = 3.0 + float(text.length()) * 0.06


func _front_info() -> Dictionary:
	# Whoever you are serving stays at the counter: someone coming in with an earlier place
	# in the line took their sprite (the user 4. 11.).
	if is_open():
		var serving: int = desk.current_guest_id()
		for q in _queue:
			if int((q as Dictionary).get("id", -1)) == serving:
				return q
	if not _queue.is_empty():
		return _queue[0]
	return _stranger


func _next_for_desk() -> Dictionary:
	_queue = GuestManager.get_desk_queue() if GuestManager != null else []
	_place_people()
	return _front_info()


## Seen from the camp, through the panes (the room stands in the building, nobody in it on this
## machine: process() is not running): who is at the counter, whoever is seeing to them (the
## user 7. 11.: "from outside I don't see the guests at the reception the other player is
## checking in"). Only shown: no door, no bell, nobody's turn moves on. Their figure outside
## walks in and is hidden: till then it is that one you see, not two of them.
func tick_unseen(delta: float, serving := -999) -> void:
	_unseen_t -= delta
	if _unseen_t > 0.0:
		return
	_unseen_t = POLL_SEC
	var q: Array = GuestManager.get_desk_queue() if GuestManager != null else []
	var inside: Array = []
	var scene: Node = host.get_tree().current_scene if host != null and host.is_inside_tree() else null
	var agents = scene.get("_guest_agents") if scene != null else null
	for row in q:
		var id := int((row as Dictionary).get("id", -1))
		if agents == null or not agents.has_method("guest_world_position") or not is_finite(agents.guest_world_position(id).x):
			if id == serving:
				inside.push_front(row)
			else:
				inside.append(row)
	_show(_front, inside[0] if inside.size() > 0 else {}, COUNTER_SPOT)
	_show(_second, inside[1] if inside.size() > 1 else {}, BENCH_SPOT)
	_place_hand()
	_turn_hand(POLL_SEC)


## The hand at work behind the counter now ("" nobody), from the books (the same on every
## machine).
func desk_hand() -> String:
	var state = CoreRoot.get_state() if CoreRoot != null else null
	var st = (state.biz as Dictionary).get("staff", {}) if state != null and state.biz is Dictionary else {}
	if not (st is Dictionary):
		return ""
	var acts: Dictionary = (st as Dictionary).get("act", {}) if (st as Dictionary).get("act", {}) is Dictionary else {}
	for slug in acts:
		var a: Dictionary = acts[slug]
		if str(a.get("do", "")) == "work" and str(a.get("what", "")) == "desk":
			return str(slug)
	return ""


var _hand: Sprite3D
var _hand_slug := ""
var _hand_view := 0.0


func _place_hand() -> void:
	var slug := desk_hand()
	if slug != _hand_slug:
		_hand_slug = slug
		if _hand != null and is_instance_valid(_hand):
			_hand.queue_free()
		_hand = null
	if slug == "":
		return
	if _hand == null:
		_hand = _make_person("DeskHand")
		_hand.pixel_size = HAND_M / 128.0
		var set := DOOM_HAND.set_of(slug)
		if set.is_empty():
			var t := _tex("res://assets/textury/npc/staff/%s.png" % slug)
			_hand.texture = t
			if t != null:
				_hand.offset = Vector2(0.0, t.get_height() * 0.5)
		else:
			DOOM_HAND.new(_hand, set, HAND_M * float(set.get("h", 128)) / 128.0)
		_hand.visible = true
	var at := HAND_ASIDE if _at_desk else HAND_SPOT
	_hand.position = at
	if _hand.has_meta("doom"):
		var d: DOOM_HAND = _hand.get_meta("doom")
		d.set_anim("stand")
		d.face(room_root.global_basis * (COUNTER_SPOT - at) if room_root.is_inside_tree() else COUNTER_SPOT - at)


## Their picture for where you look from, twelve times a second.
func _turn_hand(delta: float) -> void:
	_hand_view -= delta
	if _hand_view > 0.0 or _hand == null or not is_instance_valid(_hand) or not _hand.has_meta("doom"):
		return
	_hand_view = 1.0 / 12.0
	var cam := _hand.get_viewport().get_camera_3d() if _hand.is_inside_tree() else null
	if cam != null:
		(_hand.get_meta("doom") as DOOM_HAND).show(cam.global_position)


func _place_people() -> void:
	var front := _front_info()
	var id := int(front.get("id", -999)) if not front.is_empty() else -999
	if id != _front_id:
		var was := _front_id
		_front_id = id
		if id != -999:
			if id == STRANGER_ID:
				# He did not come in by the door.
				_ring_soft()
			else:
				_open_door()
				host.get_tree().create_timer(1.8).timeout.connect(func():
					if _front_id == id and not is_open() and desk_hand() == "":
						_ring()
				)
		elif was != -999:
			pass
	_show(_front, front, COUNTER_SPOT)
	var second: Dictionary = {}
	for q in _queue:
		if int((q as Dictionary).get("id", -1)) != id:
			second = q
			break
	_show(_second, second, BENCH_SPOT)
	# Nobody at the counter: the empty spot takes no clicks (it stood in front of the door).
	var hb = extras.hot.get("guest", {}).get("body", null) if extras != null else null
	if hb is CollisionObject3D:
		(hb as CollisionObject3D).collision_layer = 1 if not front.is_empty() else 0
	# A desk that is open follows the queue: whoever is at the counter now.
	if is_open() and desk.current_guest_id() == -999 and not front.is_empty():
		desk.open_desk(front, CoreRoot.get_day() if CoreRoot != null else 1)


func _show(sprite: Sprite3D, info: Dictionary, at: Vector3) -> void:
	if info.is_empty():
		sprite.visible = false
		return
	var path := str(info.get("sprite_path", ""))
	var tex := _tex(path)
	if tex == null:
		sprite.visible = false
		return
	sprite.texture = tex
	sprite.pixel_size = 1.70 / float(tex.get_height())
	sprite.offset = Vector2(0.0, tex.get_height() * 0.5)
	sprite.position = at
	sprite.modulate = Color(0.12, 0.11, 0.12) if bool(info.get("stranger", false)) else Color.WHITE
	sprite.visible = true


func _tex(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path)
	return _tex_cache[path]


func _tick_stranger(step: float, in_office: bool) -> void:
	if not _stranger.is_empty():
		return
	var day: int = CoreRoot.get_day() if CoreRoot != null else 1
	var hour := _hour()
	var late := hour >= 22.5 or hour < 3.5
	var night := day if hour >= 12.0 else day - 1
	if not in_office or not late or day < 2 or not _queue.is_empty() or night == _stranger_night or is_open():
		_stranger_wait = -1.0
		return
	if _stranger_wait < 0.0:
		_stranger_wait = randf_range(25.0, 80.0)
		# Not every night.
		if randf() > 0.45:
			_stranger_night = night
			_stranger_wait = -1.0
			return
	_stranger_wait -= step
	if _stranger_wait > 0.0:
		return
	_stranger_night = night
	_stranger_wait = -1.0
	_stranger = _make_stranger()


## Not booked. His card has the last name in the register on it, a black photo, and it
## ran out the summer the man sat in cabin 3 (the Courier, 1984).
func _make_stranger() -> Dictionary:
	var surname := "NOVAK"
	var first := "JOSEF"
	var hist: Array = desk.history() if desk != null else []
	if not hist.is_empty():
		var last: Dictionary = hist.back()
		surname = str(last.get("surname", surname))
		first = str(last.get("first", first))
	return {
		"id": STRANGER_ID,
		"stranger": true,
		"name": "",
		"party_size": 1,
		"stay_nights": 1,
		"rooms": [],
		"sprite_path": STRANGER_SPRITE,
		"card": {"surname": surname, "first": first, "born": "21.7.1984", "number": "AA 000003", "town": "CERNE JEZERO", "valid": "21.7.1984"},
	}


func _hour() -> float:
	var main = host.get_tree().current_scene if host != null and host.get_tree() != null else null
	if main != null and main.get("_time_of_day_hours") != null:
		return float(main.get("_time_of_day_hours"))
	return 12.0


# ── the things ───────────────────────────────────────────────────────────────

func _make_person(n: String) -> Sprite3D:
	var s := Sprite3D.new()
	s.name = n
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = true
	s.double_sided = true
	s.visible = false
	room_root.add_child(s)
	return s


func _build_bell() -> void:
	_bell = MeshInstance3D.new()
	_bell.name = "DeskBell"
	var q := QuadMesh.new()
	q.size = Vector2(0.22, 0.18)
	_bell.mesh = q
	var m := StandardMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	if ResourceLoader.exists(BELL_TEX):
		m.albedo_texture = load(BELL_TEX)
	else:
		m.albedo_color = Color(0.7, 0.7, 0.72)
	_bell.material_override = m
	_bell.position = BELL_POS + Vector3(0, 0.08, 0)
	room_root.add_child(_bell)


## The front door, in the window wall to the right of the window: boards, a small pane,
## the camp beyond it when it swings open.
func _build_door() -> void:
	_door_pivot = Node3D.new()
	_door_pivot.name = "FrontDoorPivot"
	_door_pivot.position = DOOR_HINGE
	room_root.add_child(_door_pivot)
	var leaf := K.slab(_door_pivot, Vector3(DOOR_W, 2.05, 0.05), Vector3(-DOOR_W * 0.5, 1.025, 0.0), K.surface("planks_dark", 0.8), "FrontDoorLeaf")
	# The painted door once on each face, fixed to the leaf (a world-mapped one tiled it,
	# two handles and two plates, and slid over the boards as it swung). Its handle is
	# painted on the right: inside the hinge is on the right, so that face is mirrored.
	var face_in := K.picture(_door_pivot, "door_wood", Vector2(DOOR_W, 2.05), Vector3(-DOOR_W * 0.5, 1.025, 0.026), 0.0, "FrontDoorFaceIn")
	(face_in.material_override as StandardMaterial3D).uv1_scale = Vector3(-1.0, 1.0, 1.0)
	var face_out := K.picture(_door_pivot, "door_wood", Vector2(DOOR_W, 2.05), Vector3(-DOOR_W * 0.5, 1.025, -0.026), 180.0, "FrontDoorFaceOut")
	# Click it and you go out into the camp, the way you came in (reception_extras).
	_hot("front_door", DOOR_HINGE + Vector3(-DOOR_W * 0.5, 1.05, 0.05), Vector3(DOOR_W, 2.1, 0.2), [leaf, face_in, face_out])
	# In the camp's one world (building_interior, W26) the building's own leaf is the door
	# from outside, this one from inside: the camp's eye leaves it out.
	for m in [leaf, face_in, face_out]:
		if m is VisualInstance3D:
			(m as VisualInstance3D).layers = 1 << 17


func _hot(id: String, pos: Vector3, size: Vector3, meshes: Array) -> void:
	if extras != null and extras.has_method("_hot_body"):
		extras._hot_body(id, room_root, pos, size, meshes)


func _open_door() -> void:
	if _door_t < 0.0:
		_door_t = 0.0
		_play(SFX_DOOR, -8.0)


func _ring() -> void:
	_play(SFX_BELL, -4.0)


func _ring_soft() -> void:
	_play(SFX_BELL, -16.0)


func _play(path: String, db: float) -> void:
	if not ResourceLoader.exists(path) or _audio == null:
		return
	_audio.stream = load(path)
	_audio.volume_db = db
	_audio.play()
