extends Node

## The wholesaler's van and its driver (the user 1. 11.: "the delivery does not work, no
## man from the van came to the reception, only the folder showed; do it like the
## postman: he gets out of the van and goes to the reception"). The day's event
## (scripts/day_events.gd "delivery", its `started` game minute) is the clock: the van
## comes up the road and stands outside the barrier (VAN_IN game minutes), the driver
## walks the guests' way to the office door, and then waits across the counter, left of
## the guests' place, his folder on the desk (building_interior: the note signed with the
## mouse, scripts/closeup/delivery_closeup.gd). Signed for, taken by a hand at the van, or
## given up on: he walks back from wherever he was, the van turns in its own length and
## goes off down the road. Drawn on every machine from the event as each one has it, like
## the postman (scripts/reception/post_delivery.gd), whose way in and walk this shares.

const POST = preload("res://scripts/reception/post_delivery.gd")
const VAN_IN := 5.0
const VAN_TURN := 2.0
const VAN_OUT := 6.0
## The van's faces (tools/artgen/post_art.py wholesale_van: Grok's Avia of the co-op
## wholesaler).
const VAN_DIR := "res://assets/textury/post/"
const SPRITE := "res://assets/textury/npc/npc_jednota_driver.png"
## The van as its side picture has it (post/jvan_side.png, 224 x 126): the cab's share of
## the length at the front, its roof and its bumper's underside as shares of the height,
## the box's floor; the tyres (shares of the length from the middle, + forward) and their
## radius (of the height).
const CAB_FRAC := 0.33
const CAB_H := 0.88
const CAB_FLOOR := 0.14
const BOX_FLOOR := 0.22
const WHEELS_Z := [0.29, -0.245, -0.385]
const WHEEL_R := 0.12
## Across the counter, left of the guests' place (desk_room.COUNTER_SPOT; the postman
## stands right of it, post_delivery.DESK_SPOT).
const DESK_SPOT := Vector3(-0.22, 0.0, -0.6)

var host        # building_interior.gd
var _main: Node
var _poll := 0.0
## The open delivery as last seen: its id and the game minute it began.
var _ev_id := -1
var _started := 0.0
## Gone (signed, taken at the van, given up): from when, and how far up the way he was.
var _leave_t0 := -1.0
var _leave_from := 0.0
var _path: PackedVector3Array = PackedVector3Array()
var _path_len := 0.0
var _park := Vector3.INF
var _van: Node3D
var _man: Node3D
var _man_sprite: Sprite3D
var _desk_man: Sprite3D
var _anim_t := 0.0
var _said_desk := -1
var _audio: AudioStreamPlayer


func setup(host_node) -> void:
	host = host_node
	_audio = AudioStreamPlayer.new()
	_audio.volume_db = -6.0
	add_child(_audio)


func _resolve_main() -> Node:
	if _main == null or not is_instance_valid(_main):
		_main = get_tree().current_scene if get_tree() != null else null
	return _main


func _now() -> float:
	var m := _resolve_main()
	return float(m._now_abs_minutes_float()) if m != null and m.has_method("_now_abs_minutes_float") else 0.0


func _day_events() -> Node:
	var m := _resolve_main()
	var de = m.get("_day_events") if m != null else null
	return de as Node if de is Node and is_instance_valid(de) else null


## He stands across the counter with his folder (the note can be signed).
func at_desk() -> bool:
	return _ev_id >= 0 and _ensure_path() and _now() >= _arrives()


func _arrives() -> float:
	return _started + VAN_IN + _path_len / POST.WALK_M_PER_MIN


func _process(delta: float) -> void:
	if host == null:
		return
	_anim_t += delta
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.25
		_watch_event()
	_draw_world()
	_draw_desk()


## The open delivery, or its end: he turns back from where he is.
func _watch_event() -> void:
	var de := _day_events()
	var ev: Dictionary = de.delivery_event() if de != null and de.has_method("delivery_event") else {}
	if not ev.is_empty():
		if int(ev.get("id", -1)) != _ev_id:
			_ev_id = int(ev.get("id", -1))
			_started = float(ev.get("started", _now()))
			_leave_t0 = -1.0
			# Not the van coming for a camp loaded with it standing there already.
			if _now() - _started < VAN_IN:
				_sound_world(POST.SFX_ARRIVE, -2.0)
		if at_desk() and _said_desk != _ev_id:
			_said_desk = _ev_id
			if host.visible:
				_play(POST.SFX_BELL, -4.0)
			else:
				_say("The van's driver is waiting at the reception with the delivery note.")
		return
	if _ev_id >= 0:
		# Gone from the list: signed for, taken by a hand, or given up.
		_leave_t0 = _now()
		_leave_from = _walked(_now())
		_ev_id = -1


## How far up the way to the office he is (metres) at `now`.
func _walked(now: float) -> float:
	if not _ensure_path():
		return 0.0
	return clampf((now - _started - VAN_IN) * POST.WALK_M_PER_MIN, 0.0, _path_len)


# ── the way in ───────────────────────────────────────────────────────────────

## The van's place on the road outside the barrier (west of the postman's), his way from
## its door to the office door (the guests' way: guest_agents._walk_to_reception).
func _ensure_path() -> bool:
	if not _path.is_empty():
		return true
	var gate := get_tree().get_first_node_in_group("camp_gate") if get_tree() != null else null
	var m := _resolve_main()
	if gate == null or m == null or not m.has_method("get_reception_door_position"):
		return false
	var door: Vector3 = m.get_reception_door_position()
	if door == Vector3.INF:
		return false
	var road: Vector3 = gate.road_spot()
	_park = Vector3(float(gate.gap_center_x) - 3.6, 0.0, float(gate.fence_z) - 8.5)
	var pts := PackedVector3Array([_park + Vector3(1.3, 0.0, 1.6), road])
	if gate.has_method("way_in"):
		for p in gate.way_in():
			pts.append(p)
	pts.append(door)
	var gm = m.get("grid_manager")
	var y := float(gm.grid_to_world(Vector2i.ZERO).y) if gm != null else 0.0
	for i in pts.size():
		pts[i].y = y
	_park.y = y
	_path = pts
	_path_len = 0.0
	for i in range(1, _path.size()):
		_path_len += _path[i - 1].distance_to(_path[i])
	return true


func _along(d: float) -> Vector3:
	d = clampf(d, 0.0, _path_len)
	for i in range(1, _path.size()):
		var seg := _path[i - 1].distance_to(_path[i])
		if d <= seg or i == _path.size() - 1:
			var t := 0.0 if seg < 0.001 else clampf(d / seg, 0.0, 1.0)
			return _path[i - 1].lerp(_path[i], t)
		d -= seg
	return _path[_path.size() - 1]


# ── in the camp: the van and the man ─────────────────────────────────────────

func _draw_world() -> void:
	var show_van := false
	var van_at := Vector3.ZERO
	var van_yaw := 0.0
	var man_at := Vector3.INF
	if _ensure_path():
		var now := _now()
		if _ev_id >= 0:
			var e := now - _started
			show_van = true
			# In from the south along the road, slowing to a stop.
			van_at = _park + Vector3(0.0, 0.0, -70.0 * pow(1.0 - clampf(e / VAN_IN, 0.0, 1.0), 2.0))
			if e >= VAN_IN and now < _arrives():
				man_at = _along(_walked(now))
		elif _leave_t0 >= 0.0:
			var t := now - _leave_t0
			var back := _leave_from / POST.WALK_M_PER_MIN
			if t < back:
				man_at = _along(_leave_from - t * POST.WALK_M_PER_MIN)
				show_van = true
				van_at = _park
			elif t < back + VAN_TURN + VAN_OUT:
				show_van = true
				var k := t - back
				# Round in its own length, in steps, then off down the road.
				var turn := clampf(k / VAN_TURN, 0.0, 1.0)
				van_yaw = floorf(turn * 6.0) / 6.0 * PI
				var go := clampf((k - VAN_TURN) / VAN_OUT, 0.0, 1.0)
				van_at = _park + Vector3(2.2 * turn, 0.0, -90.0 * go * go)
				if not _left_heard:
					_left_heard = true
					_sound_world(POST.SFX_LEAVE, -2.0)
			else:
				_leave_t0 = -1.0
	if show_van:
		_ensure_van()
		_van.visible = true
		_van.global_position = van_at
		_van.rotation.y = van_yaw
	elif _van != null:
		_van.visible = false
	if _ev_id >= 0 or _leave_t0 < 0.0:
		_left_heard = false
	if man_at != Vector3.INF:
		_ensure_man()
		_man.visible = true
		_man.global_position = man_at
		# A walker's bob, in steps.
		var f := floorf(_anim_t * 8.0)
		_man_sprite.position.y = absf(sin(f * 0.8)) * 0.05
		_man_sprite.rotation.z = sin(f * 0.8) * 0.03
	elif _man != null:
		_man.visible = false


var _left_heard := false


func _world() -> Node:
	var m := _resolve_main()
	var w = m.get("_world_3d") if m != null else null
	return w if w != null else m


func _ensure_man() -> void:
	if _man != null and is_instance_valid(_man):
		return
	_man = Node3D.new()
	_man.name = "VanDriver"
	_world().add_child(_man)
	_man_sprite = _person_sprite()
	_man.add_child(_man_sprite)


func _person_sprite() -> Sprite3D:
	var s := Sprite3D.new()
	var path := SPRITE if ResourceLoader.exists(SPRITE) else POST.SPRITE_FALLBACK
	var tex := load(path) as Texture2D
	s.texture = tex
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = true
	s.double_sided = true
	if tex != null:
		s.pixel_size = POST.SPRITE_HEIGHT_M / float(tex.get_height())
		s.offset = Vector2(0.0, tex.get_height() * 0.5)
	return s


## The co-op wholesaler's Avia (Grok faces on Build boxes, like the post's van,
## tools/artgen/post_art.py wholesale_van): the box body over the back, the lower cab in
## front of it, the sides (the side picture's left end is the front), the cab's front and
## the strip of the box above it, the back's roller shutter, the tyres where the side
## picture has them. Grok drew the front and the back squatter than the side: they are
## stretched to the side's heights.
func _ensure_van() -> void:
	if _van != null and is_instance_valid(_van):
		return
	_van = Node3D.new()
	_van.name = "WholesaleVan"
	_world().add_child(_van)
	var side := _tex("jvan_side.png")
	var length := 4.8
	var width := 2.1
	var h := length * float(side.get_height()) / float(side.get_width()) if side != null else 2.7
	var cab_len := length * CAB_FRAC
	var grey := Color(0.68, 0.69, 0.66)
	var white := Color(0.82, 0.8, 0.74)
	var chassis := Color(0.08, 0.075, 0.07)
	_box(_van, Vector3(0, h * 0.17, 0), Vector3(width - 0.08, h * 0.1, length - 0.1), chassis)
	_box(_van, Vector3(0, h * (BOX_FLOOR + 1.0) * 0.5, -cab_len * 0.5), Vector3(width - 0.04, h * (1.0 - BOX_FLOOR), length - cab_len - 0.04), grey)
	_box(_van, Vector3(0, h * (CAB_FLOOR + CAB_H) * 0.5, length * 0.5 - cab_len * 0.5), Vector3(width - 0.06, h * (CAB_H - CAB_FLOOR), cab_len - 0.06), white)
	for sd in [-1.0, 1.0]:
		_quad(_van, side, Vector2(length, h), Vector3(sd * width * 0.5, h * 0.5, 0.0), sd * PI * 0.5, sd < 0.0)
	_quad(_van, _tex("jvan_front.png"), Vector2(width, h * (CAB_H - CAB_FLOOR)), Vector3(0, h * (CAB_FLOOR + CAB_H) * 0.5, length * 0.5 + 0.01), 0.0, false)
	_quad(_van, _tex("jvan_front_box.png"), Vector2(width, h * (1.0 - CAB_H)), Vector3(0, h * (CAB_H + 1.0) * 0.5, length * 0.5 - cab_len + 0.01), 0.0, false)
	_quad(_van, _tex("jvan_back.png"), Vector2(width, h * (1.0 - CAB_FLOOR)), Vector3(0, h * (CAB_FLOOR + 1.0) * 0.5, -length * 0.5 - 0.01), PI, false)
	var r := h * WHEEL_R
	for x in [-(width * 0.5 - 0.14), width * 0.5 - 0.14]:
		for wz in WHEELS_Z:
			var w := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = r
			cyl.bottom_radius = r
			cyl.height = 0.24
			cyl.radial_segments = 10
			w.mesh = cyl
			var wm := StandardMaterial3D.new()
			wm.albedo_color = Color(0.07, 0.065, 0.06)
			w.material_override = wm
			w.rotation.z = PI * 0.5
			w.position = Vector3(x, r, length * float(wz))
			_van.add_child(w)


func _tex(file: String) -> Texture2D:
	var p := VAN_DIR + file
	return load(p) as Texture2D if ResourceLoader.exists(p) else null


func _box(parent: Node3D, pos: Vector3, size: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 1.0
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)


func _quad(parent: Node3D, tex: Texture2D, size: Vector2, pos: Vector3, yaw: float, mirror: bool) -> void:
	if tex == null:
		return
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if mirror:
		m.uv1_scale = Vector3(-1, 1, 1)
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = yaw
	parent.add_child(mi)


# ── in the office: across the counter ────────────────────────────────────────

func _draw_desk() -> void:
	var here := at_desk()
	if _desk_man == null:
		if not here:
			return
		var root: Node3D = host.get("_room_root")
		var extras = host.get("_extras")
		if root == null or extras == null:
			return
		_desk_man = _person_sprite()
		_desk_man.name = "DeskVanDriver"
		# The room's sprites are a little shorter than the camp's (desk_room._show).
		if _desk_man.texture != null:
			_desk_man.pixel_size = 1.72 / float(_desk_man.texture.get_height())
		_desk_man.position = DESK_SPOT
		root.add_child(_desk_man)
		extras._hot_body("van_driver", root, DESK_SPOT + Vector3(0, 0.9, 0), Vector3(0.6, 1.8, 0.5), [])
	_desk_man.visible = here
	var hb = host.get("_extras").hot.get("van_driver", {}).get("body", null)
	if hb is CollisionObject3D:
		(hb as CollisionObject3D).collision_layer = 1 if here else 0


# ── sounds and words ─────────────────────────────────────────────────────────

func _say(text: String, kind := 1) -> void:
	var m := _resolve_main()
	var hud = m.get("_hud_manager") if m != null else null
	if hud != null:
		hud.push_status(tr(text), kind)


func _play(path: String, db: float) -> void:
	if not ResourceLoader.exists(path) or _audio == null:
		return
	_audio.stream = load(path)
	_audio.volume_db = db
	_audio.play()


func _sound_world(path: String, db: float) -> void:
	if not ResourceLoader.exists(path) or not _ensure_path():
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = load(path)
	p.volume_db = db
	p.max_distance = 90.0
	p.unit_size = 6.0
	_world().add_child(p)
	p.global_position = _park + Vector3(0, 1.0, 0)
	p.play()
	p.finished.connect(p.queue_free)
