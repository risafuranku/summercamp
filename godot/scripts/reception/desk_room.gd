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
var _ring_t := 0.0
var _stranger: Dictionary = {}
var _stranger_night := -1
var _stranger_wait := -1.0
var _pending_state: Dictionary = {}
var _tex_cache: Dictionary = {}


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
	desk.key_board_provider = func(): return GuestManager.get_key_board() if GuestManager != null else []
	desk.check_in_call = func(id: int): return GuestManager.request_check_in(id) if GuestManager != null else {"ok": false}
	desk.next_guest_provider = _next_for_desk
	# How bad tonight is, for what the desk sees across the counter at night.
	desk.pressure_provider = func():
		var dread = host.get("_dread") if host != null else null
		return float(dread.get("dread")) if dread != null else 0.0
	desk.refused.connect(func(id: int):
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


func is_open() -> bool:
	return desk != null and desk.visible


func open() -> void:
	if desk == null:
		return
	_ring_t = 0.0
	desk.open_desk(_front_info(), CoreRoot.get_day() if CoreRoot != null else 1)


## Leaving the office: whoever is not booked is not there when you come back.
func on_left_office() -> void:
	if not _stranger.is_empty():
		_stranger = {}
	_stranger_wait = -1.0


# ── every frame (building_interior.gd, while the office is open) ─────────────

func process(delta: float, in_office: bool) -> void:
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


func _front_info() -> Dictionary:
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
	_show(_second, _queue[1] if _queue.size() > 1 else {}, BENCH_SPOT)
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
	var wood := K.surface("door_wood", 1.0) if ResourceLoader.exists("res://assets/textury/camp/door_wood.png") else K.surface("planks_dark", 0.8)
	var leaf := K.slab(_door_pivot, Vector3(DOOR_W, 2.05, 0.05), Vector3(-DOOR_W * 0.5, 1.025, 0.0), wood, "FrontDoorLeaf")
	var handle := K.slab(_door_pivot, Vector3(0.05, 0.05, 0.08), Vector3(-DOOR_W + 0.1, 1.0, 0.05), K.surface("planks_dark", 0.4, Color(0.8, 0.7, 0.4)), "FrontDoorHandle")
	# Click it and you go out into the camp, the way you came in (reception_extras).
	_hot("front_door", DOOR_HINGE + Vector3(-DOOR_W * 0.5, 1.05, 0.05), Vector3(DOOR_W, 2.1, 0.2), [leaf, handle])


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
