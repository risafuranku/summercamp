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
## The check-in played on the counter itself (the user 30. 10.), checkin_desk.gd's picture
## laid on it: its counter part (y 104..270 of the 384) over the counter's top left of the
## phone, the far edge where the guest stands; its key board (x 284..478, y 280..384) on
## the right wall over the old picture of the board. Your eye over the counter; look up at
## the guest, turn right to the keys (the edges of the screen, the arrows).
const INTERIOR_LOOK = preload("res://scripts/interior_look.gd")
const RETRO_UI = preload("res://scripts/ui/retro_ui.gd")
const DESK_EYE := Vector3(0.1, 1.42, 0.46)
const DESK_LOOK_AT := Vector3(0.12, 0.965, -0.02)
## Turned right to the keys you lean over to them: the eye goes up to the board.
const BOARD_EYE := Vector3(1.86, 1.5, 0.435)
const SHEET_X0 := -0.52
const SHEET_W := 1.45
const SHEET_Z0 := -0.17
const SHEET_D := 0.5015
const SHEET_Y := 0.965
const SHEET_PX_Y := Vector2(104.0, 166.0)
const BOARD_AT := Vector3(2.462, 1.52, 0.435)
const BOARD_SIZE := Vector2(0.72, 0.386)
const BOARD_PX := Rect2(284, 280, 194, 104)
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
	_poll -= delta
	if _poll <= 0.0:
		_poll = POLL_SEC
		_queue = GuestManager.get_desk_queue() if GuestManager != null else []
		_tick_stranger(POLL_SEC, in_office)
		_place_people()
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
	if not is_open() and _front_id != -999 and in_office:
		_ring_t += delta
		if _ring_t >= RING_AGAIN_SEC:
			_ring_t = 0.0
			_ring()


# ── at the counter (3D) ──────────────────────────────────────────────────────

func _step_up() -> void:
	_make_sheets()
	_sheet.visible = true
	_board.visible = true
	var pic := room_root.get_node_or_null("KeyRack") as Node3D
	if pic != null:
		pic.visible = false
	# The office's own notebook lies where the register is laid.
	var book := room_root.get_node_or_null("ReceptionNotebook") as Node3D
	if book != null:
		book.visible = false
	var cam: Camera3D = host._interior_camera
	_cam_from = [cam.position, cam.rotation]
	_desk_rot = Transform3D(Basis(), DESK_EYE).looking_at(DESK_LOOK_AT, Vector3.UP).basis.get_euler()
	look.reset()
	_at_desk = true
	_glide(DESK_EYE, _desk_rot)


func _step_down() -> void:
	_at_desk = false
	desk.in_air = false
	if _air != null:
		_air.visible = false
	if _sheet != null:
		_sheet.visible = false
		_board.visible = false
	var pic := room_root.get_node_or_null("KeyRack") as Node3D
	if pic != null:
		pic.visible = true
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
	var k := clampf((-look.yaw_deg - 40.0) / 45.0, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	cam.position = DESK_EYE.lerp(BOARD_EYE, k)
	cam.rotation = _desk_rot + offset + Vector3(deg_to_rad(30.0) * k, 0.0, 0.0)
	_point()


## The pointer through the room's eye onto the counter's picture or the wall's board.
func _point() -> void:
	var cam: Camera3D = host._interior_camera
	var vpm: Vector2 = host._to_interior_viewport_pos(host.get_viewport().get_mouse_position())
	if debug_pointer.x >= 0.0:
		vpm = debug_pointer
	var o: Vector3 = room_root.to_local(cam.project_ray_origin(vpm))
	var d: Vector3 = room_root.global_basis.inverse() * cam.project_ray_normal(vpm)
	var best := INF
	var px := Vector2(-1, -1)
	var wall := false
	if absf(d.y) > 0.0001:
		var t := (SHEET_Y - o.y) / d.y
		if t > 0.0:
			var p := o + d * t
			var u := (p.x - SHEET_X0) / SHEET_W
			var v := (p.z - SHEET_Z0) / SHEET_D
			# Past the far edge, over to the guest: where the papers go back.
			if u >= 0.0 and u <= 1.0 and v >= -0.25 and v <= 1.0:
				best = t
				px = Vector2(u * 480.0, SHEET_PX_Y.x + clampf(v, 0.0, 1.0) * SHEET_PX_Y.y)
	if absf(d.x) > 0.0001:
		var t2 := (BOARD_AT.x - o.x) / d.x
		if t2 > 0.0 and t2 < best:
			var p2 := o + d * t2
			var u2 := (p2.z - (BOARD_AT.z - BOARD_SIZE.x * 0.5)) / BOARD_SIZE.x
			var v2 := ((BOARD_AT.y + BOARD_SIZE.y * 0.5) - p2.y) / BOARD_SIZE.y
			if u2 >= 0.0 and u2 <= 1.0 and v2 >= 0.0 and v2 <= 1.0:
				px = Vector2(BOARD_PX.position.x + u2 * BOARD_PX.size.x, BOARD_PX.position.y + v2 * BOARD_PX.size.y - desk.RACK_3D.y)
				wall = true
	px = _carry_over(o, d, px, wall)
	desk.pointer = px
	desk.pointer_on_wall = wall
	# The PC across the room takes a click (input).
	if px.x < 0.0 and desk.holding_nothing() and host.crt_under(host.get_viewport().get_mouse_position()) >= 0:
		HandCursor.want(HandCursor.POINT)


## A paper or a key in hand, the pointer past the counter's far edge: it comes up off the
## counter and goes over to whoever stands there, in the air under the pointer (the user
## 4. 11.: they stayed stuck to the table, and whether you were giving them anything was
## anybody's guess). The picture draws it in rows the counter does not show; a quad in
## the room shows those rows. Let go there, it is theirs (the picture's own giving: it is
## above GIVE).
func _carry_over(o: Vector3, d: Vector3, px: Vector2, wall: bool) -> Vector2:
	var over := false
	var at := Vector3.ZERO
	if desk.carrying() and not wall and absf(d.z) > 0.0001:
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
		if desk.pointer_on_wall:
			desk.wheel(1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
		return
	if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		if not desk.put_down():
			desk.close_desk()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		# The band at the bottom of the screen, nothing in hand: up from the counter.
		if desk.holding_nothing() and INTERIOR_LOOK.in_exit_zone(host.get_viewport()):
			desk.close_desk()
			return
		# Turned to the PC, its screen clicked: over to it (the user 4. 11.).
		if desk.holding_nothing() and desk.pointer.x < 0.0:
			var screen: int = host.crt_under(mb.position)
			if screen >= 0:
				_to_pc = screen
				desk.close_desk()
				return
		desk.press_at()
	else:
		_hand_over()
		desk.release_at()
		desk.in_air = false
		if _air != null:
			_air.visible = false


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
	var q := QuadMesh.new()
	q.size = BOARD_SIZE
	_board = MeshInstance3D.new()
	_board.name = "DeskKeyBoard"
	_board.mesh = q
	_board.material_override = _sheet_mat(tex, Vector2(BOARD_PX.position.x / float(desk.W), BOARD_PX.position.y / float(desk.H_3D)), Vector2(BOARD_PX.size.x / float(desk.W), BOARD_PX.size.y / float(desk.H_3D)))
	_board.position = BOARD_AT
	_board.rotation_degrees.y = -90.0
	_board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_board.set_meta("retro_text", true)
	room_root.add_child(_board)


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
					if _front_id == id and not is_open():
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
