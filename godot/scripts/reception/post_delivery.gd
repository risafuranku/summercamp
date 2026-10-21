extends Node

## The second monitor's way to the office (the user 21. 10.: a lowkey page on the web
## that the curious find and the hasty do not, a second monitor to buy; a few hours later
## the post van, a period Czech one, and the postman; you sign his slip with the mouse,
## really drawn, he gives you the parcel, a click and it is gone, and the line on top
## says the reception's setup is better. Then D at the PC looks at the second monitor).
##
## The order is kept on the office PC (os_shell's store "post"), so it is saved with the
## camp and goes between the wardens with the PC ("pc", both ways): one order for the
## camp, whoever placed it. Its stages:
##   ordered    paid, `due` the game minute the van comes (office hours only)
##   arriving   the van pulls up on the road outside the barrier (VAN_IN game minutes),
##              the postman walks in by the way the guests come to the office door
##   at_desk    he waits across the counter (the postman sprite, the bell); clicked, the
##              slip (post_closeup.gd); at closing time he gives up for the day: "missed"
##   missed     he walks back out, drives off, comes again the next morning (ordered)
##   delivered  signed for: the second monitor is on the desk; he walks out, drives off
## Only the machine that runs the camp (Coop.sim_here) moves the stages on by the clock;
## the van and the man are drawn on every machine from the stage and the game minute it
## began (`t0`), so both see them in the same place without messages of their own.

const STORE_KEY := "post"
const PRICE := 149
## Ordered to the van at the gate, game minutes (a few hours, as the page says).
const DELAY_MIN := 150.0
const DELAY_RANGE := 90.0
## The post comes 8:30-17:30; ordered later, the next morning.
const HOURS_FROM := 8.5
const HOURS_TO := 17.5
## He waits across the counter till then, and no longer than this.
const GIVE_UP_HOUR := 19.0
const WAIT_MIN := 150.0
const VAN_IN := 5.0
const VAN_TURN := 2.0
const VAN_OUT := 6.0
## His walk: the guests' pace (1.35 m/s real) in game minutes.
const WALK_M_PER_MIN := 1.35 / 1.25
const SPRITE := "res://assets/textury/npc/npc_postman.png"
const SPRITE_FALLBACK := "res://assets/textury/npc/npc_electrician.png"
const SPRITE_HEIGHT_M := 1.74
const VAN_DIR := "res://assets/textury/post/"
const SFX_ARRIVE := "res://assets/sfx/post/van_arrive.mp3"
const SFX_LEAVE := "res://assets/sfx/post/van_leave.mp3"
const SFX_KNOCK := "res://assets/sfx/post/knock.mp3"
const SFX_BELL := "res://assets/sfx/desk/bell.mp3"
## Where he stands in the office: across the counter, right of the guests' place
## (desk_room.COUNTER_SPOT), by the bell.
const DESK_SPOT := Vector3(1.22, 0.0, -0.58)
const CLOSEUP = preload("res://scripts/closeup/post_closeup.gd")

var host        # building_interior.gd
var _main: Node
var _poll := 0.0
var _stage := ""
var _t0 := 0.0
## What this machine last saw (to tell a change: the van's sound, the line, the bell).
var _seen := ""
var _van: Node3D
var _man: Node3D
var _man_sprite: Sprite3D
var _desk_man: Sprite3D
var _path: PackedVector3Array = PackedVector3Array()
var _path_len := 0.0
var _park := Vector3.INF
var _anim_t := 0.0
var _closeup
var _audio: AudioStreamPlayer
## Signed here (not on the other warden's machine): this one gets the line on top.
var _signed_here := false


func setup(host_node) -> void:
	host = host_node
	_audio = AudioStreamPlayer.new()
	_audio.volume_db = -6.0
	add_child(_audio)


func _shell():
	return host.get("_crt_ui") if host != null else null


func state() -> Dictionary:
	var sh = _shell()
	var d = sh.stored(STORE_KEY, {}) if sh != null and sh.has_method("stored") else {}
	return d if d is Dictionary else {}


func _set_state(d: Dictionary) -> void:
	var sh = _shell()
	if sh != null and sh.has_method("store"):
		sh.store(STORE_KEY, d)
	_poll = 0.0


func stage() -> String:
	return str(state().get("stage", ""))


func has_monitor() -> bool:
	return stage() == "delivered"


## The web page's order (scripts/os98/apps/browser_app.gd "order://monitor2"): paid now
## from the camp's money. False when it cannot be (bought already, no money).
func order() -> bool:
	if stage() != "" or CoreRoot == null or CoreRoot.actions == null:
		return false
	if CoreRoot.get_money() < PRICE:
		return false
	CoreRoot.actions.add_money(-PRICE)
	var now := _now()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(now) * 7919 + 17
	_set_state({"stage": "ordered", "due": _office_hours(now + DELAY_MIN + rng.randf() * DELAY_RANGE), "t0": now, "no": 400 + int(now) % 500})
	return true


## The plate down the right edge of the screen (the user 21. 10.: "the postman shows as a
## notification with an icon on the right edge when you order the monitor";
## ui/arrival_strip.gd): {} when there is nothing coming. {stage, icon ("van" on the way,
## "parcel" waiting at the desk), left (0..1: on the way it fills as he comes nearer, at
## the desk his patience running down)}.
func hud_row() -> Dictionary:
	var d := state()
	var st := str(d.get("stage", ""))
	var now := _now()
	match st:
		"ordered":
			var t0 := float(d.get("t0", now))
			var due := float(d.get("due", now))
			# A later day's visit counts from that morning.
			var from := maxf(t0, floorf(due / 1440.0) * 1440.0 + HOURS_FROM * 60.0 - DELAY_MIN) if int(d.get("tries", 0)) > 0 else t0
			var k := clampf((now - from) / maxf(1.0, due - from), 0.0, 1.0)
			return {"stage": st, "icon": "van", "left": k}
		"arriving":
			return {"stage": st, "icon": "van", "left": 1.0}
		"at_desk":
			var waited := now - float(d.get("t0", now))
			var until := minf(WAIT_MIN, maxf(1.0, GIVE_UP_HOUR * 60.0 - fmod(float(d.get("t0", now)), 1440.0)))
			return {"stage": st, "icon": "parcel", "left": clampf(1.0 - waited / until, 0.0, 1.0)}
	return {}


## The order's number on the page and the slip.
func order_no() -> int:
	return int(state().get("no", 417))


# ── the clock ────────────────────────────────────────────────────────────────

func _resolve_main() -> Node:
	if _main == null or not is_instance_valid(_main):
		_main = get_tree().current_scene if get_tree() != null else null
	return _main


func _now() -> float:
	var m := _resolve_main()
	return float(m._now_abs_minutes_float()) if m != null and m.has_method("_now_abs_minutes_float") else 0.0


func _hour() -> float:
	var m := _resolve_main()
	return float(m.get("_time_of_day_hours")) if m != null and m.get("_time_of_day_hours") != null else 12.0


## `at` moved into the post's hours (the same day, or the next morning).
func _office_hours(at: float) -> float:
	var day := floorf(at / 1440.0) * 1440.0
	var h := (at - day) / 60.0
	if h < HOURS_FROM:
		return day + HOURS_FROM * 60.0 + fmod(at, 37.0)
	if h > HOURS_TO:
		return day + 1440.0 + HOURS_FROM * 60.0 + fmod(at, 53.0)
	return at


func _process(delta: float) -> void:
	if host == null:
		return
	_anim_t += delta
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.5
		var d := state()
		_stage = str(d.get("stage", ""))
		_t0 = float(d.get("t0", 0.0))
		if Coop.sim_here():
			_run_clock(d)
			d = state()
			_stage = str(d.get("stage", ""))
			_t0 = float(d.get("t0", 0.0))
		_noticed()
		host.set_second_monitor(_stage == "delivered")
	_draw_world()
	_draw_desk()


## The machine that runs the camp moves the order on.
func _run_clock(d: Dictionary) -> void:
	var now := _now()
	match str(d.get("stage", "")):
		"ordered":
			if now >= float(d.get("due", now)):
				var h := _hour()
				if h >= HOURS_FROM and h <= HOURS_TO:
					d["stage"] = "arriving"
					d["t0"] = now
				else:
					d["due"] = _office_hours(now + 1.0)
				_set_state(d)
		"arriving":
			if _ensure_path() and now >= float(d["t0"]) + VAN_IN + _path_len / WALK_M_PER_MIN:
				d["stage"] = "at_desk"
				d["t0"] = now
				_set_state(d)
		"at_desk":
			if _hour() >= GIVE_UP_HOUR or now - float(d["t0"]) > WAIT_MIN:
				d["stage"] = "missed"
				d["t0"] = now
				d["tries"] = int(d.get("tries", 0)) + 1
				_set_state(d)
		"missed":
			if _ensure_path() and now >= float(d["t0"]) + _path_len / WALK_M_PER_MIN + VAN_TURN + VAN_OUT:
				d["stage"] = "ordered"
				d["due"] = _office_hours(floorf(now / 1440.0) * 1440.0 + 1440.0 + HOURS_FROM * 60.0 + 20.0 + fmod(now, 61.0))
				_set_state(d)


## What changed since this machine last looked: the van's sound, a line in the feed, the
## bell across the counter.
func _noticed() -> void:
	if _stage == _seen:
		return
	var was := _seen
	_seen = _stage
	# A camp loaded with the order under way: no fanfare.
	if was == "":
		_seen_leave = _t0
		return
	match _stage:
		"arriving":
			_sound_world(SFX_ARRIVE, -2.0)
			_say("A post van pulls up outside the barrier.")
		"at_desk":
			if host.visible:
				_play(SFX_BELL, -4.0)
			else:
				_say("The postman is waiting at the reception.")
		"missed":
			_say("The postman did not wait. He will come again tomorrow.", 2)
			_close_closeup()
		"delivered":
			_close_closeup()
			if not _signed_here and was == "at_desk":
				_say("The parcel was signed for. A second monitor on the PC desk.", 1)
			_signed_here = false


# ── the way in ───────────────────────────────────────────────────────────────

## The van's place on the road outside the barrier, the postman's way from its door to
## the office door (the way the guests walk in: guest_agents._walk_to_reception).
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
	_park = Vector3(float(gate.gap_center_x) + 3.4, 0.0, float(gate.fence_z) - 9.0)
	var pts := PackedVector3Array([_park + Vector3(-1.2, 0.0, 1.4), road])
	if gate.has_method("way_in"):
		for p in gate.way_in():
			pts.append(p)
	pts.append(door)
	var y := _ground()
	for i in pts.size():
		pts[i].y = y
	_park.y = y
	_path = pts
	_path_len = 0.0
	for i in range(1, _path.size()):
		_path_len += _path[i - 1].distance_to(_path[i])
	return true


func _ground() -> float:
	var m := _resolve_main()
	var gm = m.get("grid_manager") if m != null else null
	return float(gm.grid_to_world(Vector2i.ZERO).y) if gm != null else 0.0


func _along(d: float) -> Array:
	d = clampf(d, 0.0, _path_len)
	for i in range(1, _path.size()):
		var seg := _path[i - 1].distance_to(_path[i])
		if d <= seg or i == _path.size() - 1:
			var t := 0.0 if seg < 0.001 else clampf(d / seg, 0.0, 1.0)
			return [_path[i - 1].lerp(_path[i], t), _path[i] - _path[i - 1]]
		d -= seg
	return [_path[_path.size() - 1], Vector3.FORWARD]


# ── in the camp: the van and the man ─────────────────────────────────────────

func _draw_world() -> void:
	var show_van := false
	var van_at := Vector3.ZERO
	var van_yaw := 0.0
	var man_at := Vector3.INF
	var man_dir := Vector3.ZERO
	if _stage in ["arriving", "at_desk", "missed", "delivered"] and _ensure_path():
		var e := _now() - _t0
		var walk := _path_len / WALK_M_PER_MIN
		match _stage:
			"arriving":
				show_van = true
				var k := clampf(e / VAN_IN, 0.0, 1.0)
				# In from the south along the road, slowing to a stop.
				van_at = _park + Vector3(0.0, 0.0, -70.0 * pow(1.0 - k, 2.0))
				if e >= VAN_IN:
					var r: Array = _along((e - VAN_IN) * WALK_M_PER_MIN)
					man_at = r[0]
					man_dir = r[1]
			"at_desk":
				show_van = true
				van_at = _park
			"missed", "delivered":
				if e < walk:
					var r: Array = _along(_path_len - e * WALK_M_PER_MIN)
					man_at = r[0]
					man_dir = -(r[1] as Vector3)
					show_van = true
					van_at = _park
				elif e < walk + VAN_TURN + VAN_OUT:
					show_van = true
					var t := e - walk
					# Round in its own length, in steps, then off down the road.
					var turn := clampf(t / VAN_TURN, 0.0, 1.0)
					van_yaw = floorf(turn * 6.0) / 6.0 * PI
					var go := clampf((t - VAN_TURN) / VAN_OUT, 0.0, 1.0)
					van_at = _park + Vector3(-2.2 * turn, 0.0, -90.0 * go * go)
					if _seen_leave != _t0:
						_seen_leave = _t0
						_sound_world(SFX_LEAVE, -2.0)
	if show_van:
		_ensure_van()
		_van.visible = true
		_van.global_position = van_at
		_van.rotation.y = van_yaw
	elif _van != null:
		_van.visible = false
	if man_at != Vector3.INF:
		_ensure_man()
		_man.visible = true
		_man.global_position = man_at
		var f := floorf(_anim_t * 8.0)
		_man_sprite.position.y = absf(sin(f * 0.8)) * 0.05
		_man_sprite.rotation.z = sin(f * 0.8) * 0.03
	elif _man != null:
		_man.visible = false


## The order's leaving the van's engine was heard for (its t0).
var _seen_leave := -1.0


func _world() -> Node:
	var m := _resolve_main()
	var w = m.get("_world_3d") if m != null else null
	return w if w != null else m


func _ensure_man() -> void:
	if _man != null and is_instance_valid(_man):
		return
	_man = Node3D.new()
	_man.name = "Postman"
	_world().add_child(_man)
	_man_sprite = _person_sprite()
	_man.add_child(_man_sprite)


func _person_sprite() -> Sprite3D:
	var s := Sprite3D.new()
	var path := SPRITE if ResourceLoader.exists(SPRITE) else SPRITE_FALLBACK
	var tex := load(path) as Texture2D
	s.texture = tex
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = true
	s.double_sided = true
	if tex != null:
		s.pixel_size = SPRITE_HEIGHT_M / float(tex.get_height())
		s.offset = Vector2(0.0, tex.get_height() * 0.5)
	return s


## The Czech post's van (Grok faces on Build boxes, like the wholesaler's Avia in
## day_events.gd): the sides, the front, the back doors; its nose lower than its box.
func _ensure_van() -> void:
	if _van != null and is_instance_valid(_van):
		return
	_van = Node3D.new()
	_van.name = "PostVan"
	_world().add_child(_van)
	var side_tex := _tex("van_side.png")
	var length := 4.5
	var h := 2.4
	if side_tex != null:
		h = length * float(side_tex.get_height()) / float(side_tex.get_width())
	var width := 1.9
	var yellow := Color(0.78, 0.56, 0.16)
	var blue := Color(0.16, 0.2, 0.36)
	# The box behind the faces: the lower body the whole length, the upper one short of
	# the sloping windscreen (the side picture's nose is a fifth of its length).
	_box(_van, Vector3(0, h * 0.32, 0), Vector3(width - 0.04, h * 0.3, length - 0.06), blue)
	_box(_van, Vector3(0, h * 0.72, -length * 0.1), Vector3(width - 0.04, h * 0.5, length * 0.8 - 0.06), yellow)
	# The side picture: its left end is the van's front (+z), the far side mirrored.
	for sd in [-1.0, 1.0]:
		_quad(_van, side_tex, Vector2(length, h), Vector3(sd * width * 0.5, h * 0.5, 0.0), sd * PI * 0.5, sd < 0.0)
	_quad(_van, _tex("van_front.png"), Vector2(width, h * 0.94), Vector3(0, h * 0.47, length * 0.5 - 0.02), 0.0, false)
	_quad(_van, _tex("van_back.png"), Vector2(width, h * 0.94), Vector3(0, h * 0.48, -length * 0.5 - 0.01), PI, false)
	# The tyres seen end on (where the side picture has them: post_art.py SIDE_WHEELS).
	var r := h * 104.0 / 690.0
	for x in [-(width * 0.5 - 0.12), width * 0.5 - 0.12]:
		for z in [length * (0.5 - 183.0 / 1280.0), -length * (1012.0 / 1280.0 - 0.5)]:
			var w := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = r
			cyl.bottom_radius = r
			cyl.height = 0.22
			cyl.radial_segments = 10
			w.mesh = cyl
			var wm := StandardMaterial3D.new()
			wm.albedo_color = Color(0.07, 0.065, 0.06)
			w.material_override = wm
			w.rotation.z = PI * 0.5
			w.position = Vector3(x, r, z)
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
	var here: bool = _stage == "at_desk"
	if _desk_man == null:
		if not here:
			return
		var root: Node3D = host.get("_room_root")
		var extras = host.get("_extras")
		if root == null or extras == null:
			return
		_desk_man = _person_sprite()
		_desk_man.name = "DeskPostman"
		# The room's sprites are a little shorter than the camp's (desk_room._show).
		if _desk_man.texture != null:
			_desk_man.pixel_size = 1.72 / float(_desk_man.texture.get_height())
		_desk_man.position = DESK_SPOT
		root.add_child(_desk_man)
		extras._hot_body("postman", root, DESK_SPOT + Vector3(0, 0.9, 0), Vector3(0.6, 1.8, 0.5), [])
	_desk_man.visible = here
	var hb = host.get("_extras").hot.get("postman", {}).get("body", null)
	if hb is CollisionObject3D:
		(hb as CollisionObject3D).collision_layer = 1 if here else 0


## The office's click on him (building_interior.dressing_click "postman").
func click_postman() -> bool:
	if stage() != "at_desk":
		return false
	if _closeup == null or not is_instance_valid(_closeup):
		_closeup = CLOSEUP.new()
		_closeup.post = self
		host.get_tree().root.add_child(_closeup)
	_closeup.open_view()
	return true


func is_closeup_open() -> bool:
	return _closeup != null and is_instance_valid(_closeup) and _closeup.visible


func _close_closeup() -> void:
	if is_closeup_open() and not _closeup.done:
		_closeup.close_view()


## The slip signed and the parcel taken (post_closeup.gd): the monitor is the camp's.
func signed(points: Array) -> void:
	var d := state()
	if str(d.get("stage", "")) != "at_desk":
		return
	d["stage"] = "delivered"
	d["t0"] = _now()
	# The warden's signature, as drawn (picture pixels), for the slip in the drawer.
	d["sig"] = points.slice(0, 400)
	_signed_here = true
	_set_state(d)
	_seen = "delivered"
	host.set_second_monitor(true)
	var hud = _resolve_main().get("_hud_manager") if _resolve_main() != null else null
	if hud != null:
		hud.show_banner(tr("SETUP UPGRADED"), tr("A second monitor on the PC desk."), Color(0.46, 0.86, 0.36), 4.2)


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
