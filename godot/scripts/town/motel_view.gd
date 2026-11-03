extends RefCounted

## Inside the Liblice motel (town_room.gd's places "motel", the reception, and
## "motel_room", number four), built from its plan (motel_plan.gd, motel_rooms.gd) so its
## windows look out of the block where it stands in the village (window_portal.gd).
##
##   the reception  Simek behind the counter (from seven a room: he takes four's key off
##                  the board and it goes in your bag), the bell, the guest book, the
##                  drinks machine, the television in the corner;
##   number four    you stand inside the door; the key turns twice in the lock (the user's
##                  "lock it twice"), the lamps over the beds, the light by the bed, the
##                  TV on the corner table, the curtains, the tap, the wardrobe, the
##                  radiator (knock on it at night and now and then it knocks back), the
##                  bed: lie down, and at night sleep (town_trip passes the night and wakes
##                  you there in the morning).
## Nobody narrates: things answer with their sounds and their light.

const PLAN = preload("res://scripts/town/motel_plan.gd")
const ROOMS = preload("res://scripts/town/motel_rooms.gd")
const K = preload("res://scripts/interior_kit.gd")
const WINDOW_PORTAL = preload("res://scripts/ui/window_portal.gd")
const SFX := "res://assets/sfx/"
## The TV's channels at night and by day (camp pictures).
const TV_NIGHT := ["tv_testcard", "tvshow_forest", "tvshow_weather"]
const TV_DAY := ["tvshow_weather", "tvshow_forest", "tv_testcard"]
const SIMEK_LINES := [
	"Rooms from seven in the evening. Fifteen dollars.",
	"The camp people used to come down for the shower. Then they stopped coming down at all.",
	"Number four has the best mattress. Number six I do not let.",
	"Breakfast is a promise, not a guarantee.",
	"Do not open the window in number six. It does not open, but do not.",
]

var room                         # town_room.gd
var n := 0                       # 0 the reception, else the room's number
## The motel in the village (motel_block.gd): its transform maps this room out.
var block: Node3D
var parts: Dictionary = {}
var windows: Array = []          # window_portal.gd
var lights: Dictionary = {}      # "ceiling", "lamp_a", "lamp_b", "tv", "day"
var lamps_on := false
var ceiling_on := false
var tv_on := false
var tv_channel := 0
var turns := 0                   # the key's turns in the lock (0 open .. 2 locked twice)
var lying := false
var asleep := false
var _t := 0.0
var _line := 0
var _tv_screen: MeshInstance3D
var _tv_mat: StandardMaterial3D
var _knock_back := -1.0
var _stand_rot := Vector3.ZERO


func _init(p_room, p_n: int, p_block: Node3D) -> void:
	room = p_room
	n = p_n
	block = p_block


func _origin() -> Vector3:
	return PLAN.lobby_origin() if n == 0 else PLAN.room_origin(n)


## room space -> the village (the block's own transform, the room where it stands in it).
func _xform() -> Transform3D:
	if block == null or not is_instance_valid(block) or not block.is_inside_tree():
		return Transform3D()
	return block.global_transform * Transform3D(Basis(), _origin())


func _night(hour: float) -> bool:
	return hour >= 19.5 or hour < 6.5


# ── building ─────────────────────────────────────────────────────────────────

func build(hour: float, keys: Array) -> void:
	var root: Node3D = room._root
	if n == 0:
		parts = ROOMS.build_lobby(root, true, keys)
		_lobby_things(hour)
	else:
		parts = ROOMS.build_room(root, n, true, {"made": true})
		_room_things(hour)
	_make_windows()
	_set_light(hour)


func _lobby_things(hour: float) -> void:
	var simek: Vector3 = parts.get("simek", Vector3.ZERO)
	room._npc_sprite("town_motel", 1.7, simek, "him")
	var c: Vector3 = parts.get("counter", Vector3(0, 1.1, 0.55))
	room._hot_box("desk", c + Vector3(0, -0.5, -0.2), Vector3(2.8, 1.1, 0.4), [])
	if parts.get("bell") != null:
		room._hot_box("bell", (parts["bell"] as Node3D).position + Vector3(0, 0.06, 0), Vector3(0.22, 0.16, 0.22), [parts["bell"]])
	if parts.get("book") != null:
		room._hot_box("book", (parts["book"] as Node3D).position, Vector3(0.45, 0.06, 0.32), [parts["book"]])
	if parts.get("vending") != null:
		var vm: Node3D = parts["vending"]
		room._hot_box("machine", vm.position + Vector3(0.2, 0.9, 0), Vector3(0.4, 1.8, 0.9), [vm])
	var tv: Dictionary = parts.get("tv", {})
	if not tv.is_empty():
		room._hot_box("tv", (tv["at"] as Vector3) + Vector3(0, 0.25, 0), Vector3(0.65, 0.5, 0.5), [tv["node"]])
		_make_tv_screen(tv["node"], Vector2(0.62, 0.465), Rect2(0.13, 0.17, 0.62, 0.6))
	var door := PLAN.room_door(0)
	room._hot_box("door", Vector3(door.x, 1.0, door.z + 0.05), Vector3(1.0, 2.1, 0.15), [])
	# You stand inside the door, the counter before you.
	room._cam.position = Vector3(door.x, 1.6, door.z + 0.7)
	room._base_rot = Vector3(deg_to_rad(-5.0), PI - 0.31, 0.0)
	room._look.yaw_limit_deg = 110.0


func _room_things(hour: float) -> void:
	var d := PLAN.room_door(n)
	var w := PLAN.ROOM_W
	var dd := PLAN.ROOM_D
	room._hot_box("door", Vector3(d.x, 1.0, d.z + 0.06), Vector3(0.95, 2.05, 0.1), [])
	if parts.get("key") != null:
		room._hot_box("lock", (parts["key"] as Node3D).position + Vector3(0, 0.1, 0.02), Vector3(0.22, 0.26, 0.1), [parts["key"]])
	# The headboard's lamps (on the back wall, over the beds' heads), the switch by the bed.
	room._hot_box("lamps", Vector3(0, 1.15, dd * 0.5 - 0.1), Vector3(w * 0.9, 0.5, 0.15), [])
	room._hot_box("switch", Vector3(-w * 0.43, 1.11, dd * 0.5 - 0.05), Vector3(0.14, 0.18, 0.08), [])
	for i in PLAN.BED_X.size():
		room._hot_box("bed", Vector3(PLAN.BED_X[i], 0.35, PLAN.BED_Z), Vector3(PLAN.BED_SIZE.x, 0.4, PLAN.BED_SIZE.z), [])
	var tv: Dictionary = parts.get("tv", {})
	if not tv.is_empty():
		room._hot_box("tv", (tv["at"] as Vector3) + Vector3(0, 0.3, 0), Vector3(0.5, 0.6, 0.5), [tv["node"]])
		_make_tv_screen(tv["node"], ROOMS.TV_SIZE, ROOMS.TV_SCREEN)
	room._hot_box("basin", Vector3(w * 0.5 - 0.15, 0.9, -0.62), Vector3(0.3, 0.5, 0.55), [])
	room._hot_box("wardrobe", Vector3(-w * 0.5 + 0.21, 0.95, PLAN.WARDROBE_Z), Vector3(0.44, 1.9, 1.0), [])
	var win: Vector3 = PLAN.room_windows(n)[0]
	room._hot_box("radiator", Vector3(win.x, 0.4, -dd * 0.5 + 0.12), Vector3(1.0, 0.55, 0.2), [])
	room._cam.position = PLAN.STAND
	_stand_rot = Vector3(deg_to_rad(-6.0), PI, 0.0)
	room._base_rot = _stand_rot
	room._look.yaw_limit_deg = 170.0
	room._look.pitch_down_deg = 40.0


## A picture for the TV's screen, laid over the screen of its sprite (which turns to you):
## a quad turned with it each frame, a hair in front.
func _make_tv_screen(tv_node: Node3D, size: Vector2, screen: Rect2) -> void:
	_tv_mat = StandardMaterial3D.new()
	_tv_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tv_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_tv_screen = MeshInstance3D.new()
	_tv_screen.name = "TvScreen"
	var q := QuadMesh.new()
	q.size = Vector2(size.x * screen.size.x, size.y * screen.size.y)
	_tv_screen.mesh = q
	_tv_screen.material_override = _tv_mat
	_tv_screen.visible = false
	_tv_screen.set_meta("retro_skip", true)
	_tv_screen.set_meta("screen_rect", screen)
	_tv_screen.set_meta("tv_size", size)
	_tv_screen.set_meta("tv", tv_node)
	room._root.add_child(_tv_screen)


func _make_windows() -> void:
	var root: Node3D = room._root
	var i := 0
	for wc in PLAN.room_windows(n):
		var w = WINDOW_PORTAL.make(room, root, (wc as Vector3) + Vector3(0, 0, 0.02), Vector3(0, 0, -1), PLAN.window_size(), "motel_curtain" if ResourceLoader.exists("res://assets/textury/camp/motel_curtain.png") else "curtain_floral")
		if w.body != null:
			w.body.set_meta("room_hot", "curtain%d" % i)
			room._hot["curtain%d" % i] = {"body": w.body, "meshes": []}
		windows.append(w)
		i += 1


# ── light ────────────────────────────────────────────────────────────────────

func _set_light(hour: float) -> void:
	var env: Environment = room._env
	var day := hour >= 7.0 and hour < 18.5
	var dusk := not day and (hour >= 18.5 and hour < 20.0 or hour >= 5.5 and hour < 7.0)
	env.ambient_light_color = Color(0.86, 0.84, 0.8) if day else Color(0.5, 0.55, 0.7)
	env.ambient_light_energy = 0.42 if day else (0.2 if dusk else 0.08)
	for k in lights.keys():
		if is_instance_valid(lights[k]):
			(lights[k] as Node).queue_free()
	lights.clear()
	var root: Node3D = room._root
	# Daylight through the window(s).
	if day or dusk:
		for wc in PLAN.room_windows(n):
			var l := _omni(root, (wc as Vector3) + Vector3(0, 0.1, 0.9), Color(0.9, 0.94, 1.0) if day else Color(0.9, 0.62, 0.5), 0.9 if day else 0.45, 5.0)
			lights["day%d" % lights.size()] = l
	if n == 0:
		# Simek's desk lamp, always on after dark; the room's light by day.
		var c: Vector3 = parts.get("counter", Vector3(0, 1.1, 0.55))
		lights["desk"] = _omni(root, c + Vector3(-1.05, 0.45, 0.15), Color(1.0, 0.78, 0.5), 0.9, 4.0, true)
		lights["ceiling"] = _omni(root, Vector3(0, PLAN.ROOM_H - 0.3, 0), Color(1.0, 0.86, 0.66), 0.75 if not day else 0.4, 6.0)
		return
	var hw_h := PLAN.ROOM_W * 9.0 / 16.0
	var lamp_y := PLAN.HEADWALL_Y + hw_h * 0.46
	lights["lamp_a"] = _omni(root, Vector3(-0.345 * PLAN.ROOM_W, lamp_y, PLAN.ROOM_D * 0.5 - 0.25), Color(1.0, 0.74, 0.44), 0.55, 2.6, true)
	lights["lamp_b"] = _omni(root, Vector3(0.345 * PLAN.ROOM_W, lamp_y, PLAN.ROOM_D * 0.5 - 0.25), Color(1.0, 0.74, 0.44), 0.55, 2.6)
	lights["ceiling"] = _omni(root, Vector3(0, PLAN.ROOM_H - 0.55, 0.2), Color(1.0, 0.86, 0.64), 1.0, 5.5, true)
	var tv: Dictionary = parts.get("tv", {})
	if not tv.is_empty():
		lights["tv"] = _omni(root, (tv["at"] as Vector3) + Vector3(-0.3, 0.4, 0.3), Color(0.6, 0.72, 1.0), 0.5, 3.0)
	_apply_switches()


func _omni(root: Node3D, pos: Vector3, col: Color, energy: float, rng: float, shadow := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.1
	l.shadow_enabled = shadow
	root.add_child(l)
	return l


func _apply_switches() -> void:
	for k in ["lamp_a", "lamp_b"]:
		if lights.has(k):
			(lights[k] as OmniLight3D).visible = lamps_on
	for g in parts.get("lamps", []):
		(g as Node3D).visible = lamps_on
	if lights.has("ceiling"):
		(lights["ceiling"] as OmniLight3D).visible = ceiling_on
	if lights.has("tv"):
		(lights["tv"] as OmniLight3D).visible = tv_on
	if _tv_screen != null:
		_tv_screen.visible = tv_on


## Is anybody's light on in here (the room lit from the car park).
func lit() -> bool:
	return lamps_on or ceiling_on or tv_on


# ── each frame ───────────────────────────────────────────────────────────────

func tick(delta: float) -> void:
	_t += delta
	var world: World3D = block.get_world_3d() if block != null and is_instance_valid(block) and block.is_inside_tree() else null
	var xf := _xform()
	var shell: Node3D = block.shell(n) if block != null and is_instance_valid(block) and block.has_method("shell") else null
	for w in windows:
		w.update(room._root, room._cam, xf, world != null and not asleep, world, delta, shell)
	_tick_tv()
	if _knock_back > 0.0:
		_knock_back -= delta
		if _knock_back <= 0.0:
			# Two knocks in the pipe, from somewhere in the building.
			_play("motel/radiator_knock.mp3", -9.0)


func _tick_tv() -> void:
	if _tv_screen == null or not tv_on:
		return
	var tv: Node3D = _tv_screen.get_meta("tv")
	if tv == null or not is_instance_valid(tv):
		return
	# The sprite turns with the eye's view about Y (a billboard faces the camera's plane,
	# not its position): the screen the same, a hair towards the eye.
	var base: Vector3 = tv.global_position
	var cam: Camera3D = room._cam
	var fwd: Vector3 = -cam.global_basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		return
	var to_eye: Vector3 = -fwd.normalized()
	var size: Vector2 = _tv_screen.get_meta("tv_size")
	var sr: Rect2 = _tv_screen.get_meta("screen_rect")
	var right := Vector3.UP.cross(to_eye).normalized()
	var cx := (sr.position.x + sr.size.x * 0.5 - 0.5) * size.x
	var cy := (1.0 - (sr.position.y + sr.size.y * 0.5)) * size.y
	_tv_screen.global_position = base + right * -cx + Vector3(0, cy, 0) + to_eye * 0.012
	_tv_screen.global_basis = Basis.looking_at(-to_eye, Vector3.UP)
	# The picture's light flickers with it, in steps.
	if lights.has("tv"):
		var k := floorf(_t * 8.0)
		(lights["tv"] as OmniLight3D).light_energy = 0.32 + 0.22 * absf(sin(k * 1.7))


# ── clicks ───────────────────────────────────────────────────────────────────

## A click on `id`; true when it was the motel's.
func click(id: String, hour: float) -> bool:
	if n == 0:
		return _lobby_click(id, hour)
	return _room_click(id, hour)


func _lobby_click(id: String, hour: float) -> bool:
	match id:
		"him":
			_line += 1
			room._npc_nod = 0.5
			room.say("Mr Simek", SIMEK_LINES[_line % SIMEK_LINES.size()])
		"desk":
			room._npc_nod = 0.5
			room.wants_closeup.emit("motel_room")
		"bell":
			_play("bistro/bell_ding.mp3", -6.0)
			room._npc_nod = 0.6
		"book":
			_play("desk/keys.mp3", -14.0)
		"machine":
			if CoreRoot.get_money() < 1 or not CoreRoot.actions.spend_money(1):
				_play("director/knock_wrong.mp3", -14.0)
				return true
			_play("jednota/coin.mp3", -8.0)
			room.get_tree().create_timer(0.5).timeout.connect(func(): _play("motel/can_drop.mp3", -4.0))
		"tv":
			_toggle_tv(hour)
		_:
			if id.begins_with("curtain"):
				_curtain(int(id.substr(7)))
			else:
				return false
	return true


func _room_click(id: String, hour: float) -> bool:
	if lying and id != "bed":
		# Up off the bed first, whatever was clicked.
		get_up()
		return true
	match id:
		"lock":
			if turns < 2:
				turns += 1
				_play("motel/lock_turn.mp3", -4.0)
				_turn_key()
			else:
				_unlock()
		"lamps":
			lamps_on = not lamps_on
			_play("backroom/lamp_click.mp3", -6.0)
			_apply_switches()
		"switch":
			ceiling_on = not ceiling_on
			_play("bistro/switch.mp3", -8.0)
			_apply_switches()
		"tv":
			_toggle_tv(hour)
		"bed":
			if not lying:
				lie_down(hour)
		"basin":
			_play("caravan/tap.mp3", -8.0)
		"wardrobe":
			_play("caravan/locker_open.mp3", -8.0)
			room.get_tree().create_timer(1.1).timeout.connect(func(): _play("caravan/locker_shut.mp3", -9.0))
		"radiator":
			_play("motel/radiator_knock.mp3", -2.0)
			# Late at night, now and then, it answers.
			if _night(hour) and (hour >= 23.0 or hour < 4.0) and randf() < 0.18 and _knock_back <= 0.0:
				_knock_back = 2.2
		_:
			if id.begins_with("curtain"):
				_curtain(int(id.substr(7)))
			else:
				return false
	return true


func _curtain(i: int) -> void:
	if i < 0 or i >= windows.size():
		return
	var w = windows[i]
	var opening: bool = w.curtain_open() < 0.5
	w.toggle_curtain()
	_play("backroom/curtain_open.mp3" if opening else "backroom/curtain_shut.mp3", -8.0)


func _toggle_tv(hour: float) -> void:
	tv_on = not tv_on
	_play("backroom/tv_on.mp3" if tv_on else "backroom/tv_off.mp3", -8.0)
	if tv_on and _tv_mat != null:
		var chans: Array = TV_NIGHT if _night(hour) else TV_DAY
		var tex := "res://assets/textury/camp/%s.png" % str(chans[tv_channel % chans.size()])
		tv_channel += 1
		if ResourceLoader.exists(tex):
			_tv_mat.albedo_texture = load(tex)
	_apply_switches()


## The key turned once in the lock: it goes edge on and comes round flat again.
func _turn_key() -> void:
	var key: Node3D = parts.get("key")
	if key == null:
		return
	var tw: Tween = room.create_tween()
	tw.tween_property(key, "scale:x", 0.15, 0.12)
	tw.tween_property(key, "scale:x", 1.0, 0.12)


## Both turns back, as you go out.
func _unlock() -> void:
	if turns <= 0:
		return
	turns = 0
	_play("motel/lock_turn.mp3", -4.0)
	_turn_key()
	room.get_tree().create_timer(0.3).timeout.connect(func():
		_play("motel/lock_turn.mp3", -5.0)
		_turn_key())


## The door, or S: still locked, the key turns back first (and then you go).
func wants_out() -> bool:
	if n == 0:
		return true
	if lying:
		get_up()
		return false
	if turns > 0:
		_unlock()
	_play("backroom/room_door_open.mp3", -8.0)
	return true


# ── the bed ──────────────────────────────────────────────────────────────────

func lie_down(hour: float) -> void:
	lying = true
	_play("backroom/bed_creak.mp3", -6.0)
	var tw: Tween = room.create_tween().set_parallel(true)
	tw.tween_property(room._cam, "position", PLAN.LIE, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(room, "_base_rot", Vector3(deg_to_rad(-4.0), -0.45, 0.0), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	room._look.yaw_limit_deg = 75.0
	room._look.pitch_down_deg = 20.0
	if _night(hour) or hour < 6.5:
		room.get_tree().create_timer(1.2).timeout.connect(func():
			if lying and room.is_open():
				room.wants_closeup.emit("sleep"))


func get_up() -> void:
	if not lying:
		return
	lying = false
	asleep = false
	_play("backroom/bed_creak.mp3", -8.0)
	var tw: Tween = room.create_tween().set_parallel(true)
	tw.tween_property(room._cam, "position", PLAN.STAND, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(room, "_base_rot", _stand_rot, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	room._look.yaw_limit_deg = 170.0
	room._look.pitch_down_deg = 40.0


## The night passed with you in the bed: the morning in the room, the lights left on gone
## out (the bulbs do not, but you switched them off in your sleep, as everybody does).
func morning(hour: float) -> void:
	asleep = false
	lamps_on = false
	ceiling_on = false
	tv_on = false
	_set_light(hour)


# ── co-op ────────────────────────────────────────────────────────────────────

## The other wardens in here: asleep in the other bed (lying on it the way the cabins
## show them, interior_manager._coop_lay_sleeper), else standing by the wardrobe; in the
## reception at the counter beside you.
const LOOKS = preload("res://scripts/coop/warden_looks.gd")
const SLEEPER_TILT := 28.0
const SLEEPER_LENGTH := 0.72
var _sleepers: Dictionary = {}


func place_mates(mates: Dictionary, ids: Array) -> void:
	var k := 0
	for id in _sleepers.keys():
		if not ids.has(id) or not bool(Coop.state_of(int(id)).get("z", false)):
			if is_instance_valid(_sleepers[id]):
				(_sleepers[id] as Node).queue_free()
			_sleepers.erase(id)
	for id in ids:
		var fig = mates.get(int(id))
		if fig == null:
			continue
		var asleep_there := bool(Coop.state_of(int(id)).get("z", false))
		fig.visible = true
		if n != 0 and asleep_there:
			fig.visible = false
			_lay(int(id))
		elif n != 0:
			fig.show_at(Vector3(-PLAN.ROOM_W * 0.5 + 0.75, 0.0, 0.55 + 0.5 * float(k)), "stand")
		else:
			var d := PLAN.room_door(0)
			fig.show_at(Vector3(d.x + (0.9 if k % 2 == 0 else -0.9), 0.0, d.z + 1.4), "stand")
		k += 1


## Warden `id` on their back in the second bed, the head at the pillow.
func _lay(id: int) -> void:
	var sl: Sprite3D = _sleepers.get(id)
	if sl == null or not is_instance_valid(sl):
		var look: Dictionary = Coop.look_of(id)
		var tex: Texture2D = LOOKS.texture(int(look.get("m", 1)), int(look.get("c", 0)), "bedfoot")
		if tex == null:
			return
		sl = Sprite3D.new()
		sl.name = "Sleeper"
		sl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		sl.double_sided = true
		sl.shaded = true
		sl.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sl.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sl.texture = tex
		sl.pixel_size = SLEEPER_LENGTH / float(tex.get_height())
		sl.offset = Vector2(0.0, tex.get_height() * 0.5)
		room._root.add_child(sl)
		_sleepers[id] = sl
	var bx: float = PLAN.BED_X[1]
	var head := Vector3(bx, 0.55, PLAN.ROOM_D * 0.5 - 0.35)
	var along := Vector3(0, 0, 1)
	var tilt := deg_to_rad(SLEEPER_TILT)
	var up := (along * cos(tilt) + Vector3.UP * sin(tilt)).normalized()
	var nrm := (Vector3.UP * cos(tilt) - along * sin(tilt)).normalized()
	sl.transform = Transform3D(Basis(up.cross(nrm), up, nrm), head - along * (SLEEPER_LENGTH * cos(tilt)) + Vector3(0, 0.04, 0))


func close() -> void:
	for w in windows:
		w.free_all()
	windows.clear()
	for id in _sleepers.keys():
		if is_instance_valid(_sleepers[id]):
			(_sleepers[id] as Node).queue_free()
	_sleepers.clear()


func _play(path: String, db: float) -> void:
	room._play(SFX + path, db)
